import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'owner_detalle_lista_screen.dart';

class OwnerHomeScreen extends StatelessWidget {
  final String nombre;
  final String email;

  const OwnerHomeScreen({
    super.key,
    required this.nombre,
    required this.email,
  });

  Future<void> _cerrarSesion() async {
    await FirebaseAuth.instance.signOut();
  }

  void _abrirDetalle(
    BuildContext context, {
    required String titulo,
    required String tipo,
    String? filtroEstado,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OwnerDetalleListaScreen(
          titulo: titulo,
          tipo: tipo,
          filtroEstado: filtroEstado,
        ),
      ),
    );
  }

  Widget _metricCard({
    required BuildContext context,
    required String titulo,
    required String valor,
    required IconData icon,
    required Color color,
    required String detalleTitulo,
    required String tipo,
    String? filtroEstado,
  }) {
    return Expanded(
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _abrirDetalle(
            context,
            titulo: detalleTitulo,
            tipo: tipo,
            filtroEstado: filtroEstado,
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.12),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(height: 10),
                Text(
                  valor,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textDark,
                  ),
                ),
                Text(
                  titulo,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Ver detalle',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _cargarMetricas() async {
    final empresasSnap =
        await FirebaseFirestore.instance.collection('empresas').get();

    final eventosSnap =
        await FirebaseFirestore.instance.collection('eventos').get();

    final leadsSnap =
        await FirebaseFirestore.instance.collection('leads_cotizacion').get();

    int empresasEventos = 0;
    int empresasRestaurante = 0;
    int empresasServicios = 0;

    for (final doc in empresasSnap.docs) {
      final data = doc.data();
      final giros = (data['giros'] as List?) ?? [];

      if (giros.contains('eventos')) empresasEventos++;
      if (giros.contains('restaurante')) empresasRestaurante++;
      if (giros.contains('servicios')) empresasServicios++;
    }

    int leadsNuevos = 0;
    int leadsGanados = 0;
    int leadsCotizados = 0;
    int leadsPerdidos = 0;

    num montoEstimado = 0;
    num comisionEstimada = 0;

    for (final doc in leadsSnap.docs) {
      final data = doc.data();
      final estado = (data['estado'] ?? 'nuevo').toString();

      if (estado == 'nuevo') leadsNuevos++;
      if (estado == 'ganado') leadsGanados++;
      if (estado == 'cotizado') leadsCotizados++;
      if (estado == 'perdido') leadsPerdidos++;

      final monto = data['montoEstimado'];
      final presupuesto = data['presupuestoEstimado'];
      final comision = data['comisionApp'];

      if (monto is num) {
        montoEstimado += monto;
      } else if (presupuesto is num) {
        montoEstimado += presupuesto;
      }

      if (comision is num) {
        comisionEstimada += comision;
      }
    }

    return {
      'empresas': empresasSnap.docs.length,
      'eventos': eventosSnap.docs.length,
      'leads': leadsSnap.docs.length,
      'empresasEventos': empresasEventos,
      'empresasRestaurante': empresasRestaurante,
      'empresasServicios': empresasServicios,
      'leadsNuevos': leadsNuevos,
      'leadsGanados': leadsGanados,
      'leadsCotizados': leadsCotizados,
      'leadsPerdidos': leadsPerdidos,
      'montoEstimado': montoEstimado,
      'comisionEstimada': comisionEstimada,
    };
  }

  String _moneda(num value) {
    return '\$${value.toStringAsFixed(2)}';
  }

  Widget _moduloCard({
    required BuildContext context,
    required IconData icon,
    required String titulo,
    required String descripcion,
    required String dato,
    required Color color,
    required String tipo,
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
        subtitle: Text(descripcion),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              dato,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            const Text(
              'Ver',
              style: TextStyle(
                color: AppTheme.primary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        onTap: () {
          if (tipo == 'eventos') {
            _abrirDetalle(
              context,
              titulo: 'Empresas con módulo eventos',
              tipo: 'empresas',
            );
          } else if (tipo == 'restaurante') {
            _abrirDetalle(
              context,
              titulo: 'Empresas con módulo restaurante',
              tipo: 'empresas',
            );
          } else if (tipo == 'servicios') {
            _abrirDetalle(
              context,
              titulo: 'Empresas con módulo servicios',
              tipo: 'empresas',
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nombreVisible = nombre.isEmpty ? 'Dueño de la app' : nombre;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Panel dueño app'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _cerrarSesion,
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _cargarMetricas(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error cargando métricas: ${snapshot.error}'),
              ),
            );
          }

          final data = snapshot.data ?? {};

          final empresas = data['empresas'] ?? 0;
          final eventos = data['eventos'] ?? 0;
          final leads = data['leads'] ?? 0;
          final leadsNuevos = data['leadsNuevos'] ?? 0;
          final leadsGanados = data['leadsGanados'] ?? 0;
          final leadsCotizados = data['leadsCotizados'] ?? 0;
          final leadsPerdidos = data['leadsPerdidos'] ?? 0;
          final montoEstimado = (data['montoEstimado'] ?? 0) as num;
          final comisionEstimada = (data['comisionEstimada'] ?? 0) as num;

          return ListView(
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
                      Icons.insights_outlined,
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
                      'Consulta comportamiento estratégico de empresas, eventos, cotizaciones y módulos de monetización.',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Resumen general',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _metricCard(
                    context: context,
                    titulo: 'Empresas',
                    valor: '$empresas',
                    icon: Icons.business_outlined,
                    color: AppTheme.primary,
                    detalleTitulo: 'Detalle de empresas',
                    tipo: 'empresas',
                  ),
                  const SizedBox(width: 8),
                  _metricCard(
                    context: context,
                    titulo: 'Eventos',
                    valor: '$eventos',
                    icon: Icons.event_available,
                    color: AppTheme.success,
                    detalleTitulo: 'Detalle de eventos',
                    tipo: 'eventos',
                  ),
                ],
              ),
              Row(
                children: [
                  _metricCard(
                    context: context,
                    titulo: 'Cotizaciones',
                    valor: '$leads',
                    icon: Icons.request_quote_outlined,
                    color: AppTheme.warning,
                    detalleTitulo: 'Todas las cotizaciones',
                    tipo: 'leads',
                  ),
                  const SizedBox(width: 8),
                  _metricCard(
                    context: context,
                    titulo: 'Ganadas',
                    valor: '$leadsGanados',
                    icon: Icons.check_circle_outline,
                    color: AppTheme.success,
                    detalleTitulo: 'Cotizaciones ganadas',
                    tipo: 'leads',
                    filtroEstado: 'ganado',
                  ),
                ],
              ),
              Row(
                children: [
                  _metricCard(
                    context: context,
                    titulo: 'Nuevas',
                    valor: '$leadsNuevos',
                    icon: Icons.fiber_new_outlined,
                    color: AppTheme.primary,
                    detalleTitulo: 'Cotizaciones nuevas',
                    tipo: 'leads',
                    filtroEstado: 'nuevo',
                  ),
                  const SizedBox(width: 8),
                  _metricCard(
                    context: context,
                    titulo: 'Cotizadas',
                    valor: '$leadsCotizados',
                    icon: Icons.request_quote,
                    color: AppTheme.secondary,
                    detalleTitulo: 'Cotizaciones cotizadas',
                    tipo: 'leads',
                    filtroEstado: 'cotizado',
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Monetización estimada',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _metricCard(
                    context: context,
                    titulo: 'Monto estimado',
                    valor: _moneda(montoEstimado),
                    icon: Icons.payments_outlined,
                    color: AppTheme.secondary,
                    detalleTitulo: 'Cotizaciones con monto',
                    tipo: 'leads',
                  ),
                  const SizedBox(width: 8),
                  _metricCard(
                    context: context,
                    titulo: 'Comisión app',
                    valor: _moneda(comisionEstimada),
                    icon: Icons.percent,
                    color: AppTheme.primary,
                    detalleTitulo: 'Comisiones estimadas',
                    tipo: 'leads',
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Comportamiento por módulo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              _moduloCard(
                context: context,
                icon: Icons.event_available,
                titulo: 'Eventos',
                descripcion:
                    'Empresas que usan gestión de eventos, invitados, QR y reportes.',
                dato: '${data['empresasEventos'] ?? 0}',
                color: AppTheme.primary,
                tipo: 'eventos',
              ),
              _moduloCard(
                context: context,
                icon: Icons.restaurant_outlined,
                titulo: 'Restaurantes',
                descripcion:
                    'Empresas con giro restaurante para futuras reservaciones.',
                dato: '${data['empresasRestaurante'] ?? 0}',
                color: AppTheme.secondary,
                tipo: 'restaurante',
              ),
              _moduloCard(
                context: context,
                icon: Icons.room_service_outlined,
                titulo: 'Servicios',
                descripcion:
                    'Empresas prestadoras de servicios para agenda, anticipos y cotización.',
                dato: '${data['empresasServicios'] ?? 0}',
                color: AppTheme.warning,
                tipo: 'servicios',
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Leads nuevos pendientes: $leadsNuevos\n'
                    'Leads perdidos: $leadsPerdidos\n'
                    'Este panel será la base para medir empresas activas, ingresos por comisión, pagos, reservas, servicios y comportamiento estratégico por módulo.',
                    style: const TextStyle(color: AppTheme.textMuted),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
