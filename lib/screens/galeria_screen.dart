import 'package:flutter/material.dart';

class GaleriaScreen extends StatelessWidget {
  final String eventoId;

  const GaleriaScreen({super.key, required this.eventoId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Galería del evento'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Evento: $eventoId'),
            const SizedBox(height: 20),
            const Text(
              'Aquí irá la galería de fotos del evento.',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
