/// Repositorio local de «Mi gimnasio» (Fase 8, G3): **local primero**.
///
/// Todo lo que la persona hace (perfil, plan, inventario, bandas, sesiones y
/// series) se guarda **primero** en las tablas locales (drift, espejo de
/// `hab_ent_*`) y, en la misma transacción, se **encola** para subirlo con los
/// tipos `habitos.gim_*` (`contrato_gimnasio.dart`). Sin red todo funciona; al
/// volver la señal la cola sube con **el mismo id** y el reintento no duplica
/// (CA-G-32). **Ningún registro se escribe directo con `upsert`** a Supabase.
///
/// - **Entrada y salida con la forma del servidor** (nombres de columna de
///   4.2): el dominio ya arma `SesionRegistrada.aJsonServidor` y
///   `SerieRegistrada.aJsonServidor`; este repositorio las valida
///   ([validarFilaGimnasio]), las guarda y las sube tal cual. Lo que lee lo
///   entrega como filas tipadas de drift (con `aMapaServidor()`).
/// - **Último cambio gana:** cada escritura lleva su `modificado_en` (la hora
///   del dispositivo, que nunca retrocede para esa fila).
/// - **Ids:** la sesión y la serie deben traer su id UUID v5 ([IdsGimnasio]); si
///   falta se calcula, y si no coincide se rechaza (otro id para el mismo día
///   daría 23505, permanente). Las bandas llevan UUID v4.
/// - **Lo único que no se sube** es `tiempos` (calibra el tiempo estimado).
/// - **Sin molestias:** no hay columna, y las cargas se revisan para que
///   ninguna columna ni clave hable de ellas.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import '../base_local/base_local.dart';
import '../cola/cola_sin_conexion.dart';
import '../cola/contrato_gimnasio.dart';
import 'ids_gimnasio.dart';
import 'uuid_v5.dart';
import 'validacion_gimnasio.dart';

// ------------------------------------------------------------------- filas

/// Las filas locales como las espera el servidor (para encolar y para exportar).
extension GimPerfilComoMapa on GimPerfilFila {
  Map<String, Object?> aMapaServidor() => {
    'dias_plan': diasPlan,
    'version_pref': versionPref,
    'ventana': ventana,
    'noche_desde': nocheDesde,
    'objetivo': objetivo,
    'nivel': nivel,
    'inicio_ciclo': inicioCiclo,
    'ciclo_semanas': cicloSemanas,
    'descanso_s': descansoS,
    'margen_dormir_min': margenDormirMin,
    'prueba_desde': pruebaDesde,
    'prueba_ventana': pruebaVentana,
    'voz_descanso': vozDescanso,
    'aviso_visto_en': avisoVistoEn?.toUtc().toIso8601String(),
    'modificado_en': modificadoEn.toUtc().toIso8601String(),
  };
}

extension GimPlanDiaComoMapa on GimPlanDiaFila {
  Map<String, Object?> aMapaServidor() => {
    'dia_semana': diaSemana,
    'tipo': tipo,
    'version': version,
    'hora': hora,
    'modificado_en': modificadoEn.toUtc().toIso8601String(),
  };
}

extension GimInventarioComoMapa on GimInventarioFila {
  /// Lo confirmado en el aparato (pasos de la pila, kg por paso…).
  Map<String, Object?> get confirmadoComoMapa =>
      (jsonDecode(confirmado) as Map).cast<String, Object?>();

  Map<String, Object?> aMapaServidor() => {
    'item_id': itemId,
    'estado': estado,
    'confirmado': confirmadoComoMapa,
    'notas': notas,
    'modificado_en': modificadoEn.toUtc().toIso8601String(),
  };
}

extension GimBandaComoMapa on GimBandaFila {
  Map<String, Object?> aMapaServidor() => {
    'id': id,
    'nombre': nombre,
    'orden': orden,
    'resistencia_kg_x10': resistenciaKgX10,
    'cantidad': cantidad,
    'activa': activa,
    'modificado_en': modificadoEn.toUtc().toIso8601String(),
  };
}

extension GimSesionComoMapa on GimSesionFila {
  /// Lo planeado, como lista de `{ejercicio, variante, series, reps_min,
  /// reps_max}`.
  List<Map<String, Object?>> get planComoLista => [
    for (final e in jsonDecode(plan) as List) (e as Map).cast<String, Object?>(),
  ];

