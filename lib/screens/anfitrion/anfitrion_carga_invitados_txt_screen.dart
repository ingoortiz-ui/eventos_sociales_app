import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class AnfitrionCargaInvitadosTxtScreen extends StatefulWidget {
  final String eventoId;
  final String empresaId;
  final String anfitrionId;

  const AnfitrionCargaInvitadosTxtScreen({
    super.key,
    required this.eventoId,
    required this.empresaId,
    required this.anfitrionId,
  });

  @override
  State<AnfitrionCargaInvitadosTxtScreen> createState() =>
      _AnfitrionCargaInvitadosTxtScreenState();
}

class _AnfitrionCargaInvitadosTxtScreenState
    extends State<AnfitrionCargaInvitadosTxtScreen> {
  bool processing = false;
  String anfitrionNombre = '';
  String anfitrionUid = '';
  int maxInvitados = 0;
  String nombreArchivo = '';
  final textoPegadoController = TextEditingController();

  int procesados = 0;
  int guardados = 0;
  int omitidos = 0;
  final List<String> detalles = [];

  String _normalizarCorreo(String correo) {
    return correo.trim().toLowerCase();
  }

  Future<void> _cargarAnfitrion() async {
    final doc = await FirebaseFirestore.instance
        .collection('anfitriones_evento')
        .doc(widget.anfitrionId)
        .get();

    final data = doc.data() ?? {};
    setState(() {
      anfitrionNombre = (data['nombre'] ?? '').toString();
      anfitrionUid = (data['uidUsuario'] ?? '').toString();
      maxInvitados = (data['maxInvitados'] ?? 0) as int;
    });
  }

  Future<int> _totalInvitadosAnfitrion() async {
    final snap = await FirebaseFirestore.instance
        .collection('eventos')
        .doc(widget.eventoId)
        .collection('invitados')
        .where('anfitrionId', isEqualTo: widget.anfitrionId)
        .where('esAnfitrion', isEqualTo: false)
        .get();

    return snap.docs.length;
  }

  Future<Set<String>> _emailsExistentesEnEvento() async {
    final snap = await FirebaseFirestore.instance
        .collection('eventos')
        .doc(widget.eventoId)
        .collection('invitados')
        .get();

    return snap.docs
        .map((d) =>
            _normalizarCorreo((d.data()['email_invitado'] ?? '').toString()))
        .where((e) => e.isNotEmpty)
        .toSet();
  }

  Future<void> seleccionarArchivoTxt() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    Uint8List? bytes = file.bytes;
    if (bytes == null) return;

    final texto = utf8.decode(bytes, allowMalformed: true);

    setState(() {
      nombreArchivo = file.name;
      textoPegadoController.text = texto;
      procesados = 0;
      guardados = 0;
      omitidos = 0;
      detalles.clear();
    });
  }

  List<Map<String, String>> _parsearLineas(String texto) {
    final lineas = const LineSplitter().convert(texto);
    final resultado = <Map<String, String>>[];

    for (final lineaOriginal in lineas) {
      final linea = lineaOriginal.trim();
      if (linea.isEmpty) continue;

      String separador = ',';
      if (linea.contains(';')) {
        separador = ';';
      } else if (linea.contains('|')) {
        separador = '|';
      }

      final partes = linea.split(separador).map((e) => e.trim()).toList();

      if (partes.length < 2) {
        resultado.add({'error': 'Formato inválido', 'linea': linea});
        continue;
      }

      final nombre = partes[0].trim();
      final email = _normalizarCorreo(partes[1]);
      final mesa = partes.length >= 3 ? partes[2].trim() : '';

      resultado.add({
        'nombre': nombre,
        'email': email,
        'mesa': mesa,
        'linea': linea,
      });
    }

    return resultado;
  }

  Future<void> procesarCargaMasiva() async {
    final fuenteTexto = textoPegadoController.text.trim();

    if (fuenteTexto.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un TXT o pega contenido')),
      );
      return;
    }

    setState(() {
      processing = true;
      procesados = 0;
      guardados = 0;
      omitidos = 0;
      detalles.clear();
    });

    try {
      final lineas = _parsearLineas(fuenteTexto);
      final emailsExistentesEvento = await _emailsExistentesEnEvento();
      final emailsEnArchivo = <String>{};

      int totalActualAnfitrion = await _totalInvitadosAnfitrion();

      for (final item in lineas) {
        procesados++;

        if (item.containsKey('error')) {
          omitidos++;
          detalles.add('Línea inválida: ${item['linea']}');
          continue;
        }

        final nombre = (item['nombre'] ?? '').trim();
        final email = _normalizarCorreo(item['email'] ?? '');
        final mesa = (item['mesa'] ?? '').trim();
        final linea = item['linea'] ?? '';

        if (nombre.isEmpty || email.isEmpty) {
          omitidos++;
          detalles.add('Faltan datos obligatorios: $linea');
          continue;
        }

        if (emailsEnArchivo.contains(email)) {
          omitidos++;
          detalles.add('Correo repetido en archivo: $email');
          continue;
        }

        if (emailsExistentesEvento.contains(email)) {
          omitidos++;
          detalles.add('Correo ya registrado en este evento: $email');
          continue;
        }

        if (totalActualAnfitrion >= maxInvitados) {
          omitidos++;
          detalles.add('Ya alcanzaste tu cupo máximo: $email');
          continue;
        }

        String uidUsuario = '';
        final usuarioSnap = await FirebaseFirestore.instance
            .collection('usuarios')
            .where('empresaId', isEqualTo: widget.empresaId)
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        if (usuarioSnap.docs.isNotEmpty) {
          uidUsuario = usuarioSnap.docs.first.id;
        } else {
          final nuevoUsuarioRef =
              FirebaseFirestore.instance.collection('usuarios').doc();
          await nuevoUsuarioRef.set({
            'empresaId': widget.empresaId,
            'nombre': nombre,
            'email': email,
            'rol': 'invitado',
            'activo': true,
            'createdAt': FieldValue.serverTimestamp(),
          });
          uidUsuario = nuevoUsuarioRef.id;
        }

        final invitadosRef = FirebaseFirestore.instance
            .collection('eventos')
            .doc(widget.eventoId)
            .collection('invitados');

        final docRef = invitadosRef.doc();
        final qrPayload =
            '{"eventoId":"${widget.eventoId}","invitadoId":"${docRef.id}"}';

        await docRef.set({
          'nombre_invitado': nombre,
          'email_invitado': email,
          'mesa': mesa,
          'usuarioId': uidUsuario,
          'eventoId': widget.eventoId,
          'empresaId': widget.empresaId,
          'anfitrionId': widget.anfitrionId,
          'anfitrionNombre': anfitrionNombre,
          'anfitrionUid': anfitrionUid,
          'estado_asistencia': 'pendiente',
          'qr_code': qrPayload,
          'creadoPorRol': 'anfitrion',
          'esAnfitrion': false,
          'puedeGestionarInvitados': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

        emailsExistentesEvento.add(email);
        emailsEnArchivo.add(email);
        totalActualAnfitrion++;
        guardados++;
        detalles.add('Guardado: $email');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Carga terminada. Procesados: $procesados, guardados: $guardados, omitidos: $omitidos',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error en carga masiva: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => processing = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _cargarAnfitrion();
  }

  @override
  void dispose() {
    textoPegadoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Carga masiva de invitados'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text('Anfitrión: $anfitrionNombre'),
            Text('Cupo máximo: $maxInvitados'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: processing ? null : seleccionarArchivoTxt,
              child: const Text('Seleccionar archivo TXT'),
            ),
            if (nombreArchivo.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Archivo: $nombreArchivo'),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: textoPegadoController,
              minLines: 6,
              maxLines: 12,
              decoration: const InputDecoration(
                labelText: 'O pega aquí el contenido',
                hintText: 'nombre,email,mesa',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text('Formato por línea: nombre,email,mesa'),
            const Text('También acepta: nombre;email;mesa o nombre|email|mesa'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: processing ? null : procesarCargaMasiva,
              child:
                  Text(processing ? 'Procesando...' : 'Procesar carga masiva'),
            ),
            const SizedBox(height: 24),
            Text('Procesados: $procesados'),
            Text('Guardados: $guardados'),
            Text('Omitidos: $omitidos'),
            const SizedBox(height: 12),
            ...detalles.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(e),
                )),
          ],
        ),
      ),
    );
  }
}
