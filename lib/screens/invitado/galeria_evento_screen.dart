import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class GaleriaEventoScreen extends StatelessWidget {
  final String eventoId;
  final String? invitadoId;
  final bool esAnfitrion;
  final String? anfitrionId;
  final bool esAdmin;

  const GaleriaEventoScreen({
    super.key,
    required this.eventoId,
    this.invitadoId,
    this.esAnfitrion = false,
    this.anfitrionId,
    this.esAdmin = false,
  });

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _cargarFotos() async {
    final fotosRef = FirebaseFirestore.instance
        .collection('eventos')
        .doc(eventoId)
        .collection('fotos');

    if (esAdmin) {
      final snap = await fotosRef.get();
      final docs = snap.docs.toList();
      docs.sort((a, b) {
        final aTs = a.data()['createdAt'];
        final bTs = b.data()['createdAt'];
        if (aTs is Timestamp && bTs is Timestamp) {
          return bTs.compareTo(aTs);
        }
        return 0;
      });
      return docs;
    }

    if (!esAnfitrion) {
      if (invitadoId == null || invitadoId!.isEmpty) return [];

      final snap =
          await fotosRef.where('invitadoId', isEqualTo: invitadoId).get();

      final docs = snap.docs.toList();
      docs.sort((a, b) {
        final aTs = a.data()['createdAt'];
        final bTs = b.data()['createdAt'];
        if (aTs is Timestamp && bTs is Timestamp) {
          return bTs.compareTo(aTs);
        }
        return 0;
      });
      return docs;
    }

    if (anfitrionId == null || anfitrionId!.isEmpty) {
      return [];
    }

    final invitadosSnap = await FirebaseFirestore.instance
        .collection('eventos')
        .doc(eventoId)
        .collection('invitados')
        .where('anfitrionId', isEqualTo: anfitrionId)
        .get();

    final idsPermitidos = invitadosSnap.docs.map((d) => d.id).toSet();

    if (invitadoId != null && invitadoId!.isNotEmpty) {
      idsPermitidos.add(invitadoId!);
    }

    final fotosSnap = await fotosRef.get();
    final filtradas = fotosSnap.docs.where((doc) {
      final data = doc.data();
      final fotoInvitadoId = (data['invitadoId'] ?? '').toString();
      return idsPermitidos.contains(fotoInvitadoId);
    }).toList();

    filtradas.sort((a, b) {
      final aTs = a.data()['createdAt'];
      final bTs = b.data()['createdAt'];
      if (aTs is Timestamp && bTs is Timestamp) {
        return bTs.compareTo(aTs);
      }
      return 0;
    });

    return filtradas;
  }

  @override
  Widget build(BuildContext context) {
    String titulo = 'Galería del evento';
    if (esAdmin) {
      titulo = 'Galería completa del evento';
    } else if (esAnfitrion) {
      titulo = 'Galería de mis invitados';
    } else {
      titulo = 'Mi galería';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(titulo),
      ),
      body: FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
        future: _cargarFotos(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error cargando galería: ${snapshot.error}'),
              ),
            );
          }

          final docs = snapshot.data ?? [];

          if (docs.isEmpty) {
            String mensaje = 'Aún no hay fotos';
            if (esAnfitrion) {
              mensaje = 'Aún no hay fotos tuyas o de tus invitados';
            } else if (!esAdmin) {
              mensaje = 'Aún no tienes fotos en este evento';
            }

            return Center(child: Text(mensaje));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
            ),
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final url = (data['url_foto'] ?? data['url'] ?? '').toString();
              final nombreInvitado = (data['nombreInvitado'] ??
                      data['nombre_invitado'] ??
                      data['subidaPorNombre'] ??
                      '')
                  .toString();

              return GestureDetector(
                onTap: () {
                  if (url.isEmpty) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _VistaFotoScreen(
                        imageUrl: url,
                        titulo: nombreInvitado,
                      ),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (url.isNotEmpty)
                        Image.network(url, fit: BoxFit.cover)
                      else
                        Container(
                          color: Colors.grey.shade300,
                          child: const Center(child: Icon(Icons.broken_image)),
                        ),
                      if ((esAdmin || esAnfitrion) && nombreInvitado.isNotEmpty)
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            width: double.infinity,
                            color: Colors.black54,
                            padding: const EdgeInsets.all(6),
                            child: Text(
                              nombreInvitado,
                              style: const TextStyle(color: Colors.white),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _VistaFotoScreen extends StatelessWidget {
  final String imageUrl;
  final String titulo;

  const _VistaFotoScreen({
    required this.imageUrl,
    required this.titulo,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(titulo.isEmpty ? 'Foto' : titulo),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(imageUrl),
        ),
      ),
    );
  }
}
