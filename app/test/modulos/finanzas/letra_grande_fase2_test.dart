// Letra 2.0 en 360 dp (teléfono) y letra 1.5 en 900 dp (laptop) para la
// proyección, la tarjeta "¿y si abono más cada semana?" y las vistas y
// formularios de la Fase 2 de Finanzas (Fase 4, F4-3.6). Se parece a
// `f1_i6_letra_grande_telefono_test.dart`: cero desbordes y las acciones a la
// vista. Datos de ejemplo inventados.
import 'package:finanzas_dominio/finanzas_dominio.dart'
    show
        ClaseDeuda,
        Semana,
        TipoBolsaAhorro,
        TipoCuenta,
        TipoDeuda,
        Deuda,
        CalendarioConfig,
        ReglaDiaInhabil,
        Frecuencia;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/app_gravity.dart';
import 'package:gravity/diseno/diseno.dart'
    show formatearCentavos, montosVisiblesProvider;
import 'package:gravity/modulos/finanzas/casos_uso/servicio_fase2.dart';
import 'package:gravity/modulos/finanzas/casos_uso/servicio_finanzas.dart';
import 'package:gravity/modulos/finanzas/datos/demostracion.dart';
import 'package:gravity/modulos/finanzas/datos/repositorio_memoria.dart';
import 'package:gravity/modulos/finanzas/estado/proveedores.dart';
import 'package:gravity/modulos/finanzas/estado/proveedores_fase2.dart';
import 'package:gravity/modulos/finanzas/finanzas.dart';
import 'package:gravity/modulos/finanzas/pantallas/fase2/dialogos_fase2.dart'
    show
        DialogoBolsa,
        DialogoConfirmarAportacion,
        DialogoEstadoDeCuenta,
        DialogoMsi,
        DialogoRetiro,
        DialogoTasa;
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';

import '../../revision_calidad/ayuda_calidad.dart';
import 'ayuda_finanzas.dart';

const _telefono = Size(360, 800);
const _laptop = Size(900, 800);
const _libro = IdsDemostracion.libroDueno;

/// Una tarjeta con saldo y sin tasa, una bolsa con saldo y la semana activada
/// con su reparto propuesto: lo que hace falta para abrir todos los
/// formularios de la Fase 2.
Future<void> _sembrar(
  RepositorioFinanzasEnMemoria repo, {
  bool conDeuda = true,
}) async {
  final base = servicioDe(repo, sesionDe(Rol.dueno));
  final svc = ServicioDeudasAhorro(base);
  if (conDeuda) {
    final cuenta = await base.crearCuenta(
      libroId: _libro,
      nombre: 'Tarjeta de ejemplo',
      tipo: TipoCuenta.tarjeta,
      saldoInicial: 500000,
      limiteCentavos: 1000000,
    );
    await base.guardarDeuda(
      Deuda(
        id: base.nuevoId(),
        libroId: _libro,
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
      ),
    );
  }
  await svc.crearBolsa(
    libroId: _libro,
    nombre: 'Celular',
    tipo: TipoBolsaAhorro.metaLibre,
    meta: 1000000,
    aporteFijo: 20000,
    saldoInicial: 50000,
  );
  final semana = Semana.de(hoyDePrueba);
  await base.activarSemana(_libro, semana);
  await svc.proponerReparto(libroId: _libro, semana: semana, remanente: 100000);
}

ProviderContainer _contenedor(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(AppGravity)));

Finder _lista(String llave) => find
    .descendant(
      of: find.byKey(ValueKey(llave)),
      matching: find.byType(Scrollable),
    )
    .first;

