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
import 'package:gravity/modulos/finanzas/datos/demostracion.dart';
import 'package:gravity/modulos/finanzas/datos/repositorio_memoria.dart';
import 'package:gravity/modulos/finanzas/estado/proveedores.dart';
import 'package:gravity/modulos/finanzas/estado/proveedores_fase2.dart';
import 'package:gravity/modulos/finanzas/finanzas.dart';
import 'package:gravity/modulos/finanzas/pantallas/fase2/dialogos_fase2.dart'
    show DialogoTasa;
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

  void formularios(String nombre, Size tamano, double escala) {
    group('formularios de la Fase 2 ($nombre)', () {
      Future<RepositorioFinanzasEnMemoria> montar(
        WidgetTester tester, {
        bool conDeuda = true,
      }) async {
        final repo = await montarFinanzasConTamano(
          tester,
          dispositivo: TipoDispositivo.laptop,
          tamano: tamano,
          escalaDeLetra: escala,
        );
        await _sembrar(repo, conDeuda: conDeuda);
        return repo;
      }

      Future<void> abre(
        WidgetTester tester,
        Finder boton, {
        required String formulario,
        required String lista,
      }) async {
        final errores = await recolectar(() async {
          await tester.scrollUntilVisible(
            boton,
            200,
            scrollable: _lista(lista),
          );
          await tester.ensureVisible(boton);
          await tester.pump(const Duration(milliseconds: 300));
          await tester.tap(boton);
          await avanzar(tester);
        });
        expect(
          errores.desbordes,
          isEmpty,
          reason: '$formulario: ${errores.desbordes}',
        );
        expect(find.byType(AlertDialog), findsOneWidget, reason: formulario);
        // Cerrar para el siguiente.
        await tester.tap(find.text('Cancelar').last);
        await avanzar(tester);
      }

      testWidgets('estado de cuenta, compra a meses y tasa', (tester) async {
        await montar(tester);
        await irA(tester, SeccionFinanzas.deudas.ruta);
        await abre(
          tester,
          find.byKey(const ValueKey('deudas-nuevo-msi')),
          formulario: 'compra a meses',
          lista: 'deudas-lista',
        );
        await abre(
          tester,
          find.widgetWithText(TextButton, 'Estado de cuenta').first,
          formulario: 'estado de cuenta',
          lista: 'deudas-lista',
        );
        // "Captura la tasa" solo sale con datos viejos sin tasa (el servicio ya
        // no deja guardarlos): se abre el formulario directo.
        final contexto = tester.element(find.byType(Scaffold).first);
        final deuda = _contenedor(tester)
            .read(contextoFinanzasProvider)
            .value!
            .datos
            .deudasDe(_libro)
            .first;
        final errores = await recolectar(() async {
          unawaited(
            showDialog<void>(
              context: contexto,
              builder: (_) => DialogoTasa(deuda: deuda),
            ),
          );
          await avanzar(tester);
        });
        expect(errores.desbordes, isEmpty, reason: '${errores.desbordes}');
        expect(find.byType(AlertDialog), findsOneWidget);
      });

      testWidgets('bolsa, aportación y retiro', (tester) async {
        // Sin deuda que reciba el extra, el remanente se reparte al ahorro.
        await montar(tester, conDeuda: false);
        await irA(tester, SeccionFinanzas.ahorro.ruta);
        await abre(
          tester,
          find.byKey(const ValueKey('ahorro-nueva-bolsa')),
          formulario: 'bolsa',
          lista: 'ahorro-lista',
        );
        await abre(
          tester,
          find
              .byWidgetPredicate(
                (w) =>
                    w.key is ValueKey &&
                    '${(w.key! as ValueKey).value}'.startsWith('apartar-'),
              )
              .first,
          formulario: 'aportación',
          lista: 'ahorro-lista',
        );
        await abre(
          tester,
          find
              .byWidgetPredicate(
                (w) =>
                    w.key is ValueKey &&
                    '${(w.key! as ValueKey).value}'.startsWith('retirar-'),
              )
              .first,
          formulario: 'retiro',
          lista: 'ahorro-lista',
        );
      });
    });
  }

  formularios('laptop 900 dp, letra 1.5', _laptop, 1.5);
  formularios('ventana angosta 360 dp, letra 2.0', _telefono, 2.0);
}
