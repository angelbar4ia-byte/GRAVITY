/// Repositorio de Cuidados con Supabase (D7), con el mismo patrón que
/// Finanzas: una [FuenteTablas] (la de Finanzas, no un cliente nuevo) con el
/// cliente de la persona activa. Las reglas por rol (RLS) filtran en el
/// servidor; aquí solo se arman y leen las filas.
///
/// Columnas que usa la app (contrato propuesto a backend; si difieren, solo
/// cambia este archivo):
/// - `cui_turnos`: id, hogar_id, persona_id, persona_nombre, tipo
///   (`turno`|`visita`), inicio, fin.
/// - `cui_medicamentos`: id, hogar_id, nombre, dosis, horas (text[] `HH:mm`),
///   activo.
/// - `cui_tomas`: id, hogar_id, medicamento_id, programada_en, estado
///   (`dado`|`no_dado`), registrada_por, registrada_nombre, registrada_en.
/// - `cui_comidas`: id, hogar_id, fecha, tiempo, resultado
///   (`comio`|`comio_poco`|`rechazo`), registrada_por, registrada_nombre,
///   registrada_en.
/// - `cui_bitacora`: id, hogar_id, tipo (`nota`|`cita`), texto, autor_id,
///   autor_nombre, creada_en, programada_en.
/// - `cui_entregas`: id, hogar_id, de_persona_id, de_nombre, notas, creada_en.
/// - `cui_cambios_urgentes`: id, hogar_id, accion (`suspender`|`agregar`),
///   medicamento_id, medicamento_nombre, nota, creado_por, creado_en,
///   atendido_por, atendido_nombre, atendido_en.
/// - `cui_gastos`: id, hogar_id, concepto, centavos, fecha, registrado_por,
///   registrado_nombre, estado (`pendiente`|`confirmado`|`rechazado`),
///   titular (`papa`|`casa`|`pareja`|`dueno`).
/// - `cui_autorizacion_resumen`: persona_id, autorizado. La hermana tiene una
///   fila; el albacea la cambia.
/// - `cui_consentimientos`: persona_id, vigente. La pareja, si lo dio.
/// - RPC `cui_resumen_mensual(p_mes date)` → `{lineas:[{concepto, centavos,
///   titular}]}`, o nulo si no hay permiso o autorización.
library;

import '../../finanzas/datos/fuente_tablas.dart';
import 'modelos.dart';
import 'repositorio.dart';

DateTime _fecha(Object? v) => DateTime.parse(v! as String).toLocal();
DateTime? _fechaOpc(Object? v) => v == null ? null : _fecha(v);
String _iso(DateTime d) => d.toUtc().toIso8601String();

T _enumPor<T extends Enum>(List<T> valores, Object? v, T porOmision, [String Function(T)? clave]) {
  final k = clave ?? (T e) => e.name;
  for (final e in valores) {
    if (k(e) == v) return e;
  }
  return porOmision;
}

String _snake(Enum e) => e.name.replaceAllMapped(
  RegExp('[A-Z]'),
  (m) => '_${m[0]!.toLowerCase()}',
);

class RepositorioCuidadosSupabase implements RepositorioCuidados {
  RepositorioCuidadosSupabase({
    required this.fuente,
    required this.hogarId,
    required this.personaId,
  });

  final FuenteTablas fuente;
  final String hogarId;
  final String personaId;

  @override
  Future<PerfilCuidados> perfil() async {
    final aut = await fuente.leer('cui_autorizacion_resumen');
    final fila = aut.where((f) => f['persona_id'] == personaId).firstOrNull;
    final cons = await fuente.leer('cui_consentimientos');
    final dio = cons.any((f) => f['persona_id'] == personaId && f['vigente'] == true);
    return PerfilCuidados(
      esFamiliar: fila != null,
      resumenAutorizado: fila?['autorizado'] == true,
      consentimiento: dio,
    );
  }

  @override
  Future<List<Turno>> turnos(DateTime desde, DateTime hasta) async {
    final filas = await fuente.leer('cui_turnos');
    return [
      for (final f in filas)
        Turno(
          id: f['id'] as String,
          personaId: f['persona_id'] as String,
          nombre: (f['persona_nombre'] as String?) ?? '',
          inicio: _fecha(f['inicio']),
          fin: _fecha(f['fin']),
          tipo: f['tipo'] == 'visita' ? TipoTurno.visita : TipoTurno.turno,
        ),
    ].where((t) => t.inicio.isBefore(hasta) && t.fin.isAfter(desde)).toList()
      ..sort((a, b) => a.inicio.compareTo(b.inicio));
  }

  @override
  Future<void> guardarTurno(Turno t) => fuente.guardar('cui_turnos', [
    {
      'id': t.id,
      'hogar_id': hogarId,
      'persona_id': t.personaId,
      'persona_nombre': t.nombre,
      'tipo': t.tipo.name,
      'inicio': _iso(t.inicio),
      'fin': _iso(t.fin),
    },
  ]);

