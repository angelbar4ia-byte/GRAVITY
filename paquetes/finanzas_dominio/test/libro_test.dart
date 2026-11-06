import 'package:finanzas_dominio/finanzas_dominio.dart';
import 'package:test/test.dart';

const yo = 'persona-dueno';
const pareja = 'persona-pareja';
final ahora = DateTime.utc(2026, 10, 20, 12);
final dia = Fecha(2026, 10, 20);

LibroMovimientos libroBase() => LibroMovimientos(
  cuentas: const [
    Cuenta(id: 'banco', nombre: 'Banco', tipo: TipoCuenta.banco),
    Cuenta(id: 'efectivo', nombre: 'Efectivo', tipo: TipoCuenta.efectivo),
    Cuenta(id: 'ahorro', nombre: 'Ahorro', tipo: TipoCuenta.ahorro),
    Cuenta(id: 'tarjeta', nombre: 'Tarjeta', tipo: TipoCuenta.tarjeta),
    Cuenta(id: 'salario', nombre: 'Salario', tipo: TipoCuenta.origenIngreso),
    Cuenta(
      id: 'alimentacion',
      nombre: 'Alimentación',
      tipo: TipoCuenta.deGasto,
    ),
    Cuenta(id: 'vestimenta', nombre: 'Vestimenta', tipo: TipoCuenta.deGasto),
    Cuenta(id: 'salud', nombre: 'Salud', tipo: TipoCuenta.deGasto),
    Cuenta(
      id: 'financiero',
      nombre: 'Gasto financiero',
      tipo: TipoCuenta.gastoFinanciero,
    ),
    Cuenta(
      id: 'por-clasificar',
      nombre: 'Por clasificar',
      tipo: TipoCuenta.porClasificar,
    ),
    Cuenta(id: 'ajustes', nombre: 'Ajustes', tipo: TipoCuenta.ajustes),
    Cuenta(id: 'apertura', nombre: 'Apertura', tipo: TipoCuenta.apertura),
  ],
);

var _n = 0;
Movimiento mov(
  TipoMovimiento tipo,
  String origen,
  String destino,
  int monto, {
  Fecha? fecha,
  String? id,
  String quien = yo,
  String? motivo,
  String? grupo,
  EstadoMovimiento estado = EstadoMovimiento.confirmado,
}) => Movimiento(
  id: id ?? 'm${_n++}',
  tipo: tipo,
  fecha: fecha ?? dia,
  registradoEn: ahora,
  cuentaOrigenId: origen,
  cuentaDestinoId: destino,
  monto: monto,
  realizadoPor: quien,
  motivo: motivo,
  grupoId: grupo,
  estadoInicial: estado,
);

/// Ejemplo numérico verificado de 5.0 bis 2, punto 3.
LibroMovimientos libroDelEjemplo() {
  final libro = libroBase();
  final apertura = Fecha(2026, 10, 19);
  libro
    ..agregar(
      mov(
        TipoMovimiento.apertura,
        'apertura',
        'banco',
        500000,
        fecha: apertura,
      ),
    )
    ..agregar(
      mov(
        TipoMovimiento.apertura,
        'apertura',
        'efectivo',
        80000,
        fecha: apertura,
      ),
    )
    ..agregar(
      mov(
        TipoMovimiento.apertura,
        'apertura',
        'ahorro',
        1000000,
        fecha: apertura,
      ),
    )
    ..agregar(
      mov(
        TipoMovimiento.apertura,
        'tarjeta',
        'apertura',
        300000,
        fecha: apertura,
      ),
    )
    // 1. Sueldo $9,000 al banco.
    ..agregar(mov(TipoMovimiento.ingreso, 'salario', 'banco', 900000))
    // 2. Súper $620 en efectivo.
    ..agregar(mov(TipoMovimiento.gasto, 'efectivo', 'alimentacion', 62000))
    // 3. Ropa $400 con tarjeta.
    ..agregar(mov(TipoMovimiento.gasto, 'tarjeta', 'vestimenta', 40000))
    // 4. Pago de tarjeta $1,200: capital $1,100 e intereses $100.
    ..agregar(
      mov(
        TipoMovimiento.pagoDeuda,
        'banco',
        'tarjeta',
        110000,
        grupo: 'pago-1',
      ),
    )
    ..agregar(
      mov(TipoMovimiento.gasto, 'banco', 'financiero', 10000, grupo: 'pago-1'),
    )
    // 5. Aportación al ahorro $1,500.
    ..agregar(mov(TipoMovimiento.transferencia, 'banco', 'ahorro', 150000));
  return libro;
}

