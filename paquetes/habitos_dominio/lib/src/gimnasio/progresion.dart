/// Progresión con pila limitada (5.8, PG-08): doble progresión y escalera
/// sin carga. Todo se **deriva** del historial: no hay contadores guardados.
library;

import 'ciclos.dart';
import 'inventario.dart';
import 'registro.dart';
import 'reglas.dart';
import 'tipos.dart';

/// Por qué la propuesta es la que es (para explicarlo en la sesión).
enum MotivoProgresion {
  primeraVez,
  pruebas,
  mantiene,
  repiteCargas,
  bajaUnPaso,
  subeCarga,
  escaleraRepeticiones,
  escaleraSeries,
  escaleraTempo,
  escaleraDescanso,
  escaleraVariante,
  escaleraBanda,
  escaleraAgotada,
}

/// Los seis peldaños de la escalera sin carga, en orden (5.8).
enum Peldano { repeticiones, series, tempo, descanso, variante, banda }

// ---------------------------------------------------------------------------
// Bandas (5.4)
// ---------------------------------------------------------------------------

/// Un paso de carga con bandas: una banda o dos iguales juntas.
class PasoBanda {
  const PasoBanda(this.bandaId, {this.doble = false});
  final String bandaId;
  final bool doble;

  @override
  bool operator ==(Object o) =>
      o is PasoBanda && o.bandaId == bandaId && o.doble == doble;

  @override
  int get hashCode => Object.hash(bandaId, doble);
}

/// Secuencia de la más ligera a la más fuerte; entre una banda y la
/// siguiente, dos iguales juntas (si hay cantidad ≥ 2).
List<PasoBanda> secuenciaBandas(List<BandaInventario> bandas) {
  final a = [
    for (final b in bandas)
      if (b.cuenta) b
  ]..sort((x, y) => x.orden.compareTo(y.orden));
  return [
    for (final b in a) ...[
      PasoBanda(b.id),
      if (b.cantidad >= 2) PasoBanda(b.id, doble: true),
    ]
  ];
}

PasoBanda? siguientePasoBanda(PasoBanda actual, List<BandaInventario> bandas) {
  final s = secuenciaBandas(bandas);
  final i = s.indexOf(actual);
  return i >= 0 && i + 1 < s.length ? s[i + 1] : null;
}

PasoBanda? anteriorPasoBanda(PasoBanda actual, List<BandaInventario> bandas) {
  final s = secuenciaBandas(bandas);
  final i = s.indexOf(actual);
  return i > 0 ? s[i - 1] : null;
}

// ---------------------------------------------------------------------------
// Escalera sin carga
// ---------------------------------------------------------------------------

/// Hasta dónde llegó la escalera en una variante. Se obtiene repitiendo el
/// historial ([posicionEscalera]); no se guarda.
class PosicionEscalera {
  const PosicionEscalera({
    this.techoAmpliado = false,
    this.serieExtra = false,
    this.tempoLento = false,
    this.descansoNiveles = 0,
    this.varianteDificil = false,
  });

  final bool techoAmpliado;
  final bool serieExtra;
  final bool tempoLento;
  final int descansoNiveles;
  final bool varianteDificil;

  PosicionEscalera copiar({
    bool? techoAmpliado,
    bool? serieExtra,
    bool? tempoLento,
    int? descansoNiveles,
    bool? varianteDificil,
  }) =>
      PosicionEscalera(
        techoAmpliado: techoAmpliado ?? this.techoAmpliado,
        serieExtra: serieExtra ?? this.serieExtra,
        tempoLento: tempoLento ?? this.tempoLento,
        descansoNiveles: descansoNiveles ?? this.descansoNiveles,
        varianteDificil: varianteDificil ?? this.varianteDificil,
      );
}

/// Lo que la escalera necesita saber de la variante y la sesión.
class ContextoEscalera {
  const ContextoEscalera({
    required this.seriesBase,
    required this.larga,
    required this.descansoBaseS,
    required this.hayMasDificil,
    required this.esBanda,
    required this.haySiguienteBanda,
    required this.reglas,
  });

