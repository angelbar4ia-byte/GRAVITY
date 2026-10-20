import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/diseno/diseno.dart';
import 'package:gravity/modulos/gravity/pantalla/hoy_telefono.dart';
import 'package:gravity/modulos/gravity/pantalla/resumen_gravity.dart';
import 'package:gravity/nucleo/contratos/roles.dart';

import '../../../diseno/ayuda_pruebas.dart';

Future<void> _verCuidados(WidgetTester tester) => tester.scrollUntilVisible(
  find.byKey(const ValueKey('tarjeta-cuidados')),
  200,
);

void main() {
  group('Se construye sin errores', () {
    for (final tamano in const [Size(390, 844), Size(1440, 900)]) {
      for (final (nombre, momento) in [
        ('noche', momentoNoche),
        ('día', momentoDia),
      ]) {
        testWidgets('en ${tamano.width.toInt()}×${tamano.height.toInt()} '
            'de $nombre', (tester) async {
          fijarVentana(tester, tamano);
          await montar(tester, const PantallaHoyTelefono(), momento: momento);
          await tester.pump(const Duration(seconds: 1));
          expect(tester.takeException(), isNull);
          expect(find.text('Hoy'), findsOneWidget);
          expect(find.text('Martes 20 de octubre'), findsOneWidget);
        });
      }
    }
  });

  testWidgets('muestra lo del boceto "Hoy del Dueño"', (tester) async {
    fijarVentana(tester, const Size(390, 844));
    await montar(tester, const PantallaHoyTelefono());

    expect(find.text('SIGUE · 20:00'), findsOneWidget);
    expect(find.text('Inglés: lección del día'), findsOneWidget);
    expect(find.text('Hecho'), findsOneWidget);
    expect(find.text('Posponer'), findsOneWidget);
    expect(find.text('HÁBITOS DE HOY'), findsOneWidget);
    expect(find.text('3 de 5'), findsOneWidget);
    expect(find.text('Devocional'), findsOneWidget);
    expect(find.text('FINANZAS · SEMANA'), findsOneWidget);
    expect(find.text('En verde'), findsOneWidget);
    expect(find.text(montoOculto), findsOneWidget);
    await _verCuidados(tester);
    expect(find.text('CUIDADOS'), findsOneWidget);
    expect(find.text('Medicamento 20:00'), findsOneWidget);
    expect(find.text('Pendiente'), findsOneWidget);
  });

  testWidgets('el monto se muestra al tocarlo y el modo privado lo oculta', (
    tester,
  ) async {
    fijarVentana(tester, const Size(390, 844));
    await montar(tester, const PantallaHoyTelefono());
    expect(find.text(r'$1,330.00'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('monto-quedan')));
    await tester.pump();
    expect(find.text(r'$1,330.00'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('boton-modo-privado')));
    await tester.pump();
    expect(find.text(r'$1,330.00'), findsNothing);
    expect(find.text(montoOculto), findsOneWidget);
    await _verCuidados(tester);
    expect(find.text('Medicamento 20:00'), findsNothing);
    expect(
      find.text('Datos de cuidados ocultos (modo privado)'),
      findsOneWidget,
    );

    // Con modo privado, tocar el monto no lo muestra.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('monto-quedan')),
      -200,
    );
    await tester.tap(find.byKey(const ValueKey('monto-quedan')));
    await tester.pump();
    expect(find.text(r'$1,330.00'), findsNothing);
  });

  testWidgets('las acciones de ejemplo avisan sin romper nada', (tester) async {
    fijarVentana(tester, const Size(390, 844));
    await montar(tester, const PantallaHoyTelefono());
    await tester.tap(find.text('Hecho'));
    await tester.pump();
    expect(find.byType(SnackBar), findsOneWidget);
  });

  for (final (nombre, momento) in [
    ('noche', momentoNoche),
    ('día', momentoDia),
  ]) {
    testWidgets('cumple zonas táctiles y contraste de texto de $nombre', (
      tester,
    ) async {
      fijarVentana(tester, const Size(390, 844));
      final semantica = tester.ensureSemantics();
      await montar(tester, const PantallaHoyTelefono(), momento: momento);
      await tester.pump(const Duration(seconds: 1));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantica.dispose();
    });
  }

  group('Por rol (D5)', () {
    /// Pantalla alta: la lista de "Hoy" es perezosa y así se construye todo.
    Future<void> montarComo(WidgetTester tester, Rol rol) async {
      fijarVentana(tester, const Size(390, 3000));
      await montar(tester, const PantallaHoyTelefono(), rol: rol);
    }

    String textoVisible(WidgetTester tester) => tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
        .join(' · ')
        .toLowerCase();

    testWidgets('Dueño: todas las tarjetas', (tester) async {
      await montarComo(tester, Rol.dueno);
      for (final tarjeta in [
        'tarjeta-sigue',
        'tarjeta-habitos',
        'tarjeta-finanzas',
        'tarjeta-cuidados',
      ]) {
        expect(find.byKey(ValueKey(tarjeta)), findsOneWidget, reason: tarjeta);
      }
    });

    testWidgets('Familiar: lo suyo, sin dinero ni cuidados', (tester) async {
      await montarComo(tester, Rol.familiar);
      expect(find.byKey(const ValueKey('tarjeta-sigue')), findsOneWidget);
      expect(find.byKey(const ValueKey('tarjeta-habitos')), findsOneWidget);
      expect(find.byKey(const ValueKey('tarjeta-finanzas')), findsNothing);
      expect(find.byKey(const ValueKey('monto-quedan')), findsNothing);
      expect(find.byKey(const ValueKey('tarjeta-cuidados')), findsNothing);
      final texto = textoVisible(tester);
      for (final prohibido in [
        'quedan',
        'tarjeta de crédito',
        'medicamento',
        'entrega de turno',
      ]) {
        expect(texto, isNot(contains(prohibido)), reason: prohibido);
      }
    });

    testWidgets('Casa: solo recordatorios genéricos de cuidados', (
      tester,
    ) async {
      await montarComo(tester, Rol.casa);
      expect(find.byKey(const ValueKey('tarjeta-finanzas')), findsNothing);
      expect(find.byKey(const ValueKey('tarjeta-habitos')), findsNothing);
      expect(find.byKey(const ValueKey('tarjeta-sigue')), findsNothing);
      expect(find.byKey(const ValueKey('tarjeta-cuidados')), findsOneWidget);
      expect(find.text('Recordatorio de cuidados 20:00'), findsOneWidget);
      final texto = textoVisible(tester);
      for (final prohibido in [
        'quedan',
        'medicamento',
        'cuidadora',
        'entrega de turno',
      ]) {
        expect(texto, isNot(contains(prohibido)), reason: prohibido);
      }
    });

    testWidgets('sin nada que mostrar: estado vacío, no tarjetas vacías', (
      tester,
    ) async {
      fijarVentana(tester, const Size(390, 844));
      await montar(
        tester,
        const PantallaHoyTelefono(),
        overrides: [
          datosResumenGravityProvider.overrideWithValue(const ResumenGravity()),
        ],
      );
      expect(find.byKey(const ValueKey('hoy-vacio')), findsOneWidget);
      expect(find.text('Nada pendiente por hoy'), findsOneWidget);
    });
  });
}
