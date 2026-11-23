/// Generador de sesiones sin IA (sección 5): función pura y determinista.
/// Mismas entradas, mismas salidas; sin azar, sin reloj, sin red.
library;

import 'dart:math';

import '../fecha.dart';
import '../rachas.dart' show Pausa;
import 'ciclos.dart';
import 'duracion.dart';
import 'inventario.dart';
import 'molestias.dart';
import 'progresion.dart';
import 'registro.dart';
import 'reglas.dart';
import 'sesion_planificada.dart';
import 'tipos.dart';

/// Descanso base de la versión, ajustado por objetivo (5.11) salvo que la
/// persona haya fijado el suyo en Ajustes (de 30 a 120 s).
int descansoBase(ParametrosVersion p, PerfilGimnasio perfil, ReglasGimnasio r) {
  final propio = perfil.descansoS;
  if (propio != null) {
    return propio.clamp(r.descansoPisoS, r.descansoTopeS);
  }
  return switch (perfil.objetivo) {
    // +15 s con tope de 75 s (nunca menos que el de la versión).
    ObjetivoGimnasio.fuerza => max(
      p.descansoS,
      min(p.descansoS + 15, r.descansoMaximoS),
    ),
    // −15 s con piso de 45 s (nunca más que el de la versión).
    ObjetivoGimnasio.perdidaGrasa => min(
      p.descansoS,
      max(p.descansoS - 15, r.descansoMinimoS),
    ),
    _ => p.descansoS,
  };
}

/// Rango de repeticiones del slot según el objetivo (5.11): `fuerza` baja
/// mínimo y máximo en 2 (10–12 pasa a 8–10).
(int, int) _rangoReps(Slot s, Ejercicio e, PerfilGimnasio perfil) {
  var min = s.repsMin ?? e.repsMin ?? 8;
  var max = s.repsMax ?? e.repsMax ?? 12;
  if (perfil.objetivo == ObjetivoGimnasio.fuerza && !s.esDeTiempo) {
    min = (min - 2).clamp(1, min);
    max = (max - 2).clamp(min + 1, max);
  }
  return (min, max);
}

MotivoAlternativa _motivoAlternativa(
  Variante alt,
  Variante actual,
  int intensidad,
) {
  if (intensidad > 0) return MotivoAlternativa.conPrecaucion;
  if (alt.nivel < actual.nivel) return MotivoAlternativa.masFacil;
  if (alt.nivel > actual.nivel) return MotivoAlternativa.masDificil;
  return alt.carga == TipoCarga.pila
      ? MotivoAlternativa.masDificil
      : MotivoAlternativa.sinAparato;
}

