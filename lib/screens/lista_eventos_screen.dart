import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'panel_evento_screen.dart';

class ListaEventosScreen extends StatelessWidget {
  final String empresaId;

  const ListaEventosScreen({
    super.key,
    required this.empresaId,
  });

  bool _eventoActivo(Map<String, dynamic> data) {
    final now = DateTime.now();

    final inicioTs = data['fechaHoraInicio'];
    final finTs = data['fechaHoraFin'];
    final estado = (data['estado'] ?? '').toString();

    if (estado != 'abierto') return false;
    if (inicioTs == null || finTs == null) return false;

    final inicio = (inicioTs as Timestamp).toDate();
    final fin = (finTs as Timestamp).toDate();

    return now.isAfter(inicio) && now.isBefore(fin);
  }

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('eventos')
        .where('empresaId', isEqualTo: empresaId)
        .where('estado', isEqualTo: 'abierto');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Eventos abiertos'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
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

          if (docs.isEmpty) {
            return const Center(
              child: Text('No hay eventos abiertos'),
            );
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();

              final nombreEvento = (data['nombreEvento'] ?? '').toString();
              final tipoEvento = (data['tipoEvento'] ?? '').toString();
              final lugar = (data['lugar'] ?? '').toString();
              final activo = _eventoActivo(data);

              return ListTile(
                title: Text(nombreEvento),
                subtitle: Text(
                  '$tipoEvento • $lugar\n${activo ? "Activo ahora" : "Fuera de horario"}',
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
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
                },
              );
            },
          );
        },
      ),
    );
  }
}
