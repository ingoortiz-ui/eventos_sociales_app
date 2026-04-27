import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../anfitrion/anfitrion_home_screen.dart';

class UsuarioHomeScreen extends StatelessWidget {
  final String nombre;
  final String email;
  final String empresaId;

  const UsuarioHomeScreen({
    super.key,
    required this.nombre,
    required this.email,
    required this.empresaId,
  });

  Future<void> _cerrarSesion() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio usuario'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _cerrarSesion,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            nombre.isEmpty ? 'Bienvenido' : 'Bienvenido, $nombre',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(email),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: const Icon(Icons.event),
              title: const Text('Mis eventos'),
              subtitle: const Text(
                'Consulta eventos donde eres anfitrión o invitado.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AnfitrionHomeScreen(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          const Card(
            child: ListTile(
              leading: Icon(Icons.restaurant),
              title: Text('Mis reservaciones'),
              subtitle: Text('Próximamente: reservas en restaurantes.'),
            ),
          ),
          const SizedBox(height: 12),
          const Card(
            child: ListTile(
              leading: Icon(Icons.room_service),
              title: Text('Mis servicios'),
              subtitle:
                  Text('Próximamente: servicios, cotizaciones y anticipos.'),
            ),
          ),
        ],
      ),
    );
  }
}
