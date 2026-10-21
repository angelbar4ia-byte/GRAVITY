// Hogar de ejemplo con libros (D19) y los números del diseño (5.6 bis,
// punto 5: hogar de Ana y Alex). Datos ilustrativos, nunca reales.
import 'package:finanzas_dominio/finanzas_dominio.dart';

const ana = 'persona-ana';
const alex = 'persona-alex';
const papa = 'persona-papa';
const maestra = 'persona-maestra';

/// Libro compartido con el ejemplo del diseño.
const casa = 'libro-casa';
const libroAna = 'libro-ana';
const libroAlex = 'libro-alex';
const libroPapa = 'libro-papa';

final librosEjemplo = [
  Libro(
    id: libroAna,
    nombre: 'Libro de Ana',
    tipo: TipoLibro.personal,
    titularId: ana,
    miembros: const [MiembroLibro(personaId: ana, papel: PapelLibro.titular)],
  ),
  Libro(
    id: libroAlex,
    nombre: 'Libro de Alex',
    tipo: TipoLibro.personal,
    titularId: alex,
    miembros: const [MiembroLibro(personaId: alex, papel: PapelLibro.titular)],
  ),
  Libro(
    id: casa,
    nombre: 'Gastos de la casa',
    tipo: TipoLibro.compartido,
    miembros: const [
      MiembroLibro(personaId: ana, papel: PapelLibro.miembro),
      MiembroLibro(personaId: alex, papel: PapelLibro.miembro),
    ],
  ),
  Libro(
    id: libroPapa,
    nombre: 'Papá (ejemplo)',
    tipo: TipoLibro.representado,
    titularId: papa,
    miembros: const [
      MiembroLibro(personaId: ana, papel: PapelLibro.albacea),
      MiembroLibro(personaId: alex, papel: PapelLibro.albaceaSuplente),
    ],
  ),
];

Cuenta _c(String id, String nombre, TipoCuenta tipo, [String? libro]) =>
    Cuenta(id: id, nombre: nombre, tipo: tipo, libroId: libro);

final cuentasEjemplo = [
  // Libro compartido.
  _c('banco-casa', 'Banco de la casa', TipoCuenta.banco, casa),
  _c('efectivo-casa', 'Efectivo de la casa', TipoCuenta.efectivo, casa),
  _c('tarjeta', 'Tarjeta de crédito', TipoCuenta.tarjeta, casa),
  _c('prestamo-fam', 'Préstamo familiar', TipoCuenta.prestamo, casa),
  _c('sueldo-ana', 'Sueldo de Ana', TipoCuenta.origenIngreso, casa),
  _c('sueldo-alex', 'Sueldo de Alex', TipoCuenta.origenIngreso, casa),
  _c('extras-casa', 'Extras', TipoCuenta.origenIngreso, casa),
  _c('ajustes-casa', 'Ajustes', TipoCuenta.ajustes, casa),
  _c('apertura-casa', 'Apertura', TipoCuenta.apertura, casa),
  _c('pc-casa', 'Por clasificar', TipoCuenta.porClasificar, casa),
  // Libro de Ana.
  _c('banco-ana', 'Banco de Ana', TipoCuenta.banco, libroAna),
  _c('apertura-ana', 'Apertura', TipoCuenta.apertura, libroAna),
  // Libro de papá.
  _c('banco-papa', 'Cuenta de pensión', TipoCuenta.banco, libroPapa),
  _c('pension-papa', 'Pensión', TipoCuenta.origenIngreso, libroPapa),
  _c('apoyo-papa', 'Apoyo 60+', TipoCuenta.origenIngreso, libroPapa),
  _c('apertura-papa', 'Apertura', TipoCuenta.apertura, libroPapa),
  // Cuentas de gasto del hogar (sin libro).
  _c('g-vivienda', 'Vivienda y servicios', TipoCuenta.deGasto),
  _c('g-alimentacion', 'Alimentación', TipoCuenta.deGasto),
  _c('g-transporte', 'Transporte', TipoCuenta.deGasto),
  _c('g-salud', 'Salud', TipoCuenta.deGasto),
  _c('g-limpieza', 'Limpieza', TipoCuenta.deGasto),
  _c('g-cuidado', 'Cuidado personal', TipoCuenta.deGasto),
  _c('g-entretenimiento', 'Entretenimiento', TipoCuenta.deGasto),
  _c('g-vestimenta', 'Vestimenta', TipoCuenta.deGasto),
  _c('g-tecnologia', 'Tecnología', TipoCuenta.deGasto),
  _c('g-tramites', 'Seguros, impuestos y trámites', TipoCuenta.deGasto),
  _c('g-intereses', 'Intereses y cargos', TipoCuenta.gastoFinanciero),
];

