// D14 (actualizada el 21/oct/2026): tablet personal y tablet pública de la
// casa, elegidas en Ajustes › Dispositivos. Solo PIN en las dos.
//
// - Personal: en reposo, bloqueo con los perfiles permitidos; sin modo Casa;
//   tras 2 min sin uso vuelve al bloqueo.
// - Pública: leer sin identidad (modo Casa, sin dinero); registrar algo de la
//   casa pide el nombre sin PIN; algo personal, nombre y PIN solo para esa
//   acción (o 2 min).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/app_gravity.dart';
import 'package:gravity/app/navegacion.dart';
import 'package:gravity/app/pantallas/registro_rapido.dart';
import 'package:gravity/app/router.dart';
import 'package:gravity/app/sesion_efectiva.dart';
import 'package:gravity/app/tablet/pantalla_modo_casa.dart';
import 'package:gravity/app/tablet/registro_tablet_casa.dart';
import 'package:gravity/nucleo/base_local/base_local.dart';
import 'package:gravity/nucleo/cola/proveedores_cola.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/contratos/rutas.dart';
import 'package:gravity/nucleo/sesion/proveedores_sesion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_demostracion.dart';
import 'package:gravity/nucleo/sesion/sesion.dart';
import 'package:gravity/nucleo/tablet/controlador_tablet.dart';
import 'package:gravity/nucleo/tablet/usuarios_tablet.dart';

import 'ayuda_plataforma.dart';

const nombreDueno = 'Dueño de ejemplo';
const nombrePareja = 'Pareja de ejemplo';
const nombreFamiliar = 'Familiar de ejemplo';
const llaveBloqueo = ValueKey('bloqueo-tablet-personal');

String id(Rol rol) => sesionDeEjemplo(rol).persona.id;

ProviderContainer contenedorDe(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(AppGravity)));

String ubicacion(WidgetTester tester) => contenedorDe(
  tester,
).read(routerProvider).routerDelegate.currentConfiguration.uri.path;

EstadoTablet estadoTablet(WidgetTester tester) =>
    contenedorDe(tester).read(controladorTabletProvider);

String? personaEnServidor(WidgetTester tester) =>
    (contenedorDe(tester).read(servicioSesionProvider) as SesionesPorPersona)
        .personaEnServidor;

Finder enRiel(String etiqueta) => find.descendant(
  of: find.byType(NavigationRail),
  matching: find.text(etiqueta),
);

Future<void> escribirPin(WidgetTester tester, String pin) async {
  await tester.enterText(find.byKey(const Key('campo-pin')), pin);
  await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
  await tester.pumpAndSettle();
}

/// Tablet personal con el dueño permitido (y la pareja y un familiar
/// registrados, sin permiso).
Future<void> montarPersonal(WidgetTester tester) async => montarApp(
  tester,
  dispositivo: TipoDispositivo.tablet,
  sesion: sesionCon(Rol.casa),
  almacen: await almacenConPersonas(
    {Rol.dueno: '1234', Rol.coadministrador: '2222', Rol.familiar: '3333'},
    configuracion: ConfiguracionTablet(
      tipo: TipoTablet.personal,
      permitidas: {id(Rol.dueno)},
    ),
  ),
);

/// Tablet pública con dueño y familiar.
Future<void> montarPublica(WidgetTester tester, {BaseLocal? base}) async =>
    montarApp(
      tester,
      dispositivo: TipoDispositivo.tablet,
      sesion: sesionCon(Rol.casa),
      base: base,
      almacen: await almacenConPersonas({
        Rol.dueno: '1234',
        Rol.familiar: '3333',
      }),
    );

/// Modo Casa › Registrar › Gasto › nombre › PIN.
Future<void> registrarGastoDesdeCasa(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('registrar-tablet-casa')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('casa-personal-gasto')));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('elegir-nombre')), findsOneWidget);
  // Solo quienes pueden registrar un gasto (el familiar no).
  expect(find.byKey(ValueKey('nombre-${id(Rol.familiar)}')), findsNothing);
  await tester.tap(find.byKey(ValueKey('nombre-${id(Rol.dueno)}')));
  await tester.pumpAndSettle();
  expect(find.text('Dueño · solo para esta acción'), findsOneWidget);
  await escribirPin(tester, '1234');
}

