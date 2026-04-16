import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class GaleriaCompartidaScreen extends StatefulWidget {
  const GaleriaCompartidaScreen({super.key});

  @override
  State<GaleriaCompartidaScreen> createState() =>
      _GaleriaCompartidaScreenState();
}

class _GaleriaCompartidaScreenState extends State<GaleriaCompartidaScreen> {
  final eventoIdController = TextEditingController();
  final tokenController = TextEditingController();

  bool loading = false;
  String error = '';
  List<String> fotos = [];
  String nombreEvento = '';

  Future<void> validarAcceso() async {
    final eventoId = eventoIdController.text.trim();
    final token = tokenController.text.trim();

    if (eventoId.isEmpty || token.isEmpty) {
      setState(() => error = 'Ingresa eventoId y token');
      return;
    }

    setState(() {
      loading = true;
      error = '';
      fotos = [];
      nombreEvento = '';
    });

    try {
      final eventoDoc = await FirebaseFirestore.instance
          .collection('eventos')
          .doc(eventoId)
          .get();

      if (!eventoDoc.exists) {
        setState(() => error = 'Evento no encontrado');
        return;
      }

      final data = eventoDoc.data() ?? {};
      final compartible = data['galeriaCompartible'] == true;
      final tokenGuardado = (data['tokenGaleria'] ?? '').toString();
      final expiracionTs = data['fechaExpiracionGaleria'];

      if (!compartible) {
        setState(() => error = 'La galería no está habilitada para compartir');
        return;
      }

      if (token != tokenGuardado) {
        setState(() => error = 'Token incorrecto');
        return;
      }

      if (expiracionTs is Timestamp) {
        final expiracion = expiracionTs.toDate();
        if (DateTime.now().isAfter(expiracion)) {
          setState(() => error = 'El acceso a la galería ha expirado');
          return;
        }
      }

      final fotosSnap = await FirebaseFirestore.instance
          .collection('eventos')
          .doc(eventoId)
          .collection('fotos')
          .get();

      final urls = fotosSnap.docs
          .map((d) => (d.data()['url_foto'] ?? '').toString())
          .where((e) => e.isNotEmpty)
          .toList();

      setState(() {
        fotos = urls;
        nombreEvento = (data['nombreEvento'] ?? '').toString();
      });
    } catch (e) {
      setState(() => error = 'Error validando acceso: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  class GaleriaCompartidaScreenDirecto extends StatefulWidget {
  final String eventoId;
  final String token;

  const GaleriaCompartidaScreenDirecto({
    super.key,
    required this.eventoId,
    required this.token,
  });

  @override
  State<GaleriaCompartidaScreenDirecto> createState() =>
      _GaleriaCompartidaScreenDirectoState();
}

class _GaleriaCompartidaScreenDirectoState
    extends State<GaleriaCompartidaScreenDirecto> {
  bool loading = true;
  String error = '';
  List<String> fotos = [];
  String nombreEvento = '';

  @override
  void initState() {
    super.initState();
    validar();
  }

  Future<void> validar() async {
    try {
      final eventoDoc = await FirebaseFirestore.instance
          .collection('eventos')
          .doc(widget.eventoId)
          .get();

      final data = eventoDoc.data() ?? {};

      if (data['galeriaCompartible'] != true) {
        setState(() => error = 'Galería no disponible');
        return;
      }

      if ((data['tokenGaleria'] ?? '') != widget.token) {
        setState(() => error = 'Token inválido');
        return;
      }

      final expTs = data['fechaExpiracionGaleria'];
      if (expTs is Timestamp) {
        if (DateTime.now().isAfter(expTs.toDate())) {
          setState(() => error = 'Link expirado');
          return;
        }
      }

      final fotosSnap = await FirebaseFirestore.instance
          .collection('eventos')
          .doc(widget.eventoId)
          .collection('fotos')
          .get();

      final urls = fotosSnap.docs
          .map((d) => (d.data()['url_foto'] ?? '').toString())
          .where((e) => e.isNotEmpty)
          .toList();

      setState(() {
        fotos = urls;
        nombreEvento = data['nombreEvento'] ?? '';
      });
    } catch (e) {
      setState(() => error = 'Error cargando galería');
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (error.isNotEmpty) {
      return Scaffold(
        body: Center(child: Text(error)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(nombreEvento)),
      body: GridView.builder(
        itemCount: fotos.length,
        gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
        ),
        itemBuilder: (_, i) {
          return Image.network(fotos[i], fit: BoxFit.cover);
        },
      ),
    );
  }
}

  @override
  void dispose() {
    eventoIdController.dispose();
    tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accesoConcedido = fotos.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Galería compartida'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (!accesoConcedido) ...[
              TextField(
                controller: eventoIdController,
                decoration: const InputDecoration(labelText: 'Evento ID'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: tokenController,
                decoration: const InputDecoration(labelText: 'Token de acceso'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: loading ? null : validarAcceso,
                child: Text(loading ? 'Validando...' : 'Abrir galería'),
              ),
              const SizedBox(height: 12),
              if (error.isNotEmpty)
                Text(
                  error,
                  style: const TextStyle(color: Colors.red),
                ),
            ] else ...[
              Text(
                nombreEvento,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  itemCount: fotos.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                  ),
                  itemBuilder: (context, index) {
                    final url = fotos[index];

                    return GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => Dialog(
                            child: Image.network(url, fit: BoxFit.contain),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          url,
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
