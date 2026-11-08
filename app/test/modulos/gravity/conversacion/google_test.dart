// Gmail y Calendar en el panel: formulario, confirmación y D3 (el contenido de
// Google se ve en la pantalla y no vuelve al asistente).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/gravity/conversacion/acciones_google.dart';
import 'package:gravity/modulos/gravity/conversacion/cliente_asistente.dart';
import 'package:gravity/modulos/gravity/conversacion/cliente_google.dart';
import 'package:gravity/modulos/gravity/conversacion/conversacion.dart';
import 'package:gravity/modulos/gravity/pantalla/pantalla_principal.dart';

import '../../../diseno/ayuda_pruebas.dart';
import 'conversacion_test.dart' show ClienteFalso, escribir;

class GoogleFalso implements ClienteGoogleAsistente {
  final llamadas =
      <
        ({String herramienta, Map<String, Object?> parametros, bool confirmado})
      >[];
  ErrorAsistente? error;

  @override
  Future<ResultadoGoogle> ejecutar({
    required String sesion,
    required String herramienta,
    Map<String, Object?> parametros = const {},
    bool confirmado = false,
  }) async {
    llamadas.add((
      herramienta: herramienta,
      parametros: parametros,
      confirmado: confirmado,
    ));
    final e = error;
    if (e != null) throw e;
    if (herramienta == 'gmail.leer') {
      return const ResultadoGoogle(
        titulo: 'Tu bandeja',
        lineas: ['Factura de \$12,500 · banco'],
      );
    }
    if (herramienta == 'gmail.redactar') {
      return const ResultadoGoogle(
        confirmacion: ConfirmacionGoogle(
          herramienta: 'gmail.enviar',
          parametros: {'borrador_id': 'b1'},
          titulo: '¿Enviar este correo?',
          lineas: ['Para: luis@ejemplo.test', 'Asunto: Hola'],
          boton: 'Enviar correo',
        ),
      );
    }
    if (herramienta == 'calendario.crear' && !confirmado) {
      return ResultadoGoogle(
        confirmacion: ConfirmacionGoogle(
          herramienta: 'calendario.crear',
          parametros: parametros,
          titulo: '¿Crear este evento?',
          lineas: ['Cena'],
          boton: 'Crear evento',
        ),
      );
    }
    return const ResultadoGoogle(titulo: 'Hecho.');
  }
}

