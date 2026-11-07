// Ayudas compartidas por las pruebas del sistema de diseño y de las pantallas
// de GRAVITY. No es una prueba (no termina en _test.dart).

import 'package:finanzas_dominio/finanzas_dominio.dart' as dom;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/sesion_efectiva.dart';
import 'package:gravity/diseno/diseno.dart';
import 'package:gravity/modulos/finanzas/estado/resumen_hoy.dart';
import 'package:gravity/modulos/gravity/pantalla/resumen_gravity.dart';
import 'package:gravity/nucleo/permisos/permisos.dart' show puedeAbrir;
import 'package:gravity/nucleo/contratos/roles.dart';

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

/// Resumen de Finanzas de ejemplo (nunca datos reales): un libro con $3,500 de
/// presupuesto y $2,170 gastados, o sea, "Quedan \$1,330.00".
final resumenFinanzasEjemplo = ResumenFinanzasHoy(EstadoResumenHoy.conLibros, [
  ResumenLibroHoy(
    libroId: 'libro-ejemplo',
    nombre: 'Mi libro',
    tipo: dom.TipoLibro.personal,
    alertasCriticas: 1,
    cifras: CifrasSemana(
      semana: dom.Semana.de(dom.Fecha(2026, 10, 20)),
      ingresoPlaneado: 400000,
      ingresoReal: 400000,
      presupuesto: 350000,
      gastado: 217000,
      deuda: 0,
      abonado: 0,
      remanentePlaneado: 50000,
      remanenteReal: 50000,
      semaforo: dom.Semaforo.verde,
      sinDatos: false,
    ),
  ),
]);

/// Montos a la vista desde el primer cuadro (en la app, empiezan ocultos).
class _Visibles extends MontosVisibles {
  @override
  bool build() => true;
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

/// Monta [home] dentro de `ProviderScope` + `MaterialApp` con el reloj fijo y
/// el [rol] efectivo (por omisión, el Dueño, que ve todos los paneles). Los
/// [datos] del resumen de GRAVITY son los de ejemplo de los bocetos. Los montos
/// empiezan **ocultos**, como en la app; con [montosVisibles] se ven.
Future<void> montar(
  WidgetTester tester,
  Widget home, {
  DateTime? momento,
  Reloj? reloj,
  Rol? rol = Rol.dueno,
  ResumenGravity datos = ResumenGravity.ejemplo,
  ResumenFinanzasHoy? finanzasHoy,
  bool montosVisibles = false,
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        relojProvider.overrideWithValue(
          reloj ?? RelojFijo(momento ?? momentoNoche),
        ),
        rolEfectivoProvider.overrideWithValue(rol),
        // Sin servicio de sesión, las pruebas usan los datos de ejemplo de los
        // bocetos (con una sesión real el resumen viene vacío: I9).
        datosResumenGravityProvider.overrideWithValue(datos),
        resumenFinanzasHoyProvider.overrideWithValue(
          finanzasHoy ??
              (rol != null && puedeAbrir(rol, Modulo.finanzas)
                  ? resumenFinanzasEjemplo
                  : ResumenFinanzasHoy.sinAcceso),
        ),
        if (montosVisibles) montosVisiblesProvider.overrideWith(_Visibles.new),
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

/// Letra del sistema al [escala] (1.0 es normal; 2.0 es el máximo de Android)
/// durante la prueba.
void fijarEscalaDeLetra(WidgetTester tester, double escala) {
  tester.platformDispatcher.textScaleFactorTestValue = escala;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// Corre [acciones] recogiendo los errores de maquetación de Flutter (un
/// desborde de `Row`/`Column`, o un `trailing` que ocupa todo el `ListTile`) y
/// los devuelve como líneas cortas. El manejador original vuelve antes de
/// terminar: la prueba decide después con `expect`.
Future<List<String>> recolectarDesbordes(
  Future<void> Function() acciones,
) async {
  final desbordes = <String>[];
  final original = FlutterError.onError;
  FlutterError.onError = (detalles) {
    final linea = detalles.exception.toString().split('\n').first;
    if (linea.contains('overflowed') ||
        linea.contains('Trailing widget consumes the entire tile width')) {
      final fuentes = RegExp(r'file:///[^\s]*/lib/[^\s]+')
          .allMatches(detalles.toString())
          .map((m) => m.group(0)!.split('/lib/').last)
          .toSet()
          .join(', ');
      desbordes.add('$linea ($fuentes)');
    }
  };
  try {
    await acciones();
  } finally {
    FlutterError.onError = original;
  }
  return desbordes;
}
