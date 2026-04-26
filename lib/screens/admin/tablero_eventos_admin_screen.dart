import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'editar_evento_screen.dart';
import 'panel_evento_screen.dart';

class TableroEventosAdminScreen extends StatelessWidget {
  final String empresaId;

  const TableroEventosAdminScreen({
    super.key,
    required this.empresaId,
  });

  DateTime? _parseFecha(dynamic value) {
    if (value == null) return null;

    if (value is Timestamp) return value.toDate();

    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }

    return null;
  }

  String _calcularEstado(Map<String, dynamic> data) {
    final estadoManual = (data['estado'] ?? 'abierto').toString();

    if (estadoManual == 'cerrado') return 'cerrado';

    final inicio = _parseFecha(data['fechaHoraInicio']);
    final fin = _parseFecha(data['fechaHoraFin']);

    if (inicio == null || fin == null) return 'proximo';

    final ahora = DateTime.now();

    if (ahora.isBefore(inicio)) return 'proximo';
    if (ahora.isAfter(fin)) return 'finalizado';

    return 'activo';
  }

  String _labelEstado(String estado) {
    switch (estado) {
      case 'activo':
        return 'Activo';
      case 'proximo':
        return 'Próximo';
      case 'finalizado':
        return 'Finalizado';
      case 'cerrado':
        return 'Cerrado';
      default:
        return estado;
    }
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'activo':
        return Colors.green;
      case 'proximo':
        return Colors.orange;
      case 'finalizado':
        return Colors.grey;
      case 'cerrado':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }

  String _formatearFecha(dynamic value) {
    final fecha = _parseFecha(value);
    if (fecha == null) return 'Sin definir';

    return '${fecha.day}/${fecha.month}/${fecha.year} '
        '${fecha.hour}:${fecha.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _cerrarEvento(String eventoId) async {
    await FirebaseFirestore.instance
        .collection('eventos')
        .doc(eventoId)
        .update({
      'estado': 'cerrado',
      'cerradoAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _archivarEvento(String eventoId) async {
    await FirebaseFirestore.instance
        .collection('eventos')
        .doc(eventoId)
        .update({
      'archivado': true,
      'archivadoAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _eliminarEvento(String eventoId) async {
    await FirebaseFirestore.instance
        .collection('eventos')
        .doc(eventoId)
        .delete();
  }

  Future<bool> _confirmar(
    BuildContext context, {
    required String titulo,
    required String mensaje,
    required String accion,
  }) async {
    final resp = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(titulo),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(accion),
          ),
        ],
      ),
    );

    return resp == true;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filtrar(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String estadoBuscado,
  ) {
    return docs.where((doc) {
      final data = doc.data();

      if (data['archivado'] == true) return false;

      final estado = _calcularEstado(data);
      return estado == estadoBuscado;
    }).toList();
  }

  Widget _buildListaEventos(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    if (docs.isEmpty) {
      return const Center(child: Text('No hay eventos en esta sección'));
    }

    docs.sort((a, b) {
      final fechaA = _parseFecha(a.data()['fechaHoraInicio']);
      final fechaB = _parseFecha(b.data()['fechaHoraInicio']);

      if (fechaA == null || fechaB == null) return 0;
      return fechaA.compareTo(fechaB);
    });

    return ListView.builder(
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final doc = docs[index];
        final data = doc.data();

        final nombreEvento = (data['nombreEvento'] ?? 'Evento').toString();
        final lugar = (data['lugar'] ?? '').toString();
        final totalInvitados = (data['totalInvitados'] ?? 0).toString();
        final usaAnfitriones = data['usaAnfitriones'] == true;
        final cantidadAnfitriones =
            (data['cantidadAnfitriones'] ?? 0).toString();

        final estado = _calcularEstado(data);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _colorEstado(estado),
            ),
            title: Text(
              nombreEvento,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Estado: ${_labelEstado(estado)}\n'
              'Lugar: $lugar\n'
              'Inicio: ${_formatearFecha(data['fechaHoraInicio'])}\n'
              'Fin: ${_formatearFecha(data['fechaHoraFin'])}\n'
              'Invitados: $totalInvitados'
              '${usaAnfitriones ? "\nAnfitriones permitidos: $cantidadAnfitriones" : ""}',
            ),
            isThreeLine: true,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PanelEventoScreen(
                    eventoId: doc.id,
                    empresaId: empresaId,
                    nombreEvento: nombreEvento,
                  ),
                ),
              );
            },
            trailing: PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'abrir') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PanelEventoScreen(
                        eventoId: doc.id,
                        empresaId: empresaId,
                        nombreEvento: nombreEvento,
                      ),
                    ),
                  );
                }

                if (value == 'editar') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditarEventoScreen(
                        eventoId: doc.id,
                        empresaId: empresaId,
                      ),
                    ),
                  );
                }

                if (value == 'cerrar') {
                  final ok = await _confirmar(
                    context,
                    titulo: 'Cerrar evento',
                    mensaje:
                        '¿Seguro que deseas cerrar este evento? Después quedará solo para consulta, reporte y archivo.',
                    accion: 'Cerrar',
                  );

                  if (ok) {
                    await _cerrarEvento(doc.id);
                  }
                }

                if (value == 'archivar') {
                  final ok = await _confirmar(
                    context,
                    titulo: 'Archivar evento',
                    mensaje: '¿Seguro que deseas archivar este evento cerrado?',
                    accion: 'Archivar',
                  );

                  if (ok) {
                    await _archivarEvento(doc.id);
                  }
                }

                if (value == 'eliminar') {
                  final ok = await _confirmar(
                    context,
                    titulo: 'Eliminar evento',
                    mensaje:
                        '¿Seguro que deseas eliminar este evento? Esta acción no se puede deshacer.',
                    accion: 'Eliminar',
                  );

                  if (ok) {
                    await _eliminarEvento(doc.id);
                  }
                }
              },
              itemBuilder: (_) {
                final items = <PopupMenuEntry<String>>[
                  const PopupMenuItem(
                    value: 'abrir',
                    child: Text('Abrir evento'),
                  ),
                ];

                if (estado == 'proximo') {
                  items.addAll([
                    const PopupMenuItem(
                      value: 'editar',
                      child: Text('Editar evento'),
                    ),
                    const PopupMenuItem(
                      value: 'eliminar',
                      child: Text('Eliminar evento'),
                    ),
                  ]);
                }

                if (estado == 'finalizado') {
                  items.add(
                    const PopupMenuItem(
                      value: 'cerrar',
                      child: Text('Cerrar evento'),
                    ),
                  );
                }

                if (estado == 'cerrado') {
                  items.addAll([
                    const PopupMenuItem(
                      value: 'archivar',
                      child: Text('Archivar evento'),
                    ),
                    const PopupMenuItem(
                      value: 'eliminar',
                      child: Text('Eliminar evento'),
                    ),
                  ]);
                }

                return items;
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final eventosRef = FirebaseFirestore.instance
        .collection('eventos')
        .where('empresaId', isEqualTo: empresaId);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tablero de eventos'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Activos'),
              Tab(text: 'Próximos'),
              Tab(text: 'Finalizados'),
              Tab(text: 'Cerrados'),
            ],
          ),
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: eventosRef.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text('Error cargando eventos: ${snapshot.error}'),
              );
            }

            final docs = snapshot.data?.docs ?? [];

            final activos = _filtrar(docs, 'activo');
            final proximos = _filtrar(docs, 'proximo');
            final finalizados = _filtrar(docs, 'finalizado');
            final cerrados = _filtrar(docs, 'cerrado');

            return TabBarView(
              children: [
                _buildListaEventos(context, activos),
                _buildListaEventos(context, proximos),
                _buildListaEventos(context, finalizados),
                _buildListaEventos(context, cerrados),
              ],
            );
          },
        ),
      ),
    );
  }
}
