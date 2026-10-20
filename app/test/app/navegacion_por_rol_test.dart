import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gravity/app/app_gravity.dart';
import 'package:gravity/app/router.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/contratos/rutas.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_demostracion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_falso.dart';

import 'ayuda_plataforma.dart';

Finder pestana(String etiqueta) => find.descendant(
  of: find.byType(NavigationBar),
  matching: find.text(etiqueta),
);

GoRouter routerDe(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(AppGravity)),
).read(routerProvider);

String ubicacion(WidgetTester tester) =>
    routerDe(tester).routerDelegate.currentConfiguration.uri.path;

void main() {
  group('entrar', () {
    testWidgets('sin sesión se pide entrar; con la cuenta se llega al inicio', (
      tester,
    ) async {
      final sesion = ServicioSesionFalso(
        cuentas: {
          'ana@ejemplo.mx': CuentaFalsa('secreta', sesionDeEjemplo(Rol.cuidador)),
        },
      );
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.telefono,
        sesion: sesion,
      );
      expect(find.text('Entra con tu cuenta'), findsOneWidget);
      expect(find.text('Modo demostración'), findsNothing);

      await tester.tap(find.text('Entrar'));
      await tester.pump();
      expect(find.text('Escribe tu correo.'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), 'ana@ejemplo.mx');
      await tester.enterText(find.byType(TextFormField).at(1), 'mala');
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();
      expect(find.text('Correo o contraseña incorrectos.'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(1), 'secreta');
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();
      // La cuidadora entra directo a "Mi turno".
      expect(ubicacion(tester), Rutas.cuidados);
      expect(pestana('Mi turno'), findsOneWidget);
    });

    testWidgets('modo demostración: selector de rol', (tester) async {
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.telefono,
        sesion: ServicioSesionDemostracion(),
      );
      expect(find.text('Modo demostración'), findsOneWidget);
      await tester.ensureVisible(find.text('Entrar como Familiar'));
      await tester.tap(find.text('Entrar como Familiar'));
      await tester.pumpAndSettle();
      expect(pestana('Hoy'), findsOneWidget);
      expect(pestana('Finanzas'), findsNothing);
    });

    testWidgets('salir regresa a Entrar', (tester) async {
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.telefono,
        sesion: sesionCon(Rol.familiar),
      );
      await tester.tap(pestana('Más'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salir'));
      await tester.pumpAndSettle();
      expect(find.text('Entra con tu cuenta'), findsOneWidget);
    });
  });

  group('teléfono: barra inferior por rol', () {
    testWidgets('Dueño: Hoy · Finanzas · (+) · Hábitos · Más', (tester) async {
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.telefono,
        sesion: sesionCon(Rol.dueno),
      );
      for (final etiqueta in ['Hoy', 'Finanzas', 'Registrar', 'Hábitos', 'Más']) {
        expect(pestana(etiqueta), findsOneWidget, reason: etiqueta);
      }
      await tester.tap(pestana('Finanzas'));
      await tester.pumpAndSettle();
      expect(find.text('Finanzas llega en la Fase 1.'), findsOneWidget);

      await tester.tap(pestana('Registrar'));
      await tester.pumpAndSettle();
      expect(find.text('Gasto'), findsOneWidget);
      expect(find.text('SOS: tengo un antojo'), findsOneWidget);
      await tester.tap(find.text('Gasto'));
      await tester.pumpAndSettle();
      expect(find.text('Gasto: llega en la Fase 1.'), findsOneWidget);

      await tester.tap(pestana('Más'));
      await tester.pumpAndSettle();
      expect(find.text('Cuidados'), findsOneWidget);
      expect(find.text('Ajustes'), findsOneWidget);
    });

    testWidgets('Pareja: Finanzas de lectura y sin "Gasto" en (+)', (
      tester,
    ) async {
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.telefono,
        sesion: sesionCon(Rol.coadministrador),
      );
      expect(pestana('Finanzas'), findsOneWidget);
      await tester.tap(pestana('Registrar'));
      await tester.pumpAndSettle();
      expect(find.text('Gasto'), findsNothing);
      expect(find.text('Hábito'), findsOneWidget);
    });

    testWidgets('Familiar no ve dinero, ni por enlace directo', (tester) async {
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.telefono,
        sesion: sesionCon(Rol.familiar),
      );
      for (final etiqueta in ['Hoy', 'Hábitos', 'Más']) {
        expect(pestana(etiqueta), findsOneWidget);
      }
      expect(pestana('Finanzas'), findsNothing);
      expect(pestana('Registrar'), findsNothing);

      routerDe(tester).go(Rutas.finanzas);
      await tester.pumpAndSettle();
      expect(ubicacion(tester), Rutas.inicio);
      expect(find.textContaining('Finanzas'), findsNothing);

      await tester.tap(pestana('Más'));
      await tester.pumpAndSettle();
      expect(find.text('Finanzas'), findsNothing);
      expect(find.text('Alimentación'), findsOneWidget);
    });

    testWidgets('Cuidador solo ve Cuidados', (tester) async {
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.telefono,
        sesion: sesionCon(Rol.cuidador),
      );
      expect(ubicacion(tester), Rutas.cuidados);
      final etiquetas = tester
          .widgetList<NavigationDestination>(find.byType(NavigationDestination))
          .map((d) => d.label)
          .toList();
      expect(etiquetas, ['Mi turno', 'Medicamentos', 'Comidas', 'Bitácora']);

      await tester.tap(pestana('Bitácora'));
      await tester.pumpAndSettle();
      expect(ubicacion(tester), '/cuidados/bitacora');

      for (final ruta in [
        Rutas.inicio,
        Rutas.finanzas,
        Rutas.habitos,
        Rutas.alimentacion,
        Rutas.casa,
      ]) {
        routerDe(tester).go(ruta);
        await tester.pumpAndSettle();
        expect(ubicacion(tester), Rutas.cuidados, reason: ruta);
      }
    });
  });

  group('laptop', () {
    testWidgets('Dueño: pantalla principal a pantalla completa y Desarrollador', (
      tester,
    ) async {
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.laptop,
        sesion: sesionCon(Rol.dueno),
      );
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('GRAVITY'), findsOneWidget);

      // Ctrl + 1 abre Finanzas; Esc vuelve a GRAVITY.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(ubicacion(tester), Rutas.finanzas);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(ubicacion(tester), Rutas.inicio);

      routerDe(tester).go(Rutas.desarrollador);
      await tester.pumpAndSettle();
      expect(ubicacion(tester), Rutas.desarrollador);
      expect(find.text('Desarrollador'), findsWidgets);
    });

    testWidgets('la barra de órdenes navega', (tester) async {
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.laptop,
        sesion: sesionCon(Rol.dueno),
      );
      await tester.enterText(find.byType(TextField), 'abre hábitos');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(ubicacion(tester), Rutas.habitos);
    });

    testWidgets('Pareja no abre Desarrollador ni Personas y roles', (
      tester,
    ) async {
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.laptop,
        sesion: sesionCon(Rol.coadministrador),
      );
      routerDe(tester).go(Rutas.desarrollador);
      await tester.pumpAndSettle();
      expect(ubicacion(tester), Rutas.ajustes);
      routerDe(tester).go('/ajustes/personas');
      await tester.pumpAndSettle();
      expect(ubicacion(tester), Rutas.ajustes);
    });
  });
}
