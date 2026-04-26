import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AnfitrionEditarInvitadoScreen extends StatefulWidget {
  final String eventoId;
  final String invitadoId;
  final String anfitrionId;
  final String empresaId;

  const AnfitrionEditarInvitadoScreen({
    super.key,
    required this.eventoId,
    required this.invitadoId,
    required this.anfitrionId,
    required this.empresaId,
  });

  @override
  State<AnfitrionEditarInvitadoScreen> createState() =>
      _AnfitrionEditarInvitadoScreenState();
}

class _AnfitrionEditarInvitadoScreenState
    extends State<AnfitrionEditarInvitadoScreen> {
  final nombreController = TextEditingController();
  final emailController = TextEditingController();
  final mesaController = TextEditingController();

  bool loading = true;
  bool saving = false;
  bool esAnfitrion = false;

  String _normalizarCorreo(String correo) {
    return correo.trim().toLowerCase();
  }

  Future<void> cargar() async {
    final doc = await FirebaseFirestore.instance
        .collection('eventos')
        .doc(widget.eventoId)
        .collection('invitados')
        .doc(widget.invitadoId)
        .get();

    final data = doc.data() ?? {};

    nombreController.text = (data['nombre_invitado'] ?? '').toString();
    emailController.text = (data['email_invitado'] ?? '').toString();
    mesaController.text = (data['mesa'] ?? '').toString();
    esAnfitrion = data['esAnfitrion'] == true;

    setState(() => loading = false);
  }

  Future<bool> _correoDuplicado(String correo) async {
    final snap = await FirebaseFirestore.instance
        .collection('eventos')
        .doc(widget.eventoId)
        .collection('invitados')
        .where('email_invitado', isEqualTo: _normalizarCorreo(correo))
        .get();

    return snap.docs.any((d) => d.id != widget.invitadoId);
  }

  Future<void> guardar() async {
    final nombre = nombreController.text.trim();
    final email = _normalizarCorreo(emailController.text);
    final mesa = mesaController.text.trim();

    if (nombre.isEmpty || email.isEmpty || mesa.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa nombre, correo y mesa')),
      );
      return;
    }

    setState(() => saving = true);

    try {
      final duplicado = await _correoDuplicado(email);
      if (duplicado) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Ese correo ya está registrado en este evento')),
        );
        setState(() => saving = false);
        return;
      }

      await FirebaseFirestore.instance
          .collection('eventos')
          .doc(widget.eventoId)
          .collection('invitados')
          .doc(widget.invitadoId)
          .update({
        'nombre_invitado': nombre,
        'email_invitado': email,
        'mesa': mesa,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitado actualizado')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error actualizando invitado: $e')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void initState() {
    super.initState();
    cargar();
  }

  @override
  void dispose() {
    nombreController.dispose();
    emailController.dispose();
    mesaController.dispose();
    super.dispose();
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
        title:
            Text(esAnfitrion ? 'Editar anfitrión invitado' : 'Editar invitado'),
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
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Correo'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: mesaController,
              decoration: const InputDecoration(labelText: 'Mesa'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: saving ? null : guardar,
              child: Text(saving ? 'Guardando...' : 'Guardar cambios'),
            ),
          ],
        ),
      ),
    );
  }
}
