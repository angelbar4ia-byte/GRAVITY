// Fase 1 (apoyo de plataforma): las rutas de Finanzas respetan el rol en la
// laptop, el teléfono y la tablet; el (+) y Ctrl + N abren el registro solo
// para quien escribe en Finanzas. Las rutas del módulo se sustituyen por unas
// de ejemplo (rutasFinanzasProvider), así la prueba vale igual con las reales.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gravity/app/app_gravity.dart';
import 'package:gravity/app/navegacion.dart';
import 'package:gravity/app/pantallas/registro_rapido.dart';
import 'package:gravity/app/router.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/contratos/rutas.dart';
import 'package:gravity/nucleo/permisos/permisos.dart';

import 'ayuda_plataforma.dart';

GoRouter routerDe(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(AppGravity)),
).read(routerProvider);

String ubicacion(WidgetTester tester) =>
    routerDe(tester).routerDelegate.currentConfiguration.uri.path;

Future<void> ir(WidgetTester tester, String ruta) async {
  routerDe(tester).go(ruta);
  await tester.pumpAndSettle();
}

Widget _pantalla(String texto) => Scaffold(body: Center(child: Text(texto)));

/// Rutas de Finanzas de ejemplo, con la forma del contrato: la raíz `/` es la
/// pantalla de inicio del módulo y lo demás va con segmentos relativos.
List<RouteBase> rutasDeEjemplo() => [
  GoRoute(
    path: '/',
    builder: (context, estado) => _pantalla('TABLERO DE EJEMPLO'),
    routes: [
      GoRoute(
        path: 'semana',
        builder: (context, estado) => _pantalla('SEMANA DE EJEMPLO'),
      ),
    ],
  ),
  GoRoute(
    path: 'movimientos',
    builder: (context, estado) => _pantalla('MOVIMIENTOS DE EJEMPLO'),
  ),
  GoRoute(
    path: 'asistente',
    metadata: exigeAccion(Accion.administrar),
    builder: (context, estado) => _pantalla('ASISTENTE DE EJEMPLO'),
  ),
];

final conRutasDeEjemplo = [
  rutasFinanzasProvider.overrideWithValue(rutasDeEjemplo()),
];

Finder pestana(String etiqueta) => find.descendant(
  of: find.byType(NavigationBar),
  matching: find.text(etiqueta),
);

Future<void> ctrlN(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}

