/// Repositorio de Cuidados con Supabase (D7), con el mismo patrón que
/// Finanzas: una [FuenteTablas] (la de Finanzas, no un cliente nuevo) con el
/// cliente de la persona activa. Las reglas por rol (RLS) filtran en el
/// servidor; aquí solo se arman y leen las filas.
///
/// Usa los nombres reales del servidor (migraciones `20261113` a `20261116`,
/// contrato en la cabecera de `20261114000000_cuidados_esquema.sql`).
///
/// Lectura (select a la tabla):
/// - `cui_turnos`: id, persona_id, dia_semana (1 = lunes), inicio_min,
///   fin_min, tipo (`cuidadora`|`dueno`|`hermana_visita`). Es un horario
///   **semanal**: aquí se expande a los días pedidos.
/// - `cui_medicamentos`: id, nombre, dosis, horas (text[] `HH:MM`), notas,
///   activo.
/// - `cui_tomas`: id, medicamento_id, programada_para, estado
///   (`pendiente`|`dado`|`no_dado`), marcada_por, marcada_en.
/// - `cui_comidas`: id, fecha, tiempo, resultado, registrada_por,
///   registrada_en. Solo agregar.
/// - `cui_bitacora`: id, persona_id, nota, creada_en. Solo agregar.
/// - `cui_entregas`: id, de_persona, para_persona, nota, creada_en.
/// - `cui_cambios_urgentes`: id, de_persona, para_persona, texto, creado_en,
///   atendido_en, atendido_por.
/// - `cui_gastos`: id, persona_id, monto_centavos, concepto, fecha, estado
///   (`pendiente_confirmacion`|`confirmado`|`rechazado`), ambito
///   (`cuidado`|`casa`), registrado_en.
/// - `cui_autorizacion_resumen` (persona_id, vigente) y `cui_consentimientos`.
///
/// Escritura directa (insert, solo las columnas con permiso; **no** se manda
/// persona_id, registrada_por, de_persona, estado ni *_en: los pone el
/// servidor): `cui_turnos` y `cui_medicamentos` (solo el dueño), `cui_comidas`
/// (id, hogar_id, fecha, tiempo, resultado), `cui_bitacora` (id, hogar_id,
/// nota), `cui_entregas` (id, hogar_id, para_persona, nota) y `cui_gastos`
/// (id, hogar_id, monto_centavos, concepto, fecha, ambito).
///
/// Por RPC: `cui_marcar_toma`, `cui_crear_cambio_urgente`,
/// `cui_atender_cambio_urgente`, `cui_confirmar_gasto`,
/// `cui_cambiar_consentimiento`, `cui_autorizar_resumen`,
/// `cui_generar_tomas`, `cui_posponer_toma`. Lecturas por RPC: `cui_perfil`, `cui_puede`,
/// `cui_resumen_mensual`, `cui_resumen_papa`.
///
/// Las citas viven en `cui_citas` (id, programada_en, lugar, nota; solo
/// agregar; el servidor pone `persona_id` y `creada_en`). Las notas viejas con
/// prefijo `[cita ` no se migran: se siguen mostrando como nota. Los nombres
/// salen de `personas` cuando la sesión puede leerlos (el dueño); si no, se
/// usa la función del turno.
library;

import '../../../nucleo/cuidados/posponer_toma.dart' show rpcPosponerToma;
import '../../finanzas/datos/fuente_tablas.dart';
import '../../finanzas/datos/repositorio.dart' show ErrorFinanzas;
import 'modelos.dart';
import 'repositorio.dart';

DateTime _fecha(Object? v) => DateTime.parse(v! as String).toLocal();
DateTime? _fechaOpc(Object? v) => v == null ? null : _fecha(v);

T _enumPor<T extends Enum>(
  List<T> valores,
  Object? v,
  T porOmision, [
  String Function(T)? clave,
]) {
  final k = clave ?? (T e) => e.name;
  for (final e in valores) {
    if (k(e) == v) return e;
  }
  return porOmision;
}

String _snake(Enum e) =>
    e.name.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');

class RepositorioCuidadosSupabase implements RepositorioCuidados {
  RepositorioCuidadosSupabase({
    required this.fuente,
    required this.hogarId,
    required this.personaId,
    this.nombre = '',
  });

  final FuenteTablas fuente;
  final String hogarId;
  final String personaId;

  /// Nombre de quien usa la app (para mostrar lo suyo).
  final String nombre;

