// La fuente A (voz del dispositivo) con una puerta simulada: sin plugin real.
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/gravity/voz/asignador.dart';
import 'package:gravity/modulos/gravity/voz/fuente_de_voz.dart';
import 'package:gravity/modulos/gravity/voz/fuentes/dispositivo/fuente_dispositivo.dart';
import 'package:gravity/modulos/gravity/voz/fuentes/dispositivo/puerto_tts.dart';
import 'package:gravity/modulos/gravity/voz/motor.dart';
import 'package:gravity/modulos/gravity/voz/preferencias.dart';
import 'package:gravity/modulos/gravity/voz/tipos.dart';

VozDelSistema sis(
  String nombre,
  String locale, {
  String? calidad,
  bool? red,
  bool instalada = true,
  Genero genero = Genero.sinDato,
}) => VozDelSistema(
  nombre: nombre,
  locale: locale,
  calidad: calidad,
  requiereRed: red,
  instalada: instalada,
  genero: genero,
);

/// Un equipo Android de ejemplo: voces locales, de red y sin instalar.
List<VozDelSistema> equipoAndroid() => [
  sis('en-us-x-aaa-local', 'en-US', calidad: 'normal', red: false),
  sis('en-us-x-bbb-network', 'en-US', calidad: 'very high', red: true),
  sis('en-us-x-ccc#female_1-local', 'en-US', calidad: 'high', red: false, genero: Genero.mujer),
  sis('en-us-x-ddd#male_1-local', 'en-US', calidad: 'high', red: false, genero: Genero.hombre),
  sis('en-us-x-eee-local', 'en-US', calidad: 'low', red: false, instalada: false),
  sis('en-gb-x-fff-local', 'en-GB', calidad: 'normal', red: false),
  sis('en-au-x-ggg-local', 'en-AU', calidad: 'normal', red: false),
  sis('es-es-x-hhh-local', 'es-ES', calidad: 'normal', red: false),
  sis('es-mx-x-iii-local', 'es-MX', calidad: 'normal', red: false),
  sis('es-us-x-jjj-local', 'es-US', calidad: 'high', red: false),
  sis('es-mx-x-kkk-network', 'es-MX', calidad: 'very high', red: true),
];

Guion frase(String texto, {Variante v = Variante.esMX, VozDeGuion voz = VozDeGuion.f1}) =>
    Guion(id: 'f', variante: v, turnos: [Turno(voz: voz, texto: texto)]);

