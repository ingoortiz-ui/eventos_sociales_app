import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../invitado/invitado_evento_detalle_screen.dart';
import 'anfitrion_evento_detalle_screen.dart';

class AnfitrionHomeScreen extends StatelessWidget {
  const AnfitrionHomeScreen({super.key});

  String _normalizeEmail(String email) => email.trim().toLowerCase();

  Future<Map<String, String>> _contexto() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return {'email': '', 'empresaId': '', 'uid': ''};
    }

    final email = _normalizeEmail(user.email ?? '');

    final userDoc = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(user.uid)
        .get();

    final data = userDoc.data() ?? {};

    return {
      'email': email,
      'empresaId': (data['empresaId'] ?? '').toString(),
      'uid': user.uid,
    };
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _streamAnfitrion(
    String empresaId,
    String email,
  ) {
    return FirebaseFirestore.instance
        .collection('anfitriones_evento')
        .where('empresaId', isEqualTo: empresaId)
        .where('email', isEqualTo: email)
        .where('activo', isEqualTo: true)
        .snapshots();
  }

  String _estadoVisual(Map<String, dynamic> evento) {
    final estado = (evento['estado'] ?? 'abierto').toString();
    final inicioTs = evento['fechaHoraInicio'];
    final finTs = evento['fechaHoraFin'];

    if (estado == 'cerrado' ||
        estado == 'archivado' ||
        estado == 'finalizado') {
      return estado;
    }

    if (inicioTs is Timestamp && finTs is Timestamp) {
      final now = DateTime.now();
      final inicio = inicioTs.toDate();
      final fin = finTs.toDate();

      if (now.isBefore(inicio)) return 'proximo';
      if (now.isAfter(fin)) return 'finalizado';
      return 'activo_ahora';
    }

    return estado;
  }

  String _textoEstado(String estado) {
    switch (estado) {
      case 'activo_ahora':
        return 'Activo ahora';
      case 'proximo':
        return 'Próximo';
      case 'cerrado':
        return 'Cerrado';
      case 'archivado':
        return 'Archivado';
      case 'finalizado':
        return 'Finalizado';
      case 'abierto':
        return 'Abierto';
      default:
        return estado;
    }
  }

  Future<Map<String, dynamic>> _cargarTarjetaEventoAnfitrion(
    QueryDocumentSnapshot<Map<String, dynamic>> anfitrionDoc,
  ) async {
    final eventoId = (anfitrionDoc.data()['eventoId'] ?? '').toString();

    final eventoSnap = await FirebaseFirestore.instance
        .collection('eventos')
        .doc(eventoId)
        .get();

    final evento = eventoSnap.data() ?? {};

    final espejoSnap = await FirebaseFirestore.instance
        .collection('eventos')
        .doc(eventoId)
        .collection('invitados')
        .where('anfitrionId', isEqualTo: anfitrionDoc.id)
        .where('esAnfitrion', isEqualTo: true)
        .limit(1)
        .get();

    final espejo = espejoSnap.docs.isNotEmpty
        ? espejoSnap.docs.first.data()
        : <String, dynamic>{};

    return {
      'eventoId': eventoId,
      'evento': evento,
      'espejo': espejo,
    };
  }

  Future<List<Map<String, dynamic>>> _cargarEventosComoInvitado(
    String email,
    String empresaId,
    String uid,
  ) async {
    final db = FirebaseFirestore.instance;

    final eventosSnap = await db
        .collection('eventos')
        .where('empresaId', isEqualTo: empresaId)
        .get();

    final List<Map<String, dynamic>> resultado = [];

    for (final eventoDoc in eventosSnap.docs) {
      final invitadosPorCorreo = await db
          .collection('eventos')
          .doc(eventoDoc.id)
          .collection('invitados')
          .where('email_invitado', isEqualTo: email)
          .get();

      final invitadosPorUid = uid.isEmpty
          ? <QueryDocumentSnapshot<Map<String, dynamic>>>[]
          : (await db
                  .collection('eventos')
                  .doc(eventoDoc.id)
                  .collection('invitados')
                  .where('usuarioId', isEqualTo: uid)
                  .get())
              .docs;

      final vistos = <String>{};

      for (final invitadoDoc in [
        ...invitadosPorCorreo.docs,
        ...invitadosPorUid,
      ]) {
        if (vistos.contains(invitadoDoc.id)) continue;
        vistos.add(invitadoDoc.id);

        final invitadoData = invitadoDoc.data();

        final esAnfitrionEspejo = invitadoData['esAnfitrion'] == true;
        if (esAnfitrionEspejo) continue;

        resultado.add({
          'eventoId': eventoDoc.id,
          'evento': eventoDoc.data(),
          'invitadoId': invitadoDoc.id,
          'invitado': invitadoData,
        });
      }
    }

    resultado.sort((a, b) {
      final aEvento = (a['evento'] ?? {}) as Map<String, dynamic>;
      final bEvento = (b['evento'] ?? {}) as Map<String, dynamic>;

      final aInicio = aEvento['fechaHoraInicio'];
      final bInicio = bEvento['fechaHoraInicio'];

      if (aInicio is Timestamp && bInicio is Timestamp) {
        return bInicio.compareTo(aInicio);
      }
      return 0;
    });

    return resultado;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filtrarAnfitrion(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    Map<String, Map<String, dynamic>> eventos,
    String tipo,
  ) {
    return docs.where((doc) {
      final evento = eventos[(doc.data()['eventoId'] ?? '').toString()] ?? {};
      final estadoVisual = _estadoVisual(evento);

      switch (tipo) {
        case 'activos':
          return estadoVisual == 'activo_ahora' || estadoVisual == 'abierto';
        case 'proximos':
          return estadoVisual == 'proximo';
        case 'finalizados':
          return estadoVisual == 'finalizado';
        case 'cerrados':
          return estadoVisual == 'cerrado' || estadoVisual == 'archivado';
        default:
          return false;
      }
    }).toList();
  }

  List<Map<String, dynamic>> _filtrarInvitado(
    List<Map<String, dynamic>> items,
    String tipo,
  ) {
    return items.where((item) {
      final evento = (item['evento'] ?? {}) as Map<String, dynamic>;
      final estadoVisual = _estadoVisual(evento);

      switch (tipo) {
        case 'activos':
          return estadoVisual == 'activo_ahora' || estadoVisual == 'abierto';
        case 'proximos':
          return estadoVisual == 'proximo';
        case 'finalizados':
          return estadoVisual == 'finalizado';
        case 'cerrados':
          return estadoVisual == 'cerrado' || estadoVisual == 'archivado';
        default:
          return false;
      }
    }).toList();
  }

  Future<Map<String, Map<String, dynamic>>> _cargarEventosMap(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final db = FirebaseFirestore.instance;
    final map = <String, Map<String, dynamic>>{};

    for (final doc in docs) {
      final id = (doc.data()['eventoId'] ?? '').toString();
      final eventoDoc = await db.collection('eventos').doc(id).get();
      map[id] = eventoDoc.data() ?? {};
    }

    return map;
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

    return Column(
      children: docs.map((doc) {
        final anfitrionData = doc.data();
        final nombreAnfitrion = (anfitrionData['nombre'] ?? '').toString();
        final cupo = (anfitrionData['maxInvitados'] ?? 0).toString();

        return FutureBuilder<Map<String, dynamic>>(
          future: _cargarTarjetaEventoAnfitrion(doc),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const ListTile(title: Text('Cargando evento...'));
            }

            final data = snap.data!;
            final eventoId = (data['eventoId'] ?? '').toString();
            final evento = (data['evento'] ?? {}) as Map<String, dynamic>;
            final espejo = (data['espejo'] ?? {}) as Map<String, dynamic>;

            final nombreEvento =
                (evento['nombreEvento'] ?? 'Evento').toString();
            final lugar = (evento['lugar'] ?? '').toString();
            final estadoVisual = _estadoVisual(evento);
            final accesoPropio =
                (espejo['estado_asistencia'] ?? 'pendiente').toString();

            return ListTile(
              title: Text(nombreEvento),
              subtitle: Text(
                'Modo: anfitrión\n'
                'Anfitrión: $nombreAnfitrion\n'
                'Lugar: $lugar\n'
                'Cupo: $cupo\n'
                'Estado: ${_textoEstado(estadoVisual)}\n'
                'Mi acceso: $accesoPropio',
              ),
              isThreeLine: true,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AnfitrionEventoDetalleScreen(
                      eventoId: eventoId,
                      empresaId: empresaId,
                      anfitrionId: doc.id,
                    ),
                  ),
                );
              },
            );
          },
        );
      }).toList(),
    );
  }

  Widget _seccionInvitado(
    BuildContext context,
    List<Map<String, dynamic>> items,
  ) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('No tienes eventos como invitado'),
      );
    }

    return Column(
      children: items.map((item) {
        final eventoId = (item['eventoId'] ?? '').toString();
        final invitadoId = (item['invitadoId'] ?? '').toString();
        final evento = (item['evento'] ?? {}) as Map<String, dynamic>;
        final invitado = (item['invitado'] ?? {}) as Map<String, dynamic>;

        final nombreEvento = (evento['nombreEvento'] ?? 'Evento').toString();
        final lugar = (evento['lugar'] ?? '').toString();
        final mesa = (invitado['mesa'] ?? '').toString();
        final acceso =
            (invitado['estado_asistencia'] ?? 'pendiente').toString();
        final estado = _textoEstado(_estadoVisual(evento));

        return ListTile(
          title: Text(nombreEvento),
          subtitle: Text(
            'Modo: invitado\n'
            'Lugar: $lugar\n'
            'Mesa: $mesa\n'
            'Estado: $estado\n'
            'Mi acceso: $acceso',
          ),
          isThreeLine: true,
          onTap: () {
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
    List<QueryDocumentSnapshot<Map<String, dynamic>>> anfitrionDocs,
    List<Map<String, dynamic>> invitadoItems,
    String empresaId,
  ) {
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
        _seccionInvitado(context, invitadoItems),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String>>(
      future: _contexto(),
      builder: (context, ctxSnap) {
        if (!ctxSnap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final email = ctxSnap.data!['email']!;
        final empresaId = ctxSnap.data!['empresaId']!;
        final uid = ctxSnap.data!['uid']!;

        final stream = _streamAnfitrion(empresaId, email);

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
              builder: (context, anfitrionSnap) {
                if (!anfitrionSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final anfitrionDocs = anfitrionSnap.data!.docs;

                return FutureBuilder<Map<String, dynamic>>(
                  future: () async {
                    final eventosMap = await _cargarEventosMap(anfitrionDocs);
                    final invitadoItems =
                        await _cargarEventosComoInvitado(email, empresaId, uid);

                    return {
                      'eventosMap': eventosMap,
                      'invitadoItems': invitadoItems,
                    };
                  }(),
                  builder: (context, extraSnap) {
                    if (!extraSnap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final eventosMap = (extraSnap.data!['eventosMap'] ?? {})
                        as Map<String, Map<String, dynamic>>;
                    final invitadoItems = (extraSnap.data!['invitadoItems'] ??
                        []) as List<Map<String, dynamic>>;

                    return TabBarView(
                      children: [
                        _buildTab(
                          context,
                          _filtrarAnfitrion(
                              anfitrionDocs, eventosMap, 'activos'),
                          _filtrarInvitado(invitadoItems, 'activos'),
                          empresaId,
                        ),
                        _buildTab(
                          context,
                          _filtrarAnfitrion(
                              anfitrionDocs, eventosMap, 'proximos'),
                          _filtrarInvitado(invitadoItems, 'proximos'),
                          empresaId,
                        ),
                        _buildTab(
                          context,
                          _filtrarAnfitrion(
                              anfitrionDocs, eventosMap, 'finalizados'),
                          _filtrarInvitado(invitadoItems, 'finalizados'),
                          empresaId,
                        ),
                        _buildTab(
                          context,
                          _filtrarAnfitrion(
                              anfitrionDocs, eventosMap, 'cerrados'),
                          _filtrarInvitado(invitadoItems, 'cerrados'),
                          empresaId,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}
