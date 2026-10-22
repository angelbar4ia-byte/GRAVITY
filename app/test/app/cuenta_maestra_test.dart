// D19 (21/oct/2026): la cuenta maestra solo lee todo y nunca ve botones de
// escribir en lo ajeno. En la plataforma: el estado de sesión la lleva
// (`membresias.es_maestra`) y Ajustes no le ofrece lo que administra el hogar.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/app_gravity.dart';
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

/// Cuenta maestra de ejemplo: una cuenta aparte con rol de dueño.
Sesion maestra() => Sesion(
  persona: const Persona(
    id: '00000000-0000-4000-8000-0000000000f1',
    nombre: 'Cuenta maestra de ejemplo',
  ),
  rol: Rol.dueno,
  hogarId: hogarDeEjemplo,
  esMaestra: true,
);

ProviderContainer contenedorDe(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(AppGravity)));

String ubicacion(WidgetTester tester) => contenedorDe(
  tester,
).read(routerProvider).routerDelegate.currentConfiguration.uri.path;

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
      expect(sesionDesdeFila({...fila, 'es_maestra': false}).esMaestra, isFalse);
      // Servidor sin la columna todavía: nadie es maestra.
      expect(sesionDesdeFila(fila).esMaestra, isFalse);
    });

    test('en la tablet la persona guarda si es la cuenta maestra', () {
      final usuario = UsuarioTablet.desdeSesion(maestra(), hashPin: 'hash');
      final copia = UsuarioTablet.desdeJson(
        (jsonDecode(jsonEncode(usuario.aJson())) as Map).cast<String, Object?>(),
      );
      expect(copia.esMaestra, isTrue);
      expect(copia.sesion.esMaestra, isTrue);
    });
  });

  testWidgets('laptop: Ajustes de solo lectura, sin lo que administra el hogar', (
    tester,
  ) async {
    await montarApp(
      tester,
      dispositivo: TipoDispositivo.laptop,
      sesion: ServicioSesionFalso(inicial: maestra()),
    );
    expect(contenedorDe(tester).read(esCuentaMaestraProvider), isTrue);

    await ir(tester, Rutas.ajustes);
    expect(find.text('Dueño · cuenta maestra (solo lectura)'), findsOneWidget);
    for (final titulo in ['Personas y roles', 'Copias de seguridad', 'Desarrollador']) {
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
}
