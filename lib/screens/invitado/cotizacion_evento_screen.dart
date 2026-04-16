import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CotizacionEventoScreen extends StatefulWidget {
  final String empresaId;
  final String eventoOrigenId;

  const CotizacionEventoScreen({
    super.key,
    required this.empresaId,
    required this.eventoOrigenId,
  });

  @override
  State<CotizacionEventoScreen> createState() => _CotizacionEventoScreenState();
}

class _CotizacionEventoScreenState extends State<CotizacionEventoScreen> {
  final nombreController = TextEditingController();
  final telefonoController = TextEditingController();
  final correoController = TextEditingController();
  final invitadosEstimadosController = TextEditingController();
  final comentariosController = TextEditingController();

  String tipoEvento = 'boda';
  bool saving = false;
  DateTime? fechaEstimada;

  Future<void> seleccionarFechaEstimada() async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          fechaEstimada ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2035),
    );

    if (picked != null) {
      setState(() => fechaEstimada = picked);
    }
  }

  String get fechaEstimadaTexto {
    if (fechaEstimada == null) return 'Seleccionar fecha estimada';
    return '${fechaEstimada!.day.toString().padLeft(2, '0')}/'
        '${fechaEstimada!.month.toString().padLeft(2, '0')}/'
        '${fechaEstimada!.year}';
  }

  Future<void> guardarLead() async {
    final nombre = nombreController.text.trim();
    final telefono = telefonoController.text.trim();
    final correo = correoController.text.trim().toLowerCase();
    final invitadosEstimados =
        int.tryParse(invitadosEstimadosController.text.trim()) ?? 0;
    final comentarios = comentariosController.text.trim();

    if (nombre.isEmpty || telefono.isEmpty || correo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa nombre, teléfono y correo')),
      );
      return;
    }

    setState(() => saving = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

      await FirebaseFirestore.instance.collection('leads_cotizacion').add({
        'empresaId': widget.empresaId,
        'eventoOrigenId': widget.eventoOrigenId,
        'invitadoUid': uid,
        'nombre': nombre,
        'telefono': telefono,
        'email': correo,
        'tipoEvento': tipoEvento,
        'fechaEstimada': fechaEstimada == null
            ? ''
            : Timestamp.fromDate(
                DateTime(
                  fechaEstimada!.year,
                  fechaEstimada!.month,
                  fechaEstimada!.day,
                ),
              ),
        'fechaEstimadaTexto': fechaEstimadaTexto,
        'invitadosEstimados': invitadosEstimados,
        'comentarios': comentarios,
        'origen': 'app_invitado',
        'estado': 'nuevo',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud enviada correctamente')),
      );

      nombreController.clear();
      telefonoController.clear();
      correoController.clear();
      invitadosEstimadosController.clear();
      comentariosController.clear();

      setState(() {
        tipoEvento = 'boda';
        fechaEstimada = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error enviando solicitud: $e')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    nombreController.dispose();
    telefonoController.dispose();
    correoController.dispose();
    invitadosEstimadosController.dispose();
    comentariosController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tipos = [
      'boda',
      'xv_anios',
      'bautizo',
      'graduacion',
      'aniversario',
      'otro',
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cotizar mi evento'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: nombreController,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: telefonoController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Teléfono'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: correoController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Correo'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: tipoEvento,
              items: tipos
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => tipoEvento = value);
              },
              decoration: const InputDecoration(labelText: 'Tipo de evento'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: seleccionarFechaEstimada,
              child: Text(fechaEstimadaTexto),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: invitadosEstimadosController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Invitados estimados',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: comentariosController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Comentarios',
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: saving ? null : guardarLead,
              child: Text(saving ? 'Guardando...' : 'Solicitar cotización'),
            ),
          ],
        ),
      ),
    );
  }
}
