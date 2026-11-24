/// B1.3 · Bicicletas, mantenimiento por kilómetros y odómetro derivado (4.8,
/// PB-05, PB-11, PB-13).
///
/// **El odómetro no se guarda: se calcula** (RB4). Los intervalos iniciales
/// son un punto de partida **`borrador`, sin fuente** y editables; la pantalla
/// dice «Contenido en revisión» y «Confirma los intervalos con el manual de tu
/// bici o con tu taller».
library;

import '../fecha.dart';
import '../gimnasio/tipos.dart' show RevisionContenido;
import 'tipos_bici.dart';

/// Tareas del catálogo cerrado más los tipos de registro de
/// `hab_bici_mantenimientos.tarea`.
enum TareaMantenimiento {
  lubricarCadena('lubricar_cadena'),
  limpiarTransmision('limpiar_transmision'),
  revisarFrenosLlantas('revisar_frenos_llantas'),
  revisionGeneral('revision_general'),

  /// Una lectura del odómetro (4.8): fija el kilometraje de ese día.
  lecturaOdometro('lectura_odometro'),
  otra('otra');

  const TareaMantenimiento(this.id);
  final String id;

  /// Las cuatro tareas con intervalo (la lectura y «otra» no tocan).
  static const catalogo = [
    lubricarCadena,
    limpiarTransmision,
    revisarFrenosLlantas,
    revisionGeneral,
  ];

  static TareaMantenimiento? deId(String? id) {
    for (final t in values) {
      if (t.id == id) return t;
    }
    return null;
  }
}

/// Intervalo de una tarea: kilómetros enteros y/o semanas. Un campo vacío
/// (`null`) no cuenta; **ambos vacíos desactivan la tarea** (4.8).
class IntervaloMantenimiento {
  const IntervaloMantenimiento({this.km, this.semanas});
  final int? km;
  final int? semanas;

  bool get desactivado => km == null && semanas == null;

  /// Un intervalo de 0 (o negativo) se rechaza (CA-B-06).
  List<ErrorBici> validar() => [
    if (km != null && km! <= 0)
      ErrorBici('intervalo_km_invalido', 'km debe ser mayor que 0'),
    if (semanas != null && semanas! <= 0)
      ErrorBici('intervalo_semanas_invalido', 'semanas debe ser mayor que 0'),
  ];

  Map<String, Object?> aJson() => {'km': km, 'semanas': semanas};

  static IntervaloMantenimiento desdeJson(Map<String, Object?> m) =>
      IntervaloMantenimiento(
        km: m['km'] as int?,
        semanas: m['semanas'] as int?,
      );
}

/// Una tarea del catálogo con su valor inicial.
class TareaCatalogo {
  const TareaCatalogo({
    required this.tarea,
    required this.nombre,
    required this.kmInicial,
    required this.semanasInicial,
    this.origen = 'Propuesta sin fuente',
    this.revision = RevisionContenido.borrador,
  });

  final TareaMantenimiento tarea;
  final String nombre;
  final int kmInicial;
  final int semanasInicial;
  final String origen;

  /// Todo contenido de mantenimiento nace `borrador`.
  final RevisionContenido revision;

  IntervaloMantenimiento get intervaloInicial =>
      IntervaloMantenimiento(km: kmInicial, semanas: semanasInicial);
}

/// Intervalos iniciales (4.8): **propuestas sin fuente**, `borrador`.
const catalogoMantenimiento = <TareaCatalogo>[
  TareaCatalogo(
    tarea: TareaMantenimiento.lubricarCadena,
    nombre: 'Lubricar la cadena',
    kmInicial: 150,
    semanasInicial: 4,
  ),
  TareaCatalogo(
    tarea: TareaMantenimiento.limpiarTransmision,
    nombre: 'Limpiar la transmisión',
    kmInicial: 400,
    semanasInicial: 12,
  ),
  TareaCatalogo(
    tarea: TareaMantenimiento.revisarFrenosLlantas,
    nombre: 'Revisar frenos y llantas',
    kmInicial: 300,
    semanasInicial: 8,
  ),
  TareaCatalogo(
    tarea: TareaMantenimiento.revisionGeneral,
    nombre: 'Revisión general (taller)',
    kmInicial: 2000,
    semanasInicial: 26,
  ),
];

TareaCatalogo? tareaDelCatalogo(TareaMantenimiento t) {
  for (final c in catalogoMantenimiento) {
    if (c.tarea == t) return c;
  }
  return null;
}

enum TipoBicicleta {
  montana('montana'),
  ruta('ruta'),
  gravel('gravel'),
  urbana('urbana'),
  otra('otra');

  const TipoBicicleta(this.id);
  final String id;

  static TipoBicicleta? deId(String? id) {
    for (final t in values) {
      if (t.id == id) return t;
    }
    return null;
  }
}

const odometroMaximoM = 200000000;

