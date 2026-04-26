import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'cotizacion_evento_screen.dart';
import 'galeria_evento_screen.dart';
import 'satisfaccion_evento_screen.dart';
import 'subir_foto_screen.dart';

class InvitadoEventoDetalleScreen extends StatelessWidget {
  final String eventoId;
  final String invitadoId;

  const InvitadoEventoDetalleScreen({
    super.key,
    required this.eventoId,
    required this.invitadoId,
  });

  bool _eventoActivo(Map<String, dynamic> evento) {
    final now = DateTime.now();
    final estado = (evento['estado'] ?? '').toString();
    final inicioTs = evento['fechaHoraInicio'];
    final finTs = evento['fechaHoraFin'];

    if (estado == 'cerrado' ||
        estado == 'archivado' ||
        estado == 'finalizado') {
      return false;
    }
    if (inicioTs == null || finTs == null) return false;

    final inicio = (inicioTs as Timestamp).toDate();
    final fin = (finTs as Timestamp).toDate();

    return now.isAfter(inicio) && now.isBefore(fin);
  }

  Future<Map<String, dynamic>> cargarDetalle() async {
    final eventoDoc = await FirebaseFirestore.instance
        .collection('eventos')
        .doc(eventoId)
        .get();
    final invitadoDoc = await FirebaseFirestore.instance
        .collection('eventos')
        .doc(eventoId)
        .collection('invitados')
        .doc(invitadoId)
        .get();

    final evento = eventoDoc.data() ?? {};
    final invitado = invitadoDoc.data() ?? {};

    return {
      'evento': evento,
      'invitado': invitado,
      'esAnfitrion': invitado['esAnfitrion'] == true,
      'anfitrionId': (invitado['anfitrionId'] ?? '').toString(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del evento'),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: cargarDetalle(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error cargando detalle: ${snapshot.error}'),
              ),
            );
          }

          final data = snapshot.data ?? {};
          final evento = (data['evento'] ?? {}) as Map<String, dynamic>;
          final invitado = (data['invitado'] ?? {}) as Map<String, dynamic>;
          final esAnfitrion = (data['esAnfitrion'] ?? false) as bool;
          final anfitrionId = (data['anfitrionId'] ?? '').toString();

          final nombreEvento = (evento['nombreEvento'] ?? '').toString();
          final lugar = (evento['lugar'] ?? '').toString();
          final empresaId = (evento['empresaId'] ?? '').toString();
          final nombreInvitado = (invitado['nombre_invitado'] ?? '').toString();
          final mesa = (invitado['mesa'] ?? '').toString();
          final estadoAsistencia =
              (invitado['estado_asistencia'] ?? 'pendiente').toString();
          final modoEncuesta =
              (evento['modoEncuestaExperiencia'] ?? 'todos').toString();

          final eventoActivo = _eventoActivo(evento);
          final puedeSubir = eventoActivo && estadoAsistencia == 'ingresado';

          final puedeResponderEncuesta = modoEncuesta == 'todos' ||
              (modoEncuesta == 'solo_anfitriones' && esAnfitrion);

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
                Text('Lugar: $lugar'),
                Text('Invitado: $nombreInvitado'),
                Text('Mesa: $mesa'),
                Text('Estado de ingreso: $estadoAsistencia'),
                Text('Evento activo: ${eventoActivo ? "Sí" : "No"}'),
                Text(
                  'Encuesta: ${modoEncuesta == "todos" ? "Todos los invitados" : "Solo anfitriones"}',
                ),
                if (esAnfitrion) const Text('Rol en este evento: anfitrión'),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: puedeSubir
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SubirFotoScreen(
                                eventoId: eventoId,
                                invitadoId: invitadoId,
                              ),
                            ),
                          );
                        }
                      : null,
                  child: const Text('Subir foto'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GaleriaEventoScreen(
                          eventoId: eventoId,
                          invitadoId: invitadoId,
                          esAnfitrion: esAnfitrion,
                          anfitrionId: anfitrionId,
                        ),
                      ),
                    );
                  },
                  child: Text(
                    esAnfitrion
                        ? 'Ver mis fotos y las de mis invitados'
                        : 'Ver mis fotos',
                  ),
                ),
                const SizedBox(height: 12),
                if (puedeResponderEncuesta)
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SatisfaccionEventoScreen(
                            eventoId: eventoId,
                            invitadoId: invitadoId,
                            nombreEvento: nombreEvento,
                            tipoRespondente:
                                esAnfitrion ? 'anfitrion' : 'invitado',
                          ),
                        ),
                      );
                    },
                    child: const Text('Calificar mi experiencia'),
                  ),
                if (!puedeResponderEncuesta)
                  const Text(
                    'La encuesta de experiencia está habilitada solo para anfitriones en este evento.',
                  ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CotizacionEventoScreen(
                          empresaId: empresaId,
                          eventoOrigenId: eventoId,
                        ),
                      ),
                    );
                  },
                  child: const Text('Cotizar mi evento'),
                ),
                const SizedBox(height: 12),
                if (!puedeSubir)
                  const Text(
                    'Solo puedes subir fotos si ya ingresaste y el evento está activo.',
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
