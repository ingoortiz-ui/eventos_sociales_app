import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import 'lista_invitados_screen.dart';

class GestionarAnfitrionesScreen extends StatefulWidget {
  final String eventoId;
  final String empresaId;

  const GestionarAnfitrionesScreen({
    super.key,
    required this.eventoId,
    required this.empresaId,
  });

  @override
  State<GestionarAnfitrionesScreen> createState() =>
      _GestionarAnfitrionesScreenState();
}

class _GestionarAnfitrionesScreenState
    extends State<GestionarAnfitrionesScreen> {
  final nombreController = TextEditingController();
  final emailController = TextEditingController();
  final maxInvitadosController = TextEditingController(text: '10');

  bool loadingEvento = true;
  bool guardando = false;

  String nombreEvento = '';
  int totalInvitados = 0;
  bool usaAnfitriones = false;
  int cantidadAnfitriones = 0;

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
      nombreEvento = (data['nombreEvento'] ?? '').toString();
      totalInvitados = (data['totalInvitados'] ?? 0) as int;
      usaAnfitriones = data['usaAnfitriones'] == true;
      cantidadAnfitriones = (data['cantidadAnfitriones'] ?? 0) as int;
      loadingEvento = false;
    });
  }

  Future<void> _compartirQrComoImagen({
    required BuildContext context,
    required String qr,
    required String nombre,
  }) async {
    try {
      if (qr.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Este anfitrión no tiene QR')),
        );
        return;
      }

      final painter = QrPainter(
        data: qr,
        version: QrVersions.auto,
        gapless: true,
        color: Colors.black,
        emptyColor: Colors.white,
      );

      final byteData = await painter.toImageData(
        900,
        format: ui.ImageByteFormat.png,
      );

      if (byteData == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo generar imagen QR')),
        );
        return;
      }

      await Share.shareXFiles(
        [
          XFile.fromData(
            byteData.buffer.asUint8List(),
            mimeType: 'image/png',
            name: 'qr_anfitrion_${nombre.replaceAll(' ', '_')}.png',
          ),
        ],
        text: 'QR de acceso\nEvento: $nombreEvento\nAnfitrión: $nombre',
        subject: 'QR de anfitrión - $nombreEvento',
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error compartiendo QR: $e')),
      );
    }
  }

  Future<int> _contarAnfitrionesActuales() async {
    final snap = await FirebaseFirestore.instance
        .collection('anfitriones_evento')
        .where('empresaId', isEqualTo: widget.empresaId)
        .where('eventoId', isEqualTo: widget.eventoId)
        .where('activo', isEqualTo: true)
        .get();

    return snap.docs.length;
  }

  Future<bool> _correoYaEsAnfitrion(String email) async {
    final snap = await FirebaseFirestore.instance
        .collection('anfitriones_evento')
        .where('empresaId', isEqualTo: widget.empresaId)
        .where('eventoId', isEqualTo: widget.eventoId)
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    return snap.docs.isNotEmpty;
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

  Future<void> _guardarAnfitrion() async {
    if (!usaAnfitriones) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este evento no permite gestión de anfitriones'),
        ),
      );
      return;
    }

    final nombre = nombreController.text.trim();
    final email = _normalizarCorreo(emailController.text);
    final maxInvitados = int.tryParse(maxInvitadosController.text.trim()) ?? 0;

    if (nombre.isEmpty || email.isEmpty || maxInvitados <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completa nombre, correo y máximo de invitados'),
        ),
      );
      return;
    }

    setState(() => guardando = true);

    try {
      final anfitrionesActuales = await _contarAnfitrionesActuales();

      if (anfitrionesActuales >= cantidadAnfitriones) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Ya alcanzaste el máximo de anfitriones permitidos: $cantidadAnfitriones',
            ),
          ),
        );
        return;
      }

      final yaExiste = await _correoYaEsAnfitrion(email);

      if (yaExiste) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ese correo ya está registrado como anfitrión'),
          ),
        );
        return;
      }

      String uidUsuario = '';
      bool existeEnSistema = false;

      final usuarioExistente = await _buscarUsuarioPorCorreo(email);

      if (usuarioExistente != null) {
        uidUsuario = (usuarioExistente['uid'] ?? '').toString();
        existeEnSistema = true;

        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(uidUsuario)
            .set({
          'empresaId': widget.empresaId,
          'nombre': nombre,
          'email': email,
          'rol': 'anfitrion',
          'activo': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        final nuevoUsuarioRef =
            FirebaseFirestore.instance.collection('usuarios').doc();

        await nuevoUsuarioRef.set({
          'empresaId': widget.empresaId,
          'nombre': nombre,
          'email': email,
          'rol': 'anfitrion',
          'activo': true,
          'createdAt': FieldValue.serverTimestamp(),
        });

        uidUsuario = nuevoUsuarioRef.id;
      }

      final anfitrionRef =
          FirebaseFirestore.instance.collection('anfitriones_evento').doc();

      await anfitrionRef.set({
        'empresaId': widget.empresaId,
        'eventoId': widget.eventoId,
        'nombre': nombre,
        'email': email,
        'maxInvitados': maxInvitados,
        'uidUsuario': uidUsuario,
        'activo': true,
        'existeEnSistema': existeEnSistema,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final invitadosRef = FirebaseFirestore.instance
          .collection('eventos')
          .doc(widget.eventoId)
          .collection('invitados');

      final invitadoEspejoRef = invitadosRef.doc();

      final qrPayload =
          '{"eventoId":"${widget.eventoId}","invitadoId":"${invitadoEspejoRef.id}"}';

      await invitadoEspejoRef.set({
        'nombre_invitado': nombre,
        'email_invitado': email,
        'mesa': 'ANFITRION',
        'usuarioId': uidUsuario,
        'eventoId': widget.eventoId,
        'empresaId': widget.empresaId,
        'anfitrionId': anfitrionRef.id,
        'anfitrionNombre': nombre,
        'anfitrionUid': uidUsuario,
        'estado_asistencia': 'pendiente',
        'qr_code': qrPayload,
        'existeEnSistema': existeEnSistema,
        'creadoPorRol': 'admin',
        'esAnfitrion': true,
        'cuentaComoInvitado': false,
        'puedeGestionarInvitados': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await anfitrionRef.update({
        'invitadoEspejoId': invitadoEspejoRef.id,
        'qr_code': qrPayload,
      });

      if (!mounted) return;

      nombreController.clear();
      emailController.clear();
      maxInvitadosController.text = '10';

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Anfitrión guardado correctamente')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error guardando anfitrión: $e')),
      );
    } finally {
      if (mounted) setState(() => guardando = false);
    }
  }

  Future<void> _eliminarAnfitrion({
    required String anfitrionId,
    required String? invitadoEspejoId,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar anfitrión'),
        content: const Text(
          '¿Seguro que deseas eliminar este anfitrión? También se eliminará su QR de acceso como anfitrión.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('anfitriones_evento')
          .doc(anfitrionId)
          .delete();

      if (invitadoEspejoId != null && invitadoEspejoId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('eventos')
            .doc(widget.eventoId)
            .collection('invitados')
            .doc(invitadoEspejoId)
            .delete();
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Anfitrión eliminado')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error eliminando anfitrión: $e')),
      );
    }
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
    maxInvitadosController.dispose();
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
        .where('empresaId', isEqualTo: widget.empresaId)
        .where('eventoId', isEqualTo: widget.eventoId)
        .where('activo', isEqualTo: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestionar anfitriones'),
      ),
      body: !usaAnfitriones
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Este evento no permite gestión de anfitriones.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      nombreEvento.isEmpty ? 'Evento' : nombreEvento,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Invitados permitidos: $totalInvitados'),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Máximo de anfitriones permitidos: $cantidadAnfitriones',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nombreController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del anfitrión',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Correo del anfitrión',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: maxInvitadosController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Máximo de invitados que puede registrar',
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: guardando ? null : _guardarAnfitrion,
                    child:
                        Text(guardando ? 'Guardando...' : 'Agregar anfitrión'),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: anfitrionesStream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Error cargando anfitriones: ${snapshot.error}',
                            ),
                          );
                        }

                        final docs = snapshot.data?.docs ?? [];

                        if (docs.isEmpty) {
                          return const Center(
                            child: Text('Aún no hay anfitriones registrados'),
                          );
                        }

                        return ListView.separated(
                          itemCount: docs.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, index) {
                            final doc = docs[index];
                            final data = doc.data();

                            final nombre = (data['nombre'] ?? '').toString();
                            final email = (data['email'] ?? '').toString();
                            final maxInvitados =
                                (data['maxInvitados'] ?? 0).toString();
                            final invitadoEspejoId =
                                (data['invitadoEspejoId'] ?? '').toString();
                            final qr = (data['qr_code'] ?? '').toString();

                            return ListTile(
                              title: Text(nombre),
                              subtitle: Text(
                                '$email\nPuede registrar invitados: $maxInvitados\nQR propio generado',
                              ),
                              isThreeLine: true,
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'invitados') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ListaInvitadosScreen(
                                          eventoId: widget.eventoId,
                                          anfitrionIdFiltro: doc.id,
                                          titulo: 'Invitados de $nombre',
                                        ),
                                      ),
                                    );
                                  } else if (value == 'compartir') {
                                    _compartirQrComoImagen(
                                      context: context,
                                      qr: qr,
                                      nombre: nombre,
                                    );
                                  } else if (value == 'eliminar') {
                                    _eliminarAnfitrion(
                                      anfitrionId: doc.id,
                                      invitadoEspejoId: invitadoEspejoId,
                                    );
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'invitados',
                                    child: Text('Gestionar invitados'),
                                  ),
                                  PopupMenuItem(
                                    value: 'compartir',
                                    child: Text('Compartir QR imagen'),
                                  ),
                                  PopupMenuItem(
                                    value: 'eliminar',
                                    child: Text('Eliminar anfitrión'),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
