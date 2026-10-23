/// Ayudas comunes de las pruebas de la revisión de calidad de la Fase 1
/// (docs/revisiones/fase-1.md).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gravity/app/app_gravity.dart';
import 'package:gravity/app/router.dart';
import 'package:gravity/diseno/proveedores.dart' show Reloj, RelojFijo;
import 'package:gravity/modulos/finanzas/datos/repositorio_memoria.dart';
import 'package:gravity/modulos/finanzas/estado/proveedores.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_demostracion.dart';

import '../app/ayuda_plataforma.dart';
import '../modulos/finanzas/ayuda_finanzas.dart';

/// Errores de maquetación que se reconocen: un desborde de `Row` o `Column` y
/// el aviso de `ListTile` cuando su `trailing` ocupa todo el ancho.
bool esDesborde(String texto) =>
    texto.contains('overflowed') ||
    texto.contains('Trailing widget consumes the entire tile width');

/// Errores de Flutter recogidos mientras corría una acción. Guarda un resumen
/// (mensaje corto y archivos de `lib/` que lo causaron).
class RecolectorDeErrores {
  final List<String> resumenes = [];

  /// Solo los desbordes y los `trailing` que ocupan todo el ancho (los demás
  /// errores son consecuencia de estos).
  List<String> get desbordes => [
    for (final r in resumenes)
      if (esDesborde(r)) r,
  ];

  void limpiar() => resumenes.clear();
}

/// Corre [acciones] recogiendo los errores de Flutter (desbordes incluidos) y
/// **devuelve el manejador original antes de terminar**: la prueba decide
/// después con `expect` (Flutter exige que `FlutterError.onError` vuelva a su
/// estado original antes de que acabe la prueba, o se cuelga al fallar).
Future<RecolectorDeErrores> recolectar(Future<void> Function() acciones) async {
  final recolector = RecolectorDeErrores();
  final original = FlutterError.onError;
  FlutterError.onError = (detalles) {
    final linea = detalles.exception.toString().split('\n').first;
    final fuentes = RegExp(r'file:///[^\s]*/lib/[^\s]+')
        .allMatches(detalles.toString())
        .map((m) => m.group(0)!.split('/lib/').last)
        .toSet()
        .join(', ');
    recolector.resumenes.add('$linea ($fuentes)');
  };
  try {
    await acciones();
  } finally {
    FlutterError.onError = original;
  }
  return recolector;
}

/// Avanza un poco el tiempo sin esperar a que todo se asiente (con un desborde
/// de por medio, `pumpAndSettle` puede tardar mucho).
Future<void> avanzar(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

/// Monta la app con el hogar de ejemplo de [rol] en un tamaño y con una
/// escala de letra dados. Devuelve el repositorio en memoria.
Future<RepositorioFinanzasEnMemoria> montarFinanzasConTamano(
  WidgetTester tester, {
  required TipoDispositivo dispositivo,
  required Size tamano,
  double escalaDeLetra = 1.0,
  Rol rol = Rol.dueno,
  int hora = 10,
  Reloj? reloj,
}) async {
  final sesion = sesionDe(rol);
  final repo = repositorioDe(sesion);
  addTearDown(repo.cerrar);
  tester.platformDispatcher.textScaleFactorTestValue = escalaDeLetra;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await montarApp(
    tester,
    dispositivo: dispositivo,
    sesion: ServicioSesionDemostracion(inicial: sesion),
    reloj: reloj ?? RelojFijo(DateTime(2026, 10, 20, hora)),
    extras: [repositorioFinanzasProvider.overrideWithValue(repo)],
  );
  tester.view.physicalSize = tamano;
  await tester.pump();
  await avanzar(tester);
  return repo;
}

/// Va a [ruta] dentro de la app.
Future<void> irA(WidgetTester tester, String ruta) async {
  ProviderScope.containerOf(
    tester.element(find.byType(AppGravity)),
  ).read(routerProvider).go(ruta);
  await avanzar(tester);
}

GoRouter routerDe(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(AppGravity)),
).read(routerProvider);

/// Abre la hoja del (+) del teléfono y elige [opcion] ("Gasto", "Ingreso
/// extra").
Future<void> abrirRegistroDelTelefono(
  WidgetTester tester,
  String opcion,
) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Registrar'),
    ),
  );
  await tester.pump(const Duration(milliseconds: 600));
  await tester.ensureVisible(find.text(opcion));
  await tester.pump(const Duration(milliseconds: 200));
  await tester.tap(find.text(opcion), warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 600));
}
