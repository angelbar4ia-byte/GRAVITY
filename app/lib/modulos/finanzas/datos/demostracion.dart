/// Datos de ejemplo de Finanzas para el modo demostración (sin servidor).
///
/// Ilustrativos, **nunca reales**: el libro compartido "Gastos de la casa"
/// lleva los números del ejemplo del diseño (5.6 bis, punto 5: hogar de Ana y
/// Alex); cada adulto tiene su libro personal y el de "Papá (ejemplo)" lo
/// llevan sus albaceas (D19). Las fechas se arman alrededor de [hoy] para que
/// la semana actual tenga movimientos.
library;

import 'package:finanzas_dominio/finanzas_dominio.dart';

import '../../../nucleo/contratos/roles.dart';
import '../../../nucleo/sesion/servicio_sesion_demostracion.dart';

/// Ids fijos del ejemplo.
abstract final class IdsDemostracion {
  static final dueno = personasDeEjemplo[Rol.dueno]!.id;
  static final pareja = personasDeEjemplo[Rol.coadministrador]!.id;
  static const papa = '00000000-0000-4000-8000-0000000000b1';

  static const libroCasa = '00000000-0000-4000-8000-0000000000c1';
  static const libroDueno = '00000000-0000-4000-8000-0000000000c2';
  static const libroPareja = '00000000-0000-4000-8000-0000000000c3';
  static const libroPapa = '00000000-0000-4000-8000-0000000000c4';
}

/// Nombres visibles del ejemplo.
Map<String, String> personasDeDemostracion() => {
  for (final p in personasDeEjemplo.values) p.id: p.nombre,
  IdsDemostracion.papa: 'Papá (ejemplo)',
};

