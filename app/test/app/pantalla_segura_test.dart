// I11 (revisión de la Fase 1): qué pantallas se protegen contra capturas
// (FLAG_SECURE en Android) y que la app las pida y las suelte al navegar.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/app_gravity.dart';
import 'package:gravity/app/navegacion.dart';
import 'package:gravity/app/pantalla_segura.dart';
import 'package:gravity/app/pantallas/registro_rapido.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/contratos/rutas.dart';
import 'package:gravity/nucleo/permisos/permisos.dart' show puedeAbrir;
import 'package:gravity/nucleo/seguridad/pantalla_segura.dart';

import '../nucleo/seguridad/pantalla_segura_test.dart'
    show ProtectorRegistrador;
import 'ayuda_plataforma.dart';
import 'finanzas_por_rol_test.dart' show conRutasDeEjemplo, ir;

void main() {
  group('esPantallaSensible', () {
    test('Finanzas, solo para quien la ve', () {
      for (final ruta in [
        Rutas.finanzas,
        '${Rutas.finanzas}/semana',
        '${Rutas.finanzas}/ajustes/cuentas',
      ]) {
        expect(esPantallaSensible(ruta, Rol.dueno), isTrue, reason: ruta);
        expect(esPantallaSensible(ruta, Rol.coadministrador), isTrue);
        // Quien no la abre la ve redirigida: nada que proteger.
        for (final rol in [Rol.familiar, Rol.cuidador, Rol.casa]) {
          expect(esPantallaSensible(ruta, rol), isFalse, reason: '$ruta $rol');
        }
      }
    });

    test(
      'Cuidados: datos clínicos sí; recordatorios genéricos de Casa, no',
      () {
        for (final ruta in [
          Rutas.cuidados,
          RutasApp.cuidadosMedicamentos,
          RutasApp.cuidadosComidas,
          RutasApp.cuidadosBitacora,
        ]) {
          expect(esPantallaSensible(ruta, Rol.dueno), isTrue, reason: ruta);
          expect(esPantallaSensible(ruta, Rol.cuidador), isTrue, reason: ruta);
          expect(esPantallaSensible(ruta, Rol.casa), isFalse, reason: ruta);
          expect(esPantallaSensible(ruta, Rol.familiar), isFalse, reason: ruta);
        }
      },
    );

    test('"Hoy" y lo pendiente, para quien ve dinero o datos clínicos', () {
      expect(esPantallaSensible(Rutas.inicio, Rol.dueno), isTrue);
      expect(esPantallaSensible(Rutas.inicio, Rol.coadministrador), isTrue);
      expect(esPantallaSensible(Rutas.inicio, Rol.familiar), isFalse);
      expect(esPantallaSensible(Rutas.inicio, Rol.casa), isFalse);
      expect(esPantallaSensible(RutasApp.solicitudes, Rol.cuidador), isTrue);
      expect(esPantallaSensible(RutasApp.solicitudes, Rol.casa), isFalse);
      expect(esPantallaSensible(RutasApp.pendientes, Rol.dueno), isTrue);
      expect(esPantallaSensible(RutasApp.pendientes, Rol.familiar), isFalse);
    });

    test(
      'F4-A1: Alimentación (perfil clínico de Papá) solo para quien la abre',
      () {
        for (final ruta in [
          Rutas.alimentacion,
          '${Rutas.alimentacion}/compras',
        ]) {
          for (final rol in Rol.values) {
            expect(
              esPantallaSensible(ruta, rol),
              puedeAbrir(rol, Modulo.alimentacion),
              reason: '$ruta $rol',
            );
          }
        }
        expect(esPantallaSensible(Rutas.alimentacion, Rol.dueno), isTrue);
      },
    );

    test('lo demás se puede capturar', () {
      for (final ruta in [
        Rutas.habitos,
        Rutas.casa,
        Rutas.ajustes,
        RutasApp.mas,
        Rutas.entrar,
      ]) {
        for (final rol in Rol.values) {
          expect(esPantallaSensible(ruta, rol), isFalse, reason: '$ruta $rol');
        }
      }
    });

    test('sin rol (nadie ha entrado) no hay nada que proteger', () {
      expect(esPantallaSensible(Rutas.finanzas, null), isFalse);
      expect(esPantallaSensible(Rutas.inicio, null), isFalse);
    });
  });

  group('la app pide y suelta la protección', () {
    late ProtectorRegistrador protector;

    Future<ControladorPantallaSegura> montar(
      WidgetTester tester,
      TipoDispositivo dispositivo,
      Rol rol,
    ) async {
      protector = ProtectorRegistrador();
      await montarApp(
        tester,
        dispositivo: dispositivo,
        sesion: sesionCon(rol),
        extras: [
          ...conRutasDeEjemplo,
          protectorDePantallaProvider.overrideWithValue(protector),
        ],
      );
      return ProviderScope.containerOf(tester.element(find.byType(AppGravity)))
          .read(controladorPantallaSeguraProvider);
    }

    testWidgets(
      'dueño en el teléfono: Hoy y Finanzas sí; Hábitos y Ajustes no',
      (tester) async {
        final controlador = await montar(
          tester,
          TipoDispositivo.telefono,
          Rol.dueno,
        );
        await controlador.aplicado;
        expect(protector.segura, isTrue, reason: 'Hoy resume Finanzas');

        await ir(tester, Rutas.habitos);
        await controlador.aplicado;
        expect(protector.segura, isFalse, reason: 'Hábitos se puede capturar');

        await ir(tester, '${Rutas.finanzas}/semana');
        await controlador.aplicado;
        expect(protector.segura, isTrue, reason: 'Finanzas no');

        await ir(tester, Rutas.ajustes);
        await controlador.aplicado;
        expect(protector.segura, isFalse);
        // Se encendió y apagó cuando hizo falta, sin parpadeos de más.
        expect(protector.cambios, [true, false, true, false]);
      },
    );

    testWidgets('familiar: nunca se protege (no ve dinero ni datos clínicos)', (
      tester,
    ) async {
      final controlador = await montar(
        tester,
        TipoDispositivo.telefono,
        Rol.familiar,
      );
      for (final ruta in [Rutas.inicio, Rutas.habitos, RutasApp.mas]) {
        await ir(tester, ruta);
        await controlador.aplicado;
      }
      expect(protector.cambios, isEmpty);
    });

    testWidgets('cuidadora: su turno (Cuidados) sí se protege', (tester) async {
      final controlador = await montar(
        tester,
        TipoDispositivo.telefono,
        Rol.cuidador,
      );
      await controlador.aplicado;
      expect(protector.segura, isTrue);
    });

    testWidgets(
      'tablet en modo Casa: sin dinero ni datos clínicos, sin protección',
      (tester) async {
        final controlador = await montar(
          tester,
          TipoDispositivo.tablet,
          Rol.casa,
        );
        await ir(tester, Rutas.cuidados);
        await controlador.aplicado;
        expect(protector.cambios, isEmpty);
      },
    );

    testWidgets(
      'la hoja de registro (+) se protege aunque esté sobre Hábitos',
      (tester) async {
        final controlador = await montar(
          tester,
          TipoDispositivo.telefono,
          Rol.dueno,
        );
        await ir(tester, Rutas.habitos);
        await controlador.aplicado;
        expect(protector.segura, isFalse);

        final contexto = tester.element(find.byType(Scaffold).first);
        final abierta = abrirRegistro(contexto, opcionesDeRegistro.first);
        await tester.pumpAndSettle();
        await controlador.aplicado;
        expect(find.byKey(llaveRegistro(TipoRegistro.gasto)), findsOneWidget);
        expect(
          protector.segura,
          isTrue,
          reason: 'la hoja de gasto no se captura',
        );

        Navigator.of(
          tester.element(find.byKey(llaveRegistro(TipoRegistro.gasto))),
        ).pop();
        await abierta;
        await tester.pumpAndSettle();
        await controlador.aplicado;
        expect(
          protector.segura,
          isFalse,
          reason: 'al cerrar, vuelve a poder capturarse',
        );
      },
    );

    testWidgets('Ctrl + N en la laptop: el diálogo del gasto se protege', (
      tester,
    ) async {
      // Windows no usa FLAG_SECURE, pero la regla es la misma (protector nulo).
      final controlador = await montar(
        tester,
        TipoDispositivo.laptop,
        Rol.dueno,
      );
      await ir(tester, Rutas.habitos);
      await controlador.aplicado;
      expect(protector.segura, isFalse);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      await controlador.aplicado;
      expect(find.byKey(llaveRegistro(TipoRegistro.gasto)), findsOneWidget);
      expect(protector.segura, isTrue);
    });
  });
}
