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

  Future<Map<String, dynamic>> _cargarResumen() async {
    final eventoRef =
        FirebaseFirestore.instance.collection('eventos').doc(eventoId);

    final eventoDoc = await eventoRef.get();
    final invitadosSnap = await eventoRef.collection('invitados').get();
    final satisfaccionSnap = await eventoRef.collection('satisfaccion').get();
    final fotosSnap = await eventoRef.collection('fotos').get();

    final invitadosReales = invitadosSnap.docs.where((doc) {
      final data = doc.data();
      return data['esAnfitrion'] != true;
    }).toList();

    final anfitriones = invitadosSnap.docs.where((doc) {
      final data = doc.data();
      return data['esAnfitrion'] == true;
    }).toList();

    int invitadosIngresados = 0;
    int anfitrionesIngresados = 0;

    for (final doc in invitadosReales) {
      final estado = (doc.data()['estado_asistencia'] ?? '').toString();
      if (estado == 'ingresado') invitadosIngresados++;
    }

    for (final doc in anfitriones) {
      final estado = (doc.data()['estado_asistencia'] ?? '').toString();
      if (estado == 'ingresado') anfitrionesIngresados++;
    }

    double promedio = 0;
    if (satisfaccionSnap.docs.isNotEmpty) {
      int suma = 0;
      for (final doc in satisfaccionSnap.docs) {
        suma += ((doc.data()['calificacion'] ?? 0) as num).toInt();
      }
      promedio = suma / satisfaccionSnap.docs.length;
    }

    return {
      'evento': eventoDoc.data() ?? {},
      'totalInvitadosReales': invitadosReales.length,
      'totalAnfitriones': anfitriones.length,
      'invitadosIngresados': invitadosIngresados,
      'anfitrionesIngresados': anfitrionesIngresados,
      'totalRespuestas': satisfaccionSnap.docs.length,
      'promedioSatisfaccion': promedio,
      'totalFotos': fotosSnap.docs.length,
    };
  }

  @override
  Widget build(BuildContext context) {
    final eventoRef =
        FirebaseFirestore.instance.collection('eventos').doc(eventoId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reporte del evento'),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _cargarResumen(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error cargando reporte: ${snapshot.error}'),
              ),
            );
          }

          final resumen = snapshot.data ?? {};
          final evento = (resumen['evento'] ?? {}) as Map<String, dynamic>;

          final nombreEvento = (evento['nombreEvento'] ?? '').toString();
          final lugar = (evento['lugar'] ?? '').toString();
          final tipoEvento = (evento['tipoEvento'] ?? '').toString();
          final estado = (evento['estado'] ?? '').toString();
          final totalPermitidos = (evento['totalInvitados'] ?? 0).toString();
          final usaAnfitriones = evento['usaAnfitriones'] == true;
          final cantidadAnfitriones =
              (evento['cantidadAnfitriones'] ?? 0).toString();

          final totalInvitadosReales =
              (resumen['totalInvitadosReales'] ?? 0).toString();
          final totalAnfitriones =
              (resumen['totalAnfitriones'] ?? 0).toString();
          final invitadosIngresados =
              (resumen['invitadosIngresados'] ?? 0).toString();
          final anfitrionesIngresados =
              (resumen['anfitrionesIngresados'] ?? 0).toString();
          final respuestas = (resumen['totalRespuestas'] ?? 0).toString();
          final totalFotos = (resumen['totalFotos'] ?? 0).toString();

          final promedio =
              ((resumen['promedioSatisfaccion'] ?? 0) as num).toDouble();

          return Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                Text(
                  nombreEvento.isEmpty ? 'Reporte del evento' : nombreEvento,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text('Tipo: $tipoEvento'),
                Text('Lugar: $lugar'),
                Text('Estado: $estado'),
                Text('Empresa: $empresaId'),
                SelectableText('Evento ID: $eventoId'),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _dato('Invitados permitidos', totalPermitidos),
                        _dato('Invitados reales registrados',
                            totalInvitadosReales),
                        _dato(
                            'Invitados reales ingresados', invitadosIngresados),
                        if (usaAnfitriones) ...[
                          _dato('Anfitriones permitidos', cantidadAnfitriones),
                          _dato('Anfitriones registrados', totalAnfitriones),
                          _dato(
                              'Anfitriones ingresados', anfitrionesIngresados),
                        ],
                        _dato('Fotos subidas', totalFotos),
                        _dato('Respuestas de satisfacción', respuestas),
                        _dato(
                          'Promedio satisfacción',
                          promedio == 0
                              ? 'Sin respuestas'
                              : promedio.toStringAsFixed(1),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GaleriaEventoScreen(
                          eventoId: eventoId,
                          esAdmin: true,
                        ),
                      ),
                    );
                  },
                  child: const Text('Ver galería completa del evento'),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Invitados y anfitriones registrados',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: eventoRef.collection('invitados').snapshots(),
                  builder: (context, invitadoSnap) {
                    if (invitadoSnap.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (invitadoSnap.hasError) {
                      return Text(
                        'Error cargando invitados: ${invitadoSnap.error}',
                      );
                    }

                    final docs = invitadoSnap.data?.docs ?? [];

                    docs.sort((a, b) {
                      final aAnfitrion = a.data()['esAnfitrion'] == true;
                      final bAnfitrion = b.data()['esAnfitrion'] == true;

                      if (aAnfitrion && !bAnfitrion) return -1;
                      if (!aAnfitrion && bAnfitrion) return 1;

                      final aTs = a.data()['createdAt'];
                      final bTs = b.data()['createdAt'];

                      if (aTs is Timestamp && bTs is Timestamp) {
                        return bTs.compareTo(aTs);
                      }

                      return 0;
                    });

                    if (docs.isEmpty) {
                      return const Text('No hay registros todavía');
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, index) {
                        final d = docs[index].data();

                        final nombre = (d['nombre_invitado'] ?? '').toString();
                        final email = (d['email_invitado'] ?? '').toString();
                        final mesa = (d['mesa'] ?? '').toString();
                        final estadoAsistencia =
                            (d['estado_asistencia'] ?? '').toString();
                        final anfitrionNombre =
                            (d['anfitrionNombre'] ?? '').toString();
                        final esAnfitrion = d['esAnfitrion'] == true;

                        return ListTile(
                          title: Text(nombre),
                          subtitle: Text(
                            '$email\n'
                            'Mesa: $mesa\n'
                            'Estado: $estadoAsistencia\n'
                            'Anfitrión asignado: ${anfitrionNombre.isEmpty ? "Sin anfitrión" : anfitrionNombre}\n'
                            'Tipo: ${esAnfitrion ? "Anfitrión" : "Invitado"}',
                          ),
                          isThreeLine: true,
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _dato(String titulo, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(titulo)),
          const SizedBox(width: 12),
          Text(
            valor,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
