import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CrearEventoScreen extends StatefulWidget {
  const CrearEventoScreen({super.key});

  @override
  State<CrearEventoScreen> createState() => _CrearEventoScreenState();
}

class _CrearEventoScreenState extends State<CrearEventoScreen> {
  final _name = TextEditingController();
  final _place = TextEditingController();
  final _giftTable = TextEditingController();

  // Fórmula 2 editable
  final _bebidasBasePorMesa = TextEditingController(text: '12');
  final _extraPercent = TextEditingController(text: '15');

  bool _saving = false;
  String? _createdEventId;

  int _toInt(String v, {int fallback = 0}) =>
      int.tryParse(v.trim()) ?? fallback;

  Future<void> _crearEvento() async {
    setState(() => _saving = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('eventos').add({
        'name': _name.text.trim(),
        'place': _place.text.trim(),
        'giftTable': _giftTable.text.trim(),

        // Por ahora: estatus y tiempos
        'galleryStatus': 'open',
        'createdAt': FieldValue.serverTimestamp(),

        // Settings para bebidas (Fórmula 2)
        'settings': {
          'bebidasBasePorMesa': _toInt(_bebidasBasePorMesa.text, fallback: 12),
          'extraPercent': _toInt(_extraPercent.text, fallback: 15),
        },
      });

      setState(() => _createdEventId = doc.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Evento creado: ${doc.id}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creando evento: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _place.dispose();
    _giftTable.dispose();
    _bebidasBasePorMesa.dispose();
    _extraPercent.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Organizador - Crear evento')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nombre del evento'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _place,
              decoration: const InputDecoration(labelText: 'Lugar'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _giftTable,
              decoration: const InputDecoration(
                  labelText: 'Mesa de regalos (URL o texto)'),
            ),
            const SizedBox(height: 24),
            const Text('Bebidas sin alcohol por mesa (editable)',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(
              controller: _bebidasBasePorMesa,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Bebidas base por mesa',
                hintText: 'Ej: 12',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _extraPercent,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Extra % (merma)',
                hintText: 'Ej: 15',
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _crearEvento,
                child: Text(_saving ? 'Guardando...' : 'Crear evento'),
              ),
            ),
            if (_createdEventId != null) ...[
              const SizedBox(height: 16),
              SelectableText('eventId: $_createdEventId'),
              const SizedBox(height: 8),
              const Text(
                'Siguiente paso: pantalla Mesas para este eventId.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