void main() {
  final pantallas = {
    'Deudas': SeccionFinanzas.deudas,
    'Ahorro y fondo': SeccionFinanzas.ahorro,
    'Vencimientos': SeccionFinanzas.vencimientos,
  };

  group('Vistas de la Fase 2 con letra grande', () {
    for (final e in pantallas.entries) {
      testWidgets('${e.key}: teléfono 360 dp con letra 2.0 sin desbordes', (
        tester,
      ) async {
        final repo = await montarFinanzasConTamano(
          tester,
          dispositivo: TipoDispositivo.telefono,
          tamano: _telefono,
          escalaDeLetra: 2.0,
        );
        await _sembrar(repo);
        final errores = await recolectar(() => irA(tester, e.value.ruta));
        expect(
          errores.desbordes,
          isEmpty,
          reason: errores.desbordes.join('\n'),
        );
      });

      testWidgets('${e.key}: laptop 900 dp con letra 1.5 sin desbordes', (
        tester,
      ) async {
        final repo = await montarFinanzasConTamano(
          tester,
          dispositivo: TipoDispositivo.laptop,
          tamano: _laptop,
          escalaDeLetra: 1.5,
        );
        await _sembrar(repo);
        final errores = await recolectar(() => irA(tester, e.value.ruta));
        expect(
          errores.desbordes,
          isEmpty,
          reason: errores.desbordes.join('\n'),
        );
      });
    }

    testWidgets('Ahorro con el reparto propuesto: teléfono 360 dp, letra 2.0, '
        'Apartar y Después caben', (tester) async {
      final repo = await montarFinanzasConTamano(
        tester,
        dispositivo: TipoDispositivo.telefono,
        tamano: _telefono,
        escalaDeLetra: 2.0,
      );
      await _sembrar(repo, conDeuda: false);
      final errores = await recolectar(
        () => irA(tester, SeccionFinanzas.ahorro.ruta),
      );
      expect(errores.desbordes, isEmpty, reason: errores.desbordes.join('\n'));
      final apartar = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey &&
            '${(w.key! as ValueKey).value}'.startsWith('apartar-'),
      );
      expect(apartar, findsWidgets, reason: 'hay un reparto propuesto');
    });

    testWidgets('la hoja corta de pago (teléfono, letra 2.0) cabe y Guardar '
        'queda a la vista', (tester) async {
      final repo = await montarFinanzasConTamano(
        tester,
        dispositivo: TipoDispositivo.telefono,
        tamano: _telefono,
        escalaDeLetra: 2.0,
      );
      await _sembrar(repo);
      await irA(tester, SeccionFinanzas.deudas.ruta);
      final errores = await recolectar(() async {
        final deuda = _contenedor(tester)
            .read(contextoFinanzasProvider)
            .value!
            .datos
            .deudasDe(_libro)
            .first;
        final tarjeta = find.byKey(ValueKey('deuda-${deuda.id}'));
        await tester.scrollUntilVisible(
          tarjeta,
          200,
          scrollable: _lista('deudas-lista'),
        );
        await tester.ensureVisible(tarjeta);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(tarjeta);
        await avanzar(tester);
      });
      expect(errores.desbordes, isEmpty, reason: errores.desbordes.join('\n'));
      final guardar = find.byKey(const ValueKey('pago-guardar'));
      expect(guardar, findsOneWidget);
      expect(tester.getRect(guardar).right, lessThanOrEqualTo(360));
    });
  });

  group('la tarjeta "¿y si abono más cada semana?" y su proyección', () {
    testWidgets('360 dp, letra 2.0: se lee, se usa y no se desborda', (
      tester,
    ) async {
      final repo = await montarFinanzasConTamano(
        tester,
        dispositivo: TipoDispositivo.telefono,
        tamano: _telefono,
        escalaDeLetra: 2.0,
      );
      await _sembrar(repo);
      final errores = await recolectar(() async {
        await irA(tester, SeccionFinanzas.deudas.ruta);
        final campo = find.byKey(const ValueKey('abono-extra-monto'));
        await tester.scrollUntilVisible(
          campo,
          200,
          scrollable: _lista('deudas-lista'),
        );
        // Con el teclado del sistema abierto el campo sigue a la vista.
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        addTearDown(tester.view.resetViewInsets);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.enterText(campo, '500');
        await avanzar(tester);
      });
      expect(errores.desbordes, isEmpty, reason: errores.desbordes.join('\n'));
      expect(
        find.byKey(const ValueKey('abono-extra-semanas')),
        findsOneWidget,
        reason: 'la proyección aparece al escribir el extra',
      );
      expect(
        find.byKey(const ValueKey('abono-extra-monto')).hitTestable(),
        findsOneWidget,
      );
    });

    testWidgets('con los montos ocultos no hay cifras de dinero en la '
        'tarjeta, ni en el texto ni en la semántica', (tester) async {
      final repo = await montarFinanzasConTamano(
        tester,
        dispositivo: TipoDispositivo.telefono,
        tamano: _telefono,
        escalaDeLetra: 2.0,
      );
      await _sembrar(repo);
      await irA(tester, SeccionFinanzas.deudas.ruta);
      final tarjeta = find.byKey(const ValueKey('deudas-abono-extra'));
      await tester.scrollUntilVisible(
        tarjeta,
        200,
        scrollable: _lista('deudas-lista'),
      );
      await tester.enterText(
        find.byKey(const ValueKey('abono-extra-monto')),
        '500',
      );
      await avanzar(tester);
      final dinero = RegExp(r'\$\s*\d');
      final textos = find.descendant(of: tarjeta, matching: find.byType(Text));
      for (final t in tester.widgetList<Text>(textos)) {
        expect(dinero.hasMatch(t.data ?? ''), isFalse, reason: t.data);
      }
      expect(dinero.hasMatch(tester.getSemantics(tarjeta).label), isFalse);
    });

    testWidgets('el resultado coincide al centavo con el cálculo del dominio', (
      tester,
    ) async {
      final repo = await montarFinanzasConTamano(
        tester,
        dispositivo: TipoDispositivo.laptop,
        tamano: _laptop,
        escalaDeLetra: 1.5,
      );
      await _sembrar(repo);
      await irA(tester, SeccionFinanzas.deudas.ruta);
      final contenedor = _contenedor(tester);
      contenedor.read(montosVisiblesProvider.notifier).fijar(true);
      final tarjeta = find.byKey(const ValueKey('deudas-abono-extra'));
      await tester.scrollUntilVisible(
        tarjeta,
        200,
        scrollable: _lista('deudas-lista'),
      );
      await tester.enterText(
        find.byKey(const ValueKey('abono-extra-monto')),
        '500',
      );
      await avanzar(tester);
      final c = contenedor.read(contextoFinanzasProvider).value!;
      final esperado = contenedor
          .read(servicioFase2Provider)
          .abonoExtra(c.libroId, Semana.de(c.hoy), 50000)!;
      expect(
        find.descendant(
          of: tarjeta,
          matching: find.text(formatearCentavos(esperado.interesesAhorrados)),
        ),
        findsOneWidget,
      );
    });
  });

  // Los formularios se abren directo (en el teléfono no hay botones para
  // todos): el contenido es el mismo en ambos tamaños.
  void formularios(
    String nombre,
    TipoDispositivo dispositivo,
    Size tamano,
    double escala,
  ) {
    testWidgets('formularios de la Fase 2 ($nombre): sin desbordes y con '
        'Guardar a la vista', (tester) async {
      final repo = await montarFinanzasConTamano(
        tester,
        dispositivo: dispositivo,
        tamano: tamano,
        escalaDeLetra: escala,
      );
      await _sembrar(repo, conDeuda: false);
      final base = servicioDe(repo, sesionDe(Rol.dueno));
      await _tarjeta(base);
      await irA(tester, SeccionFinanzas.ahorro.ruta);
      final contenedor = _contenedor(tester);
      final c = contenedor.read(contextoFinanzasProvider).value!;
      final deuda = c.datos.deudasDe(_libro).first;
      final bolsa = c.datos.bolsasDe(_libro).first;
      final aportacion = c.datos.aportaciones.firstWhere((a) => a.sugerido > 0);
      final contexto = tester.element(find.byType(Scaffold).first);
      final formularios = <String, Widget>{
        'estado de cuenta': DialogoEstadoDeCuenta(deuda: deuda),
        'tasa': DialogoTasa(deuda: deuda),
        'compra a meses': DialogoMsi(contexto: c),
        'bolsa': DialogoBolsa(contexto: c),
        'aportación': DialogoConfirmarAportacion(
          contexto: c,
          aportacion: aportacion,
          nombreBolsa: bolsa.nombre,
        ),
        'retiro': DialogoRetiro(contexto: c, bolsa: bolsa),
      };
      for (final f in formularios.entries) {
        final errores = await recolectar(() async {
          unawaited(
            showDialog<void>(context: contexto, builder: (_) => f.value),
          );
          await avanzar(tester);
          expect(find.byType(AlertDialog), findsOneWidget, reason: f.key);
          final guardar = find.byKey(const ValueKey('dialogo-guardar'));
          if (guardar.evaluate().isNotEmpty) {
            await tester.ensureVisible(guardar);
            expect(
              tester.getRect(guardar).right,
              lessThanOrEqualTo(tamano.width),
              reason: '${f.key}: Guardar no se corta',
            );
          }
          await tester.tap(find.text('Cancelar').last);
          await avanzar(tester);
        });
        expect(
          errores.desbordes,
          isEmpty,
          reason: '${f.key}: ${errores.desbordes}',
        );
      }
    });
  }

  formularios('laptop 900 dp, letra 1.5', TipoDispositivo.laptop, _laptop, 1.5);
  formularios(
    'teléfono 360 dp, letra 2.0',
    TipoDispositivo.telefono,
    _telefono,
    2.0,
  );
}

/// Una tarjeta con saldo para los formularios de estado de cuenta y tasa.
Future<void> _tarjeta(ServicioFinanzas base) async {
  final cuenta = await base.crearCuenta(
    libroId: _libro,
    nombre: 'Tarjeta de ejemplo',
    tipo: TipoCuenta.tarjeta,
    saldoInicial: 500000,
    limiteCentavos: 1000000,
  );
  await base.guardarDeuda(
    Deuda(
      id: base.nuevoId(),
      libroId: _libro,
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
    ),
  );
}
