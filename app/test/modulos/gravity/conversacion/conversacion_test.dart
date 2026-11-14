import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/gravity/conversacion/cliente_asistente.dart';
import 'package:gravity/modulos/gravity/conversacion/conversacion.dart';
import 'package:gravity/modulos/gravity/conversacion/panel_conversacion.dart';
import 'package:gravity/modulos/gravity/pantalla/hoy_telefono.dart';
import 'package:gravity/modulos/gravity/pantalla/pantalla_principal.dart';
import 'package:gravity/nucleo/contratos/roles.dart';

import '../../../diseno/ayuda_pruebas.dart';

/// Cliente falso: guarda lo que recibe y responde lo que se le indique.
class ClienteFalso implements ClienteAsistente {
  ClienteFalso([this.respuesta = const RespuestaAsistente(texto: 'Hola.')]);

  RespuestaAsistente respuesta;
  ErrorAsistente? error;
  Completer<void>? espera;
  final llamadas =
      <({String mensaje, String sesion, List<TurnoConversacion> historial})>[];

  @override
  Future<RespuestaAsistente> preguntar({
    required String mensaje,
    required String sesion,
    List<TurnoConversacion> historial = const [],
  }) async {
    llamadas.add((mensaje: mensaje, sesion: sesion, historial: historial));
    await espera?.future;
    final e = error;
    if (e != null) throw e;
    return respuesta;
  }

  @override
  Future<Object?> sugerirRecetas(Map<String, Object?> contexto) async =>
      throw UnimplementedError();
}

Future<void> escribir(WidgetTester tester, String texto) async {
  await tester.enterText(
    find.byKey(const ValueKey('campo-conversacion')),
    texto,
  );
  await tester.tap(find.byKey(const ValueKey('boton-enviar-conversacion')));
  await tester.pump();
  await tester.pump();
}