Categoria _cat(String id, String nombre, {String? padre, String? cuenta}) =>
    Categoria(
      id: id,
      padreId: padre,
      nivel: padre == null ? 1 : 2,
      nombre: nombre,
      cuentaGastoId: cuenta,
    );

final categoriasEjemplo = [
  _cat('c-vivienda', 'Vivienda y servicios', cuenta: 'g-vivienda'),
  _cat('c-renta', 'Renta o hipoteca', padre: 'c-vivienda'),
  _cat('c-luz', 'Luz', padre: 'c-vivienda'),
  _cat('c-agua', 'Agua', padre: 'c-vivienda'),
  _cat('c-internet', 'Internet', padre: 'c-vivienda'),
  _cat('c-alimentacion', 'Alimentación', cuenta: 'g-alimentacion'),
  _cat('c-super', 'Despensa y abarrotes', padre: 'c-alimentacion'),
  _cat('c-transporte', 'Transporte', cuenta: 'g-transporte'),
  _cat('c-salud', 'Salud', cuenta: 'g-salud'),
  _cat('c-limpieza', 'Limpieza', cuenta: 'g-limpieza'),
  _cat('c-cuidado', 'Cuidado personal', cuenta: 'g-cuidado'),
  _cat('c-entretenimiento', 'Entretenimiento', cuenta: 'g-entretenimiento'),
  _cat('c-vestimenta', 'Vestimenta', cuenta: 'g-vestimenta'),
  _cat('c-tecnologia', 'Tecnología', cuenta: 'g-tecnologia'),
  _cat('c-celular', 'Telefonía móvil', padre: 'c-tecnologia'),
  _cat('c-tramites', 'Seguros, impuestos y trámites', cuenta: 'g-tramites'),
  _cat('c-impuestos', 'Impuestos', padre: 'c-tramites'),
];

/// Pagos que salen: en su fecha (regla 5 de 4.5).
const _enSuFecha = ReglaDiaInhabil.sinCambio;

