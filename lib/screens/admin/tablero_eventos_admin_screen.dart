import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'panel_evento_screen.dart';
import 'reporte_evento_screen.dart';

class TableroEventosAdminScreen extends StatelessWidget {
  final String empresaId;

  const TableroEventosAdminScreen({
    super.key,
    required this.empresaId,
  });

  bool _estaActivoEnHorario(Map<String, dynamic> data) {
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

  bool _finalizadoSinCerrar(Map<String, dynamic> data) {
    final now = DateTime.now();
    final estado = (data['estado'] ?? '').toString();
    final finTs = data['fechaHoraFin'];

    if (estado != 'abierto') return false;
    if (finTs == null) return false;

    final fin = (finTs as Timestamp).toDate();
    return now.isAfter(fin);
  }

  String _rangoHorario(Map<String, dynamic> data) {
    final inicioTs = data['fechaHoraInicio'];
    final finTs = data['fechaHoraFin'];

    if (inicioTs == null || finTs == null) return 'Horario no definido';

    final inicio = (inicioTs as Timestamp).toDate();
    final fin = (finTs as Timestamp).toDate();

    String two(int n) => n.toString().padLeft(2, '0');

    return '${inicio.day}/${inicio.month}/${inicio.year} ${two(inicio.hour)}:${two(inicio.minute)}'
        ' - ${two(fin.hour)}:${two(fin.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final eventosRef = FirebaseFirestore.instance
        .collection('eventos')
        .where('empresaId', isEqualTo: empresaId);

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tablero de eventos'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Activos'),
              Tab(text: 'Próximos'),
              Tab(text: 'Finalizados'),
              Tab(text: 'Cerrados'),
              Tab(text: 'Archivados'),
            ],
          ),
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: eventosRef.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Error cargando eventos: ${snapshot.error}'),
                ),
              );
            }

            final docs = snapshot.data?.docs ?? [];

            final activos =
                docs.where((d) => _estaActivoEnHorario(d.data())).toList();
            final proximos = docs.where((d) => _esProximo(d.data())).toList();
            final finalizados =
                docs.where((d) => _finalizadoSinCerrar(d.data())).toList();
            final cerrados = docs
                .where(
                    (d) => (d.data()['estado'] ?? '').toString() == 'cerrado')
                .toList();
            final archivados = docs
                .where(
                    (d) => (d.data()['estado'] ?? '').toString() == 'archivado')
                .toList();

            return TabBarView(
              children: [
                _listaEventos(context, activos, empresaId, 'panel'),
                _listaEventos(context, proximos, empresaId, 'panel'),
                _listaEventos(context, finalizados, empresaId, 'panel'),
                _listaEventos(context, cerrados, empresaId, 'reporte'),
                _listaEventos(context, archivados, empresaId, 'panel'),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _listaEventos(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String empresaId,
    String modo,
  ) {
    if (docs.isEmpty) {
      return const Center(child: Text('No hay eventos en esta categoría'));
    }

    return ListView.separated(
      itemCount: docs.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final doc = docs[index];
        final data = doc.data();

        final nombreEvento = (data['nombreEvento'] ?? '').toString();
        final tipoEvento = (data['tipoEvento'] ?? '').toString();
        final lugar = (data['lugar'] ?? '').toString();
        final estado = (data['estado'] ?? '').toString();
        final horario = _rangoHorario(data);

        return ListTile(
          title: Text(nombreEvento),
          subtitle: Text('$tipoEvento • $lugar\n$horario\nEstado: $estado'),
          isThreeLine: true,
          trailing: Icon(
            modo == 'reporte' ? Icons.assessment : Icons.arrow_forward_ios,
          ),
          onTap: () {
            if (modo == 'reporte') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReporteEventoScreen(
                    eventoId: doc.id,
                    empresaId: empresaId,
                  ),
                ),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PanelEventoScreen(
                    eventoId: doc.id,
                    empresaId: empresaId,
                    nombreEvento: nombreEvento,
                  ),
                ),
              );
            }
          },
        );
      },
    );
  }
}
