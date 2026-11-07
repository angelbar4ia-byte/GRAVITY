import 'package:finanzas_dominio/finanzas_dominio.dart';
import 'package:test/test.dart';

// Fase 5, criterio 3: el resumen mensual del costo del cuidado y de la casa
// no lleva montos de la pareja ni del dueño. Datos ilustrativos.
const dueno = 'dueno';
const pareja = 'pareja';
const papa = 'papa';
const hermana = 'hermana';
const casa = 'libro-casa';
const libroPapa = 'libro-papa';
const libroDueno = 'libro-dueno';

final registrado = DateTime.utc(2026, 11, 7, 12);

LibroMovimientos base() => LibroMovimientos(
  cuentas: const [
    Cuenta(
      id: 'banco-casa',
      nombre: 'Banco casa',
      tipo: TipoCuenta.banco,
      libroId: casa,
    ),
    Cuenta(
      id: 'banco-papa',
      nombre: 'Banco Papá',
      tipo: TipoCuenta.banco,
      libroId: libroPapa,
    ),
    Cuenta(
      id: 'banco-dueno',
      nombre: 'Mi banco',
      tipo: TipoCuenta.banco,
      libroId: libroDueno,
    ),
    Cuenta(id: 'salud', nombre: 'Salud', tipo: TipoCuenta.deGasto),
    Cuenta(
      id: 'alimentacion',
      nombre: 'Alimentación',
      tipo: TipoCuenta.deGasto,
    ),
    Cuenta(
      id: 'vivienda',
      nombre: 'Vivienda y servicios',
      tipo: TipoCuenta.deGasto,
    ),
    Cuenta(
      id: 'sueldo',
      nombre: 'Sueldo',
      tipo: TipoCuenta.origenIngreso,
      libroId: casa,
    ),
    Cuenta(id: 'sin-libro', nombre: 'Sin libro', tipo: TipoCuenta.banco),
    Cuenta(
      id: 'ajustes',
      nombre: 'Ajustes',
      tipo: TipoCuenta.ajustes,
      libroId: casa,
    ),
  ],
);

var _n = 0;
Movimiento mov(
  TipoMovimiento tipo,
  String origen,
  String destino,
  int monto, {
  Fecha? fecha,
  String quien = dueno,
  String? enNombreDe,
  String? motivo,
  EstadoMovimiento estado = EstadoMovimiento.confirmado,
}) => Movimiento(
  id: 'm${_n++}',
  tipo: tipo,
  fecha: fecha ?? Fecha(2026, 10, 15),
  registradoEn: registrado,
  cuentaOrigenId: origen,
  cuentaDestinoId: destino,
  monto: monto,
  realizadoPor: quien,
  registradoPor: dueno,
  enNombreDe: enNombreDe,
  motivo: motivo,
  estadoInicial: estado,
);

Movimiento deLaCasa(int monto, String rubro, {String quien = hermana}) =>
    mov(TipoMovimiento.gasto, 'banco-casa', rubro, monto, quien: quien);

Movimiento dePapa(int monto, String rubro) => mov(
  TipoMovimiento.gasto,
  'banco-papa',
  rubro,
  monto,
  quien: papa,
  enNombreDe: papa,
  motivo: 'Cuidado de Papá',
);

ResumenMensualCuidado resumir(LibroMovimientos l) => resumenMensualCuidado(
  anio: 2026,
  mes: 10,
  libro: l,
  librosIncluidos: {casa, libroPapa},
  personasExcluidas: {dueno, pareja},
);

