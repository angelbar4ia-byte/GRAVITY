// Fase 8, bloque 2: simulador de estrategias, intereses y tarjetas con
// beneficios. Datos de ejemplo inventados.
import 'package:finanzas_dominio/finanzas_dominio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gravity/app/app_gravity.dart';
import 'package:gravity/app/router.dart';
import 'package:gravity/modulos/finanzas/casos_uso/simulador_deudas.dart';
import 'package:gravity/modulos/finanzas/datos/demostracion.dart';
import 'package:gravity/modulos/finanzas/datos/tarjetas.dart';
import 'package:gravity/modulos/finanzas/estado/proveedores.dart';
import 'package:gravity/modulos/finanzas/finanzas.dart' show SeccionFinanzas;
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_demostracion.dart';

import '../../app/ayuda_plataforma.dart';
import 'ayuda_finanzas.dart';

void main() {
  const tienda = DeudaSimulable(
    id: 'a',
    nombre: 'Tienda',
    saldo: 300000,
    tasaAnualPuntosBase: 3000,
    minimoMensual: 30000,
    diasParaVencer: 20,
  );
  const cara = DeudaSimulable(
    id: 'b',
    nombre: 'Tarjeta cara',
    saldo: 1200000,
    tasaAnualPuntosBase: 6000,
    minimoMensual: 60000,
    diasParaVencer: 10,
  );
  const prestamo = DeudaSimulable(
    id: 'c',
    nombre: 'Préstamo',
    saldo: 2500000,
    tasaAnualPuntosBase: 2000,
    minimoMensual: 90000,
    diasParaVencer: 3,
  );
  const deudas = [tienda, cara, prestamo];

  group('Simulador', () {
    test('las tres estrategias pagan el mismo capital y total de deuda', () {
      final r = simularTodas(deudas, extraMensual: 50000);
      expect(r, hasLength(3));
      for (final x in r) {
        expect(x.calculada && x.liquidada, isTrue);
        expect(x.capitalPagado, 4000000);
        expect(x.totalPagado, x.capitalPagado + x.interesesTotales);
      }
    });

    test('la avalancha paga menos intereses cuando las tasas difieren', () {
      final r = simularTodas(deudas, extraMensual: 50000);
      expect(
        r[1].interesesTotales,
        lessThan(r[0].interesesTotales),
        reason: 'avalancha < bola de nieve',
      );
      expect(recomendar(r)!.estrategia, EstrategiaPago.avalancha);
    });

    test('falta_dato solo bloquea la estrategia afectada', () {
      const sinFecha = DeudaSimulable(
        id: 'd',
        nombre: 'Sin fecha',
        saldo: 100000,
        tasaAnualPuntosBase: 4000,
        minimoMensual: 10000,
      );
      final r = simularTodas([...deudas, sinFecha]);
      expect(r[0].calculada, isTrue);
      expect(r[1].calculada, isTrue);
      expect(r[2].estado, EstadoEstrategia.faltaDato);
      expect(r[2].interesesTotales, 0);
      expect(r[2].orden, isEmpty);
    });

    test('con el pago mínimo se paga más de intereses que con cualquier '
        'estrategia', () {
      final minimo = interesesConPagoMinimo(deudas);
      for (final x in simularTodas(deudas)) {
        expect(x.interesesTotales, lessThanOrEqualTo(minimo.interesesTotales));
      }
    });

    test('las deudas del libro salen sin inventar lo que falta', () {
      final datos = datosDeDemostracion(hoy: hoyDePrueba);
      final lista = deudasSimulables(
        datos,
        IdsDemostracion.libroDueno,
        hoyDePrueba,
      );
      for (final d in lista) {
        if (d.saldo == null) {
          expect(
            simularEstrategia(EstrategiaPago.avalancha, [d]).calculada,
            isFalse,
          );
        }
      }
    });
  });

  group('Presupuesto y ciclos futuros', () {
    test('el presupuesto por omisión es la suma de los mínimos', () {
      expect(sumaDeMinimos(deudas), 180000);
      final omision = simularTodas(deudas);
      final explicito = simularTodas(deudas, presupuestoMensual: 180000);
      for (var i = 0; i < 3; i++) {
        expect(omision[i].interesesTotales, explicito[i].interesesTotales);
        expect(omision[i].meses, explicito[i].meses);
      }
    });

    test('un monto menor que la suma de mínimos marca "no alcanza"', () {
      for (final r in simularTodas(deudas, presupuestoMensual: 179999)) {
        expect(r.estado, EstadoEstrategia.noAlcanza);
        expect(r.calculada, isFalse);
      }
    });

    test('por vencimiento paga primero la de vencimiento más cercano cuando '
        'la liquidez alcanza solo para una', () {
      const cercana = DeudaSimulable(
        id: 'x',
        nombre: 'Cercana',
        saldo: 100000,
        tasaAnualPuntosBase: 2000,
        minimoMensual: 10000,
        diasParaVencer: 8,
      );
      const futura = DeudaSimulable(
        id: 'y',
        nombre: 'Futura',
        saldo: 100000,
        tasaAnualPuntosBase: 5000,
        minimoMensual: 10000,
        diasParaVencer: 40,
      );
      // Mínimos 20 000; con 120 000 alcanza a liquidar solo una en el mes 1.
      final r = simularEstrategia(EstrategiaPago.porVencimiento, [
        futura,
        cercana,
      ], presupuestoMensual: 110000);
      expect(r.orden.first.deudaId, 'x');
      expect(r.orden.first.mesDeLiquidacion, 1);
      expect(r.orden.last.mesDeLiquidacion, greaterThan(1));
    });
  });

  group('Tarjetas y beneficios', () {
    test('lo capturado a mano nunca aparece como verificado', () {
      final t = tarjetaCapturada(
        id: 't1',
        libroId: IdsDemostracion.libroDueno,
        banco: 'Banco Ejemplo',
        nombre: 'Oro',
      );
      final b = beneficioCapturado(
        id: 'b1',
        tarjetaId: 't1',
        tipo: TipoBeneficio.cashback,
        descripcion: '2 % en súper',
        desde: Fecha(2026, 1, 1),
        hasta: Fecha(2026, 12, 31),
      );
      expect(t.origen, OrigenDato.capturado);
      expect(t.esVerificada, isFalse);
      expect(b.esVerificado, isFalse);
      expect(b.origen.etiqueta, 'Capturado, no verificado');
      expect(b.vigenteEn(Fecha(2026, 11, 8)), isTrue);
      expect(b.vigenteEn(Fecha(2027, 1, 1)), isFalse);
    });

    test('valida como el servidor: sin cifras ni vigencia al revés', () {
      expect(
        () => beneficioCapturado(
          id: 'b',
          tarjetaId: 't',
          tipo: TipoBeneficio.puntos,
          descripcion: r'Saldo $500',
          desde: Fecha(2026, 1, 1),
        ),
        throwsArgumentError,
      );
      expect(
        () => beneficioCapturado(
          id: 'b',
          tarjetaId: 't',
          tipo: TipoBeneficio.puntos,
          descripcion: 'Tarjeta 1234',
          desde: Fecha(2026, 1, 1),
        ),
        throwsArgumentError,
      );
      expect(
        () => beneficioCapturado(
          id: 'b',
          tarjetaId: 't',
          tipo: TipoBeneficio.mesesSinIntereses,
          descripcion: '12 MSI',
          desde: Fecha(2026, 5, 1),
          hasta: Fecha(2026, 4, 1),
        ),
        throwsArgumentError,
      );
    });

    test('el repositorio guarda y quita beneficios', () async {
      final repo = RepositorioTarjetasEnMemoria();
      await repo.guardarTarjeta(
        tarjetaCapturada(id: 't', libroId: 'l', banco: 'B', nombre: 'N'),
      );
      await repo.guardarBeneficio(
        beneficioCapturado(
          id: 'x',
          tarjetaId: 't',
          tipo: TipoBeneficio.puntos,
          descripcion: 'Puntos dobles',
          desde: Fecha(2026, 1, 1),
        ),
      );
      expect(await repo.beneficios(), hasLength(1));
      await repo.quitarBeneficio('x');
      expect(await repo.beneficios(), isEmpty);
    });
  });

  group('Quién ve las deudas (D19)', () {
    final hoy = hoyDePrueba;
    final datos = datosDeDemostracion(hoy: hoy);
    List<String> visibles(Rol rol) => [
      for (final l in librosVisibles(
        datos.libros,
        sesionDe(rol).persona.id,
        hoy: hoy,
      ))
        l.id,
    ];

    test('el dueño ve lo suyo, la casa y a Papá como albacea', () {
      final v = visibles(Rol.dueno);
      expect(
        v,
        containsAll([
          IdsDemostracion.libroDueno,
          IdsDemostracion.libroCasa,
          IdsDemostracion.libroPapa,
        ]),
      );
      expect(v, isNot(contains(IdsDemostracion.libroPareja)));
    });

    test('la pareja ve lo suyo y la casa, no lo del dueño', () {
      final v = visibles(Rol.coadministrador);
      expect(v, contains(IdsDemostracion.libroPareja));
      expect(v, contains(IdsDemostracion.libroCasa));
      expect(v, isNot(contains(IdsDemostracion.libroDueno)));
    });

    test('Casa, familiar y cuidadora no ven ningún libro', () {
      for (final r in [Rol.casa, Rol.familiar, Rol.cuidador]) {
        expect(visibles(r), isEmpty, reason: '$r');
      }
    });
  });

  group('Pantallas', () {
    Future<void> montar(WidgetTester tester) async {
      final r = repositorioDe(sesionDe(Rol.dueno));
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.laptop,
        sesion: ServicioSesionDemostracion(inicial: sesionDe(Rol.dueno)),
        extras: [repositorioFinanzasProvider.overrideWithValue(r)],
      );
      addTearDown(r.cerrar);
    }

    GoRouter router(WidgetTester t) =>
        ProviderScope.containerOf(t.element(find.byType(AppGravity)))
            .read(routerProvider);

    testWidgets('el simulador abre y no pone el pago a nombre de nadie', (
      tester,
    ) async {
      await montar(tester);
      router(tester).go(SeccionFinanzas.simulador.ruta);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Finanzas › Simulador de deudas'), findsOneWidget);
      expect(find.textContaining('Pagar ahora'), findsNothing);
    });

    testWidgets('el simulador marca "no alcanza" con un monto bajo', (
      tester,
    ) async {
      await montar(tester);
      router(tester).go(SeccionFinanzas.simulador.ruta);
      await tester.pumpAndSettle();
      final campo = find.byKey(const ValueKey('simulador-extra-campo'));
      if (campo.evaluate().isEmpty) return; // sin deudas en la demostración
      expect(find.byKey(const ValueKey('simulador-no-alcanza')), findsNothing);
      await tester.enterText(campo, '0.01');
      await tester.pump();
      expect(
        find.byKey(const ValueKey('simulador-no-alcanza')),
        findsOneWidget,
      );
    });

    testWidgets('tarjetas: se agrega una y queda como capturada', (
      tester,
    ) async {
      await montar(tester);
      router(tester).go(SeccionFinanzas.tarjetas.ruta);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tarjetas-nueva')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('tarjeta-nombre')),
        'Oro',
      );
      await tester.enterText(
        find.byKey(const ValueKey('tarjeta-banco')),
        'Banco Ejemplo',
      );
      await tester.tap(find.byKey(const ValueKey('tarjeta-guardar')));
      await tester.pumpAndSettle();
      expect(find.text('Banco Ejemplo'), findsOneWidget);
      expect(find.text('Capturado, no verificado'), findsOneWidget);
      expect(find.text('Verificado'), findsNothing);
    });
  });
}
