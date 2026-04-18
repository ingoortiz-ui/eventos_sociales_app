import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'scanner.dart';
import 'ver_croquis_screen.dart';

class HostessEventosScreen extends StatelessWidget {
  final String empresaId;

  const HostessEventosScreen({
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
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No hay eventos abiertos en este momento.'),
              ),
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
              final croquisUrl = (data['croquisUrl'] ?? '').toString();
              final activo = _eventoActivo(data);
              final horario = _rangoHorario(data);
              final estadoVisible =
                  activo ? 'Activo ahora' : 'Fuera de horario';

              return Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      ListTile(
                        title: Text(nombreEvento),
                        subtitle: Text(
                          '$tipoEvento • $lugar\n$horario\n$estadoVisible',
                        ),
                        isThreeLine: true,
                        trailing: Icon(
                          Icons.qr_code_scanner,
                          color: activo ? null : Colors.grey,
                        ),
                        onTap: activo
                            ? () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ScannerScreen(
                                      eventoId: doc.id,
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
                                      'Este evento está fuera de horario. Solo puedes escanear durante el horario del evento.',
                                    ),
                                  ),
                                );
                              },
                      ),
                      if (croquisUrl.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 16,
                            right: 16,
                            bottom: 12,
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => VerCroquisScreen(
                                      nombreEvento: nombreEvento,
                                      croquisUrl: croquisUrl,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.map),
                              label: const Text('Ver croquis de mesas'),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
