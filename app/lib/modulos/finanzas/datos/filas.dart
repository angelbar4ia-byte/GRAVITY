/// Conversión entre los modelos de `finanzas_dominio` y las filas de las
/// tablas `fin_*` de Supabase (especificación de la Fase 1, secciones 4.1 y
/// 4.5). Los enums viajan en `snake_case` (`pagoDeuda` ↔ `pago_deuda`), las
/// fechas como `AAAA-MM-DD`, las horas en ISO 8601 (UTC) y el dinero en
/// centavos.
///
/// Contrato con el servidor (`supabase/README.md`, "Contrato para la app"):
/// - Las columnas que pone o genera el servidor no se envían: `clase`,
///   `liquida`, `recibido_en`, `libro_origen_id`, `libro_destino_id`,
///   `diferencia`, `diferido`, `reaperturas`, `activada_por`/`activada_en` y
///   `creada_por`.
/// - `fin_libro_miembros.desde`/`hasta` son `timestamptz` (hora ISO); sin
///   `desde` el servidor pone `now()`.
/// - `fin_cuentas.libro_id` va nulo solo en `de_gasto` y `gasto_financiero`.
/// - `regla_inhabil` siempre se envía con la regla efectiva: la elegida o la
///   de por omisión de su origen (ingreso: siguiente día hábil; compromiso y
///   deuda: en su fecha).
library;

import 'package:finanzas_dominio/finanzas_dominio.dart';

/// Tablas de Finanzas (para comparar con la migración de backend).
abstract final class TablasFinanzas {
  static const libros = 'fin_libros';
  static const miembros = 'fin_libro_miembros';
  static const parametros = 'fin_parametros';
  static const categorias = 'fin_categorias';
  static const cuentas = 'fin_cuentas';
  static const movimientos = 'fin_movimientos';
  static const ingresos = 'fin_ingresos';
  static const vigencias = 'fin_vigencias_ingreso';
  static const compromisos = 'fin_compromisos';
  static const sobres = 'fin_sobres';
  static const deudas = 'fin_deudas';
  static const diasInhabiles = 'fin_dias_inhabiles';
  static const semanas = 'fin_semanas';
  static const partidasSemana = 'fin_partidas_semana';
  static const abonosSemana = 'fin_abonos_semana';
  static const cierres = 'fin_cierres';
  static const cierrePartidas = 'fin_cierre_partidas';
  static const cierreAbonos = 'fin_cierre_abonos';
  static const ocurrencias = 'fin_ocurrencias';
  static const conciliaciones = 'fin_conciliaciones';
  static const importaciones = 'fin_importaciones';

  /// Función que deja en la bitácora la consulta de la cuenta maestra.
  static const consultaMaestra = 'fin_registrar_consulta_maestra';

  /// Función que dice si existe la cuenta maestra y de quién es.
  static const cuentaMaestra = 'cuenta_maestra';

  /// Función que crea el libro de una persona representada (papá).
  static const crearLibroRepresentado = 'fin_crear_libro_representado';
}

// ------------------------------------------------------------------ ayudas

/// `pagoDeuda` → `pago_deuda`.
String aSnake(String camel) => camel.replaceAllMapped(
  RegExp('[A-Z]'),
  (m) => '_${m[0]!.toLowerCase()}',
);

String nombreEnum(Enum valor) => aSnake(valor.name);

/// Lee un enum guardado en `snake_case`. Lanza [FormatException] si no existe.
T enumDe<T extends Enum>(List<T> valores, Object? texto) {
  for (final v in valores) {
    if (nombreEnum(v) == texto || v.name == texto) return v;
  }
  throw FormatException('Valor desconocido: $texto (${T.toString()})');
}

T? enumONulo<T extends Enum>(List<T> valores, Object? texto) =>
    texto == null ? null : enumDe(valores, texto);

String fechaIso(Fecha f) => f.toString();

Fecha? fechaDe(Object? v) {
  if (v == null) return null;
  final texto = '$v';
  return Fecha.parse(texto.length > 10 ? texto.substring(0, 10) : texto);
}

Fecha fechaReq(Object? v) =>
    fechaDe(v) ?? (throw const FormatException('Falta una fecha'));

String horaIso(DateTime t) => t.toUtc().toIso8601String();

DateTime? horaDe(Object? v) =>
    v == null ? null : DateTime.parse('$v').toLocal();

int entero(Object? v, [int porOmision = 0]) => switch (v) {
  null => porOmision,
  final int n => n,
  final num n => n.toInt(),
  final String s => int.parse(s),
  _ => throw FormatException('No es un número: $v'),
};

int? enteroONulo(Object? v) => v == null ? null : entero(v);

bool booleano(Object? v, [bool porOmision = false]) => switch (v) {
  null => porOmision,
  final bool b => b,
  final String s => s == 'true' || s == 't',
  _ => porOmision,
};

String? texto(Object? v) => v == null ? null : '$v';

