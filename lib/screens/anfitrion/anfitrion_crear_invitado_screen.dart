import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AnfitrionCrearInvitadoScreen extends StatefulWidget {
  final String eventoId;
  final String empresaId;
  final String anfitrionId;

  const AnfitrionCrearInvitadoScreen({
    super.key,
    required this.eventoId,
    required this.empresaId,
    required this.anfitrionId,
  });

  @override
  State<AnfitrionCrearInvitadoScreen> createState() =>
      _AnfitrionCrearInvitadoScreenState();
}

class _AnfitrionCrearInvitadoScreenState
    extends State<AnfitrionCrearInvitadoScreen> {
  final nombreController = TextEditingController();
  final emailController = TextEditingController();
  final mesaController = TextEditingController();

  bool saving = false;
  String anfitrionNombre = '';
  String anfitrionUid = '';
  int maxInvitados = 0;

  String _normalizarCorreo(String correo) {
    return correo.trim().toLowerCase();
  }

  Future<void> _cargarAnfitrion() async {
    final doc = await FirebaseFirestore.instance
        .collection('anfitriones_evento')
        .doc(widget.anfitrionId)
        .get();

    final data = doc.data() ?? {};
    setState(() {
      anfitrionNombre = (data['nombre'] ?? '').toString();
      anfitrionUid = (data['uidUsuario'] ?? '').toString();
      maxInvitados = (data['maxInvitados'] ?? 0) as int;
    });
  }

  Future<bool> _invitadoYaExiste(String correo) async {
    final snap = await FirebaseFirestore.instance
        .collection('eventos')
        .doc(widget.eventoId)
        .collection('invitados')
        .where('email_invitado', isEqualTo: _normalizarCorreo(correo))
        .limit(1)
        .get();

    return snap.docs.isNotEmpty;
  }

  Future<int> _totalInvitadosAnfitrion() async {
    final snap = await FirebaseFirestore.instance
        .collection('eventos')
        .doc(widget.eventoId)
        .collection('invitados')
        .where('anfitrionId', isEqualTo: widget.anfitrionId)
        .where('esAnfitrion', isEqualTo: false)
        .get();

    return snap.docs.length;
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
      final yaExiste = await _invitadoYaExiste(email);
      if (yaExiste) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Ese correo ya está registrado en este evento')),
        );
        setState(() => saving = false);
        return;
      }

      final totalActual = await _totalInvitadosAnfitrion();
      if (totalActual >= maxInvitados) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Ya alcanzaste tu cupo máximo: $maxInvitados')),
        );
        setState(() => saving = false);
        return;
      }

      String uidUsuario = '';
      final usuarioSnap = await FirebaseFirestore.instance
          .collection('usuarios')
          .where('empresaId', isEqualTo: widget.empresaId)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (usuarioSnap.docs.isNotEmpty) {
        uidUsuario = usuarioSnap.docs.first.id;
      } else {
        final nuevoUsuarioRef =
            FirebaseFirestore.instance.collection('usuarios').doc();
        await nuevoUsuarioRef.set({
          'empresaId': widget.empresaId,
          'nombre': nombre,
          'email': email,
          'rol': 'invitado',
          'activo': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
        uidUsuario = nuevoUsuarioRef.id;
      }

      final invitadosRef = FirebaseFirestore.instance
          .collection('eventos')
          .doc(widget.eventoId)
          .collection('invitados');

      final docRef = invitadosRef.doc();
      final qrPayload =
          '{"eventoId":"${widget.eventoId}","invitadoId":"${docRef.id}"}';

      await docRef.set({
        'nombre_invitado': nombre,
        'email_invitado': email,
        'mesa': mesa,
        'usuarioId': uidUsuario,
        'eventoId': widget.eventoId,
        'empresaId': widget.empresaId,
        'anfitrionId': widget.anfitrionId,
        'anfitrionNombre': anfitrionNombre,
        'anfitrionUid': anfitrionUid,
        'estado_asistencia': 'pendiente',
        'qr_code': qrPayload,
        'creadoPorRol': 'anfitrion',
        'esAnfitrion': false,
        'puedeGestionarInvitados': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitado registrado correctamente')),
      );
      Navigator.pop(context);
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
  void initState() {
    super.initState();
    _cargarAnfitrion();
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agregar invitado'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text('Anfitrión: $anfitrionNombre'),
            Text('Cupo máximo: $maxInvitados'),
            const SizedBox(height: 16),
            TextField(
              controller: nombreController,
              decoration:
                  const InputDecoration(labelText: 'Nombre del invitado'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              decoration:
                  const InputDecoration(labelText: 'Correo del invitado'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: mesaController,
              decoration: const InputDecoration(labelText: 'Mesa'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: saving ? null : guardar,
              child: Text(saving ? 'Guardando...' : 'Guardar invitado'),
            ),
          ],
        ),
      ),
    );
  }
}
