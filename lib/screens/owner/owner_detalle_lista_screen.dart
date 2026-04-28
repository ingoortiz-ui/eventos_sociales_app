import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class OwnerDetalleListaScreen extends StatelessWidget {
  final String titulo;
  final String tipo;
  final String? filtroEstado;

  const OwnerDetalleListaScreen({
    super.key,
    required this.titulo,
    required this.tipo,
    this.filtroEstado,
  });

  String _fecha(dynamic value) {
    if (value is Timestamp) {
      final d = value.toDate();
      return '${d.day}/${d.month}/${d.year}';
    }
    return 'Sin fecha';
  }

  String _moneda(dynamic value) {
    final n = value is num ? value : num.tryParse(value?.toString() ?? '') ?? 0;
    return '\$${n.toStringAsFixed(2)}';
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() {
    if (tipo == 'empresas') {
      return FirebaseFirestore.instance.collection('empresas').snapshots();
    }

    if (tipo == 'eventos') {
      return FirebaseFirestore.instance.collection('eventos').snapshots();
    }

    if (tipo == 'leads') {
      Query<Map<String, dynamic>> q =
          FirebaseFirestore.instance.collection('leads_cotizacion');

      if (filtroEstado != null) {
        q = q.where('estado', isEqualTo: filtroEstado);
      }

      return q.snapshots();
    }

    return FirebaseFirestore.instance.collection('empresas').snapshots();
  }

  Widget _empresaTile(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    final nombre = (data['nombreEmpresa'] ?? 'Empresa').toString();
    final plan = (data['plan'] ?? 'sin plan').toString();
    final modeloCobro = (data['modeloCobro'] ?? 'sin modelo').toString();
    final giros = ((data['giros'] as List?) ?? []).join(', ');

    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFE0E7FF),
          child: Icon(Icons.business_outlined, color: AppTheme.primary),
        ),
        title: Text(
          nombre,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          'Giros: ${giros.isEmpty ? "Sin giros" : giros}\n'
          'Plan: $plan\n'
          'Modelo cobro: $modeloCobro\n'
          'Alta: ${_fecha(data['createdAt'])}',
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _eventoTile(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    final nombre = (data['nombreEvento'] ?? 'Evento').toString();
    final empresaId = (data['empresaId'] ?? '').toString();
    final lugar = (data['lugar'] ?? '').toString();
    final invitados = (data['totalInvitados'] ?? 0).toString();
    final estado = (data['estado'] ?? 'abierto').toString();

    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFDCFCE7),
          child: Icon(Icons.event_available, color: AppTheme.success),
        ),
        title: Text(
          nombre,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          'Empresa: $empresaId\n'
          'Lugar: $lugar\n'
          'Invitados: $invitados\n'
          'Estado: $estado',
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _leadTile(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    final cliente = (data['nombreCliente'] ?? 'Cliente sin nombre').toString();
    final empresaId = (data['empresaId'] ?? '').toString();
    final estado = (data['estado'] ?? 'nuevo').toString();
    final tipoEvento = (data['tipoEvento'] ?? '').toString();
    final invitados = (data['numeroInvitados'] ?? '').toString();
    final monto = data['montoEstimado'] ?? data['presupuestoEstimado'] ?? 0;
    final comision = data['comisionApp'] ?? 0;

    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFFEF3C7),
          child: Icon(Icons.request_quote_outlined, color: AppTheme.warning),
        ),
        title: Text(
          cliente,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          'Empresa: $empresaId\n'
          'Estado: $estado\n'
          'Tipo: $tipoEvento | Invitados: $invitados\n'
          'Monto: ${_moneda(monto)} | Comisión: ${_moneda(comision)}',
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _tile(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    if (tipo == 'empresas') return _empresaTile(doc);
    if (tipo == 'eventos') return _eventoTile(doc);
    if (tipo == 'leads') return _leadTile(doc);

    return _empresaTile(doc);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(titulo),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error cargando información: ${snapshot.error}'),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Text('No hay información para mostrar'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: docs.length,
            itemBuilder: (context, index) => _tile(docs[index]),
          );
        },
      ),
    );
  }
}