  Map<String, String>? _nombres;
  String? _perfil;

  /// El servidor responde con [ErrorFinanzas]; aquí se vuelve [ErrorCuidados].
  Future<T> _seg<T>(Future<T> Function() accion) async {
    try {
      return await accion();
    } on ErrorFinanzas catch (e) {
      if (e.sinConexion) throw ErrorCuidados.conexion;
      if (e.mensaje.startsWith('No tienes permiso')) {
        throw ErrorCuidados.sinPermiso;
      }
      throw ErrorCuidados(e.mensaje);
    }
  }

  Future<List<Map<String, dynamic>>> _leer(String tabla) =>
      _seg(() => fuente.leer(tabla));

  Future<void> _insertar(String tabla, Map<String, Object?> fila) =>
      _seg(() => fuente.guardar(tabla, [fila], ignorarDuplicados: true));

  Future<Object?> _rpc(String funcion, Map<String, Object?> parametros) =>
      _seg(() => fuente.rpc(funcion, parametros));

  /// Nombres de las personas que la sesión puede leer. Si no puede (la
  /// cuidadora y la hermana no leen `personas` ajenas), queda vacío.
  Future<Map<String, String>> _mapaNombres() async {
    final previo = _nombres;
    if (previo != null) return previo;
    final m = <String, String>{if (nombre.isNotEmpty) personaId: nombre};
    try {
      for (final f in await fuente.leer(
        'personas',
        columnas: 'id, nombre_visible',
      )) {
        final n = f['nombre_visible'];
        if (n is String && n.isNotEmpty) m['${f['id']}'] = n;
      }
    } catch (_) {
      // Sin permiso o sin señal: se usan nombres genéricos.
    }
    return _nombres = m;
  }

  String _quien(Map<String, String> nombres, Object? id, [String vacio = '']) =>
      id == null ? vacio : (nombres['$id'] ?? vacio);

  // ---------------------------------------------------------------- Perfil

  Future<String?> _perfilServidor() async {
    final v = await _rpc('cui_perfil', {'p_hogar_id': hogarId});
    return _perfil = v is String ? v : null;
  }

  @override
  Future<PerfilCuidados> perfil() async {
    final valor = await _perfilServidor();
    var autorizado = false;
    if (valor == 'hermana') {
      final aut = await _leer('cui_autorizacion_resumen');
      autorizado = aut.any(
        (f) => f['persona_id'] == personaId && f['vigente'] == true,
      );
    }
    return PerfilCuidados.servidor(
      valor,
      resumenAutorizado: autorizado,
      esAlbacea: valor != null && await _esAlbacea(),
    );
  }

  /// El servidor no expone `cui_es_albacea`; quien lo es lee su propia fila
  /// de `fin_libro_miembros` (papel `albacea`, sin `hasta`). Solo oculta o
  /// muestra: `cui_autorizar_resumen` lo vuelve a exigir.
  Future<bool> _esAlbacea() async {
    try {
      final filas = await _leer('fin_libro_miembros');
      return filas.any(
        (f) =>
            f['persona_id'] == personaId &&
            f['papel'] == 'albacea' &&
            f['hasta'] == null,
      );
    } catch (_) {
      return false;
    }
  }

  @override
  Future<EstadoConsentimientos> estadoConsentimientos() async {
    final nombres = await _mapaNombres();
    String? parejaId, hermanaId;
    if (_perfil?.startsWith('pareja') ?? false) parejaId = personaId;
    try {
      for (final f in await _leer('membresias')) {
        if (f['activa'] == false) continue;
        if (f['rol'] == 'coadministrador') {
          parejaId ??= f['persona_id'] as String?;
        }
      }
    } catch (_) {}
    try {
      for (final f in await _leer('cui_turnos')) {
        if (f['tipo'] == 'hermana_visita') {
          hermanaId ??= f['persona_id'] as String?;
        }
      }
    } catch (_) {}
    var parejaOk = false, hermanaOk = false;
    try {
      for (final f in await _leer('cui_consentimientos')) {
        if (f['persona_id'] == parejaId) parejaOk = f['concedido'] == true;
      }
    } catch (_) {}
    try {
      for (final f in await _leer('cui_autorizacion_resumen')) {
        if (f['persona_id'] == hermanaId) hermanaOk = f['vigente'] == true;
      }
    } catch (_) {}
    return EstadoConsentimientos(
      parejaId: parejaId,
      parejaNombre: _quien(nombres, parejaId, 'Pareja'),
      parejaConcedido: parejaOk,
      hermanaId: hermanaId,
      hermanaNombre: _quien(nombres, hermanaId, 'Hermana'),
      hermanaAutorizada: hermanaOk,
    );
  }

