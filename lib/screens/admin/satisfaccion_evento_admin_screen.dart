import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SatisfaccionEventoAdminScreen extends StatelessWidget {
  final String eventoId;
  final String nombreEvento;

  const SatisfaccionEventoAdminScreen({
    super.key,
    required this.eventoId,
    required this.nombreEvento,
  });

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance
        .collection('eventos')
        .doc(eventoId)
        .collection('satisfaccion');

    return Scaffold(
      appBar: AppBar(
        title: Text('Satisfacción - $nombreEvento'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: ref.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error cargando satisfacción: ${snapshot.error}'),
              ),
            );
          }

          var docs = snapshot.data?.docs ?? [];

          docs.sort((a, b) {
            final aTs = a.data()['createdAt'];
            final bTs = b.data()['createdAt'];

            if (aTs is Timestamp && bTs is Timestamp) {
              return bTs.compareTo(aTs);
            }
            return 0;
          });

          if (docs.isEmpty) {
            return const Center(
              child: Text('Aún no hay respuestas de satisfacción'),
            );
          }

          double suma = 0;
          for (final d in docs) {
            final raw = d.data()['calificacion'];
            final cal = raw is int ? raw : int.tryParse('$raw') ?? 0;
            suma += cal;
          }

          final promedio = suma / docs.length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Promedio: ${promedio.toStringAsFixed(1)} / 5',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...docs.map((doc) {
                final data = doc.data();
                final calificacion = (data['calificacion'] ?? 0).toString();
                final comentario = (data['comentario'] ?? '').toString();
                final gustoMas = (data['gustoMas'] ?? '').toString();
                final sugerencia = (data['sugerencia'] ?? '').toString();

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Calificación: $calificacion / 5',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text('Comentario: $comentario'),
                        const SizedBox(height: 6),
                        Text('Lo que más gustó: $gustoMas'),
                        const SizedBox(height: 6),
                        Text('Sugerencia: $sugerencia'),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
