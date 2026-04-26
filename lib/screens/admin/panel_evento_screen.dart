import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'carga_invitados_txt_screen.dart';
import 'crear_invitado.dart';
import 'editar_evento_screen.dart';
import 'gestionar_anfitriones_screen.dart';
import 'lista_invitados_screen.dart';
import 'reporte_evento_screen.dart';

class PanelEventoScreen extends StatefulWidget {
  final String eventoId;
  final String empresaId;
  final String? nombreEvento;

  const PanelEventoScreen({
    super.key,
    required this.eventoId,
    required this.empresaId,
    this.nombreEvento,
  });

  @override
  State<PanelEventoScreen> createState() => _PanelEventoScreenState();
}

class _PanelEventoScreenState extends State<PanelEventoScreen> {
  bool subiendoCroquis = false;

  String _formatearFecha(Timestamp? ts) {
    if (ts == null) return 'Sin definir';
    final d = ts.toDate();
    return '${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _subirCroquisMesas() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;

      if (bytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo leer la imagen')),
        );
        return;
      }

      setState(() => subiendoCroquis = true);

      final extension = file.extension ?? 'jpg';
      final contentType = extension.toLowerCase() == 'png'
          ? 'image/png'
          : extension.toLowerCase() == 'webp'
              ? 'image/webp'
              : 'image/jpeg';

      final path =
          'empresas/${widget.empresaId}/eventos/${widget.eventoId}/croquis_mesas.$extension';

      final ref = FirebaseStorage.instance.ref(path);

      await ref.putData(
        bytes,
        SettableMetadata(contentType: contentType),
      );

      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('eventos')
          .doc(widget.eventoId)
          .update({
        'croquisUrl': url,
        'croquisPath': path,
        'croquisUpdatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Croquis de mesas actualizado')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error subiendo croquis: $e')),
      );
    } finally {
      if (mounted) setState(() => subiendoCroquis = false);
    }
  }

  void _verCroquis(String croquisUrl) {
    if (croquisUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este evento aún no tiene croquis')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: InteractiveViewer(
          child: Image.network(croquisUrl),
        ),
      ),
    );
  }

  bool _eventoCerrado(Map<String, dynamic> data) {
    final estado = (data['estado'] ?? '').toString();
    return estado == 'cerrado' || data['archivado'] == true;
  }

  @override
  Widget build(BuildContext context) {
    final eventoRef =
        FirebaseFirestore.instance.collection('eventos').doc(widget.eventoId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel del evento'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: eventoRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error cargando evento: ${snapshot.error}'),
            );
          }

          final data = snapshot.data?.data() ?? {};

          final nombre =
              (data['nombreEvento'] ?? widget.nombreEvento ?? 'Evento')
                  .toString();
          final lugar = (data['lugar'] ?? '').toString();
          final estado = (data['estado'] ?? 'abierto').toString();
          final usaAnfitriones = data['usaAnfitriones'] == true;
          final totalInvitados = (data['totalInvitados'] ?? 0).toString();
          final cantidadAnfitriones =
              (data['cantidadAnfitriones'] ?? 0).toString();
          final croquisUrl = (data['croquisUrl'] ?? '').toString();

          final inicio = data['fechaHoraInicio'] is Timestamp
              ? data['fechaHoraInicio'] as Timestamp
              : null;

          final fin = data['fechaHoraFin'] is Timestamp
              ? data['fechaHoraFin'] as Timestamp
              : null;

          final cerrado = _eventoCerrado(data);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                nombre,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text('Lugar: $lugar'),
              Text('Estado: $estado'),
              Text('Invitados permitidos: $totalInvitados'),
              Text('Usa anfitriones: ${usaAnfitriones ? "Sí" : "No"}'),
              if (usaAnfitriones)
                Text('Máximo de anfitriones: $cantidadAnfitriones'),
              Text('Inicio: ${_formatearFecha(inicio)}'),
              Text('Fin: ${_formatearFecha(fin)}'),
              Text(
                croquisUrl.isEmpty
                    ? 'Croquis de mesas: pendiente'
                    : 'Croquis de mesas: cargado',
              ),
              if (cerrado)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'Este evento está cerrado. Solo permite consulta, reporte y archivo.',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: cerrado
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditarEventoScreen(
                              eventoId: widget.eventoId,
                              empresaId: widget.empresaId,
                            ),
                          ),
                        );
                      },
                child: const Text('Editar evento'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed:
                    cerrado || subiendoCroquis ? null : _subirCroquisMesas,
                child: Text(
                  subiendoCroquis
                      ? 'Subiendo croquis...'
                      : 'Subir imagen de croquis / mesas',
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed:
                    croquisUrl.isEmpty ? null : () => _verCroquis(croquisUrl),
                child: const Text('Ver croquis de mesas'),
              ),
              const SizedBox(height: 12),
              if (usaAnfitriones)
                ElevatedButton(
                  onPressed: cerrado
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => GestionarAnfitrionesScreen(
                                eventoId: widget.eventoId,
                                empresaId: widget.empresaId,
                              ),
                            ),
                          );
                        },
                  child: const Text('Gestionar anfitriones'),
                )
              else
                const Text(
                  'Este evento no usa anfitriones.',
                  style: TextStyle(color: Colors.grey),
                ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: cerrado
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CrearInvitadoScreen(
                              eventoId: widget.eventoId,
                              empresaId: widget.empresaId,
                              nombreEvento: nombre,
                              fechaHoraInicio: inicio,
                              fechaHoraFin: fin,
                            ),
                          ),
                        );
                      },
                child: const Text('Agregar invitado'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: cerrado
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CargaInvitadosTxtScreen(
                              eventoId: widget.eventoId,
                            ),
                          ),
                        );
                      },
                child: const Text('Carga masiva TXT'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ListaInvitadosScreen(
                        eventoId: widget.eventoId,
                      ),
                    ),
                  );
                },
                child: const Text('Lista de invitados / compartir QRs'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReporteEventoScreen(
                        eventoId: widget.eventoId,
                        empresaId: widget.empresaId,
                      ),
                    ),
                  );
                },
                child: const Text('Reporte del evento'),
              ),
            ],
          );
        },
      ),
    );
  }
}