  @override
  Future<List<Medicamento>> medicamentos() async {
    final filas = await fuente.leer('cui_medicamentos');
    return [
      for (final f in filas)
        Medicamento(
          id: f['id'] as String,
          nombre: f['nombre'] as String,
          dosis: (f['dosis'] as String?) ?? '',
          horas: [for (final h in (f['horas'] as List? ?? const [])) '$h'],
          activo: f['activo'] != false,
        ),
    ];
  }

  @override
  Future<void> guardarMedicamento(Medicamento m) => fuente.guardar(
    'cui_medicamentos',
    [
      {
        'id': m.id,
        'hogar_id': hogarId,
        'nombre': m.nombre,
        'dosis': m.dosis,
        'horas': m.horas,
        'activo': m.activo,
      },
    ],
  );

  @override
  Future<List<Toma>> tomas(DateTime dia) async {
    final d = soloFecha(dia);
    final filas = await fuente.leer('cui_tomas');
    return [
      for (final f in filas)
        if (soloFecha(_fecha(f['programada_en'])) == d)
          Toma(
            id: f['id'] as String,
            medicamentoId: f['medicamento_id'] as String,
            programada: _fecha(f['programada_en']),
            estado: f['estado'] == 'dado' ? EstadoToma.dado : EstadoToma.noDado,
            registradaPor: f['registrada_por'] as String,
            registradaPorNombre: (f['registrada_nombre'] as String?) ?? '',
            registradaEn: _fecha(f['registrada_en']),
          ),
    ];
  }

  @override
  Future<void> registrarToma(Toma t) => fuente.guardar('cui_tomas', [
    {
      'id': t.id,
      'hogar_id': hogarId,
      'medicamento_id': t.medicamentoId,
      'programada_en': _iso(t.programada),
      'estado': t.estado == EstadoToma.dado ? 'dado' : 'no_dado',
      'registrada_por': t.registradaPor,
      'registrada_nombre': t.registradaPorNombre,
      'registrada_en': _iso(t.registradaEn),
    },
  ]);

  @override
  Future<List<ComidaRegistro>> comidas(DateTime dia) async {
    final d = soloFecha(dia);
    final filas = await fuente.leer('cui_comidas');
    return [
      for (final f in filas)
        if (soloFecha(DateTime.parse(f['fecha'] as String)) == d)
          ComidaRegistro(
            id: f['id'] as String,
            fecha: d,
            tiempo: _enumPor(TiempoComidaPapa.values, f['tiempo'], TiempoComidaPapa.comida),
            resultado: _enumPor(ResultadoComida.values, f['resultado'], ResultadoComida.comio, _snake),
            registradaPor: f['registrada_por'] as String,
            registradaPorNombre: (f['registrada_nombre'] as String?) ?? '',
            registradaEn: _fecha(f['registrada_en']),
          ),
    ];
  }

  @override
  Future<void> registrarComida(ComidaRegistro c) => fuente.guardar(
    'cui_comidas',
    [
      {
        'id': c.id,
        'hogar_id': hogarId,
        'fecha': fechaClave(c.fecha),
        'tiempo': c.tiempo.name,
        'resultado': _snake(c.resultado),
        'registrada_por': c.registradaPor,
        'registrada_nombre': c.registradaPorNombre,
        'registrada_en': _iso(c.registradaEn),
      },
    ],
  );

  @override
  Future<List<EntradaBitacora>> bitacora() async {
    final filas = await fuente.leer('cui_bitacora');
    return [
      for (final f in filas)
        EntradaBitacora(
          id: f['id'] as String,
          tipo: f['tipo'] == 'cita' ? TipoBitacora.cita : TipoBitacora.nota,
          texto: f['texto'] as String,
          autorId: f['autor_id'] as String,
          autorNombre: (f['autor_nombre'] as String?) ?? '',
          creadaEn: _fecha(f['creada_en']),
          programadaEn: _fechaOpc(f['programada_en']),
        ),
    ]..sort((a, b) => b.creadaEn.compareTo(a.creadaEn));
  }

  @override
  Future<void> agregarBitacora(EntradaBitacora e) => fuente.guardar(
    'cui_bitacora',
    [
      {
        'id': e.id,
        'hogar_id': hogarId,
        'tipo': e.tipo.name,
        'texto': e.texto,
        'autor_id': e.autorId,
        'autor_nombre': e.autorNombre,
        'creada_en': _iso(e.creadaEn),
        'programada_en': e.programadaEn == null ? null : _iso(e.programadaEn!),
      },
    ],
    ignorarDuplicados: true,
  );

