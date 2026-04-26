import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class EditarInvitadoAdminScreen extends StatefulWidget {
  final String eventoId;
  final String invitadoId;

  const EditarInvitadoAdminScreen({
    super.key,
    required this.eventoId,
    required this.invitadoId,
  });

  @override
  State<EditarInvitadoAdminScreen> createState() =>
      _EditarInvitadoAdminScreenState();
}

class _EditarInvitadoAdminScreenState extends State<EditarInvitadoAdminScreen> {
  final nombreController = TextEditingController();
  final emailController = TextEditingController();
  final mesaController = TextEditingController();

  bool loading = true;
  bool saving = false;

  String empresaId = '';
  bool usaAnfitriones = false;

  String? anfitrionSeleccionadoId;
  String anfitrionSeleccionadoNombre = '';
  String anfitrionUid = '';

  String _normalizarCorreo(String correo) {
    return correo.trim().toLowerCase();
  }

  Future<void> _cargarDatos() async {
    final invitadoDoc = await FirebaseFirestore.instance
        .collection('eventos')
        .doc(widget.eventoId)
        .collection('invitados')
        .doc(widget.invitadoId)
        .get();

    final eventoDoc = await FirebaseFirestore.instance
        .collection('eventos')
        .doc(widget.eventoId)
        .get();

    final invitadoData = invitadoDoc.data() ?? {};
    final eventoData = eventoDoc.data() ?? {};

    nombreController.text = (invitadoData['nombre_invitado'] ?? '').toString();
    emailController.text = (invitadoData['email_invitado'] ?? '').toString();
    mesaController.text = (invitadoData['mesa'] ?? '').toString();

    anfitrionSeleccionadoId =
        (invitadoData['anfitrionId'] ?? '').toString().isEmpty
            ? null
            : (invitadoData['anfitrionId'] ?? '').toString();

    anfitrionSeleccionadoNombre =
        (invitadoData['anfitrionNombre'] ?? '').toString();

    anfitrionUid = (invitadoData['anfitrionUid'] ?? '').toString();

    empresaId = (eventoData['empresaId'] ?? '').toString();
    usaAnfitriones = eventoData['usaAnfitriones'] == true;

    setState(() => loading = false);
  }

  Future<void> _guardarCambios() async {
    final nombre = nombreController.text.trim();
    final email = _normalizarCorreo(emailController.text);
    final mesa = mesaController.text.trim();

    if (nombre.isEmpty || email.isEmpty || mesa.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos')),
      );
      return;
    }

    setState(() => saving = true);

    try {
      await FirebaseFirestore.instance
          .collection('eventos')
          .doc(widget.eventoId)
          .collection('invitados')
          .doc(widget.invitadoId)
          .update({
        'nombre_invitado': nombre,
        'email_invitado': email,
        'mesa': mesa,
        'anfitrionId': usaAnfitriones ? (anfitrionSeleccionadoId ?? '') : '',
        'anfitrionNombre': usaAnfitriones ? anfitrionSeleccionadoNombre : '',
        'anfitrionUid': usaAnfitriones ? anfitrionUid : '',
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
        SnackBar(content: Text('Error actualizando: $e')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _cargarDatos();
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

    final anfitrionesStream = FirebaseFirestore.instance
        .collection('anfitriones_evento')
        .where('empresaId', isEqualTo: empresaId)
        .where('eventoId', isEqualTo: widget.eventoId)
        .where('activo', isEqualTo: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar invitado'),
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
                labelText: 'Correo',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: mesaController,
              decoration: const InputDecoration(
                labelText: 'Mesa',
              ),
            ),
            const SizedBox(height: 12),

            /// SOLO SI EL EVENTO USA ANFITRIONES
            if (usaAnfitriones)
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: anfitrionesStream,
                builder: (context, snapshot) {
                  final docs = snapshot.data?.docs ?? [];

                  if (docs.isEmpty) {
                    return const Text(
                      'No hay anfitriones disponibles',
                    );
                  }

                  return DropdownButtonFormField<String>(
                    value: anfitrionSeleccionadoId ?? '',
                    decoration: const InputDecoration(
                      labelText: 'Asignar anfitrión (opcional)',
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: '',
                        child: Text('Sin anfitrión'),
                      ),
                      ...docs.map((doc) {
                        final data = doc.data();
                        final nombre = (data['nombre'] ?? '').toString();

                        return DropdownMenuItem<String>(
                          value: doc.id,
                          child: Text(nombre),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      if (value == null || value.isEmpty) {
                        setState(() {
                          anfitrionSeleccionadoId = null;
                          anfitrionSeleccionadoNombre = '';
                          anfitrionUid = '';
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
                      });
                    },
                  );
                },
              ),

            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: saving ? null : _guardarCambios,
              child: Text(
                saving ? 'Guardando...' : 'Guardar cambios',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