List<int> enteros(Object? v) => switch (v) {
  null => const [],
  final List<Object?> l => [for (final x in l) entero(x)],
  // PostgREST puede devolver un arreglo de Postgres como texto: {1,11}.
  final String s => [
    for (final p in s.replaceAll(RegExp(r'[{}\[\]\s]'), '').split(','))
      if (p.isNotEmpty) int.parse(p),
  ],
  _ => const [],
};

// ------------------------------------------------------------------ libros

Map<String, Object?> filaLibro(Libro l, {required String hogarId}) => {
  'id': l.id,
  'hogar_id': hogarId,
  'nombre': l.nombre,
  'tipo': nombreEnum(l.tipo),
  'titular_id': l.titularId,
  'activo': l.activo,
};

/// Inicio del día [f] en la hora local, como `timestamptz` ISO (UTC).
String horaDeFecha(Fecha f) => horaIso(DateTime(f.anio, f.mes, f.dia));

/// Fecha local de un `timestamptz` (o de una fecha `AAAA-MM-DD`).
Fecha? fechaDeHora(Object? v) {
  if (v == null) return null;
  final texto = '$v';
  if (texto.length <= 10) return fechaDe(texto);
  return Fecha.deDateTime(DateTime.parse(texto).toLocal());
}

/// Fila de `fin_libro_miembros`. `desde` y `hasta` son `timestamptz`; sin
/// `desde` no se manda y el servidor pone `now()`.
Map<String, Object?> filaMiembro(
  String libroId,
  MiembroLibro m, {
  required String hogarId,
  required String id,
}) => {
  'id': id,
  'hogar_id': hogarId,
  'libro_id': libroId,
  'persona_id': m.personaId,
  'papel': nombreEnum(m.papel),
  if (m.desde != null) 'desde': horaDeFecha(m.desde!),
  'hasta': m.hasta == null ? null : horaDeFecha(m.hasta!),
};

Libro libroDeFila(
  Map<String, dynamic> f,
  Iterable<Map<String, dynamic>> miembros,
) => Libro(
  id: '${f['id']}',
  nombre: '${f['nombre']}',
  tipo: enumDe(TipoLibro.values, f['tipo']),
  titularId: texto(f['titular_id']),
  activo: booleano(f['activo'], true),
  miembros: [
    for (final m in miembros)
      if ('${m['libro_id']}' == '${f['id']}')
        MiembroLibro(
          personaId: '${m['persona_id']}',
          papel: enumDe(PapelLibro.values, m['papel']),
          desde: fechaDeHora(m['desde']),
          hasta: fechaDeHora(m['hasta']),
        ),
  ],
);

// -------------------------------------------------------------- parámetros

/// Lo que cambia la persona en `fin_parametros` (UPDATE por `libro_id`). La
/// fila nace con el libro y las cuentas de sistema no cambian, así que no van.
Map<String, Object?> cambiosParametros(ParametrosFinanzas p) => {
  'meta_remanente_pb': p.metaRemanentePuntosBase,
  'ahorro_minimo_con_deuda_pb': p.ahorroMinimoConDeudaPuntosBase,
  'tope_arrastre_semanas': p.topeArrastreSemanas,
  'partida_ambar_pb': p.umbrales.partidaAmbarDesde,
  'partida_rojo_pb': p.umbrales.partidaRojoArribaDe,
  'remanente_verde_pb': p.umbrales.remanenteVerdeDesde,
  'remanente_ambar_pb': p.umbrales.remanenteAmbarDesde,
  'carga_ambar_pb': p.umbrales.cargaDeudaAmbarDesde,
  'carga_rojo_pb': p.umbrales.cargaDeudaRojoArribaDe,
  'cumplimiento_verde_pb': p.umbrales.cumplimientoVerdeDesde,
  'cumplimiento_ambar_pb': p.umbrales.cumplimientoAmbarDesde,
  'cierre_automatico_dias': p.cierreAutomaticoDias,
};

Map<String, Object?> filaParametros(
  ParametrosFinanzas p, {
  required String hogarId,
}) => {
  'libro_id': p.libroId,
  'hogar_id': hogarId,
  'meta_remanente_pb': p.metaRemanentePuntosBase,
  'ahorro_minimo_con_deuda_pb': p.ahorroMinimoConDeudaPuntosBase,
  'tope_arrastre_semanas': p.topeArrastreSemanas,
  'partida_ambar_pb': p.umbrales.partidaAmbarDesde,
  'partida_rojo_pb': p.umbrales.partidaRojoArribaDe,
  'remanente_verde_pb': p.umbrales.remanenteVerdeDesde,
  'remanente_ambar_pb': p.umbrales.remanenteAmbarDesde,
  'carga_ambar_pb': p.umbrales.cargaDeudaAmbarDesde,
  'carga_rojo_pb': p.umbrales.cargaDeudaRojoArribaDe,
  'cumplimiento_verde_pb': p.umbrales.cumplimientoVerdeDesde,
  'cumplimiento_ambar_pb': p.umbrales.cumplimientoAmbarDesde,
  'cierre_automatico_dias': p.cierreAutomaticoDias,
  'cuenta_ajustes_id': p.cuentaAjustesId,
  'cuenta_apertura_id': p.cuentaAperturaId,
  'cuenta_por_clasificar_id': p.cuentaPorClasificarId,
};

