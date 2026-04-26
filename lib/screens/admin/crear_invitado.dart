import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CrearInvitadoScreen extends StatefulWidget {
  final String eventoId;
  final String empresaId;
  final String nombreEvento;
  final Timestamp? fechaHoraInicio;
  final Timestamp? fechaHoraFin;

  const CrearInvitadoScreen({
    super.key,
    required this.eventoId,
    required this.empresaId,
    required this.nombreEvento,
    this.fechaHoraInicio,
    this.fechaHoraFin,
  });

  @override
  State<CrearInvitadoScreen> createState() => _CrearInvitadoScreenState();
}

class _CrearInvitadoScreenState extends State<CrearInvitadoScreen> {
  final nombreController = TextEditingController();
  final emailController = TextEditingController();
  final mesaController = TextEditingController();

  bool guardando = false;

  String _normalizarCorreo(String correo) {
    return correo.trim().toLowerCase();
  }

  Future<void> _crearIndice({
    required String invitadoId,
    required String email,
    required String nombre,
  }) async {
    await FirebaseFirestore.instance.collection('usuarios_eventos').add({
      'empresaId': widget.empresaId,
      'eventoId': widget.eventoId,
      'invitadoId': invitadoId,
      'email': email,
      'rolEvento': 'invitado',
      'nombrePersona': nombre,
      'nombreEvento': widget.nombreEvento,
      'fechaHoraInicio': widget.fechaHoraInicio,
      'fechaHoraFin': widget.fechaHoraFin,
      'estadoManual': 'abierto',
      'activo': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _guardar() async {
    final nombre = nombreController.text.trim();
    final email = _normalizarCorreo(emailController.text);
    final mesa = mesaController.text.trim();

    if (nombre.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa el nombre')),
      );
      return;
    }

    setState(() => guardando = true);

    try {
      final ref = FirebaseFirestore.instance
          .collection('eventos')
          .doc(widget.eventoId)
          .collection('invitados')
          .doc();

      final qr = '{"eventoId":"${widget.eventoId}","invitadoId":"${ref.id}"}';

      await ref.set({
        'nombre_invitado': nombre,
        'email_invitado': email,
        'mesa': mesa,
        'eventoId': widget.eventoId,
        'empresaId': widget.empresaId,
        'estado_asistencia': 'pendiente',
        'qr_code': qr,
        'createdAt': FieldValue.serverTimestamp(),
      });

      /// 🔥 CREAR ÍNDICE
      if (email.isNotEmpty) {
        await _crearIndice(
          invitadoId: ref.id,
          email: email,
          nombre: nombre,
        );
      }

      if (!mounted) return;

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear invitado'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: nombreController,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: mesaController,
              decoration: const InputDecoration(labelText: 'Mesa'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: guardando ? null : _guardar,
              child: Text(guardando ? 'Guardando...' : 'Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
