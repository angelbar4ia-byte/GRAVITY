// I11 (revisión de la Fase 1): FLAG_SECURE y cubierta al pasar a segundo plano
// mientras hay dinero o datos clínicos a la vista. Aquí, la parte de nucleo:
// el contador de quién pide la protección, el canal hacia Android y que la
// parte nativa (MainActivity.kt) hable el mismo canal.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/seguridad/pantalla_segura.dart';

/// Protector que anota cada cambio.
class ProtectorRegistrador implements ProtectorDePantalla {
  final List<bool> cambios = [];

  bool get segura => cambios.isNotEmpty && cambios.last;

  @override
  Future<void> establecer({required bool segura}) async => cambios.add(segura);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ControladorPantallaSegura', () {
    late ProtectorRegistrador protector;
    late ControladorPantallaSegura controlador;

    setUp(() {
      protector = ProtectorRegistrador();
      controlador = ControladorPantallaSegura(protector);
    });

    test('empieza sin protección y no llama al protector', () async {
      await controlador.aplicado;
      expect(controlador.segura, isFalse);
      expect(protector.cambios, isEmpty);
    });

    test('se enciende con el primer pedido y se apaga con el último', () async {
      final soltarPantalla = controlador.pedir();
      final soltarHoja = controlador.pedir();
      await controlador.aplicado;
      expect(controlador.segura, isTrue);
      expect(protector.cambios, [true], reason: 'una sola vez');

      soltarHoja();
      await controlador.aplicado;
      expect(controlador.segura, isTrue, reason: 'la pantalla sigue pidiendo');
      expect(protector.cambios, [true]);

      soltarPantalla();
      await controlador.aplicado;
      expect(controlador.segura, isFalse);
      expect(protector.cambios, [true, false]);
    });

    test('soltar dos veces el mismo pedido no resta de más', () async {
      final a = controlador.pedir();
      controlador.pedir();
      a();
      a();
      await controlador.aplicado;
      expect(controlador.segura, isTrue, reason: 'el otro pedido sigue vivo');
    });

    test('los cambios llegan en el orden en que se pidieron', () async {
      controlador.pedir()();
      controlador.pedir();
      await controlador.aplicado;
      expect(protector.cambios, [true, false, true]);
    });

    test('un protector que falla no rompe al controlador', () async {
      final roto = ControladorPantallaSegura(_ProtectorRoto());
      final soltar = roto.pedir();
      await roto.aplicado;
      soltar();
      await roto.aplicado;
      expect(roto.segura, isFalse);
    });
  });

  group('ProtectorDePantallaAndroid (MethodChannel)', () {
    const canal = MethodChannel(ProtectorDePantallaAndroid.canalDelSistema);
    final mensajero = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    tearDown(() => mensajero.setMockMethodCallHandler(canal, null));

    test('manda "establecer" con segura verdadero o falso', () async {
      final llamadas = <MethodCall>[];
      mensajero.setMockMethodCallHandler(canal, (llamada) async {
        llamadas.add(llamada);
        return null;
      });
      const protector = ProtectorDePantallaAndroid();
      await protector.establecer(segura: true);
      await protector.establecer(segura: false);
      expect([for (final l in llamadas) l.method], ['establecer', 'establecer']);
      expect([for (final l in llamadas) l.arguments], [
        {'segura': true},
        {'segura': false},
      ]);
    });

    test('sin la parte nativa no falla', () async {
      // Sin manejador: MissingPluginException.
      await const ProtectorDePantallaAndroid().establecer(segura: true);
    });

    test('si Android responde con error, se anota y no lanza', () async {
      mensajero.setMockMethodCallHandler(canal, (_) async {
        throw PlatformException(code: 'sin-ventana');
      });
      await const ProtectorDePantallaAndroid().establecer(segura: true);
    });
  });

  group('MainActivity.kt (la parte nativa)', () {
    final actividad = File(
      'android/app/src/main/kotlin/mx/segundocerebro/gravity/MainActivity.kt',
    );

    test('usa FLAG_SECURE y quita la bandera al apagar', () {
      final fuente = actividad.readAsStringSync();
      expect(fuente, contains('FLAG_SECURE'));
      expect(fuente, contains('window.addFlags'));
      expect(fuente, contains('window.clearFlags'));
    });

    test('atiende el mismo canal y el mismo método que Dart', () {
      final fuente = actividad.readAsStringSync();
      expect(
        fuente,
        contains('"${ProtectorDePantallaAndroid.canalDelSistema}"'),
      );
      expect(fuente, contains('"establecer"'));
      expect(fuente, contains('"segura"'));
    });

    test('sigue siendo FlutterFragmentActivity (local_auth lo necesita)', () {
      expect(
        actividad.readAsStringSync(),
        contains('class MainActivity : FlutterFragmentActivity()'),
      );
    });
  });
}

class _ProtectorRoto implements ProtectorDePantalla {
  @override
  Future<void> establecer({required bool segura}) async =>
      throw StateError('no se pudo');
}