ParametrosFinanzas parametrosDeFila(Map<String, dynamic> f) =>
    ParametrosFinanzas(
      libroId: '${f['libro_id']}',
      metaRemanentePuntosBase: entero(f['meta_remanente_pb'], 2000),
      ahorroMinimoConDeudaPuntosBase: entero(f['ahorro_minimo_con_deuda_pb']),
      topeArrastreSemanas: entero(f['tope_arrastre_semanas'], 2),
      umbrales: Umbrales(
        partidaAmbarDesde: entero(f['partida_ambar_pb'], 8000),
        partidaRojoArribaDe: entero(f['partida_rojo_pb'], 10000),
        remanenteVerdeDesde: entero(f['remanente_verde_pb'], 2000),
        remanenteAmbarDesde: entero(f['remanente_ambar_pb'], 1000),
        cargaDeudaAmbarDesde: entero(f['carga_ambar_pb'], 2000),
        cargaDeudaRojoArribaDe: entero(f['carga_rojo_pb'], 3500),
        cumplimientoVerdeDesde: entero(f['cumplimiento_verde_pb'], 9000),
        cumplimientoAmbarDesde: entero(f['cumplimiento_ambar_pb'], 7000),
      ),
      cierreAutomaticoDias: entero(f['cierre_automatico_dias'], 3),
      cuentaAjustesId: texto(f['cuenta_ajustes_id']),
      cuentaAperturaId: texto(f['cuenta_apertura_id']),
      cuentaPorClasificarId: texto(f['cuenta_por_clasificar_id']),
    );

// -------------------------------------------------------------- categorías

Map<String, Object?> filaCategoria(Categoria c, {required String hogarId}) => {
  'id': c.id,
  'hogar_id': hogarId,
  'padre_id': c.padreId,
  'nivel': c.nivel,
  'nombre': c.nombre,
  'icono': c.icono,
  'color': c.color,
  'naturaleza': c.naturaleza,
  'prioridad': nombreEnum(c.prioridad),
  'protegida': c.protegida,
  'es_del_sistema': c.esDelSistema,
  'oculta': c.oculta,
  'archivada': c.archivada,
  'posiblemente_deducible': c.posiblementeDeducible,
  'cuenta_gasto_id': c.cuentaGastoId,
};

Categoria categoriaDeFila(Map<String, dynamic> f) => Categoria(
  id: '${f['id']}',
  padreId: texto(f['padre_id']),
  nivel: entero(f['nivel'], 1),
  nombre: '${f['nombre']}',
  icono: texto(f['icono']),
  color: texto(f['color']),
  naturaleza: texto(f['naturaleza']) ?? '',
  prioridad: enumONulo(Prioridad.values, f['prioridad']) ?? Prioridad.deseable,
  protegida: booleano(f['protegida']),
  esDelSistema: booleano(f['es_del_sistema']),
  oculta: booleano(f['oculta']),
  archivada: booleano(f['archivada']),
  posiblementeDeducible: booleano(f['posiblemente_deducible']),
  cuentaGastoId: texto(f['cuenta_gasto_id']),
);

// ----------------------------------------------------------------- cuentas

/// Tipos de cuenta que son del **hogar** (sin libro): las de gasto por rubro.
const tiposDelHogar = {TipoCuenta.deGasto, TipoCuenta.gastoFinanciero};

/// `creada_por` la pone el servidor; las cuentas de gasto (`de_gasto` y
/// `gasto_financiero`) van sin libro y todas las demás con el suyo (check
/// `fin_cuentas_gasto_es_del_hogar`). Lanza [ArgumentError] si no se cumple:
/// mejor aquí que un 23514 del servidor.
Map<String, Object?> filaCuenta(Cuenta c, {required String hogarId}) {
  if (tiposDelHogar.contains(c.tipo) != (c.libroId == null)) {
    throw ArgumentError(
      'La cuenta ${c.nombre}: solo las cuentas de gasto van sin libro.',
    );
  }
  if (c.tipo == TipoCuenta.otroLibro) {
    throw ArgumentError('Una cuenta de otro libro es virtual: no se guarda.');
  }
  return _filaCuenta(c, hogarId: hogarId);
}

Map<String, Object?> _filaCuenta(Cuenta c, {required String hogarId}) => {
  'id': c.id,
  'hogar_id': hogarId,
  'libro_id': c.libroId,
  'nombre': c.nombre,
  'tipo': nombreEnum(c.tipo),
  'estado': nombreEnum(c.estado),
  'categoria_id': c.categoriaId,
  'limite_centavos': c.limiteCentavos,
};

