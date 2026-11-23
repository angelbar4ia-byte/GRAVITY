/// Ciclo, descarga, reentrada y modo foco (5.9). Todo se calcula: no hay
/// contadores guardados (R4).
library;

import '../fecha.dart';
import '../rachas.dart' show Pausa;
import 'registro.dart';
import 'reglas.dart';

/// Posición en el ciclo de carga y descarga.
class SemanaCiclo {
  const SemanaCiclo(this.numero, {required this.descarga});

  /// 1 a `cicloSemanas` (o creciente si no hay descarga programada).
  final int numero;
  final bool descarga;
}

/// Semana del ciclo = `(lunesDe(hoy) − inicio) ÷ 7 + 1`, módulo
/// `cicloSemanas` (4.4). Las semanas en modo foco ([lunesEnFoco]) no cuentan:
/// el contador se detiene y retoma donde estaba (PG-11). `null` si el plan
/// aún no empieza.
SemanaCiclo? semanaDelCiclo({
  required DateTime hoy,
  required DateTime? inicioCiclo,
  required int cicloSemanas,
  List<DateTime> lunesEnFoco = const [],
}) {
  if (inicioCiclo == null) return null;
  final inicio = lunesDe(inicioCiclo);
  final lunes = lunesDe(hoy);
  if (lunes.isBefore(inicio)) return null;
  var transcurridas = diasEntre(inicio, lunes) ~/ 7;
  final foco = {for (final f in lunesEnFoco) lunesDe(f)};
  for (final f in foco) {
    if (!f.isBefore(inicio) && f.isBefore(lunes)) transcurridas--;
  }
  if (cicloSemanas <= 0) {
    return SemanaCiclo(transcurridas + 1, descarga: false);
  }
  final n = transcurridas % cicloSemanas + 1;
  return SemanaCiclo(n, descarga: n == cicloSemanas);
}

/// Cómo se arma la semana (5.9 y 5.11).
class ParametrosSemana {
  const ParametrosSemana({
    required this.tipo,
    this.series,
    this.incrementos = true,
    this.bajarUnPaso = false,
    this.repiteCargas = false,
    this.cargasDePrueba = false,
    this.repsAlMinimo = false,
    this.adaptacion = false,
    this.ciclo,
    this.versionSugerida,
  });

  final TipoSemana tipo;

  /// Series fijas para toda la semana (2 en descarga, reentrada y adaptación).
  final int? series;

  /// ¿Puede subir carga, repeticiones o series? (`false` en foco, descarga,
  /// reentrada y adaptación).
  final bool incrementos;

  /// Una placa menos (o la banda anterior).
  final bool bajarUnPaso;

  /// Se repiten las cargas de la última vez.
  final bool repiteCargas;

  /// Sin historial útil: la primera serie fija el punto de partida.
  final bool cargasDePrueba;
  final bool repsAlMinimo;
  final bool adaptacion;
  final SemanaCiclo? ciclo;

  /// En modo foco se sugiere la versión corta, sin culpa.
  final VersionSesion? versionSugerida;
}

/// Días sin sesión de fuerza desde la última terminada, sin contar los días
/// cubiertos por una pausa declarada (5.9). `null` si nunca entrenó.
int? diasSinSesionFuerza({
  required List<SesionRegistrada> historial,
  required DateTime hoy,
  List<Pausa> pausas = const [],
  String objetivoId = 'entrenamiento',
}) {
  DateTime? ultima;
  for (final s in historial) {
    if (!s.esDeFuerza || !s.terminada) continue;
    final f = soloDia(s.fecha);
    if (ultima == null || f.isAfter(ultima)) ultima = f;
  }
  if (ultima == null) return null;
  final h = soloDia(hoy);
  var dias = 0;
  for (var d = sumarDias(ultima, 1); !d.isAfter(h); d = sumarDias(d, 1)) {
    if (!pausas.any((p) => p.cubre(d, objetivoId))) dias++;
  }
  return dias;
}