  @override
  Future<List<Entrega>> entregas() async {
    final filas = await fuente.leer('cui_entregas');
    return [
      for (final f in filas)
        Entrega(
          id: f['id'] as String,
          dePersonaId: f['de_persona_id'] as String,
          deNombre: (f['de_nombre'] as String?) ?? '',
          notas: f['notas'] as String,
          creadaEn: _fecha(f['creada_en']),
        ),
    ]..sort((a, b) => b.creadaEn.compareTo(a.creadaEn));
  }

  @override
  Future<void> dejarEntrega(Entrega e) => fuente.guardar('cui_entregas', [
    {
      'id': e.id,
      'hogar_id': hogarId,
      'de_persona_id': e.dePersonaId,
      'de_nombre': e.deNombre,
      'notas': e.notas,
      'creada_en': _iso(e.creadaEn),
    },
  ], ignorarDuplicados: true);

  @override
  Future<List<CambioUrgente>> cambiosUrgentes() async {
    final filas = await fuente.leer('cui_cambios_urgentes');
    return [
      for (final f in filas)
        CambioUrgente(
          id: f['id'] as String,
          accion: f['accion'] == 'agregar' ? AccionCambio.agregar : AccionCambio.suspender,
          nota: (f['nota'] as String?) ?? '',
          creadoPor: f['creado_por'] as String,
          creadoEn: _fecha(f['creado_en']),
          medicamentoId: f['medicamento_id'] as String?,
          medicamentoNombre: f['medicamento_nombre'] as String?,
          atendidoPor: f['atendido_por'] as String?,
          atendidoNombre: f['atendido_nombre'] as String?,
          atendidoEn: _fechaOpc(f['atendido_en']),
        ),
    ]..sort((a, b) => b.creadoEn.compareTo(a.creadoEn));
  }

  /// El servidor avisa a la cuidadora de turno al insertar (plataforma, D4).
  @override
  Future<void> crearCambioUrgente(CambioUrgente c) => fuente.guardar(
    'cui_cambios_urgentes',
    [
      {
        'id': c.id,
        'hogar_id': hogarId,
        'accion': c.accion.name,
        'medicamento_id': c.medicamentoId,
        'medicamento_nombre': c.medicamentoNombre,
        'nota': c.nota,
        'creado_por': c.creadoPor,
        'creado_en': _iso(c.creadoEn),
      },
    ],
    ignorarDuplicados: true,
  );

  @override
  Future<void> atenderCambioUrgente(
    String id, {
    required String personaId,
    required String nombre,
    required DateTime en,
  }) => fuente.actualizar(
    'cui_cambios_urgentes',
    {'atendido_por': personaId, 'atendido_nombre': nombre, 'atendido_en': _iso(en)},
    donde: {'id': id, 'atendido_en': null},
  );

  @override
  Future<List<GastoCuidado>> gastos() async {
    final filas = await fuente.leer('cui_gastos');
    return [
      for (final f in filas)
        GastoCuidado(
          id: f['id'] as String,
          concepto: f['concepto'] as String,
          centavos: (f['centavos'] as num).toInt(),
          fecha: DateTime.parse(f['fecha'] as String),
          registradoPor: f['registrado_por'] as String,
          registradoNombre: (f['registrado_nombre'] as String?) ?? '',
          estado: _enumPor(EstadoGasto.values, f['estado'], EstadoGasto.pendiente),
          titular: _enumPor(Titular.values, f['titular'], Titular.papa),
        ),
    ]..sort((a, b) => b.fecha.compareTo(a.fecha));
  }

  @override
  Future<void> registrarGasto(GastoCuidado g) => fuente.guardar(
    'cui_gastos',
    [
      {
        'id': g.id,
        'hogar_id': hogarId,
        'concepto': g.concepto,
        'centavos': g.centavos,
        'fecha': fechaClave(g.fecha),
        'registrado_por': g.registradoPor,
        'registrado_nombre': g.registradoNombre,
        // Siempre pendiente: solo el dueño confirma (el servidor lo exige).
        'estado': 'pendiente',
        'titular': g.titular.name,
      },
    ],
    ignorarDuplicados: true,
  );

  @override
  Future<void> resolverGasto(String id, EstadoGasto estado) =>
      fuente.actualizar('cui_gastos', {'estado': estado.name}, donde: {'id': id});

  @override
  Future<ResumenMensual?> resumenMensual(DateTime mes) async {
    final m = DateTime(mes.year, mes.month);
    final r = await fuente.rpc('cui_resumen_mensual', {'p_mes': fechaClave(m)});
    if (r is! Map) return null;
    return ResumenMensual(
      mes: m,
      lineas: [
        for (final l in (r['lineas'] as List? ?? const []))
          LineaResumen(
            concepto: (l as Map)['concepto'] as String,
            centavos: (l['centavos'] as num).toInt(),
            titular: _enumPor(Titular.values, l['titular'], Titular.papa),
          ),
      ],
    );
  }
}
