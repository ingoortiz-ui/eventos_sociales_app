import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
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
        return AppTheme.success;
      case 'proximo':
        return AppTheme.warning;
      case 'finalizado':
        return AppTheme.textMuted;
      case 'cerrado':
        return AppTheme.danger;
      default:
        return AppTheme.primary;
    }
  }

  IconData _iconoEstado(String estado) {
    switch (estado) {
      case 'activo':
        return Icons.play_circle_outline;
      case 'proximo':
        return Icons.schedule;
      case 'finalizado':
        return Icons.flag_outlined;
      case 'cerrado':
        return Icons.lock_outline;
      default:
        return Icons.event;
    }
  }

  String _formatearFecha(dynamic value) {
    final fecha = _parseFecha(value);
    if (fecha == null) return 'Sin definir';

    String two(int n) => n.toString().padLeft(2, '0');

    return '${fecha.day}/${fecha.month}/${fecha.year} '
        '${two(fecha.hour)}:${two(fecha.minute)}';
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

  void _ordenarPorFecha(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    docs.sort((a, b) {
      final fechaA = _parseFecha(a.data()['fechaHoraInicio']);
      final fechaB = _parseFecha(b.data()['fechaHoraInicio']);

      if (fechaA == null && fechaB == null) return 0;
      if (fechaA == null) return 1;
      if (fechaB == null) return -1;

      return fechaA.compareTo(fechaB);
    });
  }

  Widget _resumenCard({
    required String titulo,
    required int total,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.12),
                child: Icon(icon, color: color),
              ),
              const SizedBox(height: 10),
              Text(
                '$total',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textDark,
                ),
              ),
              Text(
                titulo,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader({
    required int activos,
    required int proximos,
    required int finalizados,
    required int cerrados,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dashboard de eventos',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Controla tus eventos, invitados, anfitriones, accesos y reportes.',
            style: TextStyle(color: AppTheme.textMuted),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _resumenCard(
                titulo: 'Activos',
                total: activos,
                color: AppTheme.success,
                icon: Icons.play_circle_outline,
              ),
              const SizedBox(width: 8),
              _resumenCard(
                titulo: 'Próximos',
                total: proximos,
                color: AppTheme.warning,
                icon: Icons.schedule,
              ),
            ],
          ),
          Row(
            children: [
              _resumenCard(
                titulo: 'Finalizados',
                total: finalizados,
                color: AppTheme.textMuted,
                icon: Icons.flag_outlined,
              ),
              const SizedBox(width: 8),
              _resumenCard(
                titulo: 'Cerrados',
                total: cerrados,
                color: AppTheme.danger,
                icon: Icons.lock_outline,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyState(String texto) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_busy,
              size: 64,
              color: AppTheme.textMuted.withOpacity(0.7),
            ),
            const SizedBox(height: 12),
            Text(
              texto,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListaEventos(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    if (docs.isEmpty) {
      return _emptyState('No hay eventos en esta sección');
    }

    _ordenarPorFecha(docs);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
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
        final color = _colorEstado(estado);

        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
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
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: color.withOpacity(0.12),
                    child: Icon(_iconoEstado(estado), color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nombreEvento,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _labelEstado(estado),
                            style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (lugar.isNotEmpty)
                          _infoLine(Icons.location_on_outlined, lugar),
                        _infoLine(
                          Icons.calendar_month_outlined,
                          'Inicio: ${_formatearFecha(data['fechaHoraInicio'])}',
                        ),
                        _infoLine(
                          Icons.timer_outlined,
                          'Fin: ${_formatearFecha(data['fechaHoraFin'])}',
                        ),
                        _infoLine(
                          Icons.people_outline,
                          'Invitados permitidos: $totalInvitados',
                        ),
                        if (usaAnfitriones)
                          _infoLine(
                            Icons.groups_outlined,
                            'Anfitriones permitidos: $cantidadAnfitriones',
                          ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
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
                          mensaje:
                              '¿Seguro que deseas archivar este evento cerrado?',
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _infoLine(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.textMuted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
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
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('Eventos'),
          bottom: const TabBar(
            isScrollable: true,
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
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text(
                    'Error cargando eventos: ${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final docs = snapshot.data?.docs ?? [];

            final activos = _filtrar(docs, 'activo');
            final proximos = _filtrar(docs, 'proximo');
            final finalizados = _filtrar(docs, 'finalizado');
            final cerrados = _filtrar(docs, 'cerrado');

            return Column(
              children: [
                _buildHeader(
                  activos: activos.length,
                  proximos: proximos.length,
                  finalizados: finalizados.length,
                  cerrados: cerrados.length,
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildListaEventos(context, activos),
                      _buildListaEventos(context, proximos),
                      _buildListaEventos(context, finalizados),
                      _buildListaEventos(context, cerrados),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
