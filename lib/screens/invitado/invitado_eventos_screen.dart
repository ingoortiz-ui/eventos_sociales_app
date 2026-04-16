import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'invitado_evento_detalle_screen.dart';

class InvitadoEventosScreen extends StatelessWidget {
  const InvitadoEventosScreen({super.key});

  Future<List<Map<String, dynamic>>> cargarEventosInvitado() async {
    final user = FirebaseAuth.instance.currentUser;
    final email = (user?.email ?? '').trim().toLowerCase();

    if (email.isEmpty) return [];

    final uid = user!.uid;
    final userDoc =
        await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();

    if (!userDoc.exists) return [];

    final userData = userDoc.data() ?? {};
    final empresaId = (userData['empresaId'] ?? '').toString();

    if (empresaId.isEmpty) return [];

    final eventosSnap = await FirebaseFirestore.instance
        .collection('eventos')
        .where('empresaId', isEqualTo: empresaId)
        .where('estado', isEqualTo: 'abierto')
        .get();

    final List<Map<String, dynamic>> resultados = [];

    for (final eventoDoc in eventosSnap.docs) {
      final invitadoSnap = await FirebaseFirestore.instance
          .collection('eventos')
          .doc(eventoDoc.id)
          .collection('invitados')
          .where('email_invitado', isEqualTo: email)
          .limit(1)
          .get();

      if (invitadoSnap.docs.isEmpty) continue;

      final invitadoDoc = invitadoSnap.docs.first;

      resultados.add({
        'eventoId': eventoDoc.id,
        'evento': eventoDoc.data(),
        'invitadoId': invitadoDoc.id,
        'invitado': invitadoDoc.data(),
      });
    }

    return resultados;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis eventos'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: cargarEventosInvitado(),
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

          final items = snapshot.data ?? [];

          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No tienes eventos abiertos asignados'),
              ),
            );
          }

          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final item = items[index];
              final evento = item['evento'] as Map<String, dynamic>;
              final invitado = item['invitado'] as Map<String, dynamic>;

              final nombreEvento = (evento['nombreEvento'] ?? '').toString();
              final tipoEvento = (evento['tipoEvento'] ?? '').toString();
              final lugar = (evento['lugar'] ?? '').toString();
              final mesa = (invitado['mesa'] ?? '').toString();
              final estadoAsistencia =
                  (invitado['estado_asistencia'] ?? 'pendiente').toString();

              return ListTile(
                title: Text(nombreEvento),
                subtitle: Text('$tipoEvento • $lugar • Mesa $mesa'),
                trailing: Text(
                  estadoAsistencia,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: estadoAsistencia == 'ingresado'
                        ? Colors.green
                        : Colors.orange,
                  ),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => InvitadoEventoDetalleScreen(
                        eventoId: item['eventoId'].toString(),
                        invitadoId: item['invitadoId'].toString(),
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
