import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gravity/app/app_gravity.dart';
import 'package:gravity/app/router.dart';
import 'package:gravity/modulos/ajustes/secciones_ajustes.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/contratos/rutas.dart';
import 'package:gravity/nucleo/firebase/firebase.dart';
import 'package:gravity/nucleo/tablet/controlador_tablet.dart';

import '../../app/ayuda_plataforma.dart';

GoRouter routerDe(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(AppGravity)),
).read(routerProvider);

String ubicacion(WidgetTester tester) =>
    routerDe(tester).routerDelegate.currentConfiguration.uri.path;

void main() {
  group('secciones visibles', () {
    test('Dueño en la laptop ve todas, con Desarrollador y sin Dispositivos', () {
      expect(seccionesVisibles(Rol.dueno, TipoDispositivo.laptop), [
        for (final seccion in SeccionAjustes.values)
          if (seccion != SeccionAjustes.dispositivos) seccion,
      ]);
    });

    test('Dispositivos: solo el Dueño y solo en la tablet', () {
      expect(
        seccionesVisibles(Rol.dueno, TipoDispositivo.tablet),
        contains(SeccionAjustes.dispositivos),
      );
      for (final rol in [Rol.coadministrador, Rol.familiar, Rol.cuidador]) {
        expect(
          seccionesVisibles(rol, TipoDispositivo.tablet),
          isNot(contains(SeccionAjustes.dispositivos)),
        );
      }
    });

    test('cuenta maestra (D19): sin lo que administra el hogar', () {
      expect(
        seccionesVisibles(
          Rol.dueno,
          TipoDispositivo.laptop,
          esMaestra: true,
        ),
        [
          SeccionAjustes.apariencia,
          SeccionAjustes.voz,
          SeccionAjustes.privacidad,
          SeccionAjustes.notificaciones,
        ],
      );
    });

    test('Dueño en el teléfono: sin Desarrollador', () {
      expect(
        seccionesVisibles(Rol.dueno, TipoDispositivo.telefono),
        isNot(contains(SeccionAjustes.desarrollador)),
      );
      expect(
        seccionesVisibles(Rol.dueno, TipoDispositivo.telefono),
        contains(SeccionAjustes.personas),
      );
    });

    test('los demás roles: lo propio, sin Personas ni Copias', () {
      for (final rol in [Rol.coadministrador, Rol.familiar, Rol.cuidador]) {
        expect(seccionesVisibles(rol, TipoDispositivo.laptop), [
          SeccionAjustes.apariencia,
          SeccionAjustes.voz,
          SeccionAjustes.privacidad,
          SeccionAjustes.notificaciones,
        ], reason: '$rol');
      }
    });

    test('Casa no tiene Ajustes', () {
      expect(seccionesVisibles(Rol.casa, TipoDispositivo.tablet), isEmpty);
    });

    test('rutas: Desarrollador es la del contrato', () {
      expect(rutaSeccion(SeccionAjustes.desarrollador), Rutas.desarrollador);
      expect(rutaSeccion(SeccionAjustes.voz), '/ajustes/voz');
      expect(seccionDeRuta('/ajustes/voz'), SeccionAjustes.voz);
      expect(seccionDeRuta(Rutas.ajustes), isNull);
    });
  });

  testWidgets('teléfono: Ajustes desde Más y regreso', (tester) async {
    await montarApp(
      tester,
      dispositivo: TipoDispositivo.telefono,
      sesion: sesionCon(Rol.dueno),
      extras: [
        estadoFirebaseProvider.overrideWithValue(EstadoFirebase.sinConfiguracion),
      ],
    );
    await tester.tap(find.text('Más'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    for (final titulo in [
      'Apariencia',
      'Voz',
      'Personas y roles',
      'Privacidad',
      'Copias de seguridad',
      'Notificaciones',
    ]) {
      expect(find.text(titulo), findsOneWidget, reason: titulo);
    }
    expect(find.text('Desarrollador'), findsNothing);

    await tester.tap(find.text('Notificaciones'));
    await tester.pumpAndSettle();
    expect(find.textContaining('falta la configuración de Firebase'), findsOneWidget);
    await tester.tap(find.byTooltip('Regresar'));
    await tester.pumpAndSettle();
    expect(ubicacion(tester), Rutas.ajustes);
  });

  testWidgets('Familiar: sin Personas y roles', (tester) async {
    await montarApp(
      tester,
      dispositivo: TipoDispositivo.telefono,
      sesion: sesionCon(Rol.familiar),
    );
    routerDe(tester).go(Rutas.ajustes);
    await tester.pumpAndSettle();
    expect(find.text('Apariencia'), findsOneWidget);
    expect(find.text('Personas y roles'), findsNothing);
    expect(find.text('Copias de seguridad'), findsNothing);
  });

  testWidgets('cuidadora: Ajustes desde el menú de la cuenta', (tester) async {
    await montarApp(
      tester,
      dispositivo: TipoDispositivo.telefono,
      sesion: sesionCon(Rol.cuidador),
    );
    await tester.tap(find.byTooltip('Cuenta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    expect(ubicacion(tester), Rutas.ajustes);
    expect(find.text('Voz'), findsOneWidget);
  });

  testWidgets('laptop: Desarrollador para el Dueño', (tester) async {
    await montarApp(
      tester,
      dispositivo: TipoDispositivo.laptop,
      sesion: sesionCon(Rol.dueno),
    );
    routerDe(tester).go(Rutas.ajustes);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Desarrollador'));
    await tester.pumpAndSettle();
    expect(ubicacion(tester), Rutas.desarrollador);
  });

  testWidgets('tablet: el Dueño administra las personas y el tiempo', (
    tester,
  ) async {
    await montarApp(
      tester,
      dispositivo: TipoDispositivo.tablet,
      sesion: sesionCon(Rol.casa),
      almacen: await almacenConPersonas({
        Rol.dueno: '1234',
        Rol.familiar: '4321',
      }),
    );
    await tester.tap(find.text('Dueño de ejemplo'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo-pin')), '1234');
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pumpAndSettle();

    routerDe(tester).go('/ajustes/personas');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Personas de esta tablet'), 200);
    expect(find.text('Familiar de ejemplo'), findsOneWidget);

    final selector = find.byType(DropdownButton<Duration>);
    await tester.ensureVisible(selector);
    await tester.pumpAndSettle();
    await tester.tap(selector);
    await tester.pumpAndSettle();
    await tester.tap(find.text('5 minutos').last);
    await tester.pumpAndSettle();
    final contenedor = ProviderScope.containerOf(
      tester.element(find.byType(AppGravity)),
    );
    expect(
      contenedor.read(controladorTabletProvider).configuracion.regresoModoCasa,
      const Duration(minutes: 5),
    );
  });
}
