// Dispersión de ingresos con confirmación (Fase 8, F8-6.4; especificación
// `docs/specs/fase-8-finanzas-dispersion.md`). Los números salen del ejemplo
// de 5.6 bis, punto 5 (hogar de Ana y Alex), con montos ilustrativos.
//
// Cuentas del ejemplo (a mano, en centavos):
//   ingreso anual del plan = 900000 × 24 + 1400000 × 12 = 38,400,000
//   presupuesto anual      = 28,456,000      deuda anual = 2,040,000
//   Ana (quincena 9,000):  presupuesto 666,938 · deuda 47,813 (tarjeta 33,750
//                          y préstamo familiar 14,063) · remanente 185,249
//   Alex (mes 14,000):     presupuesto 1,037,458 · deuda 74,375 ·
//                          remanente 288,167
import 'package:finanzas_dominio/finanzas_dominio.dart';
import 'package:test/test.dart';

import 'ejemplo_ana_alex.dart' as ej;
import 'hogar_ejemplo.dart' as hogar;

IngresoPorRepartir _sueldoAna([int monto = 900000]) => IngresoPorRepartir(
  movimientoId: 'mov-ana',
  libroId: 'libro',
  fecha: Fecha(2026, 11, 13),
  monto: monto,
  cuentaDestinoId: 'banco',
  nombre: 'Sueldo de Ana',
  ingresoPlanId: 'ana',
);

IngresoPorRepartir _extra(int monto) => IngresoPorRepartir(
  movimientoId: 'mov-extra',
  libroId: 'libro',
  fecha: Fecha(2026, 11, 13),
  monto: monto,
  cuentaDestinoId: 'banco',
  nombre: 'Extras',
);

/// Invariantes de toda propuesta: renglones no negativos y sin pasar del
/// monto; lo repartido más lo que queda por repartir es el monto.
void _cuadra(PropuestaDispersion p) {
  expect(p.lineas.every((l) => l.monto >= 0), isTrue);
  expect(p.totalRepartido + p.quedaPorRepartir, p.monto);
  expect(p.quedaPorRepartir, greaterThanOrEqualTo(0));
}

int _de(PropuestaDispersion p, DestinoLinea d, String id) => p.lineas
    .where((l) => l.destino == d && l.referenciaId == id)
    .fold<int>(0, (t, l) => t + l.monto);

