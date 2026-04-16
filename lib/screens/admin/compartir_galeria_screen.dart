import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

class CompartirGaleriaScreen extends StatefulWidget {
  final String eventoId;
  final String nombreEvento;

  const CompartirGaleriaScreen({
    super.key,
    required this.eventoId,
    required this.nombreEvento,
  });

  @override
  State<CompartirGaleriaScreen> createState() => _CompartirGaleriaScreenState();
}

class _CompartirGaleriaScreenState extends State<CompartirGaleriaScreen> {
  bool loading = true;
  bool saving = false;

  bool galeriaCompartible = false;
  DateTime? fechaExpiracion;
  String tokenGaleria = '';

  String generarToken() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(
      24,
      (index) => chars[random.nextInt(chars.length)],
    ).join();
  }

  Future<void> cargarConfiguracion() async {
    final doc = await FirebaseFirestore.instance
        .collection('eventos')
        .doc(widget.eventoId)
        .get();

    final data = doc.data() ?? {};

    final ts = data['fechaExpiracionGaleria'];
    if (ts is Timestamp) {
      fechaExpiracion = ts.toDate();
    }

    setState(() {
      galeriaCompartible = data['galeriaCompartible'] == true;
      tokenGaleria = (data['tokenGaleria'] ?? '').toString();
      loading = false;
    });
  }

  Future<void> seleccionarFechaExpiracion() async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          fechaExpiracion ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2035),
    );

    if (picked != null) {
      setState(() => fechaExpiracion = picked);
    }
  }

  String get fechaTexto {
    if (fechaExpiracion == null) return 'Sin fecha definida';
    return '${fechaExpiracion!.day.toString().padLeft(2, '0')}/'
        '${fechaExpiracion!.month.toString().padLeft(2, '0')}/'
        '${fechaExpiracion!.year}';
  }

  Future<void> guardarConfiguracion() async {
    setState(() => saving = true);

    try {
      final token = tokenGaleria.isEmpty ? generarToken() : tokenGaleria;

      await FirebaseFirestore.instance
          .collection('eventos')
          .doc(widget.eventoId)
          .update({
        'galeriaCompartible': galeriaCompartible,
        'tokenGaleria': token,
        'fechaExpiracionGaleria': fechaExpiracion == null
            ? null
            : Timestamp.fromDate(
                DateTime(
                  fechaExpiracion!.year,
                  fechaExpiracion!.month,
                  fechaExpiracion!.day,
                  23,
                  59,
                  59,
                ),
              ),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        tokenGaleria = token;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuración guardada')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> compartirAcceso() async {
    if (tokenGaleria.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Guarda primero la configuración')),
      );
      return;
    }

    final link =
        'eventosapp://galeria?evento=${widget.eventoId}&token=$tokenGaleria';

    final mensaje = '''
📸 Galería del evento: ${widget.nombreEvento}

Accede aquí:
$link

Vigencia: $fechaTexto

Puedes ver y descargar las fotos mientras el acceso esté activo.
''';

    await Share.share(
      mensaje,
      subject: 'Galería del evento',
    );
  }

  @override
  void initState() {
    super.initState();
    cargarConfiguracion();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compartir galería'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(
              widget.nombreEvento,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            SwitchListTile(
              value: galeriaCompartible,
              title: const Text('Habilitar galería compartida'),
              onChanged: (value) {
                setState(() => galeriaCompartible = value);
              },
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: seleccionarFechaExpiracion,
              child: Text(fechaTexto),
            ),
            const SizedBox(height: 20),
            if (tokenGaleria.isNotEmpty) ...[
              const Text(
                'Token generado',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SelectableText(tokenGaleria),
              const SizedBox(height: 20),
            ],
            ElevatedButton(
              onPressed: saving ? null : guardarConfiguracion,
              child: Text(saving ? 'Guardando...' : 'Guardar'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: (!galeriaCompartible || tokenGaleria.isEmpty)
                  ? null
                  : compartirAcceso,
              child: const Text('Compartir acceso'),
            ),
          ],
        ),
      ),
    );
  }
}
