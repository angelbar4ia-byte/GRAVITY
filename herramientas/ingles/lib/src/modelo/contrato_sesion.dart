/// Lo que el contrato `gravity-sesion-60` declara y que leen V21 (mínimos), V22
/// (minutos), V27 (consistencia) y V28 (pruebas por unidad y mini pruebas).
///
/// Nada de esto está en el código: cada cifra sale del contrato, y si el
/// contrato no la trae el getter devuelve null y quien la necesita lo dice. Los
/// nombres de los campos son los del contrato (`por_dia`, `minutos_parte`,
/// `tolerancias_de_minutos`, `tarjetas_nuevas`, `sin_audio`, `asistencia`,
/// `viernes`, `estimacion_de_minutos`).
library;

import 'datos.dart';
import 'formato.dart';

/// El identificador del contrato de la sesión.
const String idContratoSesion = 'gravity-sesion-60';

class ContratoSesion {
  ContratoSesion(this.formato) : datos = formato.datos;

  final Formato formato;
  final Mapa datos;

  Mapa? _parte(String id) => formato.parte(id)?.datos;

  /// ¿Declara el contrato la estructura de la sesión (días, minutos por parte y
  /// total)? Sin ella V21 y V22 no tienen contra qué comprobar y callan; V27 dice
  /// en el contrato lo que le falta.
  bool get declaraLaSesion =>
      dias.isNotEmpty &&
      minutosTotales != null &&
      minutosDeParte('leccion') != null &&
      minutosDeParte('repaso') != null;

  // ---------------------------------------------------------------- minutos

  num? minutosDeParte(String parte) => numeroEn(_parte(parte), 'minutos_parte');

  num? get minutosTotales => numeroEn(datos, 'totales.minutos');
  num? get minutosPrincipal => numeroEn(datos, 'totales.minutos_principal');
  num? get minutosTraslado => numeroEn(datos, 'totales.minutos_traslado');
  int? get sesionesPorSemana => enteroEn(datos, 'totales.sesiones_por_semana');

  num? get porcentajeMinimoPorBloque =>
      numeroEn(datos, 'tolerancias_de_minutos.por_bloque.minimo_porcentaje');
  num? get porcentajeMaximoPorBloque =>
      numeroEn(datos, 'tolerancias_de_minutos.por_bloque.maximo_porcentaje');
  num? get totalMinimo => numeroEn(datos, 'tolerancias_de_minutos.total.min');
  num? get totalMaximo => numeroEn(datos, 'tolerancias_de_minutos.total.max');

  // ------------------------------------------------------------------- días

  List<String> get dias => [
    for (final d in listaEn(datos, 'dias.lista') ?? const <Object?>[])
      if (d is Map && d['dia'] is String) d['dia']! as String,
  ];

  /// Lo que dice la lección de un día (`por_dia.<día>`), o null si no dice nada.
  Mapa? leccionDelDia(String dia) => mapaEn(_parte('leccion'), 'por_dia.$dia');

  /// La marca de pendiente de la lección de un día, si la tiene.
  DatoPendiente? pendienteDeLeccion(String dia) {
    final m = leccionDelDia(dia);
    if (m == null || m['pendiente'] != true) return null;
    return DatoPendiente('leccion.por_dia.$dia', m['nota'] as String?);
  }

  int? elementosDeLeccion(String dia) =>
      enteroEn(leccionDelDia(dia), 'elementos.min');
  String? estimuloDeLeccion(String dia) =>
      textoEn(leccionDelDia(dia), 'estimulo.tipo');
  int? ejemplosMinimos(String dia) =>
      enteroEn(leccionDelDia(dia), 'ejemplos.min');
  int? preguntasMinimasDeLeccion(String dia) =>
      enteroEn(leccionDelDia(dia), 'preguntas.min');
  bool exigeErrorComun(String dia) =>
      boolEn(leccionDelDia(dia), 'error_comun') ?? false;
  bool exigeExplicacion(String dia) =>
      boolEn(leccionDelDia(dia), 'explicacion') ?? false;

  /// Con qué se sustituye la lección ese día (`conversacion_guiada` el viernes).
  String? leccionSustituidaPor(String dia) =>
      textoEn(leccionDelDia(dia), 'sustituido_por');
  String? repasoSustituidoPor(String dia) =>
      textoEn(_parte('repaso'), 'por_dia.$dia.sustituido_por');

  int? elementosDePronunciacion(String dia) =>
      enteroEn(_parte('pronunciacion'), 'por_dia.$dia.elementos.min');

  /// Lo que la producción exige: consigna, cotejo y modelo.
  List<String> get requisitosDeProduccion =>
      textosEn(_parte('produccion'), 'requiere') ?? const [];

