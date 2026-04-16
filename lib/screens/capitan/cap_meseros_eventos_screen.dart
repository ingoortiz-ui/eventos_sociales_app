import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'cap_meseros_consumo_screen.dart';

class CapMeserosEventosScreen extends StatelessWidget {
  final String empresaId;

  const CapMeserosEventosScreen({
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

  String _rangoHorario(Map<String, dynamic> data) {
    final inicioTs = data['fechaHoraInicio'];
    final finTs = data['fechaHoraFin'];

    if (inicioTs == null || finTs == null) return 'Horario no definido';

    final inicio = (inicioTs as Timestamp).toDate();
    final fin = (finTs as Timestamp).toDate();

    String two(int n) => n.toString().padLeft(2, '0');

    return '${inicio.day}/${inicio.month}/${inicio.year} '
        '${two(inicio.hour)}:${two(inicio.minute)} - '
        '${two(fin.hour)}:${two(fin.minute)}';
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
              child: Text('No hay eventos abiertos para capturar consumos'),
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
              final horario = _rangoHorario(data);
              final estadoVisible =
                  activo ? 'Activo ahora' : 'Fuera de horario';

              return ListTile(
                title: Text(nombreEvento),
                subtitle: Text(
                  '$tipoEvento • $lugar\n$horario\n$estadoVisible',
                ),
                isThreeLine: true,
                trailing: Icon(
                  Icons.restaurant_menu,
                  color: activo ? null : Colors.grey,
                ),
                onTap: activo
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CapMeserosConsumoScreen(
                              eventoId: doc.id,
                              empresaId: empresaId,
                              nombreEvento: nombreEvento,
                              horarioEvento: horario,
                              estadoVisible: estadoVisible,
                            ),
                          ),
                        );
                      }
                    : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Este evento está fuera de horario. Solo puedes capturar consumos durante el horario del evento.',
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