  /// Lo medido solo en este equipo (nunca se sube).
  Map<String, Object?>? get tiemposComoMapa => tiempos == null
      ? null
      : (jsonDecode(tiempos!) as Map).cast<String, Object?>();

  Map<String, Object?> aMapaServidor() => {
    'id': id,
    'fecha': fecha,
    'plantilla': plantilla,
    'version': version,
    'semana_tipo': semanaTipo,
    'ventana': ventana,
    'bloque_id': bloqueId,
    'inicio': inicio.toUtc().toIso8601String(),
    'fin': fin?.toUtc().toIso8601String(),
    'estado': estado,
    'esfuerzo': esfuerzo,
    'energia': energia,
    'plan': planComoLista,
    'catalogo_version': catalogoVersion,
    'modificado_en': modificadoEn.toUtc().toIso8601String(),
  };
}

extension GimSerieComoMapa on GimSerieFila {
  Map<String, Object?> aMapaServidor() => {
    'id': id,
    'sesion_id': sesionId,
    'ejercicio_id': ejercicioId,
    'variante_id': varianteId,
    'n': n,
    'lado': lado,
    'reps': reps,
    'segundos': segundos,
    'carga_pasos': cargaPasos,
    'banda_id': bandaId,
    'esfuerzo': esfuerzo,
    'descanso_real_s': descansoRealS,
    'sustituye_a': sustituyeA,
    'motivo_cambio': motivoCambio,
    'modificado_en': modificadoEn.toUtc().toIso8601String(),
  };
}

// --------------------------------------------------------------- utilidades

/// El instante como texto ISO en UTC. Acepta [DateTime] o texto (con o sin zona:
/// sin zona se toma como hora local del dispositivo, que es como lo arma el
/// dominio con `toIso8601String`).
String? _aIsoUtc(Object? v) {
  if (v == null) return null;
  if (v is DateTime) return v.toUtc().toIso8601String();
  if (v is String) return DateTime.tryParse(v)?.toUtc().toIso8601String();
  return null;
}

/// Hora `HH:MM` (el servidor devuelve `HH:MM:SS`).
String? _hhmm(Object? v) =>
    v is String ? (v.length >= 5 ? v.substring(0, 5) : v) : null;

/// Quita los segundos sueltos: lo que guarda drift (segundos desde 1970).
DateTime _aSegundos(DateTime t) =>
    DateTime.fromMillisecondsSinceEpoch(t.millisecondsSinceEpoch ~/ 1000 * 1000);

class RepositorioGimnasio {
  RepositorioGimnasio(
    this._base, {
    this._cola,
    DateTime Function()? reloj,
  }) : _reloj = reloj ?? DateTime.now;

  final BaseLocal _base;

  /// Con cola, cada cambio se encola para subirlo. Sin ella (pruebas de lo
  /// local, demostración) solo se guarda en el equipo.
  final ColaSinConexion? _cola;
  final DateTime Function() _reloj;

  // ------------------------------------------------------------------ perfil

  Future<GimPerfilFila?> perfil(String persona) => (_base.select(
    _base.gimPerfil,
  )..where((t) => t.personaId.equals(persona))).getSingleOrNull();

  /// Cambia el perfil: [cambios] son columnas de `hab_ent_perfil` (por ejemplo
  /// `{'dias_plan': 4}`); lo demás queda como estaba (o por omisión la primera
  /// vez). Devuelve la fila guardada.
  Future<GimPerfilFila> guardarPerfil(
    String persona,
    Map<String, Object?> cambios,
  ) async {
    final actual = await perfil(persona);
    final fila = {
      ..._perfilPorOmision,
      ...?actual?.aMapaServidor(),
      ...cambios,
    };
    fila['aviso_visto_en'] = _aIsoUtc(fila['aviso_visto_en']);
    fila['noche_desde'] = _hhmm(fila['noche_desde']);
    await _guardar(
      tabla: 'hab_ent_perfil',
      persona: persona,
      fila: fila,
      tipo: TipoColaGimnasio.perfil,
      clave: 'perfil',
      anterior: actual?.modificadoEn,
    );
    return (await perfil(persona))!;
  }