/// Todo el hogar de ejemplo (lo que vería la cuenta maestra).
DatosFinanzas datosDeDemostracion({required Fecha hoy}) {
  final dueno = IdsDemostracion.dueno;
  final pareja = IdsDemostracion.pareja;
  const papa = IdsDemostracion.papa;
  const casa = IdsDemostracion.libroCasa;
  const libroDueno = IdsDemostracion.libroDueno;
  const libroPareja = IdsDemostracion.libroPareja;
  const libroPapa = IdsDemostracion.libroPapa;
  final lunes = Semana.de(hoy).inicio;
  final apertura = lunes.sumarDias(-7);
  var n = 0;
  String id(String prefijo) =>
      '00000000-0000-4000-9${(++n).toString().padLeft(3, '0')}-'
      '${prefijo.codeUnits.fold(0, (a, b) => a + b).toString().padLeft(12, '0')}';

  final libros = [
    Libro(
      id: casa,
      nombre: 'Gastos de la casa',
      tipo: TipoLibro.compartido,
      // Quien lo crea es su administrador (23/oct/2026); privado por omisión.
      creadoPor: dueno,
      miembros: [
        MiembroLibro(personaId: dueno, papel: PapelLibro.miembro),
        MiembroLibro(personaId: pareja, papel: PapelLibro.miembro),
      ],
    ),
    Libro(
      id: libroDueno,
      nombre: 'Finanzas del dueño',
      tipo: TipoLibro.personal,
      titularId: dueno,
      miembros: [MiembroLibro(personaId: dueno, papel: PapelLibro.titular)],
    ),
    Libro(
      id: libroPareja,
      nombre: 'Finanzas de la pareja',
      tipo: TipoLibro.personal,
      titularId: pareja,
      miembros: [MiembroLibro(personaId: pareja, papel: PapelLibro.titular)],
    ),
    Libro(
      id: libroPapa,
      nombre: 'Papá (ejemplo)',
      tipo: TipoLibro.representado,
      titularId: papa,
      miembros: [
        MiembroLibro(personaId: dueno, papel: PapelLibro.albacea),
        MiembroLibro(personaId: pareja, papel: PapelLibro.albaceaSuplente),
      ],
    ),
  ];

  final cuentas = <Cuenta>[];
  final parametros = <ParametrosFinanzas>[];
  Cuenta cuenta(String nombre, TipoCuenta tipo, String? libro) {
    final c = Cuenta(id: id(nombre), nombre: nombre, tipo: tipo, libroId: libro);
    cuentas.add(c);
    return c;
  }

  // Cuentas técnicas de cada libro (las crea el servidor con el libro).
  final apertureras = <String, Cuenta>{};
  final porClasificar = <String, Cuenta>{};
  for (final l in libros) {
    final ajustes = cuenta('Ajustes', TipoCuenta.ajustes, l.id);
    apertureras[l.id] = cuenta('Apertura', TipoCuenta.apertura, l.id);
    porClasificar[l.id] = cuenta('Por clasificar', TipoCuenta.porClasificar, l.id);
    parametros.add(
      ParametrosFinanzas(
        libroId: l.id,
        cuentaAjustesId: ajustes.id,
        cuentaAperturaId: apertureras[l.id]!.id,
        cuentaPorClasificarId: porClasificar[l.id]!.id,
      ),
    );
  }

  // Cuentas de gasto del hogar y categorías (parte de la plantilla).
  final categorias = <Categoria>[];
  final gasto = <String, Cuenta>{};
  final subcategoria = <String, Categoria>{};
  void rubro(
    String nombre,
    Prioridad prioridad,
    List<String> subs, {
    bool protegida = false,
    String naturaleza = '',
  }) {
    final c = cuenta(nombre, TipoCuenta.deGasto, null);
    gasto[nombre] = c;
    final cat = Categoria(
      id: id('cat $nombre'),
      nivel: 1,
      nombre: nombre,
      naturaleza: naturaleza,
      prioridad: prioridad,
      protegida: protegida,
      esDelSistema: true,
      cuentaGastoId: c.id,
    );
    categorias.add(cat);
    for (final s in subs) {
      final sub = Categoria(
        id: id('sub $nombre $s'),
        padreId: cat.id,
        nivel: 2,
        nombre: s,
        naturaleza: naturaleza,
        prioridad: prioridad,
        protegida: protegida,
        esDelSistema: true,
      );
      categorias.add(sub);
      subcategoria[s] = sub;
    }
  }

  rubro(
    'Vivienda y servicios',
    Prioridad.necesario,
    ['Renta o hipoteca', 'Luz', 'Agua', 'Internet'],
    protegida: true,
    naturaleza: 'Fija',
  );
  rubro('Alimentación', Prioridad.necesario, [
    'Despensa y abarrotes',
    'Frutas y verduras',
    'Comidas fuera',
  ], naturaleza: 'Variable');
  rubro('Transporte', Prioridad.necesario, [
    'Combustible',
    'Transporte público',
  ], naturaleza: 'Mixta');
  rubro('Salud', Prioridad.necesario, ['Medicinas', 'Consultas'],
      naturaleza: 'Recurrente y eventual');
  rubro('Limpieza y mantenimiento del hogar', Prioridad.deseable, [
    'Productos de limpieza',
  ], naturaleza: 'Mixta');
  rubro('Cuidado personal', Prioridad.deseable, ['Higiene personal'],
      naturaleza: 'Mixta');
  rubro('Entretenimiento', Prioridad.discrecional, [
    'Salidas',
    'Streaming y suscripciones',
  ], naturaleza: 'Discrecional');
  rubro('Vestimenta', Prioridad.discrecional, ['Ropa'], naturaleza: 'Eventual');
  rubro('Tecnología y comunicaciones', Prioridad.deseable, [
    'Telefonía móvil',
  ], naturaleza: 'Mixta');
  rubro('Seguros, impuestos y trámites', Prioridad.necesario, ['Impuestos'],
      naturaleza: 'Fija y eventual');
  final intereses = cuenta(
    'Intereses y cargos',
    TipoCuenta.gastoFinanciero,
    null,
  );

  // Libro compartido: el ejemplo del diseño.
  final bancoCasa = cuenta('Banco de la casa', TipoCuenta.banco, casa);
  final efectivoCasa = cuenta('Efectivo de la casa', TipoCuenta.efectivo, casa);
  final tarjeta = cuenta('Tarjeta de crédito', TipoCuenta.tarjeta, casa);
  final prestamo = cuenta('Préstamo familiar', TipoCuenta.prestamo, casa);
  final sueldoDueno = cuenta('Sueldo del dueño', TipoCuenta.origenIngreso, casa);
  final sueldoPareja = cuenta(
    'Sueldo de la pareja',
    TipoCuenta.origenIngreso,
    casa,
  );
  cuenta('Extras', TipoCuenta.origenIngreso, casa);
  // Libro del dueño.
  final bancoDueno = cuenta('Mi banco', TipoCuenta.banco, libroDueno);
  final efectivoDueno = cuenta('Mi efectivo', TipoCuenta.efectivo, libroDueno);
  final honorarios = cuenta('Honorarios', TipoCuenta.origenIngreso, libroDueno);
  cuenta('Extras', TipoCuenta.origenIngreso, libroDueno);
  // Libro de la pareja.
  final bancoPareja = cuenta('Mi banco', TipoCuenta.banco, libroPareja);
  final honorariosPareja = cuenta(
    'Clases particulares',
    TipoCuenta.origenIngreso,
    libroPareja,
  );
  // Libro de papá.
  final bancoPapa = cuenta('Cuenta de la pensión', TipoCuenta.banco, libroPapa);
  final pension = cuenta('Pensión', TipoCuenta.origenIngreso, libroPapa);
  final apoyo = cuenta('Apoyo 60+', TipoCuenta.origenIngreso, libroPapa);

  const enSuFecha = ReglaDiaInhabil.sinCambio;
  VigenciaIngreso vig(String ingreso, int monto, CalendarioConfig c) =>
      VigenciaIngreso(
        id: id('vig $ingreso'),
        ingresoId: ingreso,
        montoNeto: monto,
        calendario: c,
        desde: Fecha(2026, 1, 1),
      );
  final ingDueno = id('ing dueno');
  final ingPareja = id('ing pareja');
  final ingHonorarios = id('ing honorarios');
  final ingClases = id('ing clases');
  final ingPension = id('ing pension');
  final ingApoyo = id('ing apoyo');
  final ingresos = [
    Ingreso(
      id: ingDueno,
      libroId: casa,
      personaId: dueno,
      nombre: 'Sueldo del dueño (neto)',
      cuentaOrigenId: sueldoDueno.id,
      cuentaDestinoId: bancoCasa.id,
      vigencias: [vig(ingDueno, 900000, const CalendarioConfig.quincenal())],
    ),
    Ingreso(
      id: ingPareja,
      libroId: casa,
      personaId: pareja,
      nombre: 'Sueldo de la pareja (neto)',
      cuentaOrigenId: sueldoPareja.id,
      cuentaDestinoId: bancoCasa.id,
      vigencias: [vig(ingPareja, 1400000, const CalendarioConfig.mensual([0]))],
    ),
    Ingreso(
      id: ingHonorarios,
      libroId: libroDueno,
      personaId: dueno,
      nombre: 'Honorarios (ejemplo)',
      tipo: TipoIngreso.independiente,
      certeza: Certeza.probable,
      cuentaOrigenId: honorarios.id,
      cuentaDestinoId: bancoDueno.id,
      vigencias: [vig(ingHonorarios, 300000, const CalendarioConfig.mensual([5]))],
    ),
    Ingreso(
      id: ingClases,
      libroId: libroPareja,
      personaId: pareja,
      nombre: 'Clases particulares (ejemplo)',
      tipo: TipoIngreso.independiente,
      cuentaOrigenId: honorariosPareja.id,
      cuentaDestinoId: bancoPareja.id,
      vigencias: [vig(ingClases, 80000, const CalendarioConfig.semanal(5))],
    ),
    Ingreso(
      id: ingPension,
      libroId: libroPapa,
      personaId: papa,
      nombre: 'Pensión (ejemplo)',
      tipo: TipoIngreso.pension,
      cuentaOrigenId: pension.id,
      cuentaDestinoId: bancoPapa.id,
      vigencias: [
        vig(ingPension, 300000, const CalendarioConfig.mensual([1, 11])),
      ],
    ),
    Ingreso(
      id: ingApoyo,
      libroId: libroPapa,
      personaId: papa,
      nombre: 'Apoyo 60+ (ejemplo)',
      tipo: TipoIngreso.otro,
      certeza: Certeza.probable,
      cuentaOrigenId: apoyo.id,
      cuentaDestinoId: bancoPapa.id,
      vigencias: [
        vig(ingApoyo, 600000, CalendarioConfig.cadaMeses(Fecha(2026, 9, 1), 2)),
      ],
    ),
  ];

  String g(String rubro) => gasto[rubro]!.id;
  String s(String sub) => subcategoria[sub]!.id;
  Compromiso fijo(
    String nombre,
    int monto,
    Frecuencia f,
    String rubro,
    String sub,
    CalendarioConfig c, {
    bool protegida = false,
    TipoCompromiso tipo = TipoCompromiso.fija,
    String libro = casa,
  }) => Compromiso(
    id: id('comp $nombre $libro'),
    libroId: libro,
    nombre: nombre,
    tipo: tipo,
    cuentaGastoId: g(rubro),
    categoriaId: s(sub),
    monto: monto,
    frecuencia: f,
    calendario: c,
    protegida: protegida,
  );
  final compromisos = [
    fijo('Renta', 800000, Frecuencia.mensual, 'Vivienda y servicios',
        'Renta o hipoteca', const CalendarioConfig.mensual([1], regla: enSuFecha),
        protegida: true),
    fijo('Luz', 90000, Frecuencia.bimestral, 'Vivienda y servicios', 'Luz',
        CalendarioConfig.cadaMeses(Fecha(2026, 1, 10), 2, regla: enSuFecha),
        protegida: true),
    fijo('Agua', 30000, Frecuencia.mensual, 'Vivienda y servicios', 'Agua',
        const CalendarioConfig.mensual([5], regla: enSuFecha),
        protegida: true),
    fijo('Internet', 40000, Frecuencia.mensual, 'Vivienda y servicios',
        'Internet', const CalendarioConfig.mensual([20], regla: enSuFecha),
        protegida: true),
    fijo('Celular', 35000, Frecuencia.mensual, 'Tecnología y comunicaciones',
        'Telefonía móvil', const CalendarioConfig.mensual([15], regla: enSuFecha)),
    fijo('Reserva: placas y predial', 156000, Frecuencia.anual,
        'Seguros, impuestos y trámites', 'Impuestos',
        CalendarioConfig.cadaMeses(Fecha(2027, 1, 15), 12, regla: enSuFecha),
        tipo: TipoCompromiso.reserva),
    fijo('Celular personal', 25000, Frecuencia.mensual,
        'Tecnología y comunicaciones', 'Telefonía móvil',
        const CalendarioConfig.mensual([12], regla: enSuFecha),
        libro: libroDueno),
  ];

  Sobre sobre(
    String nombre,
    int monto,
    String rubro, {
    Prioridad prioridad = Prioridad.deseable,
    String libro = casa,
  }) => Sobre(
    id: id('sobre $nombre $libro'),
    libroId: libro,
    cuentaGastoId: g(rubro),
    nombre: nombre,
    montoSemanal: monto,
    prioridad: prioridad,
  );
  final sobres = [
    sobre('Alimentación', 150000, 'Alimentación', prioridad: Prioridad.necesario),
    sobre('Transporte', 70000, 'Transporte', prioridad: Prioridad.necesario),
    sobre('Salud', 30000, 'Salud'),
    sobre('Limpieza', 15000, 'Limpieza y mantenimiento del hogar'),
    sobre('Cuidado personal', 15000, 'Cuidado personal'),
    sobre('Entretenimiento', 25000, 'Entretenimiento',
        prioridad: Prioridad.discrecional),
    sobre('Vestimenta', 20000, 'Vestimenta', prioridad: Prioridad.discrecional),
    sobre('Gustos personales', 40000, 'Entretenimiento',
        prioridad: Prioridad.discrecional, libro: libroDueno),
    sobre('Transporte', 30000, 'Transporte', libro: libroPareja),
    sobre('Medicinas', 50000, 'Salud',
        prioridad: Prioridad.necesario, libro: libroPapa),
    sobre('Alimentación especial', 30000, 'Alimentación',
        prioridad: Prioridad.necesario, libro: libroPapa),
  ];

  final deudas = [
    Deuda(
      id: id('deuda tarjeta'),
      libroId: casa,
      nombre: 'Tarjeta de crédito',
      tipo: TipoDeuda.conCosto,
      cuentaPasivoId: tarjeta.id,
      abono: 120000,
      frecuencia: Frecuencia.mensual,
      calendario: const CalendarioConfig.mensual([20], regla: enSuFecha),
      tasaAnualPuntosBase: 4800,
    ),
    Deuda(
      id: id('deuda familiar'),
      libroId: casa,
      nombre: 'Préstamo familiar',
      tipo: TipoDeuda.familiar,
      cuentaPasivoId: prestamo.id,
      abono: 50000,
      frecuencia: Frecuencia.mensual,
      calendario: const CalendarioConfig.mensual([25], regla: enSuFecha),
    ),
  ];

  final movimientos = <Movimiento>[];
  Movimiento mov(
    TipoMovimiento tipo,
    Fecha fecha,
    String origen,
    String destino,
    int monto, {
    String? por,
    String? categoria,
    String? nota,
    String? enNombreDe,
    String? motivo,
    String? realizadoPor,
  }) {
    final m = Movimiento(
      id: id('mov ${movimientos.length}'),
      tipo: tipo,
      fecha: fecha,
      registradoEn: DateTime(fecha.anio, fecha.mes, fecha.dia, 9 + movimientos.length % 10),
      cuentaOrigenId: origen,
      cuentaDestinoId: destino,
      monto: monto,
      realizadoPor: realizadoPor ?? por ?? dueno,
      registradoPor: por ?? dueno,
      categoriaId: categoria,
      nota: nota,
      enNombreDe: enNombreDe,
      motivo: motivo,
    );
    movimientos.add(m);
    return m;
  }

  // Saldos iniciales.
  mov(TipoMovimiento.apertura, apertura, apertureras[casa]!.id, bancoCasa.id, 300000);
  mov(TipoMovimiento.apertura, apertura, apertureras[casa]!.id, efectivoCasa.id, 80000);
  mov(TipoMovimiento.apertura, apertura, tarjeta.id, apertureras[casa]!.id, 600000);
  mov(TipoMovimiento.apertura, apertura, prestamo.id, apertureras[casa]!.id, 300000);
  mov(TipoMovimiento.apertura, apertura, apertureras[libroDueno]!.id, bancoDueno.id, 450000);
  mov(TipoMovimiento.apertura, apertura, apertureras[libroDueno]!.id, efectivoDueno.id, 60000);
  mov(TipoMovimiento.apertura, apertura, apertureras[libroPareja]!.id, bancoPareja.id, 250000,
      por: pareja);
  mov(TipoMovimiento.apertura, apertura, apertureras[libroPapa]!.id, bancoPapa.id, 420000,
      realizadoPor: papa, enNombreDe: papa, motivo: 'Saldo de la cuenta de la pensión');

  // Gastos de la semana (los del boceto: Alimentación $620, Transporte $510).
  Fecha dia(int i) {
    final f = lunes.sumarDias(i);
    return f.despuesDe(hoy) ? hoy : f;
  }

  mov(TipoMovimiento.gasto, dia(0), bancoCasa.id, g('Alimentación'), 42000,
      categoria: s('Despensa y abarrotes'), nota: 'Súper');
  mov(TipoMovimiento.gasto, dia(1), efectivoCasa.id, g('Alimentación'), 20000,
      categoria: s('Frutas y verduras'), por: pareja);
  mov(TipoMovimiento.gasto, dia(1), tarjeta.id, g('Transporte'), 51000,
      categoria: s('Combustible'));
  mov(TipoMovimiento.gasto, dia(0), efectivoDueno.id, g('Entretenimiento'), 18000,
      categoria: s('Salidas'));
  mov(TipoMovimiento.gasto, dia(0), bancoPapa.id, g('Salud'), 32000,
      categoria: s('Medicinas'), realizadoPor: papa, enNombreDe: papa,
      motivo: 'Medicinas del mes');
  // Aportación de la pareja a la casa (transferencia entre libros).
  mov(TipoMovimiento.transferencia, dia(0), bancoPareja.id, bancoCasa.id, 50000,
      por: pareja, nota: 'Aportación a la casa');
  mov(TipoMovimiento.gasto, dia(1), bancoCasa.id, intereses.id, 2400,
      nota: 'Comisión bancaria');

  final datos = DatosFinanzas(
    libros: libros,
    parametros: parametros,
    cuentas: cuentas,
    categorias: categorias,
    ingresos: ingresos,
    compromisos: compromisos,
    sobres: sobres,
    deudas: deudas,
    movimientos: movimientos,
  );
  // La semana de la casa ya está activada; las demás quedan en borrador
  // para probar "Activar semana".
  final semana = Semana.de(hoy);
  final foto = fotoDelPlan(
    armarPlanDelLibro(datos, casa, semana),
    id: id('semana casa'),
    libroId: casa,
    arrastrePorOrigen: const {},
    activadaPor: dueno,
    activadaEn: DateTime(lunes.anio, lunes.mes, lunes.dia, 8),
    generarId: () => id('foto'),
  );
  return datos.copiar(semanas: [foto]);
}