void main() {
  group('5.0 bis 2, prueba 1: ejemplo numérico verificado', () {
    test('saldos de apertura', () {
      final b = libroDelEjemplo().balance(al: Fecha(2026, 10, 19));
      expect(b.activos, 1580000);
      expect(b.pasivos, 300000);
      expect(b.patrimonio, 1280000);
      expect(b.patrimonioInicial, 1280000);
    });

    test('saldos al cierre', () {
      final libro = libroDelEjemplo();
      expect(libro.saldo('banco'), 1130000);
      expect(libro.saldo('efectivo'), 18000);
      expect(libro.saldo('ahorro'), 1150000);
      expect(libro.saldo('tarjeta'), 230000); // lo que se debe
    });

    test('activos \$22,980; pasivos \$2,300; patrimonio \$20,680; resultado '
        '\$7,880; cuadre en cero', () {
      final libro = libroDelEjemplo();
      final b = libro.balance();
      expect(b.activos, 2298000);
      expect(b.pasivos, 230000);
      expect(b.patrimonio, 2068000);
      expect(b.resultadoAcumulado, 788000);
      expect(b.descuadre, 0);
      expect(b.cuadra, isTrue);

      final r = libro.estadoResultados(Periodo.semana(dia));
      expect(r.ingresos, 900000);
      expect(r.gastos, 102000); // 620 + 400
      expect(r.gastoFinanciero, 10000); // aparte
      expect(r.resultado, 788000);
    });

    test('disponible: solo efectivo y bancos', () {
      expect(libroDelEjemplo().disponible(), 1148000); // 11,300 + 180
    });
  });

  group('Reglas contables (5.0 bis 2, pruebas 2 a 4)', () {
    test('2: compra con tarjeta sube el pasivo y no baja el efectivo; el pago '
        'de capital baja ambos', () {
      final libro = libroBase()
        ..agregar(mov(TipoMovimiento.apertura, 'apertura', 'banco', 100000));
      libro.agregar(mov(TipoMovimiento.gasto, 'tarjeta', 'vestimenta', 40000));
      expect(libro.saldo('tarjeta'), 40000);
      expect(libro.saldo('banco'), 100000);
      libro.agregar(mov(TipoMovimiento.pagoDeuda, 'banco', 'tarjeta', 40000));
      expect(libro.saldo('tarjeta'), 0);
      expect(libro.saldo('banco'), 60000);
    });

    test('3: una aportación a ahorro no cambia el patrimonio', () {
      final libro = libroBase()
        ..agregar(mov(TipoMovimiento.apertura, 'apertura', 'banco', 100000));
      final antes = libro.balance().patrimonio;
      libro.agregar(
        mov(TipoMovimiento.transferencia, 'banco', 'ahorro', 50000),
      );
      expect(libro.balance().patrimonio, antes);
    });

    test('un reembolso baja el gasto y no es ingreso (IN8)', () {
      final libro = libroBase()
        ..agregar(mov(TipoMovimiento.apertura, 'apertura', 'banco', 100000))
        ..agregar(mov(TipoMovimiento.gasto, 'banco', 'salud', 80000))
        ..agregar(mov(TipoMovimiento.reembolso, 'salud', 'banco', 50000));
      final r = libro.estadoResultados(Periodo.semana(dia));
      expect(r.gastos, 30000);
      expect(r.ingresos, 0);
      expect(libro.saldo('banco'), 70000);
    });

    test('combinaciones inválidas se rechazan', () {
      final libro = libroBase();
      expect(
        () =>
            libro.agregar(mov(TipoMovimiento.ingreso, 'banco', 'salario', 100)),
        throwsA(isA<ErrorLibro>()),
      );
      expect(
        () => libro.agregar(mov(TipoMovimiento.gasto, 'salario', 'salud', 100)),
        throwsA(isA<ErrorLibro>()),
      );
      expect(
        () => libro.agregar(
          mov(TipoMovimiento.transferencia, 'banco', 'tarjeta', 100),
        ),
        throwsA(isA<ErrorLibro>()),
      );
      expect(
        () => libro.agregar(mov(TipoMovimiento.gasto, 'banco', 'banco', 100)),
        throwsA(isA<ErrorLibro>()),
      );
      expect(
        () => libro.agregar(mov(TipoMovimiento.gasto, 'banco', 'salud', 0)),
        throwsA(isA<ErrorLibro>()),
      );
      expect(
        () =>
            libro.agregar(mov(TipoMovimiento.gasto, 'banco', 'no-existe', 100)),
        throwsA(isA<ErrorLibro>()),
      );
    });

    test('una sola apertura por cuenta', () {
      final libro = libroBase()
        ..agregar(mov(TipoMovimiento.apertura, 'apertura', 'banco', 100000));
      expect(
        () =>
            libro.agregar(mov(TipoMovimiento.apertura, 'apertura', 'banco', 5)),
        throwsA(isA<ErrorLibro>()),
      );
    });

    test('reclasificar desde "Por clasificar"', () {
      final libro = libroBase()
        ..agregar(
          mov(TipoMovimiento.gasto, 'efectivo', 'por-clasificar', 15000),
        );
      final semana = Periodo.semana(dia);
      expect(libro.gastoPorCuenta(semana)['por-clasificar'], 15000);
      libro.agregar(
        mov(
          TipoMovimiento.reclasificacion,
          'por-clasificar',
          'alimentacion',
          15000,
        ),
      );
      final gasto = libro.gastoPorCuenta(semana);
      expect(gasto['por-clasificar'], 0);
      expect(gasto['alimentacion'], 15000);
      expect(
        () => libro.agregar(
          mov(TipoMovimiento.reclasificacion, 'alimentacion', 'salud', 100),
        ),
        throwsA(isA<ErrorLibro>()),
      );
    });
  });

  group('Solo-agregar: anulación con contraasiento (5.0 bis)', () {
    test('la anulación invierte origen y destino y deja el original', () {
      final libro = libroBase();
      final gasto = libro.agregar(
        mov(TipoMovimiento.gasto, 'efectivo', 'alimentacion', 62000),
      );
      final contra = libro.anular(
        gasto.id,
        nuevoId: 'anula-1',
        motivo: 'Capturado dos veces',
        registradoPor: yo,
        registradoEn: ahora.add(const Duration(days: 9)),
      );
      expect(contra.tipo, TipoMovimiento.anulacion);
      expect(contra.cuentaOrigenId, 'alimentacion');
      expect(contra.cuentaDestinoId, 'efectivo');
      expect(contra.monto, 62000);
      expect(contra.anulaA, gasto.id);
      expect(contra.fecha, gasto.fecha); // misma semana económica
      expect(libro.movimientos.length, 2); // el original sigue ahí
      expect(libro.estaAnulado(gasto.id), isTrue);
      expect(libro.saldo('efectivo'), 0);
      expect(libro.gastoPorCuenta(Periodo.semana(dia))['alimentacion'], 0);
    });

    test(
      'motivo obligatorio; no se anula dos veces ni se anula una anulación',
      () {
        final libro = libroBase();
        final gasto = libro.agregar(
          mov(TipoMovimiento.gasto, 'efectivo', 'salud', 1000),
        );
        expect(
          () => libro.anular(
            gasto.id,
            nuevoId: 'a0',
            motivo: '  ',
            registradoPor: yo,
            registradoEn: ahora,
          ),
          throwsA(isA<ErrorLibro>()),
        );
        final contra = libro.anular(
          gasto.id,
          nuevoId: 'a1',
          motivo: 'error',
          registradoPor: yo,
          registradoEn: ahora,
        );
        expect(
          () => libro.anular(
            gasto.id,
            nuevoId: 'a2',
            motivo: 'otra vez',
            registradoPor: yo,
            registradoEn: ahora,
          ),
          throwsA(isA<ErrorLibro>()),
        );
        expect(
          () => libro.anular(
            contra.id,
            nuevoId: 'a3',
            motivo: 'deshacer',
            registradoPor: yo,
            registradoEn: ahora,
          ),
          throwsA(isA<ErrorLibro>()),
        );
      },
    );

    test('un contraasiento hecho a mano debe invertir exactamente', () {
      final libro = libroBase();
      final gasto = libro.agregar(
        mov(TipoMovimiento.gasto, 'efectivo', 'salud', 1000),
      );
      expect(
        () => libro.agregar(
          Movimiento(
            id: 'mal',
            tipo: TipoMovimiento.anulacion,
            fecha: dia,
            registradoEn: ahora,
            cuentaOrigenId: 'salud',
            cuentaDestinoId: 'efectivo',
            monto: 500, // parcial: no se permite
            realizadoPor: yo,
            motivo: 'parcial',
            anulaA: gasto.id,
          ),
        ),
        throwsA(isA<ErrorLibro>()),
      );
    });

    test('no hay forma de editar: mismo id con otro contenido falla; igual es '
        'idempotente', () {
      final libro = libroBase();
      final original = mov(
        TipoMovimiento.gasto,
        'efectivo',
        'salud',
        1000,
        id: 'uuid-1',
      );
      libro.agregar(original);
      libro.agregar(
        mov(TipoMovimiento.gasto, 'efectivo', 'salud', 1000, id: 'uuid-1'),
      );
      expect(libro.movimientos.length, 1);
      expect(
        () => libro.agregar(
          mov(TipoMovimiento.gasto, 'efectivo', 'salud', 2000, id: 'uuid-1'),
        ),
        throwsA(isA<ErrorLibro>()),
      );
      expect(() => libro.movimientos.add(original), throwsUnsupportedError);
    });

    test('5.6 bis, prueba 9: corregir un gasto de una semana cerrada', () {
      final libro = libroBase();
      final semanaPasada = Fecha(2026, 10, 14);
      final gasto = libro.agregar(
        mov(
          TipoMovimiento.gasto,
          'efectivo',
          'alimentacion',
          50000,
          fecha: semanaPasada,
        ),
      );
      // Foto del cierre de esa semana (se guarda aparte y no cambia).
      final foto = libro.gastoPorCuenta(
        Periodo.semana(semanaPasada),
      )['alimentacion'];
      // Corrección: anulación más el movimiento correcto.
      libro.anular(
        gasto.id,
        nuevoId: 'c1',
        motivo: 'Eran \$400',
        registradoPor: yo,
        registradoEn: ahora,
      );
      libro.agregar(
        mov(
          TipoMovimiento.gasto,
          'efectivo',
          'alimentacion',
          40000,
          fecha: semanaPasada,
        ),
      );
      expect(foto, 50000);
      expect(
        libro.gastoPorCuenta(Periodo.semana(semanaPasada))['alimentacion'],
        40000,
      );
      expect(libro.movimientos.length, 3);
    });

    test('5.0 bis 2, prueba 8: una corrección con fecha posterior no cambia el '
        'balance de un cierre', () {
      final libro = libroDelEjemplo();
      final cierre = libro.balance(al: dia).patrimonio;
      final gasto = libro.movimientos.firstWhere(
        (m) => m.cuentaDestinoId == 'vestimenta',
      );
      libro.anular(
        gasto.id,
        nuevoId: 'c-posterior',
        motivo: 'Devolución en tienda',
        registradoPor: yo,
        registradoEn: ahora,
        fecha: Fecha(2026, 10, 27),
      );
      expect(libro.balance(al: dia).patrimonio, cierre);
      expect(libro.balance().patrimonio, cierre + 40000);
    });
  });

  group('Confirmaciones (5.0 ter; base para la Fase 8)', () {
    test('7: un pendiente no altera el saldo confirmado pero sí el saldo con '
        'pendientes', () {
      final libro = libroBase()
        ..agregar(mov(TipoMovimiento.apertura, 'apertura', 'banco', 100000));
      final t = libro.agregar(
        mov(
          TipoMovimiento.transferencia,
          'banco',
          'efectivo',
          30000,
          estado: EstadoMovimiento.pendiente,
        ),
      );
      expect(libro.saldo('efectivo'), 0);
      expect(libro.saldo('efectivo', incluirPendientes: true), 30000);
      libro.confirmar(t.id, por: pareja, fechaHora: ahora);
      expect(libro.estadoDe(t.id), EstadoMovimiento.confirmado);
      expect(libro.saldo('efectivo'), 30000);
    });

    test('quien registra no confirma; el albacea confirma con motivo', () {
      final libro = libroBase();
      final t = libro.agregar(
        mov(
          TipoMovimiento.transferencia,
          'banco',
          'efectivo',
          100,
          estado: EstadoMovimiento.pendiente,
        ),
      );
      expect(
        () => libro.confirmar(t.id, por: yo, fechaHora: ahora),
        throwsA(isA<ErrorLibro>()),
      );
      expect(
        () => libro.confirmar(
          t.id,
          por: 'albacea',
          enNombreDe: pareja,
          fechaHora: ahora,
        ),
        throwsA(isA<ErrorLibro>()),
      );
      libro.confirmar(
        t.id,
        por: 'albacea',
        enNombreDe: pareja,
        motivo: 'No usa teléfono',
        fechaHora: ahora,
      );
      expect(libro.confirmaciones.single.enNombreDe, pareja);
      expect(
        () => libro.confirmar(t.id, por: pareja, fechaHora: ahora),
        throwsA(isA<ErrorLibro>()),
      );
    });

    test('un rechazado sale de todos los saldos; en revisión cuenta como pendiente', () {
      final libro = libroBase();
      final a = libro.agregar(
        mov(
          TipoMovimiento.transferencia,
          'banco',
          'efectivo',
          100,
          estado: EstadoMovimiento.pendiente,
        ),
      );
      final b = libro.agregar(
        mov(
          TipoMovimiento.transferencia,
          'banco',
          'efectivo',
          200,
          estado: EstadoMovimiento.pendiente,
        ),
      );
      libro.rechazar(
        a.id,
        por: pareja,
        fechaHora: ahora,
        motivo: 'No lo recibí',
      );
      libro.marcarEnRevision(
        b.id,
        por: pareja,
        fechaHora: ahora,
        motivo: 'Fueron 150',
      );
      expect(libro.saldo('efectivo', incluirPendientes: true), 200);
      expect(libro.saldo('efectivo'), 0);
      expect(
        () => libro.anular(
          a.id,
          nuevoId: 'x',
          motivo: 'm',
          registradoPor: yo,
          registradoEn: ahora,
        ),
        throwsA(isA<ErrorLibro>()),
      );
    });

    test('una anulación pendiente no anula hasta confirmarse', () {
      final libro = libroBase();
      final g = libro.agregar(
        mov(TipoMovimiento.gasto, 'efectivo', 'alimentacion', 4500),
      );
      final c = libro.anular(
        g.id,
        nuevoId: 'an',
        motivo: 'Error de captura',
        registradoPor: yo,
        registradoEn: ahora,
        estado: EstadoMovimiento.pendiente,
      );
      expect(libro.estaAnulado(g.id), isFalse);
      expect(libro.contraasientoDe(g.id), c);
      libro.confirmar(c.id, por: pareja, fechaHora: ahora);
      expect(libro.estaAnulado(g.id), isTrue);
    });
  });

  group('Ciclo de vida de las cuentas (5.0 bis 2, prueba 6)', () {
    test(
      'no se borra una cuenta con movimientos; sí se cierra con saldo cero',
      () {
        final libro = libroBase()
          ..agregar(mov(TipoMovimiento.apertura, 'apertura', 'efectivo', 1000));
        expect(
          () => libro.eliminarCuenta('efectivo'),
          throwsA(isA<ErrorLibro>()),
        );
        expect(
          () => libro.cambiarEstadoCuenta('efectivo', EstadoCuenta.cerrada),
          throwsA(isA<ErrorLibro>()),
        );
        libro.agregar(
          mov(TipoMovimiento.transferencia, 'efectivo', 'banco', 1000),
        );
        libro.cambiarEstadoCuenta('efectivo', EstadoCuenta.cerrada);
        expect(libro.cuenta('efectivo').estado, EstadoCuenta.cerrada);
        expect(
          () =>
              libro.agregar(mov(TipoMovimiento.gasto, 'efectivo', 'salud', 1)),
          throwsA(isA<ErrorLibro>()),
        );
        libro.eliminarCuenta('vestimenta'); // sin movimientos: sí se elimina
        expect(libro.cuentas.any((c) => c.id == 'vestimenta'), isFalse);
      },
    );

    test('una cuenta congelada no admite movimientos nuevos', () {
      final libro = libroBase()
        ..cambiarEstadoCuenta('efectivo', EstadoCuenta.congelada);
      expect(
        () => libro.agregar(mov(TipoMovimiento.gasto, 'efectivo', 'salud', 1)),
        throwsA(isA<ErrorLibro>()),
      );
    });
  });

  group('Conciliación (5.0 bis 2, prueba 5)', () {
    test('con diferencia crea un ajuste con motivo en la cuenta Ajustes', () {
      final libro = libroBase()
        ..agregar(mov(TipoMovimiento.apertura, 'apertura', 'efectivo', 80000));
      expect(
        () => libro.conciliar(
          cuentaId: 'efectivo',
          fecha: dia,
          saldoDeclarado: 75000,
          cuentaAjustesId: 'ajustes',
          idAjuste: 'aj-1',
          persona: yo,
          registradoEn: ahora,
        ),
        throwsA(isA<ErrorLibro>()), // falta el motivo
      );
      final c = libro.conciliar(
        cuentaId: 'efectivo',
        fecha: dia,
        saldoDeclarado: 75000,
        cuentaAjustesId: 'ajustes',
        idAjuste: 'aj-1',
        persona: yo,
        registradoEn: ahora,
        motivo: 'Gasto hormiga sin capturar',
      );
      expect(c.diferencia, -5000);
      expect(c.ajuste!.tipo, TipoMovimiento.ajuste);
      expect(c.ajuste!.cuentaDestinoId, 'ajustes');
      expect(libro.saldo('efectivo'), 75000);
      expect(libro.balance().ajustes, -5000);
      expect(libro.balance().cuadra, isTrue);
    });

    test('en una tarjeta, una deuda mayor a la calculada sube el pasivo', () {
      final libro = libroBase()
        ..agregar(mov(TipoMovimiento.apertura, 'tarjeta', 'apertura', 100000));
      libro.conciliar(
        cuentaId: 'tarjeta',
        fecha: dia,
        saldoDeclarado: 101500,
        cuentaAjustesId: 'ajustes',
        idAjuste: 'aj-2',
        persona: yo,
        registradoEn: ahora,
        motivo: 'Intereses del estado de cuenta',
      );
      expect(libro.saldo('tarjeta'), 101500);
    });

    test('sin diferencia no crea nada', () {
      final libro = libroBase()
        ..agregar(mov(TipoMovimiento.apertura, 'apertura', 'efectivo', 80000));
      final c = libro.conciliar(
        cuentaId: 'efectivo',
        fecha: dia,
        saldoDeclarado: 80000,
        cuentaAjustesId: 'ajustes',
        idAjuste: 'aj-3',
        persona: yo,
        registradoEn: ahora,
      );
      expect(c.ajuste, isNull);
      expect(libro.movimientos.length, 1);
    });
  });

  test(
    'aportaciones por persona a una cuenta de gasto (leche y pan, 5.0 bis)',
    () {
      final libro = libroBase()
        ..agregar(
          mov(
            TipoMovimiento.gasto,
            'efectivo',
            'alimentacion',
            4500,
            quien: 'A',
          ),
        )
        ..agregar(
          mov(TipoMovimiento.gasto, 'banco', 'alimentacion', 8000, quien: 'B'),
        );
      final semana = Periodo.semana(dia);
      expect(libro.gastoPorCuenta(semana)['alimentacion'], 12500);
      expect(libro.aportacionesPorPersona('alimentacion', semana), {
        'A': 4500,
        'B': 8000,
      });
    },
  );
}
