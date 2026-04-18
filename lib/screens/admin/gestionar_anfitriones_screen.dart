import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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

  bool saving = false;
  int totalInvitadosEvento = 0;

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
      totalInvitadosEvento = (data['totalInvitados'] ?? 0) as int;
    });
  }

  Future<Map<String, dynamic>?> _buscarUsuarioPorCorreo(String correo) async {
    final correoNormalizado = _normalizarCorreo(correo);

    final snap = await FirebaseFirestore.instance
        .collection('usuarios')
        .where('empresaId', isEqualTo: widget.empresaId)
        .where('email', isEqualTo: correoNormalizado)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;

    return {
      'uid': snap.docs.first.id,
      'data': snap.docs.first.data(),
    };
  }

  Future<bool> _anfitrionYaExisteEnEvento(String correo) async {
    final correoNormalizado = _normalizarCorreo(correo);

    final snap = await FirebaseFirestore.instance
        .collection('anfitriones_evento')
        .where('empresaId', isEqualTo: widget.empresaId)
        .where('eventoId', isEqualTo: widget.eventoId)
        .where('email', isEqualTo: correoNormalizado)
        .limit(1)
        .get();

    return snap.docs.isNotEmpty;
  }

  Future<int> _sumarCuposActuales() async {
    final snap = await FirebaseFirestore.instance
        .collection('anfitriones_evento')
        .where('empresaId', isEqualTo: widget.empresaId)
        .where('eventoId', isEqualTo: widget.eventoId)
        .get();

    int suma = 0;
    for (final doc in snap.docs) {
      final data = doc.data();
      final maxInvitados = (data['maxInvitados'] ?? 0) as int;
      suma += maxInvitados;
    }
    return suma;
  }

  Future<void> guardarAnfitrion() async {
    final nombre = nombreController.text.trim();
    final email = _normalizarCorreo(emailController.text);
    final maxInvitados = int.tryParse(maxInvitadosController.text.trim()) ?? 0;

    if (nombre.isEmpty || email.isEmpty || maxInvitados <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completa nombre, correo y máximo de invitados válido'),
        ),
      );
      return;
    }

    setState(() => saving = true);

    try {
      final yaExisteEnEvento = await _anfitrionYaExisteEnEvento(email);

      if (yaExisteEnEvento) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Ese correo ya está registrado como anfitrión en este evento'),
          ),
        );
        setState(() => saving = false);
        return;
      }

      final sumaActual = await _sumarCuposActuales();
      final nuevaSuma = sumaActual + maxInvitados;

      if (nuevaSuma > totalInvitadosEvento) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No puedes asignar ese cupo. Total evento: $totalInvitadosEvento, ya asignado: $sumaActual, intento nuevo: $maxInvitados',
            ),
          ),
        );
        setState(() => saving = false);
        return;
      }

      final usuarioExistente = await _buscarUsuarioPorCorreo(email);

      String uidUsuario = '';
      bool existeEnSistema = false;
      String nombreSistema = nombre;

      if (usuarioExistente != null) {
        final data = (usuarioExistente['data'] ?? {}) as Map<String, dynamic>;
        uidUsuario = (usuarioExistente['uid'] ?? '').toString();
        existeEnSistema = true;
        nombreSistema = (data['nombre'] ?? nombre).toString();
      }

      await FirebaseFirestore.instance.collection('anfitriones_evento').add({
        'empresaId': widget.empresaId,
        'eventoId': widget.eventoId,
        'nombre': nombreSistema,
        'email': email,
        'maxInvitados': maxInvitados,
        'activo': true,
        'uidUsuario': uidUsuario,
        'existeEnSistema': existeEnSistema,
        'createdAt': FieldValue.serverTimestamp(),
      });

      nombreController.clear();
      emailController.clear();
      maxInvitadosController.text = '10';

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existeEnSistema
                ? 'Anfitrión ligado a usuario existente'
                : 'Anfitrión guardado. Aún no existe como usuario del sistema',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error guardando anfitrión: $e')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> eliminarAnfitrion(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar anfitrión'),
        content: const Text(
            '¿Seguro que deseas eliminar este anfitrión del evento?'),
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

    await FirebaseFirestore.instance
        .collection('anfitriones_evento')
        .doc(docId)
        .delete();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Anfitrión eliminado')),
    );
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
    final ref = FirebaseFirestore.instance
        .collection('anfitriones_evento')
        .where('empresaId', isEqualTo: widget.empresaId)
        .where('eventoId', isEqualTo: widget.eventoId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestionar anfitriones'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Total invitados del evento: $totalInvitadosEvento',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
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
                labelText: 'Máximo de invitados',
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: saving ? null : guardarAnfitrion,
              child: Text(saving ? 'Guardando...' : 'Agregar anfitrión'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: ref.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                            'Error cargando anfitriones: ${snapshot.error}'),
                      ),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];

                  docs.sort((a, b) {
                    final aTs = a.data()['createdAt'];
                    final bTs = b.data()['createdAt'];

                    if (aTs is Timestamp && bTs is Timestamp) {
                      return bTs.compareTo(aTs);
                    }
                    return 0;
                  });

                  int sumaActual = 0;
                  for (final d in docs) {
                    sumaActual += (d.data()['maxInvitados'] ?? 0) as int;
                  }

                  if (docs.isEmpty) {
                    return const Center(
                      child: Text('Aún no hay anfitriones registrados'),
                    );
                  }

                  return Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Cupo asignado a anfitriones: $sumaActual / $totalInvitadosEvento',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.separated(
                          itemCount: docs.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, index) {
                            final doc = docs[index];
                            final data = doc.data();

                            final nombre = (data['nombre'] ?? '').toString();
                            final email = (data['email'] ?? '').toString();
                            final maxInvitados =
                                (data['maxInvitados'] ?? 0).toString();
                            final existeEnSistema =
                                data['existeEnSistema'] == true;
                            final uidUsuario =
                                (data['uidUsuario'] ?? '').toString();

                            return ListTile(
                              title: Text(nombre),
                              subtitle: Text(
                                '$email\nMáximo invitados: $maxInvitados\n'
                                '${existeEnSistema ? "Usuario existente en sistema" : "Aún no existe en sistema"}'
                                '${uidUsuario.isNotEmpty ? "\nUID: $uidUsuario" : ""}',
                              ),
                              isThreeLine: true,
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => eliminarAnfitrion(doc.id),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
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
