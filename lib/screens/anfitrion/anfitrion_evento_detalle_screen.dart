import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../invitado/galeria_evento_screen.dart';
import '../invitado/subir_foto_screen.dart';
import 'anfitrion_carga_invitados_txt_screen.dart';
import 'anfitrion_crear_invitado_screen.dart';
import 'anfitrion_editar_invitado_screen.dart';

class AnfitrionEventoDetalleScreen extends StatelessWidget {
  final String eventoId;
  final String empresaId;
  final String anfitrionId;

  const AnfitrionEventoDetalleScreen({
    super.key,
    required this.eventoId,
    required this.empresaId,
    required this.anfitrionId,
  });

  Future<Map<String, dynamic>> _cargarTodo() async {
    final eventoDoc = await FirebaseFirestore.instance
        .collection('eventos')
        .doc(eventoId)
        .get();

    final anfitrionDoc = await FirebaseFirestore.instance
        .collection('anfitriones_evento')
        .doc(anfitrionId)
        .get();

    final invitadoEspejoSnap = await FirebaseFirestore.instance
        .collection('eventos')
        .doc(eventoId)
        .collection('invitados')
        .where('anfitrionId', isEqualTo: anfitrionId)
        .where('esAnfitrion', isEqualTo: true)
        .limit(1)
        .get();

    return {
      'evento': eventoDoc.data() ?? {},
      'anfitrion': anfitrionDoc.data() ?? {},
      'invitadoEspejoId': invitadoEspejoSnap.docs.isNotEmpty
          ? invitadoEspejoSnap.docs.first.id
          : '',
      'invitadoEspejo': invitadoEspejoSnap.docs.isNotEmpty
          ? invitadoEspejoSnap.docs.first.data()
          : <String, dynamic>{},
    };
  }

  DateTime? _parseFecha(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();

    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }

