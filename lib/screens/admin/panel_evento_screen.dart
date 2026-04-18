import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'carga_invitados_txt_screen.dart';
import 'compartir_galeria_screen.dart';
import 'crear_invitado.dart';
import 'editar_evento_screen.dart';
import 'gestionar_anfitriones_screen.dart';
import 'lista_invitados_screen.dart';
import 'pdf_qrs_evento_screen.dart';
import 'reporte_evento_screen.dart';
import 'satisfaccion_evento_admin_screen.dart';
import 'subir_croquis_screen.dart';

class PanelEventoScreen extends StatelessWidget {
  final String eventoId;
  final String empresaId;
  final String nombreEvento;

  const PanelEventoScreen({
    super.key,
    required this.eventoId,
    required this.empresaId,
    required this.nombreEvento,
  });

  Future<void> cerrarEvento(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cerrar evento'),
        content: const Text(
          '¿Seguro que deseas cerrar este evento? Una vez cerrado, dejará de aparecer como activo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cerrar evento'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await FirebaseFirestore.instance
        .collection('eventos')
        .doc(eventoId)
        .update({
      'estado': 'cerrado',
      'closedAt': FieldValue.serverTimestamp(),
    });

    if (!context.mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReporteEventoScreen(
          eventoId: eventoId,
          empresaId: empresaId,
        ),
      ),
    );
  }

  Future<void> archivarEvento(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Archivar evento'),
        content: const Text(
          '¿Seguro que deseas archivar este evento? Ya no aparecerá en operación normal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archivar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await FirebaseFirestore.instance
        .collection('eventos')
        .doc(eventoId)
        .update({
      'estado': 'archivado',
      'archivedAt': FieldValue.serverTimestamp(),
    });

    if (!context.mounted) return;
    Navigator.pop(context);
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

  bool _eventoVencido(Map<String, dynamic> evento) {
    final finTs = evento['fechaHoraFin'];
    if (finTs == null) return false;
    final fin = (finTs as Timestamp).toDate();
    return DateTime.now().isAfter(fin);
  }

  @override
  Widget build(BuildContext context) {
    final eventoRef =
        FirebaseFirestore.instance.collection('eventos').doc(eventoId);

    return Scaffold(
      appBar: AppBar(
        title: Text(nombreEvento),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: eventoRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() ?? {};
          final estado = (data['estado'] ?? 'abierto').toString();
          final cerrado = estado == 'cerrado';
          final archivado = estado == 'archivado';
          final lugar = (data['lugar'] ?? '').toString();
          final tipoEvento = (data['tipoEvento'] ?? '').toString();
          final horario = _formatearHorario(data);
          final vencido = _eventoVencido(data);
          final bloquearInvitados = cerrado || archivado || vencido;
          final cantidadAnfitriones =
              (data['cantidadAnfitriones'] ?? 0).toString();

          return Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                Text(
                  nombreEvento,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text('Tipo: $tipoEvento'),
                Text('Lugar: $lugar'),
                Text('Horario: $horario'),
                Text('Estado: $estado'),
                Text('Cantidad anfitriones: $cantidadAnfitriones'),
                if (vencido && !cerrado && !archivado)
                  const Text(
                    'El horario del evento ya terminó. Ya no se pueden registrar invitados.',
                  ),
                const SizedBox(height: 8),
                SelectableText('Evento ID: $eventoId'),
                SelectableText('Empresa: $empresaId'),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: archivado
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  EditarEventoScreen(eventoId: eventoId),
                            ),
                          );
                        },
                  child: const Text('Editar evento'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GestionarAnfitrionesScreen(
                          eventoId: eventoId,
                          empresaId: empresaId,
                        ),
                      ),
                    );
                  },
                  child: const Text('Gestionar anfitriones'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SubirCroquisScreen(
                          eventoId: eventoId,
                          nombreEvento: nombreEvento,
                        ),
                      ),
                    );
                  },
                  child: const Text('Subir / actualizar croquis'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: bloquearInvitados
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  CrearInvitadoScreen(eventoId: eventoId),
                            ),
                          );
                        },
                  child: const Text('Registrar invitado manual'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: bloquearInvitados
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  CargaInvitadosTxtScreen(eventoId: eventoId),
                            ),
                          );
                        },
                  child: const Text('Carga masiva por TXT'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ListaInvitadosScreen(eventoId: eventoId),
                      ),
                    );
                  },
                  child: const Text('Consultar invitados'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PdfQrsEventoScreen(
                          eventoId: eventoId,
                          nombreEvento: nombreEvento,
                        ),
                      ),
                    );
                  },
                  child: const Text('PDF con todos los QRs'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: cerrado
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CompartirGaleriaScreen(
                                eventoId: eventoId,
                                nombreEvento: nombreEvento,
                              ),
                            ),
                          );
                        }
                      : null,
                  child: const Text('Compartir galería al contratante'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SatisfaccionEventoAdminScreen(
                          eventoId: eventoId,
                          nombreEvento: nombreEvento,
                        ),
                      ),
                    );
                  },
                  child: const Text('Ver satisfacción del evento'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReporteEventoScreen(
                          eventoId: eventoId,
                          empresaId: empresaId,
                        ),
                      ),
                    );
                  },
                  child: const Text('Ver reporte base'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: (cerrado || archivado)
                      ? null
                      : () => cerrarEvento(context),
                  child: Text(
                    cerrado
                        ? 'Evento cerrado'
                        : archivado
                            ? 'Evento archivado'
                            : 'Cerrar evento',
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: archivado ? null : () => archivarEvento(context),
                  child:
                      Text(archivado ? 'Evento archivado' : 'Archivar evento'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