/// Calcula el tipo de semana y sus parámetros. [modoFoco] es solo un
/// booleano: el generador nunca sabe qué hábito lo causó (PG-11).
ParametrosSemana calcularSemana({
  required DateTime hoy,
  required PerfilGimnasio perfil,
  required bool modoFoco,
  required int? diasSinSesion,
  List<DateTime> lunesEnFoco = const [],
  ReglasGimnasio reglas = const ReglasGimnasio(),
}) {
  final ciclo = semanaDelCiclo(
    hoy: hoy,
    inicioCiclo: perfil.inicioCiclo,
    cicloSemanas: perfil.cicloSemanas,
    lunesEnFoco: lunesEnFoco,
  );
  if (modoFoco) {
    return ParametrosSemana(
      tipo: TipoSemana.foco,
      incrementos: false,
      repiteCargas: true,
      ciclo: ciclo,
      versionSugerida: VersionSesion.corta,
    );
  }
  if (diasSinSesion == null) {
    return ParametrosSemana(
      tipo: TipoSemana.carga,
      incrementos: false,
      cargasDePrueba: true,
      ciclo: ciclo,
    );
  }
  if (diasSinSesion >= reglas.reentradaDesdeCeroDias) {
    return ParametrosSemana(
      tipo: TipoSemana.reentrada,
      incrementos: false,
      cargasDePrueba: true,
      ciclo: ciclo,
    );
  }
  if (diasSinSesion >= reglas.reentradaDias) {
    return ParametrosSemana(
      tipo: TipoSemana.reentrada,
      series: reglas.seriesDescarga,
      incrementos: false,
      bajarUnPaso: true,
      ciclo: ciclo,
    );
  }
  if (diasSinSesion >= reglas.reentradaRepiteDias) {
    return ParametrosSemana(
      tipo: TipoSemana.carga,
      incrementos: false,
      repiteCargas: true,
      ciclo: ciclo,
    );
  }
  if (ciclo != null && ciclo.descarga) {
    return ParametrosSemana(
      tipo: TipoSemana.descarga,
      series: reglas.seriesDescarga,
      incrementos: false,
      bajarUnPaso: true,
      repsAlMinimo: true,
      ciclo: ciclo,
    );
  }
  if (esSemanaDeAdaptacion(hoy: hoy, perfil: perfil, reglas: reglas)) {
    return ParametrosSemana(
      tipo: TipoSemana.carga,
      series: reglas.seriesAdaptacion,
      incrementos: false,
      adaptacion: true,
      ciclo: ciclo,
    );
  }
  return ParametrosSemana(tipo: TipoSemana.carga, ciclo: ciclo);
}

/// Principiante: las 2 primeras semanas del plan son de adaptación (5.11).
bool esSemanaDeAdaptacion({
  required DateTime hoy,
  required PerfilGimnasio perfil,
  ReglasGimnasio reglas = const ReglasGimnasio(),
}) {
  final inicio = perfil.inicioCiclo;
  if (perfil.nivel != NivelGimnasio.principiante || inicio == null) {
    return false;
  }
  final lunes = lunesDe(hoy);
  final i = lunesDe(inicio);
  if (lunes.isBefore(i)) return false;
  return diasEntre(i, lunes) ~/ 7 < reglas.semanasAdaptacion;
}

/// ¿Conviene **sugerir** una descarga ahora? Dos sesiones de fuerza seguidas
/// con esfuerzo 5 (5.9). Solo sugiere: nunca la impone.
bool sugerirDescarga(
  List<SesionRegistrada> historial, {
  ReglasGimnasio reglas = const ReglasGimnasio(),
}) {
  final f = [
    for (final s in historial)
      if (s.esDeFuerza && s.terminada) s,
  ]..sort((a, b) => b.fecha.compareTo(a.fecha));
  final n = reglas.descargaSugeridaSesiones;
  if (f.length < n) return false;
  return f.take(n).every((s) => s.esfuerzo == reglas.esfuerzoMaximo);
}