  static const _perfilPorOmision = <String, Object?>{
    'dias_plan': 3,
    'version_pref': 'auto',
    'ventana': 'noche',
    'noche_desde': '19:00',
    'objetivo': 'salud_general',
    'nivel': 'principiante',
    'inicio_ciclo': null,
    'ciclo_semanas': 4,
    'descanso_s': null,
    'margen_dormir_min': 90,
    'prueba_desde': null,
    'prueba_ventana': null,
    'voz_descanso': false,
    'aviso_visto_en': null,
  };

  // -------------------------------------------------------------------- plan

  Future<List<GimPlanDiaFila>> planDias(String persona) =>
      (_base.select(_base.gimPlanDias)
            ..where((t) => t.personaId.equals(persona))
            ..orderBy([(t) => OrderingTerm.asc(t.diaSemana)]))
          .get();

  /// Pone el día [diaSemana] (1 = lunes) del plan: [tipo] (`A`, `B`, `C`, `R1`,
  /// `R2`, `bici` o `descanso`), [version] y [hora] (`HH:MM`, opcional).
  Future<void> guardarPlanDia(
    String persona, {
    required int diaSemana,
    required String tipo,
    String version = 'auto',
    String? hora,
  }) async {
    final actual = await (_base.select(_base.gimPlanDias)..where(
          (t) => t.personaId.equals(persona) & t.diaSemana.equals(diaSemana),
        ))
        .getSingleOrNull();
    await _guardar(
      tabla: 'hab_ent_plan_dias',
      persona: persona,
      fila: {
        'dia_semana': diaSemana,
        'tipo': tipo,
        'version': version,
        'hora': _hhmm(hora),
      },
      tipo: TipoColaGimnasio.planDia,
      clave: 'plan:$diaSemana',
      anterior: actual?.modificadoEn,
    );
  }

  // -------------------------------------------------------------- inventario

  Future<List<GimInventarioFila>> inventario(String persona) =>
      (_base.select(_base.gimInventario)
            ..where((t) => t.personaId.equals(persona))
            ..orderBy([(t) => OrderingTerm.asc(t.itemId)]))
          .get();

  /// Pone un aparato, puesto o accesorio del inventario. [confirmado] son los
  /// datos del **aparato** confirmados por la persona (`pasos_max`,
  /// `kg_por_paso_x10`…): nada de salud.
  Future<void> guardarItemInventario(
    String persona, {
    required String itemId,
    required String estado,
    Map<String, Object?> confirmado = const {},
    String? notas,
  }) async {
    final actual = await (_base.select(_base.gimInventario)..where(
          (t) => t.personaId.equals(persona) & t.itemId.equals(itemId),
        ))
        .getSingleOrNull();
    await _guardar(
      tabla: 'hab_ent_inventario',
      persona: persona,
      fila: {
        'item_id': itemId,
        'estado': estado,
        'confirmado': confirmado,
        'notas': notas,
      },
      tipo: TipoColaGimnasio.inventario,
      clave: 'inv:$itemId',
      anterior: actual?.modificadoEn,
    );
  }

  // ------------------------------------------------------------------ bandas

  Future<List<GimBandaFila>> bandas(String persona) =>
      (_base.select(_base.gimBandas)
            ..where((t) => t.personaId.equals(persona))
            ..orderBy([(t) => OrderingTerm.asc(t.orden)]))
          .get();

  /// Agrega o cambia una banda. [id] es un UUID v4 ([IdsGimnasio.banda]); si no
  /// se da, se crea uno. Devuelve el id.
  Future<String> guardarBanda(
    String persona, {
    String? id,
    required String nombre,
    required int orden,
    int? resistenciaKgX10,
    int cantidad = 1,
    bool activa = true,
  }) async {
    final idFinal = id ?? IdsGimnasio.banda();
    final actual = await (_base.select(_base.gimBandas)..where(
          (t) => t.personaId.equals(persona) & t.id.equals(idFinal),
        ))
        .getSingleOrNull();
    await _guardar(
      tabla: 'hab_ent_bandas',
      persona: persona,
      fila: {
        'id': idFinal,
        'nombre': nombre,
        'orden': orden,
        'resistencia_kg_x10': resistenciaKgX10,
        'cantidad': cantidad,
        'activa': activa,
      },
      tipo: TipoColaGimnasio.banda,
      clave: 'banda:$idFinal',
      anterior: actual?.modificadoEn,
    );
    return idFinal;
  }

