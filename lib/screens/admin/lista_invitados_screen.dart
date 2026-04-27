import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import 'editar_invitado_admin_screen.dart';

class ListaInvitadosScreen extends StatelessWidget {
  final String eventoId;
  final String? anfitrionIdFiltro;
  final String? titulo;

  const ListaInvitadosScreen({
    super.key,
    required this.eventoId,
    this.anfitrionIdFiltro,
    this.titulo,
  });

  Future<String> _nombreEvento() async {
    final doc = await FirebaseFirestore.instance
        .collection('eventos')
        .doc(eventoId)
        .get();
    final data = doc.data() ?? {};
    return (data['nombreEvento'] ?? 'Evento').toString();
  }

  String _nombreArchivoSeguro(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .toLowerCase();
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

  Future<void> _compartirQrComoImagen({
    required BuildContext context,
    required String qr,
    required String nombre,
    required String evento,
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
        ..writeln('Evento: $evento')
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
        subject: 'QR de acceso - $evento',
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error compartiendo QR: $e')),
      );
    }
  }

  Future<void> _compartirPdfQrs({
    required BuildContext context,
    required String nombreEvento,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    required bool soloInvitados,
  }) async {
    try {
      final registros = docs.where((doc) {
        final data = doc.data();
        final esAnfitrion = data['esAnfitrion'] == true;
        final qr = (data['qr_code'] ?? '').toString();

        if (qr.trim().isEmpty) return false;
        if (soloInvitados && esAnfitrion) return false;

        return true;
      }).toList();

      if (registros.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay QRs para generar PDF')),
        );
        return;
      }

      final pdf = pw.Document();

      for (final doc in registros) {
        final data = doc.data();

        final nombre = (data['nombre_invitado'] ?? '').toString();
        final email = (data['email_invitado'] ?? '').toString();
        final mesa = (data['mesa'] ?? '').toString();
        final qr = (data['qr_code'] ?? '').toString();
        final esAnfitrion = data['esAnfitrion'] == true;
        final anfitrionNombre = (data['anfitrionNombre'] ?? '').toString();

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
                      pw.SizedBox(height: 18),
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
                      pw.SizedBox(height: 8),
                      pw.Text(
                        esAnfitrion ? 'Tipo: Anfitrión' : 'Tipo: Invitado',
                      ),
                      if (anfitrionNombre.isNotEmpty && !esAnfitrion)
                        pw.Text('Anfitrión: $anfitrionNombre'),
                      pw.SizedBox(height: 22),
                      pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: qr,
                        width: 190,
                        height: 190,
                      ),
                      pw.SizedBox(height: 18),
                      pw.Text('Presenta este QR al ingresar.'),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      }

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: soloInvitados
            ? 'qrs_invitados_${_nombreArchivoSeguro(nombreEvento)}.pdf'
            : 'qrs_todos_${_nombreArchivoSeguro(nombreEvento)}.pdf',
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generando PDF: $e')),
      );
    }
  }

  Future<void> _eliminarInvitado(
    BuildContext context,
    String invitadoId,
    bool esAnfitrion,
  ) async {
    if (esAnfitrion) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'El QR de anfitrión se elimina desde Gestión de anfitriones',
          ),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar invitado'),
        content: const Text('¿Seguro que deseas eliminar este invitado?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('eventos')
          .doc(eventoId)
          .collection('invitados')
          .doc(invitadoId)
          .delete();

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitado eliminado')),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error eliminando: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('eventos')
        .doc(eventoId)
        .collection('invitados');

    if ((anfitrionIdFiltro ?? '').isNotEmpty) {
      query = query.where('anfitrionId', isEqualTo: anfitrionIdFiltro);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(titulo ?? 'Lista de invitados'),
      ),
      body: FutureBuilder<String>(
        future: _nombreEvento(),
        builder: (context, eventoSnap) {
          final nombreEvento = eventoSnap.data ?? 'Evento';

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: query.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return const Center(
                  child: Text('No hay registros'),
                );
              }

              final anfitriones = docs.where((d) {
                return d.data()['esAnfitrion'] == true;
              }).toList();

              final invitados = docs.where((d) {
                return d.data()['esAnfitrion'] != true;
              }).toList();

              return ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _compartirPdfQrs(
                            context: context,
                            nombreEvento: nombreEvento,
                            docs: docs,
                            soloInvitados: true,
                          ),
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('PDF invitados'),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _compartirPdfQrs(
                            context: context,
                            nombreEvento: nombreEvento,
                            docs: docs,
                            soloInvitados: false,
                          ),
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('PDF todos'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  if (anfitriones.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'ANFITRIONES',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ...anfitriones.map((doc) {
                      final data = doc.data();

                      final nombre = (data['nombre_invitado'] ?? '').toString();
                      final email = (data['email_invitado'] ?? '').toString();
                      final mesa = (data['mesa'] ?? '').toString();
                      final estado =
                          (data['estado_asistencia'] ?? '').toString();
                      final qr = (data['qr_code'] ?? '').toString();

                      return ListTile(
                        leading: const Icon(Icons.star, color: Colors.orange),
                        title: Text(nombre),
                        subtitle: Text('$email\nEstado: $estado'),
                        isThreeLine: true,
                        trailing: IconButton(
                          icon: const Icon(Icons.share),
                          onPressed: () {
                            _compartirQrComoImagen(
                              context: context,
                              qr: qr,
                              nombre: nombre,
                              evento: nombreEvento,
                              mesa: mesa,
                            );
                          },
                        ),
                      );
                    }),
                    const Divider(),
                  ],
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'INVITADOS',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (invitados.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('No hay invitados registrados'),
                    ),
                  ...invitados.map((doc) {
                    final data = doc.data();

                    final nombre = (data['nombre_invitado'] ?? '').toString();
                    final email = (data['email_invitado'] ?? '').toString();
                    final mesa = (data['mesa'] ?? '').toString();
                    final estado = (data['estado_asistencia'] ?? '').toString();
                    final anfitrion =
                        (data['anfitrionNombre'] ?? '').toString();
                    final qr = (data['qr_code'] ?? '').toString();

                    return ListTile(
                      title: Text(nombre),
                      subtitle: Text(
                        '$email\n'
                        'Mesa: $mesa\n'
                        'Estado: $estado\n'
                        'Anfitrión: ${anfitrion.isEmpty ? "Sin anfitrión" : anfitrion}',
                      ),
                      isThreeLine: true,
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'compartir') {
                            _compartirQrComoImagen(
                              context: context,
                              qr: qr,
                              nombre: nombre,
                              evento: nombreEvento,
                              mesa: mesa,
                            );
                          } else if (value == 'editar') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EditarInvitadoAdminScreen(
                                  eventoId: eventoId,
                                  invitadoId: doc.id,
                                ),
                              ),
                            );
                          } else if (value == 'eliminar') {
                            _eliminarInvitado(context, doc.id, false);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'compartir',
                            child: Text('Compartir QR imagen'),
                          ),
                          PopupMenuItem(
                            value: 'editar',
                            child: Text('Editar'),
                          ),
                          PopupMenuItem(
                            value: 'eliminar',
                            child: Text('Eliminar'),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