/// Genera la sesión concreta de [plantillaId] (5.1).
///
/// - Filtra por inventario (5.2) y ocupa cada slot con la primera variante
///   disponible: el Marcy gana a las bandas (5.4); el equipo `futuro` no
///   cuenta nunca (CA-G-09).
/// - Las [molestias] son **locales**: se aplican aquí, en este equipo, y no
///   quedan en nada que se guarde (4.3).
/// - [modoFoco] es solo un booleano: no se sabe qué hábito lo causó (PG-11).
/// - [ultimaPlaca] son las variantes en que la persona marcó «ya estoy en la
///   última placa» (5.8).
SesionPlanificada generarSesion({
  required Catalogo catalogo,
  required String plantillaId,
  required VersionSesion version,
  required Inventario inventario,
  required DateTime hoy,
  List<Molestia> molestias = const [],
  List<SesionRegistrada> historial = const [],
  bool modoFoco = false,
  PerfilGimnasio perfil = const PerfilGimnasio(),
  ReglasGimnasio reglas = const ReglasGimnasio(),
  List<Pausa> pausas = const [],
  List<DateTime> lunesEnFoco = const [],
  Set<String> ultimaPlaca = const {},
  ModeloTiempo? modelo,
}) {
  final plantilla = catalogo.plantilla(plantillaId);
  if (plantilla == null) {
    throw ArgumentError.value(
      plantillaId,
      'plantillaId',
      'plantilla de fuerza inexistente',
    );
  }
  final params = reglas.de(version);
  final diasSin = diasSinSesionFuerza(
    historial: historial,
    hoy: hoy,
    pausas: pausas,
  );
  final semana = calcularSemana(
    hoy: hoy,
    perfil: perfil,
    modoFoco: modoFoco,
    diasSinSesion: diasSin,
    lunesEnFoco: lunesEnFoco,
    reglas: reglas,
  );
  final descanso = descansoBase(params, perfil, reglas);

  final avisos = <AvisoGimnasio>[];
  final omitidos = <SlotOmitido>[];
  final ejercicios = <EjercicioPlanificado>[];
  final usadas = <String>{};
  var intensidadMaxima = 0;
  var hayBorrador = plantilla.revision != RevisionContenido.revisado;
  final caminadora = inventario.disponible('caminadora', catalogo);
  // Se evalúan primero las variantes del slot contra las molestias.
  for (final slot in plantilla.slots) {
    if (slot.extra && !params.incluyeExtras) continue;
    if (slot.omitirEnCorta && params.omiteOmitibles && !slot.esencial) continue;

    final disponibles = <Variante>[
      for (final id in slot.candidatas)
        if (!usadas.contains(id) &&
            catalogo.variante(id) != null &&
            inventario.varianteDisponible(catalogo.variante(id)!, catalogo))
          catalogo.variante(id)!,
    ];
    int inten(Variante v) =>
        intensidadQueAfecta(molestias, catalogo.zonasDe(v.id));

    if (disponibles.isEmpty) {
      if (!slot.extra) {
        omitidos.add(SlotOmitido(slot.id, RazonOmision.sinEquipo));
        avisos.add(
          AvisoGimnasio(
            CodigoAviso.slotOmitido,
            slotId: slot.id,
            razon: RazonOmision.sinEquipo,
          ),
        );
      }
      continue;
    }

    final primera = disponibles.first;
    final iPrimera = inten(primera);
    if (iPrimera > intensidadMaxima) intensidadMaxima = iPrimera;
    Variante? elegida;
    var precaucion = false;
    if (precaucionDe(iPrimera) != PrecaucionVariante.noSeOcupa) {
      elegida = primera;
      precaucion = iPrimera == IntensidadMolestia.leve;
    } else {
      for (final v in disponibles) {
        if (inten(v) == 0) {
          elegida = v;
          break;
        }
      }
    }
    if (elegida == null) {
      if (!slot.extra) {
        omitidos.add(
          SlotOmitido(
            slot.id,
            RazonOmision.precaucion,
            opcionesConPrecaucion: [for (final v in disponibles) v.id],
          ),
        );
        avisos.add(
          AvisoGimnasio(
            CodigoAviso.slotOmitido,
            slotId: slot.id,
            razon: RazonOmision.precaucion,
          ),
        );
      }
      continue;
    }

    var variante = elegida;
    var ejercicio = catalogo.ejercicioDeVariante(variante.id)!;
    final (rMin, rMax) = _rangoReps(slot, ejercicio, perfil);
    final min = slot.esDeTiempo ? slot.segundosMin! : rMin;
    final max = slot.esDeTiempo ? slot.segundosMax! : rMax;
    final seriesBase = slot.extra
        ? slot.series
        : (params.series ?? slot.series);

    PropuestaProgresion calcular(Variante v, Ejercicio e) => proponerProgresion(
      catalogo: catalogo,
      variante: v,
      ejercicio: e,
      slot: slot,
      rangoMin: min,
      rangoMax: max,
      seriesBase: seriesBase,
      descansoBaseS: descanso,
      larga: version == VersionSesion.larga,
      plantillaId: plantillaId,
      historial: historial,
      inventario: inventario,
      semana: semana,
      perfil: perfil,
      reglas: reglas,
      enUltimaPlaca: ultimaPlaca.contains(v.id),
    );

    var p = calcular(variante, ejercicio);
    // Peldaño de la variante más difícil: se cambia si está disponible, no se
    // usa ya y no carga una zona con molestia (la escalera nunca empuja a una
    // zona marcada).
    final dificil = p.cambiaAVariante == null
        ? null
        : catalogo.variante(p.cambiaAVariante!);
    if (dificil != null &&
        !usadas.contains(dificil.id) &&
        inventario.varianteDisponible(dificil, catalogo) &&
        inten(dificil) == 0) {
      variante = dificil;
      ejercicio = catalogo.ejercicioDeVariante(dificil.id)!;
      p = calcular(variante, ejercicio);
      // Solo el cambio mismo se explica como peldaño; después la variante
      // nueva sigue su propia escalera.
      if (p.motivo == MotivoProgresion.primeraVez) {
        p = p.conMotivo(MotivoProgresion.escaleraVariante);
      }
    } else if (p.cambiaAVariante != null) {
      p = p.conMotivo(MotivoProgresion.escaleraAgotada);
    }

    usadas.add(variante.id);
    if (variante.revision != RevisionContenido.revisado ||
        ejercicio.revision != RevisionContenido.revisado) {
      hayBorrador = true;
    }

    final alternativas = <AlternativaSlot>[
      for (final v in disponibles)
        if (v.id != variante.id)
          AlternativaSlot(v.id, _motivoAlternativa(v, variante, inten(v))),
    ];

    ejercicios.add(
      EjercicioPlanificado(
        slotId: slot.id,
        ejercicioId: ejercicio.id,
        varianteId: variante.id,
        series: p.series,
        rangoMin: p.rangoMin,
        rangoMax: p.rangoMax,
        objetivo: p.objetivo,
        porTiempo: p.porTiempo,
        porLado: ejercicio.porLado,
        descansoS: p.descansoS,
        tempoBajadaS: p.tempoBajadaS,
        motivo: p.motivo,
        cargaPasos: p.cargaPasos,
        bandaId: p.bandaId,
        bandaDoble: p.bandaDoble,
        conPrecaucion: precaucion,
        esExtra: slot.extra,
        topeDePila: p.topeDePila,
        alternativas: alternativas,
      ),
    );
    if (precaucion) {
      avisos.add(AvisoGimnasio(CodigoAviso.conPrecaucion, slotId: slot.id));
    }
    if (p.topeDePila) {
      avisos.add(AvisoGimnasio(CodigoAviso.topeDePila, slotId: slot.id));
    }
    if (variante.carga == TipoCarga.banda &&
        _tocaAvisoDeBanda(historial, variante.id, hoy)) {
      avisos.add(AvisoGimnasio(CodigoAviso.seguridadBanda, slotId: slot.id));
    }
  }

  // Serie de aproximación en el primer ejercicio (PG-20).
  if (ejercicios.isNotEmpty) {
    final e = ejercicios.first;
    final v = catalogo.variante(e.varianteId)!;
    if (v.carga == TipoCarga.pila || v.carga == TipoCarga.banda) {
      ejercicios[0] = _conAproximacion(
        e,
        Aproximacion(
          reps: reglas.aproximacionReps,
          cargaPasos: e.cargaPasos == null
              ? null
              : redondearMitadArriba(e.cargaPasos!, 2),
        ),
      );
    }
  }

  // Calentamiento y cierre (3.6): sin caminadora, marcha suave.
  List<String> bloques(List<String> ids) => [
    for (final id in ids)
      () {
        final b = catalogo.bloque(id);
        if (b != null && b.revision != RevisionContenido.revisado) {
          hayBorrador = true;
        }
        return b != null && b.requiereCaminadora && !caminadora
            ? (b.sustitutoSinCaminadora ?? id)
            : id;
      }(),
  ];
  final calentamiento = bloques(plantilla.calentamiento);
  final cierre = bloques(plantilla.cierre);
  final calMin =
      perfil.ventana == VentanaEntrenamiento.manana &&
          reglas.calentamientoMananaMin > params.calentamientoMin
      ? reglas.calentamientoMananaMin
      : params.calentamientoMin;

  final m = modelo ?? calibrarModelo(historial, reglas: reglas);
  final duracion = duracionSegundos(
    ejercicios,
    calentamientoMin: calMin,
    cierreMin: params.cierreMin,
    modelo: m,
  );

  // Avisos de la sesión.
  if (ejercicios.length < 3) {
    avisos.add(const AvisoGimnasio(CodigoAviso.sinEquipoSuficiente));
    avisos.add(const AvisoGimnasio(CodigoAviso.ofrecerRegenerativa));
  }
  if (intensidadMaxima >= IntensidadMolestia.fuerte) {
    avisos.add(const AvisoGimnasio(CodigoAviso.molestiaFuerte));
    avisos.add(const AvisoGimnasio(CodigoAviso.ofrecerRegenerativa));
  }
  if (modoFoco) {
    avisos.add(const AvisoGimnasio(CodigoAviso.modoFoco));
    if (version != VersionSesion.corta) {
      avisos.add(const AvisoGimnasio(CodigoAviso.versionCortaSugerida));
    }
  }
  if (semana.tipo == TipoSemana.carga &&
      sugerirDescarga(historial, reglas: reglas)) {
    avisos.add(const AvisoGimnasio(CodigoAviso.descargaSugerida));
  }
  if (hayBorrador) {
    avisos.add(const AvisoGimnasio(CodigoAviso.contenidoEnRevision));
  }

  return SesionPlanificada(
    plantillaId: plantillaId,
    version: version,
    semana: semana,
    ejercicios: ejercicios,
    omitidos: omitidos,
    calentamientoMin: calMin,
    cierreMin: params.cierreMin,
    calentamiento: calentamiento,
    cierre: cierre,
    duracionEstimadaSeg: duracion,
    avisos: avisos,
    contenidoEnRevision: hayBorrador,
    versionSugerida: semana.versionSugerida,
  );
}