  final int seriesBase;
  final bool larga;
  final int descansoBaseS;
  final bool hayMasDificil;
  final bool esBanda;
  final bool haySiguienteBanda;
  final ReglasGimnasio reglas;

  int get topeSeries => larga ? reglas.seriesTopeLarga : reglas.seriesTopeOtras;
}

class AvanceEscalera {
  const AvanceEscalera(this.posicion, this.peldano);
  final PosicionEscalera posicion;
  final Peldano peldano;
}

/// Un peldaño se agota antes de pasar al siguiente: ninguno se salta.
/// `null` = la escalera está agotada.
AvanceEscalera? avanzarEscalera(PosicionEscalera p, ContextoEscalera c) {
  if (!p.techoAmpliado) {
    return AvanceEscalera(p.copiar(techoAmpliado: true), Peldano.repeticiones);
  }
  if (!p.serieExtra && c.seriesBase < c.topeSeries) {
    return AvanceEscalera(p.copiar(serieExtra: true), Peldano.series);
  }
  if (!p.tempoLento) {
    return AvanceEscalera(p.copiar(tempoLento: true), Peldano.tempo);
  }
  final siguiente = c.descansoBaseS - c.reglas.pasoDescansoS * (p.descansoNiveles + 1);
  if (siguiente >= c.reglas.descansoMinimoS) {
    return AvanceEscalera(
        p.copiar(descansoNiveles: p.descansoNiveles + 1), Peldano.descanso);
  }
  if (!p.varianteDificil && c.hayMasDificil) {
    return AvanceEscalera(p.copiar(varianteDificil: true), Peldano.variante);
  }
  if (c.esBanda && c.haySiguienteBanda) {
    return AvanceEscalera(p, Peldano.banda);
  }
  return null;
}

// ---------------------------------------------------------------------------
// Propuesta
// ---------------------------------------------------------------------------

class PropuestaProgresion {
  const PropuestaProgresion({
    required this.varianteId,
    required this.rangoMin,
    required this.rangoMax,
    required this.objetivo,
    required this.porTiempo,
    required this.series,
    required this.descansoS,
    required this.motivo,
    this.tempoBajadaS = 2,
    this.cargaPasos,
    this.bandaId,
    this.bandaDoble = false,
    this.topeDePila = false,
    this.cambiaAVariante,
  });

  final String varianteId;

  /// Rango efectivo (repeticiones, o segundos si [porTiempo]).
  final int rangoMin;
  final int rangoMax;
  final int objetivo;
  final bool porTiempo;
  final int series;
  final int descansoS;

  /// Segundos de bajada del tempo (2, o 3 con tempo lento: «3-1-1»).
  final int tempoBajadaS;
  final MotivoProgresion motivo;
  final int? cargaPasos;
  final String? bandaId;
  final bool bandaDoble;
  final bool topeDePila;

  /// Si la escalera llegó al peldaño de la variante más difícil.
  final String? cambiaAVariante;

  String get tempo => '$tempoBajadaS-1-1';
}

/// Series de la variante en una sesión, en orden de número.
List<SerieRegistrada> _seriesDe(SesionRegistrada s, String varianteId) => [
      for (final x in s.series)
        if (x.varianteId == varianteId) x
    ]..sort((a, b) => a.n.compareTo(b.n));

PlanEjercicioGuardado? _planDe(SesionRegistrada s, String varianteId) {
  for (final p in s.plan) {
    if (p.varianteId == varianteId) return p;
  }
  return null;
}

/// Última carga hecha (la de la última serie con carga).
int? _cargaDe(List<SerieRegistrada> series) {
  for (var i = series.length - 1; i >= 0; i--) {
    if (series[i].cargaPasos != null) return series[i].cargaPasos;
  }
  return null;
}

PasoBanda? _bandaDe(List<SerieRegistrada> series) {
  for (var i = series.length - 1; i >= 0; i--) {
    if (series[i].bandaId != null) {
      return PasoBanda(series[i].bandaId!, doble: series[i].bandaDoble);
    }
  }
  return null;
}

