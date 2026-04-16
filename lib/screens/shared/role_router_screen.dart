import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../admin/home_screen.dart';
import '../capitan/cap_meseros_home_screen.dart';
import '../hostess/hostess_home_screen.dart';
import '../invitado/invitado_home_screen.dart';
import 'login_screen.dart';

class RoleRouterScreen extends StatelessWidget {
  const RoleRouterScreen({super.key});

  String _normalizeEmail(String email) => email.trim().toLowerCase();

  Future<Map<String, dynamic>?> _resolveUserConfig(User user) async {
    final db = FirebaseFirestore.instance;

    final uidDoc = await db.collection('usuarios').doc(user.uid).get();
    if (uidDoc.exists) {
      return uidDoc.data();
    }

    final email = user.email;
    if (email == null || email.trim().isEmpty) return null;

    final emailKey = _normalizeEmail(email);
    final configDoc =
        await db.collection('usuarios_config').doc(emailKey).get();

    if (!configDoc.exists) return null;

    final data = configDoc.data() ?? {};

    final userData = {
      ...data,
      'uid': user.uid,
      'email': emailKey,
      'migratedAt': FieldValue.serverTimestamp(),
    };

    await db
        .collection('usuarios')
        .doc(user.uid)
        .set(userData, SetOptions(merge: true));

    return userData;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const LoginScreen();
    }

    return FutureBuilder<Map<String, dynamic>?>(
      future: _resolveUserConfig(user),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Error de acceso')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error consultando usuario: ${snapshot.error}'),
              ),
            ),
          );
        }

        final data = snapshot.data;

        if (data == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Usuario sin configuración')),
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Tu usuario no tiene configuración en Firestore.'),
                  const SizedBox(height: 12),
                  SelectableText('UID: ${user.uid}'),
                  const SizedBox(height: 8),
                  SelectableText('Email: ${user.email ?? "sin email"}'),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                    },
                    child: const Text('Cerrar sesión'),
                  ),
                ],
              ),
            ),
          );
        }

        final rol = (data['rol'] ?? '').toString().trim();
        final activo = data['activo'] == true;
        final empresaId = (data['empresaId'] ?? '').toString();
        final nombre = (data['nombre'] ?? '').toString();
        final email = (data['email'] ?? user.email ?? '').toString();

        if (!activo) {
          return Scaffold(
            appBar: AppBar(title: const Text('Usuario inactivo')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Tu usuario está inactivo.'),
                    const SizedBox(height: 12),
                    SelectableText('Empresa: $empresaId'),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                      },
                      child: const Text('Cerrar sesión'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        switch (rol) {
          case 'admin':
            return AdminHomeScreen(
              nombre: nombre,
              email: email,
              empresaId: empresaId,
            );
          case 'hostess':
            return HostessHomeScreen(
              nombre: nombre,
              email: email,
              empresaId: empresaId,
            );
          case 'cap_meseros':
            return CapMeserosHomeScreen(
              nombre: nombre,
              email: email,
              empresaId: empresaId,
            );
          case 'invitado':
            return InvitadoHomeScreen(
              nombre: nombre,
              email: email,
              empresaId: empresaId,
            );
          default:
            return Scaffold(
              appBar: AppBar(title: const Text('Rol no válido')),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Rol no válido: $rol'),
                ),
              ),
            );
        }
      },
    );
  }
}
