import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
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

  Widget _opcion({
    required IconData icon,
    required String titulo,
    required String subtitulo,
    required VoidCallback? onTap,
  }) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primary.withOpacity(0.10),
          child: Icon(icon, color: AppTheme.primary),
        ),
        title: Text(
          titulo,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(subtitulo),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nombreVisible = nombre.isEmpty ? 'Usuario' : nombre;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Inicio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _cerrarSesion,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  AppTheme.primary,
                  AppTheme.secondary,
                ],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.account_circle_outlined,
                  color: Colors.white,
                  size: 54,
                ),
                const SizedBox(height: 12),
                Text(
                  'Hola, $nombreVisible',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Consulta tus eventos, reservaciones y servicios desde un solo lugar.',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Tus accesos',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          _opcion(
            icon: Icons.event_available,
            titulo: 'Mis eventos',
            subtitulo: 'Eventos donde eres anfitrión o invitado.',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AnfitrionHomeScreen(),
                ),
              );
            },
          ),
          _opcion(
            icon: Icons.restaurant_outlined,
            titulo: 'Mis reservaciones',
            subtitulo: 'Próximamente: reservas en restaurantes.',
            onTap: null,
          ),
          _opcion(
            icon: Icons.room_service_outlined,
            titulo: 'Mis servicios',
            subtitulo: 'Próximamente: cotizaciones, agenda y anticipos.',
            onTap: null,
          ),
          const SizedBox(height: 20),
          const Text(
            'Disponible próximamente',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'En esta cuenta podrás consultar reservaciones en restaurantes, '
                'servicios contratados, cotizaciones, anticipos e historial.',
                style: TextStyle(color: AppTheme.textMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
