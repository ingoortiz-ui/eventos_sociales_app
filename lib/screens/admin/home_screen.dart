import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'crear_usuario_screen.dart';
import 'crear_evento_screen.dart';
import 'dashboard_admin_screen.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrador'),
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
              'ADMIN HOME OK',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          DashboardAdminScreen(empresaId: empresaId),
                    ),
                  );
                },
                child: const Text('Dashboard KPI'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CrearUsuarioScreen(empresaId: empresaId),
                    ),
                  );
                },
                child: const Text('Crear usuario'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CrearEventoScreen(empresaId: empresaId),
                    ),
                  );
                },
                child: const Text('Crear evento'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          TableroEventosAdminScreen(empresaId: empresaId),
                    ),
                  );
                },
                child: const Text('Consultar eventos'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          LeadsCotizacionScreen(empresaId: empresaId),
                    ),
                  );
                },
                child: const Text('Leads de cotización'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