void main() {
  group('tablet personal', () {
    testWidgets('en reposo: bloqueo con los permitidos, sin modo Casa', (
      tester,
    ) async {
      await montarPersonal(tester);
      expect(find.byKey(llaveBloqueo), findsOneWidget);
      expect(find.text('GRAVITY · Casa'), findsNothing);
      expect(find.byType(PantallaModoCasa), findsNothing);
      expect(find.text(nombreDueno), findsOneWidget);
      // Registradas pero no permitidas: no se ofrecen.
      expect(find.text(nombrePareja), findsNothing);
      expect(find.text(nombreFamiliar), findsNothing);
      revisarSinDinero(tester);
      revisarSinCuidados(tester);

      // Ni por enlace se ve algo detrás del bloqueo.
      contenedorDe(tester).read(routerProvider).go(Rutas.alimentacion);
      await tester.pumpAndSettle();
      expect(find.byKey(llaveBloqueo), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('con su PIN entra a sus pantallas; tras 2 min, al bloqueo', (
      tester,
    ) async {
      await montarPersonal(tester);
      await tester.tap(find.text(nombreDueno));
      await tester.pumpAndSettle();
      await escribirPin(tester, '9999');
      expect(find.text('PIN incorrecto.'), findsOneWidget);
      await escribirPin(tester, '1234');

      expect(find.byKey(llaveBloqueo), findsNothing);
      expect(enRiel('Finanzas'), findsOneWidget);
      expect(find.byTooltip('Bloquear la tablet'), findsOneWidget);
      await tester.tap(enRiel('Finanzas'));
      await tester.pumpAndSettle();
      expect(ubicacion(tester), Rutas.finanzas);

      await tester.pump(const Duration(minutes: 2, seconds: 1));
      await tester.pumpAndSettle();
      expect(find.byKey(llaveBloqueo), findsOneWidget);
      expect(estadoTablet(tester).usuarioActivo, isNull);
      expect(find.text('GRAVITY · Casa'), findsNothing);
      revisarSinDinero(tester);
    });

    testWidgets('bloquear a mano', (tester) async {
      await montarPersonal(tester);
      await tester.tap(find.text(nombreDueno));
      await tester.pumpAndSettle();
      await escribirPin(tester, '1234');
      await tester.tap(find.byTooltip('Bloquear la tablet'));
      await tester.pumpAndSettle();
      expect(find.byKey(llaveBloqueo), findsOneWidget);
    });
  });

  group('Ajustes › Dispositivos', () {
    testWidgets('el dueño la vuelve personal y elige quién entra', (
      tester,
    ) async {
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.tablet,
        sesion: sesionCon(Rol.casa),
        almacen: await almacenConPersonas({
          Rol.dueno: '1234',
          Rol.coadministrador: '2222',
          Rol.familiar: '3333',
        }),
      );
      expect(find.text('GRAVITY · Casa'), findsOneWidget);
      await tester.tap(find.text(nombreDueno));
      await tester.pumpAndSettle();
      await escribirPin(tester, '1234');

      contenedorDe(tester).read(routerProvider).go('/ajustes/dispositivos');
      await tester.pumpAndSettle();
      expect(ubicacion(tester), '/ajustes/dispositivos');
      await tester.tap(find.text('Personal'));
      await tester.pumpAndSettle();
      expect(estadoTablet(tester).configuracion.esPersonal, isTrue);

      // Quien la cambió queda permitido; el familiar no puede serlo.
      final dueno = tester.widget<SwitchListTile>(
        find.byKey(ValueKey('permitida-${id(Rol.dueno)}')),
      );
      expect(dueno.value, isTrue);
      final familiar = tester.widget<SwitchListTile>(
        find.byKey(ValueKey('permitida-${id(Rol.familiar)}')),
      );
      expect(familiar.onChanged, isNull);
      await tester.tap(find.byKey(ValueKey('permitida-${id(Rol.coadministrador)}')));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Bloquear la tablet'));
      await tester.pumpAndSettle();
      expect(find.byKey(llaveBloqueo), findsOneWidget);
      expect(find.text(nombreDueno), findsOneWidget);
      expect(find.text(nombrePareja), findsOneWidget);
      expect(find.text(nombreFamiliar), findsNothing);
    });

    testWidgets('solo el dueño ve Dispositivos', (tester) async {
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.tablet,
        sesion: sesionCon(Rol.casa),
        almacen: await almacenConPersonas({Rol.coadministrador: '2222'}),
      );
      await tester.tap(find.text(nombrePareja));
      await tester.pumpAndSettle();
      await escribirPin(tester, '2222');
      contenedorDe(tester).read(routerProvider).go('/ajustes/dispositivos');
      await tester.pumpAndSettle();
      expect(ubicacion(tester), Rutas.ajustes);
    });
  });

  group('tablet pública', () {
    testWidgets('algo personal: nombre y PIN solo para esa acción', (
      tester,
    ) async {
      await montarPublica(tester);
      await registrarGastoDesdeCasa(tester);

      // El registro abierto, con la sesión de la persona; detrás, el modo Casa.
      expect(find.byKey(llaveRegistro(TipoRegistro.gasto)), findsOneWidget);
      expect(find.byType(PantallaModoCasa), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      expect(ubicacion(tester), Rutas.inicio);
      expect(contenedorDe(tester).read(rolEfectivoProvider), Rol.dueno);
      expect(estadoTablet(tester).soloAccion, isTrue);
      await contenedorDe(
        tester,
      ).read(controladorTabletProvider.notifier).cambiosEnServidor;
      expect(personaEnServidor(tester), id(Rol.dueno));

      // Al terminar la acción, de vuelta a la cuenta Casa.
      Navigator.of(
        tester.element(find.byKey(llaveRegistro(TipoRegistro.gasto))),
      ).pop();
      await tester.pumpAndSettle();
      expect(estadoTablet(tester).usuarioActivo, isNull);
      expect(contenedorDe(tester).read(rolEfectivoProvider), Rol.casa);
      await contenedorDe(
        tester,
      ).read(controladorTabletProvider.notifier).cambiosEnServidor;
      expect(personaEnServidor(tester), id(Rol.casa));
      expect(find.text('GRAVITY · Casa'), findsOneWidget);
      revisarSinDinero(tester);
    });

    testWidgets('algo personal: tras 2 min sin uso se cierra y vuelve a Casa', (
      tester,
    ) async {
      await montarPublica(tester);
      await registrarGastoDesdeCasa(tester);
      expect(find.byKey(llaveRegistro(TipoRegistro.gasto)), findsOneWidget);

      await tester.pump(const Duration(minutes: 2, seconds: 1));
      await tester.pumpAndSettle();
      expect(find.byKey(llaveRegistro(TipoRegistro.gasto)), findsNothing);
      expect(estadoTablet(tester).usuarioActivo, isNull);
      expect(find.text('GRAVITY · Casa'), findsOneWidget);
      revisarSinDinero(tester);
    });

    testWidgets('algo personal: con PIN incorrecto no se abre nada', (
      tester,
    ) async {
      await montarPublica(tester);
      await tester.tap(find.byKey(const ValueKey('registrar-tablet-casa')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('casa-personal-gasto')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('nombre-${id(Rol.dueno)}')));
      await tester.pumpAndSettle();
      await escribirPin(tester, '9999');
      expect(find.text('PIN incorrecto.'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.byKey(llaveRegistro(TipoRegistro.gasto)), findsNothing);
      expect(estadoTablet(tester).usuarioActivo, isNull);
    });

    testWidgets('algo de la casa: el nombre sin PIN, con origen de la tablet', (
      tester,
    ) async {
      final base = BaseLocal.enMemoria();
      addTearDown(base.close);
      await montarPublica(tester, base: base);
      final contexto = tester.element(find.byType(PantallaModoCasa));
      final registro = registrarAlgoDeLaCasa(
        contexto,
        tipo: 'casa.lista_compras',
        carga: const {'texto': 'Tortillas'},
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('elegir-nombre')), findsOneWidget);
      // Cualquiera de la tablet puede decir quién es.
      expect(find.byKey(ValueKey('nombre-${id(Rol.familiar)}')), findsOneWidget);
      await tester.tap(find.byKey(ValueKey('nombre-${id(Rol.familiar)}')));
      await tester.pumpAndSettle();
      // Sin PIN y sin salir del modo Casa.
      expect(find.byKey(const Key('campo-pin')), findsNothing);
      expect(estadoTablet(tester).usuarioActivo, isNull);

      final id0 = await tester.runAsync(() => registro);
      expect(id0, isNotNull);
      final guardado = (await tester.runAsync(
        () => contenedorDe(tester).read(colaSinConexionProvider).registros(),
      ))!.single;
      expect(guardado.id, id0);
      expect(guardado.personaId, id(Rol.familiar));
      expect(guardado.origen, OrigenRegistro.tabletCasa);
    });

    testWidgets('leer no pide identidad y el modo Casa sigue sin dinero', (
      tester,
    ) async {
      await montarPublica(tester);
      expect(find.text('GRAVITY · Casa'), findsOneWidget);
      expect(find.byKey(llaveBloqueo), findsNothing);
      await tester.tap(find.byKey(const ValueKey('registrar-tablet-casa')));
      await tester.pumpAndSettle();
      expect(find.text('Lista de compras'), findsOneWidget);
      revisarSinDinero(tester);
    });
  });
}
