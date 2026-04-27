import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class RegistroUsuarioScreen extends StatefulWidget {
  const RegistroUsuarioScreen({super.key});

  @override
  State<RegistroUsuarioScreen> createState() => _RegistroUsuarioScreenState();
}

class _RegistroUsuarioScreenState extends State<RegistroUsuarioScreen> {
  final nombreController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;

  Future<void> _registrarUsuario() async {
    final nombre = nombreController.text.trim();
    final email = emailController.text.trim().toLowerCase();
    final password = passwordController.text.trim();

    if (nombre.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos')),
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

      await FirebaseFirestore.instance.collection('usuarios').doc(uid).set({
        'uid': uid,
        'nombre': nombre,
        'email': email,
        'rol': 'usuario',
        'empresaId': 'sin_empresa',
        'activo': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      String mensaje = 'Error registrando usuario';

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
    nombreController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Crear usuario'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.person_add_alt_1_outlined,
                  size: 72,
                  color: AppTheme.primary,
                ),
                const SizedBox(height: 18),
                const Text(
                  'Crea tu cuenta',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Consulta tus eventos, reservaciones y servicios desde un solo lugar.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        TextField(
                          controller: nombreController,
                          decoration: const InputDecoration(
                            labelText: 'Nombre completo',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Correo',
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
                        const SizedBox(height: 18),
                        ElevatedButton(
                          onPressed: loading ? null : _registrarUsuario,
                          child: Text(
                            loading ? 'Creando cuenta...' : 'Crear usuario',
                          ),
                        ),
                      ],
                    ),
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
