import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'crear_evento_screen.dart';
import 'leads_cotizacion_screen.dart';
import 'tablero_eventos_admin_screen.dart';

class AdminHomeScreen extends StatelessWidget {
  final String nombre;
  final String email;
  final String empresaId;

  const AdminHomeScreen({
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
    required VoidCallback onTap,
    Color color = AppTheme.primary,
  }) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.12),
          child: Icon(icon, color: color),
        ),
        title: Text(
          titulo,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(subtitulo),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nombreVisible = nombre.isEmpty ? 'Administrador' : nombre;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Panel administrador'),
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
                  Icons.admin_panel_settings_outlined,
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
                  'Administra eventos, cotizaciones, invitados, anfitriones y reportes de tu empresa.',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Gestión principal',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          _opcion(
            icon: Icons.dashboard_outlined,
            titulo: 'Dashboard de eventos',
            subtitulo:
                'Consulta eventos activos, próximos, finalizados y cerrados.',
            color: AppTheme.primary,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TableroEventosAdminScreen(
                    empresaId: empresaId,
                  ),
                ),
              );
            },
          ),
          _opcion(
            icon: Icons.add_circle_outline,
            titulo: 'Crear evento',
            subtitulo:
                'Registra un nuevo evento, invitados y configuración inicial.',
            color: AppTheme.success,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CrearEventoScreen(
                    empresaId: empresaId,
                  ),
                ),
              );
            },
          ),
          _opcion(
            icon: Icons.request_quote_outlined,
            titulo: 'Cotizaciones de eventos',
            subtitulo:
                'Gestiona solicitudes nuevas, cotizadas, ganadas y perdidas.',
            color: AppTheme.warning,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LeadsCotizacionScreen(
                    empresaId: empresaId,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 22),
          const Text(
            'Módulos próximos',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          _opcion(
            icon: Icons.restaurant_outlined,
            titulo: 'Reservaciones restaurante',
            subtitulo:
                'Próximamente: calendario, mesas, consumo estimado y comisión.',
            color: AppTheme.secondary,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Módulo de reservaciones próximamente'),
                ),
              );
            },
          ),
          _opcion(
            icon: Icons.room_service_outlined,
            titulo: 'Servicios',
            subtitulo:
                'Próximamente: cotizaciones, anticipos, agenda y comisión.',
            color: AppTheme.primary,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Módulo de servicios próximamente'),
                ),
              );
            },
          ),
          const SizedBox(height: 22),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Nota estratégica: el dueño de la app tendrá un panel independiente para ver comportamiento por empresa, módulos activos, cotizaciones, eventos, reservaciones, servicios, ingresos estimados y comisiones.',
                style: TextStyle(color: AppTheme.textMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