/// Una bicicleta (`hab_bici_bicicletas`).
class Bicicleta {
  const Bicicleta({
    required this.id,
    required this.nombre,
    this.tipo,
    this.odometroInicialM = 0,
    this.intervalos = const {},
    this.activa = true,
  });

  final String id;

  /// De 1 a 40 caracteres, lo escribe la persona.
  final String nombre;
  final TipoBicicleta? tipo;

  /// Lo que ya tenía al registrarla, en metros (0 a 200 000 000).
  final int odometroInicialM;

  /// Intervalos propios. **Sin clave = los valores iniciales** del catálogo;
  /// con clave y ambos campos vacíos = tarea desactivada.
  final Map<TareaMantenimiento, IntervaloMantenimiento> intervalos;
  final bool activa;

  /// El intervalo vigente de una tarea del catálogo (null si no existe).
  IntervaloMantenimiento? intervaloDe(TareaMantenimiento t) =>
      intervalos[t] ?? tareaDelCatalogo(t)?.intervaloInicial;

  List<ErrorBici> validar() {
    final e = <ErrorBici>[];
    final n = nombre.trim();
    if (n.isEmpty || nombre.length > 40) {
      e.add(ErrorBici('nombre_invalido', 'el nombre va de 1 a 40 caracteres'));
    }
    if (odometroInicialM < 0 || odometroInicialM > odometroMaximoM) {
      e.add(ErrorBici('odometro_inicial_fuera_de_rango', '$odometroInicialM'));
    }
    for (final i in intervalos.entries) {
      e.addAll(i.value.validar());
    }
    return e;
  }

  /// Fila de `hab_bici_bicicletas`. Sin ubicación.
  Map<String, Object?> aJson() => {
    'id': id,
    'nombre': nombre,
    'tipo': tipo?.id,
    'odometro_inicial_m': odometroInicialM,
    'intervalos': intervalos.isEmpty
        ? null
        : {for (final i in intervalos.entries) i.key.id: i.value.aJson()},
    'activa': activa,
  };
}

/// Un hecho de `hab_bici_mantenimientos`: una tarea hecha o una lectura del
/// odómetro.
class RegistroMantenimiento {
  const RegistroMantenimiento({
    required this.id,
    required this.bicicletaId,
    required this.tarea,
    required this.fecha,
    this.odometroM,
    this.nota,
  });

  final String id;
  final String bicicletaId;
  final TareaMantenimiento tarea;
  final DateTime fecha;

  /// Obligatorio en `lectura_odometro`; opcional en lo demás.
  final int? odometroM;

  /// Hasta 120 caracteres; sin lugares ni nombres de talleres (se recomienda
  /// en pantalla; no se puede validar).
  final String? nota;

  bool get esLectura => tarea == TareaMantenimiento.lecturaOdometro;

  List<ErrorBici> validar() {
    final e = <ErrorBici>[];
    if (esLectura && odometroM == null) {
      e.add(ErrorBici('lectura_sin_odometro', 'la lectura necesita km'));
    }
    if (odometroM != null && (odometroM! < 0 || odometroM! > odometroMaximoM)) {
      e.add(ErrorBici('odometro_fuera_de_rango', '$odometroM'));
    }
    if (nota != null && nota!.length > 120) {
      e.add(ErrorBici('nota_larga', '${nota!.length}'));
    }
    return e;
  }

  Map<String, Object?> aJson() => {
    'id': id,
    'bicicleta_id': bicicletaId,
    'tarea': tarea.id,
    'fecha': fechaIso(fecha),
    'odometro_m': odometroM,
    'nota': nota,
  };
}

// ---------------------------------------------------------------------------
// Odómetro derivado (RB4, PB-05)
// ---------------------------------------------------------------------------

/// Kilometraje de la bici, en metros:
/// **última lectura (o el odómetro inicial) + suma de las distancias de las
/// salidas con esa bici posteriores a esa lectura.**
///
/// - «Posteriores» = de un día **después** de la lectura (una salida del mismo
///   día ya está en lo que marcó el aparato).
/// - Una salida omitida, sin distancia o **sin bicicleta** no suma a ninguna.
/// - [hasta] limita el cálculo a ese día inclusive (el odómetro «de ese día»).
int odometroM({
  required Bicicleta bici,
  List<RegistroMantenimiento> mantenimientos = const [],
  List<Salida> salidas = const [],
  DateTime? hasta,
}) {
  final tope = hasta == null ? null : soloDia(hasta);
  RegistroMantenimiento? lectura;
  for (final r in mantenimientos) {
    if (!r.esLectura || r.bicicletaId != bici.id || r.odometroM == null) {
      continue;
    }
    if (tope != null && soloDia(r.fecha).isAfter(tope)) continue;
    if (lectura == null || !soloDia(r.fecha).isBefore(soloDia(lectura.fecha))) {
      lectura = r;
    }
  }
  var total = lectura?.odometroM ?? bici.odometroInicialM;
  final desde = lectura == null ? null : soloDia(lectura.fecha);
  for (final s in salidas) {
    if (!s.cuenta || s.bicicletaId != bici.id || s.distanciaM == null) continue;
    final d = soloDia(s.fecha);
    if (desde != null && !d.isAfter(desde)) continue;
    if (tope != null && d.isAfter(tope)) continue;
    total += s.distanciaM!;
  }
  return total;
}