  /// La modalidad que el contrato fija a la producción de un día, si la fija.
  String? modalidadDeProduccion(String dia) {
    final propia = textoEn(_parte('produccion'), 'por_dia.$dia.modalidad');
    if (propia != null) return propia;
    // `ver: viernes`: la modalidad la fija el cambio del viernes.
    if (textoEn(_parte('produccion'), 'por_dia.$dia.ver') == 'viernes') {
      for (final c in listaEn(datos, 'viernes.cambios') ?? const <Object?>[]) {
        if (c is Map && c['bloque'] == 'produccion' && c['modalidad'] is String) {
          return c['modalidad']! as String;
        }
      }
    }
    return null;
  }

  /// La marca de pendiente de la modalidad de la producción de lunes a miércoles.
  DatoPendiente? get pendienteDeModalidad {
    final m = mapaEn(_parte('produccion'), 'modalidad_de_lunes_a_miercoles');
    if (m == null || m['pendiente'] != true) return null;
    return DatoPendiente(
      'produccion.modalidad_de_lunes_a_miercoles',
      m['nota'] as String?,
    );
  }

  /// La marca de pendiente del bloque en que se cuentan las tarjetas nuevas.
  DatoPendiente? get pendienteDeTarjetasNuevas {
    final m = mapaEn(datos, 'tarjetas_nuevas.se_cuentan_en_el_bloque');
    if (m == null || m['pendiente'] != true) return null;
    return DatoPendiente(
      'tarjetas_nuevas.se_cuentan_en_el_bloque',
      m['nota'] as String?,
    );
  }

  /// Pendientes de la estructura del viernes (conversación, mini prueba, prueba
  /// por unidad y su estimación).
  List<DatoPendiente> get pendientesDelViernes =>
      pendientesEn(mapaEn(datos, 'viernes'), 'viernes');

  int? tarjetasNuevasDelDia(String dia) =>
      enteroEn(datos, 'tarjetas_nuevas.por_dia.$dia');
  int? get tarjetasNuevasPorSemana =>
      enteroEn(datos, 'tarjetas_nuevas.por_semana');

  // --------------------------------------------------------------- traslado

  int? get audiosDeTraslado => formato.parte('traslado-audio')?.unidades;
  int? get reproduccionesDeTraslado =>
      formato.parte('traslado-audio')?.reproducciones;
  int? get frasesMinimas =>
      enteroEn(_parte('traslado-repeticion'), 'frases.min');
  bool get mismosAudiosTodaLaSemana =>
      boolEn(
        _parte('traslado-audio'),
        'por_semana.los_mismos_en_las_cinco_sesiones',
      ) ??
      false;
  bool get audiosDistintosEntreSi =>
      boolEn(_parte('traslado-audio'), 'por_semana.distintos_entre_si') ??
      false;

  /// La marca de pendiente del criterio «monólogo y diálogo», si la tiene.
  DatoPendiente? get pendienteDeMonologoYDialogo {
    final m = mapaEn(_parte('traslado-audio'), 'criterio_monologo_y_dialogo');
    if (m == null || m['pendiente'] != true) return null;
    return DatoPendiente(
      'traslado-audio.criterio_monologo_y_dialogo',
      m['nota'] as String?,
    );
  }

  // ------------------------------------------------------------ estimación

  num? get palabrasPorMinuto =>
      numeroEn(datos, 'estimacion_de_minutos.explicacion.palabras_por_minuto');
  num? get segundosPorEjemplo =>
      numeroEn(datos, 'estimacion_de_minutos.ejemplo.segundos');
  num? get segundosPorFrase =>
      numeroEn(datos, 'estimacion_de_minutos.frase_para_repetir.segundos');
  num? get segundosPorElemento => numeroEn(
    datos,
    'estimacion_de_minutos.elemento_de_pronunciacion.segundos',
  );
  num? get segundosPorTarjetaNueva =>
      numeroEn(datos, 'estimacion_de_minutos.tarjeta_nueva.segundos');
  num? get segundosPorPreguntaDeEscucha =>
      numeroEn(datos, 'estimacion_de_minutos.escucha.segundos_por_pregunta');
  num? get palabrasPorMinutoDeEscucha =>
      numeroEn(datos, 'estimacion_de_minutos.escucha.palabras_por_minuto');

  /// Segundos por pregunta según su tipo (`opcion_multiple` → 40...). Null si el
  /// contrato no da el tipo.
  num? segundosDePregunta(String tipo) {
    final grupos = mapaEn(datos, 'estimacion_de_minutos.preguntas');
    if (grupos == null) return null;
    for (final g in grupos.values) {
      if (g is! Map) continue;
      final tipos = g['tipos'];
      final s = g['segundos'];
      if (tipos is List && tipos.contains(tipo) && s is num) return s;
    }
    return null;
  }

