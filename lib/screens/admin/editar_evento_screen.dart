import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class EditarEventoScreen extends StatefulWidget {
  final String eventoId;
  final String empresaId;

  const EditarEventoScreen({
    super.key,
    required this.eventoId,
    required this.empresaId,
  });

  @override
  State<EditarEventoScreen> createState() => _EditarEventoScreenState();
}

class _EditarEventoScreenState extends State<EditarEventoScreen> {
  final nombreEventoController = TextEditingController();
  final lugarController = TextEditingController();
  final totalInvitadosController = TextEditingController();
  final cantidadAnfitrionesController = TextEditingController();
  final diasGaleriaController = TextEditingController(text: '30');

  String? tipoEvento;
  String modoEncuestaExperiencia = 'todos';

  bool usaAnfitriones = false;
  bool loading = true;
  bool saving = false;

  DateTime? fechaInicio;
  TimeOfDay? horaInicio;
  DateTime? fechaFin;
  TimeOfDay? horaFin;

  DateTime? _combine(DateTime? date, TimeOfDay? time) {
    if (date == null || time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<int> _contarAnfitrionesActuales() async {
    final snap = await FirebaseFirestore.instance
        .collection('anfitriones_evento')
        .where('empresaId', isEqualTo: widget.empresaId)
        .where('eventoId', isEqualTo: widget.eventoId)
        .get();

    return snap.docs.length;
  }

  Future<int> _contarInvitadosRealesActuales() async {
    final snap = await FirebaseFirestore.instance
        .collection('eventos')
        .doc(widget.eventoId)
        .collection('invitados')
        .where('esAnfitrion', isEqualTo: false)
        .get();

    return snap.docs.length;
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
    cantidadAnfitrionesController.text =
        (data['cantidadAnfitriones'] ?? 0).toString();

    tipoEvento = (data['tipoEvento'] ?? '').toString().isEmpty
        ? null
        : (data['tipoEvento'] ?? '').toString();

    usaAnfitriones = data['usaAnfitriones'] == true;
    modoEncuestaExperiencia =
        (data['modoEncuestaExperiencia'] ?? 'todos').toString();

    final expiracion = data['fechaExpiracionGaleria'];
    if (expiracion is Timestamp && fin != null) {
      final dias = expiracion.toDate().difference(fin).inDays;
      diasGaleriaController.text = dias > 0 ? dias.toString() : '30';
    }

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
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
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
      firstDate:
          fechaInicio ?? DateTime.now().subtract(const Duration(days: 1)),
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
    final cantidadAnfitriones =
        int.tryParse(cantidadAnfitrionesController.text.trim()) ?? 0;
    final diasGaleria = int.tryParse(diasGaleriaController.text.trim()) ?? 30;

    final inicio = _combine(fechaInicio, horaInicio);
    final fin = _combine(fechaFin, horaFin);

    if (nombreEvento.isEmpty ||
        lugar.isEmpty ||
        tipoEvento == null ||
        totalInvitados <= 0 ||
        inicio == null ||
        fin == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos obligatorios')),
      );
      return;
    }

    if (!fin.isAfter(inicio)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La fecha/hora de fin debe ser mayor que la de inicio'),
        ),
      );
      return;
    }

    if (usaAnfitriones && cantidadAnfitriones <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Captura la cantidad máxima de anfitriones'),
        ),
      );
      return;
    }

    final anfitrionesActuales = await _contarAnfitrionesActuales();

    if (!usaAnfitriones && anfitrionesActuales > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Este evento ya tiene $anfitrionesActuales anfitrión(es). No puedes desactivar anfitriones.',
          ),
        ),
      );
      return;
    }

    if (usaAnfitriones && anfitrionesActuales > cantidadAnfitriones) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ya tienes $anfitrionesActuales anfitrión(es). No puedes bajar el máximo a $cantidadAnfitriones.',
          ),
        ),
      );
      return;
    }

    final invitadosRealesActuales = await _contarInvitadosRealesActuales();

    if (invitadosRealesActuales > totalInvitados) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ya tienes $invitadosRealesActuales invitados reales. No puedes bajar el total a $totalInvitados.',
          ),
        ),
      );
      return;
    }

    setState(() => saving = true);

    try {
      final fechaExpiracionGaleria = fin.add(Duration(days: diasGaleria));

      await FirebaseFirestore.instance
          .collection('eventos')
          .doc(widget.eventoId)
          .update({
        'nombreEvento': nombreEvento,
        'tipoEvento': tipoEvento,
        'lugar': lugar,
        'totalInvitados': totalInvitados,
        'usaAnfitriones': usaAnfitriones,
        'cantidadAnfitriones': usaAnfitriones ? cantidadAnfitriones : 0,
        'modoEncuestaExperiencia': modoEncuestaExperiencia,
        'fechaHoraInicio': Timestamp.fromDate(inicio),
        'fechaHoraFin': Timestamp.fromDate(fin),
        'fechaExpiracionGaleria': Timestamp.fromDate(fechaExpiracionGaleria),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Evento actualizado correctamente')),
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
    cantidadAnfitrionesController.dispose();
    diasGaleriaController.dispose();
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
      'corporativo',
      'otro',
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
              decoration: const InputDecoration(labelText: 'Tipo de evento'),
              hint: const Text('Selecciona tipo de evento'),
              items: tipos
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (value) {
                setState(() => tipoEvento = value);
              },
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
                labelText: 'Cantidad total de invitados',
                helperText: 'No incluye anfitriones',
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Permitir gestión de anfitriones'),
              subtitle: const Text(
                'Los anfitriones son extra al total de invitados',
              ),
              value: usaAnfitriones,
              onChanged: (value) {
                setState(() {
                  usaAnfitriones = value;
                  if (!value) {
                    cantidadAnfitrionesController.text = '0';
                  }
                });
              },
            ),
            if (usaAnfitriones) ...[
              const SizedBox(height: 8),
              TextField(
                controller: cantidadAnfitrionesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Cantidad máxima de anfitriones',
                ),
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: modoEncuestaExperiencia,
              decoration: const InputDecoration(
                labelText: 'Quién puede responder encuesta',
              ),
              items: const [
                DropdownMenuItem(
                  value: 'todos',
                  child: Text('Todos los invitados'),
                ),
                DropdownMenuItem(
                  value: 'solo_anfitriones',
                  child: Text('Solo anfitriones'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => modoEncuestaExperiencia = value);
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: diasGaleriaController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Días de vigencia de la galería',
              ),
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