Cuenta cuentaDeFila(Map<String, dynamic> f) => Cuenta(
  id: '${f['id']}',
  nombre: '${f['nombre']}',
  tipo: enumDe(TipoCuenta.values, f['tipo']),
  estado: enumONulo(EstadoCuenta.values, f['estado']) ?? EstadoCuenta.activa,
  categoriaId: texto(f['categoria_id']),
  limiteCentavos: enteroONulo(f['limite_centavos']),
  libroId: texto(f['libro_id']),
);

// ------------------------------------------------------------- movimientos

Map<String, Object?> filaMovimiento(Movimiento m, {required String hogarId}) =>
    {
      'id': m.id,
      'hogar_id': hogarId,
      'tipo': nombreEnum(m.tipo),
      'fecha': fechaIso(m.fecha),
      'registrado_en': horaIso(m.registradoEn),
      'cuenta_origen_id': m.cuentaOrigenId,
      'cuenta_destino_id': m.cuentaDestinoId,
      'monto_centavos': m.monto,
      'categoria_id': m.categoriaId,
      'grupo_id': m.grupoId,
      'realizado_por': m.realizadoPor,
      'registrado_por': m.registradoPor,
      'via': nombreEnum(m.via),
      'nota': m.nota,
      'motivo': m.motivo,
      'anula_a': m.anulaA,
      'en_nombre_de': m.enNombreDe,
      'estado_inicial': nombreEnum(m.estadoInicial),
    };

Movimiento movimientoDeFila(Map<String, dynamic> f) => Movimiento(
  id: '${f['id']}',
  tipo: enumDe(TipoMovimiento.values, f['tipo']),
  fecha: fechaReq(f['fecha']),
  registradoEn: horaDe(f['registrado_en'])!,
  cuentaOrigenId: '${f['cuenta_origen_id']}',
  cuentaDestinoId: '${f['cuenta_destino_id']}',
  monto: entero(f['monto_centavos']),
  realizadoPor: '${f['realizado_por']}',
  registradoPor: texto(f['registrado_por']),
  via: enumONulo(ViaCaptura.values, f['via']) ?? ViaCaptura.manual,
  categoriaId: texto(f['categoria_id']),
  grupoId: texto(f['grupo_id']),
  nota: texto(f['nota']),
  motivo: texto(f['motivo']),
  anulaA: texto(f['anula_a']),
  enNombreDe: texto(f['en_nombre_de']),
  estadoInicial:
      enumONulo(EstadoMovimiento.values, f['estado_inicial']) ??
      EstadoMovimiento.confirmado,
);

// --------------------------------------------------------------- calendario

/// Columnas del calendario. `regla_inhabil` va con la regla efectiva: la
/// elegida o [porOmision] (es `not null` en el servidor).
Map<String, Object?> filaCalendario(
  CalendarioConfig? c, {
  required ReglaDiaInhabil porOmision,
}) => {
  'forma': c == null ? null : nombreEnum(c.forma),
  'dia_semana': c?.diaSemana,
  'dias_mes': c == null || c.diasMes.isEmpty ? null : c.diasMes,
  'fecha_ancla': c?.fechaAncla == null ? null : fechaIso(c!.fechaAncla!),
  'intervalo_meses': c?.intervaloMeses,
  'regla_inhabil': nombreEnum(c?.reglaPara(porOmision) ?? porOmision),
};

CalendarioConfig? calendarioDeFila(
  Map<String, dynamic> f, {
  required ReglaDiaInhabil reglaPorOmision,
}) {
  final forma = enumONulo(FormaPago.values, f['forma']);
  if (forma == null) return null;
  return CalendarioConfig(
    forma: forma,
    diaSemana: enteroONulo(f['dia_semana']),
    diasMes: enteros(f['dias_mes']),
    fechaAncla: fechaDe(f['fecha_ancla']),
    intervaloMeses: enteroONulo(f['intervalo_meses']),
    regla: enumONulo(ReglaDiaInhabil.values, f['regla_inhabil']) ??
        reglaPorOmision,
  );
}

// ---------------------------------------------------------------- ingresos

Map<String, Object?> filaIngreso(Ingreso i, {required String hogarId}) => {
  'id': i.id,
  'hogar_id': hogarId,
  'libro_id': i.libroId,
  'persona_id': i.personaId,
  'nombre': i.nombre,
  'tipo': nombreEnum(i.tipo),
  'cuenta_origen_id': i.cuentaOrigenId,
  'cuenta_destino_id': i.cuentaDestinoId,
  'certeza': nombreEnum(i.certeza),
  'activo': i.activo,
};

Map<String, Object?> filaVigencia(
  VigenciaIngreso v, {
  required String hogarId,
  required String libroId,
}) => {
  'id': v.id,
  'hogar_id': hogarId,
  'libro_id': libroId,
  'ingreso_id': v.ingresoId,
  'monto_neto_centavos': v.montoNeto,
  ...filaCalendario(
    v.calendario,
    porOmision: CalendarioConfig.reglaDeIngreso,
  ),
  'desde': fechaIso(v.desde),
  'hasta': v.hasta == null ? null : fechaIso(v.hasta!),
};