void main() {
  group('lista de voces', () {
    test('filtra por idioma y acento y deja fuera las de red y las sin instalar', () async {
      final f = FuenteDispositivo(PuertoTtsFalso(voces: equipoAndroid()));
      final us = await f.voces(Variante.enUS);
      expect(us.map((x) => x.nombre), [
        // Calidad alta primero, después normal; la de red y la sin instalar no.
        'en-us-x-ccc#female_1-local',
        'en-us-x-ddd#male_1-local',
        'en-us-x-aaa-local',
      ]);
      expect(us.every((x) => x.local && x.fuente == Fuente.dispositivo), isTrue);
      expect((await f.voces(Variante.enGB)).map((x) => x.nombre), ['en-gb-x-fff-local']);
    });

    test('otros acentos del inglés (Australia) no se ofrecen', () async {
      final f = FuenteDispositivo(PuertoTtsFalso(voces: equipoAndroid()));
      final todas = [
        for (final v in Variante.values) ...await f.voces(v),
      ];
      expect(todas.map((x) => x.locale), isNot(contains('en-AU')));
    });

    test('el español se ordena con el de México primero', () async {
      final f = FuenteDispositivo(PuertoTtsFalso(voces: equipoAndroid()));
      final es = await f.voces(Variante.esMX);
      expect(es.map((x) => x.locale), ['es-MX', 'es-US', 'es-ES']);
      expect(es.map((x) => x.nombre), isNot(contains('es-mx-x-kkk-network')));
    });

    test('Windows no dice si una voz usa red: se ofrecen todas', () async {
      final f = FuenteDispositivo(
        PuertoTtsFalso(
          voces: [
            sis('Microsoft Zira', 'en-US', genero: Genero.mujer),
            sis('Microsoft David', 'en-US', genero: Genero.hombre),
          ],
        ),
      );
      expect(await f.voces(Variante.enUS), hasLength(2));
    });

    test('el id de la voz es estable y distingue idioma y nombre', () async {
      final f = FuenteDispositivo(PuertoTtsFalso(voces: equipoAndroid()));
      final a = await f.voces(Variante.enUS);
      final b = await f.voces(Variante.enUS);
      expect(a.map((x) => x.id), b.map((x) => x.id));
      expect(a.map((x) => x.id).toSet(), hasLength(a.length));
    });

    test('la lista se consulta una sola vez hasta pedir refrescar', () async {
      final puerto = PuertoTtsFalso(voces: equipoAndroid());
      final f = FuenteDispositivo(puerto);
      await f.voces(Variante.enUS);
      await f.voces(Variante.esMX);
      await f.diagnostico();
      expect(puerto.consultasDeVoces, 1);
      await f.refrescar();
      expect(puerto.consultasDeVoces, 2);
    });

    test('un fallo al listar no se guarda: la próxima vez se vuelve a preguntar', () async {
      final puerto = PuertoTtsFalso(voces: equipoAndroid())
        ..errorAlListar = const FalloDeSintesis(Fuente.dispositivo, 'sin_motor_de_voz');
      final f = FuenteDispositivo(puerto);
      await expectLater(f.voces(Variante.enUS), throwsA(isA<FalloDeSintesis>()));
      puerto.errorAlListar = null;
      expect(await f.voces(Variante.enUS), isNotEmpty);
    });

    test('el diagnóstico trae todo lo que dice el sistema', () async {
      final f = FuenteDispositivo(PuertoTtsFalso(voces: equipoAndroid()));
      final d = await f.diagnostico();
      expect(d, hasLength(equipoAndroid().length));
      expect(d.where((v) => v.requiereRed == true), hasLength(2));
      expect(d.where((v) => !v.instalada), hasLength(1));
    });
  });

  group('motivos por los que no sirve', () {
    test('sin voz en el idioma, voces insuficientes y sin motor', () async {
      final puerto = PuertoTtsFalso(voces: [sis('en-us-x-a-local', 'en-US', red: false)]);
      final f = FuenteDispositivo(puerto);
      // Español: ninguna.
      expect(
        await f.motivoNoDisponible(frase('hola'), const Asignacion(Fuente.dispositivo, Variante.esMX, {})),
        Motivo.sinVozEnElIdioma,
      );
      // Inglés con dos voces de guion y una sola voz.
      final dos = Guion(
        id: 'd',
        variante: Variante.enUS,
        turnos: const [
          Turno(voz: VozDeGuion.f1, texto: 'a'),
          Turno(voz: VozDeGuion.m1, texto: 'b'),
        ],
      );
      final voces = await f.voces(Variante.enUS);
      final a = resolverAsignacion(
        asignador: const AsignadorPorGenero(),
        fuente: Fuente.dispositivo,
        variante: Variante.enUS,
        voces: voces,
        roles: dos.vocesUsadas,
      );
      expect(await f.motivoNoDisponible(dos, a), Motivo.vocesInsuficientes);
      // Una voz repetida en dos papeles tampoco sirve.
      final repetida = Asignacion(
        Fuente.dispositivo,
        Variante.enUS,
        {VozDeGuion.f1: voces.first.id, VozDeGuion.m1: voces.first.id},
      );
      expect(await f.motivoNoDisponible(dos, repetida), Motivo.vocesInsuficientes);
      // Sin motor de voz.
      puerto.errorAlListar = const FalloDeSintesis(Fuente.dispositivo, 'sin_motor_de_voz');
      await f.refrescar();
      expect(await f.motivoNoDisponible(dos, a), Motivo.sinMotorDeVoz);
    });

    test('con voces suficientes sirve', () async {
      final f = FuenteDispositivo(PuertoTtsFalso(voces: equipoAndroid()));
      final voces = await f.voces(Variante.enUS);
      final dos = Guion(
        id: 'd',
        variante: Variante.enUS,
        turnos: const [
          Turno(voz: VozDeGuion.f1, texto: 'a'),
          Turno(voz: VozDeGuion.m1, texto: 'b'),
        ],
      );
      final a = resolverAsignacion(
        asignador: const AsignadorPorGenero(),
        fuente: Fuente.dispositivo,
        variante: Variante.enUS,
        voces: voces,
        roles: dos.vocesUsadas,
      );
      expect(await f.motivoNoDisponible(dos, a), isNull);
      // F1 toma a la mujer conocida y M1 al hombre conocido.
      expect(voces.firstWhere((v) => v.id == a.idVozMotor[VozDeGuion.f1]).genero, Genero.mujer);
      expect(voces.firstWhere((v) => v.id == a.idVozMotor[VozDeGuion.m1]).genero, Genero.hombre);
    });
  });

  group('reproducir', () {
    Future<(MotorDeVoz, PuertoTtsFalso)> motorCon(
      PuertoTtsFalso puerto, {
      PreferenciasVoz prefs = const PreferenciasVoz(),
    }) async {
      final motor = MotorDeVoz(
        fuentes: [FuenteDispositivo(puerto)],
        preferencias: () => prefs,
      );
      return (motor, puerto);
    }

    test('dice cada turno con la voz asignada y la elige solo cuando cambia', () async {
      final (motor, puerto) = await motorCon(PuertoTtsFalso(voces: equipoAndroid()));
      final repro = await motor.reproducir(
        Guion(
          id: 'd',
          variante: Variante.enUS,
          pausaEntreTurnos: Duration.zero,
          turnos: const [
            Turno(voz: VozDeGuion.f1, texto: 'one'),
            Turno(voz: VozDeGuion.f1, texto: 'two'),
            Turno(voz: VozDeGuion.m1, texto: 'three'),
            Turno(voz: VozDeGuion.f1, texto: 'four'),
          ],
        ),
      );
      expect(repro.fuente, Fuente.dispositivo);
      expect(await repro.terminada, Fin.completa);
      expect(puerto.dichos, ['one', 'two', 'three', 'four']);
      expect(puerto.vocesFijadas.map((x) => x.nombre), [
        'en-us-x-ccc#female_1-local',
        'en-us-x-ddd#male_1-local',
        'en-us-x-ccc#female_1-local',
      ]);
      expect(puerto.vocesFijadas.every((x) => x.locale == 'en-US'), isTrue);
    });

    test('traduce la velocidad a la escala del plugin (0.5 es la normal)', () async {
      final (motor, puerto) = await motorCon(PuertoTtsFalso(voces: equipoAndroid()));
      for (final vel in [1.0, 0.8, 1.5, 3.0, 0.1]) {
        final r = await motor.decir('hello', uso: UsoVoz.curso, velocidad: vel);
        await r.terminada;
      }
      expect(puerto.velocidadesFijadas, [
        closeTo(0.5, 1e-9),
        closeTo(0.4, 1e-9),
        closeTo(0.75, 1e-9),
        closeTo(0.75, 1e-9), // 3.0 se ajusta a 1.5
        closeTo(0.25, 1e-9), // 0.1 se ajusta a 0.5
      ]);
    });

    test('el rango del plugin acota la velocidad', () async {
      final puerto = PuertoTtsFalso(
        voces: equipoAndroid(),
        rango: (min: 0.3, normal: 0.5, max: 0.6),
      );
      final (motor, _) = await motorCon(puerto);
      final r = await motor.decir('hello', uso: UsoVoz.curso, velocidad: 1.5);
      await r.terminada;
      expect(puerto.velocidadesFijadas.single, closeTo(0.6, 1e-9));
    });

    test('pausar corta el turno y reanudar lo repite desde el principio', () async {
      final puerto = PuertoTtsFalso(voces: equipoAndroid(), manual: true);
      final (motor, _) = await motorCon(puerto);
      final repro = await motor.decir('hello world', uso: UsoVoz.curso);
      await Future<void>.delayed(Duration.zero);
      expect(puerto.sonando, isTrue);
      await repro.pausar();
      await Future<void>.delayed(Duration.zero);
      expect(puerto.cortes, 1);
      expect(puerto.sonando, isFalse);
      await repro.reanudar();
      await Future<void>.delayed(Duration.zero);
      expect(puerto.dichos, ['hello world', 'hello world']);
      puerto.terminarTurno();
      expect(await repro.terminada, Fin.completa);
    });

    test('parar corta y completa con parada', () async {
      final puerto = PuertoTtsFalso(voces: equipoAndroid(), manual: true);
      final (motor, _) = await motorCon(puerto);
      final repro = await motor.decir('hello', uso: UsoVoz.curso);
      await Future<void>.delayed(Duration.zero);
      await repro.parar();
      expect(await repro.terminada, Fin.parada);
      expect(puerto.cortes, 1);
    });

    test('una falla del sistema completa con FalloDeSintesis y un código, sin el texto', () async {
      const secreto = 'TEXTO-QUE-NO-DEBE-SALIR';
      final puerto = PuertoTtsFalso(voces: equipoAndroid())..fallarEnTurno = 0;
      final (motor, _) = await motorCon(puerto);
      final repro = await motor.decir(secreto, uso: UsoVoz.curso);
      Object? error;
      try {
        await repro.terminada;
      } catch (e) {
        error = e;
      }
      expect(error, isA<FalloDeSintesis>());
      expect((error! as FalloDeSintesis).codigo, 'speak_error');
      expect(error.toString(), isNot(contains(secreto)));
    });

    test('si el sistema no encuentra la voz elegida, falla con un código', () async {
      final puerto = PuertoTtsFalso(voces: equipoAndroid())..vozNoEncontrada = true;
      final (motor, _) = await motorCon(puerto);
      final repro = await motor.decir('hello', uso: UsoVoz.curso);
      await expectLater(
        repro.terminada,
        throwsA(
          isA<FalloDeSintesis>().having((e) => e.codigo, 'codigo', 'voz_no_encontrada'),
        ),
      );
    });

    test('sin motor de voz el motor no puede hablar y lo dice', () async {
      final puerto = PuertoTtsFalso()
        ..errorAlListar = const FalloDeSintesis(Fuente.dispositivo, 'sin_motor_de_voz');
      final (motor, _) = await motorCon(puerto);
      await expectLater(
        motor.decir('hola', uso: UsoVoz.asistente, variante: Variante.esMX),
        throwsA(
          isA<SinFuenteDisponible>().having(
            (e) => e.motivos[Fuente.dispositivo],
            'motivo',
            Motivo.sinMotorDeVoz,
          ),
        ),
      );
    });

    test('la capacidad dice que no hay progreso por palabra y que sí hay pausa', () {
      final c = FuenteDispositivo(PuertoTtsFalso()).capacidades;
      expect(c.progresoPorPalabra, isFalse);
      expect(c.pausa, isTrue);
      expect(c.ajustarVelocidad(9), c.velocidadMax);
    });
  });

  group('vozDelSistemaDe (formatos del plugin)', () {
    test('Android: red, instalada, calidad y género en el nombre', () {
      final v = vozDelSistemaDe({
        'name': 'en-us-x-sfg#female_2-local',
        'locale': 'en-US',
        'quality': 'high',
        'latency': 'normal',
        'network_required': '0',
        'features': 'networkTimeoutMs\tretryTimeoutMs',
      })!;
      expect(v.requiereRed, isFalse);
      expect(v.instalada, isTrue);
      expect(v.genero, Genero.mujer);
      expect(v.calidad, 'high');
      final red = vozDelSistemaDe({
        'name': 'en-us-x-iom-network',
        'locale': 'en-US',
        'network_required': '1',
        'features': 'networkTimeoutMs',
      })!;
      expect(red.requiereRed, isTrue);
      final sin = vozDelSistemaDe({
        'name': 'en-us-x-iol#male_1-local',
        'locale': 'en-US',
        'network_required': '0',
        'features': 'notInstalled\tnetworkTimeoutMs',
      })!;
      expect(sin.instalada, isFalse);
      expect(sin.genero, Genero.hombre);
    });

    test('Windows: género e identificador, sin dato de red', () {
      final v = vozDelSistemaDe({
        'name': 'Microsoft David',
        'locale': 'en-US',
        'gender': 'male',
        'identifier': r'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Speech_OneCore\Voices\Tokens\MSTTS_V110_enUS_DavidM',
      })!;
      expect(v.requiereRed, isNull);
      expect(v.genero, Genero.hombre);
      expect(v.instalada, isTrue);
    });

    test('una voz sin nombre o sin idioma se descarta', () {
      expect(vozDelSistemaDe({'name': '', 'locale': 'en-US'}), isNull);
      expect(vozDelSistemaDe({'name': 'x', 'locale': ''}), isNull);
      expect(vozDelSistemaDe({'locale': 'en-US'}), isNull);
    });
  });

  test('varianteDe entiende guion y guion bajo', () {
    expect(FuenteDispositivo.varianteDe('en_US'), Variante.enUS);
    expect(FuenteDispositivo.varianteDe('EN-gb'), Variante.enGB);
    expect(FuenteDispositivo.varianteDe('es'), Variante.esMX);
    expect(FuenteDispositivo.varianteDe('es-419'), Variante.esMX);
    expect(FuenteDispositivo.varianteDe('en-IN'), isNull);
    expect(FuenteDispositivo.varianteDe('fr-FR'), isNull);
  });
}
