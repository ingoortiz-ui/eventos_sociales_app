import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class SubirCroquisScreen extends StatefulWidget {
  final String eventoId;
  final String nombreEvento;

  const SubirCroquisScreen({
    super.key,
    required this.eventoId,
    required this.nombreEvento,
  });

  @override
  State<SubirCroquisScreen> createState() => _SubirCroquisScreenState();
}

class _SubirCroquisScreenState extends State<SubirCroquisScreen> {
  bool loading = true;
  bool saving = false;
  String croquisUrl = '';

  Future<void> cargarEvento() async {
    final doc = await FirebaseFirestore.instance
        .collection('eventos')
        .doc(widget.eventoId)
        .get();

    final data = doc.data() ?? {};
    setState(() {
      croquisUrl = (data['croquisUrl'] ?? '').toString();
      loading = false;
    });
  }

  Future<void> seleccionarYSubir() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);

    if (file == null) return;

    setState(() => saving = true);

    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('croquis_eventos')
          .child('${widget.eventoId}.jpg');

      await storageRef.putFile(File(file.path));

      final url = await storageRef.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('eventos')
          .doc(widget.eventoId)
          .update({
        'croquisUrl': url,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        croquisUrl = url;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Croquis subido correctamente')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error subiendo croquis: $e')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void initState() {
    super.initState();
    cargarEvento();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Croquis del evento'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(
              widget.nombreEvento,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (croquisUrl.isEmpty)
              const Text('Aún no hay croquis cargado')
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(croquisUrl),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: saving ? null : seleccionarYSubir,
              child:
                  Text(saving ? 'Subiendo...' : 'Seleccionar y subir croquis'),
            ),
          ],
        ),
      ),
    );
  }
}
