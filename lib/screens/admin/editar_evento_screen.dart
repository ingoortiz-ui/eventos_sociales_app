import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class EditarEventoScreen extends StatefulWidget {
  final String eventoId;

  const EditarEventoScreen({
    super.key,
    required this.eventoId,
  });

  @override
  State<EditarEventoScreen> createState() => _EditarEventoScreenState();
}

class _EditarEventoScreenState extends State<EditarEventoScreen> {
  final nombreEventoController = TextEditingController();
  final lugarController = TextEditingController();
  final totalInvitadosController = TextEditingController();

  String tipoEvento = 'boda';
  DateTime? fechaInicio;
  TimeOfDay? horaInicio;
  DateTime? fechaFin;
  TimeOfDay? horaFin;

  bool loading = true;
  bool saving = false;

  DateTime? _combine(DateTime? date, TimeOfDay? time) {
    if (date == null || time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> cargarEvento() async {
    final doc = await FirebaseFirestore.instance
        .collection('eventos')
        .doc(widget.eventoId)
        .get();

    final data = doc.data() ?? {};

    final inicioTs = data['fechaHoraInicio'];
    final finTs = data['fechaHoraFin'];

    final inicio = inicioTs is Timestamp ? inicioTs.toDate() : null;
    final fin = finTs is Timestamp ? finTs.toDate() : null;

    nombreEventoController.text = (data['nombreEvento'] ?? '').toString();
    lugarController.text = (data['lugar'] ?? '').toString();
    totalInvitadosController.text = (data['totalInvitados'] ?? '').toString();
    tipoEvento = (data['tipoEvento'] ?? 'boda').toString();

    if (inicio != null) {
      fechaInicio = DateTime(inicio.year, inicio.month, inicio.day);
      horaInicio = TimeOfDay(hour: inicio.hour, minute: inicio.minute);
    }

    if (fin != null) {
      fechaFin = DateTime(fin.year, fin.month, fin.day);
      horaFin = TimeOfDay(hour: fin.hour, minute: fin.minute);
    }

    setState(() => loading = false);
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

  Future<void> guardarCambios() async {
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
        fin == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos')),
      );
      return;
    }

    setState(() => saving = true);

    try {
      await FirebaseFirestore.instance
          .collection('eventos')
          .doc(widget.eventoId)
          .update({
        'nombreEvento': nombreEvento,
        'tipoEvento': tipoEvento,
        'lugar': lugar,
        'totalInvitados': totalInvitados,
        'fechaHoraInicio': Timestamp.fromDate(inicio),
        'fechaHoraFin': Timestamp.fromDate(fin),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Evento actualizado')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error actualizando evento: $e')),
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

    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar evento'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
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
                if (value != null) setState(() => tipoEvento = value);
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
              onPressed: saving ? null : guardarCambios,
              child: Text(saving ? 'Guardando...' : 'Guardar cambios'),
            ),
          ],
        ),
      ),
    );
  }
}
