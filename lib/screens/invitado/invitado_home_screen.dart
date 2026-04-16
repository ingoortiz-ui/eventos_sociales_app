import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'invitado_eventos_screen.dart';

class InvitadoHomeScreen extends StatelessWidget {
  final String nombre;
  final String email;
  final String empresaId;

  const InvitadoHomeScreen({
    super.key,
    required this.nombre,
    required this.email,
    required this.empresaId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invitado'),
        actions: [
          IconButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text('Nombre: $nombre'),
            Text('Email: $email'),
            Text('Empresa: $empresaId'),
            const SizedBox(height: 24),
            const Text(
              'INVITADO HOME OK',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Aquí el invitado verá solo los eventos donde fue registrado.',
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const InvitadoEventosScreen(),
                  ),
                );
              },
              child: const Text('Ver mis eventos'),
            ),
          ],
        ),
      ),
    );
  }
}
