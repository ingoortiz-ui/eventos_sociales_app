import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class CrearInvitadoScreen extends StatefulWidget {
  final String eventoId;

  const CrearInvitadoScreen({
    super.key,
    required this.eventoId,
  });

  @override
  State<CrearInvitadoScreen> createState() => _CrearInvitadoScreenState();
}

class _CrearInvitadoScreenState extends State<CrearInvitadoScreen> {
  final nombreController = TextEditingController();
  final emailController = TextEditingController();
  final mesaController = TextEditingController();
  final invitadoDeController = TextEditingController();

  bool saving = false;
  String ultimoQr = '';
  String ultimoNombre = '';

  Future<void> guardarInvitado() async {
    final nombre = nombreController.text.trim();
    final email = emailController.text.trim().toLowerCase();
    final mesa = mesaController.text.trim();
    final invitadoDe = invitadoDeController.text.trim();

    if (nombre.isEmpty || email.isEmpty || mesa.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa nombre, correo y mesa')),
      );
      return;
    }

    setState(() => saving = true);

    try {
      final docRef = await FirebaseFirestore.instance
          .collection('eventos')
          .doc(widget.eventoId)
          .collection('invitados')
          .add({
        'nombre_invitado': nombre,
        'email_invitado': email,
        'mesa': mesa,
        'invitadoDe': invitadoDe,
        'estado_asistencia': 'pendiente',
        'createdAt': FieldValue.serverTimestamp(),
      });

      final payload = jsonEncode({
        'eventoId': widget.eventoId,
        'invitadoId': docRef.id,
      });

      await docRef.update({
        'qr_code': payload,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invitado guardado: $nombre')),
      );

      // Limpiar todo para el siguiente invitado
      nombreController.clear();
      emailController.clear();
      mesaController.clear();
      invitadoDeController.clear();

      setState(() {
        // Borrar QR y nombre del invitado anterior
        ultimoQr = '';
        ultimoNombre = '';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error guardando invitado: $e')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    nombreController.dispose();
    emailController.dispose();
    mesaController.dispose();
    invitadoDeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mostrandoUltimoQr = ultimoQr.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Invitado'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: nombreController,
              decoration: const InputDecoration(
                labelText: 'Nombre del invitado',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Correo del invitado',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: mesaController,
              decoration: const InputDecoration(
                labelText: 'Mesa asignada',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: invitadoDeController,
              decoration: const InputDecoration(
                labelText: 'Invitado de',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: saving ? null : guardarInvitado,
              child: Text(saving ? 'Guardando...' : 'Guardar y generar QR'),
            ),
            const SizedBox(height: 24),
            if (mostrandoUltimoQr) ...[
              Text(
                'Último QR generado: $ultimoNombre',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Center(
                child: QrImageView(
                  data: ultimoQr,
                  version: QrVersions.auto,
                  size: 220,
                ),
              ),
              const SizedBox(height: 12),
              SelectableText(ultimoQr),
            ],
          ],
        ),
      ),
    );
  }
}
