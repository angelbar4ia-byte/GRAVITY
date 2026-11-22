// Ajustes › Voz con la voz real del dispositivo (motor de voz, P3.2a-1):
// estado honesto, elegir voz y velocidad, probar una frase y lo que falta
// ("próximamente"). Todo con una fuente simulada: no hay plugin ni se oye nada.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/router.dart' show routerProvider;
import 'package:gravity/modulos/ajustes/voz/pantalla_voz.dart';
import 'package:gravity/modulos/ajustes/voz/prueba_voz.dart';
import 'package:gravity/modulos/gravity/voz/fuente_falsa.dart';
import 'package:gravity/modulos/gravity/voz/preferencias.dart';
import 'package:gravity/modulos/gravity/voz/proveedores.dart';
import 'package:gravity/modulos/gravity/voz/tipos.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/contratos/rutas.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_demostracion.dart'
    show hogarDeEjemplo;
import 'package:gravity/nucleo/sesion/servicio_sesion_falso.dart';
import 'package:gravity/nucleo/sesion/sesion.dart';

import '../../../app/ayuda_plataforma.dart';
import '../../../diseno/ayuda_pruebas.dart'
    show fijarEscalaDeLetra, recolectarDesbordes;

VozMotor voz(String id, Variante v, Genero g, {bool local = true}) => VozMotor(
  id: id,
  fuente: Fuente.dispositivo,
  nombre: 'Voz $id',
  variante: v,
  genero: g,
  local: local,
  locale: v.etiqueta,
);

Future<void> abrirVoz(
  WidgetTester tester, {
  FuenteDeVozFalsa? fuente,
  Rol rol = Rol.dueno,
  TipoDispositivo dispositivo = TipoDispositivo.laptop,
  List<Override> extras = const [],
  Size? ventana,
}) async {
  await montarApp(
    tester,
    dispositivo: dispositivo,
    sesion: sesionCon(rol),
    extras: [
      if (fuente != null) fuentesDeVozProvider.overrideWithValue([fuente]),
      ...extras,
    ],
  );
  tester.view.physicalSize = ventana ?? const Size(1280, 4200);
  tester.view.devicePixelRatio = 1;
  final c = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
  c.read(routerProvider).go('${Rutas.ajustes}/voz');
  await tester.pumpAndSettle();
}

ProviderContainer contenedor(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(PantallaVoz)));

Future<void> asentar(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
}

Finder k(String clave) => find.byKey(ValueKey(clave));

String textoDe(WidgetTester tester, String clave) =>
    tester.widget<Text>(k(clave)).data!;

