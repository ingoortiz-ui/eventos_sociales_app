import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../invitado/galeria_evento_screen.dart';

class ReporteEventoScreen extends StatelessWidget {
  final String eventoId;
  final String empresaId;

  const ReporteEventoScreen({
    super.key,
    required this.eventoId,
    required this.empresaId,
  });

  Future<Map<String, dynamic>> cargarReporte() async {
    final db = FirebaseFirestore.instance;

    final eventoDoc = await db.collection('eventos').doc(eventoId).get();
    final invitadosSnap = await db
        .collection('eventos')
        .doc(eventoId)
        .collection('invitados')
        .get();
    final consumosSnap = await db
        .collection('eventos')
        .doc(eventoId)
        .collection('consumos')
        .get();
    final fotosSnap =
        await db.collection('eventos').doc(eventoId).collection('fotos').get();

    final evento = eventoDoc.data() ?? {};

    final totalInvitados = invitadosSnap.docs.length;
    final ingresados = invitadosSnap.docs
        .where((d) => (d.data()['estado_asistencia'] ?? '') == 'ingresado')
        .length;
    final faltantes = totalInvitados - ingresados;

    int totalPlatillos = 0;
    int totalBebidas = 0;

    for (final doc in consumosSnap.docs) {
      final data = doc.data();
      final tipo = (data['tipo'] ?? '').toString();
      final cantidadDynamic = data['cantidad'];
      final cantidad = cantidadDynamic is int
          ? cantidadDynamic
          : int.tryParse(cantidadDynamic.toString()) ?? 0;

      if (tipo == 'platillo') {
        totalPlatillos += cantidad;
      } else if (tipo == 'bebida') {
        totalBebidas += cantidad;
      }
    }

    return {
      'evento': evento,
      'totalInvitados': totalInvitados,
      'ingresados': ingresados,
      'faltantes': faltantes,
      'totalPlatillos': totalPlatillos,
      'totalBebidas': totalBebidas,
      'totalConsumos': consumosSnap.docs.length,
      'totalFotos': fotosSnap.docs.length,
    };
  }

  String _formatearHorario(Map<String, dynamic> evento) {
    final inicioTs = evento['fechaHoraInicio'];
    final finTs = evento['fechaHoraFin'];

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reporte del evento'),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: cargarReporte(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error generando reporte: ${snapshot.error}'),
              ),
            );
          }

          final data = snapshot.data ?? {};
          final evento = (data['evento'] ?? {}) as Map<String, dynamic>;

          final nombreEvento = (evento['nombreEvento'] ?? '').toString();
          final tipoEvento = (evento['tipoEvento'] ?? '').toString();
          final lugar = (evento['lugar'] ?? '').toString();
          final estado = (evento['estado'] ?? '').toString();
          final horario = _formatearHorario(evento);

          return Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                Text(
                  nombreEvento,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text('Tipo: $tipoEvento'),
                Text('Lugar: $lugar'),
                Text('Empresa: $empresaId'),
                Text('Estado: $estado'),
                Text('Día y horario: $horario'),
                const SizedBox(height: 24),
                const Text(
                  'Asistencia',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('Total invitados: ${data['totalInvitados'] ?? 0}'),
                Text('Asistentes reales: ${data['ingresados'] ?? 0}'),
                Text('Invitados pendientes: ${data['faltantes'] ?? 0}'),
                const SizedBox(height: 24),
                const Text(
                  'Consumos',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('Platillos servidos: ${data['totalPlatillos'] ?? 0}'),
                Text('Bebidas consumidas: ${data['totalBebidas'] ?? 0}'),
                Text('Registros de consumos: ${data['totalConsumos'] ?? 0}'),
                const SizedBox(height: 24),
                const Text(
                  'Fotos',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('Total fotos: ${data['totalFotos'] ?? 0}'),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GaleriaEventoScreen(eventoId: eventoId),
                      ),
                    );
                  },
                  child: const Text('Ver galería'),
                ),
                const SizedBox(height: 24),
                const Text(
                  'REPORTE BASE OK',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
