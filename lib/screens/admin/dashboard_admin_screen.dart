import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class DashboardAdminScreen extends StatefulWidget {
  final String empresaId;

  const DashboardAdminScreen({
    super.key,
    required this.empresaId,
  });

  @override
  State<DashboardAdminScreen> createState() => _DashboardAdminScreenState();
}

class _DashboardAdminScreenState extends State<DashboardAdminScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = cargarKpis();
  }

  bool _estaActivoAhora(Map<String, dynamic> data) {
    final now = DateTime.now();
    final estado = (data['estado'] ?? '').toString();
    final inicioTs = data['fechaHoraInicio'];
    final finTs = data['fechaHoraFin'];

    if (estado != 'abierto') return false;
    if (inicioTs == null || finTs == null) return false;

    final inicio = (inicioTs as Timestamp).toDate();
    final fin = (finTs as Timestamp).toDate();

    return now.isAfter(inicio) && now.isBefore(fin);
  }

  bool _esProximo(Map<String, dynamic> data) {
    final now = DateTime.now();
    final estado = (data['estado'] ?? '').toString();
    final inicioTs = data['fechaHoraInicio'];

    if (estado != 'abierto') return false;
    if (inicioTs == null) return false;

    final inicio = (inicioTs as Timestamp).toDate();
    return now.isBefore(inicio);
  }

  Future<Map<String, dynamic>> cargarKpis() async {
    final db = FirebaseFirestore.instance;

    final eventosSnap = await db
        .collection('eventos')
        .where('empresaId', isEqualTo: widget.empresaId)
        .get();

    final eventos = eventosSnap.docs;

    int totalEventos = eventos.length;
    int eventosActivos = 0;
    int eventosProximos = 0;
    int eventosCerrados = 0;
    int totalInvitados = 0;
    int totalAsistentes = 0;
    int totalConsumos = 0;
    int totalFotos = 0;
    int totalRespuestasSatisfaccion = 0;
    int sumaSatisfaccion = 0;

    for (final eventoDoc in eventos) {
      final evento = eventoDoc.data();

      if ((evento['estado'] ?? '') == 'cerrado') {
        eventosCerrados++;
      }
      if (_estaActivoAhora(evento)) {
        eventosActivos++;
      }
      if (_esProximo(evento)) {
        eventosProximos++;
      }
    }

    for (final eventoDoc in eventos) {
      final invitadosSnap = await db
          .collection('eventos')
          .doc(eventoDoc.id)
          .collection('invitados')
          .get();

      totalInvitados += invitadosSnap.docs.length;
      totalAsistentes += invitadosSnap.docs
          .where((d) => (d.data()['estado_asistencia'] ?? '') == 'ingresado')
          .length;

      final consumosSnap = await db
          .collection('eventos')
          .doc(eventoDoc.id)
          .collection('consumos')
          .get();
      totalConsumos += consumosSnap.docs.length;

      final fotosSnap = await db
          .collection('eventos')
          .doc(eventoDoc.id)
          .collection('fotos')
          .get();
      totalFotos += fotosSnap.docs.length;

      final satisfaccionSnap = await db
          .collection('eventos')
          .doc(eventoDoc.id)
          .collection('satisfaccion')
          .get();

      for (final s in satisfaccionSnap.docs) {
        final raw = s.data()['calificacion'];
        final cal = raw is int ? raw : int.tryParse('$raw') ?? 0;
        if (cal > 0) {
          totalRespuestasSatisfaccion++;
          sumaSatisfaccion += cal;
        }
      }
    }

    final promedioSatisfaccion = totalRespuestasSatisfaccion == 0
        ? 0.0
        : sumaSatisfaccion / totalRespuestasSatisfaccion;

    return {
      'totalEventos': totalEventos,
      'eventosActivos': eventosActivos,
      'eventosProximos': eventosProximos,
      'eventosCerrados': eventosCerrados,
      'totalInvitados': totalInvitados,
      'totalAsistentes': totalAsistentes,
      'totalConsumos': totalConsumos,
      'totalFotos': totalFotos,
      'promedioSatisfaccion': promedioSatisfaccion,
      'respuestasSatisfaccion': totalRespuestasSatisfaccion,
    };
  }

  Future<void> _recargar() async {
    setState(() {
      _future = cargarKpis();
    });
    await _future;
  }

  Widget _kpiCard({
    required String titulo,
    required String valor,
    IconData? icono,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (icono != null) ...[
              Icon(icono, size: 28),
              const SizedBox(height: 8),
            ],
            Text(
              valor,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              titulo,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Admin'),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error cargando dashboard: ${snapshot.error}'),
              ),
            );
          }

          final data = snapshot.data ?? {};

          return RefreshIndicator(
            onRefresh: _recargar,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Resumen ejecutivo',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.15,
                  children: [
                    _kpiCard(
                      titulo: 'Eventos totales',
                      valor: '${data['totalEventos'] ?? 0}',
                      icono: Icons.event,
                    ),
                    _kpiCard(
                      titulo: 'Eventos activos ahora',
                      valor: '${data['eventosActivos'] ?? 0}',
                      icono: Icons.play_circle,
                    ),
                    _kpiCard(
                      titulo: 'Eventos próximos',
                      valor: '${data['eventosProximos'] ?? 0}',
                      icono: Icons.schedule,
                    ),
                    _kpiCard(
                      titulo: 'Eventos cerrados',
                      valor: '${data['eventosCerrados'] ?? 0}',
                      icono: Icons.lock,
                    ),
                    _kpiCard(
                      titulo: 'Invitados registrados',
                      valor: '${data['totalInvitados'] ?? 0}',
                      icono: Icons.group,
                    ),
                    _kpiCard(
                      titulo: 'Asistentes reales',
                      valor: '${data['totalAsistentes'] ?? 0}',
                      icono: Icons.verified_user,
                    ),
                    _kpiCard(
                      titulo: 'Consumos',
                      valor: '${data['totalConsumos'] ?? 0}',
                      icono: Icons.restaurant,
                    ),
                    _kpiCard(
                      titulo: 'Fotos',
                      valor: '${data['totalFotos'] ?? 0}',
                      icono: Icons.photo_library,
                    ),
                    _kpiCard(
                      titulo: 'Promedio satisfacción',
                      valor:
                          '${((data['promedioSatisfaccion'] ?? 0.0) as num).toStringAsFixed(1)}',
                      icono: Icons.star,
                    ),
                    _kpiCard(
                      titulo: 'Respuestas satisfacción',
                      valor: '${data['respuestasSatisfaccion'] ?? 0}',
                      icono: Icons.rate_review,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
