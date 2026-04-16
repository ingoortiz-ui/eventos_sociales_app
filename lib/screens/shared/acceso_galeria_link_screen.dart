import 'package:flutter/material.dart';

import 'galeria_compartida_screen.dart';

class AccesoGaleriaLinkScreen extends StatefulWidget {
  const AccesoGaleriaLinkScreen({super.key});

  @override
  State<AccesoGaleriaLinkScreen> createState() =>
      _AccesoGaleriaLinkScreenState();
}

class _AccesoGaleriaLinkScreenState extends State<AccesoGaleriaLinkScreen> {
  final linkController = TextEditingController();

  String error = '';

  void procesarLink() {
    final link = linkController.text.trim();

    if (!link.contains('evento=') || !link.contains('token=')) {
      setState(() => error = 'Link inválido');
      return;
    }

    try {
      final uri = Uri.parse(link);

      final eventoId = uri.queryParameters['evento'] ?? '';
      final token = uri.queryParameters['token'] ?? '';

      if (eventoId.isEmpty || token.isEmpty) {
        setState(() => error = 'Datos incompletos en el link');
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GaleriaCompartidaScreenDirecto(
            eventoId: eventoId,
            token: token,
          ),
        ),
      );
    } catch (e) {
      setState(() => error = 'Error procesando link');
    }
  }

  @override
  void dispose() {
    linkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Abrir galería compartida'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Pega el link de acceso que te compartieron',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: linkController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'eventosapp://galeria?...',
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: procesarLink,
              child: const Text('Abrir galería'),
            ),
            if (error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  error,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
