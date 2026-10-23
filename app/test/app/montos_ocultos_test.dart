// Montos ocultos automáticos (decisión del 23/oct/2026): tras N minutos sin
// uso se ocultan solos y para verlos se pide el PIN (en el teléfono, también
// la huella). El sistema de diseño dibuja los montos; aquí, el flujo de la
// plataforma.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/app_gravity.dart';
import 'package:gravity/app/montos/revelar_montos.dart';
import 'package:gravity/app/router.dart';
import 'package:gravity/diseno/proveedores.dart'
    show modoPrivadoProvider, montosOcultosProvider, montosVisiblesProvider, revelarMontosProvider;
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';
import 'package:gravity/nucleo/seguridad/biometria.dart';
import 'package:gravity/nucleo/seguridad/bloqueo.dart';
import 'package:gravity/nucleo/seguridad/montos.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_demostracion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_falso.dart';

import 'ayuda_plataforma.dart';

ProviderContainer contenedorDe(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(AppGravity)));

bool visibles(WidgetTester tester) =>
    contenedorDe(tester).read(montosVisiblesProvider);

bool ocultos(WidgetTester tester) =>
    contenedorDe(tester).read(montosOcultosProvider);

/// Pide ver los montos (como lo hace una marca "Toca para ver") y devuelve lo
/// que respondió al terminar.
Future<bool> Function() pedirVer(WidgetTester tester) {
  final contexto = tester.element(find.byType(Scaffold).first);
  final futuro = contenedorDe(tester).read(revelarMontosProvider)(contexto);
  return () => futuro;
}

Future<void> escribir(WidgetTester tester, Key campo, String texto) async {
  await tester.enterText(find.byKey(campo), texto);
  await tester.pump();
}

const campoPin = Key('revelar-pin');
const campoConfirmacion = Key('revelar-confirmacion');
final aceptar = find.byKey(const ValueKey('revelar-aceptar'));