Ingreso ingresoDeFila(
  Map<String, dynamic> f,
  Iterable<Map<String, dynamic>> vigencias,
) => Ingreso(
  id: '${f['id']}',
  libroId: '${f['libro_id']}',
  personaId: texto(f['persona_id']),
  nombre: '${f['nombre']}',
  tipo: enumONulo(TipoIngreso.values, f['tipo']) ?? TipoIngreso.otro,
  cuentaOrigenId: '${f['cuenta_origen_id']}',
  cuentaDestinoId: '${f['cuenta_destino_id']}',
  certeza: enumONulo(Certeza.values, f['certeza']) ?? Certeza.segura,
  activo: booleano(f['activo'], true),
  vigencias: [
    for (final v in vigencias)
      if ('${v['ingreso_id']}' == '${f['id']}')
        VigenciaIngreso(
          id: '${v['id']}',
          ingresoId: '${v['ingreso_id']}',
          montoNeto: entero(v['monto_neto_centavos']),
          calendario: calendarioDeFila(
            v,
            reglaPorOmision: ReglaDiaInhabil.siguienteDiaHabil,
          )!,
          desde: fechaReq(v['desde']),
          hasta: fechaDe(v['hasta']),
        ),
  ],
);

// ------------------------------------------------------------ compromisos

Map<String, Object?> filaCompromiso(Compromiso c, {required String hogarId}) =>
    {
      'id': c.id,
      'hogar_id': hogarId,
      'libro_id': c.libroId,
      'nombre': c.nombre,
      'tipo': nombreEnum(c.tipo),
      'cuenta_gasto_id': c.cuentaGastoId,
      'categoria_id': c.categoriaId,
      'monto_centavos': c.monto,
      'frecuencia': nombreEnum(c.frecuencia),
      'dias_activos': c.diasActivos,
      ...filaCalendario(
        c.calendario,
        porOmision: CalendarioConfig.reglaDeSalida,
      ),
      'protegida': c.protegida,
      'prioridad': nombreEnum(c.prioridad),
      'desde': c.desde == null ? null : fechaIso(c.desde!),
      'hasta': c.hasta == null ? null : fechaIso(c.hasta!),
      'activo': c.activo,
    };

Compromiso compromisoDeFila(Map<String, dynamic> f) => Compromiso(
  id: '${f['id']}',
  libroId: '${f['libro_id']}',
  nombre: '${f['nombre']}',
  tipo: enumONulo(TipoCompromiso.values, f['tipo']) ?? TipoCompromiso.fija,
  cuentaGastoId: '${f['cuenta_gasto_id']}',
  categoriaId: texto(f['categoria_id']),
  monto: entero(f['monto_centavos']),
  frecuencia: enumDe(Frecuencia.values, f['frecuencia']),
  diasActivos: enteroONulo(f['dias_activos']),
  // Regla 5 de 4.5: los pagos que salen se quedan en su fecha.
  calendario: calendarioDeFila(f, reglaPorOmision: ReglaDiaInhabil.sinCambio),
  protegida: booleano(f['protegida']),
  prioridad: enumONulo(Prioridad.values, f['prioridad']) ?? Prioridad.necesario,
  desde: fechaDe(f['desde']),
  hasta: fechaDe(f['hasta']),
  activo: booleano(f['activo'], true),
);

// ------------------------------------------------------------------ sobres

Map<String, Object?> filaSobre(Sobre s, {required String hogarId}) => {
  'id': s.id,
  'hogar_id': hogarId,
  'libro_id': s.libroId,
  'cuenta_gasto_id': s.cuentaGastoId,
  'nombre': s.nombre,
  'monto_semanal_centavos': s.montoSemanal,
  'protegida': s.protegida,
  'prioridad': nombreEnum(s.prioridad),
  'piso_minimo_centavos': s.pisoMinimo,
  'modo_arrastre': nombreEnum(s.modoArrastre),
  'activo': s.activo,
};

Sobre sobreDeFila(Map<String, dynamic> f) => Sobre(
  id: '${f['id']}',
  libroId: '${f['libro_id']}',
  cuentaGastoId: '${f['cuenta_gasto_id']}',
  nombre: '${f['nombre']}',
  montoSemanal: entero(f['monto_semanal_centavos']),
  protegida: booleano(f['protegida']),
  prioridad: enumONulo(Prioridad.values, f['prioridad']) ?? Prioridad.deseable,
  pisoMinimo: entero(f['piso_minimo_centavos']),
  modoArrastre:
      enumONulo(ModoArrastre.values, f['modo_arrastre']) ??
      ModoArrastre.arrastrar,
  activo: booleano(f['activo'], true),
);

// ------------------------------------------------------------------ deudas

