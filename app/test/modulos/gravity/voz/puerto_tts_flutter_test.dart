// La puerta real a flutter_tts, probada contra un canal simulado: no hay
// plugin ni dispositivo, pero sí el protocolo del plugin tal como lo leímos en
// su código (flutter_tts 4.2.5).
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/gravity/voz/fuentes/dispositivo/puerto_tts.dart';
import 'package:gravity/modulos/gravity/voz/tipos.dart';

const _canal = MethodChannel('flutter_tts');

/// El "sistema" simulado: contesta a las llamadas y deja a la prueba mandar
/// eventos como los del plugin (`speak.onComplete`, `speak.onError`…).
class SistemaSimulado {
  final llamadas = <MethodCall>[];
  Object? voces = <Object?>[];
  Object? rango = {'min': '0', 'normal': '0.5', 'max': '1.5', 'platform': 'android'};
  bool sinSoporteDeRango = false;
  bool pluginAusente = false;
  Object? respuestaSetVoice = 1;

  /// Cada `speak` pendiente; la prueba lo completa con 1 (terminó) o 0.
  final speaks = <Completer<Object?>>[];

  List<String> get metodos => [for (final l in llamadas) l.method];

  int llamadasA(String metodo) => metodos.where((m) => m == metodo).length;

  Future<Object?> _manejar(MethodCall call) async {
    llamadas.add(call);
    if (pluginAusente) throw MissingPluginException();
    switch (call.method) {
      case 'getVoices':
        return voces;
      case 'getSpeechRateValidRange':
        if (sinSoporteDeRango) throw MissingPluginException();
        return rango;
      case 'setVoice':
        return respuestaSetVoice;
      case 'speak':
        final c = Completer<Object?>();
        speaks.add(c);
        return c.future;
      case 'stop':
        return 1;
      default:
        return 1;
    }
  }

  void instalar() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_canal, _manejar);
  }

  void quitar() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_canal, null);
  }

  /// Un evento que el plugin manda a Dart.
  Future<void> evento(String nombre, [Object? argumentos]) async {
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          'flutter_tts',
          const StandardMethodCodec().encodeMethodCall(MethodCall(nombre, argumentos)),
          (_) {},
        );
  }
}