    return null;
  }

  bool _puedeEditar(Map<String, dynamic> evento) {
    final estado = (evento['estado'] ?? 'abierto').toString();
    if (estado == 'cerrado' || estado == 'archivado') return false;

    final fin = _parseFecha(evento['fechaHoraFin']);
    if (fin != null && DateTime.now().isAfter(fin)) return false;

    return true;
  }

  bool _puedeSubirFotos(
      Map<String, dynamic> evento, Map<String, dynamic> espejo) {
    final estadoAsistencia =
        (espejo['estado_asistencia'] ?? 'pendiente').toString();
    final estado = (evento['estado'] ?? '').toString();

    if (estado == 'cerrado' || estado == 'archivado') return false;
    return estadoAsistencia == 'ingresado';
  }

  String _formatearHorario(Map<String, dynamic> evento) {
    final inicio = _parseFecha(evento['fechaHoraInicio']);
    final fin = _parseFecha(evento['fechaHoraFin']);

    if (inicio == null || fin == null) return 'Horario no definido';

    String two(int n) => n.toString().padLeft(2, '0');

    return '${inicio.day}/${inicio.month}/${inicio.year} '
        '${two(inicio.hour)}:${two(inicio.minute)} - '
        '${two(fin.hour)}:${two(fin.minute)}';
  }

  Future<Uint8List?> _generarQrPng(String qr) async {
    final painter = QrPainter(
      data: qr,
      version: QrVersions.auto,
      gapless: true,
      color: Colors.black,
      emptyColor: Colors.white,
    );

    final byteData = await painter.toImageData(
      900,
      format: ui.ImageByteFormat.png,
    );

    return byteData?.buffer.asUint8List();
  }

  String _nombreArchivoSeguro(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .toLowerCase();
  }

  Future<void> _compartirQrComoImagen({
    required BuildContext context,
    required String qr,
    required String nombre,
    required String nombreEvento,
    required String mesa,
  }) async {
    try {
      if (qr.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Este registro no tiene QR')),
        );
        return;
      }

      final bytes = await _generarQrPng(qr);

      if (bytes == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo generar la imagen QR')),
        );
        return;
      }

      final texto = StringBuffer()
        ..writeln('QR de acceso')
        ..writeln('Evento: $nombreEvento')
        ..writeln('Nombre: $nombre');

      if (mesa.trim().isNotEmpty) {
        texto.writeln('Mesa: $mesa');
      }

      await Share.shareXFiles(
        [
          XFile.fromData(
            bytes,
            mimeType: 'image/png',
            name: 'qr_${_nombreArchivoSeguro(nombre)}.png',
          ),
        ],
        text: texto.toString(),
        subject: 'QR de acceso - $nombreEvento',
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error compartiendo QR: $e')),
      );
    }
  }

  Future<void> _compartirPdfQrsInvitados({
    required BuildContext context,
    required String nombreEvento,
    required String nombreAnfitrion,
  }) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('eventos')
          .doc(eventoId)
          .collection('invitados')
          .where('anfitrionId', isEqualTo: anfitrionId)
          .where('esAnfitrion', isEqualTo: false)
          .get();

      if (snap.docs.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay invitados para generar PDF')),
        );
        return;
      }

      final pdf = pw.Document();

      for (final doc in snap.docs) {
        final data = doc.data();

        final nombre = (data['nombre_invitado'] ?? '').toString();
        final email = (data['email_invitado'] ?? '').toString();
        final mesa = (data['mesa'] ?? '').toString();
        final qr = (data['qr_code'] ?? '').toString();

        if (qr.trim().isEmpty) continue;

        pdf.addPage(
          pw.Page(
            build: (_) {
              return pw.Center(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(28),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(width: 1.2),
                    borderRadius: pw.BorderRadius.circular(14),
                  ),
                  child: pw.Column(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.Text(
                        'Invitación del evento',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 10),
                      pw.Text(
                        nombreEvento,
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 20),
                      pw.Text(
                        nombre,
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      if (email.isNotEmpty) pw.Text(email),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        mesa.isEmpty ? 'Mesa: sin asignar' : 'Mesa: $mesa',
                        style: const pw.TextStyle(fontSize: 16),
                      ),
                      pw.SizedBox(height: 22),
                      pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: qr,
                        width: 190,
                        height: 190,
                      ),
                      pw.SizedBox(height: 18),
                      pw.Text('Presenta este QR al ingresar.'),
                      pw.SizedBox(height: 8),
                      pw.Text('Anfitrión: $nombreAnfitrion'),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      }

      final bytes = await pdf.save();

      await Printing.sharePdf(
        bytes: bytes,
        filename: 'qrs_${_nombreArchivoSeguro(nombreEvento)}.pdf',
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generando PDF: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final invitadosStream = FirebaseFirestore.instance
        .collection('eventos')
        .doc(eventoId)
        .collection('invitados')
        .where('anfitrionId', isEqualTo: anfitrionId)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi evento'),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _cargarTodo(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error cargando detalle: ${snapshot.error}'),
              ),
            );
          }

          final data = snapshot.data ?? {};
          final evento = (data['evento'] ?? {}) as Map<String, dynamic>;
          final anfitrion = (data['anfitrion'] ?? {}) as Map<String, dynamic>;
          final invitadoEspejoId = (data['invitadoEspejoId'] ?? '').toString();
          final espejo = (data['invitadoEspejo'] ?? {}) as Map<String, dynamic>;

          final nombreEvento = (evento['nombreEvento'] ?? '').toString();
          final lugar = (evento['lugar'] ?? '').toString();
          final estado = (evento['estado'] ?? '').toString();
          final horario = _formatearHorario(evento);
          final estadoAsistencia =
              (espejo['estado_asistencia'] ?? 'pendiente').toString();

          final maxInvitados = (anfitrion['maxInvitados'] ?? 0) as int;
          final nombreAnfitrion = (anfitrion['nombre'] ?? '').toString();

          final editable = _puedeEditar(evento);
          final puedeSubirFotos = _puedeSubirFotos(evento, espejo);

          final qrPropio = (espejo['qr_code'] ?? '').toString();
          final mesaPropia = (espejo['mesa'] ?? 'ANFITRION').toString();
          final nombrePropio =
              (espejo['nombre_invitado'] ?? nombreAnfitrion).toString();

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    nombreEvento,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Lugar: $lugar'),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Anfitrión: $nombreAnfitrion'),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Horario: $horario'),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Estado: $estado'),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Mi acceso: $estadoAsistencia'),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Cupo asignado: $maxInvitados'),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton(
                      onPressed: editable
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AnfitrionCrearInvitadoScreen(
                                    eventoId: eventoId,
                                    empresaId: empresaId,
                                    anfitrionId: anfitrionId,
                                  ),
                                ),
                              );
                            }
                          : null,
                      child: const Text('Agregar invitado'),
                    ),
                    ElevatedButton(
                      onPressed: editable
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      AnfitrionCargaInvitadosTxtScreen(
                                    eventoId: eventoId,
                                    empresaId: empresaId,
                                    anfitrionId: anfitrionId,
                                  ),
                                ),
                              );
                            }
                          : null,
                      child: const Text('Carga TXT'),
                    ),
                    ElevatedButton(
                      onPressed: invitadoEspejoId.isEmpty
                          ? null
                          : () => _compartirQrComoImagen(
                                context: context,
                                qr: qrPropio,
                                nombre: nombrePropio,
                                nombreEvento: nombreEvento,
                                mesa: mesaPropia,
                              ),
                      child: const Text('Compartir mi QR'),
                    ),
                    ElevatedButton(
                      onPressed: () => _compartirPdfQrsInvitados(
                        context: context,
                        nombreEvento: nombreEvento,
                        nombreAnfitrion: nombreAnfitrion,
                      ),
                      child: const Text('PDF QRs invitados'),
                    ),
                    ElevatedButton(
                      onPressed: invitadoEspejoId.isEmpty
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => GaleriaEventoScreen(
                                    eventoId: eventoId,
                                    invitadoId: invitadoEspejoId,
                                    esAnfitrion: true,
                                    anfitrionId: anfitrionId,
                                  ),
                                ),
                              );
                            },
                      child: const Text('Ver fotos'),
                    ),
                    ElevatedButton(
                      onPressed: puedeSubirFotos && invitadoEspejoId.isNotEmpty
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SubirFotoScreen(
                                    eventoId: eventoId,
                                    invitadoId: invitadoEspejoId,
                                  ),
                                ),
                              );
                            }
                          : null,
                      child: const Text('Subir fotos'),
                    ),
                  ],
                ),
                if (!puedeSubirFotos)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Podrás subir fotos cuando tu acceso esté marcado como ingresado.',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                if (!editable)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'Este evento ya no permite modificaciones. Solo consulta de historial.',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                const SizedBox(height: 16),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: invitadosStream,
                    builder: (context, invitadoSnap) {
                      if (invitadoSnap.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (invitadoSnap.hasError) {
                        return Center(
                          child: Text(
                            'Error cargando invitados: ${invitadoSnap.error}',
                          ),
                        );
                      }

                      final docs = invitadoSnap.data?.docs ?? [];

                      docs.sort((a, b) {
                        final aTs = a.data()['createdAt'];
                        final bTs = b.data()['createdAt'];

                        if (aTs is Timestamp && bTs is Timestamp) {
                          return bTs.compareTo(aTs);
                        }

                        return 0;
                      });

                      final invitadosReales = docs.where((doc) {
                        return doc.data()['esAnfitrion'] != true;
                      }).toList();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Invitados registrados: ${invitadosReales.length} / $maxInvitados',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: docs.isEmpty
                                ? const Center(
                                    child:
                                        Text('Aún no has registrado invitados'),
                                  )
                                : ListView.separated(
                                    itemCount: docs.length,
                                    separatorBuilder: (_, __) =>
                                        const Divider(),
                                    itemBuilder: (context, index) {
                                      final doc = docs[index];
                                      final d = doc.data();

                                      final nombre =
                                          (d['nombre_invitado'] ?? '')
                                              .toString();
                                      final email = (d['email_invitado'] ?? '')
                                          .toString();
                                      final mesa = (d['mesa'] ?? '').toString();
                                      final esAnfitrion =
                                          d['esAnfitrion'] == true;
                                      final estadoInvitado =
                                          (d['estado_asistencia'] ?? '')
                                              .toString();
                                      final qr =
                                          (d['qr_code'] ?? '').toString();

                                      return ListTile(
                                        title: Text(nombre),
                                        subtitle: Text(
                                          '$email\n'
                                          'Mesa: $mesa\n'
                                          'Estado: $estadoInvitado'
                                          '${esAnfitrion ? "\nTipo: Anfitrión" : ""}',
                                        ),
                                        isThreeLine: true,
                                        trailing: PopupMenuButton<String>(
                                          onSelected: (value) async {
                                            if (value == 'compartir') {
                                              await _compartirQrComoImagen(
                                                context: context,
                                                qr: qr,
                                                nombre: nombre,
                                                nombreEvento: nombreEvento,
                                                mesa: mesa,
                                              );
                                            }

                                            if (value == 'editar') {
                                              if (!editable || esAnfitrion)
                                                return;

                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      AnfitrionEditarInvitadoScreen(
                                                    eventoId: eventoId,
                                                    invitadoId: doc.id,
                                                    anfitrionId: anfitrionId,
                                                    empresaId: empresaId,
                                                  ),
                                                ),
                                              );
                                            }

                                            if (value == 'eliminar') {
                                              if (!editable || esAnfitrion)
                                                return;

                                              final confirm =
                                                  await showDialog<bool>(
                                                context: context,
                                                builder: (_) => AlertDialog(
                                                  title: const Text(
                                                    'Eliminar invitado',
                                                  ),
                                                  content: const Text(
                                                    '¿Seguro que deseas eliminar este invitado?',
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                        context,
                                                        false,
                                                      ),
                                                      child: const Text(
                                                          'Cancelar'),
                                                    ),
                                                    ElevatedButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                        context,
                                                        true,
                                                      ),
                                                      child: const Text(
                                                          'Eliminar'),
                                                    ),
                                                  ],
                                                ),
                                              );

                                              if (confirm == true) {
                                                await FirebaseFirestore.instance
                                                    .collection('eventos')
                                                    .doc(eventoId)
                                                    .collection('invitados')
                                                    .doc(doc.id)
                                                    .delete();
                                              }
                                            }
                                          },
                                          itemBuilder: (_) => [
                                            const PopupMenuItem(
                                              value: 'compartir',
                                              child:
                                                  Text('Compartir QR imagen'),
                                            ),
                                            if (editable && !esAnfitrion)
                                              const PopupMenuItem(
                                                value: 'editar',
                                                child: Text('Editar'),
                                              ),
                                            if (editable && !esAnfitrion)
                                              const PopupMenuItem(
                                                value: 'eliminar',
                                                child: Text('Eliminar'),
                                              ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