EjercicioPlanificado _conAproximacion(EjercicioPlanificado e, Aproximacion a) =>
    EjercicioPlanificado(
      slotId: e.slotId,
      ejercicioId: e.ejercicioId,
      varianteId: e.varianteId,
      series: e.series,
      rangoMin: e.rangoMin,
      rangoMax: e.rangoMax,
      objetivo: e.objetivo,
      porTiempo: e.porTiempo,
      porLado: e.porLado,
      descansoS: e.descansoS,
      tempoBajadaS: e.tempoBajadaS,
      motivo: e.motivo,
      cargaPasos: e.cargaPasos,
      bandaId: e.bandaId,
      bandaDoble: e.bandaDoble,
      conPrecaucion: e.conPrecaucion,
      esExtra: e.esExtra,
      topeDePila: e.topeDePila,
      alternativas: e.alternativas,
      aproximacion: a,
    );

/// El aviso de seguridad de la banda sale la primera vez de cada variante y
/// cada 4 semanas (5.4).
bool _tocaAvisoDeBanda(
  List<SesionRegistrada> historial,
  String varianteId,
  DateTime hoy,
) {
  DateTime? ultima;
  for (final s in historial) {
    if (!s.terminada || !s.series.any((x) => x.varianteId == varianteId)) {
      continue;
    }
    final f = soloDia(s.fecha);
    if (ultima == null || f.isAfter(ultima)) ultima = f;
  }
  return ultima == null || diasEntre(ultima, hoy) >= 28;
}
