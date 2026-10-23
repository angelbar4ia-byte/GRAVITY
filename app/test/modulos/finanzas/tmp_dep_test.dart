import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gravity/app/app_gravity.dart';
import 'package:gravity/app/router.dart';
import 'package:gravity/modulos/finanzas/datos/demostracion.dart';
import 'package:gravity/modulos/finanzas/estado/proveedores.dart';
import 'package:gravity/modulos/finanzas/finanzas.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_demostracion.dart';
import '../../app/ayuda_plataforma.dart';
import 'ayuda_finanzas.dart';

void main() {
  testWidgets('dep', (tester) async {
    final dueno = sesionDe(Rol.dueno);
    final repo = repositorioDe(dueno);
    await montarApp(tester, dispositivo: TipoDispositivo.laptop,
      sesion: ServicioSesionDemostracion(inicial: dueno),
      extras: [repositorioFinanzasProvider.overrideWithValue(repo)]);
    final c = ProviderScope.containerOf(tester.element(find.byType(AppGravity)));
    c.read(routerProvider).go(SeccionFinanzas.arranque.ruta);
    await tester.pumpAndSettle();
    c.read(libroElegidoProvider.notifier).elegir(IdsDemostracion.libroPapa);
    await tester.pumpAndSettle();
    await tester.tap(find.text('2. Ingresos'));
    await tester.pumpAndSettle();
    final p = find.byKey(const ValueKey('arranque-plantilla-Pensión'));
    print('size ${tester.view.physicalSize} rect ${tester.getRect(p)}');
    await tester.ensureVisible(p);
    print('rect after ${tester.getRect(p)}');
    print(tester.getRect(find.byKey(const ValueKey('arranque-ingreso'))));
    final r = HitTestResult();
    tester.binding.hitTestInView(r, tester.getCenter(p), tester.view.viewId);
    for (final e in r.path.take(40)) { final t = e.target; if (t is RenderObject) { print('HIT ${t.runtimeType} ${t.debugCreator}'); } }
    final w = find.byKey(const ValueKey('arranque-ingreso'));
    print('ingreso hittable: ${w.hitTestable().evaluate().length}; plantilla hittable: ${p.hitTestable().evaluate().length}');
    print('dpr ${tester.view.devicePixelRatio}');
    print('marca ${tester.getRect(find.byKey(const ValueKey('marca-montos-ocultos'))).toString()}');
    print('principal ${tester.getRect(find.byKey(const ValueKey('finanzas-barra-lateral')))}');
    final lv = find.byType(Scrollable);
    for (final e in lv.evaluate()) { print('scrollable ${tester.getRect(find.byElementPredicate((x) => x == e))}'); }
  });
}