/// ¿Cumplió la sesión el objetivo? Todas las series planeadas llegaron al
/// máximo del rango y el esfuerzo de la última serie fue ≤ 4 (sin registro se
/// asume 3).
bool cumplioObjetivo({
  required List<SerieRegistrada> series,
  required int seriesEsperadas,
  required int techo,
  required bool porTiempo,
  required bool porLado,
  required ReglasGimnasio reglas,
}) {
  if (series.isEmpty) return false;
  final buenas = series.where((s) => porTiempo
      ? (s.segundos ?? 0) >= techo
      : (s.reps ?? 0) >= techo);
  final necesarias = seriesEsperadas * (porLado ? 2 : 1);
  if (buenas.length < necesarias) return false;
  final esfuerzo = series.last.esfuerzo ?? reglas.esfuerzoPorOmision;
  return esfuerzo <= reglas.esfuerzoMaximoParaSubir;
}

class _Repeticion {
  _Repeticion(this.pos, this.ultimoAvance, this.ultimoCumplio, this.ultimoTope);
  PosicionEscalera pos;
  AvanceEscalera? ultimoAvance;
  bool ultimoCumplio;
  bool ultimoTope;
}

/// Hasta dónde llegó la escalera: se repite el historial de la variante.
_Repeticion _repetir({
  required List<SesionRegistrada> refs,
  required Variante variante,
  required Ejercicio ejercicio,
  required Slot slot,
  required int rangoMax,
  required bool porTiempo,
  required int seriesBase,
  required int descansoBaseS,
  required bool larga,
  required Inventario inv,
  required PerfilGimnasio perfil,
  required ReglasGimnasio reglas,
  required bool enUltimaPlaca,
  required bool haySiguienteBanda,
  required bool hayMasDificil,
}) {
  final r = _Repeticion(const PosicionEscalera(), null, false, false);
  for (var i = 0; i < refs.length; i++) {
    final s = refs[i];
    final esUltima = i == refs.length - 1;
    r.ultimoAvance = null;
    r.ultimoCumplio = false;
    r.ultimoTope = false;
    // Solo las sesiones de carga normal cuentan para avanzar (no foco,
    // reentrada ni adaptación).
    if (s.semanaTipo != TipoSemana.carga ||
        esSemanaDeAdaptacion(hoy: s.fecha, perfil: perfil, reglas: reglas)) {
      continue;
    }
    final series = _seriesDe(s, variante.id);
    final plan = _planDe(s, variante.id);
    final ampliado = r.pos.techoAmpliado
        ? (porTiempo ? reglas.techoEscaleraSegundos : reglas.techoEscaleraReps)
        : 0;
    final techo = (porTiempo ? null : plan?.repsMax) ?? rangoMax + ampliado;
    final esperadas =
        plan?.series ?? seriesBase + (r.pos.serieExtra ? 1 : 0);
    final cumple = cumplioObjetivo(
      series: series,
      seriesEsperadas: esperadas,
      techo: techo,
      porTiempo: porTiempo,
      porLado: ejercicio.porLado,
      reglas: reglas,
    );
    r.ultimoCumplio = cumple;
    if (!cumple) continue;
    var aplica = true;
    if (variante.carga == TipoCarga.pila) {
      final c = _cargaDe(series);
      final tope = c != null &&
          (inv.enTopeDePila(c) || (enUltimaPlaca && esUltima));
      r.ultimoTope = tope;
      aplica = tope;
    }
    if (!aplica) continue;
    final a = avanzarEscalera(
      r.pos,
      ContextoEscalera(
        seriesBase: seriesBase,
        larga: larga,
        descansoBaseS: descansoBaseS,
        hayMasDificil: hayMasDificil,
        esBanda: variante.carga == TipoCarga.banda,
        haySiguienteBanda: haySiguienteBanda,
        reglas: reglas,
      ),
    );
    if (a != null) {
      r.pos = a.posicion;
      r.ultimoAvance = a;
    }
  }
  return r;
}