  @override
  Future<bool> puede(String objeto, String accion) async {
    final v = await _rpc('cui_puede', {
      'p_hogar_id': hogarId,
      'p_objeto': objeto,
      'p_accion': accion,
    });
    return v == true;
  }

  // ---------------------------------------------------------------- Turnos

  @override
  Future<List<Turno>> turnos(DateTime desde, DateTime hasta) async {
    final filas = await _leer('cui_turnos');
    final nombres = await _mapaNombres();
    final salida = <Turno>[];
    for (
      var d = soloFecha(desde);
      d.isBefore(hasta);
      d = DateTime(d.year, d.month, d.day + 1)
    ) {
      for (final f in filas) {
        if ((f['dia_semana'] as num).toInt() != d.weekday) continue;
        final ini = (f['inicio_min'] as num).toInt();
        final fin = (f['fin_min'] as num).toInt();
        final inicio = DateTime(d.year, d.month, d.day, ini ~/ 60, ini % 60);
        // fin_min llega a 1440 (medianoche del día siguiente).
        final termina = DateTime(d.year, d.month, d.day, fin ~/ 60, fin % 60);
        if (!inicio.isBefore(hasta) || !termina.isAfter(desde)) continue;
        final funcion = FuncionTurno.deServidor(f['tipo']);
        salida.add(
          Turno(
            id: idEstableCuidados('turno:${f['id']}:${fechaClave(d)}'),
            plantillaId: f['id'] as String,
            personaId: f['persona_id'] as String,
            nombre: _quien(
              nombres,
              f['persona_id'],
              funcion?.etiqueta ?? 'Cuidado',
            ),
            inicio: inicio,
            fin: termina,
            funcion: funcion,
          ),
        );
      }
    }
    return salida..sort((a, b) => a.inicio.compareTo(b.inicio));
  }

  @override
  Future<void> guardarTurno(Turno t) {
    final f = t.funcion;
    if (f == null) {
      throw const ErrorCuidados('Falta indicar el tipo de turno.');
    }
    final fin = t.fin.difference(soloFecha(t.inicio)).inMinutes;
    // Turno semanal: todos los días de la semana que coinciden con éste.
    return _seg(
      () => fuente.guardar('cui_turnos', [
        {
          'id': t.plantillaId ?? t.id,
          'hogar_id': hogarId,
          'persona_id': t.personaId,
          'dia_semana': t.inicio.weekday,
          'inicio_min': t.inicio.hour * 60 + t.inicio.minute,
          'fin_min': fin,
          'tipo': f.valor,
        },
      ]),
    );
  }

  // ---------------------------------------------------------- Medicamentos

  @override
  Future<List<Medicamento>> medicamentos() async {
    final filas = await _leer('cui_medicamentos');
    return [
      for (final f in filas)
        Medicamento(
          id: f['id'] as String,
          nombre: f['nombre'] as String,
          dosis: (f['dosis'] as String?) ?? '',
          horas: [for (final h in (f['horas'] as List? ?? const [])) '$h'],
          activo: f['activo'] != false,
          notas: (f['notas'] as String?) ?? '',
        ),
    ];
  }

  @override
  Future<void> guardarMedicamento(Medicamento m) => _seg(
    () => fuente.guardar('cui_medicamentos', [
      {
        'id': m.id,
        'hogar_id': hogarId,
        'nombre': m.nombre,
        'dosis': m.dosis,
        'horas': m.horas,
        'notas': m.notas.isEmpty ? null : m.notas,
        'activo': m.activo,
      },
    ]),
  );

  // ----------------------------------------------------------------- Tomas

