import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SatisfaccionEventoScreen extends StatefulWidget {
  final String eventoId;
  final String invitadoId;
  final String nombreEvento;
  final String tipoRespondente;

  const SatisfaccionEventoScreen({
    super.key,
    required this.eventoId,
    required this.invitadoId,
    required this.nombreEvento,
    required this.tipoRespondente,
  });

  @override
  State<SatisfaccionEventoScreen> createState() =>
      _SatisfaccionEventoScreenState();
}

class _SatisfaccionEventoScreenState extends State<SatisfaccionEventoScreen> {
  final comentarioController = TextEditingController();
  final gustoMasController = TextEditingController();
  final sugerenciaController = TextEditingController();

  int calificacion = 5;
  bool saving = false;

  Future<void> guardarSatisfaccion() async {
    final comentario = comentarioController.text.trim();
    final gustoMas = gustoMasController.text.trim();
    final sugerencia = sugerenciaController.text.trim();

    setState(() => saving = true);

    try {
      await FirebaseFirestore.instance
          .collection('eventos')
          .doc(widget.eventoId)
          .collection('satisfaccion')
          .doc(widget.invitadoId)
          .set({
        'invitadoId': widget.invitadoId,
        'calificacion': calificacion,
        'comentario': comentario,
        'gustoMas': gustoMas,
        'sugerencia': sugerencia,
        'tipoRespondente': widget.tipoRespondente,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gracias por calificar tu experiencia')),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error guardando calificación: $e')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget estrella(int valor) {
    return IconButton(
      onPressed: () {
        setState(() => calificacion = valor);
      },
      icon: Icon(
        valor <= calificacion ? Icons.star : Icons.star_border,
        size: 34,
      ),
    );
  }

  @override
  void dispose() {
    comentarioController.dispose();
    gustoMasController.dispose();
    sugerenciaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final etiquetaRespondente =
        widget.tipoRespondente == 'anfitrion' ? 'Anfitrión' : 'Invitado';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Califica tu experiencia'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(
              widget.nombreEvento,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text('Respondente: $etiquetaRespondente'),
            const SizedBox(height: 20),
            const Text(
              '¿Cómo calificarías tu experiencia?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                estrella(1),
                estrella(2),
                estrella(3),
                estrella(4),
                estrella(5),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: comentarioController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Comentario general',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: gustoMasController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '¿Qué fue lo que más te gustó?',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: sugerenciaController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Sugerencia de mejora',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: saving ? null : guardarSatisfaccion,
              child: Text(
                saving ? 'Guardando...' : 'Enviar calificación',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