/// Lo que **una persona** ve del hogar (como lo filtraría la RLS con
/// `fin_puede`): sus libros, los compartidos de los que es miembro, el
/// representado si es albacea, los compartidos públicos (solo lectura) y, para
/// la cuenta maestra, todos. Las cuentas de gasto y las categorías del hogar
/// las ve quien tiene Finanzas.
DatosFinanzas filtrarParaPersona(
  DatosFinanzas d,
  String personaId, {
  required Fecha hoy,
  bool esMaestra = false,
}) {
  final visibles = {
    for (final l in d.libros)
      if (permisoEnLibro(l, personaId, hoy: hoy, esMaestra: esMaestra).leer)
        l.id,
  };
  return datosDeLibros(d, visibles, conservarLibros: false);
}

/// Los datos de [d] solo con el **contenido** de los libros [visibles]: sus
/// cuentas, movimientos, plan y cierres. Las cuentas de gasto del hogar
/// (sin libro) se conservan. Con [conservarLibros] la lista de libros queda
/// completa (la portada de la cuenta maestra: libros y quién los lleva, sin
/// consulta registrada); si no, solo los visibles.
DatosFinanzas datosDeLibros(
  DatosFinanzas d,
  Set<String> visibles, {
  bool conservarLibros = true,
}) {
  bool delLibro(String? libroId) => libroId != null && visibles.contains(libroId);
  final cuentas = [
    for (final c in d.cuentas)
      if (c.libroId == null || visibles.contains(c.libroId)) c,
  ];
  final libroDeCuenta = {for (final c in d.cuentas) c.id: c.libroId};
  bool movVisible(Movimiento m) =>
      delLibro(libroDeCuenta[m.cuentaOrigenId]) ||
      delLibro(libroDeCuenta[m.cuentaDestinoId]);
  final semanas = [for (final s in d.semanas) if (delLibro(s.libroId)) s];
  final semanasIds = {for (final s in semanas) s.id};
  return d.copiar(
    libros: [
      for (final l in d.libros)
        if (conservarLibros || visibles.contains(l.id)) l,
    ],
    parametros: [for (final p in d.parametros) if (delLibro(p.libroId)) p],
    cuentas: cuentas,
    ingresos: [for (final i in d.ingresos) if (delLibro(i.libroId)) i],
    compromisos: [for (final c in d.compromisos) if (delLibro(c.libroId)) c],
    sobres: [for (final s in d.sobres) if (delLibro(s.libroId)) s],
    deudas: [for (final x in d.deudas) if (delLibro(x.libroId)) x],
    semanas: semanas,
    cierres: [for (final c in d.cierres) if (semanasIds.contains(c.semanaId)) c],
    ocurrencias: [for (final o in d.ocurrencias) if (delLibro(o.libroId)) o],
    conciliaciones: [
      for (final c in d.conciliaciones)
        if (delLibro(c.libroId)) c,
    ],
    movimientos: [for (final m in d.movimientos) if (movVisible(m)) m],
  );
}