void main() {
  test('suma por rubro lo de Papá (que captura el albacea) y lo de la casa '
      'que no es del dueño ni de la pareja', () {
    final l = base()
      ..agregar(dePapa(120050, 'salud'))
      ..agregar(dePapa(30025, 'salud'))
      ..agregar(deLaCasa(80000, 'alimentacion'))
      ..agregar(deLaCasa(45075, 'vivienda'));
    final r = resumir(l);
    expect(r.totalCentavos, 120050 + 30025 + 80000 + 45075);
    expect(r.lineas.map((x) => (x.categoria, x.centavos)).toList(), [
      ('Salud', 150075),
      ('Alimentación', 80000),
      ('Vivienda y servicios', 45075),
    ]);
  });

  test('no incluye gastos del dueño ni de la pareja (criterio 3)', () {
    final l = base()
      ..agregar(deLaCasa(80000, 'alimentacion'))
      ..agregar(deLaCasa(999900, 'alimentacion', quien: dueno))
      ..agregar(deLaCasa(777700, 'vivienda', quien: pareja))
      ..agregar(mov(TipoMovimiento.gasto, 'banco-dueno', 'salud', 555500));
    final r = resumir(l);
    expect(r.totalCentavos, 80000);
    expect(r.lineas, hasLength(1));
    expect(r.lineas.single.centavos, 80000);
    // El resultado solo tiene rubros y montos, ninguna persona ni libro.
    final texto = r.lineas.map((x) => x.toString()).join();
    for (final no in [dueno, pareja, hermana, papa, casa, libroPapa]) {
      expect(texto.contains(no), isFalse, reason: no);
    }
  });

  test('solo cuentan los libros incluidos y falla cerrado con cuentas '
      'desconocidas', () {
    final l = base()
      ..agregar(
        mov(
          TipoMovimiento.gasto,
          'banco-dueno',
          'salud',
          10000,
          quien: hermana,
        ),
      )
      ..agregar(
        mov(TipoMovimiento.gasto, 'sin-libro', 'salud', 20000, quien: hermana),
      )
      ..agregar(deLaCasa(5000, 'salud'));
    expect(resumir(l).totalCentavos, 5000);
  });

  test('solo el mes pedido, y solo lo confirmado', () {
    final l = base()
      ..agregar(deLaCasa(1000, 'salud'))
      ..agregar(
        mov(
          TipoMovimiento.gasto,
          'banco-casa',
          'salud',
          2000,
          quien: hermana,
          fecha: Fecha(2026, 9, 30),
        ),
      )
      ..agregar(
        mov(
          TipoMovimiento.gasto,
          'banco-casa',
          'salud',
          4000,
          quien: hermana,
          fecha: Fecha(2026, 11, 1),
        ),
      )
      ..agregar(
        mov(
          TipoMovimiento.gasto,
          'banco-casa',
          'salud',
          8000,
          quien: hermana,
          estado: EstadoMovimiento.pendiente,
        ),
      );
    expect(resumir(l).totalCentavos, 1000);
  });

  test('un gasto anulado no cuenta, ni su contraasiento', () {
    final l = base();
    final g = l.agregar(dePapa(50000, 'salud'));
    l.agregar(deLaCasa(1234, 'salud'));
    l.anular(
      g.id,
      nuevoId: 'anula',
      motivo: 'Capturado dos veces',
      registradoPor: dueno,
      registradoEn: registrado,
    );
    final r = resumir(l);
    expect(r.totalCentavos, 1234);
  });

  test(
    'un reembolso resta del rubro; ingresos y transferencias no cuentan',
    () {
      final l = base()
        ..agregar(dePapa(100001, 'salud'))
        ..agregar(
          mov(
            TipoMovimiento.reembolso,
            'salud',
            'banco-papa',
            25001,
            quien: papa,
            enNombreDe: papa,
            motivo: 'Reembolso del seguro',
          ),
        )
        ..agregar(mov(TipoMovimiento.ingreso, 'sueldo', 'banco-casa', 900000))
        ..agregar(
          mov(TipoMovimiento.transferencia, 'banco-dueno', 'banco-casa', 5000),
        );
      final r = resumir(l);
      expect(r.totalCentavos, 75000);
    },
  );

  test('mes sin gastos: resumen vacío en cero', () {
    final r = resumenMensualCuidado(
      anio: 2026,
      mes: 3,
      libro: base()..agregar(deLaCasa(1000, 'salud')),
      librosIncluidos: {casa},
      personasExcluidas: {},
    );
    expect(r.vacio, isTrue);
    expect(r.totalCentavos, 0);
  });

  test('empate de monto: orden por nombre', () {
    final l = base()
      ..agregar(deLaCasa(1000, 'vivienda'))
      ..agregar(deLaCasa(1000, 'alimentacion'));
    expect(resumir(l).lineas.map((x) => x.categoria), [
      'Alimentación',
      'Vivienda y servicios',
    ]);
  });
}
