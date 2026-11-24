// H-14 (aprobado el 24/nov/2026): mantener la pantalla encendida con un canal
// nativo de Android (FLAG_KEEP_SCREEN_ON), sin paquete ni permisos nuevos.
// Aquí: el canal simulado (activar, soltar, idempotencia, pedidos contados,
// segundo plano, fallos), el no-op fuera de Android y que la parte nativa, el
// manifiesto y las dependencias no ganen nada de más.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/gimnasio/pantalla_encendida.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const canal = MethodChannel(PantallaEncendidaAndroid.canalDelSistema);
  final mensajero =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => mensajero.setMockMethodCallHandler(canal, null));

  /// Registra cada llamada y la deja pasar (o lanza [fallo]).
  List<bool> simular({Object? Function()? fallo}) {
    final enviados = <bool>[];
    mensajero.setMockMethodCallHandler(canal, (llamada) async {
      expect(llamada.method, 'establecer');
      final error = fallo?.call();
      if (error != null) throw error;
      enviados.add((llamada.arguments as Map)['encendida'] as bool);
      return null;
    });
    return enviados;
  }

  group('PantallaEncendidaAndroid (canal simulado)', () {
    test('mantener(true) y mantener(false) mandan "establecer"', () async {
      final enviados = simular();
      final p = PantallaEncendidaAndroid();
      expect(p.disponible, isTrue);
      expect(await p.mantener(true), isTrue);
      expect(p.encendidaEnElSistema, isTrue);
      expect(await p.mantener(false), isTrue);
      expect(p.encendidaEnElSistema, isFalse);
      expect(enviados, [true, false]);
    });

    test('es idempotente: pedir o soltar de más no manda nada de más', () async {
      final enviados = simular();
      final p = PantallaEncendidaAndroid();
      await p.mantener(true);
      await p.mantener(true);
      await p.mantener(true);
      await p.mantener(false);
      await p.mantener(false);
      expect(enviados, [true, false]);
    });

    test('soltar sin haber pedido nunca no toca el canal', () async {
      final enviados = simular();
      final p = PantallaEncendidaAndroid();
      expect(await p.mantener(false), isTrue);
      expect(enviados, isEmpty);
    });

    test('dos pedidos: se apaga solo al soltar el último', () async {
      final enviados = simular();
      final p = PantallaEncendidaAndroid();
      final a = p.pedir();
      final b = p.pedir();
      await p.aplicado;
      expect(enviados, [true]);
      a();
      await p.aplicado;
      expect(p.encendidaEnElSistema, isTrue, reason: 'queda el de b');
      expect(enviados, [true]);
      b();
      await p.aplicado;
      expect(p.encendidaEnElSistema, isFalse);
      expect(enviados, [true, false]);
    });

    test('soltar dos veces el mismo pedido no resta el de otro', () async {
      final enviados = simular();
      final p = PantallaEncendidaAndroid();
      final a = p.pedir();
      final b = p.pedir();
      a();
      a();
      await p.aplicado;
      expect(p.pedida, isTrue);
      expect(enviados, [true]);
      b();
      await p.aplicado;
      expect(enviados, [true, false]);
    });

    test('mantener() cuenta como un solo pedido junto a pedir()', () async {
      final enviados = simular();
      final p = PantallaEncendidaAndroid();
      final suelta = p.pedir();
      await p.mantener(true);
      expect(await p.mantener(false), isTrue);
      await p.aplicado;
      expect(p.encendidaEnElSistema, isTrue, reason: 'queda el de pedir()');
      suelta();
      await p.aplicado;
      expect(enviados, [true, false]);
    });

    test('segundo plano: se suelta con los pedidos vigentes y vuelve al volver',
        () async {
      final enviados = simular();
      final p = PantallaEncendidaAndroid();
      p.pedir();
      await p.aplicado;
      p.alCambiarElCicloDeVida(AppLifecycleState.inactive);
      await p.aplicado;
      expect(enviados, [true], reason: 'inactive no suelta');
      p.alCambiarElCicloDeVida(AppLifecycleState.paused);
      await p.aplicado;
      expect(enviados, [true, false]);
      expect(p.pedida, isTrue);
      p.alCambiarElCicloDeVida(AppLifecycleState.resumed);
      await p.aplicado;
      expect(enviados, [true, false, true]);
    });

    test('pedir en segundo plano no enciende hasta volver', () async {
      final enviados = simular();
      final p = PantallaEncendidaAndroid();
      p.alCambiarElCicloDeVida(AppLifecycleState.hidden);
      p.pedir();
      await p.aplicado;
      expect(enviados, isEmpty);
      p.alCambiarElCicloDeVida(AppLifecycleState.resumed);
      await p.aplicado;
      expect(enviados, [true]);
    });

    test('cerrar() suelta todo y los pedidos viejos ya no restan', () async {
      final enviados = simular();
      final p = PantallaEncendidaAndroid();
      final viejo = p.pedir();
      await p.aplicado;
      p.cerrar();
      await p.aplicado;
      expect(enviados, [true, false]);
      final nuevo = p.pedir();
      viejo(); // de la vida anterior: no cuenta
      await p.aplicado;
      expect(p.pedida, isTrue);
      expect(enviados, [true, false, true]);
      nuevo();
    });

    test('sin la parte nativa no lanza y deja de estar disponible', () async {
      // Sin manejador: MissingPluginException.
      final p = PantallaEncendidaAndroid();
      expect(await p.mantener(true), isFalse);
      expect(p.disponible, isFalse);
      expect(await p.mantener(false), isTrue);
    });

    test('si Android responde con error, no lanza y se reintenta al volver',
        () async {
      var falla = true;
      final enviados = simular(
        fallo: () => falla ? PlatformException(code: 'sin-ventana') : null,
      );
      final p = PantallaEncendidaAndroid();
      expect(await p.mantener(true), isFalse);
      expect(p.disponible, isTrue, reason: 'un error no es "sin canal"');
      expect(p.pedida, isTrue, reason: 'el pedido sigue vigente');
      falla = false;
      p.alCambiarElCicloDeVida(AppLifecycleState.resumed);
      await p.aplicado;
      expect(enviados, [true]);
      expect(p.encendidaEnElSistema, isTrue);
    });

    test('una llamada que falla no frena las siguientes', () async {
      var falla = true;
      final enviados = simular(
        fallo: () => falla ? PlatformException(code: 'x') : null,
      );
      final p = PantallaEncendidaAndroid();
      final a = p.pedir();
      await p.aplicado;
      falla = false;
      a();
      p.pedir();
      await p.aplicado;
      expect(enviados, [true]);
    });
  });

  group('fuera de Android', () {
    test('la nula no hace nada y lo dice', () async {
      const p = PantallaEncendidaNula();
      expect(p.disponible, isFalse);
      expect(await p.mantener(true), isFalse);
      expect(await p.mantener(false), isFalse);
      p.pedir()();
    });

    test('el proveedor entrega la nula si el arranque no pone otra', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(pantallaEncendidaProvider), isA<PantallaEncendidaNula>());
    });
  });

  group('lo que no debe cambiar', () {
    final actividad = File(
      'android/app/src/main/kotlin/mx/segundocerebro/gravity/MainActivity.kt',
    ).readAsStringSync();

    test('MainActivity atiende el mismo canal y método que Dart', () {
      expect(
        actividad,
        contains('"${PantallaEncendidaAndroid.canalDelSistema}"'),
      );
      expect(actividad, contains('"encendida"'));
      expect(actividad, contains('FLAG_KEEP_SCREEN_ON'));
      expect(actividad, contains('window.addFlags'));
      expect(actividad, contains('window.clearFlags'));
      expect(actividad, contains('runOnUiThread'));
    });

    test('MainActivity suelta la bandera al destruirse', () {
      expect(actividad, contains('override fun onDestroy()'));
      final cuerpo = actividad.substring(actividad.indexOf('onDestroy()'));
      expect(
        cuerpo.substring(0, cuerpo.indexOf('}')),
        contains('FLAG_KEEP_SCREEN_ON'),
      );
    });

    test('FLAG_SECURE sigue en su canal, sin mezclarse', () {
      expect(actividad, contains('mx.segundocerebro.gravity/pantalla_segura'));
      expect(actividad, contains('FLAG_SECURE'));
    });

    test('el manifiesto no gana permisos de pantalla (ni WAKE_LOCK)', () {
      final manifiesto = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(manifiesto, isNot(contains('WAKE_LOCK')));
      expect(manifiesto, isNot(contains('DISABLE_KEYGUARD')));
      expect(manifiesto, isNot(contains('WRITE_SETTINGS')));
      final permisos = RegExp(
        r'uses-permission android:name="android\.permission\.(\w+)"',
      ).allMatches(manifiesto).map((m) => m.group(1)).toSet();
      // La lista de hoy: si crece, que sea una decisión, no un descuido.
      expect(permisos, {
        'INTERNET',
        'USE_BIOMETRIC',
        'POST_NOTIFICATIONS',
        'RECEIVE_BOOT_COMPLETED',
        'VIBRATE',
        'CAMERA',
        'RECORD_AUDIO',
      });
    });

    test('pubspec.yaml y pubspec.lock no traen paquetes de pantalla', () {
      for (final archivo in ['pubspec.yaml', 'pubspec.lock']) {
        final texto = File(archivo).readAsStringSync().toLowerCase();
        for (final p in [
          'wakelock',
          'screen_brightness',
          'keep_screen_on',
          'screen_state',
          'flutter_window',
        ]) {
          expect(texto, isNot(contains(p)), reason: '$archivo no debe traer $p');
        }
      }
    });
  });
}
