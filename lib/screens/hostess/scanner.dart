import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
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

  Future<void> procesarQR(String rawValue) async {
    if (procesando) return;

    setState(() {
      procesando = true;
      resultado = 'Procesando QR...';
    });

    try {
      final payload = _parsePayload(rawValue);

      if (payload == null) {
        setState(() {
          resultado = 'QR inválido';
          nombreInvitado = '';
          mesaInvitado = '';
          invitadoDe = '';
        });
        return;
      }

      final qrEventoId =
          ((payload['eventoId'] ?? payload['eventId']) ?? '').toString().trim();

      final invitadoId = ((payload['invitadoId'] ?? payload['guestId']) ?? '')
          .toString()
          .trim();

      if (qrEventoId.isEmpty || invitadoId.isEmpty) {
        setState(() {
          resultado = 'QR inválido';
          nombreInvitado = '';
          mesaInvitado = '';
          invitadoDe = '';
        });
        return;
      }

      if (qrEventoId != widget.eventoId) {
        setState(() {
          resultado = 'Este QR no pertenece al evento activo';
          nombreInvitado = '';
          mesaInvitado = '';
          invitadoDe = '';
        });
        return;
      }

      final docRef = FirebaseFirestore.instance
          .collection('eventos')
          .doc(widget.eventoId)
          .collection('invitados')
          .doc(invitadoId);

      final doc = await docRef.get();

      if (!doc.exists) {
        setState(() {
          resultado = 'Invitado no encontrado';
          nombreInvitado = '';
          mesaInvitado = '';
          invitadoDe = '';
        });
        return;
      }

      final data = doc.data() ?? {};
      final nombre =
          (data['nombre_invitado'] ?? data['nombre'] ?? '').toString();
      final mesa = (data['mesa'] ?? '').toString();
      final invitadoPor = (data['invitadoDe'] ?? '').toString();
      final estado = (data['estado_asistencia'] ?? 'pendiente').toString();

      if (estado == 'ingresado') {
        setState(() {
          resultado = 'Ingreso duplicado';
          nombreInvitado = nombre;
          mesaInvitado = mesa;
          invitadoDe = invitadoPor;
        });
        return;
      }

      await docRef.update({
        'estado_asistencia': 'ingresado',
        'checkInAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        resultado = 'Ingreso correcto';
        nombreInvitado = nombre;
        mesaInvitado = mesa;
        invitadoDe = invitadoPor;
      });
    } catch (e) {
      setState(() {
        resultado = 'Error al escanear: $e';
        nombreInvitado = '';
        mesaInvitado = '';
        invitadoDe = '';
      });
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
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
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
                    Text('Invitado: $nombreInvitado'),
                    Text('Mesa: $mesaInvitado'),
                    if (invitadoDe.isNotEmpty) Text('Invitado de: $invitadoDe'),
                  ],
                  const SizedBox(height: 20),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: invitadosRef.snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const CircularProgressIndicator();
                      }

                      final docs = snapshot.data!.docs;
                      final total = docs.length;
                      final ingresados = docs
                          .where((d) =>
                              (d.data()['estado_asistencia'] ?? '') ==
                              'ingresado')
                          .length;
                      final faltan = total - ingresados;

                      return Column(
                        children: [
                          Text('Total invitados: $total'),
                          Text('Ingresados: $ingresados'),
                          Text('Faltan: $faltan'),
                        ],
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
