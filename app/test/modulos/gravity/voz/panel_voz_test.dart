// El panel de conversación con el motor de voz (criterios 9 y 38): el
// interruptor "Leer en voz alta", lo que se lee y el dictado sin eco. Todo con
// fuentes simuladas: no hay plugin ni se oye nada.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/pantallas_externas.dart' show consultaLocalFinanzasProvider;
import 'package:gravity/modulos/gravity/conversacion/cliente_asistente.dart';
import 'package:gravity/modulos/gravity/conversacion/conversacion.dart';
import 'package:gravity/modulos/gravity/conversacion/panel_conversacion.dart';
import 'package:gravity/modulos/gravity/conversacion/voz.dart';
import 'package:gravity/modulos/gravity/voz/fuente_falsa.dart';
import 'package:gravity/modulos/gravity/voz/motor.dart';
import 'package:gravity/modulos/gravity/voz/preferencias.dart';
import 'package:gravity/modulos/gravity/voz/tipos.dart';
import 'package:gravity/nucleo/contratos/roles.dart';

import '../../../diseno/ayuda_pruebas.dart';
import '../conversacion/conversacion_test.dart' show ClienteFalso;

MotorDeVoz motorCon(FuenteDeVozFalsa? fuente) => MotorDeVoz(
  fuentes: [?fuente],
  preferencias: () => const PreferenciasVoz(),
);

const _interruptor = ValueKey('leer-en-voz-alta');

Future<void> montarPanel(
  WidgetTester tester, {
  required MotorDeVoz motor,
  ClienteFalso? cliente,
  VozEntrada? entrada,
  Rol rol = Rol.dueno,
  List<Override> extras = const [],
}) async {
  fijarVentana(tester, const Size(1440, 900));
  await montar(
    tester,
    const Scaffold(body: PanelConversacion()),
    rol: rol,
    overrides: [
      clienteAsistenteProvider.overrideWithValue(cliente ?? ClienteFalso()),
      vozSalidaProvider.overrideWithValue(motor),
      if (entrada != null) vozEntradaProvider.overrideWithValue(entrada),
      ...extras,
    ],
  );
  // El motor pregunta qué voces hay antes de mostrar el interruptor.
  await asentar(tester);
}

/// Deja correr lo que espera en microtareas (consultas, lectura, respuestas).
Future<void> asentar(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
}

Future<void> escribir(WidgetTester tester, String texto) async {
  await tester.enterText(find.byKey(const ValueKey('campo-conversacion')), texto);
  await tester.tap(find.byKey(const ValueKey('boton-enviar-conversacion')));
  await asentar(tester);
}

