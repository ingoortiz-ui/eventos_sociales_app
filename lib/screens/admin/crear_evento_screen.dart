import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'panel_evento_screen.dart';

class CrearEventoScreen extends StatefulWidget {
  final String empresaId;

  const CrearEventoScreen({
    super.key,
    required this.empresaId,
  });

  @override
  State<CrearEventoScreen> createState() => _CrearEventoScreenState();
}

class _CrearEventoScreenState extends State<CrearEventoScreen> {
  final nombreEventoController = TextEditingController();
  final lugarController = TextEditingController();
  final totalInvitadosController = TextEditingController();

  String tipoEvento = 'boda';
  int cantidadAnfitriones = 2;

  DateTime? fechaInicio;
  TimeOfDay? horaInicio;
  DateTime? fechaFin;
  TimeOfDay? horaFin;

  bool saving = false;

  void _actualizarCantidadPorTipo(String tipo) {
    switch (tipo) {
      case 'boda':
        cantidadAnfitriones = 2;
        break;
      case 'aniversario':
        cantidadAnfitriones = 2;
        break;
      case 'xv_anios':
        cantidadAnfitriones = 1;
        break;
      case 'bautizo':
        cantidadAnfitriones = 2;
        break;
      case 'graduacion':
        cantidadAnfitriones = 3;
        break;
      default:
        cantidadAnfitriones = 1;
    }
  }

  Future<void> seleccionarFechaInicio() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: fechaInicio ?? DateTime.now(),
      firstDate: DateTime(2025),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => fechaInicio = picked);
    }
  }

  Future<void> seleccionarHoraInicio() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: horaInicio ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => horaInicio = picked);
    }
  }

  Future<void> seleccionarFechaFin() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: fechaFin ?? (fechaInicio ?? DateTime.now()),
      firstDate: DateTime(2025),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => fechaFin = picked);
    }
  }

  Future<void> seleccionarHoraFin() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: horaFin ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => horaFin = picked);
    }
  }

  DateTime? _combine(DateTime? date, TimeOfDay? time) {
    if (date == null || time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> guardar() async {
    final nombreEvento = nombreEventoController.text.trim();
    final lugar = lugarController.text.trim();
    final totalInvitados =
        int.tryParse(totalInvitadosController.text.trim()) ?? 0;

    final inicio = _combine(fechaInicio, horaInicio);
    final fin = _combine(fechaFin, horaFin);

    if (nombreEvento.isEmpty ||
        lugar.isEmpty ||
        totalInvitados <= 0 ||
        inicio == null ||
        fin == null ||
        cantidadAnfitriones <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos del evento')),
      );
      return;
    }

    setState(() => saving = true);

    try {
      final adminUid = FirebaseAuth.instance.currentUser?.uid ?? '';

      final docRef =
          await FirebaseFirestore.instance.collection('eventos').add({
        'empresaId': widget.empresaId,
        'nombreEvento': nombreEvento,
        'tipoEvento': tipoEvento,
        'lugar': lugar,
        'totalInvitados': totalInvitados,
        'cantidadAnfitriones': cantidadAnfitriones,
        'fechaHoraInicio': Timestamp.fromDate(inicio),
        'fechaHoraFin': Timestamp.fromDate(fin),
        'estado': 'abierto',
        'croquisUrl': '',
        'createdBy': adminUid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Evento creado correctamente')),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PanelEventoScreen(
            eventoId: docRef.id,
            empresaId: widget.empresaId,
            nombreEvento: nombreEvento,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creando evento: $e')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _actualizarCantidadPorTipo(tipoEvento);
  }

  @override
  void dispose() {
    nombreEventoController.dispose();
    lugarController.dispose();
    totalInvitadosController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tipos = [
      'boda',
      'xv_anios',
      'bautizo',
      'graduacion',
      'aniversario',
      'otro'
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear evento'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text('Empresa: ${widget.empresaId}'),
            const SizedBox(height: 16),
            TextField(
              controller: nombreEventoController,
              decoration: const InputDecoration(labelText: 'Nombre del evento'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: tipoEvento,
              items: tipos
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    tipoEvento = value;
                    _actualizarCantidadPorTipo(value);
                  });
                }
              },
              decoration: const InputDecoration(labelText: 'Tipo de evento'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: lugarController,
              decoration: const InputDecoration(labelText: 'Lugar del evento'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: totalInvitadosController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Cantidad total de invitados'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: cantidadAnfitriones.toString(),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Cantidad de anfitriones principales',
              ),
              onChanged: (value) {
                setState(() {
                  cantidadAnfitriones =
                      int.tryParse(value) ?? cantidadAnfitriones;
                });
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: seleccionarFechaInicio,
              child: Text(
                fechaInicio == null
                    ? 'Seleccionar fecha inicio'
                    : 'Fecha inicio: ${fechaInicio!.day}/${fechaInicio!.month}/${fechaInicio!.year}',
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: seleccionarHoraInicio,
              child: Text(
                horaInicio == null
                    ? 'Seleccionar hora inicio'
                    : 'Hora inicio: ${horaInicio!.format(context)}',
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: seleccionarFechaFin,
              child: Text(
                fechaFin == null
                    ? 'Seleccionar fecha fin'
                    : 'Fecha fin: ${fechaFin!.day}/${fechaFin!.month}/${fechaFin!.year}',
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: seleccionarHoraFin,
              child: Text(
                horaFin == null
                    ? 'Seleccionar hora fin'
                    : 'Hora fin: ${horaFin!.format(context)}',
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: saving ? null : guardar,
              child: Text(saving ? 'Guardando...' : 'Guardar evento'),
            ),
          ],
        ),
      ),
    );
  }
}