void main() {
  group('Propuesta de un sueldo (cascada: presupuesto, deuda, remanente)', () {
    test('la quincena de Ana cubre su parte y el resto es abono extra', () {
      final plan = ej.planEjemplo();
      final p = proponerDispersion(ingreso: _sueldoAna(), plan: plan);
      _cuadra(p);
      expect(p.totalPresupuesto, 666938);
      expect(p.totalPagosDeuda, 47813);
      expect(_de(p, DestinoLinea.pagoDeuda, 'tarjeta'), 33750);
      expect(_de(p, DestinoLinea.pagoDeuda, 'familiar'), 14063);
      expect(p.remanente, 185249);
      expect(p.ahorro, 0);
      // El remanente paga primero la tarjeta (mayor costo).
      expect(p.abonosExtra, hasLength(1));
      expect(_de(p, DestinoLinea.abonoExtra, 'tarjeta'), 185249);
      expect(p.quedaPorRepartir, 0);
      expect(p.faltante, 0);
      expect(p.cubreTodo, isTrue);
    });

    test('el sueldo mensual de Alex cubre un mes del plan', () {
      final p = proponerDispersion(
        ingreso: IngresoPorRepartir(
          movimientoId: 'mov-alex',
          libroId: 'libro',
          fecha: Fecha(2026, 11, 2),
          monto: 1400000,
          cuentaDestinoId: 'banco',
          nombre: 'Sueldo de Alex',
          ingresoPlanId: 'alex',
        ),
        plan: ej.planEjemplo(),
      );
      _cuadra(p);
      expect(p.totalPresupuesto, 1037458);
      expect(p.totalPagosDeuda, 74375);
      expect(p.remanente, 288167);
    });

    test('lo que cada partida cubre sale del plan (renta de un mes)', () {
      // Renta anual 9,600,000 × 900,000 ÷ 38,400,000 = 225,000.
      final p = proponerDispersion(
        ingreso: _sueldoAna(),
        plan: ej.planEjemplo(),
      );
      expect(_de(p, DestinoLinea.presupuesto, 'renta'), 225000);
    });

    test('los dos sueldos del periodo cubren exactamente el plan anual', () {
      // 24 quincenas de Ana + 12 meses de Alex cubren 12 meses de plan: cada
      // ingreso cubre su parte proporcional (anual × monto ÷ ingreso anual).
      final plan = ej.planEjemplo();
      final ana = proponerDispersion(ingreso: _sueldoAna(), plan: plan);
      final alex = proponerDispersion(
        ingreso: IngresoPorRepartir(
          movimientoId: 'x',
          libroId: 'libro',
          fecha: Fecha(2026, 11, 2),
          monto: 1400000,
          cuentaDestinoId: 'banco',
          nombre: 'Alex',
          ingresoPlanId: 'alex',
        ),
        plan: plan,
      );
      final anual = ana.totalPresupuesto * 24 + alex.totalPresupuesto * 12;
      // Dentro del redondeo de un centavo por pago.
      expect(
        (anual - plan.presupuestoEquivalente.anualCentavos).abs(),
        lessThan(40),
      );
    });

    test('sin deuda el remanente completo va a ahorro (5.6 bis, caso 9)', () {
      final plan = ej.planEjemplo(deudas: const []);
      final p = proponerDispersion(ingreso: _sueldoAna(), plan: plan);
      _cuadra(p);
      expect(p.pagosDeuda, isEmpty);
      expect(p.abonosExtra, isEmpty);
      expect(p.ahorro, 900000 - 666938);
      expect(p.remanente, p.ahorro);
    });

    test('ahorro mínimo con deuda: parte del remanente va a ahorro', () {
      final plan = ej.planEjemplo(
        parametros: const ParametrosPlan(ahorroMinimoConDeudaPuntosBase: 1000),
      );
      final p = proponerDispersion(ingreso: _sueldoAna(), plan: plan);
      _cuadra(p);
      // 10 % de 185,249 = 18,525 (R1); el resto, abono extra.
      expect(p.ahorro, 18525);
      expect(p.totalAbonoExtra, 185249 - 18525);
    });

    test('un abono extra no pasa del saldo y el resto sigue la cascada', () {
      final plan = ej.planEjemplo();
      final tarjetaCasiPagada = [
        ej.tarjetaEjemplo.conSaldo(50000),
        ej.prestamoFamiliarEjemplo,
      ];
      final p = proponerDispersion(
        ingreso: _sueldoAna(),
        plan: plan,
        deudas: tarjetaCasiPagada,
      );
      _cuadra(p);
      // Saldo 50,000 − abono apartado 33,750 = 16,250 para la tarjeta.
      expect(_de(p, DestinoLinea.abonoExtra, 'tarjeta'), 16250);
      // Lo demás va al préstamo familiar (después de las deudas con costo).
      expect(_de(p, DestinoLinea.abonoExtra, 'familiar'), 185249 - 16250);
    });
  });

  group('Propuesta de un extra (5.1 bis, punto 4)', () {
    test('un extra va a la deuda de mayor costo y luego al familiar', () {
      final p = proponerDispersion(
        ingreso: _extra(900000),
        plan: ej.planEjemplo(),
      );
      _cuadra(p);
      expect(p.partidas, isEmpty);
      expect(p.pagosDeuda, isEmpty);
      expect(_de(p, DestinoLinea.abonoExtra, 'tarjeta'), 600000);
      expect(_de(p, DestinoLinea.abonoExtra, 'familiar'), 300000);
    });

    test('lo que sobra de toda la deuda va a ahorro', () {
      final p = proponerDispersion(
        ingreso: _extra(1000000),
        plan: ej.planEjemplo(),
      );
      _cuadra(p);
      expect(p.totalAbonoExtra, 900000);
      expect(p.ahorro, 100000);
    });

    test('primero se completan los sobres de previsión que no alcanzan', () {
      final p = proponerDispersion(
        ingreso: _extra(300000),
        plan: ej.planEjemplo(),
        faltantePrevision: const {'placas-predial': 50000},
      );
      _cuadra(p);
      expect(_de(p, DestinoLinea.presupuesto, 'placas-predial'), 50000);
      expect(_de(p, DestinoLinea.abonoExtra, 'tarjeta'), 250000);
    });

    test('la parte libre es un porcentaje del remanente (0 % por defecto)', () {
      final sinLibre = proponerDispersion(
        ingreso: _extra(300000),
        plan: ej.planEjemplo(),
      );
      expect(sinLibre.libre, 0);
      final conLibre = proponerDispersion(
        ingreso: _extra(300000),
        plan: ej.planEjemplo(),
        parametros: const ParametrosDispersion(parteLibrePuntosBase: 1000),
      );
      _cuadra(conLibre);
      expect(conLibre.libre, 30000);
      expect(conLibre.totalAbonoExtra, 270000);
    });

    test('el tope de ahorro deja libre lo que pasa de la meta', () {
      final p = proponerDispersion(
        ingreso: _extra(1000000),
        plan: ej.planEjemplo(),
        parametros: const ParametrosDispersion(topeAhorro: 40000),
      );
      _cuadra(p);
      expect(p.ahorro, 40000);
      expect(p.libre, 60000);
    });

    test('un sueldo que ya no está en el plan se reparte como extra', () {
      final p = proponerDispersion(
        ingreso: IngresoPorRepartir(
          movimientoId: 'm',
          libroId: 'libro',
          fecha: Fecha(2026, 11, 13),
          monto: 200000,
          cuentaDestinoId: 'banco',
          nombre: 'Sueldo viejo',
          ingresoPlanId: 'ya-no-existe',
        ),
        plan: ej.planEjemplo(),
      );
      expect(p.partidas, isEmpty);
      expect(p.totalAbonoExtra, 200000);
    });
  });

  group('Si el ingreso no alcanza', () {
    test('lo protegido y los mínimos se financian al final', () {
      final plan = ej.planEjemplo();
      final completa = proponerDispersion(ingreso: _sueldoAna(), plan: plan);
      final corta = proponerDispersion(ingreso: _sueldoAna(600000), plan: plan);
      _cuadra(corta);
      expect(corta.faltante, 666938 + 47813 - 600000);
      expect(corta.cubreTodo, isFalse);
      expect(corta.remanente, 0);
      expect(corta.totalRepartido, 600000);
      // Las partidas protegidas (renta, luz, agua, internet) no se tocan.
      for (final id in ['renta', 'luz', 'agua', 'internet']) {
        expect(
          _de(corta, DestinoLinea.presupuesto, id),
          _de(completa, DestinoLinea.presupuesto, id),
          reason: id,
        );
      }
      // Primero se recorta el abono sobre el mínimo (aquí, todo el abono).
      expect(corta.pagosDeuda, isEmpty);
      // Y entre las partidas, lo discrecional.
      expect(
        _de(corta, DestinoLinea.presupuesto, 'entretenimiento'),
        lessThan(_de(completa, DestinoLinea.presupuesto, 'entretenimiento')),
      );
    });

    test('con el mínimo de la tarjeta igual a su abono, no se recorta', () {
      final tarjetaConMinimo = DeudaPlan(
        id: 'tarjeta',
        nombre: 'Tarjeta de crédito',
        tipo: TipoDeuda.conCosto,
        abono: 120000,
        frecuencia: Frecuencia.mensual,
        minimo: 120000,
        tasaAnualPuntosBase: 4800,
        saldo: 600000,
      );
      final plan = ej.planEjemplo(
        deudas: [tarjetaConMinimo, ej.prestamoFamiliarEjemplo],
      );
      final p = proponerDispersion(ingreso: _sueldoAna(660000), plan: plan);
      _cuadra(p);
      // Se recorta el préstamo familiar (sin mínimo) y partidas, no la tarjeta.
      expect(_de(p, DestinoLinea.pagoDeuda, 'tarjeta'), 33750);
      expect(_de(p, DestinoLinea.pagoDeuda, 'familiar'), 0);
    });

    test('un ingreso de cero o negativo se rechaza', () {
      expect(
        () => proponerDispersion(ingreso: _extra(0), plan: ej.planEjemplo()),
        throwsA(isA<ErrorDispersion>()),
      );
    });
  });

  group('Editar la propuesta', () {
    final plan = ej.planEjemplo();

    test('quitar un renglón deja ese dinero por repartir', () {
      final p = proponerDispersion(ingreso: _sueldoAna(), plan: plan);
      final i = p.lineas.indexWhere(
        (l) => l.destino == DestinoLinea.abonoExtra,
      );
      final editada = p.editar(i, 100000);
      _cuadra(editada);
      expect(editada.quedaPorRepartir, 185249 - 100000);
      final guardar = editada.lineasParaGuardar();
      expect(
        guardar
            .where((l) => l.destino == DestinoLinea.porRepartir)
            .single
            .monto,
        85249,
      );
      expect(guardar.fold<int>(0, (t, l) => t + l.monto), 900000);
    });

    test(
      'no se puede pasar de lo que queda por repartir ni quedar negativo',
      () {
        final p = proponerDispersion(ingreso: _sueldoAna(), plan: plan);
        expect(() => p.editar(0, -1), throwsA(isA<ErrorDispersion>()));
        expect(() => p.editar(0, 900001), throwsA(isA<ErrorDispersion>()));
        expect(() => p.editar(99, 1), throwsA(isA<ErrorDispersion>()));
      },
    );

    test('mover dinero entre renglones: baja uno y sube otro', () {
      final p = proponerDispersion(ingreso: _sueldoAna(), plan: plan);
      final iExtra = p.lineas.indexWhere(
        (l) => l.destino == DestinoLinea.abonoExtra,
      );
      final iRenta = p.lineas.indexWhere((l) => l.referenciaId == 'renta');
      final conMenosExtra = p.editar(iExtra, 0);
      final conMasRenta = conMenosExtra.editar(
        iRenta,
        conMenosExtra.lineas[iRenta].monto + 185249,
      );
      _cuadra(conMasRenta);
      expect(conMasRenta.quedaPorRepartir, 0);
      expect(conMasRenta.totalAbonoExtra, 0);
    });

    test('lo que no se edita no cambia (la propuesta es inmutable)', () {
      final p = proponerDispersion(ingreso: _sueldoAna(), plan: plan);
      final antes = p.lineas.toList();
      p.editar(0, 0);
      expect(p.lineas, antes);
      expect(() => p.lineas.add(antes.first), throwsUnsupportedError);
    });
  });

  group('Modo automático (pregunta abierta P1)', () {
    test('solo es automática si el ingreso cubre todo lo comprometido', () {
      final plan = ej.planEjemplo();
      final completa = proponerDispersion(ingreso: _sueldoAna(), plan: plan);
      final corta = proponerDispersion(ingreso: _sueldoAna(600000), plan: plan);
      expect(
        estadoAlRecibir(completa, ModoDispersion.automatico),
        EstadoDispersion.automatica,
      );
      expect(
        estadoAlRecibir(corta, ModoDispersion.automatico),
        EstadoDispersion.porRepartir,
      );
      expect(
        estadoAlRecibir(completa, ModoDispersion.confirmacion),
        EstadoDispersion.porRepartir,
      );
    });

    test(
      'la versión automática no mueve dinero: el remanente queda por repartir',
      () {
        final plan = ej.planEjemplo();
        final p = proponerDispersion(ingreso: _sueldoAna(), plan: plan);
        final lineas = p.lineasAutomaticas();
        expect(lineas.any((l) => l.destino.mueveDinero), isFalse);
        final resto = lineas.where(
          (l) => l.destino == DestinoLinea.porRepartir,
        );
        expect(resto.single.monto, 185249);
        expect(lineas.fold<int>(0, (t, l) => t + l.monto), 900000);
      },
    );

    test('el modo por omisión es con confirmación', () {
      expect(const ParametrosDispersion().modo, ModoDispersion.confirmacion);
    });
  });

  group('Estados de un ingreso y lo que se arrastra a la semana actual', () {
    // Jueves 19/nov/2026: el sueldo del viernes 13 es de la semana anterior.
    final hoy = Fecha(2026, 11, 19);
    final semanaActual = Semana.de(hoy);
    final sueldo = Movimiento(
      id: 'sueldo-13nov',
      tipo: TipoMovimiento.ingreso,
      fecha: Fecha(2026, 11, 13),
      registradoEn: DateTime(2026, 11, 14, 9),
      cuentaOrigenId: 'extras-casa',
      cuentaDestinoId: 'banco-casa',
      monto: 900000,
      realizadoPor: hogar.ana,
    );

    test('sin reparto, todo el monto está por repartir', () {
      final d = hogar.hogarEjemplo(movimientos: [sueldo]);
      final lista = ingresosDelLibro(d, hogar.casa, const []);
      expect(lista, hasLength(1));
      final i = lista.single;
      expect(i.estado, EstadoDispersion.porRepartir);
      expect(i.pendiente, 900000);
      expect(i.esSueldo, isFalse, reason: 'se registró como extra');
      expect(i.semana, Semana.de(Fecha(2026, 11, 13)));
    });

    test(
      'lo por repartir se arrastra a la semana actual y no a las pasadas',
      () {
        final d = hogar.hogarEjemplo(movimientos: [sueldo]);
        final lista = ingresosDelLibro(d, hogar.casa, const []);
        expect(
          porRepartirArrastrado(lista, semana: semanaActual, hoy: hoy),
          900000,
        );
        // Semana del propio sueldo (ya pasó): conserva sus cifras de entonces.
        expect(
          porRepartirArrastrado(lista, semana: semanaActual.anterior, hoy: hoy),
          0,
        );
        // Una semana futura también lo lleva hasta que se reparta.
        expect(
          porRepartirArrastrado(
            lista,
            semana: semanaActual.siguiente,
            hoy: hoy,
          ),
          900000,
        );
      },
    );

    test('un ingreso de una semana futura aún no cuenta en la actual', () {
      final futuro = Movimiento(
        id: 'futuro',
        tipo: TipoMovimiento.ingreso,
        fecha: Fecha(2026, 11, 27),
        registradoEn: DateTime(2026, 11, 19, 9),
        cuentaOrigenId: 'extras-casa',
        cuentaDestinoId: 'banco-casa',
        monto: 50000,
        realizadoPor: hogar.ana,
      );
      final d = hogar.hogarEjemplo(movimientos: [sueldo, futuro]);
      final lista = ingresosDelLibro(d, hogar.casa, const []);
      expect(
        porRepartirArrastrado(lista, semana: semanaActual, hoy: hoy),
        900000,
      );
    });

    test('confirmado deja solo lo no repartido; propuesta sigue pendiente', () {
      final d = hogar.hogarEjemplo(movimientos: [sueldo]);
      final dispersion = Dispersion(
        id: 'd1',
        libroId: hogar.casa,
        movimientoId: sueldo.id,
        estado: EstadoDispersion.confirmada,
        lineas: const [
          LineaDispersion(
            destino: DestinoLinea.presupuesto,
            referenciaId: 'renta',
            etiqueta: 'Renta',
            monto: 800000,
          ),
          LineaDispersion(
            destino: DestinoLinea.porRepartir,
            etiqueta: 'Por repartir',
            monto: 100000,
          ),
        ],
        creadaEn: DateTime(2026, 11, 19, 9),
      );
      var lista = ingresosDelLibro(d, hogar.casa, [dispersion]);
      expect(lista.single.estado, EstadoDispersion.confirmada);
      expect(lista.single.pendiente, 100000);
      expect(
        porRepartirArrastrado(lista, semana: semanaActual, hoy: hoy),
        100000,
      );
      lista = ingresosDelLibro(d, hogar.casa, [
        dispersion.conEstado(EstadoDispersion.propuesta),
      ]);
      expect(lista.single.pendiente, 900000);
      expect(lista.single.estado.pendiente, isTrue);
    });

    test('un ingreso anulado no pide reparto; su reparto anulado tampoco', () {
      final libro = hogar.hogarEjemplo(movimientos: [sueldo]).nuevoLibroHogar();
      final anulacion = libro.anular(
        sueldo.id,
        nuevoId: 'anula',
        motivo: 'Se capturó dos veces',
        registradoPor: hogar.ana,
        registradoEn: DateTime(2026, 11, 19, 10),
      );
      final d = hogar.hogarEjemplo(movimientos: [sueldo, anulacion]);
      expect(ingresosDelLibro(d, hogar.casa, const []), isEmpty);
    });

    test('lo anterior a "desde" se da por repartido', () {
      final d = hogar.hogarEjemplo(movimientos: [sueldo]);
      expect(
        ingresosDelLibro(
          d,
          hogar.casa,
          const [],
          parametros: ParametrosDispersion(desde: Fecha(2026, 11, 14)),
        ),
        isEmpty,
      );
      expect(
        ingresosDelLibro(
          d,
          hogar.casa,
          const [],
          parametros: ParametrosDispersion(desde: Fecha(2026, 11, 9)),
        ),
        hasLength(1),
      );
    });

    test('lo que entra a otro libro no cuenta en este', () {
      final d = hogar.hogarEjemplo(movimientos: [sueldo]);
      expect(ingresosDelLibro(d, hogar.libroAna, const []), isEmpty);
    });

    test('"Quedan" suma lo por repartir al presupuesto que queda', () {
      expect(quedanConPorRepartir(disponible: 0, porRepartir: 900000), 900000);
      expect(quedanConPorRepartir(disponible: -500, porRepartir: 0), -500);
    });
  });

  group('Corregir el tipo de un ingreso (anulación y contraasiento)', () {
    final sueldoComoExtra = Movimiento(
      id: 'sueldo-13nov',
      tipo: TipoMovimiento.ingreso,
      fecha: Fecha(2026, 11, 13),
      registradoEn: DateTime(2026, 11, 14, 9),
      cuentaOrigenId: 'extras-casa',
      cuentaDestinoId: 'banco-casa',
      monto: 900000,
      realizadoPor: hogar.ana,
      nota: 'Quincena',
    );

    CorreccionIngreso corregir(
      LibroMovimientos libro, {
      String cuenta = 'sueldo-ana',
    }) => corregirTipoDeIngreso(
      libro,
      movimientoId: sueldoComoExtra.id,
      nuevaCuentaOrigenId: cuenta,
      idAnulacion: 'anula',
      idNuevo: 'nuevo',
      grupoId: 'grupo-1',
      motivo: 'Era el sueldo, no un extra',
      registradoPor: hogar.ana,
      registradoEn: DateTime(2026, 11, 19, 10),
    );

    test(
      'anula el original y registra el sueldo con la misma fecha y monto',
      () {
        final d = hogar.hogarEjemplo(movimientos: [sueldoComoExtra]);
        final libro = d.nuevoLibroHogar();
        final c = corregir(libro);
        expect(c.anulacion.anulaA, sueldoComoExtra.id);
        expect(c.anulacion.monto, 900000);
        expect(c.anulacion.cuentaOrigenId, 'banco-casa');
        expect(c.anulacion.cuentaDestinoId, 'extras-casa');
        expect(c.nuevo.tipo, TipoMovimiento.ingreso);
        expect(c.nuevo.cuentaOrigenId, 'sueldo-ana');
        expect(c.nuevo.cuentaDestinoId, 'banco-casa');
        expect(c.nuevo.fecha, sueldoComoExtra.fecha);
        expect(c.nuevo.monto, sueldoComoExtra.monto);
        expect(c.nuevo.nota, 'Quincena');
        expect(c.anulacion.grupoId, c.nuevo.grupoId);
        expect(libro.estaAnulado(sueldoComoExtra.id), isTrue);
      },
    );

    test(
      'el saldo del banco no cambia y el historial conserva los tres asientos',
      () {
        final d = hogar.hogarEjemplo(movimientos: [sueldoComoExtra]);
        final antes = d.vista(hogar.casa).saldo('banco-casa');
        final libro = d.nuevoLibroHogar();
        final c = corregir(libro);
        final d2 = hogar.hogarEjemplo(
          movimientos: [sueldoComoExtra, c.anulacion, c.nuevo],
        );
        final vista = d2.vista(hogar.casa);
        expect(vista.saldo('banco-casa'), antes);
        expect(vista.saldo('extras-casa'), 0, reason: 'el extra quedó en cero');
        expect(
          vista.movimientos.where((m) => m.fecha == Fecha(2026, 11, 13)),
          hasLength(3),
        );
        // Ya es un sueldo y el extra anulado no pide reparto.
        final lista = ingresosDelLibro(d2, hogar.casa, const []);
        expect(lista, hasLength(1));
        expect(lista.single.esSueldo, isTrue);
        expect(lista.single.ingresoPlanId, 'ing-ana');
      },
    );

    test('el extra de la semana baja y el ingreso real no se duplica', () {
      final d = hogar.hogarEjemplo(movimientos: [sueldoComoExtra]);
      final semana = Semana.de(Fecha(2026, 11, 13));
      expect(extrasDeLaSemana(d, hogar.casa, semana), 900000);
      final libro = d.nuevoLibroHogar();
      final c = corregir(libro);
      final d2 = hogar.hogarEjemplo(
        movimientos: [sueldoComoExtra, c.anulacion, c.nuevo],
      );
      expect(extrasDeLaSemana(d2, hogar.casa, semana), 0);
    });

    test('no corrige un movimiento que no es ingreso, ni a un tipo igual', () {
      final d = hogar.hogarEjemplo(movimientos: [sueldoComoExtra]);
      expect(
        () => corregirTipoDeIngreso(
          d.nuevoLibroHogar(),
          movimientoId: 'ap-banco-casa',
          nuevaCuentaOrigenId: 'sueldo-ana',
          idAnulacion: 'a',
          idNuevo: 'n',
          grupoId: 'g',
          motivo: 'Prueba',
          registradoPor: hogar.ana,
          registradoEn: DateTime(2026, 11, 19),
        ),
        throwsA(isA<ErrorDispersion>()),
      );
      expect(
        () => corregir(d.nuevoLibroHogar(), cuenta: 'extras-casa'),
        throwsA(isA<ErrorDispersion>()),
      );
      expect(
        () => corregir(d.nuevoLibroHogar(), cuenta: 'banco-casa'),
        throwsA(isA<ErrorDispersion>()),
      );
    });

    test('exige motivo y no corrige dos veces', () {
      final d = hogar.hogarEjemplo(movimientos: [sueldoComoExtra]);
      expect(
        () => corregirTipoDeIngreso(
          d.nuevoLibroHogar(),
          movimientoId: sueldoComoExtra.id,
          nuevaCuentaOrigenId: 'sueldo-ana',
          idAnulacion: 'a',
          idNuevo: 'n',
          grupoId: 'g',
          motivo: ' ',
          registradoPor: hogar.ana,
          registradoEn: DateTime(2026, 11, 19),
        ),
        throwsA(isA<ErrorDispersion>()),
      );
      final libro = d.nuevoLibroHogar();
      corregir(libro);
      expect(
        () => corregirTipoDeIngreso(
          libro,
          movimientoId: sueldoComoExtra.id,
          nuevaCuentaOrigenId: 'sueldo-alex',
          idAnulacion: 'a2',
          idNuevo: 'n2',
          grupoId: 'g2',
          motivo: 'Otra vez',
          registradoPor: hogar.ana,
          registradoEn: DateTime(2026, 11, 19),
        ),
        throwsA(isA<ErrorDispersion>()),
      );
    });
  });

  group('Cambiar un reparto ya confirmado (P5)', () {
    Dispersion confirmada(PropuestaDispersion p, {int version = 1}) =>
        Dispersion(
          id: 'rep-$version',
          libroId: 'libro',
          movimientoId: p.movimientoId,
          estado: EstadoDispersion.confirmada,
          lineas: p.lineasParaGuardar(),
          creadaEn: DateTime(2026, 11, 19, 9),
          version: version,
          reemplazaA: version > 1 ? 'rep-${version - 1}' : null,
        );

    int abono(PropuestaDispersion p) => p.totalAbonoExtra;
    int indiceAbono(PropuestaDispersion p) =>
        p.lineas.indexWhere((l) => l.destino == DestinoLinea.abonoExtra);

    test('el estado reemplazada no es vigente y la versión viaja', () {
      expect(EstadoDispersion.reemplazada.vigente, isFalse);
      expect(EstadoDispersion.anulada.vigente, isFalse);
      expect(EstadoDispersion.confirmada.vigente, isTrue);
      expect(EstadoDispersion.reemplazada.aplicada, isFalse);
      expect(EstadoDispersion.reemplazada.pendiente, isFalse);
      final d = confirmada(
        proponerDispersion(ingreso: _sueldoAna(), plan: ej.planEjemplo()),
        version: 3,
      );
      expect(d.version, 3);
      expect(d.reemplazaA, 'rep-2');
      expect(d.conEstado(EstadoDispersion.reemplazada).version, 3);
    });

    test('un reparto reemplazado no cuenta como el vigente del ingreso', () {
      final p = proponerDispersion(
        ingreso: _sueldoAna(),
        plan: ej.planEjemplo(),
      );
      final viejo = confirmada(p).conEstado(EstadoDispersion.reemplazada);
      final d = hogar.hogarEjemplo(
        movimientos: [
          Movimiento(
            id: 'mov-ana',
            tipo: TipoMovimiento.ingreso,
            fecha: Fecha(2026, 11, 13),
            registradoEn: DateTime(2026, 11, 13, 12),
            cuentaOrigenId: 'extras-casa',
            cuentaDestinoId: 'banco-casa',
            monto: 900000,
            realizadoPor: hogar.ana,
          ),
        ],
      );
      expect(
        ingresosDelLibro(d, hogar.casa, [viejo]).single.estado,
        EstadoDispersion.porRepartir,
      );
      final nuevo = Dispersion(
        id: 'rep-2',
        libroId: hogar.casa,
        movimientoId: 'mov-ana',
        estado: EstadoDispersion.confirmada,
        lineas: [
          const LineaDispersion(
            destino: DestinoLinea.presupuesto,
            etiqueta: 'Renta',
            monto: 800000,
          ),
          const LineaDispersion(
            destino: DestinoLinea.porRepartir,
            etiqueta: 'Por repartir',
            monto: 100000,
          ),
        ],
        creadaEn: DateTime(2026, 11, 20),
        version: 2,
        reemplazaA: 'rep-1',
      );
      final lista = ingresosDelLibro(d, hogar.casa, [viejo, nuevo]);
      expect(lista.single.dispersionId, 'rep-2');
      expect(lista.single.pendiente, 100000);
    });

    test('la propuesta para cambiar arranca con los montos del vigente', () {
      final base = proponerDispersion(
        ingreso: _sueldoAna(),
        plan: ej.planEjemplo(),
      );
      final editada = base.editar(indiceAbono(base), 100000);
      final vigente = confirmada(editada);
      final p = propuestaParaCambiar(vigente: vigente, base: base);
      _cuadra(p);
      expect(abono(p), 100000);
      expect(p.totalPresupuesto, base.totalPresupuesto);
      expect(p.quedaPorRepartir, editada.quedaPorRepartir);
      expect(p.quedaPorRepartir, base.totalAbonoExtra - 100000);
    });

    test('un renglón que quedó en cero sigue editable', () {
      final base = proponerDispersion(
        ingreso: _sueldoAna(),
        plan: ej.planEjemplo(),
      );
      // Se confirmó sin abono extra: ese renglón no se guardó.
      final sinAbono = base.editar(indiceAbono(base), 0);
      final vigente = confirmada(sinAbono);
      expect(
        vigente.lineas.where((l) => l.destino == DestinoLinea.abonoExtra),
        isEmpty,
      );
      final p = propuestaParaCambiar(vigente: vigente, base: base);
      final i = indiceAbono(p);
      expect(i, isNonNegative, reason: 'el renglón vuelve, en cero');
      expect(p.lineas[i].monto, 0);
      final subida = p.editar(i, 50000);
      _cuadra(subida);
      expect(subida.quedaPorRepartir, sinAbono.quedaPorRepartir - 50000);
      expect(
        () => p.editar(i, p.monto + 1),
        throwsA(isA<ErrorDispersion>()),
        reason: 'las reglas de editar siguen valiendo',
      );
    });

    test('armar el cambio: qué se anula, qué se crea y la diferencia', () {
      final plan = ej.planEjemplo();
      final base = proponerDispersion(ingreso: _sueldoAna(), plan: plan);
      final vigente = confirmada(base, version: 2);
      final puesta = propuestaParaCambiar(vigente: vigente, base: base);
      final editada = puesta.editar(indiceAbono(puesta), 100000);
      final c = armarCambioDeReparto(vigente: vigente, editada: editada);
      expect(c.versionEsperada, 2);
      expect(c.anterior.id, 'rep-2');
      expect(c.hayCambios, isTrue);
      // Se anula lo que creó el reparto anterior (el abono extra) y se crea lo
      // nuevo; el pago de deuda sigue solo apartando (P4).
      expect(c.anulan.map((l) => l.destino), [DestinoLinea.abonoExtra]);
      expect(c.anulan.single.monto, base.totalAbonoExtra);
      expect(c.crean.single.monto, 100000);
      expect(c.diferenciaDeSalida, 100000 - base.totalAbonoExtra);
      expect(c.dineroDevuelto, base.totalAbonoExtra);
      expect(c.dineroNuevo, 100000);
      // Lo que se quitó queda por repartir y todo suma el monto del ingreso.
      expect(c.lineas.fold<int>(0, (t, l) => t + l.monto), _sueldoAna().monto);
      expect(
        c.lineas
            .where((l) => l.destino == DestinoLinea.porRepartir)
            .single
            .monto,
        base.totalAbonoExtra - 100000,
      );
      expect(c.renglonesDistintos, hasLength(2));
    });

    test('sin ediciones no hay cambios', () {
      final base = proponerDispersion(
        ingreso: _sueldoAna(),
        plan: ej.planEjemplo(),
      );
      final vigente = confirmada(base);
      final puesta = propuestaParaCambiar(vigente: vigente, base: base);
      final c = armarCambioDeReparto(vigente: vigente, editada: puesta);
      expect(c.hayCambios, isFalse);
      expect(c.diferenciaDeSalida, 0);
      expect(c.renglonesDistintos, isEmpty);
    });

    test('pasar dinero entre renglones: ahorro de un extra', () {
      final plan = ej.planEjemplo();
      final base = proponerDispersion(ingreso: _extra(300000), plan: plan);
      final vigente = confirmada(base);
      final puesta = propuestaParaCambiar(vigente: vigente, base: base);
      final todosCero = [for (var i = 0; i < puesta.lineas.length; i++) i]
          .fold<PropuestaDispersion>(puesta, (p, i) => p.editar(i, 0));
      final c = armarCambioDeReparto(vigente: vigente, editada: todosCero);
      expect(c.hayCambios, isTrue);
      expect(c.crean, isEmpty);
      expect(c.anulan.every((l) => l.destino.mueveDinero), isTrue);
      expect(
        c.lineas.single.destino,
        DestinoLinea.porRepartir,
        reason: 'todo queda por repartir',
      );
      expect(c.lineas.single.monto, 300000);
    });

    test('rechaza lo que el servidor rechazaría', () {
      final base = proponerDispersion(
        ingreso: _sueldoAna(),
        plan: ej.planEjemplo(),
      );
      final vigente = confirmada(base);
      final puesta = propuestaParaCambiar(vigente: vigente, base: base);
      // Una propuesta no se cambia: se confirma.
      expect(
        () => armarCambioDeReparto(
          vigente: vigente.conEstado(EstadoDispersion.propuesta),
          editada: puesta,
        ),
        throwsA(isA<ErrorDispersion>()),
      );
      // Un reparto reemplazado ya no es el vigente.
      expect(
        () => armarCambioDeReparto(
          vigente: vigente.conEstado(EstadoDispersion.reemplazada),
          editada: puesta,
        ),
        throwsA(isA<ErrorDispersion>()),
      );
      // Otro ingreso.
      final otro = proponerDispersion(
        ingreso: IngresoPorRepartir(
          movimientoId: 'otro',
          libroId: 'libro',
          fecha: Fecha(2026, 11, 13),
          monto: 900000,
          cuentaDestinoId: 'banco',
          nombre: 'Otro',
          ingresoPlanId: 'ana',
        ),
        plan: ej.planEjemplo(),
      );
      expect(
        () => armarCambioDeReparto(vigente: vigente, editada: otro),
        throwsA(isA<ErrorDispersion>()),
      );
      expect(
        () => propuestaParaCambiar(vigente: vigente, base: otro),
        throwsA(isA<ErrorDispersion>()),
      );
      // Un reparto que no suma el monto del ingreso (datos viejos): pide
      // volver a cargar.
      final roto = Dispersion(
        id: 'rep-x',
        libroId: 'libro',
        movimientoId: 'mov-ana',
        estado: EstadoDispersion.confirmada,
        lineas: const [
          LineaDispersion(
            destino: DestinoLinea.presupuesto,
            etiqueta: 'Renta',
            monto: 1,
          ),
        ],
        creadaEn: DateTime(2026, 11, 19),
      );
      expect(
        () => propuestaParaCambiar(vigente: roto, base: base),
        throwsA(isA<ErrorDispersion>()),
      );
    });
  });
}
