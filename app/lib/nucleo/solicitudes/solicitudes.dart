/// Solicitudes y recordatorios de GRAVITY para quien **no conversa** con él
/// (D18, cuidadora): GRAVITY le recuerda sus actividades y le hace
/// solicitudes; ella las confirma (*Hecho* o *No se pudo*, con nota).
///
/// Fase 1: datos de ejemplo en memoria (nada de la familia, nada clínico).
/// Cuando el servidor tenga su tabla, las confirmaciones se suben con la cola
/// sin conexión.
library;

/// Recordatorio de una actividad del turno o solicitud puntual de GRAVITY.
enum TipoSolicitud { recordatorio, solicitud }

enum EstadoSolicitud {
  pendiente,

  /// La persona la hizo.
  hecha,

  /// No se pudo; la nota dice por qué.
  noSePudo,
}

/// Largo máximo de la nota (convención de textos cortos).
const largoMaximoNota = 200;

class SolicitudGravity {
  const SolicitudGravity({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.hora,
    this.detalle,
    this.estado = EstadoSolicitud.pendiente,
    this.nota,
    this.confirmadaEn,
  });

  final String id;
  final TipoSolicitud tipo;
  final String titulo;
  final String? detalle;

  /// Cuándo toca.
  final DateTime hora;
  final EstadoSolicitud estado;
  final String? nota;
  final DateTime? confirmadaEn;

  bool get pendiente => estado == EstadoSolicitud.pendiente;

  /// Confirma la solicitud. *No se pudo* exige una nota; ninguna nota pasa de
  /// [largoMaximoNota] caracteres.
  SolicitudGravity confirmar(
    EstadoSolicitud resultado, {
    String? nota,
    required DateTime en,
  }) {
    if (resultado == EstadoSolicitud.pendiente) {
      throw ArgumentError.value(resultado, 'resultado');
    }
    final limpia = nota?.trim();
    if (resultado == EstadoSolicitud.noSePudo &&
        (limpia == null || limpia.isEmpty)) {
      throw ArgumentError('Escribe por qué no se pudo.');
    }
    if (limpia != null && limpia.length > largoMaximoNota) {
      throw ArgumentError('La nota pasa de $largoMaximoNota caracteres.');
    }
    return SolicitudGravity(
      id: id,
      tipo: tipo,
      titulo: titulo,
      hora: hora,
      detalle: detalle,
      estado: resultado,
      nota: (limpia == null || limpia.isEmpty) ? null : limpia,
      confirmadaEn: en,
    );
  }

  /// Vuelve a pendiente (deshacer).
  SolicitudGravity reabrir() => SolicitudGravity(
    id: id,
    tipo: tipo,
    titulo: titulo,
    hora: hora,
    detalle: detalle,
  );
}

/// Solicitudes de ejemplo de un turno de cuidados para el día de [hoy]. Sin
/// nombres, sin medicamentos y sin nada de la familia.
List<SolicitudGravity> solicitudesDeEjemplo(DateTime hoy) {
  DateTime a(int hora, int minuto) =>
      DateTime(hoy.year, hoy.month, hoy.day, hora, minuto);
  return [
    SolicitudGravity(
      id: 'ejemplo-1',
      tipo: TipoSolicitud.recordatorio,
      titulo: 'Ofrecer agua y anotar cuánto tomó',
      hora: a(9, 0),
    ),
    SolicitudGravity(
      id: 'ejemplo-2',
      tipo: TipoSolicitud.solicitud,
      titulo: 'Salir a caminar 15 minutos',
      detalle: 'Si el clima lo permite.',
      hora: a(11, 30),
    ),
    SolicitudGravity(
      id: 'ejemplo-3',
      tipo: TipoSolicitud.recordatorio,
      titulo: 'Revisar que la bitácora del turno esté al día',
      hora: a(14, 0),
    ),
    SolicitudGravity(
      id: 'ejemplo-4',
      tipo: TipoSolicitud.solicitud,
      titulo: 'Avisar si falta algo del botiquín',
      detalle: 'Para la próxima compra.',
      hora: a(17, 0),
    ),
  ];
}
