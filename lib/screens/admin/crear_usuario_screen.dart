import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CrearUsuarioScreen extends StatefulWidget {
  final String empresaId;

  const CrearUsuarioScreen({
    super.key,
    required this.empresaId,
  });

  @override
  State<CrearUsuarioScreen> createState() => _CrearUsuarioScreenState();
}

class _CrearUsuarioScreenState extends State<CrearUsuarioScreen> {
  final nombreController = TextEditingController();
  final emailController = TextEditingController();

  String rol = 'hostess';
  bool activo = true;
  bool saving = false;

  String _normalizeEmail(String email) => email.trim().toLowerCase();

  Future<void> guardar() async {
    final nombre = nombreController.text.trim();
    final email = _normalizeEmail(emailController.text);

    if (nombre.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa nombre y correo')),
      );
      return;
    }

    setState(() => saving = true);

    try {
      final adminUid = FirebaseAuth.instance.currentUser?.uid ?? '';

      await FirebaseFirestore.instance
          .collection('usuarios_config')
          .doc(email.toLowerCase())
          .set({
        'nombre': nombre,
        'email': email,
        'rol': rol,
        'activo': true,
        'empresaId': widget.empresaId,
        'createdBy': adminUid,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Configuración de usuario guardada. Ahora crea el correo/contraseña en Firebase Authentication con el mismo email.',
          ),
        ),
      );

      nombreController.clear();
      emailController.clear();
      setState(() {
        rol = 'hostess';
        activo = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error guardando usuario: $e')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    nombreController.dispose();
    emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roles = ['hostess', 'cap_meseros', 'invitado'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear usuario'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text('Empresa: ${widget.empresaId}'),
            const SizedBox(height: 16),
            TextField(
              controller: nombreController,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Correo'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: rol,
              items: roles
                  .map(
                    (r) => DropdownMenuItem(
                      value: r,
                      child: Text(r),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => rol = value);
                }
              },
              decoration: const InputDecoration(labelText: 'Rol'),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: activo,
              onChanged: (value) => setState(() => activo = value),
              title: const Text('Activo'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: saving ? null : guardar,
              child: Text(saving ? 'Guardando...' : 'Guardar usuario'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Nota MVP: el correo/contraseña real del usuario se crea manualmente en Firebase Authentication con el mismo email.',
            ),
          ],
        ),
      ),
    );
  }
}