// ---------------------------------------------------------------------------
// Qué toca (4.8)
// ---------------------------------------------------------------------------

/// Estado de una tarea: **sin registro no es vencida** (sin culpa, RB6).
enum EstadoTarea { sinRegistro, alDia, toca, desactivada }

class TareaEstado {
  const TareaEstado({
    required this.tarea,
    required this.estado,
    this.kmDesdeM,
    this.semanasDesde,
    this.kmFaltanM,
    this.semanasFaltan,
  });

  final TareaMantenimiento tarea;
  final EstadoTarea estado;

  /// Desde el último registro de la tarea (null si no hay registro).
  final int? kmDesdeM;
  final int? semanasDesde;

  /// Lo que falta para que toque, por cada intervalo configurado (0 si ya).
  final int? kmFaltanM;
  final int? semanasFaltan;

  /// **No bloquea nada** y no genera notificaciones propias (PB-13).
  bool get bloquea => false;
}

/// Estado de las cuatro tareas del catálogo de [bici] a [hoy].
///
/// Una tarea **toca** cuando se cumple lo primero de: los km desde su último
/// registro llegan al intervalo, o las semanas llegan al intervalo.
List<TareaEstado> estadoMantenimiento({
  required Bicicleta bici,
  required List<RegistroMantenimiento> mantenimientos,
  List<Salida> salidas = const [],
  required DateTime hoy,
}) {
  final actual = odometroM(
    bici: bici,
    mantenimientos: mantenimientos,
    salidas: salidas,
    hasta: hoy,
  );
  final r = <TareaEstado>[];
  for (final t in TareaMantenimiento.catalogo) {
    final iv = bici.intervaloDe(t) ?? const IntervaloMantenimiento();
    if (iv.desactivado) {
      r.add(TareaEstado(tarea: t, estado: EstadoTarea.desactivada));
      continue;
    }
    RegistroMantenimiento? ultimo;
    for (final m in mantenimientos) {
      if (m.tarea != t || m.bicicletaId != bici.id) continue;
      if (ultimo == null || !soloDia(m.fecha).isBefore(soloDia(ultimo.fecha))) {
        ultimo = m;
      }
    }
    if (ultimo == null) {
      r.add(TareaEstado(tarea: t, estado: EstadoTarea.sinRegistro));
      continue;
    }
    final base =
        ultimo.odometroM ??
        odometroM(
          bici: bici,
          mantenimientos: mantenimientos,
          salidas: salidas,
          hasta: ultimo.fecha,
        );
    final km = actual - base < 0 ? 0 : actual - base;
    final dias = diasEntre(ultimo.fecha, hoy);
    final sem = dias < 0 ? 0 : dias ~/ 7;
    final faltaKm = iv.km == null ? null : _resto(iv.km! * 1000 - km);
    final faltaSem = iv.semanas == null ? null : _resto(iv.semanas! - sem);
    final toca =
        (faltaKm != null && faltaKm == 0) ||
        (faltaSem != null && faltaSem == 0);
    r.add(
      TareaEstado(
        tarea: t,
        estado: toca ? EstadoTarea.toca : EstadoTarea.alDia,
        kmDesdeM: km,
        semanasDesde: sem,
        kmFaltanM: faltaKm,
        semanasFaltan: faltaSem,
      ),
    );
  }
  return r;
}

int _resto(int n) => n < 0 ? 0 : n;

/// Solo las que tocan, en el orden del catálogo (la línea de la preparación
/// del viernes y de Bici › Mantenimiento).
List<TareaEstado> mantenimientoQueToca({
  required Bicicleta bici,
  required List<RegistroMantenimiento> mantenimientos,
  List<Salida> salidas = const [],
  required DateTime hoy,
}) => [
  for (final e in estadoMantenimiento(
    bici: bici,
    mantenimientos: mantenimientos,
    salidas: salidas,
    hoy: hoy,
  ))
    if (e.estado == EstadoTarea.toca) e,
];

/// El registro que guarda «Hecho»: la tarea, la fecha y el odómetro **de ese
/// día** (F-B7: 2 toques). El id lo pone la capa de datos (v5).
RegistroMantenimiento registrarHecho({
  required String id,
  required Bicicleta bici,
  required TareaMantenimiento tarea,
  required DateTime fecha,
  List<RegistroMantenimiento> mantenimientos = const [],
  List<Salida> salidas = const [],
  String? nota,
}) => RegistroMantenimiento(
  id: id,
  bicicletaId: bici.id,
  tarea: tarea,
  fecha: soloDia(fecha),
  odometroM: odometroM(
    bici: bici,
    mantenimientos: mantenimientos,
    salidas: salidas,
    hasta: fecha,
  ),
  nota: nota,
);
