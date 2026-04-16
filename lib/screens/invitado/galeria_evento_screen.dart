import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class GaleriaEventoScreen extends StatelessWidget {
  final String eventoId;

  const GaleriaEventoScreen({
    super.key,
    required this.eventoId,
  });

  @override
  Widget build(BuildContext context) {
    final fotosRef = FirebaseFirestore.instance
        .collection('eventos')
        .doc(eventoId)
        .collection('fotos')
        .orderBy('timestamp', descending: true);

    return Scaffold(
      appBar: AppBar(title: const Text('Galería del evento')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: fotosRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text('No hay fotos aún'));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final url = data['url_foto'] ?? '';

              return GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => Dialog(
                      child: Image.network(url, fit: BoxFit.cover),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.broken_image),
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
