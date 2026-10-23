// Aviso de la bandeja de salida de la tablet (D14, 23/oct): solo cuenta, solo
// en tablets, y dice qué se sube solo y qué espera el PIN de su persona.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/dispositivo.dart';
import 'package:gravity/app/pantallas/registros_atencion.dart';
import 'package:gravity/nucleo/cola/proveedores_cola.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';

const aviso = ValueKey('aviso-bandeja-de-salida');

Future<void> montar(
  WidgetTester tester, {
  TipoDispositivo dispositivo = TipoDispositivo.tablet,
  EstadoBandeja estado = EstadoBandeja.vacio,
  int caducados = 0,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tipoDispositivoProvider.overrideWithValue(dispositivo),
        estadoBandejaProvider.overrideWith((ref) async => estado),
        caducadosDeLaBandejaProvider.overrideWith(
          (ref) => Stream.value(caducados),
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(body: ConAvisoAtencion(child: Text('contenido'))),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sin nada por subir no se ve', (tester) async {
    await montar(tester);
    expect(find.byKey(aviso), findsNothing);
    expect(find.text('contenido'), findsOneWidget);
  });

  testWidgets('en el teléfono nunca se ve', (tester) async {
    await montar(
      tester,
      dispositivo: TipoDispositivo.telefono,
      estado: const EstadoBandeja(porSubir: 3, seSubenSolos: 3),
    );
    expect(find.byKey(aviso), findsNothing);
  });

  testWidgets('uno por subir y se sube solo, sin pedir el PIN', (tester) async {
    await montar(
      tester,
      estado: const EstadoBandeja(porSubir: 1, seSubenSolos: 1),
    );
    expect(find.byKey(aviso), findsOneWidget);
    expect(find.text('1 por subir'), findsOneWidget);
    expect(
      find.text('Se suben solos cuando haya señal; no hace falta el PIN.'),
      findsOneWidget,
    );
  });

  testWidgets('mezcla: unos se suben solos y otros esperan su PIN', (
    tester,
  ) async {
    await montar(
      tester,
      estado: const EstadoBandeja(porSubir: 3, seSubenSolos: 1),
    );
    expect(find.text('3 por subir'), findsOneWidget);
    expect(
      find.textContaining('1 se suben solos cuando haya señal.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('2 esperan a que su persona entre con su PIN.'),
      findsOneWidget,
    );
  });

  testWidgets('los caducados se avisan aunque no quede nada por subir', (
    tester,
  ) async {
    await montar(tester, caducados: 2);
    expect(find.byKey(aviso), findsOneWidget);
    expect(find.textContaining('2 caducaron (7 días sin señal)'), findsOneWidget);
  });

  testWidgets('solo cuenta: no muestra montos ni nombres', (tester) async {
    await montar(
      tester,
      estado: const EstadoBandeja(porSubir: 2, seSubenSolos: 2),
    );
    final textos = tester
        .widgetList<Text>(find.descendant(
          of: find.byKey(aviso),
          matching: find.byType(Text),
        ))
        .map((t) => t.data ?? '')
        .join(' ');
    expect(textos, isNot(contains(r'$')));
    expect(RegExp(r'\d').allMatches(textos).length, lessThanOrEqualTo(4));
  });
}
