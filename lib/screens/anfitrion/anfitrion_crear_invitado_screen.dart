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

  bool guardando = false;

  String nombreEvento = '';
  Timestamp? fechaHoraInicio;
  Timestamp? fechaHoraFin;
  String estadoEvento = 'abierto';

  String anfitrionNombre = '';
  String anfitrionUid = '';

  String _normalizarCorreo(String correo) {
    return correo.trim().toLowerCase();
  }

  Future<void> _cargarEventoYAnfitrion() async {
    final eventoDoc = await FirebaseFirestore.instance
        .collection('eventos')
        .doc(widget.eventoId)
        .get();

    final anfitrionDoc = await FirebaseFirestore.instance
        .collection('anfitriones_evento')
        .doc(widget.anfitrionId)
        .get();

    final eventoData = eventoDoc.data() ?? {};
    final anfitrionData = anfitrionDoc.data() ?? {};

    setState(() {
      nombreEvento = (eventoData['nombreEvento'] ?? '').toString();
      fechaHoraInicio = eventoData['fechaHoraInicio'] is Timestamp
          ? eventoData['fechaHoraInicio']
          : null;
      fechaHoraFin = eventoData['fechaHoraFin'] is Timestamp
          ? eventoData['fechaHoraFin']
          : null;
      estadoEvento = (eventoData['estado'] ?? 'abierto').toString();

      anfitrionNombre = (anfitrionData['nombre'] ?? '').toString();
      anfitrionUid = (anfitrionData['uidUsuario'] ?? '').toString();
    });
  }

  Future<void> _crearIndice({
    required String invitadoId,
    required String email,
    required String uidUsuario,
    required String nombre,
  }) async {
    if (email.trim().isEmpty) return;

    await FirebaseFirestore.instance.collection('usuarios_eventos').add({
      'empresaId': widget.empresaId,
      'eventoId': widget.eventoId,
      'invitadoId': invitadoId,
      'anfitrionId': widget.anfitrionId,
      'uidUsuario': uidUsuario,
      'email': email,
      'rolEvento': 'invitado',
      'nombrePersona': nombre,
      'nombreEvento': nombreEvento,
      'fechaHoraInicio': fechaHoraInicio,
      'fechaHoraFin': fechaHoraFin,
      'estadoManual': estadoEvento,
      'activo': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, dynamic>?> _buscarUsuarioPorCorreo(String email) async {
    final snap = await FirebaseFirestore.instance
        .collection('usuarios')
        .where('empresaId', isEqualTo: widget.empresaId)
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;

    return {
      'uid': snap.docs.first.id,
      'data': snap.docs.first.data(),
    };
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
      String uidUsuario = '';
      bool existeEnSistema = false;

      if (email.isNotEmpty) {
        final usuarioExistente = await _buscarUsuarioPorCorreo(email);

        if (usuarioExistente != null) {
          uidUsuario = (usuarioExistente['uid'] ?? '').toString();
          existeEnSistema = true;
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
      }

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
        'usuarioId': uidUsuario,
        'eventoId': widget.eventoId,
        'empresaId': widget.empresaId,
        'anfitrionId': widget.anfitrionId,
        'anfitrionNombre': anfitrionNombre,
        'anfitrionUid': anfitrionUid,
        'estado_asistencia': 'pendiente',
        'qr_code': qr,
        'existeEnSistema': existeEnSistema,
        'creadoPorRol': 'anfitrion',
        'esAnfitrion': false,
        'cuentaComoInvitado': true,
        'puedeGestionarInvitados': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      /// 🔥 CREAR ÍNDICE
      await _crearIndice(
        invitadoId: ref.id,
        email: email,
        uidUsuario: uidUsuario,
        nombre: nombre,
      );

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
  void initState() {
    super.initState();
    _cargarEventoYAnfitrion();
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
