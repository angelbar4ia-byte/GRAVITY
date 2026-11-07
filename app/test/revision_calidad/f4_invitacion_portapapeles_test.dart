// REVISIÓN DE CALIDAD · FASE 4 (docs/revisiones/fase-4.md) · invitación.
//
// El código de una invitación es una credencial de un solo uso que se entrega
// en persona. No debe quedar en el portapapeles más de 60 s (C1 de la Fase 1b)
// ni salir de la app por otro camino.
//
// Guardias: `PortapapelesTemporal` borra a los 60 s, respeta lo que la persona
// copió después, y lo borra al volver a primer plano si el tiempo se cumplió
// con la app dormida. Hallazgo F4-I1: el código se pinta en un `SelectableText`,
// así que "copiar" del menú de selección lo deja en el portapapeles del
// sistema SIN pasar por el borrado.
//
// Excluir los hallazgos: flutter test --exclude-tags hallazgo
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/ajustes/personas/seccion_cuenta_maestra.dart';
import 'package:gravity/nucleo/invitaciones/invitaciones.dart';
import 'package:gravity/nucleo/seguridad/portapapeles_temporal.dart';

void main() {
  group('PortapapelesTemporal (guardias)', () {
    late String contenido;
    late DateTime ahora;
    late PortapapelesTemporal p;

    setUp(() {
      contenido = '';
      ahora = DateTime(2026, 11, 7, 10);
      p = PortapapelesTemporal(
        escribir: (t) async => contenido = t,
        leer: () async => contenido,
        reloj: () => ahora,
      );
    });
    tearDown(() => p.dispose());

    testWidgets('lo copiado se borra a los 60 s', (tester) async {
      await p.copiar('CODIGO-SECRETO');
      expect(contenido, 'CODIGO-SECRETO');
      await tester.pump(const Duration(seconds: 59));
      expect(contenido, 'CODIGO-SECRETO');
      await tester.pump(const Duration(seconds: 2));
      expect(contenido, isEmpty);
      expect(p.pendiente, isNull);
    });

    testWidgets('si la persona copió otra cosa, se respeta', (tester) async {
      await p.copiar('CODIGO-SECRETO');
      contenido = 'mi lista del súper';
      await tester.pump(const Duration(seconds: 61));
      expect(contenido, 'mi lista del súper');
    });

    testWidgets('con la app dormida, al volver ya vencido se borra', (
      tester,
    ) async {
      await p.copiar('CODIGO-SECRETO');
      ahora = ahora.add(const Duration(seconds: 90));
      p.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 10));
      expect(contenido, isEmpty);
    });

    testWidgets('al volver antes de tiempo no se borra todavía', (tester) async {
      await p.copiar('CODIGO-SECRETO');
      ahora = ahora.add(const Duration(seconds: 30));
      p.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 10));
      expect(contenido, 'CODIGO-SECRETO');
      // Cierra el temporizador pendiente (el borrado a los 60 s).
      await tester.pump(const Duration(seconds: 61));
      expect(contenido, isEmpty);
    });

    test('la duración por omisión es de 60 s', () {
      expect(PortapapelesTemporal().duracion, const Duration(seconds: 60));
    });
  });

  group('HALLAZGOS Fase 4 · invitación', () {
    // F4-I1 (MENOR) · seccion_cuenta_maestra.dart, DialogoCodigoInvitacion:
    // `SelectableText(creada.token)`. Mantener pulsado y "Copiar" escribe en
    // el portapapeles del sistema sin el borrado a los 60 s; el aviso de la
    // pantalla dice "Si lo copias, se borra". Además el diálogo no pide
    // FLAG_SECURE (el código es una credencial) aunque la frase de la nube sí.
    testWidgets(
      'F4-I1: el código no se puede copiar por fuera del botón Copiar',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => DialogoCodigoInvitacion(
                    correo: 'ejemplo@ejemplo.test',
                    creada: InvitacionCreada(
                      id: 'i1',
                      token: 'ABCD-EFGH-IJKL',
                      expira: DateTime(2026, 11, 14),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.text('ABCD-EFGH-IJKL'), findsOneWidget);
        expect(
          find.byType(SelectableText),
          findsNothing,
          reason: 'solo el botón Copiar (con borrado) debe sacar el código',
        );
      },
    );
  });
}
