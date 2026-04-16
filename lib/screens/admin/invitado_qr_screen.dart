import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

class InvitadoQrScreen extends StatefulWidget {
  final String nombre;
  final String mesa;
  final String invitadoDe;
  final String qrData;

  const InvitadoQrScreen({
    super.key,
    required this.nombre,
    required this.mesa,
    required this.invitadoDe,
    required this.qrData,
  });

  @override
  State<InvitadoQrScreen> createState() => _InvitadoQrScreenState();
}

class _InvitadoQrScreenState extends State<InvitadoQrScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _working = false;

  Future<File> _saveBytesToTempFile({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<Uint8List?> _captureQrCard() async {
    return _screenshotController.capture(
      delay: const Duration(milliseconds: 200),
      pixelRatio: 2.0,
    );
  }

  Future<void> _compartirComoImagen() async {
    if (widget.qrData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este invitado no tiene QR guardado')),
      );
      return;
    }

    setState(() => _working = true);

    try {
      final bytes = await _captureQrCard();
      if (bytes == null) {
        throw Exception('No se pudo generar la imagen del QR');
      }

      final safeName = widget.nombre.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
      final file = await _saveBytesToTempFile(
        bytes: bytes,
        fileName: 'qr_$safeName.png',
      );

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'QR de ${widget.nombre} - Mesa ${widget.mesa}',
        subject: 'QR de invitado',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error compartiendo imagen: $e')),
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _compartirComoPdf() async {
    if (widget.qrData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este invitado no tiene QR guardado')),
      );
      return;
    }

    setState(() => _working = true);

    try {
      final pngBytes = await _captureQrCard();
      if (pngBytes == null) {
        throw Exception('No se pudo generar la imagen base del PDF');
      }

      final pdf = pw.Document();
      final image = pw.MemoryImage(pngBytes);

      pdf.addPage(
        pw.Page(
          build: (context) {
            return pw.Center(
              child: pw.Container(
                width: 400,
                padding: const pw.EdgeInsets.all(24),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 1),
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(12)),
                ),
                child: pw.Column(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Text(
                      'Invitación del evento',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 16),
                    pw.Text(
                      widget.nombre,
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text('Mesa: ${widget.mesa}'),
                    if (widget.invitadoDe.isNotEmpty)
                      pw.Text('Invitado de: ${widget.invitadoDe}'),
                    pw.SizedBox(height: 20),
                    pw.Image(image, width: 220, height: 320),
                  ],
                ),
              ),
            );
          },
        ),
      );

      final bytes = await pdf.save();
      final safeName = widget.nombre.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
      final file = await _saveBytesToTempFile(
        bytes: bytes,
        fileName: 'qr_$safeName.pdf',
      );

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'PDF del QR de ${widget.nombre}',
        subject: 'QR de invitado en PDF',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error compartiendo PDF: $e')),
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _imprimirPdf() async {
    if (widget.qrData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este invitado no tiene QR guardado')),
      );
      return;
    }

    setState(() => _working = true);

    try {
      final pngBytes = await _captureQrCard();
      if (pngBytes == null) {
        throw Exception('No se pudo generar la imagen base del PDF');
      }

      final pdf = pw.Document();
      final image = pw.MemoryImage(pngBytes);

      pdf.addPage(
        pw.Page(
          build: (context) => pw.Center(
            child: pw.Image(image, width: 350),
          ),
        ),
      );

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'qr_${widget.nombre}.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generando PDF: $e')),
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tieneQr = widget.qrData.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('QR del invitado'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Screenshot(
              controller: _screenshotController,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      widget.nombre,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Mesa: ${widget.mesa}',
                      style: const TextStyle(color: Colors.black),
                    ),
                    if (widget.invitadoDe.isNotEmpty)
                      Text(
                        'Invitado de: ${widget.invitadoDe}',
                        style: const TextStyle(color: Colors.black),
                      ),
                    const SizedBox(height: 20),
                    if (tieneQr)
                      QrImageView(
                        data: widget.qrData,
                        version: QrVersions.auto,
                        size: 240,
                        backgroundColor: Colors.white,
                      )
                    else
                      const Text(
                        'Este invitado no tiene QR guardado',
                        style: TextStyle(color: Colors.black),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (tieneQr) SelectableText(widget.qrData),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _working || !tieneQr ? null : _compartirComoImagen,
              icon: const Icon(Icons.image),
              label: Text(_working ? 'Procesando...' : 'Compartir como imagen'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _working || !tieneQr ? null : _compartirComoPdf,
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Compartir como PDF'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _working || !tieneQr ? null : _imprimirPdf,
              icon: const Icon(Icons.print),
              label: const Text('Generar / compartir PDF'),
            ),
          ],
        ),
      ),
    );
  }
}
