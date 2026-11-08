import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity/modulos/gravity/conversacion/cliente_asistente.dart';
import 'package:gravity/modulos/gravity/conversacion/conversacion.dart';
import 'package:gravity/modulos/gravity/conversacion/acciones_google.dart';
import 'package:gravity/modulos/gravity/conversacion/panel_conversacion.dart';
import 'package:gravity/modulos/gravity/conversacion/voz.dart';

import '../../../diseno/ayuda_pruebas.dart';
import 'conversacion_test.dart' show ClienteFalso;

Future<void> pulsarMicrofono(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('boton-microfono')));
  await tester.pump();
  await tester.pump();
}

void main() {
  pruebasDictadoTelefono();
  testWidgets('el texto reconocido llega como un mensaje normal al asistente', (
    tester,
  ) async {
    fijarVentana(tester, const Size(1440, 900));
    final cliente = ClienteFalso();
    final voz = VozEntradaFalsa('cuánto llevo esta semana');
    await montar(
      tester,
      const Scaffold(body: PanelConversacion()),
      overrides: [
        clienteAsistenteProvider.overrideWithValue(cliente),
        vozEntradaProvider.overrideWithValue(voz),
      ],
    );
    await tester.pump();
    await pulsarMicrofono(tester);
    expect(voz.escuchas, 1);
    expect(cliente.llamadas.single.mensaje, 'cuánto llevo esta semana');
    expect(find.text('cuánto llevo esta semana'), findsOneWidget);
  });

  testWidgets('sin reconocimiento de voz no hay micrófono ni interruptor', (
    tester,
  ) async {
    fijarVentana(tester, const Size(1440, 900));
    await montar(tester, const Scaffold(body: PanelConversacion()));
    await tester.pump();
    expect(find.byKey(const ValueKey('boton-microfono')), findsNothing);
    expect(find.byKey(const ValueKey('leer-en-voz-alta')), findsNothing);
  });

  testWidgets(
    'sin activar la lectura no se habla; activada, solo lo del asistente',
    (tester) async {
      fijarVentana(tester, const Size(1440, 900));
      final cliente = ClienteFalso(
        const RespuestaAsistente(texto: 'Vas bien.'),
      );
      final salida = VozSalidaFalsa();
      final entrada = VozEntradaFalsa('hola');
      await montar(
        tester,
        const Scaffold(body: PanelConversacion()),
        overrides: [
          clienteAsistenteProvider.overrideWithValue(cliente),
          vozEntradaProvider.overrideWithValue(entrada),
          vozSalidaProvider.overrideWithValue(salida),
        ],
      );
      await tester.pump();
      await pulsarMicrofono(tester);
      expect(find.text('Vas bien.'), findsOneWidget);
      expect(salida.dichas, isEmpty);

      await tester.tap(find.byKey(const ValueKey('leer-en-voz-alta')));
      await tester.pump();
      await pulsarMicrofono(tester);
      // Solo la respuesta del asistente; nunca lo dicho por la persona.
      expect(salida.dichas, ['Vas bien.']);
    },
  );

  testWidgets('decir "confirmo" por voz no confirma ninguna acción (D8)', (
    tester,
  ) async {
    fijarVentana(tester, const Size(1440, 900));
    final cliente = ClienteFalso();
    final voz = VozEntradaFalsa('sí, confirmo, envíalo');
    await montar(
      tester,
      const Scaffold(body: PanelConversacion()),
      overrides: [
        clienteAsistenteProvider.overrideWithValue(cliente),
        vozEntradaProvider.overrideWithValue(voz),
      ],
    );
    await tester.pump();
    await pulsarMicrofono(tester);
    // Es solo un mensaje de texto: no abre ni confirma acciones de Google.
    final contenedor = ProviderScope.containerOf(
      tester.element(find.byType(PanelConversacion)),
    );
    expect(contenedor.read(accionesGoogleProvider), isNull);
    expect(cliente.llamadas.single.mensaje, 'sí, confirmo, envíalo');
  });
}

void pruebasDictadoTelefono() {
  test('el dictado real no pide permisos al abrir el panel', () async {
    // disponible() no inicializa el motor (no toca micrófono ni permisos).
    expect(await VozEntradaTelefono().disponible(), isTrue);
  });

  test('sin Android el dictado no está disponible', () async {
    expect(await const VozEntradaNoDisponible().disponible(), isFalse);
  });
}