  /// Quita una banda (las series que la usaron quedan sin banda, como en el
  /// servidor).
  Future<void> borrarBanda(String persona, String id) async {
    await _transaccion(() async {
      await (_base.delete(_base.gimBandas)
            ..where((t) => t.personaId.equals(persona) & t.id.equals(id)))
          .go();
      await (_base.update(_base.gimSeries)
            ..where((t) => t.personaId.equals(persona) & t.bandaId.equals(id)))
          .write(const GimSeriesCompanion(bandaId: Value(null)));
      await _encolarBorrado(persona, TipoColaGimnasio.bandaBorrar, id);
    });
  }

  // ---------------------------------------------------------------- sesiones

  Future<GimSesionFila?> sesion(String persona, String id) =>
      (_base.select(_base.gimSesiones)
            ..where((t) => t.personaId.equals(persona) & t.id.equals(id)))
          .getSingleOrNull();

  /// La sesión del día [fecha] (`AAAA-MM-DD`) con la [plantilla], si existe.
  Future<GimSesionFila?> sesionDelDia(
    String persona,
    String fecha,
    String plantilla,
  ) => (_base.select(_base.gimSesiones)..where(
        (t) =>
            t.personaId.equals(persona) &
            t.fecha.equals(fecha) &
            t.plantilla.equals(plantilla),
      ))
      .getSingleOrNull();

