// D19 (21/oct/2026): la cuenta maestra solo lee todo y nunca ve botones de
// escribir en lo ajeno. En la plataforma: el estado de sesión la lleva
// (`membresias.es_maestra`) y Ajustes no le ofrece lo que administra el hogar.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/app_gravity.dart';
import 'package:gravity/app/navegacion.dart';
import 'package:gravity/app/pantallas/registro_rapido.dart';
import 'package:gravity/app/router.dart';
import 'package:gravity/app/sesion_efectiva.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/contratos/rutas.dart';
import 'package:gravity/nucleo/permisos/permisos.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_demostracion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_falso.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_supabase.dart';
import 'package:gravity/nucleo/sesion/sesion.dart';
import 'package:gravity/nucleo/tablet/usuarios_tablet.dart';

import 'ayuda_plataforma.dart';

/// Cuenta maestra de ejemplo (D19, 23/oct/2026): **otra persona** con su
/// propio login (rol coadministrador con la marca), de solo lectura total.
Sesion maestra() => Sesion(
  persona: const Persona(
    id: '00000000-0000-4000-8000-0000000000f1',
    nombre: 'Cuenta maestra de ejemplo',
  ),
  rol: Rol.coadministrador,
  hogarId: hogarDeEjemplo,
  esMaestra: true,
);

/// La dueña que además se nombra maestra con su propia persona: escribe en lo
/// suyo y en lo ajeno solo lee.
Sesion duenaYMaestra() => Sesion(
  persona: personasDeEjemplo[Rol.dueno]!,
  rol: Rol.dueno,
  hogarId: hogarDeEjemplo,
  esMaestra: true,
);

ProviderContainer contenedorDe(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(AppGravity)));

String ubicacion(WidgetTester tester) =>
    contenedorDe(tester)
        .read(routerProvider)
        .routerDelegate
        .currentConfiguration
        .uri
        .path;

Future<void> ir(WidgetTester tester, String ruta) async {
  contenedorDe(tester).read(routerProvider).go(ruta);
  await tester.pumpAndSettle();
}