Map<String, Object?> filaDeuda(Deuda d, {required String hogarId}) => {
  'id': d.id,
  'hogar_id': hogarId,
  'libro_id': d.libroId,
  'nombre': d.nombre,
  'tipo': nombreEnum(d.tipo),
  'cuenta_pasivo_id': d.cuentaPasivoId,
  'abono_centavos': d.abono,
  'frecuencia': nombreEnum(d.frecuencia),
  ...filaCalendario(d.calendario, porOmision: CalendarioConfig.reglaDeSalida),
  'minimo_centavos': d.minimo,
  'tasa_anual_pb': d.tasaAnualPuntosBase,
  'prioridad_manual': d.prioridadManual,
  'grupo_prioritario': d.grupoPrioritario,
  'orden_grupo': d.ordenGrupo,
  'activa': d.activa,
};

Deuda deudaDeFila(Map<String, dynamic> f) => Deuda(
  id: '${f['id']}',
  libroId: '${f['libro_id']}',
  nombre: '${f['nombre']}',
  tipo: enumDe(TipoDeuda.values, f['tipo']),
  cuentaPasivoId: texto(f['cuenta_pasivo_id']),
  abono: entero(f['abono_centavos']),
  frecuencia: enumDe(Frecuencia.values, f['frecuencia']),
  calendario: calendarioDeFila(f, reglaPorOmision: ReglaDiaInhabil.sinCambio),
  minimo: entero(f['minimo_centavos']),
  tasaAnualPuntosBase: entero(f['tasa_anual_pb']),
  prioridadManual: enteroONulo(f['prioridad_manual']),
  grupoPrioritario: booleano(f['grupo_prioritario']),
  ordenGrupo: enteroONulo(f['orden_grupo']),
  activa: booleano(f['activa'], true),
);

// --------------------------------------------------------- días inhábiles

Map<String, Object?> filaDiaInhabil(
  DiaInhabil d, {
  required String hogarId,
  required String id,
}) => {
  'id': id,
  'hogar_id': hogarId,
  'fecha': fechaIso(d.fecha),
  'nombre': d.nombre,
  'tipo': nombreEnum(d.tipo),
  'fuente': d.fuente,
  'activo': d.activo,
  'revisado_por': d.revisadoPor,
  'revisado_en': d.revisadoEn == null ? null : horaIso(d.revisadoEn!),
};

DiaInhabil diaInhabilDeFila(Map<String, dynamic> f) => DiaInhabil(
  id: texto(f['id']),
  fecha: fechaReq(f['fecha']),
  nombre: '${f['nombre']}',
  tipo:
      enumONulo(TipoDiaInhabil.values, f['tipo']) ??
      TipoDiaInhabil.festivoOficial,
  fuente: texto(f['fuente']) ?? '',
  activo: booleano(f['activo'], true),
  revisadoPor: texto(f['revisado_por']),
  revisadoEn: horaDe(f['revisado_en']),
);

// --------------------------------------------------------------------- plan

/// `activada_por` y `activada_en` los pone el servidor.
Map<String, Object?> filaSemana(SemanaGuardada s, {required String hogarId}) =>
    {
      'id': s.id,
      'hogar_id': hogarId,
      'libro_id': s.libroId,
      'semana_inicio': fechaIso(s.semana.inicio),
      'estado': nombreEnum(s.estado),
      'metodo': s.metodo,
      'ingreso': s.ingreso,
      'presupuesto': s.presupuesto,
      'deuda_plan': s.deudaPlan,
      'remanente_plan': s.remanentePlan,
      'meta_remanente_pb': s.metaRemanentePuntosBase,
      'ahorro_minimo_con_deuda_pb': s.ahorroMinimoConDeudaPuntosBase,
      'techo': s.techo,
    };

Map<String, Object?> filaPartidaSemana(
  PartidaSemana p, {
  required String hogarId,
  required String libroId,
}) => {
  'id': p.id,
  'hogar_id': hogarId,
  'libro_id': libroId,
  'semana_id': p.semanaId,
  'origen': nombreEnum(p.origen),
  'origen_id': p.origenId,
  'cuenta_gasto_id': p.cuentaGastoId,
  'tipo': nombreEnum(p.tipo),
  'asignado': p.asignado,
  'arrastre_recibido': p.arrastreRecibido,
  'protegida': p.protegida,
  'prioridad': nombreEnum(p.prioridad),
  'piso_minimo': p.pisoMinimo,
  'modo_arrastre': nombreEnum(p.modoArrastre),
};

Map<String, Object?> filaAbonoSemana(
  AbonoSemana a, {
  required String hogarId,
  required String libroId,
}) => {
  'id': a.id,
  'hogar_id': hogarId,
  'libro_id': libroId,
  'semana_id': a.semanaId,
  'deuda_id': a.deudaId,
  'abono_planeado': a.abonoPlaneado,
  'minimo': a.minimo,
  'extra_planeado': a.extraPlaneado,
};

