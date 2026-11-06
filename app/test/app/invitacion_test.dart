// "Tengo una invitación" (E3 de la Fase 4, D22): registro y aceptación del
// código del dueño con el servicio de sesión simulado.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/app_gravity.dart';
import 'package:gravity/app/navegacion.dart';
import 'package:gravity/app/router.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_falso.dart';
import 'package:gravity/nucleo/sesion/sesion.dart';

import 'ayuda_plataforma.dart';

Future<void> irAInvitacion(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('tengo-invitacion')));
  await tester.pumpAndSettle();
}

Future<void> llenar(
  WidgetTester tester, {
  String codigo = 'codigo-1',
  String? nombre = 'Luisa',
  String correo = 'luisa@ejemplo.test',
  String contrasena = 'contrasena-larga',
}) async {
  await tester.enterText(
    find.byKey(const ValueKey('invitacion-codigo')),
    codigo,
  );
  if (nombre != null) {
    await tester.enterText(
      find.byKey(const ValueKey('invitacion-nombre')),
      nombre,
    );
  }
  await tester.enterText(
    find.byKey(const ValueKey('invitacion-correo')),
    correo,
  );
  await tester.enterText(
    find.byKey(const ValueKey('invitacion-contrasena')),
    contrasena,
  );
}

Future<void> enviar(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const ValueKey('invitacion-aceptar')));
  await tester.tap(find.byKey(const ValueKey('invitacion-aceptar')));
  await tester.pumpAndSettle();
}

