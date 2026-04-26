import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../invitado/invitado_evento_detalle_screen.dart';
import 'anfitrion_evento_detalle_screen.dart';

class AnfitrionHomeScreen extends StatelessWidget {
  const AnfitrionHomeScreen({super.key});

  String _normalizarCorreo(String email) => email.trim().toLowerCase();

  Future<Map<String, String>> _contexto() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return {'email': '', 'empresaId': '', 'uid': ''};
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(user.uid)
        .get();

    final data = userDoc.data() ?? {};

    return {
      'email': _normalizarCorreo(user.email ?? ''),
      'empresaId': (data['empresaId'] ?? '').toString(),
      'uid': user.uid,
    };
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

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _porRol(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String rolEvento,
  ) {
    return docs.where((doc) {
      return (doc.data()['rolEvento'] ?? '').toString() == rolEvento;
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

  Widget _seccionAnfitrion(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String empresaId,
  ) {
    if (docs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('No tienes eventos como anfitrión'),
      );
    }

    _ordenarPorFecha(docs);

    return Column(
      children: docs.map((doc) {
        final data = doc.data();

        final eventoId = (data['eventoId'] ?? '').toString();
        final anfitrionId = (data['anfitrionId'] ?? '').toString();
        final nombreEvento = (data['nombreEvento'] ?? 'Evento').toString();
        final nombrePersona = (data['nombrePersona'] ?? '').toString();
        final estado = _textoEstado(_estadoVisual(data));

        return ListTile(
          title: Text(nombreEvento),
          subtitle: Text(
            'Modo: anfitrión\n'
            'Anfitrión: $nombrePersona\n'
            'Estado: $estado',
          ),
          isThreeLine: true,
          onTap: eventoId.isEmpty || anfitrionId.isEmpty
              ? null
              : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AnfitrionEventoDetalleScreen(
                        eventoId: eventoId,
                        empresaId: empresaId,
                        anfitrionId: anfitrionId,
                      ),
                    ),
                  );
                },
        );
      }).toList(),
    );
  }

  Widget _seccionInvitado(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    if (docs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('No tienes eventos como invitado'),
      );
    }

    _ordenarPorFecha(docs);

    return Column(
      children: docs.map((doc) {
        final data = doc.data();

        final eventoId = (data['eventoId'] ?? '').toString();
        final invitadoId = (data['invitadoId'] ?? '').toString();
        final nombreEvento = (data['nombreEvento'] ?? 'Evento').toString();
        final nombrePersona = (data['nombrePersona'] ?? '').toString();
        final estado = _textoEstado(_estadoVisual(data));

        return ListTile(
          title: Text(nombreEvento),
          subtitle: Text(
            'Modo: invitado\n'
            'Invitado: $nombrePersona\n'
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
      }).toList(),
    );
  }

  Widget _buildTab(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String empresaId,
  ) {
    final anfitrionDocs = _porRol(docs, 'anfitrion');
    final invitadoDocs = _porRol(docs, 'invitado');

    return ListView(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Text(
            'Como anfitrión',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        _seccionAnfitrion(context, anfitrionDocs, empresaId),
        const Divider(),
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Text(
            'Como invitado',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        _seccionInvitado(context, invitadoDocs),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String>>(
      future: _contexto(),
      builder: (context, ctxSnap) {
        if (ctxSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (ctxSnap.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Mis eventos')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error cargando usuario: ${ctxSnap.error}'),
              ),
            ),
          );
        }

        final email = ctxSnap.data?['email'] ?? '';
        final empresaId = ctxSnap.data?['empresaId'] ?? '';

        final stream = FirebaseFirestore.instance
            .collection('usuarios_eventos')
            .where('empresaId', isEqualTo: empresaId)
            .where('email', isEqualTo: email)
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
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                  },
                ),
              ],
            ),
            body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Error cargando eventos: ${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                final activos = _filtrar(docs, 'activos');
                final proximos = _filtrar(docs, 'proximos');
                final finalizados = _filtrar(docs, 'finalizados');
                final cerrados = _filtrar(docs, 'cerrados');

                return TabBarView(
                  children: [
                    _buildTab(context, activos, empresaId),
                    _buildTab(context, proximos, empresaId),
                    _buildTab(context, finalizados, empresaId),
                    _buildTab(context, cerrados, empresaId),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}