SemanaGuardada semanaDeFila(
  Map<String, dynamic> f,
  Iterable<Map<String, dynamic>> partidas,
  Iterable<Map<String, dynamic>> abonos,
) {
  final id = '${f['id']}';
  return SemanaGuardada(
    id: id,
    libroId: '${f['libro_id']}',
    semana: Semana.de(fechaReq(f['semana_inicio'])),
    estado: enumDe(EstadoSemana.values, f['estado']),
    metodo: texto(f['metodo']) ?? 'sobres',
    ingreso: entero(f['ingreso']),
    presupuesto: entero(f['presupuesto']),
    deudaPlan: entero(f['deuda_plan']),
    remanentePlan: entero(f['remanente_plan']),
    metaRemanentePuntosBase: entero(f['meta_remanente_pb'], 2000),
    ahorroMinimoConDeudaPuntosBase: entero(f['ahorro_minimo_con_deuda_pb']),
    techo: entero(f['techo']),
    activadaPor: texto(f['activada_por']),
    activadaEn: horaDe(f['activada_en']),
    reaperturas: entero(f['reaperturas']),
    partidas: [
      for (final p in partidas)
        if ('${p['semana_id']}' == id)
          PartidaSemana(
            id: '${p['id']}',
            semanaId: id,
            origen: enumDe(OrigenPartida.values, p['origen']),
            origenId: '${p['origen_id']}',
            cuentaGastoId: texto(p['cuenta_gasto_id']),
            tipo: enumDe(TipoPartida.values, p['tipo']),
            asignado: entero(p['asignado']),
            arrastreRecibido: entero(p['arrastre_recibido']),
            protegida: booleano(p['protegida']),
            prioridad:
                enumONulo(Prioridad.values, p['prioridad']) ??
                Prioridad.necesario,
            pisoMinimo: entero(p['piso_minimo']),
            modoArrastre:
                enumONulo(ModoArrastre.values, p['modo_arrastre']) ??
                ModoArrastre.alRemanente,
          ),
    ],
    abonos: [
      for (final a in abonos)
        if ('${a['semana_id']}' == id)
          AbonoSemana(
            id: '${a['id']}',
            semanaId: id,
            deudaId: '${a['deuda_id']}',
            abonoPlaneado: entero(a['abono_planeado']),
            minimo: entero(a['minimo']),
            extraPlaneado: entero(a['extra_planeado']),
          ),
    ],
  );
}

Map<String, Object?> filaCierre(
  CierreGuardado c, {
  required String hogarId,
  required String libroId,
}) => {
  'id': c.id,
  'hogar_id': hogarId,
  'libro_id': libroId,
  'semana_id': c.semanaId,
  'version': c.version,
  'ingreso_real': c.ingresoReal,
  'gasto_real': c.gastoReal,
  'abono_real': c.abonoReal,
  'abono_diferido': c.abonoDiferido,
  'abono_extra_real': c.abonoExtraReal,
  'ahorro_real': c.ahorroReal,
  'deficit': c.deficit,
  'arrastre_siguiente': c.arrastreSiguiente,
  'accion_elegida': nombreEnum(c.accionElegida),
  'con_pendientes': c.conPendientes,
  'activos': c.activos,
  'pasivos': c.pasivos,
  'patrimonio': c.patrimonio,
  'cerrado_por': c.cerradoPor,
  'cerrado_en': horaIso(c.cerradoEn),
};

/// Fila de `fin_cierre_partidas`. Su [id] debe ser estable (sale del cierre
/// y la partida) para que reintentar no duplique.
Map<String, Object?> filaCierrePartida(
  String cierreId,
  CierrePartidaGuardada p, {
  required String hogarId,
  required String libroId,
  required String id,
}) => {
  'id': id,
  'cierre_id': cierreId,
  'hogar_id': hogarId,
  'libro_id': libroId,
  'partida_id': p.partidaId,
  'gastado': p.gastado,
  'arrastre_siguiente': p.arrastreSiguiente,
  'al_remanente': p.alRemanente,
};

/// Fila de `fin_cierre_abonos` (sin `diferido`: lo genera el servidor). Su
/// [id] debe ser estable (sale del cierre y la deuda).
Map<String, Object?> filaCierreAbono(
  String cierreId,
  CierreAbonoGuardado a, {
  required String hogarId,
  required String libroId,
  required String id,
}) => {
  'id': id,
  'cierre_id': cierreId,
  'hogar_id': hogarId,
  'libro_id': libroId,
  'deuda_id': a.deudaId,
  'planeado': a.planeado,
  'real': a.real,
  'minimo': a.minimo,
};

