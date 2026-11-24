/// Tipos de la bicicleta (5.2): la salida y sus listas cerradas.
///
/// **Sin ubicación:** ningún tipo de este archivo lleva latitud, longitud,
/// trazo, nombre ni enlace de ruta, domicilio ni contacto, y la salida **no
/// se enlaza con ninguna ruta** (PB-04, CA-B-18). Esas cosas viven solo en el
/// tipo local `ubicacion_local` y este paquete no las modela.
library;

import '../fecha.dart';

/// Un problema de validación: código estable + detalle.
class ErrorBici {
  const ErrorBici(this.codigo, this.detalle);
  final String codigo;
  final String detalle;

  @override
  String toString() => '$codigo: $detalle';
}

/// Superficie de la salida completa (`hab_bici_salidas.superficie`).
enum SuperficieSalida {
  calle('calle'),
  terreno('terreno'),
  mixta('mixta');

  const SuperficieSalida(this.id);
  final String id;

  static SuperficieSalida? deId(String? id) {
    for (final s in values) {
      if (s.id == id) return s;
    }
    return null;
  }
}

/// Las cinco casillas del clima (4.3); el id es el de la columna `clima`.
enum ClimaSalida {
  despejado('despejado'),
  nublado('nublado'),
  lluvia('lluvia'),
  calor('calor'),
  frio('frio');

  const ClimaSalida(this.id);
  final String id;

  static ClimaSalida? deId(String? id) {
    for (final c in values) {
      if (c.id == id) return c;
    }
    return null;
  }
}

enum EstadoSalida {
  hecha('hecha'),
  parcial('parcial'),
  omitida('omitida');

  const EstadoSalida(this.id);
  final String id;

  static EstadoSalida? deId(String? id) {
    for (final s in values) {
      if (s.id == id) return s;
    }
    return null;
  }
}

/// Por qué no salió (solo con estado `omitida`, 4.11).
enum MotivoOmision {
  clima('clima'),
  seguridad('seguridad'),
  otra('otra');

  const MotivoOmision(this.id);
  final String id;

  static MotivoOmision? deId(String? id) {
    for (final m in values) {
      if (m.id == id) return m;
    }
    return null;
  }
}

/// Fecha `AAAA-MM-DD` de un día.
String fechaIso(DateTime f) {
  final d = soloDia(f);
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${d.year.toString().padLeft(4, '0')}-${dos(d.month)}-${dos(d.day)}';
}

/// Hora `H:MM` de unos minutos desde la medianoche (480 → `8:00`).
String horaTexto(int minutos) {
  final m = ((minutos % 1440) + 1440) % 1440;
  return '${m ~/ 60}:${(m % 60).toString().padLeft(2, '0')}';
}

/// Duración en palabras cortas: 2205 → `36 h 45 min`; 45 → `45 min`.
String duracionTexto(int minutos) {
  final h = minutos ~/ 60;
  final m = minutos % 60;
  if (h == 0) return '$m min';
  if (m == 0) return '$h h';
  return '$h h $m min';
}

/// Una salida en la bici (`hab_bici_salidas`): números sin lugar.
///
/// La **distancia la escribe la persona**: la app no la valida contra un mapa.
class Salida {
  const Salida({
    required this.id,
    required this.fecha,
    this.n = 1,
    this.bloqueId,
    this.bicicletaId,
    this.inicioMin,
    this.duracionMin,
    this.distanciaM,
    this.desnivelM,
    this.superficie,
    this.esfuerzo,
    this.clima,
    this.acompanado = false,
    this.estado = EstadoSalida.hecha,
    this.motivo,
  });

  final String id;
  final DateTime fecha;

  /// Número de salida del día (1 a 3).
  final int n;
  final String? bloqueId;
  final String? bicicletaId;

  /// Minutos desde la medianoche.
  final int? inicioMin;
  final int? duracionMin;

  /// Metros enteros.
  final int? distanciaM;
  final int? desnivelM;
  final SuperficieSalida? superficie;

  /// 1 muy ligero … 5 al límite.
  final int? esfuerzo;
  final ClimaSalida? clima;

  /// Casilla «Salí acompañado», **sin identificar a nadie**.
  final bool acompanado;
  final EstadoSalida estado;
  final MotivoOmision? motivo;

  /// ¿La persona salió (hecha o parcial)? Una omitida no suma nada.
  bool get cuenta => estado != EstadoSalida.omitida;

  /// Errores de rango (los de las columnas, CA-B-17); lista vacía = válida.
  List<ErrorBici> validar() {
    final e = <ErrorBici>[];
    void mal(String c, String d) => e.add(ErrorBici(c, d));
    if (n < 1 || n > 3) mal('n_fuera_de_rango', '$n');
    if (duracionMin != null && (duracionMin! < 1 || duracionMin! > 1440)) {
      mal('duracion_fuera_de_rango', '$duracionMin');
    }
    if (distanciaM != null && (distanciaM! < 0 || distanciaM! > 1000000)) {
      mal('distancia_fuera_de_rango', '$distanciaM');
    }
    if (desnivelM != null && (desnivelM! < 0 || desnivelM! > 20000)) {
      mal('desnivel_fuera_de_rango', '$desnivelM');
    }
    if (esfuerzo != null && (esfuerzo! < 1 || esfuerzo! > 5)) {
      mal('esfuerzo_fuera_de_rango', '$esfuerzo');
    }
    if (inicioMin != null && (inicioMin! < 0 || inicioMin! >= 1440)) {
      mal('inicio_fuera_del_dia', '$inicioMin');
    }
    if (motivo != null && estado != EstadoSalida.omitida) {
      mal('motivo_sin_omision', 'el motivo solo va con estado omitida');
    }
    return e;
  }

  /// Fila de `hab_bici_salidas` (lo único que puede subir a tu hogar). Sin
  /// ubicación, sin ruta, sin enlaces. `persona_id`, `hogar_id` y
  /// `actualizado_en` los pone el servidor.
  Map<String, Object?> aJson() => {
    'id': id,
    'fecha': fechaIso(fecha),
    'n': n,
    'bloque_id': bloqueId,
    'bicicleta_id': bicicletaId,
    'inicio': inicioMin == null ? null : _horaSql(inicioMin!),
    'duracion_min': duracionMin,
    'distancia_m': distanciaM,
    'desnivel_m': desnivelM,
    'superficie': superficie?.id,
    'esfuerzo': esfuerzo,
    'clima': clima?.id,
    'acompanado': acompanado,
    'estado': estado.id,
    'motivo': motivo?.id,
  };
}

String _horaSql(int min) =>
    '${(min ~/ 60).toString().padLeft(2, '0')}:'
    '${(min % 60).toString().padLeft(2, '0')}';

/// Las salidas que cuentan, de la más reciente a la más antigua.
List<Salida> salidasRecientes(Iterable<Salida> salidas) =>
    [
      for (final s in salidas)
        if (s.cuenta) s,
    ]..sort((a, b) {
      final c = soloDia(b.fecha).compareTo(soloDia(a.fecha));
      return c != 0 ? c : b.n.compareTo(a.n);
    });
