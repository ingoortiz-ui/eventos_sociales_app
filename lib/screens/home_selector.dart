import 'package:flutter/material.dart';

// Organizador (lo creamos enseguida)
import 'organizador/crear_evento.dart';

// Las pantallas que ya tienes:
import 'admin/crear_invitado.dart';
import 'hostess/scanner.dart';

class HomeSelectorScreen extends StatelessWidget {
  const HomeSelectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Eventos Sociales')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 12),

            // ORGANIZADOR
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CrearEventoScreen()),
                  );
                },
                child: const Text('Organizador (crear / administrar evento)'),
              ),
            ),

            const SizedBox(height: 12),

            // ACCESO / CHECK-IN (por ahora pide eventId manual, luego lo elegimos por lista)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  const eventoId = 'ME4H5mOF6MrVIXzke1XW'; // temporal
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ScannerScreen(eventoId: eventoId),
                    ),
                  );
                },
                child: const Text('Acceso (escanear QR / check-in)'),
              ),
            ),

            const SizedBox(height: 12),

            // INVITADO (por ahora temporal)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  const eventoId = 'ME4H5mOF6MrVIXzke1XW'; // temporal
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CrearInvitadoScreen(eventoId: eventoId),
                    ),
                  );
                },
                child:
                    const Text('Invitado (galería / subir fotos) - temporal'),
              ),
            ),

            const Spacer(),
            const Text(
              'Siguiente: lista de eventos + selección por rol.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
