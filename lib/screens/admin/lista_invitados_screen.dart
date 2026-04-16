import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'invitado_qr_screen.dart';

class ListaInvitadosScreen extends StatelessWidget {
  final String eventoId;

  const ListaInvitadosScreen({
    super.key,
    required this.eventoId,
  });

  @override
  Widget build(BuildContext context) {
    final invitadosRef = FirebaseFirestore.instance
        .collection('eventos')
        .doc(eventoId)
        .collection('invitados')
        .orderBy('nombre_invitado');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invitados del evento'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: invitadosRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error cargando invitados: ${snapshot.error}'),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Text('No hay invitados registrados'),
            );
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();

              final nombre = (data['nombre_invitado'] ?? '').toString();
              final mesa = (data['mesa'] ?? '').toString();
              final invitadoDe = (data['invitadoDe'] ?? '').toString();
              final estado =
                  (data['estado_asistencia'] ?? 'pendiente').toString();
              final qrCode = (data['qr_code'] ?? '').toString();

              return ListTile(
                title: Text(nombre),
                subtitle: Text(
                  invitadoDe.isEmpty
                      ? 'Mesa: $mesa'
                      : 'Mesa: $mesa • Invitado de: $invitadoDe',
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      estado,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: estado == 'ingresado'
                            ? Colors.green
                            : Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Icon(Icons.qr_code),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => InvitadoQrScreen(
                        nombre: nombre,
                        mesa: mesa,
                        invitadoDe: invitadoDe,
                        qrData: qrCode,
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