final ingresosEjemplo = [
  Ingreso(
    id: 'ing-ana',
    libroId: casa,
    personaId: ana,
    nombre: 'Sueldo de Ana (neto)',
    cuentaOrigenId: 'sueldo-ana',
    cuentaDestinoId: 'banco-casa',
    vigencias: [
      VigenciaIngreso(
        id: 'vig-ana',
        ingresoId: 'ing-ana',
        montoNeto: 900000,
        calendario: const CalendarioConfig.quincenal(),
        desde: Fecha(2026, 1, 1),
      ),
    ],
  ),
  Ingreso(
    id: 'ing-alex',
    libroId: casa,
    personaId: alex,
    nombre: 'Sueldo de Alex (neto)',
    cuentaOrigenId: 'sueldo-alex',
    cuentaDestinoId: 'banco-casa',
    vigencias: [
      VigenciaIngreso(
        id: 'vig-alex',
        ingresoId: 'ing-alex',
        montoNeto: 1400000,
        calendario: const CalendarioConfig.mensual([0]),
        desde: Fecha(2026, 1, 1),
      ),
    ],
  ),
  // Libro de papá (P15): pensión los días 1 y 11 y apoyo 60+ bimestral.
  Ingreso(
    id: 'ing-pension',
    libroId: libroPapa,
    personaId: papa,
    nombre: 'Pensión',
    tipo: TipoIngreso.pension,
    cuentaOrigenId: 'pension-papa',
    cuentaDestinoId: 'banco-papa',
    vigencias: [
      VigenciaIngreso(
        id: 'vig-pension',
        ingresoId: 'ing-pension',
        montoNeto: 250000,
        calendario: const CalendarioConfig.mensual([1, 11]),
        desde: Fecha(2026, 1, 1),
      ),
    ],
  ),
  Ingreso(
    id: 'ing-apoyo',
    libroId: libroPapa,
    personaId: papa,
    nombre: 'Apoyo 60+',
    tipo: TipoIngreso.otro,
    certeza: Certeza.probable,
    cuentaOrigenId: 'apoyo-papa',
    cuentaDestinoId: 'banco-papa',
    vigencias: [
      VigenciaIngreso(
        id: 'vig-apoyo',
        ingresoId: 'ing-apoyo',
        montoNeto: 620000,
        calendario: CalendarioConfig.cadaMeses(Fecha(2026, 9, 1), 2),
        desde: Fecha(2026, 1, 1),
      ),
    ],
  ),
];

Compromiso _fijo(
  String id,
  String nombre,
  int monto,
  Frecuencia frecuencia,
  String categoria,
  String cuenta,
  CalendarioConfig calendario, {
  bool protegida = false,
  TipoCompromiso tipo = TipoCompromiso.fija,
}) => Compromiso(
  id: id,
  libroId: casa,
  nombre: nombre,
  tipo: tipo,
  cuentaGastoId: cuenta,
  categoriaId: categoria,
  monto: monto,
  frecuencia: frecuencia,
  calendario: calendario,
  protegida: protegida,
);

final compromisosEjemplo = [
  _fijo(
    'renta',
    'Renta',
    800000,
    Frecuencia.mensual,
    'c-renta',
    'g-vivienda',
    const CalendarioConfig.mensual([1], regla: _enSuFecha),
    protegida: true,
  ),
  _fijo(
    'luz',
    'Luz',
    90000,
    Frecuencia.bimestral,
    'c-luz',
    'g-vivienda',
    CalendarioConfig.cadaMeses(Fecha(2026, 1, 10), 2, regla: _enSuFecha),
    protegida: true,
  ),
  _fijo(
    'agua',
    'Agua',
    30000,
    Frecuencia.mensual,
    'c-agua',
    'g-vivienda',
    const CalendarioConfig.mensual([5], regla: _enSuFecha),
    protegida: true,
  ),
  _fijo(
    'internet',
    'Internet',
    40000,
    Frecuencia.mensual,
    'c-internet',
    'g-vivienda',
    const CalendarioConfig.mensual([20], regla: _enSuFecha),
    protegida: true,
  ),
  _fijo(
    'celular',
    'Celular',
    35000,
    Frecuencia.mensual,
    'c-celular',
    'g-tecnologia',
    const CalendarioConfig.mensual([15], regla: _enSuFecha),
  ),
  _fijo(
    'placas-predial',
    'Reserva: placas y predial',
    156000,
    Frecuencia.anual,
    'c-impuestos',
    'g-tramites',
    CalendarioConfig.cadaMeses(Fecha(2027, 1, 15), 12, regla: _enSuFecha),
    tipo: TipoCompromiso.reserva,
  ),
];

Sobre _sobre(
  String id,
  String nombre,
  int monto,
  String cuenta, [
  Prioridad prioridad = Prioridad.deseable,
]) => Sobre(
  id: id,
  libroId: casa,
  cuentaGastoId: cuenta,
  nombre: nombre,
  montoSemanal: monto,
  prioridad: prioridad,
);

