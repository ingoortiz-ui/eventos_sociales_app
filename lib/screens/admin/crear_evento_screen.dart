import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nombreEventoController = TextEditingController();
  final TextEditingController _lugarController = TextEditingController();
  final TextEditingController _totalInvitadosController =
      TextEditingController();
  final TextEditingController _cantidadAnfitrionesController =
      TextEditingController();
  final TextEditingController _diasGaleriaController =
      TextEditingController(text: '30');

  String? _tipoEvento;
  String _modoEncuestaExperiencia = 'todos';

  bool _usaAnfitriones = false;
  bool _guardando = false;

  DateTime? _fechaInicio;
  TimeOfDay? _horaInicio;
  DateTime? _fechaFin;
  TimeOfDay? _horaFin;

  Future<void> _seleccionarFechaInicio() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaInicio ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime(2035),
    );

    if (picked != null) {
      setState(() => _fechaInicio = picked);
    }
  }

  Future<void> _seleccionarHoraInicio() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _horaInicio ?? TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() => _horaInicio = picked);
    }
  }

  Future<void> _seleccionarFechaFin() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaFin ?? (_fechaInicio ?? DateTime.now()),
      firstDate: _fechaInicio ??
          DateTime.now().subtract(
            const Duration(days: 1),
          ),
      lastDate: DateTime(2035),
    );

    if (picked != null) {
      setState(() => _fechaFin = picked);
    }
  }

  Future<void> _seleccionarHoraFin() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _horaFin ?? TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() => _horaFin = picked);
    }
  }

  DateTime? _combinarFechaHora(DateTime? fecha, TimeOfDay? hora) {
    if (fecha == null || hora == null) return null;

    return DateTime(
      fecha.year,
      fecha.month,
      fecha.day,
      hora.hour,
      hora.minute,
    );
  }

  Future<void> _guardarEvento() async {
    if (!_formKey.currentState!.validate()) return;

    final fechaHoraInicio = _combinarFechaHora(_fechaInicio, _horaInicio);
    final fechaHoraFin = _combinarFechaHora(_fechaFin, _horaFin);

    if (fechaHoraInicio == null || fechaHoraFin == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona fecha y hora de inicio y fin'),
        ),
      );
      return;
    }

    if (!fechaHoraFin.isAfter(fechaHoraInicio)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La fecha/hora de fin debe ser mayor que la de inicio'),
        ),
      );
      return;
    }

    final totalInvitados =
        int.tryParse(_totalInvitadosController.text.trim()) ?? 0;

    final cantidadAnfitriones =
        int.tryParse(_cantidadAnfitrionesController.text.trim()) ?? 0;

    final diasGaleria = int.tryParse(_diasGaleriaController.text.trim()) ?? 30;

    if (_usaAnfitriones && cantidadAnfitriones <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Captura la cantidad máxima de anfitriones'),
        ),
      );
      return;
    }

    setState(() => _guardando = true);

    try {
      final fechaExpiracionGaleria =
          fechaHoraFin.add(Duration(days: diasGaleria));

      await FirebaseFirestore.instance.collection('eventos').add({
        'empresaId': widget.empresaId,
        'nombreEvento': _nombreEventoController.text.trim(),
        'tipoEvento': _tipoEvento,
        'lugar': _lugarController.text.trim(),

        // Invitados reales. NO incluye anfitriones.
        'totalInvitados': totalInvitados,

        // Nueva lógica de anfitriones.
        'usaAnfitriones': _usaAnfitriones,
        'cantidadAnfitriones': _usaAnfitriones ? cantidadAnfitriones : 0,

        // Encuesta.
        'modoEncuestaExperiencia': _modoEncuestaExperiencia,

        // El estado siempre inicia abierto.
        'estado': 'abierto',

        // Fechas.
        'fechaHoraInicio': Timestamp.fromDate(fechaHoraInicio),
        'fechaHoraFin': Timestamp.fromDate(fechaHoraFin),
        'fechaExpiracionGaleria': Timestamp.fromDate(fechaExpiracionGaleria),

        // Campos base.
        'galeriaCompartible': true,
        'croquisUrl': '',

        // Auditoría.
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Evento creado correctamente')),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creando evento: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  @override
  void dispose() {
    _nombreEventoController.dispose();
    _lugarController.dispose();
    _totalInvitadosController.dispose();
    _cantidadAnfitrionesController.dispose();
    _diasGaleriaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tiposEvento = [
      'boda',
      'xv_anios',
      'bautizo',
      'graduacion',
      'aniversario',
      'corporativo',
      'otro',
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear evento'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nombreEventoController,
              decoration: const InputDecoration(
                labelText: 'Nombre del evento',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Captura el nombre del evento';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _tipoEvento,
              decoration: const InputDecoration(
                labelText: 'Tipo de evento',
              ),
              hint: const Text('Selecciona tipo de evento'),
              items: tiposEvento
                  .map(
                    (tipo) => DropdownMenuItem(
                      value: tipo,
                      child: Text(tipo),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() => _tipoEvento = value);
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Selecciona el tipo de evento';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _lugarController,
              decoration: const InputDecoration(
                labelText: 'Lugar del evento',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Captura el lugar del evento';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _totalInvitadosController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Cantidad total de invitados',
                helperText: 'No incluye anfitriones',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Captura el total de invitados';
                }

                final n = int.tryParse(value.trim());
                if (n == null || n <= 0) {
                  return 'Debe ser un número mayor a cero';
                }

                return null;
              },
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Permitir gestión de anfitriones'),
              subtitle: const Text(
                'Los anfitriones serán extra al total de invitados',
              ),
              value: _usaAnfitriones,
              onChanged: (value) {
                setState(() {
                  _usaAnfitriones = value;
                  if (!value) {
                    _cantidadAnfitrionesController.clear();
                  }
                });
              },
            ),
            if (_usaAnfitriones) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _cantidadAnfitrionesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Cantidad máxima de anfitriones',
                ),
                validator: (value) {
                  if (!_usaAnfitriones) return null;

                  if (value == null || value.trim().isEmpty) {
                    return 'Captura la cantidad máxima de anfitriones';
                  }

                  final n = int.tryParse(value.trim());
                  if (n == null || n <= 0) {
                    return 'Debe ser un número mayor a cero';
                  }

                  return null;
                },
              ),
            ],
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _modoEncuestaExperiencia,
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
                  setState(() => _modoEncuestaExperiencia = value);
                }
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _diasGaleriaController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Días de vigencia de la galería',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Captura los días de vigencia';
                }

                final n = int.tryParse(value.trim());
                if (n == null || n <= 0) {
                  return 'Debe ser un número mayor a cero';
                }

                return null;
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _seleccionarFechaInicio,
              child: Text(
                _fechaInicio == null
                    ? 'Seleccionar fecha de inicio'
                    : 'Fecha inicio: ${_fechaInicio!.day}/${_fechaInicio!.month}/${_fechaInicio!.year}',
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _seleccionarHoraInicio,
              child: Text(
                _horaInicio == null
                    ? 'Seleccionar hora de inicio'
                    : 'Hora inicio: ${_horaInicio!.format(context)}',
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _seleccionarFechaFin,
              child: Text(
                _fechaFin == null
                    ? 'Seleccionar fecha de fin'
                    : 'Fecha fin: ${_fechaFin!.day}/${_fechaFin!.month}/${_fechaFin!.year}',
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _seleccionarHoraFin,
              child: Text(
                _horaFin == null
                    ? 'Seleccionar hora de fin'
                    : 'Hora fin: ${_horaFin!.format(context)}',
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _guardando ? null : _guardarEvento,
              child: Text(_guardando ? 'Guardando...' : 'Guardar evento'),
            ),
          ],
        ),
      ),
    );
  }
}