ProviderContainer contenedor(ClienteFalso ia, GoogleFalso g) {
  final c = ProviderContainer(
    overrides: [
      clienteAsistenteProvider.overrideWithValue(ia),
      clienteGoogleProvider.overrideWithValue(g),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

Future<void> tocar(WidgetTester tester, Key k) async {
  await tester.ensureVisible(find.byKey(k));
  await tester.pump();
  await tester.tap(find.byKey(k));
}

void main() {
  test('interpreta la respuesta del servidor', () {
    final r = resultadoGoogleDeJson({
      'requiere_confirmacion': true,
      'confirmacion': {
        'herramienta': 'gmail.enviar',
        'parametros': {'borrador_id': 'x'},
        'titulo': 't',
        'lineas': ['a'],
        'boton': 'Enviar',
      },
    });
    expect(r.confirmacion!.herramienta, 'gmail.enviar');
    expect(r.confirmacion!.parametros['borrador_id'], 'x');
    expect(
      resultadoGoogleDeJson({
        'ok': true,
        'local': {
          'titulo': 'T',
          'lineas': ['l'],
        },
      }).texto,
      'T\nl',
    );
    expect(() => resultadoGoogleDeJson('raro'), throwsA(isA<ErrorAsistente>()));
  });

  test('la fecha lleva su diferencia horaria', () {
    expect(
      isoConZona(DateTime(2026, 11, 12, 19, 5)),
      matches(RegExp(r'^2026-11-12T19:05:00[+-]\d\d:\d\d$')),
    );
  });

  test('leer: se muestra en la pantalla y no entra al historial que viaja al asistente (D3)', () async {
    final ia = ClienteFalso(
      const RespuestaAsistente(
        texto: 'Aquí tienes.',
        herramienta: 'gmail.leer',
      ),
    );
    final g = GoogleFalso();
    final c = contenedor(ia, g);
    await c
        .read(conversacionAsistenteProvider.notifier)
        .enviar(
          'revisa mi correo',
          ejecutar: (h) async {
            await c.read(accionesGoogleProvider.notifier).iniciar(h);
            return null;
          },
        );
    expect(g.llamadas.single.confirmado, isFalse);
    final m = c.read(conversacionAsistenteProvider).mensajes;
    expect(
      m.any((x) => x.autor == AutorMensaje.local && x.texto.contains('12,500')),
      isTrue,
    );
    await c.read(conversacionAsistenteProvider.notifier).enviar('gracias');
    expect(
      ia.llamadas.last.historial.map((t) => t.texto).join(),
      isNot(contains('12,500')),
    );
  });

  test(
    'redactar: no se envía hasta confirmar; cancelar no envía nada',
    () async {
      final g = GoogleFalso();
      final c = contenedor(ClienteFalso(), g);
      final n = c.read(accionesGoogleProvider.notifier);
      await n.iniciar('gmail.redactar');
      expect(c.read(accionesGoogleProvider)!.fase, FaseGoogle.formulario);
      expect(g.llamadas, isEmpty);
      await n.enviarFormulario({
        'para': 'luis@ejemplo.test',
        'asunto': 'Hola',
        'cuerpo': 'Hola',
      });
      expect(c.read(accionesGoogleProvider)!.fase, FaseGoogle.confirmacion);
      expect(g.llamadas.every((l) => !l.confirmado), isTrue);
      n.cancelar();
      expect(c.read(accionesGoogleProvider), isNull);
      expect(g.llamadas.where((l) => l.herramienta == 'gmail.enviar'), isEmpty);

      await n.iniciar('gmail.redactar');
      await n.enviarFormulario({
        'para': 'luis@ejemplo.test',
        'asunto': 'Hola',
        'cuerpo': 'Hola',
      });
      await n.confirmar();
      final envio = g.llamadas.last;
      expect(
        (envio.herramienta, envio.confirmado, envio.parametros['borrador_id']),
        ('gmail.enviar', true, 'b1'),
      );
      expect(c.read(accionesGoogleProvider), isNull);
      expect(
        c.read(conversacionAsistenteProvider).mensajes.last.texto,
        'Hecho.',
      );
    },
  );

  test('sin cuenta conectada se avisa en la conversación', () async {
    final g = GoogleFalso()
      ..error = const ErrorAsistente(
        'sin_cuenta_google',
        'Falta conectar tu cuenta de Google.',
      );
    final c = contenedor(ClienteFalso(), g);
    await c.read(accionesGoogleProvider.notifier).iniciar('calendario.ver');
    final ultimo = c.read(conversacionAsistenteProvider).mensajes.last;
    expect(
      (ultimo.autor, ultimo.texto),
      (AutorMensaje.error, 'Falta conectar tu cuenta de Google.'),
    );
  });

  testWidgets(
    'panel: el asistente elige crear evento, se llena, se revisa y se confirma',
    (tester) async {
      fijarVentana(tester, const Size(1440, 900));
      final ia = ClienteFalso(
        const RespuestaAsistente(
          texto: 'Vamos.',
          herramienta: 'calendario.crear',
        ),
      );
      final g = GoogleFalso();
      await montar(
        tester,
        const PantallaPrincipalGravity(),
        overrides: [
          clienteAsistenteProvider.overrideWithValue(ia),
          clienteGoogleProvider.overrideWithValue(g),
        ],
      );
      await escribir(tester, 'crea una cena el jueves');
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('tarjeta-google')), findsOneWidget);
      // Datos inválidos: no llega al servidor.
      await tocar(tester, const ValueKey('continuar-google'));
      await tester.pump();
      expect(find.byKey(const ValueKey('error-google')), findsOneWidget);
      expect(g.llamadas, isEmpty);

      await tester.enterText(
        find.byKey(const ValueKey('google-titulo')),
        'Cena',
      );
      await tester.enterText(
        find.byKey(const ValueKey('google-inicio')),
        '2026-11-12 19:00',
      );
      await tester.enterText(
        find.byKey(const ValueKey('google-fin')),
        '2026-11-12 21:00',
      );
      await tocar(tester, const ValueKey('continuar-google'));
      await tester.pump();
      await tester.pump();
      expect(g.llamadas.single.confirmado, isFalse);
      expect(find.text('¿Crear este evento?'), findsOneWidget);
      expect(find.byKey(const ValueKey('confirmar-google')), findsOneWidget);

      await tocar(tester, const ValueKey('confirmar-google'));
      await tester.pump();
      await tester.pump();
      expect(g.llamadas.last.confirmado, isTrue);
      expect(find.byKey(const ValueKey('tarjeta-google')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('panel: cancelar la tarjeta no manda nada', (tester) async {
    fijarVentana(tester, const Size(390, 844));
    final ia = ClienteFalso(
      const RespuestaAsistente(texto: 'Va.', herramienta: 'gmail.redactar'),
    );
    final g = GoogleFalso();
    await montar(
      tester,
      const PantallaPrincipalGravity(),
      overrides: [
        clienteAsistenteProvider.overrideWithValue(ia),
        clienteGoogleProvider.overrideWithValue(g),
      ],
    );
    await escribir(tester, 'escríbele a Luis');
    await tester.pump();
    await tester.pump();
    await tocar(tester, const ValueKey('cancelar-google'));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('tarjeta-google')), findsNothing);
    expect(g.llamadas, isEmpty);
  });
}