void main() {
  group('sin voz en el equipo', () {
    testWidgets('dice con honestidad que la voz aún no está y no ofrece nada que no hay', (tester) async {
      await abrirVoz(tester);
      expect(find.byType(PantallaVoz), findsOneWidget);
      expect(find.textContaining('La voz todavía no está disponible'), findsOneWidget);
      expect(find.textContaining('puedes escribirle a GRAVITY'), findsOneWidget);
      expect(find.textContaining('llega en la Fase'), findsNothing);
      expect(k('voz-asistente'), findsNothing);
      expect(k('voz-curso'), findsNothing);
      expect(k('voz-otras'), findsNothing);
      // Lo de las bocinas y la privacidad sigue a la vista.
      expect(find.textContaining('Por las bocinas de la casa nunca se dicen'), findsOneWidget);
      expect(find.textContaining('nunca montos de dinero ni datos de salud'), findsOneWidget);
    });

    testWidgets('el equipo tiene la fuente pero no un motor de voz que responda', (tester) async {
      final f = FuenteDeVozFalsa()
        ..errorAlListar = const FalloDeSintesis(Fuente.dispositivo, 'sin_motor_de_voz');
      await abrirVoz(tester, fuente: f);
      expect(find.textContaining('no tiene un motor de texto a voz que responda'), findsOneWidget);
      expect(find.textContaining('Salida de texto a voz'), findsOneWidget);
      expect(k('voz-asistente'), findsNothing);
    });
  });

  group('estado de lo que hay en el equipo', () {
    testWidgets('cuenta las voces locales y avisa de las que se dejaron fuera', (tester) async {
      final f = FuenteDeVozFalsa(
        voces: [
          voz('es-1', Variante.esMX, Genero.sinDato),
          voz('es-2', Variante.esMX, Genero.sinDato),
          voz('es-red', Variante.esMX, Genero.sinDato, local: false),
          for (var i = 0; i < 3; i++) voz('us-$i', Variante.enUS, Genero.sinDato),
          voz('gb-1', Variante.enGB, Genero.sinDato),
        ],
      );
      await abrirVoz(tester, fuente: f);
      expect(textoDe(tester, 'voz-estado-espanol'), 'En español: 2 voces.');
      expect(
        textoDe(tester, 'voz-estado-ingles'),
        'En inglés: 4 voces (americano 3, británico 1).',
      );
      expect(textoDe(tester, 'voz-estado-red'), 'Se dejaron fuera 1 voz que necesitan conexión.');
      expect(k('voz-como-instalar'), findsNothing);
    });

    testWidgets('sin voces en inglés dice cómo instalar una, sin prometer una ruta exacta', (tester) async {
      final f = FuenteDeVozFalsa(voces: [voz('es-1', Variante.esMX, Genero.sinDato)]);
      await abrirVoz(tester, fuente: f);
      expect(
        textoDe(tester, 'voz-estado-ingles'),
        'En inglés: no hay ninguna voz que funcione sin conexión.',
      );
      expect(k('voz-como-instalar'), findsOneWidget);
      expect(textoDe(tester, 'voz-como-instalar'), contains('La ruta exacta cambia'));
      expect(k('voz-curso-sin-ingles'), findsOneWidget);
    });

    testWidgets('Actualizar vuelve a preguntar al sistema', (tester) async {
      final f = FuenteDeVozFalsa();
      await abrirVoz(tester, fuente: f);
      await tester.tap(k('voz-actualizar'));
      await tester.pumpAndSettle();
      expect(f.refrescos, 1);
    });

    testWidgets('Otras voces: próximamente, sin prometer fecha', (tester) async {
      await abrirVoz(tester, fuente: FuenteDeVozFalsa());
      expect(k('voz-otras'), findsOneWidget);
      final texto = textoVisible(tester);
      expect(texto, contains('voz descargada · próximamente'));
      expect(texto, contains('audio pregrabado del curso · próximamente'));
      for (final prohibida in ['fase ', 'llega en', RegExp(r'\b2026\b'), RegExp(r'\bsemana')]) {
        expect(texto, isNot(contains(prohibida)), reason: '$prohibida');
      }
    });

    testWidgets('Detalles técnicos muestra cada voz con su red y calidad', (tester) async {
      final f = FuenteDeVozFalsa(
        voces: [
          voz('es-1', Variante.esMX, Genero.mujer),
          voz('es-red', Variante.esMX, Genero.sinDato, local: false),
        ],
      );
      await abrirVoz(tester, fuente: f);
      await tester.tap(find.text('Detalles técnicos'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Voces que reporta el sistema: 2.'), findsOneWidget);
      expect(find.textContaining('Voz es-red · es-MX'), findsOneWidget);
      expect(find.textContaining('necesita red'), findsOneWidget);
      expect(find.textContaining('sin red · mujer'), findsOneWidget, reason: 'el género, si se sabe');
    });
  });

  group('voz y velocidad del asistente', () {
    testWidgets('elegir otra voz la guarda y es la que suena', (tester) async {
      final f = FuenteDeVozFalsa(duracionTurno: Duration.zero);
      await abrirVoz(tester, fuente: f);
      expect(textoDe(tester, 'voz-asistente-fila-voz'), 'Voz es-1 · es-MX');

      await tester.tap(k('voz-asistente-fila-cambiar'));
      await tester.pumpAndSettle();
      expect(k('voz-elegir'), findsOneWidget);
      expect(find.byKey(const ValueKey('voz-opcion-es-1')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('voz-opcion-es-3')));
      await tester.pumpAndSettle();
      expect(textoDe(tester, 'voz-asistente-fila-voz'), 'Voz es-3 · es-MX');
      expect(
        contenedor(tester)
            .read(preferenciasVozProvider)
            .asignacionDe(Fuente.dispositivo, Variante.esMX),
        {VozDeGuion.f1: 'es-3'},
      );

      await tester.tap(k('voz-asistente-fila-probar'));
      await asentar(tester);
      expect(f.peticiones, hasLength(1));
      expect(f.peticiones.single.idVozMotor, 'es-3');
      expect(f.peticiones.single.texto, fraseDePruebaEnEspanol);
      await tester.pumpAndSettle();
      expect(textoDe(tester, 'voz-asistente-fila-mensaje'), 'Sonó con: Voz del dispositivo · Voz es-3');
    });

    testWidgets('Probar usa la velocidad elegida y muestra qué voz suena mientras suena', (tester) async {
      final f = FuenteDeVozFalsa(manual: true);
      await abrirVoz(tester, fuente: f);
      contenedor(tester).read(preferenciasVozProvider.notifier).fijarVelocidad(UsoVoz.asistente, 0.8);
      await tester.pumpAndSettle();
      expect(textoDe(tester, 'voz-velocidad-texto'), 'Velocidad: 0.8 (1.0 es la normal)');

      await tester.tap(k('voz-asistente-fila-probar'));
      await asentar(tester);
      expect(f.peticiones.single.velocidad, closeTo(0.8, 1e-9));
      expect(textoDe(tester, 'voz-asistente-fila-mensaje'), 'Suena con: Voz del dispositivo · Voz es-1');
      expect(k('voz-asistente-fila-parar'), findsOneWidget);

      await tester.tap(k('voz-asistente-fila-parar'));
      await asentar(tester);
      expect(f.sonando, isFalse);
      expect(k('voz-asistente-fila-parar'), findsNothing);
    });

    testWidgets('el control de velocidad guarda lo que se mueve', (tester) async {
      await abrirVoz(tester, fuente: FuenteDeVozFalsa());
      final slider = k('voz-velocidad');
      expect(tester.widget<Slider>(slider).value, 1.0);
      await tester.drag(slider, const Offset(-150, 0));
      await tester.pumpAndSettle();
      final guardada = contenedor(tester).read(preferenciasVozProvider).asistente.velocidad;
      expect(guardada, lessThan(1.0));
      expect(guardada, greaterThanOrEqualTo(velocidadVozMinima));
      expect(textoDe(tester, 'voz-velocidad-texto'), startsWith('Velocidad: ${guardada.toStringAsFixed(1)}'));
    });

    testWidgets('el control de velocidad se anuncia con su valor y su referencia', (tester) async {
      await abrirVoz(tester, fuente: FuenteDeVozFalsa());
      final slider = tester.widget<Slider>(k('voz-velocidad'));
      expect(slider.semanticFormatterCallback!(0.8), 'Velocidad 0.8, 1.0 es la normal');
      expect(slider.min, velocidadVozMinima);
      expect(slider.max, velocidadVozMaxima);
    });

    testWidgets('sin voz en español no hay sección del asistente', (tester) async {
      final f = FuenteDeVozFalsa(voces: [voz('us-1', Variante.enUS, Genero.mujer)]);
      await abrirVoz(tester, fuente: f);
      expect(k('voz-asistente'), findsNothing);
      expect(textoDe(tester, 'voz-estado-espanol'), contains('no hay ninguna voz'));
    });
  });

  group('voces del curso de inglés', () {
    testWidgets('cinco papeles por acento, con la propuesta por género', (tester) async {
      await abrirVoz(tester, fuente: FuenteDeVozFalsa());
      expect(k('voz-acento-en-US'), findsOneWidget);
      expect(k('voz-acento-en-GB'), findsOneWidget);
      expect(textoDe(tester, 'voz-en-US-F1-voz'), 'Voz us-mujer-1 · en-US');
      expect(textoDe(tester, 'voz-en-US-F2-voz'), 'Voz us-mujer-2 · en-US');
      expect(textoDe(tester, 'voz-en-US-M1-voz'), 'Voz us-hombre-1 · en-US');
      expect(textoDe(tester, 'voz-en-US-M2-voz'), 'Voz us-hombre-2 · en-US');
      expect(textoDe(tester, 'voz-en-US-N-voz'), 'Voz us-neutra-1 · en-US');
      // El británico solo tiene dos voces: los demás papeles quedan sin voz.
      expect(textoDe(tester, 'voz-en-GB-F1-voz'), 'Voz gb-mujer-1 · en-GB');
      expect(textoDe(tester, 'voz-en-GB-M1-voz'), 'Voz gb-hombre-1 · en-GB');
      expect(textoDe(tester, 'voz-en-GB-F2-voz'), 'Sin otra voz distinta en este equipo');
      expect(tester.widget<OutlinedButton>(k('voz-en-GB-F2-probar')).onPressed, isNull);
      expect(tester.widget<OutlinedButton>(k('voz-en-GB-F1-probar')).onPressed, isNotNull);
    });

    testWidgets('Probar un papel dice la frase con esa voz y en ese acento', (tester) async {
      final f = FuenteDeVozFalsa(duracionTurno: Duration.zero);
      await abrirVoz(tester, fuente: f);
      await tester.tap(k('voz-en-US-M1-probar'));
      await asentar(tester);
      await tester.pumpAndSettle();
      final p = f.peticiones.single;
      expect(p.idVozMotor, 'us-hombre-1');
      expect(p.voz, VozDeGuion.m1);
      expect(p.texto, fraseDePruebaEnIngles);
      expect(textoDe(tester, 'voz-en-US-M1-mensaje'), 'Sonó con: Voz del dispositivo · Voz us-hombre-1');
    });

    testWidgets('el diálogo de prueba usa dos voces distintas en seis turnos', (tester) async {
      final f = FuenteDeVozFalsa(duracionTurno: Duration.zero);
      await abrirVoz(tester, fuente: f);
      await tester.tap(k('voz-dialogo-en-US'));
      await asentar(tester);
      // Entre turnos pasa la pausa del guion (600 ms).
      await tester.pump(const Duration(seconds: 4));
      await asentar(tester);
      await tester.pumpAndSettle();
      expect(f.peticiones, hasLength(6));
      final voces = f.peticiones.map((p) => p.idVozMotor).toSet();
      expect(voces, {'us-mujer-1', 'us-hombre-1'});
      expect(
        f.peticiones.map((p) => p.voz),
        [VozDeGuion.f1, VozDeGuion.m1, VozDeGuion.f1, VozDeGuion.m1, VozDeGuion.f1, VozDeGuion.m1],
      );
    });

    testWidgets('con una sola voz en inglés no hay diálogo y la pantalla lo explica', (tester) async {
      final f = FuenteDeVozFalsa(
        voces: [voz('es-1', Variante.esMX, Genero.sinDato), voz('us-1', Variante.enUS, Genero.mujer)],
      );
      await abrirVoz(tester, fuente: f);
      expect(tester.widget<OutlinedButton>(k('voz-dialogo-en-US')).onPressed, isNull);
      expect(k('voz-dialogo-en-US-falta'), findsOneWidget);
      expect(k('voz-acento-en-GB'), findsNothing);
    });

    testWidgets('cambiar una voz que ya usa otro papel las intercambia', (tester) async {
      await abrirVoz(tester, fuente: FuenteDeVozFalsa());
      await tester.tap(k('voz-en-US-M1-cambiar'));
      await tester.pumpAndSettle();
      // El diálogo dice quién usa cada voz.
      expect(find.text('en-US · la usa: Mujer 1'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('voz-opcion-us-mujer-1')));
      await tester.pumpAndSettle();
      expect(textoDe(tester, 'voz-en-US-M1-voz'), 'Voz us-mujer-1 · en-US');
      expect(textoDe(tester, 'voz-en-US-F1-voz'), 'Voz us-hombre-1 · en-US');
      final guardada = contenedor(tester)
          .read(preferenciasVozProvider)
          .asignacionDe(Fuente.dispositivo, Variante.enUS);
      expect(guardada.values.toSet().length, guardada.length, reason: 'ninguna voz repetida');
    });

    testWidgets('lo elegido se conserva al volver a abrir la pantalla', (tester) async {
      await abrirVoz(tester, fuente: FuenteDeVozFalsa());
      await tester.tap(k('voz-en-US-F1-cambiar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('voz-opcion-us-neutra-1')));
      await tester.pumpAndSettle();
      final c = contenedor(tester);
      c.read(routerProvider).go(Rutas.ajustes);
      await tester.pumpAndSettle();
      c.read(routerProvider).go('${Rutas.ajustes}/voz');
      await tester.pumpAndSettle();
      expect(textoDe(tester, 'voz-en-US-F1-voz'), 'Voz us-neutra-1 · en-US');
    });
  });

  group('qué ve cada rol', () {
    testWidgets('el dueño ve asistente y curso', (tester) async {
      await abrirVoz(tester, fuente: FuenteDeVozFalsa());
      expect(k('voz-asistente'), findsOneWidget);
      expect(k('voz-curso'), findsOneWidget);
    });

    testWidgets('la cuidadora ve el estado, pero no el asistente ni el curso (D5)', (tester) async {
      await abrirVoz(tester, fuente: FuenteDeVozFalsa(), rol: Rol.cuidador);
      expect(k('voz-estado'), findsOneWidget);
      expect(k('voz-asistente'), findsNothing);
      expect(k('voz-curso'), findsNothing);
    });

    testWidgets('la cuenta maestra conversa, pero no tiene Hábitos', (tester) async {
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.laptop,
        sesion: ServicioSesionFalso(
          inicial: Sesion(
            persona: const Persona(
              id: '00000000-0000-4000-8000-0000000000f1',
              nombre: 'Cuenta maestra de ejemplo',
            ),
            rol: Rol.coadministrador,
            hogarId: hogarDeEjemplo,
            esMaestra: true,
          ),
        ),
        extras: [fuentesDeVozProvider.overrideWithValue([FuenteDeVozFalsa()])],
      );
      tester.view.physicalSize = const Size(1280, 4200);
      final c = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
      c.read(routerProvider).go('${Rutas.ajustes}/voz');
      await tester.pumpAndSettle();
      expect(k('voz-asistente'), findsOneWidget);
      expect(k('voz-curso'), findsNothing);
    });
  });

  group('errores de la prueba, dichos sin culpa', () {
    testWidgets('la voz se detiene a mitad', (tester) async {
      final f = FuenteDeVozFalsa(duracionTurno: Duration.zero)..fallarEnTurno = 0;
      await abrirVoz(tester, fuente: f);
      await tester.tap(k('voz-asistente-fila-probar'));
      await asentar(tester);
      await tester.pumpAndSettle();
      expect(textoDe(tester, 'voz-asistente-fila-mensaje'), 'La voz se detuvo.');
    });

    testWidgets('si la fuente no puede, dice por qué', (tester) async {
      final f = FuenteDeVozFalsa()..motivo = Motivo.vocesInsuficientes;
      await abrirVoz(tester, fuente: f);
      await tester.tap(k('voz-asistente-fila-probar'));
      await asentar(tester);
      await tester.pumpAndSettle();
      expect(
        textoDe(tester, 'voz-asistente-fila-mensaje'),
        'No hay una voz disponible para esta prueba. '
        'Voz del dispositivo: no hay voces distintas suficientes.',
      );
    });

    testWidgets('con otra voz sonando (el curso) avisa y deja parar', (tester) async {
      final f = FuenteDeVozFalsa(manual: true);
      await abrirVoz(tester, fuente: f);
      await tester.tap(k('voz-en-US-F1-probar'));
      await asentar(tester);
      expect(f.sonando, isTrue);
      await tester.tap(k('voz-asistente-fila-probar'));
      await asentar(tester);
      expect(textoDe(tester, 'voz-asistente-fila-mensaje'), 'Hay otra voz sonando.');
      expect(k('voz-asistente-fila-parar'), findsOneWidget);
      await tester.tap(k('voz-asistente-fila-parar'));
      await asentar(tester);
      expect(f.sonando, isFalse);
    });

    testWidgets('salir de la pantalla calla la prueba que sonaba', (tester) async {
      final f = FuenteDeVozFalsa(manual: true);
      await abrirVoz(tester, fuente: f);
      await tester.tap(k('voz-asistente-fila-probar'));
      await asentar(tester);
      expect(f.sonando, isTrue);
      contenedor(tester).read(routerProvider).go(Rutas.ajustes);
      await tester.pumpAndSettle();
      expect(f.sonando, isFalse);
    });
  });

  group('accesibilidad y letra grande', () {
    for (final (nombre, dispositivo, ventana) in [
      ('teléfono', TipoDispositivo.telefono, const Size(360, 12000)),
      ('laptop estrecha', TipoDispositivo.laptop, const Size(700, 9000)),
    ]) {
      testWidgets('con letra al doble en $nombre no se desborda nada', (tester) async {
        fijarEscalaDeLetra(tester, 2.0);
        final desbordes = await recolectarDesbordes(() async {
          await abrirVoz(
            tester,
            fuente: FuenteDeVozFalsa(),
            dispositivo: dispositivo,
            ventana: ventana,
          );
          await tester.tap(find.text('Detalles técnicos'));
          await tester.pumpAndSettle();
        });
        expect(desbordes, isEmpty);
        expect(k('voz-asistente'), findsOneWidget);
      });
    }

    testWidgets('cada botón de probar, cambiar y parar tiene texto para el lector', (tester) async {
      final semantica = tester.ensureSemantics();
      await abrirVoz(tester, fuente: FuenteDeVozFalsa());
      expect(find.bySemanticsLabel('Probar'), findsWidgets);
      expect(find.bySemanticsLabel('Cambiar'), findsWidgets);
      semantica.dispose();
    });
  });
}
