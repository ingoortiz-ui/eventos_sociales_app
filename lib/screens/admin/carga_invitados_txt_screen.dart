import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class CargaInvitadosTxtScreen extends StatefulWidget {
  final String eventoId;

  const CargaInvitadosTxtScreen({
    super.key,
    required this.eventoId,
  });

  @override
  State<CargaInvitadosTxtScreen> createState() =>
      _CargaInvitadosTxtScreenState();
}

class _CargaInvitadosTxtScreenState extends State<CargaInvitadosTxtScreen> {
  final textoPegadoController = TextEditingController();

  bool loadingEvento = true;
  bool processing = false;

  String empresaId = '';
  String nombreEvento = '';
  int totalInvitados = 0;
  bool usaAnfitriones = false;

  String? anfitrionSeleccionadoId;
  String anfitrionSeleccionadoNombre = '';
  String anfitrionUid = '';
  int anfitrionMaxInvitados = 0;

  String nombreArchivo = '';
  String contenidoTxt = '';

  int procesados = 0;
  int guardados = 0;
  int omitidos = 0;
  final List<String> detalles = [];

  String _normalizarCorreo(String correo) {
    return correo.trim().toLowerCase();
  }

  Future<void> _cargarEvento() async {
    final doc = await FirebaseFirestore.instance
        .collection('eventos')
        .doc(widget.eventoId)
        .get();

    final data = doc.data() ?? {};

    setState(() {
      empresaId = (data['empresaId'] ?? '').toString();
      nombreEvento = (data['nombreEvento'] ?? '').toString();
      totalInvitados = (data['totalInvitados'] ?? 0) as int;
      usaAnfitriones = data['usaAnfitriones'] == true;
      loadingEvento = false;
    });
  }

  Future<int> _contarInvitadosReales() async {
    final snap = await FirebaseFirestore.instance
        .collection('eventos')
        .doc(widget.eventoId)
        .collection('invitados')
        .where('esAnfitrion', isEqualTo: false)
        .get();

    return snap.docs.length;
  }

  Future<int> _contarInvitadosDelAnfitrion(String anfitrionId) async {
    final snap = await FirebaseFirestore.instance
        .collection('eventos')
        .doc(widget.eventoId)
        .collection('invitados')
        .where('anfitrionId', isEqualTo: anfitrionId)
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
        .map((d) => _normalizarCorreo(
              (d.data()['email_invitado'] ?? '').toString(),
            ))
        .where((email) => email.isNotEmpty)
        .toSet();
  }

  Future<Map<String, dynamic>?> _buscarUsuarioPorCorreo(String email) async {
    final snap = await FirebaseFirestore.instance
        .collection('usuarios')
        .where('empresaId', isEqualTo: empresaId)
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;

    return {
      'uid': snap.docs.first.id,
      'data': snap.docs.first.data(),
    };
  }

  Future<void> _seleccionarArchivoTxt() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      Uint8List? bytes = file.bytes;