CierreGuardado cierreDeFila(
  Map<String, dynamic> f,
  Iterable<Map<String, dynamic>> partidas,
  Iterable<Map<String, dynamic>> abonos,
) {
  final id = '${f['id']}';
  return CierreGuardado(
    id: id,
    semanaId: '${f['semana_id']}',
    version: entero(f['version'], 1),
    ingresoReal: entero(f['ingreso_real']),
    gastoReal: entero(f['gasto_real']),
    abonoReal: entero(f['abono_real']),
    abonoDiferido: entero(f['abono_diferido']),
    abonoExtraReal: entero(f['abono_extra_real']),
    ahorroReal: entero(f['ahorro_real']),
    deficit: entero(f['deficit']),
    arrastreSiguiente: entero(f['arrastre_siguiente']),
    accionElegida:
        enumONulo(AccionCierre.values, f['accion_elegida']) ??
        AccionCierre.sinAplicar,
    conPendientes: booleano(f['con_pendientes']),
    activos: entero(f['activos']),
    pasivos: entero(f['pasivos']),
    patrimonio: entero(f['patrimonio']),
    cerradoPor: texto(f['cerrado_por']),
    cerradoEn: horaDe(f['cerrado_en']) ?? DateTime(2000),
    partidas: [
      for (final p in partidas)
        if ('${p['cierre_id']}' == id)
          CierrePartidaGuardada(
            partidaId: '${p['partida_id']}',
            gastado: entero(p['gastado']),
            arrastreSiguiente: entero(p['arrastre_siguiente']),
            alRemanente: entero(p['al_remanente']),
          ),
    ],
    abonos: [
      for (final a in abonos)
        if ('${a['cierre_id']}' == id)
          CierreAbonoGuardado(
            deudaId: '${a['deuda_id']}',
            planeado: entero(a['planeado']),
            real: entero(a['real']),
            minimo: entero(a['minimo']),
          ),
    ],
  );
}

Map<String, Object?> filaOcurrencia(Ocurrencia o, {required String hogarId}) =>
    {
      'id': o.id,
      'hogar_id': hogarId,
      'libro_id': o.libroId,
      'origen': nombreEnum(o.origen),
      'origen_id': o.origenId,
      'fecha_programada': fechaIso(o.fechaProgramada),
      'fecha_ajustada': fechaIso(o.fechaAjustada),
      'monto_esperado': o.montoEsperado,
      'estado': nombreEnum(o.estado),
      'movimiento_id': o.movimientoId,
    };

Ocurrencia ocurrenciaDeFila(Map<String, dynamic> f) => Ocurrencia(
  id: '${f['id']}',
  libroId: '${f['libro_id']}',
  origen: enumDe(OrigenOcurrencia.values, f['origen']),
  origenId: '${f['origen_id']}',
  fechaProgramada: fechaReq(f['fecha_programada']),
  fechaAjustada: fechaReq(f['fecha_ajustada']),
  montoEsperado: entero(f['monto_esperado']),
  estado:
      enumONulo(EstadoOcurrencia.values, f['estado']) ??
      EstadoOcurrencia.esperada,
  movimientoId: texto(f['movimiento_id']),
);

Map<String, Object?> filaConciliacion(
  ConciliacionGuardada c, {
  required String hogarId,
}) => {
  'id': c.id,
  'hogar_id': hogarId,
  'libro_id': c.libroId,
  'cuenta_id': c.cuentaId,
  'fecha': fechaIso(c.fecha),
  'saldo_declarado': c.saldoDeclarado,
  'saldo_calculado': c.saldoCalculado,
  'ajuste_movimiento_id': c.ajusteMovimientoId,
  'motivo': c.motivo,
  'persona_id': c.personaId,
  'creado_en': horaIso(c.creadoEn),
};

ConciliacionGuardada conciliacionDeFila(Map<String, dynamic> f) =>
    ConciliacionGuardada(
      id: '${f['id']}',
      libroId: '${f['libro_id']}',
      cuentaId: '${f['cuenta_id']}',
      fecha: fechaReq(f['fecha']),
      saldoDeclarado: entero(f['saldo_declarado']),
      saldoCalculado: entero(f['saldo_calculado']),
      ajusteMovimientoId: texto(f['ajuste_movimiento_id']),
      motivo: texto(f['motivo']),
      personaId: '${f['persona_id']}',
      creadoEn: horaDe(f['creado_en']) ?? DateTime(2000),
    );

Map<String, Object?> filaImportacion(
  ImportacionGuardada i, {
  required String hogarId,
}) => {
  'id': i.id,
  'hogar_id': hogarId,
  'archivo': i.archivo,
  'hoja': i.hoja,
  'filas_leidas': i.filasLeidas,
  'filas_creadas': i.filasCreadas,
  'filas_omitidas': i.filasOmitidas,
  'detalle': i.detalle,
  'persona_id': i.personaId,
  'creado_en': horaIso(i.creadoEn),
};

ImportacionGuardada importacionDeFila(Map<String, dynamic> f) =>
    ImportacionGuardada(
      id: '${f['id']}',
      archivo: '${f['archivo']}',
      hoja: '${f['hoja']}',
      filasLeidas: entero(f['filas_leidas']),
      filasCreadas: entero(f['filas_creadas']),
      filasOmitidas: entero(f['filas_omitidas']),
      detalle: [
        for (final d in (f['detalle'] as List<Object?>? ?? const []))
          if (d is Map) d.cast<String, Object?>(),
      ],
      personaId: '${f['persona_id']}',
      creadoEn: horaDe(f['creado_en']) ?? DateTime(2000),
    );