/// Calcula qué proponer para un ejercicio (CA-G-16 y CA-G-17).
///
/// [rangoMin] y [rangoMax] son el rango base del slot (ya ajustado por el
/// objetivo); [seriesBase] y [descansoBaseS] los de la versión.
PropuestaProgresion proponerProgresion({
  required Catalogo catalogo,
  required Variante variante,
  required Ejercicio ejercicio,
  required Slot slot,
  required int rangoMin,
  required int rangoMax,
  required int seriesBase,
  required int descansoBaseS,
  required bool larga,
  required String plantillaId,
  required List<SesionRegistrada> historial,
  required Inventario inventario,
  required ParametrosSemana semana,
  required PerfilGimnasio perfil,
  ReglasGimnasio reglas = const ReglasGimnasio(),
  bool enUltimaPlaca = false,
}) {
  final porTiempo = slot.esDeTiempo;
  final refs = [
    for (final s in historial)
      if (s.plantilla == plantillaId &&
          s.terminada &&
          s.semanaTipo != TipoSemana.descarga &&
          _seriesDe(s, variante.id).isNotEmpty)
        s
  ]..sort((a, b) => a.fecha.compareTo(b.fecha));

  int series0() => semana.series ?? seriesBase;

  PropuestaProgresion nueva(
    MotivoProgresion motivo, {
    int? objetivo,
    int? carga,
    String? banda,
    bool doble = false,
    int? series,
    int? tempo,
    int? descanso,
    int? max,
    bool tope = false,
    String? cambia,
  }) =>
      PropuestaProgresion(
        varianteId: variante.id,
        rangoMin: rangoMin,
        rangoMax: max ?? rangoMax,
        objetivo: objetivo ?? rangoMin,
        porTiempo: porTiempo,
        series: series ?? series0(),
        descansoS: descanso ?? descansoBaseS,
        tempoBajadaS: tempo ?? 2,
        motivo: motivo,
        cargaPasos: carga,
        bandaId: banda,
        bandaDoble: doble,
        topeDePila: tope,
        cambiaAVariante: cambia,
      );

  // Primera vez, o cargas de prueba tras 8 semanas o más (5.12, 5.9).
  if (refs.isEmpty || semana.cargasDePrueba) {
    return nueva(refs.isEmpty
        ? MotivoProgresion.primeraVez
        : MotivoProgresion.pruebas);
  }

  final ultima = refs.last;
  final seriesUlt = _seriesDe(ultima, variante.id);
  final cargaUlt = _cargaDe(seriesUlt);
  final bandaUlt = _bandaDe(seriesUlt);
  final esPila = variante.carga == TipoCarga.pila;
  final esBanda = variante.carga == TipoCarga.banda;
  final hayMasDificil = variante.masDificil != null &&
      catalogo.variante(variante.masDificil!) != null &&
      inventario.varianteDisponible(catalogo.variante(variante.masDificil!)!, catalogo);
  final haySiguienteBanda = bandaUlt != null &&
      siguientePasoBanda(bandaUlt, inventario.bandas) != null;

  final rep = _repetir(
    refs: refs,
    variante: variante,
    ejercicio: ejercicio,
    slot: slot,
    rangoMax: rangoMax,
    porTiempo: porTiempo,
    seriesBase: seriesBase,
    descansoBaseS: descansoBaseS,
    larga: larga,
    inv: inventario,
    perfil: perfil,
    reglas: reglas,
    enUltimaPlaca: enUltimaPlaca,
    haySiguienteBanda: haySiguienteBanda,
    hayMasDificil: hayMasDificil,
  );

  // Valores efectivos de la escalera.
  final pos = rep.pos;
  final techoExtra = pos.techoAmpliado
      ? (porTiempo ? reglas.techoEscaleraSegundos : reglas.techoEscaleraReps)
      : 0;
  final maxEf = rangoMax + techoExtra;
  final seriesEf = pos.serieExtra
      ? (seriesBase + 1 > (larga ? reglas.seriesTopeLarga : reglas.seriesTopeOtras)
          ? seriesBase
          : seriesBase + 1)
      : seriesBase;
  final tempoEf = pos.tempoLento ? 3 : 2;
  final descansoEf = descansoBaseS - reglas.pasoDescansoS * pos.descansoNiveles;

  PropuestaProgresion conPos(
    MotivoProgresion m, {
    int? objetivo,
    int? carga,
    PasoBanda? banda,
    bool tope = false,
    String? cambia,
    bool bajar = false,
  }) =>
      PropuestaProgresion(
        varianteId: variante.id,
        rangoMin: rangoMin,
        rangoMax: maxEf,
        objetivo: objetivo ?? maxEf,
        porTiempo: porTiempo,
        series: semana.series ?? seriesEf,
        descansoS: descansoEf,
        tempoBajadaS: tempoEf,
        motivo: m,
        cargaPasos: carga,
        bandaId: banda?.bandaId,
        bandaDoble: banda?.doble ?? false,
        topeDePila: tope,
        cambiaAVariante: cambia,
      );

  PasoBanda? bandaActual = bandaUlt;
  final topeActual = esPila && cargaUlt != null &&
      (inventario.enTopeDePila(cargaUlt) || enUltimaPlaca);

  // Semana de descarga o de reentrada: una placa (o banda) menos, sin subir.
  if (semana.bajarUnPaso) {
    int? c;
    if (esPila && cargaUlt != null) c = cargaUlt > 1 ? cargaUlt - 1 : cargaUlt;
    PasoBanda? b = bandaActual;
    if (esBanda && b != null) b = anteriorPasoBanda(b, inventario.bandas) ?? b;
    return conPos(MotivoProgresion.bajaUnPaso,
        objetivo: rangoMin, carga: c, banda: b);
  }

  // Foco, adaptación o 7 a 13 días sin sesión: se repiten las cargas.
  if (!semana.incrementos) {
    return conPos(
      semana.repiteCargas
          ? MotivoProgresion.repiteCargas
          : MotivoProgresion.mantiene,
      carga: cargaUlt,
      banda: bandaActual,
      tope: topeActual,
    );
  }

  // Semana normal.
  final avance = rep.ultimoAvance;
  if (avance != null) {
    final (m, cambia, banda) = switch (avance.peldano) {
      Peldano.repeticiones => (MotivoProgresion.escaleraRepeticiones, null, bandaActual),
      Peldano.series => (MotivoProgresion.escaleraSeries, null, bandaActual),
      Peldano.tempo => (MotivoProgresion.escaleraTempo, null, bandaActual),
      Peldano.descanso => (MotivoProgresion.escaleraDescanso, null, bandaActual),
      Peldano.variante => (
          MotivoProgresion.escaleraVariante,
          variante.masDificil,
          bandaActual
        ),
      Peldano.banda => (
          MotivoProgresion.escaleraBanda,
          null,
          bandaActual == null
              ? null
              : siguientePasoBanda(bandaActual, inventario.bandas)
        ),
    };
    return conPos(m,
        objetivo: rangoMin,
        carga: cargaUlt,
        banda: banda,
        tope: topeActual,
        cambia: cambia);
  }

  if (rep.ultimoCumplio) {
    if (esPila && cargaUlt != null && !topeActual) {
      final sube = cargaUlt + 1;
      if (inventario.cargaValida(sube)) {
        return conPos(MotivoProgresion.subeCarga,
            objetivo: rangoMin, carga: sube);
      }
    }
    // Cumplió y no hay a dónde subir: escalera agotada (se mantiene).
    return conPos(MotivoProgresion.escaleraAgotada,
        carga: cargaUlt, banda: bandaActual, tope: topeActual);
  }

  // No cumplió: se mantiene y el objetivo es completar el máximo.
  return conPos(MotivoProgresion.mantiene,
      carga: cargaUlt, banda: bandaActual, tope: topeActual);
}
