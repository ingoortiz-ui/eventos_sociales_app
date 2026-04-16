import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfQrsEventoScreen extends StatefulWidget {
  final String eventoId;
  final String nombreEvento;

  const PdfQrsEventoScreen({
    super.key,
    required this.eventoId,
    required this.nombreEvento,
  });

  @override
  State<PdfQrsEventoScreen> createState() => _PdfQrsEventoScreenState();
}

class _PdfQrsEventoScreenState extends State<PdfQrsEventoScreen> {
  bool loading = false;

  Future<void> generarPdf() async {
    setState(() => loading = true);

    try {
      final eventoDoc = await FirebaseFirestore.instance
          .collection('eventos')
          .doc(widget.eventoId)
          .get();

      final invitadosSnap = await FirebaseFirestore.instance
          .collection('eventos')
          .doc(widget.eventoId)
          .collection('invitados')
          .orderBy('nombre_invitado')
          .get();

      final evento = eventoDoc.data() ?? {};
      final lugar = (evento['lugar'] ?? '').toString();

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          margin: const pw.EdgeInsets.all(24),
          build: (context) {
            final widgets = <pw.Widget>[
              pw.Text(
                'Invitaciones QR del evento',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(widget.nombreEvento),
              if (lugar.isNotEmpty) pw.Text('Lugar: $lugar'),
              pw.SizedBox(height: 20),
            ];

            for (final doc in invitadosSnap.docs) {
              final data = doc.data();
              final nombre = (data['nombre_invitado'] ?? '').toString();
              final mesa = (data['mesa'] ?? '').toString();
              final invitadoDe = (data['invitadoDe'] ?? '').toString();
              final qrData = (data['qr_code'] ?? '').toString();

              widgets.add(
                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 16),
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(width: 1),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(8),
                    ),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              nombre,
                              style: pw.TextStyle(
                                fontSize: 16,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.SizedBox(height: 6),
                            pw.Text('Mesa: $mesa'),
                            if (invitadoDe.isNotEmpty)
                              pw.Text('Invitado de: $invitadoDe'),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 16),
                      pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: qrData,
                        width: 110,
                        height: 110,
                      ),
                    ],
                  ),
                ),
              );
            }

            return widgets;
          },
        ),
      );

      final bytes = await pdf.save();

      await Printing.sharePdf(
        bytes: bytes,
        filename: 'qrs_${widget.nombreEvento.replaceAll(' ', '_')}.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generando PDF: $e')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF de QRs del evento'),
      ),
      body: Center(
        child: ElevatedButton.icon(
          onPressed: loading ? null : generarPdf,
          icon: const Icon(Icons.picture_as_pdf),
          label: Text(loading ? 'Generando...' : 'Generar y compartir PDF'),
        ),
      ),
    );
  }
}