  @override
  Future<List<Toma>> tomas(DateTime dia) async {
    final d = soloFecha(dia);
    // El dueño crea las tomas del día si aún no están (idempotente); para los
    // demás las genera el servidor. Un error aquí no impide leer.
    if (_perfil == null) await _perfilServidor();
    if (_perfil == 'dueno') {
      try {
        await _rpc('cui_generar_tomas', {
          'p_hogar_id': hogarId,
          'p_desde': fechaClave(d),
          'p_dias': 1,
        });
      } on ErrorCuidados {
        // Se sigue con lo que haya.
      }
    }
    final filas = await _leer('cui_tomas');
    final nombres = await _mapaNombres();
    return [
      for (final f in filas)
        if (soloFecha(_fecha(f['programada_para'])) == d)
          Toma(
            id: f['id'] as String,
            medicamentoId: f['medicamento_id'] as String,
            programada: _fecha(f['programada_para']),
            estado: switch (f['estado']) {
              'dado' => EstadoToma.dado,
              'no_dado' => EstadoToma.noDado,
              _ => EstadoToma.pendiente,
            },
            registradaPor: (f['marcada_por'] as String?) ?? '',
            registradaPorNombre: _quien(nombres, f['marcada_por']),
            registradaEn:
                _fechaOpc(f['marcada_en']) ?? _fecha(f['programada_para']),
          ),
    ];
  }

  @override
  Future<void> marcarToma(Toma t) async {
    if (t.estado == EstadoToma.pendiente) {
      throw const ErrorCuidados('Marca la toma como dada o no dada.');
    }
    final filas = await _leer('cui_tomas');
    final minuto = t.programada.millisecondsSinceEpoch ~/ 60000;
    final fila = filas
        .where(
          (f) =>
              f['medicamento_id'] == t.medicamentoId &&
              _fecha(f['programada_para']).millisecondsSinceEpoch ~/ 60000 ==
                  minuto,
        )
        .firstOrNull;
    if (fila == null) {
      throw const ErrorCuidados(
        'La toma aún no está lista. Avisa a quien administra.',
      );
    }
    await _rpc('cui_marcar_toma', {
      'p_toma_id': fila['id'],
      'p_estado': t.estado == EstadoToma.dado ? 'dado' : 'no_dado',
    });
  }

  @override
  Future<void> posponerToma(String tomaId) async {
    await _rpc(rpcPosponerToma, {'p_toma': tomaId});
  }

  @override
  Future<int> generarTomas(DateTime desde, {int dias = 1}) async {
    final r = await _rpc('cui_generar_tomas', {
      'p_hogar_id': hogarId,
      'p_desde': fechaClave(soloFecha(desde)),
      'p_dias': dias,
    });
    return r is num ? r.toInt() : 0;
  }

  // ---------------------------------------------------------------- Comidas

  @override
  Future<List<ComidaRegistro>> comidas(DateTime dia) async {
    final d = soloFecha(dia);
    final filas = await _leer('cui_comidas');
    final nombres = await _mapaNombres();
    return [
      for (final f in filas)
        if (soloFecha(DateTime.parse(f['fecha'] as String)) == d)
          ComidaRegistro(
            id: f['id'] as String,
            fecha: d,
            tiempo: _enumPor(
              TiempoComidaPapa.values,
              f['tiempo'],
              TiempoComidaPapa.comida,
            ),
            resultado: _enumPor(
              ResultadoComida.values,
              f['resultado'],
              ResultadoComida.comio,
              _snake,
            ),
            registradaPor: f['registrada_por'] as String,
            registradaPorNombre: _quien(nombres, f['registrada_por']),
            registradaEn: _fecha(f['registrada_en']),
          ),
    ];
  }

  @override
  Future<void> registrarComida(ComidaRegistro c) => _insertar('cui_comidas', {
    'id': c.id,
    'hogar_id': hogarId,
    'fecha': fechaClave(c.fecha),
    'tiempo': c.tiempo.name,
    'resultado': _snake(c.resultado),
  });

  // --------------------------------------------------------------- Bitácora

  @override
  Future<List<EntradaBitacora>> bitacora() async {
    final filas = await _leer('cui_bitacora');
    final nombres = await _mapaNombres();
    return [for (final f in filas) _entrada(f, nombres)]
      ..sort((a, b) => b.creadaEn.compareTo(a.creadaEn));
  }

  EntradaBitacora _entrada(
    Map<String, dynamic> f,
    Map<String, String> nombres,
  ) {
    final nota = f['nota'] as String;
    return EntradaBitacora(
      id: f['id'] as String,
      tipo: f['tipo'] == 'instruccion'
          ? TipoBitacora.instruccion
          : TipoBitacora.nota,
      texto: nota,
      autorId: f['persona_id'] as String,
      autorNombre: _quien(nombres, f['persona_id']),
      creadaEn: _fecha(f['creada_en']),
    );
  }

