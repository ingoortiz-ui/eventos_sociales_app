import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'registro_empresa_screen.dart';
import 'registro_usuario_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;

  Future<void> _login() async {
    final email = emailController.text.trim().toLowerCase();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa correo y contraseña')),
      );
      return;
    }

    setState(() => loading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      String mensaje = 'Error al iniciar sesión';

      if (e.code == 'user-not-found') {
        mensaje = 'Usuario no encontrado';
      } else if (e.code == 'wrong-password') {
        mensaje = 'Contraseña incorrecta';
      } else if (e.code == 'invalid-email') {
        mensaje = 'Correo inválido';
      } else if (e.code == 'invalid-credential') {
        mensaje = 'Correo o contraseña incorrectos';
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

  void _abrirRegistroEmpresa() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const RegistroEmpresaScreen(),
      ),
    );
  }

  void _abrirRegistroUsuario() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const RegistroUsuarioScreen(),
      ),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.10),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.event_available,
                      size: 74,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Eventia',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Eventos, reservaciones y servicios en una sola plataforma.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Iniciar sesión',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textDark,
                            ),
                          ),
                          const SizedBox(height: 16),
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
                            onSubmitted: (_) {
                              if (!loading) _login();
                            },
                          ),
                          const SizedBox(height: 18),
                          ElevatedButton(
                            onPressed: loading ? null : _login,
                            child: Text(
                              loading ? 'Ingresando...' : 'Ingresar',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    '¿Qué deseas crear?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.business_outlined),
                    label: const Text('Crear empresa'),
                    onPressed: loading ? null : _abrirRegistroEmpresa,
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: const Text('Crear usuario'),
                    onPressed: loading ? null : _abrirRegistroUsuario,
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Empresas gestionan eventos, reservas y servicios.\n'
                    'Usuarios consultan invitaciones, reservaciones y cotizaciones.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
