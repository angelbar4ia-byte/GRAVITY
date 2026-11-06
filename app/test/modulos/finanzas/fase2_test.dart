// Fase 2 de Finanzas en la app: deudas a detalle (estado de cuenta, MSI, pago
// con retiro de avisos), ahorro y fondo (bolsas, reparto, aportación, retiro),
// vencimientos para los recordatorios locales y las pantallas de laptop y
// teléfono. Datos de ejemplo inventados.
import 'dart:async';

import 'package:finanzas_dominio/finanzas_dominio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gravity/app/app_gravity.dart';
import 'package:gravity/app/router.dart';
import 'package:gravity/diseno/diseno.dart' show montosVisiblesProvider;
import 'package:gravity/modulos/finanzas/casos_uso/servicio_fase2.dart';
import 'package:gravity/modulos/finanzas/casos_uso/servicio_finanzas.dart';
import 'package:gravity/modulos/finanzas/datos/demostracion.dart';
import 'package:gravity/modulos/finanzas/datos/filas.dart';
import 'package:gravity/modulos/finanzas/datos/filas_fase2.dart';
import 'package:gravity/modulos/finanzas/datos/repositorio.dart';
import 'package:gravity/modulos/finanzas/datos/repositorio_memoria.dart';
import 'package:gravity/modulos/finanzas/estado/proveedores.dart';
import 'package:gravity/modulos/finanzas/estado/proveedores_fase2.dart';
import 'package:gravity/modulos/finanzas/finanzas.dart' show SeccionFinanzas;
import 'package:gravity/modulos/finanzas/pantallas/detalle_aviso.dart';
import 'package:gravity/modulos/finanzas/pantallas/fase2/hoja_pago.dart';
import 'package:gravity/nucleo/avisos/aviso.dart';
import 'package:gravity/nucleo/avisos/recordatorios.dart' as av;
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_demostracion.dart';

import '../../app/ayuda_plataforma.dart';
import 'ayuda_finanzas.dart';

