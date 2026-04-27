import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

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
  final serviciosController = TextEditingController();

  bool loading = false;

  bool giroEventos = true;
  bool giroRestaurante = false;
  bool giroServicios = false;

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
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = cred.user!.uid;

      final empresaRef =
          FirebaseFirestore.instance.collection('empresas').doc();

      final giros = <String>[
        if (giroEventos) 'eventos',
        if (giroRestaurante) 'restaurante',
        if (giroServicios) 'servicios',
      ];

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

      await FirebaseFirestore.instance.collection('usuarios').doc(uid).set({
        'uid': uid,
        'nombre': nombreAdmin,
        'email': email,
        'rol': 'admin',
        'empresaId': empresaRef.id,
        'activo': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      String mensaje = 'Error registrando empresa';

      if (e.code == 'email-already-in-use') {
        mensaje = 'Ese correo ya tiene una cuenta';
      } else if (e.code == 'weak-password') {
        mensaje = 'La contraseña debe ser más segura';
      } else if (e.code == 'invalid-email') {
        mensaje = 'Correo inválido';
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensaje)),
      );
    } catch (e) {
      if (!mounted) return;
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

  Widget _giroTile({
    required IconData icon,
    required String titulo,
    required String subtitulo,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return Card(
      child: CheckboxListTile(
        value: value,
        onChanged: onChanged,
        secondary: Icon(icon, color: AppTheme.primary),
        title: Text(
          titulo,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(subtitulo),
        controlAffinity: ListTileControlAffinity.trailing,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Crear empresa'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.business_center_outlined,
                  size: 72,
                  color: AppTheme.primary,
                ),
                const SizedBox(height: 18),
                const Text(
                  'Registra tu empresa',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Administra eventos, reservaciones y servicios desde una sola plataforma.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textMuted),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        TextField(
                          controller: nombreEmpresaController,
                          decoration: const InputDecoration(
                            labelText: 'Nombre de la empresa',
                            prefixIcon: Icon(Icons.storefront_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: nombreAdminController,
                          decoration: const InputDecoration(
                            labelText: 'Nombre del administrador',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Correo administrador',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Contraseña',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Tipo de empresa',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                _giroTile(
                  icon: Icons.event_available,
                  titulo: 'Eventos',
                  subtitulo: 'Invitados, anfitriones, QR, fotos y reportes.',
                  value: giroEventos,
                  onChanged: (v) => setState(() => giroEventos = v ?? false),
                ),
                _giroTile(
                  icon: Icons.restaurant_outlined,
                  titulo: 'Restaurante',
                  subtitulo: 'Reservaciones, calendario y mesas.',
                  value: giroRestaurante,
                  onChanged: (v) =>
                      setState(() => giroRestaurante = v ?? false),
                ),
                _giroTile(
                  icon: Icons.room_service_outlined,
                  titulo: 'Prestadora de servicios',
                  subtitulo: 'Cotizaciones, agenda, anticipos y seguimiento.',
                  value: giroServicios,
                  onChanged: (v) => setState(() => giroServicios = v ?? false),
                ),
                if (giroServicios) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: serviciosController,
                    decoration: const InputDecoration(
                      labelText: 'Tipos de servicio',
                      hintText: 'banquetes, música, fotografía',
                      prefixIcon: Icon(Icons.list_alt_outlined),
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                ElevatedButton(
                  onPressed: loading ? null : _registrar,
                  child: Text(
                    loading ? 'Creando empresa...' : 'Crear empresa',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
