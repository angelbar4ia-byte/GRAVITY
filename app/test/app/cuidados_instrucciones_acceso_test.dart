// Fase 5 (8c, 8d, 8f): cómo se llega a Instrucciones y Consentimientos de
// Cuidados. Excepción estrecha del guardia (solo estas dos rutas exactas) y
// accesos en Más y en la franja de la laptop, con la misma visibilidad.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/app_gravity.dart';
import 'package:gravity/app/navegacion.dart';
import 'package:gravity/app/router.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/contratos/rutas.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_falso.dart';

import 'ayuda_plataforma.dart';
import 'cuenta_maestra_test.dart' show maestra;

const _instrucciones = RutasApp.cuidadosInstrucciones;
const _consentimientos = RutasApp.cuidadosConsentimientos;
const _accesoInstrucciones = ValueKey('acceso-cuidados-instrucciones');
const _accesoConsentimientos = ValueKey('acceso-cuidados-consentimientos');

void main() {
  group('guardia de rutas (función pura)', () {
    String? ir(
      String ruta,
      Rol rol, {
      bool maestra = false,
      TipoDispositivo d = TipoDispositivo.telefono,
    }) => calcularRedireccion(
      ubicacion: ruta,
      rol: rol,
      dispositivo: d,
      esMaestra: maestra,
    );

    test('las rutas son las exactas', () {
      expect(_instrucciones, '/cuidados/instrucciones');
      expect(_consentimientos, '/cuidados/consentimientos');
    });

    test('la pareja sin consentimiento pasa solo a esas dos rutas', () {
      expect(ir(_instrucciones, Rol.coadministrador), isNull);
      expect(ir(_consentimientos, Rol.coadministrador), isNull);
      // Todo lo demás de Cuidados sigue bloqueado.
      for (final ruta in [
        Rutas.cuidados,
        '${Rutas.cuidados}/bitacora',
        '${Rutas.cuidados}/medicamentos',
        '${Rutas.cuidados}/comidas',
        '${Rutas.cuidados}/resumen',
        '${Rutas.cuidados}/gestion',
        '${Rutas.cuidados}/instrucciones/otra',
        '${Rutas.cuidados}/instrucciones-viejas',
        '${Rutas.cuidados}/consentimientos/otra',
      ]) {
        expect(ir(ruta, Rol.coadministrador), Rutas.inicio, reason: ruta);
      }
    });

    test('el dueño abre las dos; el familiar ninguna', () {
      expect(ir(_instrucciones, Rol.dueno), isNull);
      expect(ir(_consentimientos, Rol.dueno), isNull);
      expect(ir(_instrucciones, Rol.familiar), Rutas.inicio);
      expect(ir(_consentimientos, Rol.familiar), Rutas.inicio);
    });

    test('la hermana y la cuidadora (cuidador) llegan a Instrucciones', () {
      expect(ir(_instrucciones, Rol.cuidador), isNull);
      // Los consentimientos no son de ellas: vuelven a su turno.
      expect(ir(_consentimientos, Rol.cuidador), Rutas.cuidados);
    });

    test('Casa no llega a ninguna', () {
      expect(ir(_instrucciones, Rol.casa), Rutas.inicio);
      expect(ir(_consentimientos, Rol.casa), Rutas.inicio);
    });

    test('la cuenta maestra no llega a ninguna', () {
      expect(
        ir(_instrucciones, Rol.coadministrador, maestra: true),
        Rutas.inicio,
      );
      expect(
        ir(_consentimientos, Rol.coadministrador, maestra: true),
        Rutas.inicio,
      );
      expect(ir(_instrucciones, Rol.cuidador, maestra: true), Rutas.cuidados);
      expect(ir(_instrucciones, Rol.dueno, maestra: true), Rutas.inicio);
      // La dueña que es maestra sí ve el estado de consentimientos.
      expect(ir(_consentimientos, Rol.dueno, maestra: true), isNull);
    });

    test('sin sesión lleva a Entrar', () {
      expect(
        calcularRedireccion(
          ubicacion: _instrucciones,
          rol: null,
          dispositivo: TipoDispositivo.telefono,
        ),
        Rutas.entrar,
      );
    });
  });

  group('visibilidad de los accesos (función pura)', () {
    test('solo el dueño y la pareja los ven', () {
      for (final rol in Rol.values) {
        final esperado = rol == Rol.dueno || rol == Rol.coadministrador;
        expect(veAccesoInstrucciones(rol), esperado, reason: rol.name);
        expect(veAccesoConsentimientos(rol), esperado, reason: rol.name);
        expect(
          veAccesoInstrucciones(rol, esMaestra: true),
          false,
          reason: '${rol.name} maestra',
        );
      }
    });
  });

  group('en la app', () {
    String ubicacion(WidgetTester t) =>
        ProviderScope.containerOf(t.element(find.byType(AppGravity)))
            .read(routerProvider)
            .routerDelegate
            .currentConfiguration
            .uri
            .path;

    Future<void> abrir(WidgetTester t, String ruta) async {
      ProviderScope.containerOf(t.element(find.byType(AppGravity)))
          .read(routerProvider)
          .go(ruta);
      await t.pumpAndSettle();
    }

    for (final rol in [Rol.dueno, Rol.coadministrador]) {
      testWidgets('${rol.name} ve los accesos en Más y no en Hoy', (t) async {
        await montarApp(
          t,
          dispositivo: TipoDispositivo.telefono,
          sesion: sesionCon(rol),
        );
        expect(find.byKey(_accesoInstrucciones), findsNothing);
        await t.tap(find.text('Más'));
        await t.pumpAndSettle();
        expect(find.byKey(_accesoInstrucciones), findsOneWidget);
        expect(find.byKey(_accesoConsentimientos), findsOneWidget);
        await t.tap(find.byKey(_accesoInstrucciones));
        await t.pumpAndSettle();
        expect(ubicacion(t), _instrucciones);
      });

      testWidgets('${rol.name} ve los accesos en la franja de la laptop', (
        t,
      ) async {
        await montarApp(
          t,
          dispositivo: TipoDispositivo.laptop,
          sesion: sesionCon(rol),
        );
        expect(find.byKey(_accesoInstrucciones), findsOneWidget);
        await t.tap(find.byKey(_accesoConsentimientos));
        await t.pumpAndSettle();
        expect(ubicacion(t), _consentimientos);
      });
    }

    testWidgets(
      'la pareja abre Instrucciones y Consentimientos, no la bitácora',
      (t) async {
        await montarApp(
          t,
          dispositivo: TipoDispositivo.telefono,
          sesion: sesionCon(Rol.coadministrador),
        );
        await abrir(t, _instrucciones);
        expect(ubicacion(t), _instrucciones);
        await abrir(t, _consentimientos);
        expect(ubicacion(t), _consentimientos);
        await abrir(t, '${Rutas.cuidados}/bitacora');
        expect(ubicacion(t), isNot('${Rutas.cuidados}/bitacora'));
      },
    );

    testWidgets('la cuidadora llega a Instrucciones y no ve los accesos', (
      t,
    ) async {
      await montarApp(
        t,
        dispositivo: TipoDispositivo.telefono,
        sesion: sesionCon(Rol.cuidador),
      );
      expect(find.byKey(_accesoInstrucciones), findsNothing);
      expect(find.byKey(_accesoConsentimientos), findsNothing);
      await abrir(t, _instrucciones);
      expect(ubicacion(t), _instrucciones);
      // Solo lectura: no hay formulario para dejar instrucciones.
      expect(find.byType(TextField), findsNothing);
    });

    for (final rol in [Rol.casa, Rol.familiar]) {
      testWidgets('${rol.name} no llega ni ve los accesos', (t) async {
        await montarApp(
          t,
          dispositivo: TipoDispositivo.telefono,
          sesion: sesionCon(rol),
        );
        await t.tap(find.text('Más'));
        await t.pumpAndSettle();
        expect(find.byKey(_accesoInstrucciones), findsNothing);
        expect(find.byKey(_accesoConsentimientos), findsNothing);
        await abrir(t, _instrucciones);
        expect(ubicacion(t), isNot(_instrucciones));
        await abrir(t, _consentimientos);
        expect(ubicacion(t), isNot(_consentimientos));
      });
    }

    testWidgets('la cuenta maestra no llega ni ve los accesos', (t) async {
      await montarApp(
        t,
        dispositivo: TipoDispositivo.telefono,
        sesion: ServicioSesionFalso(inicial: maestra()),
      );
      await t.tap(find.text('Más'));
      await t.pumpAndSettle();
      expect(find.byKey(_accesoInstrucciones), findsNothing);
      expect(find.byKey(_accesoConsentimientos), findsNothing);
      await abrir(t, _instrucciones);
      expect(ubicacion(t), isNot(_instrucciones));
    });
  });
}