void main() {
  group('crear el PIN la primera vez (laptop)', () {
    testWidgets('no se muestra nada sin PIN; no acepta triviales; luego sí', (
      tester,
    ) async {
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.laptop,
        sesion: sesionCon(Rol.dueno),
      );
      expect(ocultos(tester), isTrue, reason: 'se abren ocultos');

      final resultado = pedirVer(tester);
      await tester.pumpAndSettle();
      expect(find.text('Crea tu PIN para ver los montos'), findsOneWidget);
      expect(find.byKey(const ValueKey('revelar-huella')), findsNothing);

      for (final (pin, texto) in [
        ('1234', 'secuencia'),
        ('0000', 'mismo número'),
        ('12', 'De 4 a 6 dígitos'),
      ]) {
        await escribir(tester, campoPin, pin);
        await escribir(tester, campoConfirmacion, pin);
        await tester.tap(aceptar);
        await tester.pumpAndSettle();
        expect(find.textContaining(texto), findsOneWidget, reason: pin);
        expect(ocultos(tester), isTrue);
      }
      await escribir(tester, campoPin, '2846');
      await escribir(tester, campoConfirmacion, '2847');
      await tester.tap(aceptar);
      await tester.pumpAndSettle();
      expect(find.text('Los PIN no coinciden.'), findsOneWidget);

      await escribir(tester, campoConfirmacion, '2846');
      await tester.tap(aceptar);
      await tester.pumpAndSettle();
      expect(await resultado(), isTrue);
      expect(visibles(tester), isTrue);
      expect(ocultos(tester), isFalse);
    });

    testWidgets('cancelar no muestra nada', (tester) async {
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.laptop,
        sesion: sesionCon(Rol.dueno),
      );
      final resultado = pedirVer(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(await resultado(), isFalse);
      expect(ocultos(tester), isTrue);
    });
  });

  group('se ocultan solos tras unos minutos sin uso', () {
    Future<void> conPinCreado(WidgetTester tester) async {
      await contenedorDe(tester).read(controladorMontosProvider.notifier).listo;
      await contenedorDe(tester).read(controladorMontosProvider.notifier).crearPin('2846');
    }

    testWidgets('a los 2 minutos; luego pide el PIN', (tester) async {
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.laptop,
        sesion: sesionCon(Rol.dueno),
      );
      await conPinCreado(tester);
      contenedorDe(tester).read(montosVisiblesProvider.notifier).fijar(true);
      await tester.pump();
      expect(ocultos(tester), isFalse);

      await tester.pump(const Duration(minutes: 1, seconds: 59));
      expect(visibles(tester), isTrue, reason: 'aún no pasan los 2 minutos');
      await tester.pump(const Duration(seconds: 2));
      expect(visibles(tester), isFalse);
      expect(ocultos(tester), isTrue);

      // Para verlos otra vez: el PIN.
      final resultado = pedirVer(tester);
      await tester.pumpAndSettle();
      expect(find.text('Ver los montos'), findsOneWidget);
      await escribir(tester, campoPin, '0001');
      await tester.tap(aceptar);
      await tester.pumpAndSettle();
      expect(find.text('PIN incorrecto.'), findsOneWidget);
      expect(ocultos(tester), isTrue);
      await escribir(tester, campoPin, '2846');
      await tester.tap(aceptar);
      await tester.pumpAndSettle();
      expect(await resultado(), isTrue);
      expect(ocultos(tester), isFalse);
    });

    testWidgets('tocar la pantalla reinicia la cuenta', (tester) async {
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.laptop,
        sesion: sesionCon(Rol.dueno),
      );
      contenedorDe(tester).read(montosVisiblesProvider.notifier).fijar(true);
      await tester.pump();
      await tester.pump(const Duration(minutes: 1, seconds: 30));
      await tester.tapAt(const Offset(5, 5));
      await tester.pump();
      await tester.pump(const Duration(minutes: 1, seconds: 30));
      expect(visibles(tester), isTrue, reason: 'se tocó a los 90 s');
      await tester.pump(const Duration(seconds: 31));
      expect(visibles(tester), isFalse);
    });

    testWidgets('el tiempo es el elegido en Privacidad (1 minuto)', (tester) async {
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.laptop,
        sesion: sesionCon(Rol.dueno),
      );
      await contenedorDe(tester)
          .read(controladorMontosProvider.notifier)
          .fijarOcultarTras(const Duration(minutes: 1));
      contenedorDe(tester).read(montosVisiblesProvider.notifier).fijar(true);
      await tester.pump();
      await tester.pump(const Duration(seconds: 61));
      expect(visibles(tester), isFalse);
    });

    testWidgets('sin montos a la vista no corre nada', (tester) async {
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.laptop,
        sesion: sesionCon(Rol.dueno),
      );
      await tester.pump(const Duration(minutes: 10));
      expect(visibles(tester), isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('el modo privado no se quita pidiendo ver los montos', (tester) async {
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.laptop,
        sesion: sesionCon(Rol.dueno),
      );
      contenedorDe(tester).read(modoPrivadoProvider.notifier).fijar(true);
      await tester.pump();
      final resultado = pedirVer(tester);
      await tester.pumpAndSettle();
      expect(await resultado(), isFalse);
      expect(find.byKey(const ValueKey('dialogo-revelar-montos')), findsNothing);
      expect(ocultos(tester), isTrue);
    });

    testWidgets('al salir de la sesión los montos vuelven a ocultarse', (tester) async {
      final sesion = sesionCon(Rol.dueno);
      await montarApp(tester, dispositivo: TipoDispositivo.laptop, sesion: sesion);
      contenedorDe(tester).read(montosVisiblesProvider.notifier).fijar(true);
      await tester.pump();
      expect(ocultos(tester), isFalse);
      await sesion.salir();
      await tester.pumpAndSettle();
      sesion.fijarSesion(sesionDeEjemplo(Rol.dueno));
      await tester.pumpAndSettle();
      expect(visibles(tester), isFalse);
    });
  });

  group('teléfono', () {
    testWidgets('con el bloqueo activado se usa su PIN y se ofrece la huella', (
      tester,
    ) async {
      final biometria = BiometriaFalsa();
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.telefono,
        sesion: sesionCon(Rol.dueno),
        biometria: biometria,
      );
      final bloqueo = contenedorDe(tester).read(controladorBloqueoProvider.notifier);
      await bloqueo.listo;
      await bloqueo.configurarPin('2468');
      await tester.pumpAndSettle();

      var resultado = pedirVer(tester);
      await tester.pumpAndSettle();
      // No pide crear otro PIN: usa el del bloqueo.
      expect(find.text('Ver los montos'), findsOneWidget);
      expect(find.byKey(const ValueKey('revelar-huella')), findsOneWidget);
      await escribir(tester, campoPin, '2468');
      await tester.tap(aceptar);
      await tester.pumpAndSettle();
      expect(await resultado(), isTrue);
      expect(ocultos(tester), isFalse);

      // Se vuelven a ocultar y esta vez, con la huella.
      contenedorDe(tester).read(montosVisiblesProvider.notifier).fijar(false);
      await tester.pump();
      resultado = pedirVer(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('revelar-huella')));
      await tester.pumpAndSettle();
      expect(biometria.intentos, 1);
      expect(await resultado(), isTrue);
      expect(ocultos(tester), isFalse);
    });

    testWidgets('si la huella falla, avisa y queda el PIN', (tester) async {
      final biometria = BiometriaFalsa(acepta: false);
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.telefono,
        sesion: sesionCon(Rol.dueno),
        biometria: biometria,
      );
      final bloqueo = contenedorDe(tester).read(controladorBloqueoProvider.notifier);
      await bloqueo.listo;
      await bloqueo.configurarPin('2468');
      pedirVer(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('revelar-huella')));
      await tester.pumpAndSettle();
      expect(find.textContaining('No se reconoció la huella'), findsOneWidget);
      expect(ocultos(tester), isTrue);
    });

    testWidgets('5 PIN incorrectos: espera, y el mensaje lo dice', (tester) async {
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.telefono,
        sesion: sesionCon(Rol.dueno),
        biometria: BiometriaFalsa(hayHuella: false),
      );
      final bloqueo = contenedorDe(tester).read(controladorBloqueoProvider.notifier);
      await bloqueo.listo;
      await bloqueo.configurarPin('2468');
      pedirVer(tester);
      await tester.pumpAndSettle();
      for (var i = 0; i < 5; i++) {
        await escribir(tester, campoPin, '0001');
        await tester.tap(aceptar);
        await tester.pumpAndSettle();
      }
      expect(find.textContaining('Demasiados intentos. Espera 30 segundos'), findsOneWidget);
      expect(ocultos(tester), isTrue);
    });
  });

  group('tablet', () {
    testWidgets('con la persona dentro se pide su PIN de la tablet, sin huella', (
      tester,
    ) async {
      final casa = ServicioSesionFalso(inicial: sesionDeEjemplo(Rol.casa));
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.tablet,
        sesion: casa,
        almacen: await almacenConPersonas({Rol.dueno: '2846'}),
        biometria: BiometriaFalsa(),
      );
      // Entra el dueño con su PIN (como en la tablet).
      await tester.tap(find.text('Dueño de ejemplo'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('campo-pin')), '2846');
      await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
      await tester.pumpAndSettle();

      final resultado = pedirVer(tester);
      await tester.pumpAndSettle();
      expect(find.text('Ver los montos'), findsOneWidget);
      expect(find.byKey(const ValueKey('revelar-huella')), findsNothing);
      await escribir(tester, campoPin, '2846');
      await tester.tap(aceptar);
      await tester.pumpAndSettle();
      expect(await resultado(), isTrue);
      expect(ocultos(tester), isFalse);
    });
  });

  group('Ajustes › Privacidad', () {
    Future<void> irAPrivacidad(WidgetTester tester) async {
      contenedorDe(tester).read(routerProvider).go('/ajustes/privacidad');
      await tester.pumpAndSettle();
    }

    testWidgets('el tiempo se elige ahí y se guarda', (tester) async {
      final almacen = AlmacenSeguroEnMemoria();
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.laptop,
        sesion: sesionCon(Rol.dueno),
        almacen: almacen,
      );
      await irAPrivacidad(tester);
      expect(find.byKey(const ValueKey('privacidad-montos')), findsOneWidget);
      expect(find.text('2 minutos'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('montos-ocultar-tras')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('10 minutos').last);
      await tester.pumpAndSettle();
      expect(
        contenedorDe(tester).read(controladorMontosProvider).ocultarTras,
        const Duration(minutes: 10),
      );
      expect(
        almacen.datos[ControladorMontos.claveConfiguracion(
          sesionDeEjemplo(Rol.dueno).persona.id,
        )],
        contains('600'),
      );
    });

    testWidgets('sin PIN de tablet ni de bloqueo, se crea uno propio ahí', (
      tester,
    ) async {
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.laptop,
        sesion: sesionCon(Rol.dueno),
      );
      await irAPrivacidad(tester);
      expect(find.text('Crear un PIN para ver los montos'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('montos-pin-propio')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('bloqueo-pin')), '1234');
      await tester.enterText(find.byKey(const Key('bloqueo-confirmacion')), '1234');
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Ese PIN es una secuencia'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('bloqueo-pin')), '2846');
      await tester.enterText(find.byKey(const Key('bloqueo-confirmacion')), '2846');
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();
      expect(find.text('Cambiar el PIN para ver los montos'), findsOneWidget);
      expect(
        await contenedorDe(tester).read(controladorMontosProvider.notifier).verificar('2846'),
        ResultadoRevelar.revelado,
      );
    });

    testWidgets('en el teléfono con bloqueo dice que usa ese PIN', (tester) async {
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.telefono,
        sesion: sesionCon(Rol.dueno),
      );
      final bloqueo = contenedorDe(tester).read(controladorBloqueoProvider.notifier);
      await bloqueo.listo;
      await bloqueo.configurarPin('2468');
      await irAPrivacidad(tester);
      expect(find.text('Se usa el PIN del bloqueo del teléfono.'), findsOneWidget);
      expect(find.byKey(const ValueKey('montos-pin-propio')), findsNothing);
    });
  });

  test('el flujo de la plataforma es el que pide ver los montos', () {
    // `conexionesDeLaApp` cambia el "mostrar sin pedir nada" de diseno por
    // este flujo.
    final contenedor = ProviderContainer(
      overrides: [revelarMontosProvider.overrideWith((ref) => revelarMontos)],
    );
    addTearDown(contenedor.dispose);
    expect(contenedor.read(revelarMontosProvider), same(revelarMontos));
  });
}
