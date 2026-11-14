// I9 (revisión de la Fase 1): con una sesión real, el resumen de GRAVITY no
// trae cifras de ejemplo; el ejemplo queda para el modo demostración.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/sesion_efectiva.dart';
import 'package:gravity/modulos/finanzas/estado/resumen_hoy.dart';
import 'package:gravity/modulos/gravity/pantalla/hoy_telefono.dart';
import 'package:gravity/modulos/gravity/pantalla/pantalla_principal.dart';
import 'package:gravity/modulos/gravity/pantalla/resumen_gravity.dart';
import 'package:gravity/modulos/gravity/pantalla/saludo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/sesion/proveedores_sesion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_demostracion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_falso.dart';
import 'package:gravity/nucleo/sesion/sesion.dart';

import '../../../diseno/ayuda_pruebas.dart';

ProviderContainer _contenedor(ServicioSesion servicio) {
  final c = ProviderContainer(
    overrides: [servicioSesionProvider.overrideWithValue(servicio)],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('datosResumenGravityProvider', () {
    test('modo demostración: los datos de ejemplo de los bocetos', () {
      final c = _contenedor(ServicioSesionDemostracion());
      expect(c.read(datosResumenGravityProvider), ResumenGravity.ejemplo);
    });

    test('sesión real: sin datos todavía, nada inventado', () {
      final servicio = ServicioSesionFalso.con(Rol.dueno);
      expect(servicio.esDemostracion, isFalse, reason: 'preparación');
      final datos = _contenedor(servicio).read(datosResumenGravityProvider);
      expect(datos.sinDatos, isTrue);
      expect(datos.finanzas, isNull);
      expect(datos.cuidados, isNull);
      expect(datos.siguiente, isNull);
      expect(datos.habitos, isEmpty);
      expect(datos.agenda, isEmpty);
      expect(datos.avisos, isEmpty);
    });

    test('el filtro por rol conserva "sin datos"', () {
      for (final rol in Rol.values) {
        expect(
          ResumenGravity.sinDatosTodavia.paraRol(rol).sinDatos,
          isTrue,
          reason: '$rol',
        );
      }
      expect(ResumenGravity.ejemplo.paraRol(Rol.dueno).sinDatos, isFalse);
    });

    test('el núcleo solo saluda, sin inventar pendientes', () {
      expect(
        mensajeDelNucleo(momentoNoche, ResumenGravity.sinDatosTodavia),
        'Buenas noches.',
      );
    });
  });

  group('pantallas con una sesión real', () {
    testWidgets('la pantalla principal dice "Sin datos todavía"', (
      tester,
    ) async {
      for (final tamano in const [Size(1440, 900), Size(700, 900)]) {
        fijarVentana(tester, tamano);
        await montar(
          tester,
          const PantallaPrincipalGravity(),
          datos: ResumenGravity.sinDatosTodavia,
          finanzasHoy: ResumenFinanzasHoy.sinAcceso,
        );
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const ValueKey('panel-sin-datos')),
          findsOneWidget,
          reason: '${tamano.width}',
        );
        expect(find.text('Sin datos todavía'), findsOneWidget);
        for (final llave in [
          'panel-hoy',
          'finanzas-hoy',
          'panel-cuidados',
          'panel-avisos',
          'finanzas-hoy-quedan-libro-ejemplo',
        ]) {
          expect(find.byKey(ValueKey(llave)), findsNothing, reason: llave);
        }
        // El núcleo solo saluda.
        expect(find.text('Buenas noches.'), findsOneWidget);
      }
    });

    testWidgets('con datos (o de ejemplo) no sale el aviso', (tester) async {
      fijarVentana(tester, const Size(1440, 900));
      await montar(tester, const PantallaPrincipalGravity());
      expect(find.byKey(const ValueKey('panel-sin-datos')), findsNothing);
      expect(find.text('Sin datos todavía'), findsNothing);
    });

    testWidgets('con la sesión real, sin sobrescribir los datos, no hay '
        'ninguna cifra de ejemplo', (tester) async {
      fijarVentana(tester, const Size(390, 844));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            servicioSesionProvider.overrideWithValue(
              ServicioSesionFalso.con(Rol.dueno),
            ),
            rolEfectivoProvider.overrideWithValue(Rol.dueno),
            resumenFinanzasHoyProvider.overrideWithValue(
              ResumenFinanzasHoy.sinAcceso,
            ),
          ],
          child: const AppDePrueba(home: PantallaHoyTelefono()),
        ),
      );
      await tester.pump();
      expect(find.text('Sin datos todavía'), findsOneWidget);
      final textos = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .join(' · ')
          .toLowerCase();
      for (final inventado in [
        'quedan',
        r'$1,330',
        'tarjeta de crédito',
        'devocional',
        'medicamento',
        'inglés',
        '62',
      ]) {
        expect(textos, isNot(contains(inventado)), reason: inventado);
      }
    });
  });
}