  /// Marcas de pendiente de la estimación (tipos sin tiempo, fórmula de lectura).
  List<DatoPendiente> get pendientesDeEstimacion => pendientesEn(
    mapaEn(datos, 'estimacion_de_minutos'),
    'estimacion_de_minutos',
  );

  // ---------------------------------------------------------------- viernes

  int? get preguntasDeMiniPrueba =>
      enteroEn(datos, 'viernes.mini_prueba.preguntas');
  int? get aprobarMiniPruebaCon =>
      enteroEn(datos, 'viernes.mini_prueba.aprobar_con');
  List<int>? get semanasDeMiniPrueba =>
      enterosEn(datos, 'viernes.mini_prueba.semanas');

  List<int>? get semanasDePruebaPorUnidad =>
      enterosEn(datos, 'viernes.prueba_por_unidad.viernes_de_las_semanas');
  List<int>? get semanasDeRepeticion =>
      enterosEn(datos, 'viernes.prueba_por_unidad.repeticion.semanas');
  int? get pruebasPorEscalon =>
      enteroEn(datos, 'viernes.prueba_por_unidad.por_escalon');
  int? get preguntasDePruebaConAudio =>
      enteroEn(datos, 'viernes.prueba_por_unidad.preguntas.con_audio');
  int? get preguntasDePruebaSinAudio =>
      enteroEn(datos, 'viernes.prueba_por_unidad.preguntas.sin_audio');
  int? get reproduccionesDePrueba =>
      enteroEn(datos, 'viernes.prueba_por_unidad.reproducciones_del_audio');
  int? get umbralDePruebaPorcentaje =>
      enteroEn(datos, 'viernes.prueba_por_unidad.umbral_porcentaje');

  /// `composicion_con_audio`: habilidad → preguntas (`gramatica` 6, `vocabulario`
  /// 4, `lectura` 5, `escucha` 5).
  Map<String, int> get composicionDePrueba {
    final m = mapaEn(datos, 'viernes.prueba_por_unidad.composicion_con_audio');
    if (m == null) return const {};
    return {
      for (final e in m.entries)
        if (e.value is num) e.key: (e.value! as num).toInt(),
    };
  }

  int? get turnosMinimosDeConversacion =>
      enteroEn(datos, 'viernes.conversacion_guiada.turnos.min');

  /// Reglas de la conversación guiada que el contrato no trae como dato y que
  /// el formato 0.5 (7.1) fija en prosa: cuatro turnos de la persona como
  /// mínimo y dos variantes por turno. Si el contrato las declara
  /// (`turnos_de_la_persona.min`, `variantes_por_turno.min`) se leen de ahí.
  int get turnosMinimosDeLaPersona =>
      enteroEn(datos, 'viernes.conversacion_guiada.turnos_de_la_persona.min') ??
      4;
  int get variantesMinimasPorTurno =>
      enteroEn(datos, 'viernes.conversacion_guiada.variantes_por_turno.min') ??
      2;
  bool get declaraReglasDeConversacion =>
      enteroEn(datos, 'viernes.conversacion_guiada.turnos_de_la_persona.min') !=
          null &&
      enteroEn(datos, 'viernes.conversacion_guiada.variantes_por_turno.min') !=
          null;

  /// Segundos por turno de la conversación guiada (formato 0.5, 7.1): 60 el de
  /// la persona y 15 el del sistema. Tampoco son datos del contrato.
  num get segundosPorTurnoDePersona =>
      numeroEn(
        datos,
        'estimacion_de_minutos.conversacion_guiada.segundos_por_turno_de_persona',
      ) ??
      60;
  num get segundosPorTurnoDeSistema =>
      numeroEn(
        datos,
        'estimacion_de_minutos.conversacion_guiada.segundos_por_turno_de_sistema',
      ) ??
      15;

  // --------------------------------------------------- sin audio y asistencia

  List<String>? get bloquesQueCuentanSinAudio =>
      textosEn(datos, 'sin_audio.cuentan');
  num? get minutosSinAudio =>
      numeroEn(datos, 'sin_audio.minutos_que_cuentan_al_dia');
  num? get minutosPlaneadosConAudio =>
      numeroEn(datos, 'asistencia.minutos_planeados_por_dia.con_audio');
  num? get minutosPlaneadosSinAudio =>
      numeroEn(datos, 'asistencia.minutos_planeados_por_dia.sin_audio');
  int? get faltanteMaximoPorDia =>
      enteroEn(datos, 'asistencia.faltante_maximo_por_dia_segundos');
  int? get diasFaltadosPorEscalon =>
      enteroEn(datos, 'asistencia.dias_faltados_tolerados_por_escalon');
}
