import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RegistroEmpresaScreen extends StatefulWidget {
  const RegistroEmpresaScreen({super.key});

  @override
  State<RegistroEmpresaScreen> createState() => _RegistroEmpresaScreenState();
}

class _RegistroEmpresaScreenState extends State<RegistroEmpresaScreen> {
  final nombreEmpresaController = TextEditingController();
  final nombreAdminController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;

  // Giros
  bool giroEventos = true;
  bool giroRestaurante = false;
  bool giroServicios = false;

  final serviciosController = TextEditingController();

  Future<void> _registrar() async {
    final nombreEmpresa = nombreEmpresaController.text.trim();
    final nombreAdmin = nombreAdminController.text.trim();
    final email = emailController.text.trim().toLowerCase();
    final password = passwordController.text.trim();

    if (nombreEmpresa.isEmpty ||
        nombreAdmin.isEmpty ||
        email.isEmpty ||
        password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos')),
      );
      return;
    }

    if (!giroEventos && !giroRestaurante && !giroServicios) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos un tipo de empresa')),
      );
      return;
    }

    setState(() => loading = true);

    try {
      /// 🔐 1. Crear usuario en Firebase Auth
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = cred.user!.uid;

      /// 🏢 2. Crear empresa
      final empresaRef =
          FirebaseFirestore.instance.collection('empresas').doc();

      final giros = <String>[];

      if (giroEventos) giros.add('eventos');
      if (giroRestaurante) giros.add('restaurante');
      if (giroServicios) giros.add('servicios');

      final serviciosTipos = serviciosController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      await empresaRef.set({
        'nombreEmpresa': nombreEmpresa,
        'empresaId': empresaRef.id,
        'giros': giros,
        'serviciosTipos': serviciosTipos,
        'activo': true,
        'plan': 'prueba',
        'createdAt': FieldValue.serverTimestamp(),
      });

      /// 👤 3. Crear usuario admin
      await FirebaseFirestore.instance.collection('usuarios').doc(uid).set({
        'nombre': nombreAdmin,
        'email': email,
        'rol': 'admin',
        'empresaId': empresaRef.id,
        'activo': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    nombreEmpresaController.dispose();
    nombreAdminController.dispose();
    emailController.dispose();
    passwordController.dispose();
    serviciosController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar empresa'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: nombreEmpresaController,
              decoration: const InputDecoration(
                labelText: 'Nombre de la empresa',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nombreAdminController,
              decoration: const InputDecoration(
                labelText: 'Nombre del administrador',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Correo',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Contraseña',
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Tipo de empresa',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            CheckboxListTile(
              value: giroEventos,
              onChanged: (v) => setState(() => giroEventos = v!),
              title: const Text('Eventos'),
            ),
            CheckboxListTile(
              value: giroRestaurante,
              onChanged: (v) => setState(() => giroRestaurante = v!),
              title: const Text('Restaurante'),
            ),
            CheckboxListTile(
              value: giroServicios,
              onChanged: (v) => setState(() => giroServicios = v!),
              title: const Text('Prestadora de servicios'),
            ),
            if (giroServicios) ...[
              const SizedBox(height: 10),
              TextField(
                controller: serviciosController,
                decoration: const InputDecoration(
                  labelText: 'Tipos de servicio (separados por coma)',
                  hintText: 'banquetes, música, fotografía',
                ),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: loading ? null : _registrar,
              child: Text(
                loading ? 'Registrando...' : 'Crear empresa',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
