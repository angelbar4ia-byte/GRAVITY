// Montaje de las rutas que exporta un módulo (contrato de la Fase 1:
// relativas a su ruta, con la pantalla de inicio en la raíz) y rutas que
// exigen más que leer (`exigeAccion`).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gravity/app/navegacion.dart';
import 'package:gravity/app/router.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/contratos/rutas.dart';
import 'package:gravity/nucleo/permisos/permisos.dart';

Widget _texto(String texto) => Scaffold(body: Center(child: Text(texto)));

GoRoute _ruta(String path, String texto, {List<RouteBase> rutas = const []}) =>
    GoRoute(
      path: path,
      builder: (context, estado) => _texto(texto),
      routes: rutas,
    );

/// Router mínimo con las rutas de un módulo montadas en `/casa` y el mismo
/// redirect por rol que la app.
Future<GoRouter> montar(
  WidgetTester tester,
  List<RouteBase> rutas, {
  Rol rol = Rol.dueno,
}) async {
  final router = GoRouter(
    initialLocation: '/inicio',
    redirect: (context, estado) {
      final destino = calcularRedireccion(
        ubicacion: estado.uri.path,
        rol: rol,
        dispositivo: TipoDispositivo.laptop,
        accion: accionExigida(estado.metadata),
      );
      // En esta prueba el inicio de la app es /inicio.
      return destino == Rutas.inicio ? '/inicio' : destino;
    },
    routes: [
      _ruta('/inicio', 'INICIO'),
      ...montarRutasDeModulo(Rutas.casa, rutas, modulo: Modulo.casa),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  return router;
}

Future<String> ir(WidgetTester tester, GoRouter router, String ruta) async {
  router.go(ruta);
  await tester.pumpAndSettle();
  return router.routerDelegate.currentConfiguration.uri.path;
}

void main() {
  testWidgets('la raíz "/" queda en la ruta del módulo y lo demás debajo', (
    tester,
  ) async {
    final router = await montar(tester, [
      _ruta('/', 'RAIZ', rutas: [_ruta('semana', 'SEMANA')]),
      _ruta('movimientos', 'MOVIMIENTOS'),
    ]);
    for (final (ruta, texto) in [
      (Rutas.casa, 'RAIZ'),
      ('${Rutas.casa}/semana', 'SEMANA'),
      ('${Rutas.casa}/movimientos', 'MOVIMIENTOS'),
    ]) {
      expect(await ir(tester, router, ruta), ruta);
      expect(find.text(texto), findsOneWidget, reason: ruta);
    }
  });

  testWidgets('también acepta la raíz con la ruta completa del módulo', (
    tester,
  ) async {
    final router = await montar(tester, [
      _ruta(Rutas.casa, 'RAIZ', rutas: [_ruta('semana', 'SEMANA')]),
    ]);
    expect(await ir(tester, router, Rutas.casa), Rutas.casa);
    expect(find.text('RAIZ'), findsOneWidget);
    expect(await ir(tester, router, '${Rutas.casa}/semana'), '/casa/semana');
  });

  testWidgets('sin raíz, la ruta del módulo lleva a su primera pantalla', (
    tester,
  ) async {
    final router = await montar(tester, [
      _ruta('tablero', 'TABLERO'),
      _ruta('semana', 'SEMANA'),
    ]);
    expect(await ir(tester, router, Rutas.casa), '${Rutas.casa}/tablero');
    expect(find.text('TABLERO'), findsOneWidget);
  });

  testWidgets('sin rutas, "Próximamente"', (tester) async {
    final rutas = montarRutasDeModulo(Rutas.casa, const [], modulo: Modulo.casa);
    expect(rutas, hasLength(1));
    expect((rutas.single as GoRoute).path, Rutas.casa);
  });

  testWidgets('exigeAccion: quien solo lee vuelve al inicio del módulo', (
    tester,
  ) async {
    final rutas = [
      _ruta('/', 'RAIZ'),
      GoRoute(
        path: 'editar',
        metadata: exigeAccion(Accion.escribir),
        builder: (context, estado) => _texto('EDITAR'),
        routes: [
          GoRoute(
            path: 'detalle',
            builder: (context, estado) => _texto('DETALLE'),
          ),
        ],
      ),
    ];
    // El familiar lee Casa pero no escribe; la exigencia se hereda.
    final familiar = await montar(tester, rutas, rol: Rol.familiar);
    expect(await ir(tester, familiar, '${Rutas.casa}/editar'), Rutas.casa);
    expect(
      await ir(tester, familiar, '${Rutas.casa}/editar/detalle'),
      Rutas.casa,
    );
    expect(find.text('RAIZ'), findsOneWidget);

    final dueno = await montar(tester, rutas);
    expect(
      await ir(tester, dueno, '${Rutas.casa}/editar'),
      '${Rutas.casa}/editar',
    );
  });

  test('calcularRedireccion con acción, cuenta maestra y acción en Casa', () {
    String? redirigir(
      String ubicacion,
      Rol rol, {
      Accion? accion,
      bool esMaestra = false,
      bool enAccion = false,
      TipoDispositivo dispositivo = TipoDispositivo.laptop,
    }) => calcularRedireccion(
      ubicacion: ubicacion,
      rol: rol,
      dispositivo: dispositivo,
      accion: accion,
      esMaestra: esMaestra,
      enAccionDeTabletCasa: enAccion,
    );

    expect(redirigir('/casa/editar', Rol.familiar, accion: Accion.escribir), '/casa');
    expect(redirigir('/casa/editar', Rol.dueno, accion: Accion.escribir), isNull);
    // D19: la pareja administra su libro de Finanzas.
    expect(
      redirigir('/finanzas/asistente', Rol.coadministrador, accion: Accion.administrar),
      isNull,
    );
    // La cuenta maestra no abre lo que administra el hogar.
    expect(redirigir('/ajustes/personas', Rol.dueno, esMaestra: true), Rutas.ajustes);
    expect(redirigir(Rutas.desarrollador, Rol.dueno, esMaestra: true), Rutas.ajustes);
    expect(redirigir('/ajustes/voz', Rol.dueno, esMaestra: true), isNull);
    // Durante una acción personal en la tablet pública, la pantalla sigue en
    // el modo Casa aunque el inicio de la persona sea otro.
    expect(redirigir(Rutas.inicio, Rol.cuidador), Rutas.cuidados);
    expect(
      redirigir(
        Rutas.inicio,
        Rol.cuidador,
        enAccion: true,
        dispositivo: TipoDispositivo.tablet,
      ),
      isNull,
    );
    // Bandeja de solicitudes: quien lee GRAVITY (la cuidadora incluida).
    expect(redirigir(RutasApp.solicitudes, Rol.cuidador), isNull);
    expect(redirigir(RutasApp.solicitudes, Rol.dueno), isNull);
  });
}