      if (bytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo leer el archivo TXT')),
        );
        return;
      }

      final texto = utf8.decode(bytes, allowMalformed: true);

      setState(() {
        nombreArchivo = file.name;
        contenidoTxt = texto;
        textoPegadoController.text = texto;
        procesados = 0;
        guardados = 0;
        omitidos = 0;
        detalles.clear();
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Archivo cargado: ${file.name}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error seleccionando archivo: $e')),
      );
    }
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
        resultado.add({
          'error': 'Formato inválido',
          'linea': linea,
        });
        continue;
      }

      resultado.add({
        'nombre': partes[0],
        'email': _normalizarCorreo(partes[1]),
        'mesa': partes.length >= 3 ? partes[2] : '',
        'linea': linea,
      });
    }

    return resultado;
  }

  Future<void> _procesarCargaMasiva() async {
    final fuenteTexto = textoPegadoController.text.trim().isNotEmpty
        ? textoPegadoController.text
        : contenidoTxt;

    if (fuenteTexto.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona un TXT o pega el contenido'),
        ),
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
      final emailsExistentes = await _emailsExistentesEnEvento();
      final emailsEnArchivo = <String>{};

      int totalActualEvento = await _contarInvitadosReales();

      int totalActualAnfitrion = 0;
      if (usaAnfitriones && (anfitrionSeleccionadoId ?? '').isNotEmpty) {
        totalActualAnfitrion =
            await _contarInvitadosDelAnfitrion(anfitrionSeleccionadoId!);
      }

      final invitadosRef = FirebaseFirestore.instance
          .collection('eventos')
          .doc(widget.eventoId)
          .collection('invitados');

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
          detalles.add('Correo repetido dentro del archivo/texto: $email');
          continue;
        }

        if (emailsExistentes.contains(email)) {
          omitidos++;
          detalles.add('Correo ya registrado en este evento: $email');
          continue;
        }

        if (totalActualEvento >= totalInvitados) {
          omitidos++;
          detalles.add(
            'Se alcanzó el límite total de invitados reales. No se registró: $email',
          );
          continue;
        }

        if (usaAnfitriones &&
            (anfitrionSeleccionadoId ?? '').isNotEmpty &&
            totalActualAnfitrion >= anfitrionMaxInvitados) {
          omitidos++;
          detalles.add(
            'El anfitrión $anfitrionSeleccionadoNombre ya alcanzó su límite. No se registró: $email',
          );
          continue;
        }

        final usuarioExistente = await _buscarUsuarioPorCorreo(email);

        String uidUsuario = '';
        bool existeEnSistema = false;

        if (usuarioExistente != null) {
          uidUsuario = (usuarioExistente['uid'] ?? '').toString();
          existeEnSistema = true;
        } else {
          final nuevoUsuarioRef =
              FirebaseFirestore.instance.collection('usuarios').doc();

          await nuevoUsuarioRef.set({
            'empresaId': empresaId,
            'nombre': nombre,
            'email': email,
            'rol': 'invitado',
            'activo': true,
            'createdAt': FieldValue.serverTimestamp(),
          });

          uidUsuario = nuevoUsuarioRef.id;
          existeEnSistema = false;
        }

        final invitadoRef = invitadosRef.doc();

        final qrPayload =
            '{"eventoId":"${widget.eventoId}","invitadoId":"${invitadoRef.id}"}';

        await invitadoRef.set({
          'nombre_invitado': nombre,
          'email_invitado': email,
          'mesa': mesa,
          'usuarioId': uidUsuario,
          'eventoId': widget.eventoId,
          'empresaId': empresaId,
          'anfitrionId': usaAnfitriones ? (anfitrionSeleccionadoId ?? '') : '',
          'anfitrionNombre': usaAnfitriones ? anfitrionSeleccionadoNombre : '',
          'anfitrionUid': usaAnfitriones ? anfitrionUid : '',
          'estado_asistencia': 'pendiente',
          'qr_code': qrPayload,
          'existeEnSistema': existeEnSistema,
          'creadoPorRol': 'admin_txt',
          'esAnfitrion': false,
          'cuentaComoInvitado': true,
          'puedeGestionarInvitados': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

        emailsExistentes.add(email);
        emailsEnArchivo.add(email);
        totalActualEvento++;

        if (usaAnfitriones && (anfitrionSeleccionadoId ?? '').isNotEmpty) {
          totalActualAnfitrion++;
        }

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
        SnackBar(content: Text('Error procesando carga masiva: $e')),
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
    _cargarEvento();
  }

  @override
  void dispose() {
    textoPegadoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loadingEvento) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final anfitrionesStream = FirebaseFirestore.instance
        .collection('anfitriones_evento')
        .where('empresaId', isEqualTo: empresaId)
        .where('eventoId', isEqualTo: widget.eventoId)
        .where('activo', isEqualTo: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Carga masiva TXT'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(
              nombreEvento.isEmpty ? 'Evento' : nombreEvento,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text('Total invitados permitidos: $totalInvitados'),
            if (usaAnfitriones)
              const Text('Este evento permite asignar anfitrión.')
            else
              const Text('Este evento no usa anfitriones.'),
            const SizedBox(height: 16),
            if (usaAnfitriones)
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: anfitrionesStream,
                builder: (context, snapshot) {
                  final docs = snapshot.data?.docs ?? [];

                  if (docs.isEmpty) {
                    return const Text(
                      'Aún no hay anfitriones. Los invitados se guardarán sin anfitrión.',
                    );
                  }

                  return DropdownButtonFormField<String>(
                    value: anfitrionSeleccionadoId ?? '',
                    decoration: const InputDecoration(
                      labelText: 'Seleccionar anfitrión (opcional)',
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: '',
                        child: Text('Sin anfitrión'),
                      ),
                      ...docs.map((doc) {
                        final data = doc.data();
                        final nombre = (data['nombre'] ?? '').toString();
                        final maxInvitados =
                            (data['maxInvitados'] ?? 0).toString();

                        return DropdownMenuItem<String>(
                          value: doc.id,
                          child: Text('$nombre (cupo: $maxInvitados)'),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      if (value == null || value.isEmpty) {
                        setState(() {
                          anfitrionSeleccionadoId = null;
                          anfitrionSeleccionadoNombre = '';
                          anfitrionUid = '';
                          anfitrionMaxInvitados = 0;
                        });
                        return;
                      }

                      final seleccionado =
                          docs.firstWhere((doc) => doc.id == value);
                      final data = seleccionado.data();

                      setState(() {
                        anfitrionSeleccionadoId = seleccionado.id;
                        anfitrionSeleccionadoNombre =
                            (data['nombre'] ?? '').toString();
                        anfitrionUid = (data['uidUsuario'] ?? '').toString();
                        anfitrionMaxInvitados =
                            (data['maxInvitados'] ?? 0) as int;
                      });
                    },
                  );
                },
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: processing ? null : _seleccionarArchivoTxt,
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
              onPressed: processing ? null : _procesarCargaMasiva,
              child: Text(
                processing ? 'Procesando...' : 'Procesar carga masiva',
              ),
            ),
            const SizedBox(height: 24),
            Text('Procesados: $procesados'),
            Text('Guardados: $guardados'),
            Text('Omitidos: $omitidos'),
            const SizedBox(height: 16),
            if (detalles.isNotEmpty)
              const Text(
                'Detalle de resultados:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            const SizedBox(height: 8),
            ...detalles.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(e),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