void main() {
  group('rutas de Finanzas por rol', () {
    for (final dispositivo in [
      TipoDispositivo.laptop,
      TipoDispositivo.telefono,
    ]) {
      for (final rol in [Rol.dueno, Rol.coadministrador]) {
        testWidgets('${rol.name} en ${dispositivo.name}: abre su Finanzas', (
          tester,
        ) async {
          await montarApp(
            tester,
            dispositivo: dispositivo,
            sesion: sesionCon(rol),
            extras: conRutasDeEjemplo,
          );
          await ir(tester, Rutas.finanzas);
          expect(ubicacion(tester), Rutas.finanzas);
          expect(find.text('TABLERO DE EJEMPLO'), findsOneWidget);

          for (final (ruta, texto) in [
            ('${Rutas.finanzas}/semana', 'SEMANA DE EJEMPLO'),
            ('${Rutas.finanzas}/movimientos', 'MOVIMIENTOS DE EJEMPLO'),
            ('${Rutas.finanzas}/asistente', 'ASISTENTE DE EJEMPLO'),
          ]) {
            await ir(tester, ruta);
            expect(ubicacion(tester), ruta);
            expect(find.text(texto), findsOneWidget);
            if (dispositivo == TipoDispositivo.telefono) {
              // En el teléfono, dentro de la pestaña Finanzas.
              final barra = tester.widget<NavigationBar>(
                find.byType(NavigationBar),
              );
              expect(barra.selectedIndex, 1, reason: ruta);
            } else {
              // En la laptop, a pantalla completa dentro del cascarón.
              expect(find.byType(NavigationBar), findsNothing);
            }
          }
        });
      }

      for (final rol in [Rol.familiar, Rol.cuidador]) {
        testWidgets('${rol.name} en ${dispositivo.name}: ni por enlace', (
          tester,
        ) async {
          await montarApp(
            tester,
            dispositivo: dispositivo,
            sesion: sesionCon(rol),
            extras: conRutasDeEjemplo,
          );
          final inicio = inicioDe(rol);
          for (final ruta in [
            Rutas.finanzas,
            '${Rutas.finanzas}/semana',
            '${Rutas.finanzas}/movimientos',
            '${Rutas.finanzas}/asistente',
          ]) {
            await ir(tester, ruta);
            expect(ubicacion(tester), inicio, reason: ruta);
          }
          expect(find.textContaining('DE EJEMPLO'), findsNothing);
        });
      }
    }

    testWidgets('Casa (tablet): ni el modo Casa ni el enlace abren Finanzas', (
      tester,
    ) async {
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.tablet,
        sesion: sesionCon(Rol.casa),
        extras: conRutasDeEjemplo,
      );
      for (final ruta in [Rutas.finanzas, '${Rutas.finanzas}/semana']) {
        await ir(tester, ruta);
        expect(ubicacion(tester), Rutas.inicio, reason: ruta);
      }
      expect(find.textContaining('DE EJEMPLO'), findsNothing);
      revisarSinDinero(tester);
    });

    testWidgets('las rutas reales (o provisionales) se montan en /finanzas', (
      tester,
    ) async {
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.laptop,
        sesion: sesionCon(Rol.dueno),
      );
      await ir(tester, Rutas.finanzas);
      expect(ubicacion(tester), Rutas.finanzas);
      expect(find.text('No encontramos esa pantalla.'), findsNothing);
    });
  });

  group('(+) del teléfono: solo para quien escribe en Finanzas', () {
    for (final rol in [Rol.dueno, Rol.coadministrador]) {
      testWidgets('${rol.name}: Gasto e Ingreso extra abren su registro', (
        tester,
      ) async {
        await montarApp(
          tester,
          dispositivo: TipoDispositivo.telefono,
          sesion: sesionCon(rol),
        );
        for (final (etiqueta, tipo) in [
          ('Gasto', TipoRegistro.gasto),
          ('Ingreso extra', TipoRegistro.ingresoExtra),
        ]) {
          await tester.tap(pestana('Registrar'));
          await tester.pumpAndSettle();
          await tester.tap(find.text(etiqueta));
          await tester.pumpAndSettle();
          final registro = find.byKey(llaveRegistro(tipo));
          expect(registro, findsOneWidget, reason: etiqueta);
          // La hoja del (+) ya se cerró: solo queda el registro.
          expect(find.text('SOS: tengo un antojo'), findsNothing);
          Navigator.of(tester.element(registro)).pop();
          await tester.pumpAndSettle();
          expect(registro, findsNothing);
        }
      });
    }

    for (final rol in [Rol.familiar, Rol.cuidador]) {
      testWidgets('${rol.name}: sin registros de Finanzas', (tester) async {
        await montarApp(
          tester,
          dispositivo: TipoDispositivo.telefono,
          sesion: sesionCon(rol),
        );
        expect(opcionesRegistrar(rol).map((o) => o.modulo), isNot(contains(Modulo.finanzas)));
        if (pestana('Registrar').evaluate().isNotEmpty) {
          await tester.tap(pestana('Registrar'));
          await tester.pumpAndSettle();
        }
        expect(find.text('Gasto'), findsNothing);
        expect(find.text('Ingreso extra'), findsNothing);
      });
    }
  });

  group('Ctrl + N en la laptop', () {
    for (final rol in [Rol.dueno, Rol.coadministrador]) {
      testWidgets('${rol.name}: abre el registro de movimiento en un diálogo', (
        tester,
      ) async {
        await montarApp(
          tester,
          dispositivo: TipoDispositivo.laptop,
          sesion: sesionCon(rol),
        );
        await ctrlN(tester);
        expect(find.byKey(llaveRegistro(TipoRegistro.gasto)), findsOneWidget);
        expect(find.byType(Dialog), findsOneWidget);

        // Esc cierra el diálogo (no se va a GRAVITY por debajo).
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byKey(llaveRegistro(TipoRegistro.gasto)), findsNothing);
      });
    }

    for (final rol in [Rol.familiar, Rol.cuidador]) {
      testWidgets('${rol.name}: no abre nada', (tester) async {
        await montarApp(
          tester,
          dispositivo: TipoDispositivo.laptop,
          sesion: sesionCon(rol),
        );
        await ctrlN(tester);
        expect(find.byKey(llaveRegistro(TipoRegistro.gasto)), findsNothing);
        expect(find.byType(Dialog), findsNothing);
      });
    }
  });
}
