import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerScreen extends StatefulWidget {
  final String eventoId;
  final String nombreEvento;
  final String horarioEvento;
  final String estadoVisible;

  const ScannerScreen({
    super.key,
    required this.eventoId,
    required this.nombreEvento,
    required this.horarioEvento,
    required this.estadoVisible,
  });

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  bool procesando = false;

  String resultado = 'Escanea un código QR';
  String nombreInvitado = '';
  String mesaInvitado = '';
  String invitadoDe = '';
  String tipoRegistro = '';
  String estadoActual = '';
  String croquisUrl = '';

  @override
  void initState() {
    super.initState();
    _cargarCroquis();
  }

  Future<void> _cargarCroquis() async {
    final doc = await FirebaseFirestore.instance
        .collection('eventos')
        .doc(widget.eventoId)
        .get();

    final data = doc.data() ?? {};

    if (!mounted) return;

    setState(() {
      croquisUrl = (data['croquisUrl'] ?? '').toString();
    });
  }

  void _verCroquis() {
    if (croquisUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este evento no tiene croquis cargado')),
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

  Map<String, dynamic>? _parsePayload(String rawValue) {
    try {
      final decoded = jsonDecode(rawValue);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      if (decoded is String) {
        final decodedTwice = jsonDecode(decoded);
        if (decodedTwice is Map<String, dynamic>) {
          return decodedTwice;
        }
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> _cargarUsuarioActual() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    if (uid.isEmpty) {
      return {
        'uid': '',
        'rol': '',
        'nombre': '',
        'email': '',
      };
    }

    final doc =
        await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();

    final data = doc.data() ?? {};

    return {
      'uid': uid,
      'rol': (data['rol'] ?? '').toString(),
      'nombre': (data['nombre'] ?? '').toString(),
      'email': (data['email'] ?? '').toString(),
    };
  }

  void _limpiarResultado(String mensaje) {
    setState(() {
      resultado = mensaje;
      nombreInvitado = '';
      mesaInvitado = '';
      invitadoDe = '';
      tipoRegistro = '';
      estadoActual = '';
    });
  }

  Future<void> procesarQR(String rawValue) async {
    if (procesando) return;

    setState(() {
      procesando = true;
      resultado = 'Procesando QR...';
    });

    try {
      final payload = _parsePayload(rawValue);

      if (payload == null) {
        _limpiarResultado('QR inválido');
        return;
      }

      final qrEventoId =
          ((payload['eventoId'] ?? payload['eventId']) ?? '').toString().trim();

      final invitadoId = ((payload['invitadoId'] ?? payload['guestId']) ?? '')
          .toString()
          .trim();

      if (qrEventoId.isEmpty || invitadoId.isEmpty) {
        _limpiarResultado('QR inválido');
        return;
      }

      if (qrEventoId != widget.eventoId) {
        _limpiarResultado('Este QR no pertenece al evento activo');
        return;
      }

      final docRef = FirebaseFirestore.instance
          .collection('eventos')
          .doc(widget.eventoId)
          .collection('invitados')
          .doc(invitadoId);

      final doc = await docRef.get();

      if (!doc.exists) {
        _limpiarResultado('Invitado no encontrado');
        return;
      }

      final data = doc.data() ?? {};

      final nombre =
          (data['nombre_invitado'] ?? data['nombre'] ?? '').toString();

      final mesa = (data['mesa'] ?? '').toString();

      final invitadoPor =
          (data['anfitrionNombre'] ?? data['invitadoDe'] ?? '').toString();

      final estado = (data['estado_asistencia'] ?? 'pendiente').toString();

      final esAnfitrion = data['esAnfitrion'] == true;

      final tipo = esAnfitrion ? 'Anfitrión' : 'Invitado';

      if (estado == 'ingresado') {
        setState(() {
          resultado = 'Ingreso duplicado';
          nombreInvitado = nombre;
          mesaInvitado = mesa;
          invitadoDe = invitadoPor;
          tipoRegistro = tipo;
          estadoActual = estado;
        });
        return;
      }

      final usuarioActual = await _cargarUsuarioActual();

      await docRef.update({
        'estado_asistencia': 'ingresado',
        'checkInAt': FieldValue.serverTimestamp(),
        'horaIngreso': FieldValue.serverTimestamp(),
        'ingresadoPorUid': (usuarioActual['uid'] ?? '').toString(),
        'ingresadoPorRol': (usuarioActual['rol'] ?? '').toString(),
        'ingresadoPorNombre': (usuarioActual['nombre'] ?? '').toString(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        resultado = 'Ingreso correcto';
        nombreInvitado = nombre;
        mesaInvitado = mesa;
        invitadoDe = invitadoPor;
        tipoRegistro = tipo;
        estadoActual = 'ingresado';
      });
    } catch (e) {
      _limpiarResultado('Error al escanear: $e');
    } finally {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() => procesando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final invitadosRef = FirebaseFirestore.instance
        .collection('eventos')
        .doc(widget.eventoId)
        .collection('invitados');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.nombreEvento),
        actions: [
          IconButton(
            icon: const Icon(Icons.map),
            onPressed: _verCroquis,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.nombreEvento,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(widget.horarioEvento),
                Text(widget.estadoVisible),
                Text(
                  croquisUrl.isEmpty
                      ? 'Croquis: no cargado'
                      : 'Croquis: disponible en el ícono de mapa',
                ),
                const SizedBox(height: 8),
                SelectableText('Evento ID: ${widget.eventoId}'),
              ],
            ),
          ),
          Expanded(
            flex: 5,
            child: MobileScanner(
              onDetect: (capture) {
                final barcodes = capture.barcodes;
                if (barcodes.isEmpty) return;

                final rawValue = barcodes.first.rawValue;
                if (rawValue == null) return;

                procesarQR(rawValue);
              },
            ),
          ),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                  Text(
                    resultado,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (nombreInvitado.isNotEmpty) ...[
                    Text('Nombre: $nombreInvitado'),
                    Text('Tipo: $tipoRegistro'),
                    Text('Mesa: $mesaInvitado'),
                    if (invitadoDe.isNotEmpty) Text('Invitado de: $invitadoDe'),
                    if (estadoActual.isNotEmpty)
                      Text('Estado actual: $estadoActual'),
                  ],
                  const SizedBox(height: 20),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: invitadosRef.snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final docs = snapshot.data!.docs;

                      final invitadosReales = docs.where((d) {
                        final data = d.data();
                        return data['esAnfitrion'] != true;
                      }).toList();

                      final anfitriones = docs.where((d) {
                        final data = d.data();
                        return data['esAnfitrion'] == true;
                      }).toList();

                      final invitadosIngresados = invitadosReales.where((d) {
                        return (d.data()['estado_asistencia'] ?? '') ==
                            'ingresado';
                      }).length;

                      final anfitrionesIngresados = anfitriones.where((d) {
                        return (d.data()['estado_asistencia'] ?? '') ==
                            'ingresado';
                      }).length;

                      final totalInvitados = invitadosReales.length;
                      final totalAnfitriones = anfitriones.length;

                      final faltanInvitados =
                          totalInvitados - invitadosIngresados;
                      final faltanAnfitriones =
                          totalAnfitriones - anfitrionesIngresados;

                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              const Text(
                                'Resumen de acceso',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text('Invitados registrados: $totalInvitados'),
                              Text(
                                  'Invitados ingresados: $invitadosIngresados'),
                              Text('Invitados faltantes: $faltanInvitados'),
                              const Divider(),
                              Text(
                                  'Anfitriones registrados: $totalAnfitriones'),
                              Text(
                                'Anfitriones ingresados: $anfitrionesIngresados',
                              ),
                              Text('Anfitriones faltantes: $faltanAnfitriones'),
                              const Divider(),
                              Text(
                                'Total personas registradas: ${totalInvitados + totalAnfitriones}',
                              ),
                              Text(
                                'Total personas ingresadas: ${invitadosIngresados + anfitrionesIngresados}',
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
