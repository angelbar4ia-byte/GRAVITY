/// B1.2 · Carga de piernas de la ruta y la regla de 48 horas del gimnasio
/// (4.6, PB-07, 12.2).
///
/// **No cambia la regla del gimnasio.** `revisarSemana` y `gruposDeTipo`
/// siguen exactamente como están (la bicicleta cuenta como cuádriceps y
/// glúteo, de inicio a inicio, con 47 h mínimas). Lo único que hace este
/// archivo es **decidir si la sesión `bici` se le entrega o no** a esa regla,
/// según la declaración de la persona (`carga_piernas`): con `ligera` la ruta
/// no entra a la revisión; con `por_esfuerzo`, según las últimas salidas.
/// Con `normal` (el valor por omisión) el resultado es idéntico al de llamar
/// a `revisarSemana` directamente. Con C el jueves o el viernes el aviso sigue
/// como hoy.
library;

import '../gimnasio/plan_semana.dart';
import '../gimnasio/reglas.dart';
import '../gimnasio/tipos.dart';
import 'reglas_bici.dart';
import 'tipos_bici.dart';

/// ¿La ruta cuenta como piernas para las 48 horas? (CA-B-04)
///
/// - `normal`: sí.
/// - `ligera`: no.
/// - `por_esfuerzo`: sí si alguna de las últimas tres salidas **con esfuerzo
///   registrado** fue de 3 o más; no si todas quedaron por debajo de 3; y sin
///   salidas con esfuerzo registrado, sí (se asume carga normal).
bool biciCuentaComoPiernas({
  CargaPiernas? carga,
  List<Salida> salidas = const [],
  ReglasBicicleta reglas = const ReglasBicicleta(),
}) {
  switch (carga ?? reglas.cargaPiernas) {
    case CargaPiernas.normal:
      return true;
    case CargaPiernas.ligera:
      return false;
    case CargaPiernas.porEsfuerzo:
      final ultimas = salidasRecientes(salidas)
          .take(reglas.salidasParaEsfuerzo)
          .toList();
      final esfuerzos = [
        for (final s in ultimas)
          if (s.esfuerzo != null) s.esfuerzo!,
      ];
      if (esfuerzos.isEmpty) return true;
      return esfuerzos.any((e) => e >= reglas.esfuerzoMinimoPiernas);
  }
}

/// Qué se le presenta a la persona ante el choque con la ruta (4.6). Se dan
/// todas; la recomendación (1) va primero y la (4) al final. **La versión
/// corta de C no está aquí a propósito:** no quita el aviso porque la regla
/// mide de inicio a inicio.
enum OpcionPiernas {
  /// 1. A el lunes, C el martes, B el miércoles (cambio del plan, por la
  /// persona; solo si C no está ya el martes).
  moverCAlMartes,

  /// 3. Declarar la ruta como carga ligera de piernas (`carga_piernas`).
  declararRutaLigera,

  /// 2. Dejarlo así: la persona decide.
  dejarloAsi,

  /// 4. Mover la ruta (no se recomienda).
  moverLaRuta,
}

/// Un aviso de la ruta contra una sesión de piernas, con sus opciones.
class AvisoPiernasBici {
  const AvisoPiernasBici({
    required this.aviso,
    required this.sesionC,
    required this.opciones,
  });

  /// El aviso del gimnasio tal cual (no se modifica).
  final AvisoSemana aviso;
  final SesionProgramada sesionC;
  final List<OpcionPiernas> opciones;

  /// Inicio a inicio (ej.: C el jueves 19:15 → 2205 = 36 h 45 min).
  int get intervaloMin => aviso.intervaloMin;

  /// Cuánto falta para las 47 h (ej.: 615).
  int get faltanMin => aviso.faltanMin;
}

class ResultadoPiernas {
  const ResultadoPiernas({
    required this.biciCuenta,
    required this.avisos,
    required this.avisosBici,
  });

  /// ¿La ruta se entregó a la regla del gimnasio?
  final bool biciCuenta;

  /// Los avisos de `revisarSemana`, sin tocar.
  final List<AvisoSemana> avisos;

  /// Los que tienen la ruta en uno de sus extremos, con las opciones de 4.6.
  final List<AvisoPiernasBici> avisosBici;
}

/// Revisa la semana con la ruta del sábado según [carga] (CA-B-04).
///
/// Si la ruta cuenta, llama a `revisarSemana` con **todas** las sesiones; si
/// no, con todas menos las de tipo `bici` (la ruta solo comparte grupos con
/// C, así que no cambia ningún otro aviso). Nunca bloquea.
ResultadoPiernas revisarSemanaConBici({
  required List<SesionProgramada> sesiones,
  required Catalogo catalogo,
  CargaPiernas? carga,
  List<Salida> salidas = const [],
  ReglasGimnasio reglasGimnasio = const ReglasGimnasio(),
  ReglasBicicleta reglas = const ReglasBicicleta(),
}) {
  final cuenta = biciCuentaComoPiernas(
    carga: carga,
    salidas: salidas,
    reglas: reglas,
  );
  final entrada = cuenta
      ? sesiones
      : [
          for (final s in sesiones)
            if (s.tipo != TipoDia.bici) s,
        ];
  final avisos = revisarSemana(entrada, catalogo, reglas: reglasGimnasio);
  final conBici = <AvisoPiernasBici>[];
  for (final a in avisos) {
    final esBici = a.a.tipo == TipoDia.bici || a.b.tipo == TipoDia.bici;
    final c = a.a.tipo == TipoDia.c
        ? a.a
        : (a.b.tipo == TipoDia.c ? a.b : null);
    if (!esBici || c == null) continue;
    conBici.add(
      AvisoPiernasBici(
        aviso: a,
        sesionC: c,
        opciones: [
          if (c.inicio.weekday != DateTime.tuesday)
            OpcionPiernas.moverCAlMartes,
          OpcionPiernas.declararRutaLigera,
          OpcionPiernas.dejarloAsi,
          OpcionPiernas.moverLaRuta,
        ],
      ),
    );
  }
  return ResultadoPiernas(
    biciCuenta: cuenta,
    avisos: avisos,
    avisosBici: conBici,
  );
}

/// La última sesión de piernas hasta [hasta], sea el día que sea (CB-3,
/// CA-B-10): C o la ruta (si cuenta). El cansancio acumulado se aplica a esa
/// sesión y no a «la del viernes».
SesionProgramada? ultimaSesionDePiernas({
  required List<SesionProgramada> sesiones,
  required Catalogo catalogo,
  required DateTime hasta,
  bool biciCuenta = true,
}) {
  SesionProgramada? mejor;
  for (final s in sesiones) {
    if (s.inicio.isAfter(hasta)) continue;
    if (s.tipo == TipoDia.bici && !biciCuenta) continue;
    final g = gruposDeTipo(catalogo, s.tipo);
    if (!g.contains(Grupos.cuadriceps) && !g.contains(Grupos.gluteo)) continue;
    if (mejor == null || s.inicio.isAfter(mejor.inicio)) mejor = s;
  }
  return mejor;
}