final sobresEjemplo = [
  _sobre(
    'alimentacion',
    'Alimentación',
    150000,
    'g-alimentacion',
    Prioridad.necesario,
  ),
  _sobre(
    'transporte',
    'Transporte',
    70000,
    'g-transporte',
    Prioridad.necesario,
  ),
  _sobre('salud', 'Salud', 30000, 'g-salud'),
  _sobre('limpieza', 'Limpieza', 15000, 'g-limpieza'),
  _sobre('cuidado-personal', 'Cuidado personal', 15000, 'g-cuidado'),
  _sobre(
    'entretenimiento',
    'Entretenimiento',
    25000,
    'g-entretenimiento',
    Prioridad.discrecional,
  ),
  _sobre(
    'vestimenta',
    'Vestimenta',
    20000,
    'g-vestimenta',
    Prioridad.discrecional,
  ),
];

final deudasEjemplo = [
  const Deuda(
    id: 'deuda-tarjeta',
    libroId: casa,
    nombre: 'Tarjeta de crédito',
    tipo: TipoDeuda.conCosto,
    cuentaPasivoId: 'tarjeta',
    abono: 120000,
    frecuencia: Frecuencia.mensual,
    calendario: CalendarioConfig.mensual([20], regla: _enSuFecha),
    tasaAnualPuntosBase: 4800,
  ),
  const Deuda(
    id: 'deuda-familiar',
    libroId: casa,
    nombre: 'Préstamo familiar',
    tipo: TipoDeuda.familiar,
    cuentaPasivoId: 'prestamo-fam',
    abono: 50000,
    frecuencia: Frecuencia.mensual,
    calendario: CalendarioConfig.mensual([25], regla: _enSuFecha),
  ),
];

final _registro = DateTime(2026, 10, 19, 9);

Movimiento apertura(
  String id,
  String cuenta,
  String contra,
  int monto, {
  bool pasivo = false,
}) => Movimiento(
  id: id,
  tipo: TipoMovimiento.apertura,
  fecha: Fecha(2026, 10, 19),
  registradoEn: _registro,
  cuentaOrigenId: pasivo ? cuenta : contra,
  cuentaDestinoId: pasivo ? contra : cuenta,
  monto: monto,
  realizadoPor: ana,
);

final movimientosEjemplo = [
  apertura('ap-banco-casa', 'banco-casa', 'apertura-casa', 500000),
  apertura('ap-tarjeta', 'tarjeta', 'apertura-casa', 600000, pasivo: true),
  apertura(
    'ap-prestamo',
    'prestamo-fam',
    'apertura-casa',
    300000,
    pasivo: true,
  ),
  apertura('ap-banco-ana', 'banco-ana', 'apertura-ana', 1000000),
  apertura('ap-banco-papa', 'banco-papa', 'apertura-papa', 150000),
];

/// El hogar de ejemplo completo.
DatosFinanzas hogarEjemplo({
  List<Movimiento> movimientos = const [],
  List<Deuda>? deudas,
  List<DiaInhabil> diasInhabiles = const [],
}) => DatosFinanzas(
  libros: librosEjemplo,
  cuentas: cuentasEjemplo,
  categorias: categoriasEjemplo,
  ingresos: ingresosEjemplo,
  compromisos: compromisosEjemplo,
  sobres: sobresEjemplo,
  deudas: deudas ?? deudasEjemplo,
  diasInhabiles: diasInhabiles,
  movimientos: [...movimientosEjemplo, ...movimientos],
);

/// Un gasto de ejemplo.
Movimiento gasto(
  String id,
  Fecha fecha,
  int monto,
  String cuentaGasto, {
  String origen = 'banco-casa',
  String? categoria,
  String por = ana,
}) => Movimiento(
  id: id,
  tipo: TipoMovimiento.gasto,
  fecha: fecha,
  registradoEn: DateTime(fecha.anio, fecha.mes, fecha.dia, 12),
  cuentaOrigenId: origen,
  cuentaDestinoId: cuentaGasto,
  monto: monto,
  realizadoPor: por,
  categoriaId: categoria,
);
