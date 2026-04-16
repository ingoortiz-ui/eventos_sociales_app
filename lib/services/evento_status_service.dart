import 'package:cloud_firestore/cloud_firestore.dart';

class EventoStatusService {
  static bool estaActivoEnHorario(Map<String, dynamic> data) {
    final now = DateTime.now();
    final estado = (data['estado'] ?? '').toString();
    final inicioTs = data['fechaHoraInicio'];
    final finTs = data['fechaHoraFin'];

    if (estado != 'abierto') return false;
    if (inicioTs == null || finTs == null) return false;

    final inicio = (inicioTs as Timestamp).toDate();
    final fin = (finTs as Timestamp).toDate();

    return now.isAfter(inicio) && now.isBefore(fin);
  }

  static bool estaAbiertoFueraDeHorario(Map<String, dynamic> data) {
    final now = DateTime.now();
    final estado = (data['estado'] ?? '').toString();
    final inicioTs = data['fechaHoraInicio'];
    final finTs = data['fechaHoraFin'];

    if (estado != 'abierto') return false;
    if (inicioTs == null || finTs == null) return false;

    final inicio = (inicioTs as Timestamp).toDate();
    final fin = (finTs as Timestamp).toDate();

    return now.isBefore(inicio) || now.isAfter(fin);
  }
}