void main() {
  group('Cliente (estado)', () {
    test('manda el mensaje con la misma sesión y el historial; la herramienta se ejecuta en local', () async {
      final cliente = ClienteFalso(
        const RespuestaAsistente(
          texto: 'Abriendo.',
          herramienta: 'finanzas.resumen_semana',
        ),
      );
      final c = ProviderContainer(
        overrides: [clienteAsistenteProvider.overrideWithValue(cliente)],
      );
      addTearDown(c.dispose);
      final ejecutadas = <String>[];
      await c
          .read(conversacionAsistenteProvider.notifier)
          .enviar(
            'cómo voy',
            ejecutar: (h) async {
              ejecutadas.add(h);
              return 'Quedan 12 en la semana (texto local)';
            },
          );
      cliente.respuesta = const RespuestaAsistente(texto: 'Listo.');
      await c.read(conversacionAsistenteProvider.notifier).enviar('gracias');

      expect(ejecutadas, ['finanzas.resumen_semana']);
      expect(cliente.llamadas[0].sesion, cliente.llamadas[1].sesion);
      expect(
        cliente.llamadas[0].sesion,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
      // El segundo envío lleva el contexto de personas y asistente, nunca el texto local.
      final h = cliente.llamadas[1].historial;
      expect(h.map((t) => t.texto), ['cómo voy', 'Abriendo.']);
      expect(h.any((t) => t.texto.contains('local')), isFalse);
      final autores = c
          .read(conversacionAsistenteProvider)
          .mensajes
          .map((m) => m.autor);
      expect(autores, contains(AutorMensaje.local));
    });

    test(
      'un error del servidor se muestra tal cual y no rompe la conversación',
      () async {
        final cliente = ClienteFalso()
          ..error = const ErrorAsistente(
            'sin_clave',
            'Falta la clave en el servidor.',
          );
        final c = ProviderContainer(
          overrides: [clienteAsistenteProvider.overrideWithValue(cliente)],
        );
        addTearDown(c.dispose);
        await c.read(conversacionAsistenteProvider.notifier).enviar('hola');
        final e = c.read(conversacionAsistenteProvider);
        expect(e.pensando, isFalse);
        expect(e.mensajes.last.autor, AutorMensaje.error);
        expect(e.mensajes.last.texto, 'Falta la clave en el servidor.');
      },
    );

    test(
      'si la herramienta local falla, se avisa sin cifras del error',
      () async {
        final cliente = ClienteFalso(
          const RespuestaAsistente(texto: 'ok', herramienta: 'finanzas.abrir'),
        );
        final c = ProviderContainer(
          overrides: [clienteAsistenteProvider.overrideWithValue(cliente)],
        );
        addTearDown(c.dispose);
        await c
            .read(conversacionAsistenteProvider.notifier)
            .enviar(
              'abre',
              ejecutar: (_) async => throw StateError('saldo 9999'),
            );
        final m = c.read(conversacionAsistenteProvider).mensajes.last;
        expect(m.autor, AutorMensaje.error);
        expect(m.texto, isNot(contains('9999')));
      },
    );

    test('sin servidor (demostración) avisa con claridad', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await c.read(conversacionAsistenteProvider.notifier).enviar('hola');
      expect(
        c.read(conversacionAsistenteProvider).mensajes.last.texto,
        contains('servidor'),
      );
    });

    test('mensajes vacíos no se envían', () async {
      final cliente = ClienteFalso();
      final c = ProviderContainer(
        overrides: [clienteAsistenteProvider.overrideWithValue(cliente)],
      );
      addTearDown(c.dispose);
      await c.read(conversacionAsistenteProvider.notifier).enviar('   ');
      expect(cliente.llamadas, isEmpty);
    });
  });

  group('Pantalla', () {
    for (final tamano in const [Size(1440, 900), Size(390, 844)]) {
      testWidgets(
        'principal ${tamano.width.toInt()}: escribir y ver la respuesta en la misma pantalla',
        (tester) async {
          fijarVentana(tester, tamano);
          final cliente = ClienteFalso(
            const RespuestaAsistente(texto: 'Aquí estoy.'),
          );
          await montar(
            tester,
            const PantallaPrincipalGravity(),
            overrides: [clienteAsistenteProvider.overrideWithValue(cliente)],
          );
          expect(
            find.byKey(const ValueKey('panel-conversacion')),
            findsOneWidget,
          );
          await escribir(tester, 'hola GRAVITY');
          expect(tester.takeException(), isNull);
          expect(cliente.llamadas.single.mensaje, 'hola GRAVITY');
          expect(find.text('hola GRAVITY'), findsOneWidget);
          expect(find.text('Aquí estoy.'), findsOneWidget);
        },
      );
    }

    testWidgets('teléfono: Hoy lleva el campo y responde', (tester) async {
      fijarVentana(tester, const Size(390, 844));
      final cliente = ClienteFalso(
        const RespuestaAsistente(texto: 'Buen día.'),
      );
      await montar(
        tester,
        const PantallaHoyTelefono(),
        overrides: [clienteAsistenteProvider.overrideWithValue(cliente)],
      );
      await escribir(tester, 'buenos días');
      expect(find.text('Buen día.'), findsOneWidget);
    });

    testWidgets('mientras espera muestra "pensando" y bloquea el envío doble', (
      tester,
    ) async {
      fijarVentana(tester, const Size(1440, 900));
      final cliente = ClienteFalso()..espera = Completer<void>();
      await montar(
        tester,
        const PantallaPrincipalGravity(),
        overrides: [clienteAsistenteProvider.overrideWithValue(cliente)],
      );
      await escribir(tester, 'uno');
      expect(
        find.byKey(const ValueKey('conversacion-pensando')),
        findsOneWidget,
      );
      cliente.espera!.complete();
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('conversacion-pensando')), findsNothing);
      expect(cliente.llamadas, hasLength(1));
    });

    testWidgets('un error se ve como aviso en la misma pantalla', (
      tester,
    ) async {
      fijarVentana(tester, const Size(1440, 900));
      final cliente = ClienteFalso()
        ..error = const ErrorAsistente(
          'limite_diario',
          'Llegaste al límite de mensajes de hoy.',
        );
      await montar(
        tester,
        const PantallaPrincipalGravity(),
        overrides: [clienteAsistenteProvider.overrideWithValue(cliente)],
      );
      await escribir(tester, 'hola');
      expect(
        find.text('Llegaste al límite de mensajes de hoy.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'si el asistente elige una herramienta, se ejecuta en el dispositivo y navega',
      (tester) async {
        fijarVentana(tester, const Size(1440, 900));
        final cliente = ClienteFalso(
          const RespuestaAsistente(
            texto: 'Abriendo hábitos.',
            herramienta: 'habitos.abrir',
          ),
        );
        final rutas = <String>[];
        await montar(
          tester,
          Scaffold(body: PanelConversacion(navegar: rutas.add)),
          overrides: [clienteAsistenteProvider.overrideWithValue(cliente)],
        );
        await escribir(tester, 'abre mis hábitos');
        expect(rutas, isNotEmpty);
        expect(find.text('Abriendo hábitos.'), findsOneWidget);
      },
    );

    testWidgets(
      'una herramienta que el rol no tiene no se ejecuta aunque el servidor la devuelva',
      (tester) async {
        fijarVentana(tester, const Size(1440, 900));
        final cliente = ClienteFalso(
          const RespuestaAsistente(texto: 'ok', herramienta: 'finanzas.abrir'),
        );
        final rutas = <String>[];
        await montar(
          tester,
          Scaffold(body: PanelConversacion(navegar: rutas.add)),
          rol: Rol.familiar,
          overrides: [clienteAsistenteProvider.overrideWithValue(cliente)],
        );
        await escribir(tester, 'abre finanzas');
        expect(rutas, isEmpty);
        expect(
          find.text('No pude hacer eso en este dispositivo.'),
          findsOneWidget,
        );
      },
    );

    for (final rol in [Rol.cuidador, Rol.casa, null]) {
      testWidgets('rol $rol: no hay conversación libre (D5)', (tester) async {
        fijarVentana(tester, const Size(1440, 900));
        await montar(tester, const PantallaPrincipalGravity(), rol: rol);
        expect(find.byKey(const ValueKey('panel-conversacion')), findsNothing);
        expect(find.byKey(const ValueKey('campo-conversacion')), findsNothing);
      });
    }

    testWidgets(
      'el campo avisa que no se escriban cifras de dinero ni de salud',
      (tester) async {
        fijarVentana(tester, const Size(1440, 900));
        await montar(tester, const PantallaPrincipalGravity());
        expect(
          find.byKey(const ValueKey('aviso-conversacion')),
          findsOneWidget,
        );
      },
    );
  });
}
