import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class LeadsCotizacionScreen extends StatelessWidget {
  final String empresaId;

  const LeadsCotizacionScreen({
    super.key,
    required this.empresaId,
  });

  String _textoEstado(String estado) {
    switch (estado) {
      case 'nuevo':
        return 'Nuevo';
      case 'en_revision':
        return 'En atención';
      case 'cotizado':
        return 'Cotizado';
      case 'ganado':
        return 'Ganado';
      case 'perdido':
        return 'Perdido';
      default:
        return estado;
    }
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'nuevo':
        return AppTheme.primary;
      case 'en_revision':
        return AppTheme.warning;
      case 'cotizado':
        return AppTheme.secondary;
      case 'ganado':
        return AppTheme.success;
      case 'perdido':
        return AppTheme.danger;
      default:
        return AppTheme.textMuted;
    }
  }

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

  String _formatearFecha(dynamic value) {
    final fecha = _parseFecha(value);
    if (fecha == null) return 'Sin fecha';

    String two(int n) => n.toString().padLeft(2, '0');

    return '${fecha.day}/${fecha.month}/${fecha.year} '
        '${two(fecha.hour)}:${two(fecha.minute)}';
  }

  String _moneda(dynamic value) {
    final n = value is num ? value : num.tryParse(value?.toString() ?? '') ?? 0;
    return '\$${n.toStringAsFixed(2)}';
  }

  Future<void> _cambiarEstado({
    required BuildContext context,
    required String leadId,
    required String estado,
  }) async {
    final updates = <String, dynamic>{
      'estado': estado,
      'atendido': estado != 'nuevo',
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (estado == 'en_revision') {
      updates['atendidoAt'] = FieldValue.serverTimestamp();
    }

    if (estado == 'ganado') {
      updates['ganadoAt'] = FieldValue.serverTimestamp();
      updates['estadoPago'] = 'pendiente';
    }

    if (estado == 'perdido') {
      updates['perdidoAt'] = FieldValue.serverTimestamp();
    }

    try {
      await FirebaseFirestore.instance
          .collection('leads_cotizacion')
          .doc(leadId)
          .update(updates);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Estado actualizado a ${_textoEstado(estado)}')),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error actualizando estado: $e')),
      );
    }
  }

  Future<void> _editarMontos({
    required BuildContext context,
    required String leadId,
    required Map<String, dynamic> data,
  }) async {
    final montoController = TextEditingController(
      text: (data['montoEstimado'] ?? data['presupuestoEstimado'] ?? '')
          .toString(),
    );

    final anticipoController = TextEditingController(
      text: (data['anticipoSugerido'] ?? '').toString(),
    );

    final comisionController = TextEditingController(
      text: (data['comisionApp'] ?? '').toString(),
    );

    final result = await showDialog<Map<String, num>>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Montos de cotización'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: montoController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Monto estimado',
                prefixIcon: Icon(Icons.attach_money),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: anticipoController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Anticipo sugerido',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: comisionController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Comisión app',
                prefixIcon: Icon(Icons.percent),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, {
                'montoEstimado': num.tryParse(montoController.text.trim()) ?? 0,
                'anticipoSugerido':
                    num.tryParse(anticipoController.text.trim()) ?? 0,
                'comisionApp':
                    num.tryParse(comisionController.text.trim()) ?? 0,
              });
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    montoController.dispose();
    anticipoController.dispose();
    comisionController.dispose();

    if (result == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('leads_cotizacion')
          .doc(leadId)
          .update({
        ...result,
        'estado': 'cotizado',
        'atendido': true,
        'estadoPago': 'pendiente',
        'cotizadoAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cotización actualizada')),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error guardando montos: $e')),
      );
    }
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filtrar(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String estado,
  ) {
    final filtrados = docs.where((doc) {
      final data = doc.data();
      return (data['estado'] ?? 'nuevo').toString() == estado;
    }).toList();

    filtrados.sort((a, b) {
      final aFecha = _parseFecha(a.data()['createdAt']);
      final bFecha = _parseFecha(b.data()['createdAt']);

      if (aFecha == null && bFecha == null) return 0;
      if (aFecha == null) return 1;
      if (bFecha == null) return -1;

      return bFecha.compareTo(aFecha);
    });

    return filtrados;
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
    required int nuevos,
    required int revision,
    required int cotizados,
    required int ganados,
    required int perdidos,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cotizaciones de eventos',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Gestiona solicitudes, seguimiento comercial y monetización.',
            style: TextStyle(color: AppTheme.textMuted),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _resumenCard(
                titulo: 'Nuevas',
                total: nuevos,
                color: AppTheme.primary,
                icon: Icons.fiber_new_outlined,
              ),
              const SizedBox(width: 8),
              _resumenCard(
                titulo: 'Atención',
                total: revision,
                color: AppTheme.warning,
                icon: Icons.support_agent,
              ),
            ],
          ),
          Row(
            children: [
              _resumenCard(
                titulo: 'Cotizadas',
                total: cotizados,
                color: AppTheme.secondary,
                icon: Icons.request_quote_outlined,
              ),
              const SizedBox(width: 8),
              _resumenCard(
                titulo: 'Ganadas',
                total: ganados,
                color: AppTheme.success,
                icon: Icons.check_circle_outline,
              ),
            ],
          ),
          Row(
            children: [
              _resumenCard(
                titulo: 'Perdidas',
                total: perdidos,
                color: AppTheme.danger,
                icon: Icons.cancel_outlined,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        CircleAvatar(
                          backgroundColor: Color(0xFFE0F2FE),
                          child: Icon(
                            Icons.credit_card,
                            color: AppTheme.secondary,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Pagos',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.textDark,
                          ),
                        ),
                        Text(
                          'Próximamente',
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
              Icons.inbox_outlined,
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

  Widget _buildLista(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    if (docs.isEmpty) {
      return _emptyState('No hay solicitudes en esta sección');
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final doc = docs[index];
        final data = doc.data();

        final estado = (data['estado'] ?? 'nuevo').toString();
        final color = _colorEstado(estado);

        final nombreCliente = (data['nombreCliente'] ?? '').toString();
        final telefono = (data['telefono'] ?? '').toString();
        final email = (data['email'] ?? '').toString();
        final tipoEvento = (data['tipoEvento'] ?? '').toString();
        final invitados = (data['numeroInvitados'] ?? '').toString();
        final comentarios = (data['comentarios'] ?? '').toString();

        final presupuesto =
            data['presupuestoEstimado'] ?? data['montoEstimado'] ?? 0;
        final montoEstimado = data['montoEstimado'] ?? presupuesto;
        final anticipo = data['anticipoSugerido'] ?? 0;
        final comision = data['comisionApp'] ?? 0;
        final estadoPago = (data['estadoPago'] ?? 'pendiente').toString();

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: color.withOpacity(0.12),
                      child: Icon(Icons.request_quote, color: color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        nombreCliente.isEmpty
                            ? 'Cliente sin nombre'
                            : nombreCliente,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.textDark,
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'montos') {
                          _editarMontos(
                            context: context,
                            leadId: doc.id,
                            data: data,
                          );
                        } else {
                          _cambiarEstado(
                            context: context,
                            leadId: doc.id,
                            estado: value,
                          );
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'en_revision',
                          child: Text('Marcar en atención'),
                        ),
                        PopupMenuItem(
                          value: 'montos',
                          child: Text('Agregar / editar cotización'),
                        ),
                        PopupMenuItem(
                          value: 'ganado',
                          child: Text('Marcar ganado'),
                        ),
                        PopupMenuItem(
                          value: 'perdido',
                          child: Text('Marcar perdido'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _pill(
                      label: _textoEstado(estado),
                      color: color,
                      icon: Icons.info_outline,
                    ),
                    _pill(
                      label: 'Pago: $estadoPago',
                      color: AppTheme.secondary,
                      icon: Icons.credit_card,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _infoLine(Icons.event_outlined, 'Tipo: $tipoEvento'),
                _infoLine(
                  Icons.calendar_today_outlined,
                  'Fecha tentativa: ${_formatearFecha(data['fechaTentativa'])}',
                ),
                _infoLine(Icons.people_outline, 'Invitados: $invitados'),
                _infoLine(Icons.phone_outlined, 'Teléfono: $telefono'),
                if (email.isNotEmpty)
                  _infoLine(Icons.email_outlined, 'Correo: $email'),
                _infoLine(
                  Icons.attach_money,
                  'Presupuesto inicial: ${_moneda(presupuesto)}',
                ),
                _infoLine(
                  Icons.request_quote_outlined,
                  'Monto estimado: ${_moneda(montoEstimado)}',
                ),
                _infoLine(
                  Icons.payments_outlined,
                  'Anticipo sugerido: ${_moneda(anticipo)}',
                ),
                _infoLine(
                  Icons.percent,
                  'Comisión app: ${_moneda(comision)}',
                ),
                if (comentarios.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    comentarios,
                    style: const TextStyle(color: AppTheme.textMuted),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _pill({
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
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
    final leadsRef = FirebaseFirestore.instance
        .collection('leads_cotizacion')
        .where('empresaId', isEqualTo: empresaId);

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('Cotizaciones'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Nuevas'),
              Tab(text: 'En atención'),
              Tab(text: 'Cotizadas'),
              Tab(text: 'Ganadas'),
              Tab(text: 'Perdidas'),
            ],
          ),
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
                  padding: const EdgeInsets.all(18),
                  child: Text(
                    'Error cargando cotizaciones: ${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final docs = snapshot.data?.docs ?? [];

            final nuevos = _filtrar(docs, 'nuevo');
            final revision = _filtrar(docs, 'en_revision');
            final cotizados = _filtrar(docs, 'cotizado');
            final ganados = _filtrar(docs, 'ganado');
            final perdidos = _filtrar(docs, 'perdido');

            return Column(
              children: [
                _buildHeader(
                  nuevos: nuevos.length,
                  revision: revision.length,
                  cotizados: cotizados.length,
                  ganados: ganados.length,
                  perdidos: perdidos.length,
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildLista(context, nuevos),
                      _buildLista(context, revision),
                      _buildLista(context, cotizados),
                      _buildLista(context, ganados),
                      _buildLista(context, perdidos),
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