  @override
  Future<void> agregarBitacora(EntradaBitacora e) => _insertar('cui_bitacora', {
    'id': e.id,
    'hogar_id': hogarId,
    'nota': e.texto,
  });

  // ------------------------------------------------------------------ Citas

  @override
  Future<List<Cita>> citas() async {
    final filas = await _leer('cui_citas');
    final nombres = await _mapaNombres();
    return [
      for (final f in filas)
        Cita(
          id: f['id'] as String,
          programadaEn: _fecha(f['programada_en']),
          lugar: f['lugar'] as String?,
          nota: f['nota'] as String?,
          autorId: '${f['persona_id']}',
          autorNombre: _quien(nombres, f['persona_id']),
          creadaEn: _fecha(f['creada_en']),
        ),
    ]..sort((a, b) => a.programadaEn.compareTo(b.programadaEn));
  }

  /// Solo `id, hogar_id, programada_en, lugar, nota`: nada de `persona_id` ni
  /// `creada_en` (los pone el servidor; mandarlos da 42501).
  @override
  Future<void> agregarCita(Cita c) => _insertar('cui_citas', {
    'id': c.id,
    'hogar_id': hogarId,
    'programada_en': c.programadaEn.toUtc().toIso8601String(),
    if (c.lugar != null) 'lugar': c.lugar,
    if (c.nota != null) 'nota': c.nota,
  });

  @override
  Future<void> dejarInstruccion(
    String texto, {
    required String autorNombre,
    required DateTime en,
  }) async {
    // La RPC devuelve el id de la fila; el texto no se guarda en la app.
    await _rpc('cui_dejar_instruccion', {
      'p_hogar_id': hogarId,
      'p_texto': texto,
    });
  }

  // --------------------------------------------------------------- Entregas

  @override
  Future<List<Entrega>> entregas() async {
    final filas = await _leer('cui_entregas');
    final nombres = await _mapaNombres();
    return [
      for (final f in filas)
        Entrega(
          id: f['id'] as String,
          dePersonaId: f['de_persona'] as String,
          deNombre: _quien(nombres, f['de_persona']),
          notas: f['nota'] as String,
          creadaEn: _fecha(f['creada_en']),
          paraPersonaId: f['para_persona'] as String?,
        ),
    ]..sort((a, b) => b.creadaEn.compareTo(a.creadaEn));
  }

  @override
  Future<void> dejarEntrega(Entrega e) {
    final para = e.paraPersonaId;
    if (para == null) {
      throw const ErrorCuidados('Falta indicar para quién es la nota.');
    }
    return _insertar('cui_entregas', {
      'id': e.id,
      'hogar_id': hogarId,
      'para_persona': para,
      'nota': e.notas,
    });
  }

  // ------------------------------------------------------- Cambios urgentes

  @override
  Future<List<CambioUrgente>> cambiosUrgentes() async {
    final filas = await _leer('cui_cambios_urgentes');
    final nombres = await _mapaNombres();
    return [
      for (final f in filas)
        CambioUrgente(
          id: f['id'] as String,
          texto: f['texto'] as String,
          creadoPor: f['de_persona'] as String,
          creadoEn: _fecha(f['creado_en']),
          paraPersonaId: f['para_persona'] as String?,
          // `atendido_por` lo pone el servidor (solo lectura); sin nombre
          // visible la pantalla dice solo "Atendido".
          atendidoPor: f['atendido_por'] as String?,
          atendidoNombre: f['atendido_por'] == null
              ? null
              : _quien(nombres, f['atendido_por']),
          atendidoEn: _fechaOpc(f['atendido_en']),
        ),
    ]..sort((a, b) => b.creadoEn.compareTo(a.creadoEn));
  }

  /// Solo el dueño. El servidor crea el cambio y avisa **al instante** a quien
  /// está de turno (plataforma, D4); idempotente por [CambioUrgente.id].
  @override
  Future<void> crearCambioUrgente(CambioUrgente c) async {
    await _rpc('cui_crear_cambio_urgente', {
      'p_hogar_id': hogarId,
      'p_texto': c.texto,
      'p_id': c.id,
    });
  }

  @override
  Future<void> atenderCambioUrgente(
    String id, {
    required String personaId,
    required String nombre,
    required DateTime en,
  }) async {
    await _rpc('cui_atender_cambio_urgente', {'p_id': id});
  }

  // ----------------------------------------------------------------- Gastos

