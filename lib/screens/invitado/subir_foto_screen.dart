import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class SubirFotoScreen extends StatefulWidget {
  final String eventoId;
  final String invitadoId;

  const SubirFotoScreen({
    super.key,
    required this.eventoId,
    required this.invitadoId,
  });

  @override
  State<SubirFotoScreen> createState() => _SubirFotoScreenState();
}

class _SubirFotoScreenState extends State<SubirFotoScreen> {
  bool uploading = false;
  XFile? selectedImage;

  Future<void> seleccionarImagen() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    setState(() {
      selectedImage = image;
    });
  }

  Future<void> subirFoto() async {
    if (selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una imagen primero')),
      );
      return;
    }

    setState(() => uploading = true);

    try {
      final file = File(selectedImage!.path);
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final storageRef = FirebaseStorage.instance.ref().child(
          'eventos/${widget.eventoId}/fotos/${widget.invitadoId}_$timestamp.jpg');

      await storageRef.putFile(file);

      final downloadUrl = await storageRef.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('eventos')
          .doc(widget.eventoId)
          .collection('fotos')
          .add({
        'invitadoId': widget.invitadoId,
        'url_foto': downloadUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'estado': 'activa',
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto subida correctamente')),
      );

      setState(() {
        selectedImage = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error subiendo foto: $e')),
      );
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subir foto'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            ElevatedButton(
              onPressed: uploading ? null : seleccionarImagen,
              child: const Text('Seleccionar imagen'),
            ),
            const SizedBox(height: 16),
            if (selectedImage != null)
              Text('Imagen seleccionada: ${selectedImage!.name}'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: uploading ? null : subirFoto,
              child: Text(uploading ? 'Subiendo...' : 'Subir foto'),
            ),
          ],
        ),
      ),
    );
  }
}