void main() {
  group('redirección', () {
    test('sin sesión, la invitación se abre; con sesión, va al inicio', () {
      expect(
        calcularRedireccion(
          ubicacion: RutasApp.invitacion,
          rol: null,
          dispositivo: TipoDispositivo.telefono,
        ),
        isNull,
      );
      expect(
        calcularRedireccion(
          ubicacion: RutasApp.invitacion,
          rol: Rol.familiar,
          dispositivo: TipoDispositivo.telefono,
        ),
        '/',
      );
      expect(
        calcularRedireccion(
          ubicacion: '/finanzas',
          rol: null,
          dispositivo: TipoDispositivo.telefono,
        ),
        '/entrar',
      );
    });
  });

  group('pantalla', () {
    testWidgets('desde "Entrar" se llega a la invitación (teléfono)', (
      tester,
    ) async {
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.telefono,
        sesion: ServicioSesionFalso(),
      );
      expect(find.byKey(const ValueKey('tengo-invitacion')), findsOneWidget);
      await irAInvitacion(tester);
      expect(find.text('Crear cuenta y unirme'), findsOneWidget);
    });

    testWidgets('la tablet de la casa no ofrece invitaciones', (tester) async {
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.tablet,
        sesion: ServicioSesionFalso(),
      );
      expect(find.byKey(const ValueKey('tengo-invitacion')), findsNothing);
    });

    testWidgets('crea la cuenta, acepta y entra con el rol invitado', (
      tester,
    ) async {
      final servicio = ServicioSesionFalso()
        ..invitaciones['codigo-1'] = InvitacionFalsa(
          correo: 'luisa@ejemplo.test',
          rol: Rol.familiar,
        );
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.telefono,
        sesion: servicio,
      );
      await irAInvitacion(tester);
      await llenar(tester);
      await enviar(tester);
      expect(servicio.sesionActual?.rol, Rol.familiar);
      expect(servicio.sesionActual?.persona.nombre, 'Luisa');
      // Ya dentro: la pantalla de invitación desaparece.
      expect(find.byKey(const ValueKey('invitacion-aceptar')), findsNothing);
    });

    testWidgets('valida el código, el correo y la contraseña corta', (
      tester,
    ) async {
      final servicio = ServicioSesionFalso();
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.telefono,
        sesion: servicio,
      );
      await irAInvitacion(tester);
      await llenar(
        tester,
        codigo: ' ',
        nombre: '',
        correo: 'no-es-correo',
        contrasena: 'corta',
      );
      await enviar(tester);
      expect(find.text('Escribe el código que te dieron.'), findsOneWidget);
      expect(find.text('Escribe tu nombre.'), findsOneWidget);
      expect(find.text('Escribe tu correo.'), findsOneWidget);
      expect(find.text('Usa al menos 8 caracteres.'), findsOneWidget);
      expect(servicio.vecesAceptar, 0);
    });

    testWidgets('un código inválido o vencido se explica y no deja entrar', (
      tester,
    ) async {
      final servicio = ServicioSesionFalso()
        ..invitaciones['vencido'] = InvitacionFalsa(
          correo: 'luisa@ejemplo.test',
          rol: Rol.familiar,
          vencida: true,
        );
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.telefono,
        sesion: servicio,
      );
      await irAInvitacion(tester);
      await llenar(tester, codigo: 'vencido');
      await enviar(tester);
      expect(
        find.textContaining('El código no es válido o ya venció'),
        findsOneWidget,
      );
      expect(servicio.sesionActual, isNull);
    });

    testWidgets('un correo distinto al invitado se rechaza', (tester) async {
      final servicio = ServicioSesionFalso()
        ..invitaciones['codigo-1'] = InvitacionFalsa(
          correo: 'otra@ejemplo.test',
          rol: Rol.cuidador,
        );
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.telefono,
        sesion: servicio,
      );
      await irAInvitacion(tester);
      await llenar(tester);
      await enviar(tester);
      expect(
        find.textContaining('La invitación es para otro correo'),
        findsOneWidget,
      );
      expect(servicio.sesionActual, isNull);
    });

    testWidgets('sin señal lo dice', (tester) async {
      final servicio = ServicioSesionFalso(sinConexion: true);
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.telefono,
        sesion: servicio,
      );
      await irAInvitacion(tester);
      await llenar(tester);
      await enviar(tester);
      expect(find.textContaining('Sin conexión'), findsOneWidget);
    });

    testWidgets(
      'si el servidor pide confirmar el correo: avisa, y con "Ya tengo cuenta" '
      'acepta el mismo código',
      (tester) async {
        final servicio = ServicioSesionFalso()
          ..exigeConfirmarCorreo = true
          ..invitaciones['codigo-1'] = InvitacionFalsa(
            correo: 'luisa@ejemplo.test',
            rol: Rol.coadministrador,
          );
        await montarApp(
          tester,
          dispositivo: TipoDispositivo.telefono,
          sesion: servicio,
        );
        await irAInvitacion(tester);
        await llenar(tester);
        await enviar(tester);
        expect(find.byKey(const ValueKey('invitacion-aviso')), findsOneWidget);
        expect(servicio.sesionActual, isNull);

        // Entra antes de confirmar: se le explica.
        await tester.enterText(
          find.byKey(const ValueKey('invitacion-contrasena')),
          'contrasena-larga',
        );
        await enviar(tester);
        expect(find.textContaining('Aún no confirmas tu correo'), findsOneWidget);

        servicio.confirmarCorreo('luisa@ejemplo.test');
        await enviar(tester);
        expect(servicio.sesionActual?.rol, Rol.coadministrador);
      },
    );

    testWidgets('"Ya tengo cuenta" con la contraseña mala no entra', (
      tester,
    ) async {
      final servicio = ServicioSesionFalso(
        cuentas: {
          'luisa@ejemplo.test': CuentaFalsa(
            'la-buena-123',
            const Sesion(
              persona: Persona(id: 'luisa', nombre: 'Luisa'),
              rol: Rol.familiar,
            ),
          ),
        },
      )..invitaciones['codigo-1'] = InvitacionFalsa(
          correo: 'luisa@ejemplo.test',
          rol: Rol.familiar,
        );
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.telefono,
        sesion: servicio,
      );
      await irAInvitacion(tester);
      await tester.tap(find.text('Ya tengo cuenta'));
      await tester.pumpAndSettle();
      await llenar(tester, nombre: null, contrasena: 'incorrecta-123');
      await enviar(tester);
      expect(find.text('Correo o contraseña incorrectos.'), findsOneWidget);
      expect(servicio.sesionActual, isNull);
      await tester.enterText(
        find.byKey(const ValueKey('invitacion-contrasena')),
        'la-buena-123',
      );
      await enviar(tester);
      expect(servicio.sesionActual?.rol, Rol.familiar);
    });

    testWidgets('con sesión abierta, /invitacion lleva al inicio', (
      tester,
    ) async {
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.telefono,
        sesion: sesionCon(Rol.dueno),
      );
      ProviderScope.containerOf(tester.element(find.byType(AppGravity)))
          .read(routerProvider)
          .go(RutasApp.invitacion);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('invitacion-aceptar')), findsNothing);
    });
  });
}
