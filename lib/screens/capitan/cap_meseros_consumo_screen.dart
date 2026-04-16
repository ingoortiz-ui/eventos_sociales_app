import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CapMeserosConsumoScreen extends StatefulWidget {
  final String eventoId;
  final String empresaId;
  final String nombreEvento;
  final String horarioEvento;
  final String estadoVisible;

  const CapMeserosConsumoScreen({
    super.key,
    required this.eventoId,
    required this.empresaId,
    required this.nombreEvento,
    required this.horarioEvento,
    required this.estadoVisible,
  });

  @override
  State<CapMeserosConsumoScreen> createState() =>
      _CapMeserosConsumoScreenState();
}

class _CapMeserosConsumoScreenState extends State<CapMeserosConsumoScreen> {
  final nombreController = TextEditingController();
  final cantidadController = TextEditingController(text: '1');

  String tipo = 'platillo';
  bool saving = false;

  Future<void> guardarConsumo() async {
    final nombre = nombreController.text.trim();
    final cantidad = int.tryParse(cantidadController.text.trim()) ?? 0;

    if (nombre.isEmpty || cantidad <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa nombre y cantidad válida')),
      );
      return;
    }

    setState(() => saving = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

      await FirebaseFirestore.instance
          .collection('eventos')
          .doc(widget.eventoId)
          .collection('consumos')
          .add({
        'tipo': tipo,
        'nombre': nombre,
        'cantidad': cantidad,
        'capturadoPor': uid,
        'empresaId': widget.empresaId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Consumo guardado')),
      );

      nombreController.clear();
      cantidadController.text = '1';
      setState(() {
        tipo = 'platillo';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error guardando consumo: $e')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    nombreController.dispose();
    cantidadController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final consumosRef = FirebaseFirestore.instance
        .collection('eventos')
        .doc(widget.eventoId)
        .collection('consumos');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.nombreEvento),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(
              widget.nombreEvento,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Horario: ${widget.horarioEvento}'),
            Text('Estado: ${widget.estadoVisible}'),
            const SizedBox(height: 8),
            SelectableText('Evento ID: ${widget.eventoId}'),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: tipo,
              items: const [
                DropdownMenuItem(value: 'platillo', child: Text('Platillo')),
                DropdownMenuItem(value: 'bebida', child: Text('Bebida')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => tipo = value);
              },
              decoration: const InputDecoration(labelText: 'Tipo'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nombreController,
              decoration: const InputDecoration(
                labelText: 'Nombre del consumo',
                hintText: 'Ej. Coca Cola 600 ml / Platillo infantil',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: cantidadController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Cantidad'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: saving ? null : guardarConsumo,
              child: Text(saving ? 'Guardando...' : 'Guardar consumo'),
            ),
            const SizedBox(height: 24),
            const Text(
              'Resumen del evento',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: consumosRef.snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }

                final docs = snapshot.data!.docs;

                int totalPlatillos = 0;
                int totalBebidas = 0;

                for (final d in docs) {
                  final data = d.data();
                  final tipoItem = (data['tipo'] ?? '').toString();
                  final cantidad = (data['cantidad'] ?? 0) as int;

                  if (tipoItem == 'platillo') {
                    totalPlatillos += cantidad;
                  } else if (tipoItem == 'bebida') {
                    totalBebidas += cantidad;
                  }
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Registros totales: ${docs.length}'),
                    Text('Platillos servidos: $totalPlatillos'),
                    Text('Bebidas consumidas: $totalBebidas'),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'Últimos consumos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: consumosRef
                  .orderBy('createdAt', descending: true)
                  .limit(20)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return const Text('Aún no hay consumos registrados');
                }

                return Column(
                  children: docs.map((doc) {
                    final data = doc.data();
                    final tipoItem = (data['tipo'] ?? '').toString();
                    final nombre = (data['nombre'] ?? '').toString();
                    final cantidad = (data['cantidad'] ?? 0).toString();

                    return ListTile(
                      dense: true,
                      leading: Icon(
                        tipoItem == 'platillo'
                            ? Icons.restaurant
                            : Icons.local_drink,
                      ),
                      title: Text(nombre),
                      subtitle: Text(tipoItem),
                      trailing: Text('x$cantidad'),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
