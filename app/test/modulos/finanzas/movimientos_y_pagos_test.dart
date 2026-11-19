// Fase 8: registrar un pago desde el teléfono y la laptop, y movimientos por
// tipo y periodo con tira de totales (docs/specs/
// fase-8-finanzas-movimientos-y-pagos.md). Datos de ejemplo inventados.
import 'package:finanzas_dominio/finanzas_dominio.dart'
    hide Semaforo, formatearCentavos, TipoLibro, puntosBaseEnCien;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/app_gravity.dart';
import 'package:gravity/app/router.dart';
import 'package:gravity/diseno/diseno.dart' show montosVisiblesProvider;
import 'package:gravity/modulos/finanzas/casos_uso/servicio_finanzas.dart';
import 'package:gravity/modulos/finanzas/datos/demostracion.dart';
import 'package:gravity/modulos/finanzas/datos/repositorio_memoria.dart';
import 'package:gravity/modulos/finanzas/estado/proveedores.dart';
import 'package:gravity/modulos/finanzas/finanzas.dart' show SeccionFinanzas;
import 'package:gravity/modulos/finanzas/pantallas/fila_movimiento.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_demostracion.dart';

import '../../app/ayuda_plataforma.dart';
import 'ayuda_finanzas.dart';

void main() {
  const libro = IdsDemostracion.libroDueno;
  final dueno = sesionDe(Rol.dueno);

  late RepositorioFinanzasEnMemoria repo;
  late ServicioFinanzas base;

  setUp(() {
    repo = repositorioDe(dueno);
    base = servicioDe(repo, dueno);
  });
  tearDown(() => repo.cerrar());

  Future<void> montar(WidgetTester tester, TipoDispositivo d) async {
    await montarApp(
      tester,
      dispositivo: d,
      sesion: ServicioSesionDemostracion(inicial: dueno),
      extras: [repositorioFinanzasProvider.overrideWithValue(repo)],
    );
    ProviderScope.containerOf(tester.element(find.byType(AppGravity)))
        .read(montosVisiblesProvider.notifier)
        .fijar(true);
    await tester.pump();
  }

  ProviderContainer contenedor(WidgetTester t) =>
      ProviderScope.containerOf(t.element(find.byType(AppGravity)));

  Future<void> ir(WidgetTester t, String ruta) async {
    contenedor(t).read(routerProvider).go(ruta);
    await t.pumpAndSettle();
  }

  group('Registrar pago desde el teléfono', () {
    testWidgets('el botón es visible, abre la hoja y guarda un pagoDeuda', (
      tester,
    ) async {
      final tarjeta = await _nuevaTarjeta(base, saldo: 300000);
      await montar(tester, TipoDispositivo.telefono);
      await ir(tester, SeccionFinanzas.deudas.ruta);
      final boton = find.byKey(ValueKey('pagar-${tarjeta.id}'));
      expect(boton, findsOneWidget);
      expect(find.text('Registrar pago'), findsWidgets);

      final antes = repo.datos.movimientos.length;
      await tester.ensureVisible(boton);
      await tester.pumpAndSettle();
      await tester.tap(boton);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('pago-guardar')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('pago-sug-15000')));
      await tester.pump();
      final banco = repo.cuentaDe(libro, 'Mi banco');
      await tester.tap(find.byKey(ValueKey('pago-cuenta-${banco.id}')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('pago-guardar')));
      await tester.pumpAndSettle();

      expect(repo.datos.movimientos, hasLength(antes + 1));
      final pago = repo.datos.movimientos.last;
      expect(pago.tipo, TipoMovimiento.pagoDeuda);
      expect(pago.monto, 15000);
      expect(pago.cuentaOrigenId, banco.id);
      expect(pago.cuentaDestinoId, tarjeta.cuentaPasivoId);
      expect(tester.takeException(), isNull);
    });

    testWidgets('una deuda liquidada no ofrece Registrar pago', (tester) async {
      final tarjeta = await _nuevaTarjeta(base, saldo: 0);
      await montar(tester, TipoDispositivo.telefono);
      await ir(tester, SeccionFinanzas.deudas.ruta);
      expect(find.byKey(ValueKey('pagar-${tarjeta.id}')), findsNothing);
    });

    testWidgets('la laptop conserva el botón y usa la misma hoja', (
      tester,
    ) async {
      final tarjeta = await _nuevaTarjeta(base, saldo: 300000);
      await montar(tester, TipoDispositivo.laptop);
      await ir(tester, SeccionFinanzas.deudas.ruta);
      final boton = find.byKey(ValueKey('pagar-${tarjeta.id}'));
      await tester.ensureVisible(boton);
      await tester.pumpAndSettle();
      await tester.tap(boton);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('pago-guardar')), findsOneWidget);
    });
  });

  group('Movimientos por tipo y periodo', () {
    testWidgets('teléfono: tira de totales, filtro por tipo y por periodo', (
      tester,
    ) async {
      await montar(tester, TipoDispositivo.telefono);
      await ir(tester, SeccionFinanzas.movimientos.ruta);
      expect(find.byKey(const ValueKey('totales-tira')), findsOneWidget);
      expect(find.byKey(const ValueKey('totales-neto')), findsOneWidget);
      expect(find.byKey(const ValueKey('totales-ingresos')), findsOneWidget);

      final c = contenedor(tester).read(contextoFinanzasProvider).value!;
      final vista = c.datos.vista(c.libroId);

      // Filtro por tipo: solo gastos en la lista.
      await tester.tap(find.byKey(const ValueKey('totales-gastos')));
      await tester.pumpAndSettle();
      final filas = tester.widgetList<FilaMovimiento>(
        find.byType(FilaMovimiento),
      );
      for (final f in filas) {
        expect(tipoResumenDe(f.movimiento, vista), TipoResumen.gastos);
      }
      // Tocar otra vez quita el filtro.
      await tester.tap(find.byKey(const ValueKey('totales-gastos')));
      await tester.pumpAndSettle();

      // Filtro por periodo: solo movimientos de la semana.
      await tester.tap(
        find.byKey(const ValueKey('movimientos-periodo-semana')),
      );
      await tester.pumpAndSettle();
      final semana = Periodo.semana(c.hoy);
      for (final f in tester.widgetList<FilaMovimiento>(
        find.byType(FilaMovimiento),
      )) {
        expect(semana.contiene(f.movimiento.fecha), isTrue);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('teléfono: un tipo sin movimientos muestra el aviso', (
      tester,
    ) async {
      await montar(tester, TipoDispositivo.telefono);
      await ir(tester, SeccionFinanzas.movimientos.ruta);
      final c = contenedor(tester).read(contextoFinanzasProvider).value!;
      // Un tipo sin movimientos en el ejemplo: la lista queda vacía y avisa.
      final sinMovimientos = TipoResumen.values.firstWhere(
        (t) =>
            totalesPorTipo(c.datos.vista(c.libroId), null).cantidadDe(t) == 0,
      );
      await tester.tap(find.byKey(ValueKey('totales-${sinMovimientos.name}')));
      await tester.pumpAndSettle();
      expect(
        find.text('Aún no hay movimientos en este periodo.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('laptop: la tira aparece encima de la tabla', (tester) async {
      await montar(tester, TipoDispositivo.laptop);
      await ir(tester, SeccionFinanzas.movimientos.ruta);
      final tira = find.byKey(const ValueKey('totales-tira'));
      final tabla = find.byKey(const ValueKey('movimientos-tabla'));
      expect(tira, findsOneWidget);
      expect(tabla, findsOneWidget);
      expect(tester.getTopLeft(tira).dy, lessThan(tester.getTopLeft(tabla).dy));
      expect(find.byKey(const ValueKey('totales-neto')), findsOneWidget);
    });

    testWidgets('con los montos ocultos la tira no muestra cifras', (
      tester,
    ) async {
      await montar(tester, TipoDispositivo.telefono);
      contenedor(tester).read(montosVisiblesProvider.notifier).fijar(false);
      await ir(tester, SeccionFinanzas.movimientos.ruta);
      final neto = find.descendant(
        of: find.byKey(const ValueKey('totales-neto')),
        matching: find.textContaining(r'$'),
      );
      expect(neto, findsNothing);
    });
  });
}

/// Una tarjeta de ejemplo en el libro del dueño, con saldo.
Future<Deuda> _nuevaTarjeta(ServicioFinanzas base, {int saldo = 0}) async {
  final cuenta = await base.crearCuenta(
    libroId: IdsDemostracion.libroDueno,
    nombre: 'Tarjeta de ejemplo',
    tipo: TipoCuenta.tarjeta,
    saldoInicial: saldo,
    limiteCentavos: 1000000,
  );
  final d = Deuda(
    id: base.nuevoId(),
    libroId: IdsDemostracion.libroDueno,
    nombre: 'Tarjeta de ejemplo',
    tipo: TipoDeuda.conCosto,
    clase: ClaseDeuda.tarjeta,
    cuentaPasivoId: cuenta.id,
    abono: 50000,
    minimo: 15000,
    frecuencia: Frecuencia.mensual,
    calendario: const CalendarioConfig.mensual([
      25,
    ], regla: ReglaDiaInhabil.sinCambio),
    tasaAnualPuntosBase: 4500,
  );
  await base.guardarDeuda(d);
  return d;
}