void main() {
  group('estado de sesión', () {
    test('es_maestra viaja en la sesión guardada y por omisión es false', () {
      final sesion = maestra();
      final copia = Sesion.desdeJson(
        (jsonDecode(jsonEncode(sesion.aJson())) as Map).cast<String, Object?>(),
      );
      expect(copia, sesion);
      expect(copia.esMaestra, isTrue);
      expect(sesionDeEjemplo(Rol.dueno).esMaestra, isFalse);
      expect(sesionDeEjemplo(Rol.dueno).aJson(), isNot(contains('es_maestra')));
    });

    test('se lee de la membresía del servidor', () {
      final fila = {
        'persona_id': 'p1',
        'nombre': 'Ana',
        'rol': 'dueno',
        'hogar_id': 'h1',
      };
      expect(sesionDesdeFila({...fila, 'es_maestra': true}).esMaestra, isTrue);
      expect(
        sesionDesdeFila({...fila, 'es_maestra': false}).esMaestra,
        isFalse,
      );
      // Servidor sin la columna todavía: nadie es maestra.
      expect(sesionDesdeFila(fila).esMaestra, isFalse);
    });

    test('en la tablet la persona guarda si es la cuenta maestra', () {
      final usuario = UsuarioTablet.desdeSesion(maestra(), hashPin: 'hash');
      final copia = UsuarioTablet.desdeJson(
        (jsonDecode(jsonEncode(usuario.aJson())) as Map)
            .cast<String, Object?>(),
      );
      expect(copia.esMaestra, isTrue);
      expect(copia.sesion.esMaestra, isTrue);
    });
  });

  testWidgets(
    'laptop: Ajustes de solo lectura, sin lo que administra el hogar',
    (tester) async {
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.laptop,
        sesion: ServicioSesionFalso(inicial: maestra()),
      );
      expect(contenedorDe(tester).read(esCuentaMaestraProvider), isTrue);

      await ir(tester, Rutas.ajustes);
      expect(
        find.text('Coadministrador · cuenta maestra (solo lectura)'),
        findsOneWidget,
      );
      for (final titulo in [
        'Personas y roles',
        'Copias de seguridad',
        'Desarrollador',
      ]) {
        expect(find.text(titulo), findsNothing, reason: titulo);
      }
      expect(find.text('Apariencia'), findsOneWidget);

      for (final ruta in [
        '/ajustes/personas',
        '/ajustes/copias',
        Rutas.desarrollador,
      ]) {
        await ir(tester, ruta);
        expect(ubicacion(tester), Rutas.ajustes, reason: ruta);
      }
    },
  );

  testWidgets('la dueña que también es maestra sigue administrando el hogar', (
    tester,
  ) async {
    await montarApp(
      tester,
      dispositivo: TipoDispositivo.laptop,
      sesion: ServicioSesionFalso(inicial: duenaYMaestra()),
    );
    await ir(tester, Rutas.ajustes);
    expect(
      find.text('Dueño · también cuenta maestra (lo ajeno, solo lectura)'),
      findsOneWidget,
    );
    for (final titulo in ['Personas y roles', 'Copias de seguridad']) {
      expect(find.text(titulo), findsOneWidget, reason: titulo);
    }
    await ir(tester, '/ajustes/personas');
    expect(ubicacion(tester), '/ajustes/personas');
  });

  testWidgets('el mismo rol sin la marca sí administra', (tester) async {
    await montarApp(
      tester,
      dispositivo: TipoDispositivo.laptop,
      sesion: sesionCon(Rol.dueno),
    );
    expect(contenedorDe(tester).read(esCuentaMaestraProvider), isFalse);
    await ir(tester, '/ajustes/personas');
    expect(ubicacion(tester), '/ajustes/personas');
  });

  test('los módulos esconden los botones de escribir en lo ajeno', () {
    // Un libro de Finanzas de otra persona: lo lee, no lo toca.
    expect(
      puedeSobre(
        Rol.dueno,
        Modulo.finanzas,
        Accion.leer,
        esDeLaPersona: false,
        esMaestra: true,
      ),
      isTrue,
    );
    expect(
      puedeSobre(
        Rol.dueno,
        Modulo.finanzas,
        Accion.escribir,
        esDeLaPersona: false,
        esMaestra: true,
      ),
      isFalse,
    );
    // El historial de GRAVITY de otra persona: igual.
    expect(
      puedeSobre(
        Rol.dueno,
        Modulo.gravity,
        Accion.escribir,
        esDeLaPersona: false,
        esMaestra: true,
      ),
      isFalse,
    );
  });

  test('el dueño sin la marca no ve lo ajeno de Finanzas ni de GRAVITY', () {
    expect(
      puedeSobre(Rol.dueno, Modulo.gravity, Accion.leer, esDeLaPersona: false),
      isFalse,
    );
    expect(
      puedeSobre(Rol.dueno, Modulo.finanzas, Accion.leer, esDeLaPersona: false),
      isFalse,
    );
  });

  group(
    'D19 (23/oct): la maestra que no es la dueña es de solo lectura total',
    () {
      test('esSoloLectura y puedeConSesion', () {
        expect(esSoloLectura(Rol.coadministrador, esMaestra: true), isTrue);
        expect(esSoloLectura(Rol.coadministrador, esMaestra: false), isFalse);
        expect(esSoloLectura(Rol.dueno, esMaestra: true), isFalse);
        for (final accion in [Accion.escribir, Accion.administrar]) {
          expect(
            puedeConSesion(
              Rol.coadministrador,
              Modulo.finanzas,
              accion,
              esMaestra: true,
            ),
            isFalse,
            reason: '$accion',
          );
          expect(
            puedeConSesion(Rol.coadministrador, Modulo.finanzas, accion),
            isTrue,
            reason: 'sin la marca, la pareja sí lo hace: $accion',
          );
          expect(
            puedeConSesion(Rol.dueno, Modulo.finanzas, accion, esMaestra: true),
            isTrue,
            reason: 'la dueña conserva lo suyo: $accion',
          );
        }
        expect(
          puedeConSesion(
            Rol.coadministrador,
            Modulo.finanzas,
            Accion.leer,
            esMaestra: true,
          ),
          isTrue,
        );
      });

      test(
        'ni lo suyo: puedeSobre le niega escribir y administrar siempre',
        () {
          for (final modulo in [
            Modulo.finanzas,
            Modulo.gravity,
            Modulo.alimentacion,
          ]) {
            for (final propio in [true, false]) {
              for (final accion in [Accion.escribir, Accion.administrar]) {
                expect(
                  puedeSobre(
                    Rol.coadministrador,
                    modulo,
                    accion,
                    esDeLaPersona: propio,
                    esMaestra: true,
                  ),
                  isFalse,
                  reason: '$modulo propio=$propio $accion',
                );
              }
            }
          }
          // Lee lo suyo y lo ajeno de Finanzas y GRAVITY.
          for (final modulo in [Modulo.finanzas, Modulo.gravity]) {
            for (final propio in [true, false]) {
              expect(
                puedeSobre(
                  Rol.coadministrador,
                  modulo,
                  Accion.leer,
                  esDeLaPersona: propio,
                  esMaestra: true,
                ),
                isTrue,
                reason: '$modulo propio=$propio',
              );
            }
          }
        },
      );

      test('la dueña maestra escribe en lo suyo y en lo ajeno solo lee', () {
        expect(
          puedeSobre(
            Rol.dueno,
            Modulo.finanzas,
            Accion.escribir,
            esDeLaPersona: true,
            esMaestra: true,
          ),
          isTrue,
        );
        expect(
          puedeSobre(
            Rol.dueno,
            Modulo.finanzas,
            Accion.escribir,
            esDeLaPersona: false,
            esMaestra: true,
          ),
          isFalse,
        );
        expect(
          puedeSobre(
            Rol.dueno,
            Modulo.finanzas,
            Accion.leer,
            esDeLaPersona: false,
            esMaestra: true,
          ),
          isTrue,
        );
      });

      test('sin (+): ni pestaña, ni opciones, ni Ctrl + N', () {
        final conMaestra = destinosDe(Rol.coadministrador, esMaestra: true);
        expect(conMaestra.where((d) => d.esRegistrar), isEmpty);
        expect(
          opcionesRegistrar(Rol.coadministrador, esMaestra: true),
          isEmpty,
        );
        expect(
          puedeRegistrarEn(
            Rol.coadministrador,
            Modulo.finanzas,
            esMaestra: true,
          ),
          isFalse,
        );
        // Sin la marca, la pareja sí; y la dueña maestra también.
        expect(
          destinosDe(Rol.coadministrador).any((d) => d.esRegistrar),
          isTrue,
        );
        expect(
          destinosDe(Rol.dueno, esMaestra: true).any((d) => d.esRegistrar),
          isTrue,
        );
      });

      test(
        'las rutas que exigen escribir la regresan al inicio del módulo',
        () {
          for (final accion in [Accion.escribir, Accion.administrar]) {
            expect(
              calcularRedireccion(
                ubicacion: '${Rutas.finanzas}/asistente',
                rol: Rol.coadministrador,
                dispositivo: TipoDispositivo.laptop,
                accion: accion,
                esMaestra: true,
              ),
              Rutas.finanzas,
              reason: '$accion',
            );
            expect(
              calcularRedireccion(
                ubicacion: '${Rutas.finanzas}/asistente',
                rol: Rol.coadministrador,
                dispositivo: TipoDispositivo.laptop,
                accion: accion,
              ),
              isNull,
              reason: 'sin la marca la pareja sí entra: $accion',
            );
          }
        },
      );

      testWidgets('teléfono: la maestra no tiene el botón (+)', (tester) async {
        await montarApp(
          tester,
          dispositivo: TipoDispositivo.telefono,
          sesion: ServicioSesionFalso(inicial: maestra()),
        );
        expect(find.text('Registrar'), findsNothing);
        expect(find.byIcon(Icons.add_circle), findsNothing);
      });

      testWidgets('teléfono: la pareja sin la marca sí lo tiene', (
        tester,
      ) async {
        await montarApp(
          tester,
          dispositivo: TipoDispositivo.telefono,
          sesion: sesionCon(Rol.coadministrador),
        );
        expect(find.text('Registrar'), findsOneWidget);
      });

      testWidgets('laptop: Ctrl + N no abre el registro a la maestra', (
        tester,
      ) async {
        await montarApp(
          tester,
          dispositivo: TipoDispositivo.laptop,
          sesion: ServicioSesionFalso(inicial: maestra()),
        );
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsNothing);
        expect(find.byKey(llaveRegistro(TipoRegistro.gasto)), findsNothing);
      });
    },
  );
}
