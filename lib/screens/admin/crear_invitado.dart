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

  bool loadingEvento = true;
  bool guardando = false;

  String empresaId = '';
  String nombreEvento = '';
  int totalInvitados = 0;
  bool usaAnfitriones = false;

  String? anfitrionSeleccionadoId;
  String anfitrionSeleccionadoNombre = '';
  String anfitrionUid = '';
  int anfitrionMaxInvitados = 0;

  String qrGenerado = '';

  String _normalizarCorreo(String correo) {
    return correo.trim().toLowerCase();
  }

  Future<void> _cargarEvento() async {
    final doc = await FirebaseFirestore.instance
        .collection('eventos')
        .doc(widget.eventoId)
        .get();

    final data = doc.data() ?? {};

    setState(() {
      empresaId = (data['empresaId'] ?? '').toString();
      nombreEvento = (data['nombreEvento'] ?? '').toString();
      totalInvitados = (data['totalInvitados'] ?? 0) as int;
      usaAnfitriones = data['usaAnfitriones'] == true;
      loadingEvento = false;
    });
  }

  Future<int> _contarInvitadosReales() async {
    final snap = await FirebaseFirestore.instance
        .collection('eventos')
        .doc(widget.eventoId)
        .collection('invitados')
        .where('esAnfitrion', isEqualTo: false)
        .get();

    return snap.docs.length;
  }

  Future<int> _contarInvitadosDelAnfitrion(String anfitrionId) async {
    final snap = await FirebaseFirestore.instance
        .collection('eventos')
        .doc(widget.eventoId)
        .collection('invitados')
        .where('anfitrionId', isEqualTo: anfitrionId)
        .where('esAnfitrion', isEqualTo: false)
        .get();

    return snap.docs.length;
  }

  Future<bool> _correoYaExisteEnEvento(String email) async {
    final snap = await FirebaseFirestore.instance
        .collection('eventos')
        .doc(widget.eventoId)
        .collection('invitados')
        .where('email_invitado', isEqualTo: email)
        .limit(1)
        .get();

    return snap.docs.isNotEmpty;
  }

  Future<Map<String, dynamic>?> _buscarUsuarioPorCorreo(String email) async {
    final snap = await FirebaseFirestore.instance
        .collection('usuarios')
        .where('empresaId', isEqualTo: empresaId)
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;

    return {
      'uid': snap.docs.first.id,
      'data': snap.docs.first.data(),
    };
  }

  Future<void> _guardarInvitado() async {
    final nombre = nombreController.text.trim();
    final email = _normalizarCorreo(emailController.text);
    final mesa = mesaController.text.trim();

    if (nombre.isEmpty || email.isEmpty || mesa.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa nombre, correo y mesa')),
      );
      return;
    }

    setState(() => guardando = true);

    try {
      final invitadosActuales = await _contarInvitadosReales();

      if (invitadosActuales >= totalInvitados) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'El evento ya alcanzó su límite de invitados: $totalInvitados',
            ),
          ),
        );
        return;
      }

      final yaExiste = await _correoYaExisteEnEvento(email);

      if (yaExiste) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ese correo ya está registrado en este evento'),
          ),
        );
        return;
      }

      if (usaAnfitriones && (anfitrionSeleccionadoId ?? '').isNotEmpty) {
        final totalDelAnfitrion =
            await _contarInvitadosDelAnfitrion(anfitrionSeleccionadoId!);

        if (totalDelAnfitrion >= anfitrionMaxInvitados) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'El anfitrión ya alcanzó su límite: $anfitrionMaxInvitados',
              ),
            ),
          );
          return;
        }
      }

      String uidUsuario = '';
      bool existeEnSistema = false;

      final usuarioExistente = await _buscarUsuarioPorCorreo(email);

      if (usuarioExistente != null) {
        uidUsuario = (usuarioExistente['uid'] ?? '').toString();
        existeEnSistema = true;
      } else {
        final nuevoUsuarioRef =
            FirebaseFirestore.instance.collection('usuarios').doc();

        await nuevoUsuarioRef.set({
          'empresaId': empresaId,
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

      final invitadoRef = invitadosRef.doc();

      final qrPayload =
          '{"eventoId":"${widget.eventoId}","invitadoId":"${invitadoRef.id}"}';

      await invitadoRef.set({
        'nombre_invitado': nombre,
        'email_invitado': email,
        'mesa': mesa,
        'usuarioId': uidUsuario,
        'eventoId': widget.eventoId,
        'empresaId': empresaId,
        'anfitrionId': usaAnfitriones ? (anfitrionSeleccionadoId ?? '') : '',
        'anfitrionNombre': usaAnfitriones ? anfitrionSeleccionadoNombre : '',
        'anfitrionUid': usaAnfitriones ? anfitrionUid : '',
        'estado_asistencia': 'pendiente',
        'qr_code': qrPayload,
        'existeEnSistema': existeEnSistema,
        'creadoPorRol': 'admin',
        'esAnfitrion': false,
        'cuentaComoInvitado': true,
        'puedeGestionarInvitados': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        qrGenerado = qrPayload;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitado guardado correctamente')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error guardando invitado: $e')),
      );
    } finally {
      if (mounted) setState(() => guardando = false);
    }
  }

  void _limpiar() {
    nombreController.clear();
    emailController.clear();
    mesaController.clear();

    setState(() {
      qrGenerado = '';
      anfitrionSeleccionadoId = null;
      anfitrionSeleccionadoNombre = '';
      anfitrionUid = '';
      anfitrionMaxInvitados = 0;
    });
  }

  @override
  void initState() {
    super.initState();
    _cargarEvento();
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
    if (loadingEvento) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final anfitrionesStream = FirebaseFirestore.instance
        .collection('anfitriones_evento')
        .where('empresaId', isEqualTo: empresaId)
        .where('eventoId', isEqualTo: widget.eventoId)
        .where('activo', isEqualTo: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar invitado'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(
              nombreEvento.isEmpty ? 'Evento' : nombreEvento,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text('Total invitados permitidos: $totalInvitados'),
            if (usaAnfitriones)
              const Text('Este evento permite asignar anfitrión.'),
            if (!usaAnfitriones) const Text('Este evento no usa anfitriones.'),
            const SizedBox(height: 20),
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
            if (usaAnfitriones)
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: anfitrionesStream,
                builder: (context, snapshot) {
                  final docs = snapshot.data?.docs ?? [];

                  if (docs.isEmpty) {
                    return const Text(
                      'Aún no hay anfitriones. Puedes guardar el invitado sin anfitrión.',
                    );
                  }

                  return DropdownButtonFormField<String>(
                    value: anfitrionSeleccionadoId ?? '',
                    decoration: const InputDecoration(
                      labelText: 'Seleccionar anfitrión (opcional)',
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: '',
                        child: Text('Sin anfitrión'),
                      ),
                      ...docs.map((doc) {
                        final data = doc.data();
                        final nombre = (data['nombre'] ?? '').toString();
                        final maxInvitados =
                            (data['maxInvitados'] ?? 0).toString();

                        return DropdownMenuItem<String>(
                          value: doc.id,
                          child: Text('$nombre (cupo: $maxInvitados)'),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      if (value == null || value.isEmpty) {
                        setState(() {
                          anfitrionSeleccionadoId = null;
                          anfitrionSeleccionadoNombre = '';
                          anfitrionUid = '';
                          anfitrionMaxInvitados = 0;
                        });
                        return;
                      }

                      final seleccionado =
                          docs.firstWhere((doc) => doc.id == value);
                      final data = seleccionado.data();

                      setState(() {
                        anfitrionSeleccionadoId = seleccionado.id;
                        anfitrionSeleccionadoNombre =
                            (data['nombre'] ?? '').toString();
                        anfitrionUid = (data['uidUsuario'] ?? '').toString();
                        anfitrionMaxInvitados =
                            (data['maxInvitados'] ?? 0) as int;
                      });
                    },
                  );
                },
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: guardando ? null : _guardarInvitado,
              child: Text(
                guardando ? 'Guardando...' : 'Guardar y generar QR',
              ),
            ),
            const SizedBox(height: 24),
            if (qrGenerado.isNotEmpty) ...[
              const Text(
                'QR generado:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Center(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(12),
                  child: QrImageView(
                    data: qrGenerado,
                    version: QrVersions.auto,
                    size: 220,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SelectableText(qrGenerado),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _limpiar,
                child: const Text('Registrar otro invitado'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
