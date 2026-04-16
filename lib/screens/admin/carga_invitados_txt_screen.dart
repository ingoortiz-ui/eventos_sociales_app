import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
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
  final textoController = TextEditingController();

  bool parsing = false;
  bool importing = false;
  String status = 'Pega aquí el contenido del TXT';

  List<Map<String, String>> validos = [];
  List<String> invalidos = [];
  List<String> duplicadosInternos = [];
  List<String> duplicadosEvento = [];

  String _normalizar(String value) => value.trim().toLowerCase();

  String _claveNombreMesa(String nombre, String mesa) {
    return '${_normalizar(nombre)}|${_normalizar(mesa)}';
  }

  Future<void> procesarTexto() async {
    final content = textoController.text.trim();

    if (content.isEmpty) {
      setState(() {
        validos = [];
        invalidos = [];
        duplicadosInternos = [];
        duplicadosEvento = [];
        status = 'No hay contenido para procesar';
      });
      return;
    }

    setState(() {
      parsing = true;
      status = 'Procesando texto...';
      validos = [];
      invalidos = [];
      duplicadosInternos = [];
      duplicadosEvento = [];
    });

    try {
      final invitadosExistentesSnap = await FirebaseFirestore.instance
          .collection('eventos')
          .doc(widget.eventoId)
          .collection('invitados')
          .get();

      final correosEvento = <String>{};
      final clavesNombreMesaEvento = <String>{};

      for (final doc in invitadosExistentesSnap.docs) {
        final data = doc.data();
        final email = _normalizar((data['email_invitado'] ?? '').toString());
        final nombre = (data['nombre_invitado'] ?? '').toString();
        final mesa = (data['mesa'] ?? '').toString();

        if (email.isNotEmpty) {
          correosEvento.add(email);
        }

        if (nombre.isNotEmpty && mesa.isNotEmpty) {
          clavesNombreMesaEvento.add(_claveNombreMesa(nombre, mesa));
        }
      }

      final lines = content
          .split(RegExp(r'\r?\n'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      if (lines.isEmpty) {
        setState(() {
          parsing = false;
          status = 'El texto está vacío';
        });
        return;
      }

      final firstLine = lines.first.toLowerCase();
      final dataLines = <String>[];

      if (firstLine.contains('nombre') &&
          firstLine.contains('correo') &&
          firstLine.contains('mesa')) {
        dataLines.addAll(lines.skip(1));
      } else {
        dataLines.addAll(lines);
      }

      final nuevosValidos = <Map<String, String>>[];
      final nuevosInvalidos = <String>[];
      final nuevosDuplicadosInternos = <String>[];
      final nuevosDuplicadosEvento = <String>[];

      final correosArchivo = <String>{};
      final clavesNombreMesaArchivo = <String>{};

      for (int i = 0; i < dataLines.length; i++) {
        final line = dataLines[i];
        final lineaVisible = i + 1;
        final parts = line.split('|').map((e) => e.trim()).toList();

        if (parts.length < 3) {
          nuevosInvalidos.add('Línea $lineaVisible: formato inválido');
          continue;
        }

        final nombre = parts[0];
        final email = _normalizar(parts[1]);
        final mesa = parts[2];
        final invitadoDe = parts.length >= 4 ? parts[3] : '';

        if (nombre.isEmpty || email.isEmpty || mesa.isEmpty) {
          nuevosInvalidos.add(
            'Línea $lineaVisible: faltan nombre, correo o mesa',
          );
          continue;
        }

        final claveCorreo = email;
        final claveNombreMesa = _claveNombreMesa(nombre, mesa);

        final duplicadoInternoCorreo = correosArchivo.contains(claveCorreo);
        final duplicadoInternoNombreMesa =
            clavesNombreMesaArchivo.contains(claveNombreMesa);

        if (duplicadoInternoCorreo || duplicadoInternoNombreMesa) {
          nuevosDuplicadosInternos.add(
            'Línea $lineaVisible: $nombre | $email | mesa $mesa',
          );
          continue;
        }

        final duplicadoEventoCorreo = correosEvento.contains(claveCorreo);
        final duplicadoEventoNombreMesa =
            clavesNombreMesaEvento.contains(claveNombreMesa);

        if (duplicadoEventoCorreo || duplicadoEventoNombreMesa) {
          nuevosDuplicadosEvento.add(
            'Línea $lineaVisible: $nombre | $email | mesa $mesa',
          );
          continue;
        }

        correosArchivo.add(claveCorreo);
        clavesNombreMesaArchivo.add(claveNombreMesa);

        nuevosValidos.add({
          'nombre_invitado': nombre,
          'email_invitado': email,
          'mesa': mesa,
          'invitadoDe': invitadoDe,
        });
      }

      setState(() {
        validos = nuevosValidos;
        invalidos = nuevosInvalidos;
        duplicadosInternos = nuevosDuplicadosInternos;
        duplicadosEvento = nuevosDuplicadosEvento;
        parsing = false;
        status = 'Validación completa: ${nuevosValidos.length} válido(s), '
            '${nuevosInvalidos.length} inválido(s), '
            '${nuevosDuplicadosInternos.length} duplicado(s) internos, '
            '${nuevosDuplicadosEvento.length} duplicado(s) en evento';
      });
    } catch (e) {
      setState(() {
        parsing = false;
        validos = [];
        invalidos = [];
        duplicadosInternos = [];
        duplicadosEvento = [];
        status = 'Error procesando texto: $e';
      });
    }
  }

  Future<void> importarValidos() async {
    if (validos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay invitados válidos para importar')),
      );
      return;
    }

    setState(() {
      importing = true;
      status = 'Importando invitados válidos...';
    });

    try {
      final invitadosRef = FirebaseFirestore.instance
          .collection('eventos')
          .doc(widget.eventoId)
          .collection('invitados');

      final batch = FirebaseFirestore.instance.batch();

      for (final invitado in validos) {
        final docRef = invitadosRef.doc();

        final qrPayload = jsonEncode({
          'eventoId': widget.eventoId,
          'invitadoId': docRef.id,
        });

        batch.set(docRef, {
          'nombre_invitado': invitado['nombre_invitado'],
          'email_invitado': invitado['email_invitado'],
          'mesa': invitado['mesa'],
          'invitadoDe': invitado['invitadoDe'] ?? '',
          'estado_asistencia': 'pendiente',
          'qr_code': qrPayload,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      final totalImportados = validos.length;

      await batch.commit();

      setState(() {
        importing = false;
        status = 'Importación completada: $totalImportados invitado(s)';
        textoController.clear();
        validos = [];
        invalidos = [];
        duplicadosInternos = [];
        duplicadosEvento = [];
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Se importaron $totalImportados invitado(s) válidos con QR automático',
          ),
        ),
      );
    } catch (e) {
      setState(() {
        importing = false;
        status = 'Error importando invitados: $e';
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error importando invitados: $e')),
      );
    }
  }

  Widget _bloqueLista(
    String titulo,
    List<String> items, {
    Color? colorTitulo,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$titulo (${items.length})',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: colorTitulo,
          ),
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          const Text('Sin elementos')
        else
          ...items.take(10).map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(e),
                ),
              ),
        if (items.length > 10) Text('... y ${items.length - 10} más'),
      ],
    );
  }

  Widget _bloqueValidos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Válidos (${validos.length})',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 8),
        if (validos.isEmpty)
          const Text('Sin elementos')
        else
          ...validos.take(10).map(
                (inv) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(inv['nombre_invitado'] ?? ''),
                  subtitle: Text(
                    '${inv['email_invitado'] ?? ''} • Mesa ${inv['mesa'] ?? ''}',
                  ),
                  trailing: Text(inv['invitadoDe'] ?? ''),
                ),
              ),
        if (validos.length > 10) Text('... y ${validos.length - 10} más'),
      ],
    );
  }

  @override
  void dispose() {
    textoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalProcesados = validos.length +
        invalidos.length +
        duplicadosInternos.length +
        duplicadosEvento.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Carga masiva por TXT'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            SelectableText('Evento ID: ${widget.eventoId}'),
            const SizedBox(height: 16),
            const Text(
              'Formato esperado:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const SelectableText(
              'Nombre Invitado|Correo Invitado|Numero Mesa|Invitado De\n'
              'Juan Pérez|juan@evento.com|4|Ana\n'
              'María López|maria@evento.com|4|Ana\n'
              'Carlos Ruiz|carlos@evento.com|7|',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: textoController,
              minLines: 8,
              maxLines: 14,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Pega aquí el contenido del TXT',
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: parsing || importing ? null : procesarTexto,
              child:
                  Text(parsing ? 'Validando...' : 'Validar antes de importar'),
            ),
            const SizedBox(height: 12),
            Text(status),
            const SizedBox(height: 12),
            Text('Total revisado: $totalProcesados'),
            const SizedBox(height: 24),
            _bloqueValidos(),
            const SizedBox(height: 24),
            _bloqueLista(
              'Inválidos',
              invalidos,
              colorTitulo: Colors.red,
            ),
            const SizedBox(height: 24),
            _bloqueLista(
              'Duplicados dentro del texto',
              duplicadosInternos,
              colorTitulo: Colors.orange,
            ),
            const SizedBox(height: 24),
            _bloqueLista(
              'Duplicados ya existentes en el evento',
              duplicadosEvento,
              colorTitulo: Colors.deepOrange,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: importing || validos.isEmpty ? null : importarValidos,
              child: Text(
                importing
                    ? 'Importando...'
                    : 'Importar solo válidos y generar QR',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
