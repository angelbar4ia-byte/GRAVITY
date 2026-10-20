// Ayudas compartidas por las pruebas del sistema de diseño y de las pantallas
// de GRAVITY. No es una prueba (no termina en _test.dart).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/diseno/diseno.dart';

/// Martes 20 de octubre de 2026, 19:42 (como en los bocetos): de noche.
final momentoNoche = DateTime(2026, 10, 20, 19, 42);

/// Martes 20 de octubre de 2026, 10:15: de día.
final momentoDia = DateTime(2026, 10, 20, 10, 15);

/// Reloj que la prueba puede adelantar.
class RelojMovible implements Reloj {
  RelojMovible(this.momento);

  DateTime momento;

  @override
  DateTime ahora() => momento;
}

/// App mínima con el tema de GRAVITY tomado de los proveedores, como la armará
/// plataforma.
class AppDePrueba extends ConsumerWidget {
  const AppDePrueba({super.key, required this.home});

  final Widget home;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ref.watch(temaClaroProvider),
      darkTheme: ref.watch(temaOscuroProvider),
      themeMode: ref.watch(modoTemaProvider),
      themeAnimationDuration: duracionCambioTema,
      home: home,
    );
  }
}

/// Monta [home] dentro de `ProviderScope` + `MaterialApp` con el reloj fijo.
Future<void> montar(
  WidgetTester tester,
  Widget home, {
  DateTime? momento,
  Reloj? reloj,
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        relojProvider.overrideWithValue(
          reloj ?? RelojFijo(momento ?? momentoNoche),
        ),
        ...overrides,
      ],
      child: AppDePrueba(home: home),
    ),
  );
  await tester.pump();
}

/// Fija el tamaño lógico de la ventana para la prueba.
void fijarVentana(WidgetTester tester, Size tamano) {
  tester.view.physicalSize = tamano;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// El contenedor de Riverpod de la app montada.
ProviderContainer contenedorDe(WidgetTester tester, Finder dentroDe) =>
    ProviderScope.containerOf(tester.element(dentroDe));