  /// La sesión que quedó `en_curso` (la más reciente), para retomarla (por
  /// ejemplo tras volver al modo Casa en la tablet, PG-17).
  Future<GimSesionFila?> sesionEnCurso(String persona) =>
      (_base.select(_base.gimSesiones)
            ..where(
              (t) => t.personaId.equals(persona) & t.estado.equals('en_curso'),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.inicio)])
            ..limit(1))
          .getSingleOrNull();

  /// Sesiones de la persona, de la más nueva a la más vieja; con [desde] y
  /// [hasta] (`AAAA-MM-DD`, incluyentes) se acota.
  Future<List<GimSesionFila>> sesiones(
    String persona, {
    String? desde,
    String? hasta,
  }) =>
      (_base.select(_base.gimSesiones)
            ..where(
              (t) =>
                  t.personaId.equals(persona) &
                  (desde == null
                      ? const Constant(true)
                      : t.fecha.isBiggerOrEqualValue(desde)) &
                  (hasta == null
                      ? const Constant(true)
                      : t.fecha.isSmallerOrEqualValue(hasta)),
            )
            ..orderBy([
              (t) => OrderingTerm.desc(t.fecha),
              (t) => OrderingTerm.desc(t.inicio),
            ]))
          .get();

  /// Guarda (o actualiza) una sesión. [sesion] es lo que arma
  /// `SesionRegistrada.aJsonServidor(id: …, bloqueId: …)`; puede traer solo lo
  /// que cambia al actualizar una existente. [tiempos] se queda **solo en este
  /// equipo**. Devuelve la fila guardada.
  Future<GimSesionFila> guardarSesion(
    String persona,
    Map<String, Object?> sesion, {
    Map<String, Object?>? tiempos,
  }) async {
    final idDado = sesion['id'] as String?;
    final actual = idDado == null ? null : await this.sesion(persona, idDado);
    final fila = {...?actual?.aMapaServidor(), ...sesion};
    fila['inicio'] = _aIsoUtc(fila['inicio']);
    fila['fin'] = _aIsoUtc(fila['fin']);
    // La base exige la ventana; si el dominio no la sabe, se deduce de la hora
    // de inicio (antes del mediodía, mañana; después, noche).
    if (fila['ventana'] == null || fila['ventana'] == 'flexible') {
      final ini = fila['inicio'] == null
          ? null
          : DateTime.parse(fila['inicio']! as String).toLocal();
      fila['ventana'] = ini != null && ini.hour < 12 ? 'manana' : 'noche';
    }
    if (fila['fecha'] is! String || fila['plantilla'] is! String) {
      throw FilaGimnasioInvalida('hab_ent_sesiones', 'fecha');
    }
    final esperado = IdsGimnasio.sesion(
      persona,
      DateTime.parse(fila['fecha']! as String),
      fila['plantilla']! as String,
    );
    if (fila['id'] == null) fila['id'] = esperado;
    if (fila['id'] != esperado) {
      throw FilaGimnasioInvalida('hab_ent_sesiones', 'id');
    }
    fila['plan'] ??= const <Object?>[];
    final guardada = await _guardar(
      tabla: 'hab_ent_sesiones',
      persona: persona,
      fila: fila,
      tipo: TipoColaGimnasio.sesion,
      clave: 'ses:${fila['id']}',
      anterior: actual?.modificadoEn,
      tiempos: tiempos,
    );
    return (await this.sesion(persona, guardada))!;
  }

  /// Borra una sesión y sus series (en el servidor, las series se van en
  /// cascada).
  Future<void> borrarSesion(String persona, String id) async {
    await _transaccion(() async {
      await (_base.delete(_base.gimSeries)..where(
            (t) => t.personaId.equals(persona) & t.sesionId.equals(id),
          ))
          .go();
      await (_base.delete(_base.gimSesiones)
            ..where((t) => t.personaId.equals(persona) & t.id.equals(id)))
          .go();
      await _encolarBorrado(persona, TipoColaGimnasio.sesionBorrar, id);
    });
  }

  // ------------------------------------------------------------------ series

  Future<List<GimSerieFila>> series(String persona, String sesionId) =>
      (_base.select(_base.gimSeries)
            ..where(
              (t) =>
                  t.personaId.equals(persona) & t.sesionId.equals(sesionId),
            )
            ..orderBy([
              (t) => OrderingTerm.asc(t.ejercicioId),
              (t) => OrderingTerm.asc(t.n),
            ]))
          .get();

  /// Todas las series de la persona (historial y récords); con [ejercicioId]
  /// solo las de ese ejercicio.
  Future<List<GimSerieFila>> todasLasSeries(
    String persona, {
    String? ejercicioId,
  }) =>
      (_base.select(_base.gimSeries)..where(
            (t) =>
                t.personaId.equals(persona) &
                (ejercicioId == null
                    ? const Constant(true)
                    : t.ejercicioId.equals(ejercicioId)),
          ))
          .get();

  /// Guarda una serie hecha. [serie] es lo que arma
  /// `SerieRegistrada.aJsonServidor(id: …, sesionId: …)`; el id se calcula si
  /// falta (v5 de la persona, la sesión, el ejercicio, el número y el lado) y se
  /// rechaza si no coincide. Devuelve el id.
  Future<String> guardarSerie(
    String persona,
    Map<String, Object?> serie,
  ) async {
    final sesionId = serie['sesion_id'];
    final ejercicio = serie['ejercicio_id'];
    final n = serie['n'];
    if (sesionId is! String || ejercicio is! String || n is! int) {
      throw FilaGimnasioInvalida('hab_ent_series', 'sesion_id');
    }
    final esperado = IdsGimnasio.serie(
      persona,
      sesionId,
      ejercicio,
      n,
      lado: serie['lado'] as String?,
    );
    final id = (serie['id'] as String?) ?? esperado;
    if (id != esperado) throw FilaGimnasioInvalida('hab_ent_series', 'id');
    final actual = await (_base.select(_base.gimSeries)
          ..where((t) => t.personaId.equals(persona) & t.id.equals(id)))
        .getSingleOrNull();
    await _guardar(
      tabla: 'hab_ent_series',
      persona: persona,
      fila: {...?actual?.aMapaServidor(), ...serie, 'id': id},
      tipo: TipoColaGimnasio.serie,
      clave: 'ser:$id',
      anterior: actual?.modificadoEn,
    );
    return id;
  }

  /// Deshacer: quita una serie (y, si ya subió, se borra también en el
  /// servidor).
  Future<void> borrarSerie(String persona, String id) async {
    await _transaccion(() async {
      await (_base.delete(_base.gimSeries)
            ..where((t) => t.personaId.equals(persona) & t.id.equals(id)))
          .go();
      await _encolarBorrado(persona, TipoColaGimnasio.serieBorrar, id);
    });
  }

  // ------------------------------------------------------------------ borrar

  /// Borra de este equipo **todo** lo del entrenamiento de [persona] (tablas
  /// locales y lo suyo que espera en la cola). Lo de la nube lo borra
  /// `hab_borrar_mis_datos`. Se usa en «Borrar mis datos», al quitar a la
  /// persona de la tablet y al darla de baja.
  Future<void> borrarTodoDe(String persona) async {
    await _transaccion(() async {
      for (final borrar in <Future<int> Function()>[
        () => (_base.delete(_base.gimSeries)
              ..where((t) => t.personaId.equals(persona)))
            .go(),
        () => (_base.delete(_base.gimSesiones)
              ..where((t) => t.personaId.equals(persona)))
            .go(),
        () => (_base.delete(_base.gimBandas)
              ..where((t) => t.personaId.equals(persona)))
            .go(),
        () => (_base.delete(_base.gimInventario)
              ..where((t) => t.personaId.equals(persona)))
            .go(),
        () => (_base.delete(_base.gimPlanDias)
              ..where((t) => t.personaId.equals(persona)))
            .go(),
        () => (_base.delete(_base.gimPerfil)
              ..where((t) => t.personaId.equals(persona)))
            .go(),
        () => (_base.delete(_base.pendientes)..where(
              (t) =>
                  t.personaId.equals(persona) &
                  t.tipo.like('${TipoColaGimnasio.prefijo}%'),
            ))
            .go(),
      ]) {
        await borrar();
      }
    });
  }

  // ------------------------------------------------- bajada desde el servidor

  /// Mezcla en el equipo lo que trajo el servidor (filas con los nombres de
  /// columna de `hab_ent_*`, tal como las entrega PostgREST), con el **último
  /// cambio gana** por `modificado_en`: lo local más nuevo o igual se queda. No
  /// encola nada (ya está en el servidor) y no toca `tiempos`. Devuelve cuántas
  /// filas cambiaron en este equipo.
  Future<int> fusionarDelServidor(
    String persona, {
    List<Map<String, Object?>> perfil = const [],
    List<Map<String, Object?>> planDias = const [],
    List<Map<String, Object?>> inventario = const [],
    List<Map<String, Object?>> bandas = const [],
    List<Map<String, Object?>> sesiones = const [],
    List<Map<String, Object?>> series = const [],
  }) async {
    var cambiadas = 0;
    await _base.transaction(() async {
      final orden = <(String, List<Map<String, Object?>>)>[
        ('hab_ent_perfil', perfil),
        ('hab_ent_plan_dias', planDias),
        ('hab_ent_inventario', inventario),
        ('hab_ent_bandas', bandas),
        ('hab_ent_sesiones', sesiones),
        ('hab_ent_series', series),
      ];
      for (final (tabla, filas) in orden) {
        for (final remota in filas) {
          final fila = _normalizarRemota(tabla, remota);
          if (fila == null) continue;
          final remotoEn = DateTime.parse(fila['modificado_en']! as String);
          final local = await _modificadoLocal(tabla, persona, fila);
          if (local != null && !_aSegundos(remotoEn).isAfter(local)) continue;
          await _escribirLocal(tabla, persona, fila, _aSegundos(remotoEn));
          cambiadas++;
        }
      }
    });
    return cambiadas;
  }

  /// Convierte una fila de PostgREST a la forma local; `null` si no sirve.
  Map<String, Object?>? _normalizarRemota(
    String tabla,
    Map<String, Object?> r,
  ) {
    final permitidas = columnasQueSeMandanGimnasio[tabla]!;
    final fila = {
      for (final e in r.entries)
        if (permitidas.contains(e.key)) e.key: e.value,
    };
    for (final c in const ['inicio', 'fin', 'aviso_visto_en', 'modificado_en']) {
      if (fila.containsKey(c)) fila[c] = _aIsoUtc(fila[c]);
    }
    for (final c in const ['noche_desde', 'hora']) {
      if (fila[c] != null) fila[c] = _hhmm(fila[c]);
    }
    if (fila['modificado_en'] == null) return null;
    try {
      validarFilaGimnasio(tabla, fila);
    } on FilaGimnasioInvalida {
      return null; // una fila ajena que no cumple las reglas: se omite
    }
    return fila;
  }

  // ------------------------------------------------------------------ interno

  Future<T> _transaccion<T>(Future<T> Function() accion) =>
      _base.transaction(accion);

  /// Valida, guarda en lo local y encola, en una sola transacción. Devuelve el
  /// `id` de la fila (o la clave) para quien lo necesite.
  Future<String> _guardar({
    required String tabla,
    required String persona,
    required Map<String, Object?> fila,
    required String tipo,
    required String clave,
    DateTime? anterior,
    Map<String, Object?>? tiempos,
  }) async {
    final ahora = _aSegundos(_reloj());
    // Nunca retrocede para esa fila (si el reloj del equipo se atrasó).
    final sello = anterior != null && anterior.isAfter(ahora) ? anterior : ahora;
    final completa = {...fila, 'modificado_en': sello.toUtc().toIso8601String()};
    validarFilaGimnasio(tabla, completa);
    await _transaccion(() async {
      await _escribirLocal(tabla, persona, completa, sello, tiempos: tiempos);
      await _encolar(persona, tipo, clave, completa, sello);
    });
    return (completa['id'] as String?) ?? clave;
  }

  Future<void> _encolar(
    String persona,
    String tipo,
    String clave,
    Map<String, Object?> carga,
    DateTime sello,
  ) async {
    final cola = _cola;
    if (cola == null) return;
    // Sin columnas que ponga el servidor ni lo solo local.
    final limpia = {
      for (final e in carga.entries)
        if (columnasQueSeMandanGimnasio[destinosUpsertGimnasio[tipo]!.tabla]!
            .contains(e.key))
          e.key: e.value,
    };
    // Mismo cambio, misma entrada (idempotente); otro cambio de la misma fila,
    // otra entrada: el servidor se queda con el `modificado_en` más reciente.
    final huella = sha1.convert(utf8.encode(jsonEncode(limpia))).toString();
    await cola.encolar(
      tipo: tipo,
      id: uuidV5(
        espacioIdsGimnasio,
        'cola|$tipo|$persona|$clave|${sello.millisecondsSinceEpoch}|$huella',
      ),
      carga: limpia,
      personaId: persona,
    );
  }

  Future<void> _encolarBorrado(String persona, String tipo, String id) async {
    final cola = _cola;
    if (cola == null) return;
    await cola.encolar(
      tipo: tipo,
      id: uuidV5(
        espacioIdsGimnasio,
        'cola|$tipo|$persona|$id|${_reloj().microsecondsSinceEpoch}',
      ),
      carga: {'id': id},
      personaId: persona,
    );
  }

  /// `modificado_en` de la fila local equivalente, o `null` si no existe.
  Future<DateTime?> _modificadoLocal(
    String tabla,
    String persona,
    Map<String, Object?> f,
  ) async => switch (tabla) {
    'hab_ent_perfil' =>
      (await perfil(persona))?.modificadoEn,
    'hab_ent_plan_dias' =>
      (await (_base.select(_base.gimPlanDias)..where(
            (t) =>
                t.personaId.equals(persona) &
                t.diaSemana.equals(f['dia_semana']! as int),
          ))
              .getSingleOrNull())
          ?.modificadoEn,
    'hab_ent_inventario' =>
      (await (_base.select(_base.gimInventario)..where(
            (t) =>
                t.personaId.equals(persona) &
                t.itemId.equals(f['item_id']! as String),
          ))
              .getSingleOrNull())
          ?.modificadoEn,
    'hab_ent_bandas' =>
      (await (_base.select(_base.gimBandas)..where(
            (t) =>
                t.personaId.equals(persona) & t.id.equals(f['id']! as String),
          ))
              .getSingleOrNull())
          ?.modificadoEn,
    'hab_ent_sesiones' => (await sesion(persona, f['id']! as String))?.modificadoEn,
    'hab_ent_series' =>
      (await (_base.select(_base.gimSeries)..where(
            (t) =>
                t.personaId.equals(persona) & t.id.equals(f['id']! as String),
          ))
              .getSingleOrNull())
          ?.modificadoEn,
    _ => null,
  };

  /// Escribe la fila (ya validada) en la tabla local. [tiempos]: solo para las
  /// sesiones; `null` deja lo que había.
  Future<void> _escribirLocal(
    String tabla,
    String persona,
    Map<String, Object?> f,
    DateTime sello, {
    Map<String, Object?>? tiempos,
  }) async {
    DateTime? instante(Object? v) =>
        v == null ? null : DateTime.parse(v as String).toUtc();
    switch (tabla) {
      case 'hab_ent_perfil':
        await _base.into(_base.gimPerfil).insertOnConflictUpdate(
          GimPerfilCompanion(
            personaId: Value(persona),
            diasPlan: Value(f['dias_plan']! as int),
            versionPref: Value(f['version_pref']! as String),
            ventana: Value(f['ventana']! as String),
            nocheDesde: Value(f['noche_desde']! as String),
            objetivo: Value(f['objetivo']! as String),
            nivel: Value(f['nivel']! as String),
            inicioCiclo: Value(f['inicio_ciclo'] as String?),
            cicloSemanas: Value(f['ciclo_semanas']! as int),
            descansoS: Value(f['descanso_s'] as int?),
            margenDormirMin: Value(f['margen_dormir_min']! as int),
            pruebaDesde: Value(f['prueba_desde'] as String?),
            pruebaVentana: Value(f['prueba_ventana'] as String?),
            vozDescanso: Value(f['voz_descanso']! as bool),
            avisoVistoEn: Value(instante(f['aviso_visto_en'])),
            modificadoEn: Value(sello),
          ),
        );
      case 'hab_ent_plan_dias':
        await _base.into(_base.gimPlanDias).insertOnConflictUpdate(
          GimPlanDiasCompanion(
            personaId: Value(persona),
            diaSemana: Value(f['dia_semana']! as int),
            tipo: Value(f['tipo']! as String),
            version: Value(f['version']! as String),
            hora: Value(f['hora'] as String?),
            modificadoEn: Value(sello),
          ),
        );
      case 'hab_ent_inventario':
        await _base.into(_base.gimInventario).insertOnConflictUpdate(
          GimInventarioCompanion(
            personaId: Value(persona),
            itemId: Value(f['item_id']! as String),
            estado: Value(f['estado']! as String),
            confirmado: Value(jsonEncode(f['confirmado'])),
            notas: Value(f['notas'] as String?),
            modificadoEn: Value(sello),
          ),
        );
      case 'hab_ent_bandas':
        await _base.into(_base.gimBandas).insertOnConflictUpdate(
          GimBandasCompanion(
            id: Value(f['id']! as String),
            personaId: Value(persona),
            nombre: Value(f['nombre']! as String),
            orden: Value(f['orden']! as int),
            resistenciaKgX10: Value(f['resistencia_kg_x10'] as int?),
            cantidad: Value(f['cantidad']! as int),
            activa: Value(f['activa']! as bool),
            modificadoEn: Value(sello),
          ),
        );
      case 'hab_ent_sesiones':
        await _base.into(_base.gimSesiones).insertOnConflictUpdate(
          GimSesionesCompanion(
            id: Value(f['id']! as String),
            personaId: Value(persona),
            fecha: Value(f['fecha']! as String),
            plantilla: Value(f['plantilla']! as String),
            version: Value(f['version']! as String),
            semanaTipo: Value(f['semana_tipo']! as String),
            ventana: Value(f['ventana']! as String),
            bloqueId: Value(f['bloque_id'] as String?),
            inicio: Value(instante(f['inicio'])!),
            fin: Value(instante(f['fin'])),
            estado: Value(f['estado']! as String),
            esfuerzo: Value(f['esfuerzo'] as int?),
            energia: Value(f['energia'] as int?),
            plan: Value(jsonEncode(f['plan'])),
            catalogoVersion: Value(f['catalogo_version']! as int),
            // Solo local: si no se da, queda lo que había.
            tiempos: tiempos == null
                ? const Value.absent()
                : Value(jsonEncode(tiempos)),
            modificadoEn: Value(sello),
          ),
        );
      case 'hab_ent_series':
        await _base.into(_base.gimSeries).insertOnConflictUpdate(
          GimSeriesCompanion(
            id: Value(f['id']! as String),
            personaId: Value(persona),
            sesionId: Value(f['sesion_id']! as String),
            ejercicioId: Value(f['ejercicio_id']! as String),
            varianteId: Value(f['variante_id']! as String),
            n: Value(f['n']! as int),
            lado: Value(f['lado'] as String?),
            reps: Value(f['reps'] as int?),
            segundos: Value(f['segundos'] as int?),
            cargaPasos: Value(f['carga_pasos'] as int?),
            bandaId: Value(f['banda_id'] as String?),
            esfuerzo: Value(f['esfuerzo'] as int?),
            descansoRealS: Value(f['descanso_real_s'] as int?),
            sustituyeA: Value(f['sustituye_a'] as String?),
            motivoCambio: Value(f['motivo_cambio'] as String?),
            modificadoEn: Value(sello),
          ),
        );
      default:
        throw FilaGimnasioInvalida(tabla, 'tabla');
    }
  }
}
