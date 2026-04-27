import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'invitado_evento_detalle_screen.dart';

class InvitadoHomeScreen extends StatelessWidget {
  final String nombre;
  final String email;
  final String empresaId;
  final bool mostrarCerrarSesion;

  const InvitadoHomeScreen({
    super.key,
    required this.nombre,
    required this.email,
    required this.empresaId,
    this.mostrarCerrarSesion = true,
  });

  String _normalizarCorreo(String email) {
    return email.trim().toLowerCase();
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

  String _estadoVisual(Map<String, dynamic> data) {
    final estadoManual =
        (data['estadoManual'] ?? data['estado'] ?? 'abierto').toString();

    if (estadoManual == 'cerrado') return 'cerrado';

    final inicio = _parseFecha(data['fechaHoraInicio']);
    final fin = _parseFecha(data['fechaHoraFin']);

    if (inicio == null || fin == null) return 'proximo';

    final now = DateTime.now();

    if (now.isBefore(inicio)) return 'proximo';
    if (now.isAfter(fin)) return 'finalizado';

    return 'activo';
  }

  String _textoEstado(String estado) {
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

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filtrar(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String tipo,
  ) {
    return docs.where((doc) {
      final estado = _estadoVisual(doc.data());

      switch (tipo) {
        case 'activos':
          return estado == 'activo';
        case 'proximos':
          return estado == 'proximo';
        case 'finalizados':
          return estado == 'finalizado';
        case 'cerrados':
          return estado == 'cerrado';
        default:
          return false;
      }
    }).toList();
  }

  void _ordenar(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    docs.sort((a, b) {
      final aF = _parseFecha(a.data()['fechaHoraInicio']);
      final bF = _parseFecha(b.data()['fechaHoraInicio']);

      if (aF == null && bF == null) return 0;
      if (aF == null) return 1;
      if (bF == null) return -1;

      return aF.compareTo(bF);
    });
  }

  Widget _buildLista(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    if (docs.isEmpty) {
      return const Center(child: Text('Sin eventos'));
    }

    _ordenar(docs);

    return ListView.separated(
      itemCount: docs.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final data = docs[index].data();

        final eventoId = (data['eventoId'] ?? '').toString();
        final invitadoId = (data['invitadoId'] ?? '').toString();
        final nombreEvento = (data['nombreEvento'] ?? 'Evento').toString();
        final nombrePersona = (data['nombrePersona'] ?? '').toString();
        final empresa = (data['empresaNombre'] ?? '').toString();
        final estado = _textoEstado(_estadoVisual(data));

        return ListTile(
          title: Text(nombreEvento),
          subtitle: Text(
            'Nombre: $nombrePersona\n'
            '${empresa.isNotEmpty ? "Empresa: $empresa\n" : ""}'
            'Estado: $estado',
          ),
          isThreeLine: true,
          onTap: eventoId.isEmpty || invitadoId.isEmpty
              ? null
              : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => InvitadoEventoDetalleScreen(
                        eventoId: eventoId,
                        invitadoId: invitadoId,
                      ),
                    ),
                  );
                },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final emailNormalizado = _normalizarCorreo(email);

    final stream = FirebaseFirestore.instance
        .collection('usuarios_eventos')
        .where('email', isEqualTo: emailNormalizado)
        .where('activo', isEqualTo: true)
        .snapshots();

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mis eventos'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Activos'),
              Tab(text: 'Próximos'),
              Tab(text: 'Finalizados'),
              Tab(text: 'Cerrados'),
            ],
          ),
          actions: mostrarCerrarSesion
              ? [
                  IconButton(
                    icon: const Icon(Icons.logout),
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                    },
                  ),
                ]
              : null,
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: stream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error cargando eventos: ${snapshot.error}',
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data!.docs;

            final activos = _filtrar(docs, 'activos');
            final proximos = _filtrar(docs, 'proximos');
            final finalizados = _filtrar(docs, 'finalizados');
            final cerrados = _filtrar(docs, 'cerrados');

            return TabBarView(
              children: [
                _buildLista(context, activos),
                _buildLista(context, proximos),
                _buildLista(context, finalizados),
                _buildLista(context, cerrados),
              ],
            );
          },
        ),
      ),
    );
  }
}