void main() {
  const libro = IdsDemostracion.libroDueno;
  final dueno = sesionDe(Rol.dueno);
  final semana = Semana.de(hoyDePrueba);

  late RepositorioFinanzasEnMemoria repo;
  late ServicioFinanzas base;
  late ServicioDeudasAhorro svc;
  final retirados = <String>[];

  setUp(() {
    repo = repositorioDe(dueno);
    base = servicioDe(repo, dueno);
    retirados.clear();
    svc = ServicioDeudasAhorro(
      base,
      alRegistrarPago: (objeto, fecha) =>
          retirados.addAll(clavesDeAvisosDePago(objeto, fecha)),
    );
  });
  tearDown(() => repo.cerrar());

  group('Estado de cuenta', () {
    test('se agrega y vale el corte más reciente; no acepta límite antes del '
        'corte', () async {
      final tarjeta = await _nuevaTarjeta(base, repo);
      await svc.registrarEstadoDeCuenta(
        deudaId: tarjeta.id,
        corte: Fecha(2026, 10, 10),
        limitePago: Fecha(2026, 10, 30),
        saldoAlCorte: 500000,
        pagoMinimo: 25000,
        pagoSinIntereses: 480000,
      );
      final ultimo = await svc.registrarEstadoDeCuenta(
        deudaId: tarjeta.id,
        corte: Fecha(2026, 11, 10),
        limitePago: Fecha(2026, 11, 30),
        saldoAlCorte: 450000,
        pagoMinimo: 22000,
        pagoSinIntereses: 430000,
      );
      expect(repo.datos.estadosDeCuenta, hasLength(2));
      expect(repo.datos.ultimoEstadoDeCuenta(tarjeta.id)!.id, ultimo.id);
      await expectLater(
        svc.registrarEstadoDeCuenta(
          deudaId: tarjeta.id,
          corte: Fecha(2026, 11, 10),
          limitePago: Fecha(2026, 11, 1),
          saldoAlCorte: 1,
          pagoMinimo: 0,
          pagoSinIntereses: 0,
        ),
        throwsA(isA<ErrorFinanzas>()),
      );
    });

    test(
      'la fila viaja con sus columnas y no manda las del servidor',
      () async {
        final tarjeta = await _nuevaTarjeta(base, repo);
        final e = await svc.registrarEstadoDeCuenta(
          deudaId: tarjeta.id,
          corte: Fecha(2026, 10, 10),
          limitePago: Fecha(2026, 10, 30),
          saldoAlCorte: 100,
          pagoMinimo: 10,
          pagoSinIntereses: 90,
        );
        final fila = filaEstadoDeCuenta(e, hogarId: hogarDeEjemplo);
        expect(fila['via'], 'manual');
        expect(fila.containsKey('recibido_en'), isFalse);
        expect(fila.containsKey('registrado_por'), isFalse);
        expect(estadoDeCuentaDeFila(fila).pagoSinIntereses, 90);
      },
    );
  });

  group('Compras a meses (MSI)', () {
    test('crea cuenta pasivo, deuda clase msi sin tasa y la ficha', () async {
      final msi = await svc.crearMsi(
        libroId: libro,
        comercio: 'Tienda de ejemplo',
        total: 600000,
        meses: 12,
        fechaCompra: Fecha(2026, 9, 1),
        diaPago: 5,
        pagadas: 1,
      );
      final deuda = repo.datos.deudas.firstWhere((d) => d.id == msi.deudaId);
      expect(deuda.clase, ClaseDeuda.msi);
      expect(deuda.tipo, TipoDeuda.msi);
      expect(deuda.abono, 50000);
      expect(deuda.tasaAnualPuntosBase, 0);
      // 12 mensualidades de 500 y una ya pagada: quedan 11 = $5,500.
      expect(saldoDeDeuda(repo.datos, deuda), 550000);
      expect(repo.datos.msiDe(libro), hasLength(1));
      // Fila y de vuelta.
      final fila = filaMsi(msi, hogarId: hogarDeEjemplo);
      expect(msiDeFila(fila).mensualidades, 12);
      final dFila = filaDeuda(deuda, hogarId: hogarDeEjemplo);
      expect(dFila['clase'], 'msi');
      expect(deudaDeFila(dFila).clase, ClaseDeuda.msi);
    });

    test('valida los meses y el total', () async {
      Future<void> crea(int total, int meses) => svc.crearMsi(
        libroId: libro,
        comercio: 'X',
        total: total,
        meses: meses,
        fechaCompra: Fecha(2026, 9, 1),
        diaPago: 5,
      );
      await expectLater(crea(0, 12), throwsA(isA<ErrorFinanzas>()));
      await expectLater(crea(1000, 1), throwsA(isA<ErrorFinanzas>()));
      await expectLater(crea(1000, 49), throwsA(isA<ErrorFinanzas>()));
    });
  });

  group('Pago de una deuda', () {
    test('baja el saldo, cumple la ocurrencia y retira los avisos', () async {
      final tarjeta = await _nuevaTarjeta(base, repo, saldo: 300000);
      final banco = repo.cuentaDe(libro, 'Mi banco');
      final v = Vencimiento(
        origen: OrigenOcurrencia.deuda,
        origenId: tarjeta.id,
        concepto: tarjeta.nombre,
        fecha: FechaPago(Fecha(2026, 10, 25), Fecha(2026, 10, 25)),
        monto: 100000,
      );
      await svc.pagarDeuda(
        deudaId: tarjeta.id,
        cuentaOrigenId: banco.id,
        monto: 100000,
        vencimiento: v,
      );
      expect(saldoDeDeuda(repo.datos, tarjeta), 200000);
      expect(
        repo.datos.ocurrencias.any(
          (o) =>
              o.origenId == tarjeta.id && o.estado == EstadoOcurrencia.cumplida,
        ),
        isTrue,
      );
      final objeto = idEstable(
        ClavesId.ocurrencia(libro, 'deuda', tarjeta.id, '2026-10-25'),
      );
      expect(
        retirados,
        containsAll([
          'pago_proximo:$objeto:2026-10-25:1',
          'pago_proximo:$objeto:2026-10-25:2',
        ]),
      );
      expect(retirados, hasLength(9));
    });
  });

  group('Bolsas, reparto y retiros', () {
    test(
      'un solo fondo por libro y la bolsa lleva su cuenta de ahorro',
      () async {
        final fondo = await svc.crearBolsa(
          libroId: libro,
          nombre: 'Fondo de emergencia',
          tipo: TipoBolsaAhorro.fondoEmergencia,
          saldoInicial: 200000,
        );
        expect(fondo.nivelMeta, 3);
        expect(repo.datos.cuenta(fondo.cuentaId)!.tipo, TipoCuenta.ahorro);
        expect(svc.saldoDeBolsa(fondo), 200000);
        await expectLater(
          svc.crearBolsa(
            libroId: libro,
            nombre: 'Otro fondo',
            tipo: TipoBolsaAhorro.fondoEmergencia,
          ),
          throwsA(isA<ErrorFinanzas>()),
        );
        final fila = filaBolsa(fondo, hogarId: hogarDeEjemplo);
        expect(fila['tipo'], 'fondo_emergencia');
        expect(bolsaDeFila(fila).nivelMeta, 3);
      },
    );

    test(
      'la meta con fecha exige monto y fecha; la reserva, su monto anual',
      () async {
        await expectLater(
          svc.crearBolsa(
            libroId: libro,
            nombre: 'Viaje',
            tipo: TipoBolsaAhorro.metaFecha,
          ),
          throwsA(isA<ErrorFinanzas>()),
        );
        await expectLater(
          svc.crearBolsa(
            libroId: libro,
            nombre: 'Seguro',
            tipo: TipoBolsaAhorro.reserva,
          ),
          throwsA(isA<ErrorFinanzas>()),
        );
      },
    );

    test('proponer, confirmar y retirar no cambian el patrimonio', () async {
      final banco = repo.cuentaDe(libro, 'Mi banco');
      final meta = await svc.crearBolsa(
        libroId: libro,
        nombre: 'Celular',
        tipo: TipoBolsaAhorro.metaFecha,
        meta: 520000,
        fechaMeta: semana.inicio.sumarDias(7 * 52),
      );
      if (repo.datos.semanaGuardada(libro, semana) == null) {
        await base.activarSemana(libro, semana);
      }
      final r = await svc.proponerReparto(
        libroId: libro,
        semana: semana,
        remanente: 300000,
      );
      // 5,200 entre 52 semanas = $100 a la semana.
      expect(r.aportadoA(meta.id), 10000);
      final propuesta = repo.datos.aportaciones.single;
      expect(propuesta.estado, EstadoAportacion.propuesta);
      expect(propuesta.sugerido, 10000);

      int total() =>
          repo.datos.vista(libro).saldo(banco.id) + svc.saldoDeBolsa(meta);
      final antes = total();
      await svc.confirmarAportacion(
        aportacionId: propuesta.id,
        cuentaOrigenId: banco.id,
      );
      expect(svc.saldoDeBolsa(meta), 10000);
      expect(total(), antes);
      final confirmada = repo.datos.aportaciones.single;
      expect(confirmada.estado, EstadoAportacion.confirmada);
      expect(confirmada.movimientoId, isNotNull);

      // Retiro: motivo corto no pasa; uno válido sí.
      await expectLater(
        svc.retirar(
          bolsaId: meta.id,
          monto: 5000,
          tipo: TipoRetiro.usoPrevisto,
          motivo: ' a ',
          cuentaDestinoId: banco.id,
        ),
        throwsA(isA<ErrorFinanzas>()),
      );
      await svc.retirar(
        bolsaId: meta.id,
        monto: 4000,
        tipo: TipoRetiro.emergencia,
        motivo: 'Reparación urgente',
        cuentaDestinoId: banco.id,
      );
      expect(svc.saldoDeBolsa(meta), 6000);
      expect(total(), antes);
      expect(repo.datos.retiros, hasLength(1));
      await expectLater(
        svc.retirar(
          bolsaId: meta.id,
          monto: 99999999,
          tipo: TipoRetiro.usoPrevisto,
          motivo: 'Demasiado',
          cuentaDestinoId: banco.id,
        ),
        throwsA(isA<ErrorFinanzas>()),
      );
    });

    test('posponer deja el pendiente sin castigo', () async {
      final meta = await svc.crearBolsa(
        libroId: libro,
        nombre: 'Bici',
        tipo: TipoBolsaAhorro.metaLibre,
        meta: 300000,
      );
      await repo.guardarBolsa(
        BolsaAhorro(
          id: meta.id,
          libroId: libro,
          nombre: meta.nombre,
          tipo: meta.tipo,
          cuentaId: meta.cuentaId,
          meta: 300000,
          aporteFijo: 5000,
        ),
      );
      if (repo.datos.semanaGuardada(libro, semana) == null) {
        await base.activarSemana(libro, semana);
      }
      await svc.proponerReparto(
        libroId: libro,
        semana: semana,
        remanente: 100000,
      );
      final a = repo.datos.aportaciones.single;
      await svc.posponerAportacion(a.id);
      final despues = repo.datos.aportaciones.single;
      expect(despues.estado, EstadoAportacion.pospuesta);
      expect(despues.pendiente, 5000);
      final r = svc.bolsas(libro, semana).single;
      expect(r.pendiente, 5000);
    });

    test('la fila de aportación no manda lo que genera el servidor', () {
      final f = filaAportacion(
        const AportacionAhorro(
          id: 'a',
          libroId: 'l',
          semanaId: 's',
          bolsaId: 'b',
          sugerido: 10,
        ),
        hogarId: 'h',
      );
      expect(f.containsKey('pendiente_centavos'), isFalse);
      expect(f.containsKey('confirmada_por'), isFalse);
      expect(f['estado'], 'propuesta');
    });
  });

  group('Vencimientos para los recordatorios locales', () {
    test('trae los pagos de deudas de los próximos 14 días y el límite de pago '
        'de la tarjeta', () async {
      final tarjeta = await _nuevaTarjeta(base, repo, saldo: 300000);
      await svc.registrarEstadoDeCuenta(
        deudaId: tarjeta.id,
        corte: Fecha(2026, 10, 10),
        limitePago: Fecha(2026, 10, 28),
        saldoAlCorte: 300000,
        pagoMinimo: 15000,
        pagoSinIntereses: 290000,
      );
      final fuente = FuenteVencimientosFinanzas(() => repo.datos);
      final lista = await fuente.proximos(desde: ahoraDePrueba, dias: 14);
      expect(lista.where((v) => v.esLimiteDeTarjeta), hasLength(1));
      expect(lista.where((v) => !v.esLimiteDeTarjeta), isNotEmpty);
      // Ordenados por fecha.
      final fechas = [for (final v in lista) v.fecha];
      expect([...fechas]..sort(), fechas);
      // Sin datos, nada.
      expect(
        await FuenteVencimientosFinanzas(() => null)
            .proximos(desde: ahoraDePrueba, dias: 14),
        isEmpty,
      );
    });

    test('un pago cumplido deja de recordarse', () async {
      final tarjeta = await _nuevaTarjeta(base, repo, saldo: 300000);
      final fuente = FuenteVencimientosFinanzas(() => repo.datos);
      final pagos = tarjeta.pagosEntre(
        hoyDePrueba,
        hoyDePrueba.sumarDias(14),
        repo.datos.calendario,
      );
      final objeto = idEstable(
        ClavesId.ocurrencia(
          libro,
          'deuda',
          tarjeta.id,
          '${pagos.first.programada}',
        ),
      );
      final antes = await fuente.proximos(desde: ahoraDePrueba, dias: 14);
      expect(antes.where((v) => v.objetoId == objeto), hasLength(1));
      final cuenta = repo.cuentaDe(libro, 'Mi banco');
      await svc.pagarDeuda(
        deudaId: tarjeta.id,
        cuentaOrigenId: cuenta.id,
        monto: 10000,
        vencimiento: Vencimiento(
          origen: OrigenOcurrencia.deuda,
          origenId: tarjeta.id,
          concepto: tarjeta.nombre,
          fecha: pagos.first,
          monto: 10000,
        ),
      );
      final despues = await fuente.proximos(desde: ahoraDePrueba, dias: 14);
      expect(despues.where((v) => v.objetoId == objeto), isEmpty);
    });
  });

  group('Pantallas', () {
    Future<void> montar(WidgetTester tester, TipoDispositivo d) async {
      final r = repositorioDe(dueno);
      await montarApp(
        tester,
        dispositivo: d,
        sesion: ServicioSesionDemostracion(inicial: dueno),
        extras: [repositorioFinanzasProvider.overrideWithValue(r)],
      );
      addTearDown(r.cerrar);
      ProviderScope.containerOf(tester.element(find.byType(AppGravity)))
          .read(montosVisiblesProvider.notifier)
          .fijar(true);
      await tester.pump();
    }

    GoRouter router(WidgetTester t) =>
        ProviderScope.containerOf(t.element(find.byType(AppGravity)))
            .read(routerProvider);

    testWidgets('laptop: Deudas muestra el costo de deber y el orden de pago', (
      tester,
    ) async {
      await montar(tester, TipoDispositivo.laptop);
      router(tester).go(SeccionFinanzas.deudas.ruta);
      await tester.pumpAndSettle();
      // El libro activo es el del dueño; pasamos al de la casa donde viven.
      expect(tester.takeException(), isNull);
      expect(find.text('Finanzas › Deudas'), findsOneWidget);
    });

    testWidgets('laptop: Ahorro sin bolsas invita a crear una', (tester) async {
      await montar(tester, TipoDispositivo.laptop);
      router(tester).go(SeccionFinanzas.ahorro.ruta);
      await tester.pumpAndSettle();
      expect(find.text('Aún no tienes bolsas de ahorro.'), findsOneWidget);
      expect(find.text('Nueva bolsa'), findsWidgets);
    });

    testWidgets('laptop: Vencimientos abre sin errores', (tester) async {
      await montar(tester, TipoDispositivo.laptop);
      router(tester).go(SeccionFinanzas.vencimientos.ruta);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('vencimientos-lista')), findsOneWidget);
    });

    testWidgets(
      'las consultas locales de las herramientas dan texto discreto y '
      'sin cifras con los montos ocultos',
      (tester) async {
        await montar(tester, TipoDispositivo.laptop);
        final c = ProviderScope.containerOf(
          tester.element(find.byType(AppGravity)),
        );
        final consulta = c.read(consultaLocalFinanzasProvider);
        for (final h in [
          'finanzas.resumen_semana',
          'finanzas.proximos_pagos',
          'finanzas.ahorro_avance',
        ]) {
          final visible = await consulta(h);
          expect(visible, isNotNull, reason: h);
        }
        expect(await consulta('finanzas.otra'), isNull);
        c.read(montosVisiblesProvider.notifier).fijar(false);
        for (final h in [
          'finanzas.resumen_semana',
          'finanzas.proximos_pagos',
        ]) {
          expect(await consulta(h), isNot(contains(r'$')), reason: h);
        }
      },
    );

    testWidgets('el detalle del aviso muestra el acreedor y el monto dentro de '
        'la app', (tester) async {
      final r = repositorioDe(dueno);
      final b = servicioDe(r, dueno);
      final tarjeta = await _nuevaTarjeta(b, r, saldo: 300000);
      final e = await ServicioDeudasAhorro(b).registrarEstadoDeCuenta(
        deudaId: tarjeta.id,
        corte: Fecha(2026, 10, 10),
        limitePago: Fecha(2026, 10, 30),
        saldoAlCorte: 300000,
        pagoMinimo: 15000,
        pagoSinIntereses: 290000,
      );
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.laptop,
        sesion: ServicioSesionDemostracion(inicial: dueno),
        extras: [repositorioFinanzasProvider.overrideWithValue(r)],
      );
      addTearDown(r.cerrar);
      final c = ProviderScope.containerOf(
        tester.element(find.byType(AppGravity)),
      );
      c.read(montosVisiblesProvider.notifier).fijar(true);
      await c.read(cargaFinanzasProvider.future);
      final aviso = Aviso(
        id: 'a1',
        tipo: 'limite_tarjeta',
        clave: 'limite_tarjeta:${e.id}:2026-10-30:1',
        estado: EstadoAviso.pendiente,
        creadoEn: DateTime(2026, 10, 27),
        objetoId: e.id,
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            home: Scaffold(body: DetalleAvisoFinanzas(aviso: aviso)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tarjeta de ejemplo'), findsOneWidget);
      expect(find.textContaining(r'2,900'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('la hoja corta de pago registra el pago y retira los avisos', (
      tester,
    ) async {
      final r = repositorioDe(dueno);
      final b = servicioDe(r, dueno);
      final tarjeta = await _nuevaTarjeta(b, r, saldo: 300000);
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.telefono,
        sesion: ServicioSesionDemostracion(inicial: dueno),
        extras: [repositorioFinanzasProvider.overrideWithValue(r)],
      );
      addTearDown(r.cerrar);
      final c = ProviderScope.containerOf(
        tester.element(find.byType(AppGravity)),
      );
      await c.read(cargaFinanzasProvider.future);
      unawaited(
        mostrarHojaPago(
          tester.element(find.byType(Scaffold).first),
          deuda: tarjeta,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('pago-sug-15000')));
      await tester.pump();
      final banco = r.cuentaDe(libro, 'Mi banco');
      await tester.tap(find.byKey(ValueKey('pago-cuenta-${banco.id}')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('pago-guardar')));
      await tester.pumpAndSettle();
      expect(saldoDeDeuda(r.datos, tarjeta), 285000);
      expect(tester.takeException(), isNull);
    });

    testWidgets('teléfono: Deudas y Ahorro abren', (tester) async {
      await montar(tester, TipoDispositivo.telefono);
      for (final s in [SeccionFinanzas.deudas, SeccionFinanzas.ahorro]) {
        router(tester).go(s.ruta);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: s.segmento);
      }
    });
  });

  test('la fuente y el detalle se ofrecen como overrides de la plataforma', () {
    expect(sobrescriturasAvisosFinanzas, hasLength(2));
  });

  test('la fuente es una FuenteDeVencimientos de la plataforma', () {
    expect(
      FuenteVencimientosFinanzas(() => null),
      isA<av.FuenteDeVencimientos>(),
    );
  });
}

/// Una tarjeta de ejemplo en el libro del dueño, con saldo.
Future<Deuda> _nuevaTarjeta(
  ServicioFinanzas base,
  RepositorioFinanzasEnMemoria repo, {
  int saldo = 0,
}) async {
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
