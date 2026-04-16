import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class LeadsCotizacionScreen extends StatelessWidget {
  final String empresaId;

  const LeadsCotizacionScreen({
    super.key,
    required this.empresaId,
  });

  String _fechaTexto(Map<String, dynamic> data) {
    final texto = (data['fechaEstimadaTexto'] ?? '').toString();
    if (texto.isNotEmpty) return texto;

    final ts = data['fechaEstimada'];
    if (ts is Timestamp) {
      final d = ts.toDate();
      return '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/'
          '${d.year}';
    }

    return 'Sin fecha';
  }

  @override
  Widget build(BuildContext context) {
    final leadsRef = FirebaseFirestore.instance
        .collection('leads_cotizacion')
        .where('empresaId', isEqualTo: empresaId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leads de cotización'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: leadsRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error cargando leads: ${snapshot.error}'),
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
              child: Text('No hay leads de cotización aún'),
            );
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final data = docs[index].data();

              final nombre = (data['nombre'] ?? '').toString();
              final telefono = (data['telefono'] ?? '').toString();
              final email = (data['email'] ?? '').toString();
              final tipoEvento = (data['tipoEvento'] ?? '').toString();
              final fechaEstimada = _fechaTexto(data);
              final invitadosEstimados =
                  (data['invitadosEstimados'] ?? '').toString();
              final estado = (data['estado'] ?? 'nuevo').toString();

              return ListTile(
                title: Text(nombre),
                subtitle: Text(
                  '$tipoEvento • $telefono\n$email\nFecha estimada: $fechaEstimada • Invitados: $invitadosEstimados',
                ),
                isThreeLine: true,
                trailing: Text(
                  estado,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