  @override
  Future<List<GastoCuidado>> gastos() async {
    final filas = await _leer('cui_gastos');
    final nombres = await _mapaNombres();
    return [
      for (final f in filas)
        GastoCuidado(
          id: f['id'] as String,
          concepto: f['concepto'] as String,
          centavos: (f['monto_centavos'] as num).toInt(),
          fecha: DateTime.parse(f['fecha'] as String),
          registradoPor: f['persona_id'] as String,
          registradoNombre: _quien(nombres, f['persona_id']),
          estado: _enumPor(
            EstadoGasto.values,
            f['estado'],
            EstadoGasto.pendiente,
            (e) => e.valor,
          ),
          ambito: _enumPor(
            AmbitoGasto.values,
            f['ambito'],
            AmbitoGasto.cuidado,
            (e) => e.valor,
          ),
          registradoEn: _fechaOpc(f['registrado_en']),
        ),
    ]..sort((a, b) => b.fecha.compareTo(a.fecha));
  }

  /// El servidor lo deja siempre `pendiente_confirmacion`, a nombre de quien
  /// lo registra.
  @override
  Future<void> registrarGasto(GastoCuidado g) => _insertar('cui_gastos', {
    'id': g.id,
    'hogar_id': hogarId,
    'monto_centavos': g.centavos,
    'concepto': g.concepto,
    'fecha': fechaClave(g.fecha),
    'ambito': g.ambito.valor,
  });

  @override
  Future<void> resolverGasto(String id, EstadoGasto estado) async {
    if (estado == EstadoGasto.pendiente) {
      throw const ErrorCuidados('Indica si se confirma o se rechaza.');
    }
    await _rpc('cui_confirmar_gasto', {
      'p_gasto_id': id,
      'p_confirmar': estado == EstadoGasto.confirmado,
    });
  }

  // ------------------------------------------------ Consentimiento y resumen

  @override
  Future<void> cambiarConsentimiento(String persona, bool concedido) async {
    await _rpc('cui_cambiar_consentimiento', {
      'p_hogar_id': hogarId,
      'p_persona_id': persona,
      'p_concedido': concedido,
    });
  }

  @override
  Future<void> autorizarResumen(String persona, bool vigente) async {
    await _rpc('cui_autorizar_resumen', {
      'p_hogar_id': hogarId,
      'p_persona_id': persona,
      'p_vigente': vigente,
    });
  }

  @override
  Future<ResumenMensual?> resumenMensual(DateTime mes) async {
    final m = DateTime(mes.year, mes.month);
    final Object? r;
    try {
      r = await _rpc('cui_resumen_mensual', {'p_mes': fechaClave(m)});
    } on ErrorCuidados catch (e) {
      // 42501: sin acceso al resumen (no es dueño ni hermana autorizada).
      if (identical(e, ErrorCuidados.sinPermiso)) return null;
      rethrow;
    }
    // Un renglón por hogar.
    final filas = r is List ? r : (r is Map ? [r] : const []);
    final fila =
        filas
            .whereType<Map>()
            .where((f) => f['hogar_id'] == hogarId)
            .firstOrNull ??
        filas.whereType<Map>().firstOrNull;
    if (fila == null) return null;
    return ResumenMensual(
      mes: m,
      gastosCuidadoCentavos: (fila['gastos_cuidado_centavos'] as num).toInt(),
      gastosCasaCentavos: (fila['gastos_casa_centavos'] as num).toInt(),
      nGastos: (fila['n_gastos'] as num).toInt(),
    );
  }

  @override
  Future<ResumenPapa?> resumenPapa(DateTime dia) async {
    final d = soloFecha(dia);
    final Object? r;
    try {
      r = await _rpc('cui_resumen_papa', {
        'p_hogar_id': hogarId,
        'p_dia': fechaClave(d),
      });
    } on ErrorCuidados catch (e) {
      if (identical(e, ErrorCuidados.sinPermiso)) return null;
      rethrow;
    }
    final fila = (r is List ? r.firstOrNull : r);
    if (fila is! Map) return null;
    int n(String k) => (fila[k] as num? ?? 0).toInt();
    return ResumenPapa(
      dia: d,
      tomasTotal: n('tomas_total'),
      tomasDadas: n('tomas_dadas'),
      tomasNoDadas: n('tomas_no_dadas'),
      tomasPendientes: n('tomas_pendientes'),
      comidasRegistradas: n('comidas_registradas'),
      comidasConRechazo: n('comidas_con_rechazo'),
    );
  }
}
