import 'package:flutter/material.dart';

class VerCroquisScreen extends StatelessWidget {
  final String nombreEvento;
  final String croquisUrl;

  const VerCroquisScreen({
    super.key,
    required this.nombreEvento,
    required this.croquisUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Croquis - $nombreEvento'),
      ),
      body: croquisUrl.isEmpty
          ? const Center(
              child: Text('Este evento no tiene croquis disponible'),
            )
          : InteractiveViewer(
              child: Center(
                child: Image.network(croquisUrl),
              ),
            ),
    );
  }
}