Future<void> turno() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SistemaSimulado sistema;
  late PuertoTtsFlutter puerto;

  setUp(() {
    sistema = SistemaSimulado()..instalar();
    puerto = PuertoTtsFlutter(esperaDeCorte: const Duration(milliseconds: 40));
  });
  tearDown(() => sistema.quitar());

  group('voces', () {
    test('lee las voces de Android y de Windows', () async {
      sistema.voces = [
        {
          'name': 'en-us-x-sfg#female_1-local',
          'locale': 'en-US',
          'quality': 'high',
          'latency': 'normal',
          'network_required': '0',
          'features': '',
        },
        {'name': 'Microsoft Zira', 'locale': 'en-US', 'gender': 'female', 'identifier': 'x'},
        {'name': '', 'locale': 'en-US'},
        'no es una voz',
      ];
      final voces = await puerto.voces();
      expect(voces.map((v) => v.nombre), ['en-us-x-sfg#female_1-local', 'Microsoft Zira']);
      expect(voces.first.requiereRed, isFalse);
      expect(voces.last.requiereRed, isNull);
    });

    test('getVoices nulo es "sin motor de voz"', () async {
      sistema.voces = null;
      await expectLater(
        puerto.voces(),
        throwsA(
          isA<FalloDeSintesis>().having((e) => e.codigo, 'codigo', 'sin_motor_de_voz'),
        ),
      );
    });

    test('sin el plugin en la plataforma, un código y no una excepción cruda', () async {
      sistema.pluginAusente = true;
      await expectLater(
        puerto.voces(),
        throwsA(
          isA<FalloDeSintesis>().having((e) => e.codigo, 'codigo', 'plugin_no_disponible'),
        ),
      );
    });

    test('prepara el plugin una sola vez: espera a que termine de hablar', () async {
      sistema.voces = <Object?>[];
      await puerto.voces();
      await puerto.voces();
      expect(sistema.llamadasA('awaitSpeakCompletion'), 1);
      expect(sistema.llamadas.first.arguments, true);
    });
  });

  group('velocidad y voz', () {
    test('lee el rango de Android', () async {
      sistema.rango = {'min': '0', 'normal': '0.5', 'max': '1.5', 'platform': 'android'};
      final r = await puerto.rangoVelocidad();
      expect((r.min, r.normal, r.max), (0.0, 0.5, 1.5));
    });

    test('Windows no tiene getSpeechRateValidRange: valores por omisión', () async {
      sistema.sinSoporteDeRango = true;
      final r = await puerto.rangoVelocidad();
      expect(r.normal, 0.5);
      expect(r.max, greaterThan(r.normal));
    });

    test('fijarVoz manda nombre y locale tal como los dio el sistema', () async {
      expect(await puerto.fijarVoz('en-us-x-sfg#female_1-local', 'en-US'), isTrue);
      final l = sistema.llamadas.lastWhere((c) => c.method == 'setVoice');
      expect(l.arguments, {'name': 'en-us-x-sfg#female_1-local', 'locale': 'en-US'});
      sistema.respuestaSetVoice = 0;
      expect(await puerto.fijarVoz('no-existe', 'en-US'), isFalse);
    });

    test('fijarVelocidad usa la escala del plugin', () async {
      await puerto.fijarVelocidad(0.4);
      final l = sistema.llamadas.lastWhere((c) => c.method == 'setSpeechRate');
      expect(l.arguments, 0.4);
    });
  });

  group('hablar', () {
    test('completa cuando el plugin termina (speak responde 1)', () async {
      final f = puerto.hablar('hello');
      await turno();
      await turno();
      expect(sistema.llamadas.last.method, 'speak');
      expect(sistema.llamadas.last.arguments, 'hello');
      sistema.speaks.single.complete(1);
      expect(await f, ResultadoHabla.completo);
    });

    test('completa con el aviso de fin aunque speak no responda', () async {
      final f = puerto.hablar('hello');
      await turno();
      await turno();
      await sistema.evento('speak.onComplete', true);
      expect(await f, ResultadoHabla.completo);
    });

    test('un error de Android (speak no responde) llega por el aviso de error', () async {
      const texto = 'TEXTO-PRIVADO-123';
      final f = puerto.hablar(texto);
      final resultado = f.then<Object?>((_) => null, onError: (Object e) => e);
      await turno();
      await turno();
      await sistema.evento('speak.onError', 'Error from TextToSpeech (speak) - -4');
      final error = await resultado;
      expect(error, isA<FalloDeSintesis>());
      expect((error! as FalloDeSintesis).codigo, 'speak_error');
      expect(error.toString(), isNot(contains('TextToSpeech')));
      expect(error.toString(), isNot(contains(texto)));
    });

    test('speak responde 0 sin que lo cortemos: el sistema lo rechazó', () async {
      final f = puerto.hablar('hello');
      await turno();
      await turno();
      sistema.speaks.single.complete(0);
      await expectLater(
        f,
        throwsA(
          isA<FalloDeSintesis>().having((e) => e.codigo, 'codigo', 'speak_rechazado'),
        ),
      );
    });

    test('lo cortado por el sistema (otra app tomó el audio) es interrumpido', () async {
      final f = puerto.hablar('hello');
      await turno();
      await turno();
      await sistema.evento('speak.onCancel', true);
      expect(await f, ResultadoHabla.interrumpido);
    });
  });

  group('detener', () {
    test('si no suena nada, NO llama a stop (en Windows cerraría la app)', () async {
      await puerto.detener();
      expect(sistema.llamadasA('stop'), 0);
      // Tampoco después de que algo terminó.
      final f = puerto.hablar('hello');
      await turno();
      await turno();
      sistema.speaks.single.complete(1);
      await f;
      await puerto.detener();
      expect(sistema.llamadasA('stop'), 0);
    });

    test('corta lo que suena aunque el plugin conteste "1" al cortar (Windows)', () async {
      final f = puerto.hablar('hello');
      await turno();
      await turno();
      await puerto.detener();
      // Windows responde 1 al speak pendiente cuando se llama a stop.
      sistema.speaks.single.complete(1);
      expect(await f, ResultadoHabla.interrumpido);
      expect(sistema.llamadasA('stop'), 1);
    });

    test('el aviso de cancelado del corte anterior no corta el turno siguiente', () async {
      final a = puerto.hablar('uno');
      await turno();
      await turno();
      await puerto.detener();
      sistema.speaks.single.complete(0);
      expect(await a, ResultadoHabla.interrumpido);

      // Empieza el siguiente: espera el aviso de cancelado del corte.
      final b = puerto.hablar('dos');
      await turno();
      expect(sistema.speaks, hasLength(1), reason: 'aún espera el aviso');
      await sistema.evento('speak.onCancel', true);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(sistema.speaks, hasLength(2));
      sistema.speaks.last.complete(1);
      expect(await b, ResultadoHabla.completo);
    });

    test('si el aviso de cancelado nunca llega, el siguiente turno igual empieza', () async {
      final a = puerto.hablar('uno');
      await turno();
      await turno();
      await puerto.detener();
      sistema.speaks.single.complete(0);
      await a;
      final b = puerto.hablar('dos');
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(sistema.speaks, hasLength(2));
      sistema.speaks.last.complete(1);
      expect(await b, ResultadoHabla.completo);
    });
  });
}