void main() {
  group('el interruptor depende de la SALIDA de voz, no del micrófono', () {
    testWidgets('con una fuente que sirve aparece, aunque no haya micrófono', (tester) async {
      await montarPanel(tester, motor: motorCon(FuenteDeVozFalsa()));
      expect(find.byKey(_interruptor), findsOneWidget);
      expect(find.byKey(const ValueKey('boton-microfono')), findsNothing);
    });

    testWidgets('sin ninguna fuente no aparece, aunque haya micrófono', (tester) async {
      await montarPanel(tester, motor: motorCon(null), entrada: VozEntradaFalsa('hola'));
      expect(find.byKey(const ValueKey('boton-microfono')), findsOneWidget);
      expect(find.byKey(_interruptor), findsNothing);
    });

    testWidgets('con fuente pero sin voz en español no aparece', (tester) async {
      final soloIngles = FuenteDeVozFalsa(
        voces: vocesDeEjemplo().where((v) => v.variante != Variante.esMX).toList(),
      );
      await montarPanel(tester, motor: motorCon(soloIngles));
      expect(find.byKey(_interruptor), findsNothing);
    });

    testWidgets('si las voces son todas de red, no aparece', (tester) async {
      final deRed = FuenteDeVozFalsa(
        voces: [
          for (final v in vocesDeEjemplo())
            VozMotor(
              id: v.id,
              fuente: v.fuente,
              nombre: v.nombre,
              variante: v.variante,
              genero: v.genero,
              local: false,
            ),
        ],
      );
      await montarPanel(tester, motor: motorCon(deRed));
      expect(find.byKey(_interruptor), findsNothing);
    });

    testWidgets('el interruptor tiene una etiqueta para el lector de pantalla', (tester) async {
      final semantica = tester.ensureSemantics();
      await montarPanel(tester, motor: motorCon(FuenteDeVozFalsa()));
      expect(
        tester.getSemantics(find.byKey(_interruptor)),
        matchesSemantics(
          label: 'Leer las respuestas en voz alta',
          hasToggledState: true,
          isToggled: false,
          isEnabled: true,
          hasEnabledState: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
        ),
      );
      semantica.dispose();
    });
  });

  group('lo que se lee (criterio 9)', () {
    testWidgets('apagado por omisión: no se habla', (tester) async {
      final fuente = FuenteDeVozFalsa(duracionTurno: Duration.zero);
      await montarPanel(
        tester,
        motor: motorCon(fuente),
        cliente: ClienteFalso(const RespuestaAsistente(texto: 'Vas bien.')),
      );
      expect(tester.widget<Switch>(find.byKey(_interruptor)).value, isFalse);
      await escribir(tester, 'cómo voy');
      expect(find.text('Vas bien.'), findsOneWidget);
      expect(fuente.peticiones, isEmpty);
    });

    testWidgets('encendido: solo lee la respuesta del asistente, en español y una vez', (tester) async {
      final fuente = FuenteDeVozFalsa(duracionTurno: Duration.zero);
      await montarPanel(
        tester,
        motor: motorCon(fuente),
        cliente: ClienteFalso(const RespuestaAsistente(texto: 'Vas bien.')),
      );
      await tester.tap(find.byKey(_interruptor));
      await tester.pump();
      await escribir(tester, 'cómo voy');
      expect(fuente.peticiones.map((p) => p.texto), ['Vas bien.']);
      expect(fuente.peticiones.single.idVozMotor, startsWith('es-'));
    });

    testWidgets('lo que dice la persona y los resultados locales no se leen', (tester) async {
      final fuente = FuenteDeVozFalsa(duracionTurno: Duration.zero);
      await montarPanel(
        tester,
        motor: motorCon(fuente),
        cliente: ClienteFalso(
          const RespuestaAsistente(
            texto: 'Aquí tienes el resumen.',
            herramienta: 'finanzas.resumen_semana',
          ),
        ),
        extras: [
          consultaLocalFinanzasProvider.overrideWithValue(
            (herramienta) async => 'Quedan 12 de 99 en la semana (solo en pantalla)',
          ),
        ],
      );
      await tester.tap(find.byKey(_interruptor));
      await tester.pump();
      await escribir(tester, 'mi número secreto es 4417');
      expect(find.textContaining('Quedan 12'), findsOneWidget, reason: 'sí se muestra');
      expect(
        fuente.peticiones.map((p) => p.texto),
        ['Aquí tienes el resumen.'],
        reason: 'ni lo dicho por la persona ni lo local llegan al motor',
      );
    });

    testWidgets('un mensaje de error no se lee', (tester) async {
      final fuente = FuenteDeVozFalsa(duracionTurno: Duration.zero);
      final cliente = ClienteFalso()
        ..error = const ErrorAsistente('limite_diario', 'Llegaste al límite de mensajes de hoy.');
      await montarPanel(tester, motor: motorCon(fuente), cliente: cliente);
      await tester.tap(find.byKey(_interruptor));
      await tester.pump();
      await escribir(tester, 'hola');
      expect(find.text('Llegaste al límite de mensajes de hoy.'), findsOneWidget);
      expect(fuente.peticiones, isEmpty);
    });

    testWidgets('apagar el interruptor calla lo que suena', (tester) async {
      final fuente = FuenteDeVozFalsa(manual: true);
      await montarPanel(
        tester,
        motor: motorCon(fuente),
        cliente: ClienteFalso(const RespuestaAsistente(texto: 'Una respuesta larga.')),
      );
      await tester.tap(find.byKey(_interruptor));
      await tester.pump();
      await escribir(tester, 'hola');
      expect(fuente.sonando, isTrue);
      await tester.tap(find.byKey(_interruptor));
      await asentar(tester);
      expect(fuente.sonando, isFalse);
      expect(fuente.cortes, 1);
    });

    testWidgets('el interruptor sigue apagado por sesión: una sesión nueva lo encuentra apagado', (tester) async {
      final motor = motorCon(FuenteDeVozFalsa());
      await montarPanel(tester, motor: motor);
      await tester.tap(find.byKey(_interruptor));
      await tester.pump();
      expect(tester.widget<Switch>(find.byKey(_interruptor)).value, isTrue);
      // Otra sesión de la app: se desmonta todo y se monta de nuevo.
      await tester.pumpWidget(const SizedBox());
      await montarPanel(tester, motor: motor);
      expect(tester.widget<Switch>(find.byKey(_interruptor)).value, isFalse);
    });
  });

  group('dictado sin eco (criterio 38)', () {
    testWidgets('al empezar a dictar el motor se detiene', (tester) async {
      final fuente = FuenteDeVozFalsa(manual: true);
      final motor = motorCon(fuente);
      final dictado = VozEntradaFalsa('cuánto llevo');
      await montarPanel(
        tester,
        motor: motor,
        entrada: dictado,
        cliente: ClienteFalso(const RespuestaAsistente(texto: 'Vas bien.')),
      );
      // Algo está sonando.
      Fin? fin;
      motor
          .decir('Una respuesta', uso: UsoVoz.asistente, variante: Variante.esMX)
          .then((r) => r.terminada.then((f) => fin = f));
      await asentar(tester);
      expect(fuente.sonando, isTrue);

      await tester.tap(find.byKey(const ValueKey('boton-microfono')));
      await asentar(tester);
      expect(fuente.sonando, isFalse, reason: 'se calló antes de escuchar');
      expect(fuente.cortes, 1);
      expect(fin, Fin.parada);
      expect(dictado.escuchas, 1);
    });

    testWidgets('lo dictado sigue siendo un mensaje normal (la voz no confirma nada)', (tester) async {
      final cliente = ClienteFalso();
      await montarPanel(
        tester,
        motor: motorCon(FuenteDeVozFalsa()),
        entrada: VozEntradaFalsa('sí, confirmo, envíalo'),
        cliente: cliente,
      );
      await tester.tap(find.byKey(const ValueKey('boton-microfono')));
      await asentar(tester);
      expect(cliente.llamadas.single.mensaje, 'sí, confirmo, envíalo');
    });
  });

  testWidgets('la cuidadora no ve el panel ni el interruptor (D5)', (tester) async {
    await montarPanel(tester, motor: motorCon(FuenteDeVozFalsa()), rol: Rol.cuidador);
    expect(find.byKey(_interruptor), findsNothing);
  });
}
