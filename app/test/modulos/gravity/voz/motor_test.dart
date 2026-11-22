// El motor de voz con fuentes simuladas (spec fase-8-motor-de-voz, sección 10,
// criterios 1 a 8, 10, 16, 32 a 35 y 38).
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/gravity/conversacion/voz.dart';
import 'package:gravity/modulos/gravity/voz/fuente_falsa.dart';
import 'package:gravity/modulos/gravity/voz/motor.dart';
import 'package:gravity/modulos/gravity/voz/preferencias.dart';
import 'package:gravity/modulos/gravity/voz/tipos.dart';

/// Un motor con las fuentes dadas y preferencias que la prueba puede cambiar.
class Banco {
  Banco(this.fuentes, {PreferenciasVoz prefs = const PreferenciasVoz()})
    : preferencias = prefs {
    motor = MotorDeVoz(fuentes: fuentes, preferencias: () => preferencias);
  }
  final List<FuenteDeVozFalsa> fuentes;
  PreferenciasVoz preferencias;
  late final MotorDeVoz motor;
}

Guion dialogo(List<VozDeGuion> voces, {Variante v = Variante.enUS}) => Guion(
  id: 'unidad-1',
  variante: v,
  pausaEntreTurnos: Duration.zero,
  turnos: [
    for (var i = 0; i < voces.length; i++)
      Turno(voz: voces[i], texto: 'linea numero $i'),
  ],
);

FuenteDeVozFalsa rapida({
  Fuente tipo = Fuente.dispositivo,
  List<VozMotor>? voces,
  bool manual = false,
}) => FuenteDeVozFalsa(
  tipo: tipo,
  voces: voces,
  duracionTurno: const Duration(milliseconds: 2),
  manual: manual,
);

VozMotor v(String id, Genero g, {Fuente f = Fuente.dispositivo, bool local = true}) =>
    VozMotor(
      id: id,
      fuente: f,
      nombre: id,
      variante: Variante.enUS,
      genero: g,
      local: local,
    );

Future<void> cedeElTurno() => Future<void>.delayed(Duration.zero);

void main() {
  group('compatibilidad con VozSalida (criterios 1 y 2)', () {
    test('MotorDeVoz es una VozSalida y VozSalidaFalsa sigue compilando', () {
      final VozSalida salida = Banco([rapida()]).motor;
      expect(salida, isA<MotorVoz>());
      expect(VozSalidaFalsa(), isA<VozSalida>());
      expect(const VozSalidaNoDisponible(), isA<VozSalida>());
    });

    test('hablar equivale a decir con uso asistente en español', () async {
      final fuente = rapida();
      final banco = Banco([fuente]);
      await banco.motor.hablar('Vas bien esta semana.');
      expect(fuente.peticiones, hasLength(1));
      final p = fuente.peticiones.single;
      expect(p.texto, 'Vas bien esta semana.');
      expect(p.voz, VozDeGuion.f1);
      expect(p.idVozMotor, startsWith('es-'));
      expect(p.velocidad, 1.0);
    });

    test('hablar usa la velocidad que la persona fijó', () async {
      final fuente = rapida();
      final banco = Banco([
        fuente,
      ], prefs: const PreferenciasVoz(asistente: PreferenciasDeUso(velocidad: 0.7)));
      await banco.motor.hablar('Hola');
      expect(fuente.peticiones.single.velocidad, closeTo(0.7, 1e-9));
    });

    test('hablar con texto vacío no hace nada', () async {
      final fuente = rapida();
      await Banco([fuente]).motor.hablar('   ');
      expect(fuente.reproducciones, 0);
    });

    test('sin ninguna fuente, hablar no hace nada ni falla', () async {
      await Banco([]).motor.hablar('Hola');
    });
  });

  group('guiones de varias voces (criterios 3, 4 y 5)', () {
    test('cambia de voz en cada turno con voces distintas para F1 y M1', () async {
      final fuente = rapida();
      final banco = Banco([fuente]);
      final repro = await banco.motor.reproducir(
        dialogo([VozDeGuion.f1, VozDeGuion.m1, VozDeGuion.f1, VozDeGuion.m1]),
      );
      expect(await repro.terminada, Fin.completa);
      final ps = fuente.peticiones;
      expect(ps.map((p) => p.voz), [
        VozDeGuion.f1,
        VozDeGuion.m1,
        VozDeGuion.f1,
        VozDeGuion.m1,
      ]);
      expect(ps[0].idVozMotor, ps[2].idVozMotor);
      expect(ps[1].idVozMotor, ps[3].idVozMotor);
      expect(ps[0].idVozMotor, isNot(ps[1].idVozMotor));
      // F1 es mujer y M1 hombre en las voces de ejemplo.
      expect(ps[0].idVozMotor, contains('mujer'));
      expect(ps[1].idVozMotor, contains('hombre'));
    });

    test('cinco voces con una fuente de tres: se descarta y sigue la siguiente', () async {
      final tres = rapida(
        tipo: Fuente.dispositivo,
        voces: [
          v('a', Genero.mujer),
          v('b', Genero.hombre),
          v('c', Genero.sinDato),
        ],
      );
      final seis = rapida(
        tipo: Fuente.modelo,
        voces: [
          for (final (i, g) in [
            Genero.mujer,
            Genero.mujer,
            Genero.hombre,
            Genero.hombre,
            Genero.sinDato,
            Genero.sinDato,
          ].indexed)
            v('modelo-$i', g, f: Fuente.modelo),
        ],
      );
      final banco = Banco([tres, seis]);
      final guion = dialogo(VozDeGuion.values);

      final d = await banco.motor.disponibilidad(
        UsoVoz.curso,
        variante: Variante.enUS,
        vocesNecesarias: 5,
      );
      expect(d.descartadas[Fuente.dispositivo], Motivo.vocesInsuficientes);
      expect(d.cadena, [Fuente.modelo]);

      final repro = await banco.motor.reproducir(guion);
      expect(repro.fuente, Fuente.modelo);
      await repro.terminada;
      expect(tres.reproducciones, 0);
      final ids = seis.peticiones.map((p) => p.idVozMotor).toList();
      expect(ids.toSet().length, 5, reason: 'ninguna voz se repite');
    });

    test('con una sola fuente de tres voces el guion de cinco no se reproduce', () async {
      final tres = rapida(
        voces: [v('a', Genero.mujer), v('b', Genero.hombre), v('c', Genero.sinDato)],
      );
      final banco = Banco([tres]);
      await expectLater(
        banco.motor.reproducir(dialogo(VozDeGuion.values)),
        throwsA(
          isA<SinFuenteDisponible>().having(
            (e) => e.motivos[Fuente.dispositivo],
            'motivo',
            Motivo.vocesInsuficientes,
          ),
        ),
      );
      expect(tres.reproducciones, 0);
    });

    test('el avance emite los 8 turnos en orden y nunca lleva el texto', () async {
      final fuente = rapida();
      final voces = [
        VozDeGuion.f1, VozDeGuion.m1, VozDeGuion.f1, VozDeGuion.m1,
        VozDeGuion.n, VozDeGuion.f1, VozDeGuion.m1, VozDeGuion.n,
      ];
      final guion = Guion(
        id: 'u',
        variante: Variante.enUS,
        pausaEntreTurnos: Duration.zero,
        turnos: [
          for (var i = 0; i < 8; i++)
            Turno(voz: voces[i], texto: 'palabrasecreta$i'),
        ],
      );
      final repro = await Banco([fuente]).motor.reproducir(guion);
      final eventos = await repro.avance.toList();
      expect(eventos.map((e) => e.turno), [0, 1, 2, 3, 4, 5, 6, 7]);
      expect(eventos.map((e) => e.voz), voces);
      expect(eventos.every((e) => e.totalTurnos == 8), isTrue);
      for (final e in eventos) {
        expect(e.toString(), isNot(contains('palabrasecreta')));
      }
      expect(guion.toString(), isNot(contains('palabrasecreta')));
      expect(guion.turnos.first.toString(), isNot(contains('palabrasecreta')));
      expect(await repro.terminada, Fin.completa);
    });
  });

  group('velocidad (criterio 6)', () {
    test('0.8 y 1.0 llegan a la fuente tal cual', () async {
      final fuente = rapida();
      final banco = Banco([fuente]);
      for (final vel in [0.8, 1.0]) {
        final r = await banco.motor.decir(
          'hello',
          uso: UsoVoz.curso,
          velocidad: vel,
        );
        await r.terminada;
        expect(fuente.ultimaVelocidad, vel);
      }
    });

    test('un factor fuera del rango de la fuente se ajusta', () async {
      final fuente = rapida();
      final banco = Banco([fuente]);
      var r = await banco.motor.decir('a', uso: UsoVoz.curso, velocidad: 3.0);
      await r.terminada;
      expect(fuente.ultimaVelocidad, 1.5);
      r = await banco.motor.decir('a', uso: UsoVoz.curso, velocidad: 0.1);
      await r.terminada;
      expect(fuente.ultimaVelocidad, 0.5);
    });
  });

  group('pausar, reanudar y parar (criterios 7 y 8)', () {
    test('pausar detiene el avance sin cambiar de turno; reanudar sigue en el mismo', () async {
      final fuente = rapida(manual: true);
      final banco = Banco([fuente]);
      final repro = await banco.motor.reproducir(
        dialogo([VozDeGuion.f1, VozDeGuion.m1]),
      );
      final eventos = <Avance>[];
      repro.avance.listen(eventos.add);
      await cedeElTurno();
      expect(eventos.map((e) => e.turno), [0]);
      expect(fuente.sonando, isTrue);

      await repro.pausar();
      await cedeElTurno();
      expect(fuente.sonando, isFalse, reason: 'se cortó el turno');
      expect(eventos.map((e) => e.turno), [0], reason: 'no avanzó');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(eventos.map((e) => e.turno), [0]);

      await repro.reanudar();
      await cedeElTurno();
      expect(fuente.sonando, isTrue, reason: 'el mismo turno suena otra vez');
      expect(fuente.peticiones.map((p) => p.voz), [VozDeGuion.f1, VozDeGuion.f1]);
      expect(eventos.map((e) => e.turno), [0], reason: 'sigue en el turno 0');
      fuente.terminarTurno();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(eventos.map((e) => e.turno), [0, 1]);
      fuente.terminarTurno();
      expect(await repro.terminada, Fin.completa);
    });

    test('pausar entre dos turnos espera a reanudar', () async {
      final fuente = FuenteDeVozFalsa(duracionTurno: Duration.zero);
      final banco = Banco([fuente]);
      final repro = await banco.motor.reproducir(
        Guion(
          id: 'u',
          variante: Variante.enUS,
          pausaEntreTurnos: const Duration(milliseconds: 30),
          turnos: const [
            Turno(voz: VozDeGuion.f1, texto: 'uno'),
            Turno(voz: VozDeGuion.m1, texto: 'dos'),
          ],
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 8));
      await repro.pausar();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(fuente.peticiones, hasLength(1), reason: 'no pasó al turno 2');
      await repro.reanudar();
      expect(await repro.terminada, Fin.completa);
      expect(fuente.peticiones, hasLength(2));
    });

    test('parar completa con parada y se puede reproducir otro guion', () async {
      final fuente = rapida(manual: true);
      final banco = Banco([fuente]);
      final repro = await banco.motor.reproducir(
        dialogo([VozDeGuion.f1, VozDeGuion.m1]),
      );
      await cedeElTurno();
      await repro.parar();
      expect(await repro.terminada, Fin.parada);
      expect(fuente.peticiones, hasLength(1), reason: 'no empezó el turno 2');
      expect(await repro.avance.length, 1);

      fuente.manual = false;
      final otra = await banco.motor.reproducir(dialogo([VozDeGuion.n]));
      expect(await otra.terminada, Fin.completa);
    });

    test('entre turnos pasa al menos la pausa del guion o la del turno', () async {
      final fuente = FuenteDeVozFalsa(duracionTurno: Duration.zero);
      final banco = Banco([fuente]);
      final reloj = Stopwatch()..start();
      final tiempos = <int>[];
      final repro = await banco.motor.reproducir(
        Guion(
          id: 'u',
          variante: Variante.enUS,
          pausaEntreTurnos: const Duration(milliseconds: 60),
          turnos: const [
            Turno(voz: VozDeGuion.f1, texto: 'a'),
            Turno(voz: VozDeGuion.m1, texto: 'b', pausaDespues: Duration(milliseconds: 120)),
            Turno(voz: VozDeGuion.f1, texto: 'c'),
          ],
        ),
      );
      final sub = repro.avance.listen((e) => tiempos.add(reloj.elapsedMilliseconds));
      await repro.terminada;
      await sub.cancel();
      expect(tiempos, hasLength(3));
      expect(tiempos[1] - tiempos[0], greaterThanOrEqualTo(58));
      expect(tiempos[2] - tiempos[1], greaterThanOrEqualTo(118));
    });
  });

  group('una sola voz a la vez (criterio 38)', () {
    test('el curso detiene al asistente', () async {
      final fuente = rapida(manual: true);
      final banco = Banco([fuente]);
      final hablando = banco.motor.hablar('Respuesta larga del asistente.');
      await cedeElTurno();
      await cedeElTurno();
      expect(fuente.sonando, isTrue);

      final curso = await banco.motor.decir('hello', uso: UsoVoz.curso);
      await cedeElTurno();
      expect(fuente.cortes, 1, reason: 'se cortó al asistente');
      await hablando; // el asistente terminó (parado)
      fuente.terminarTurno();
      expect(await curso.terminada, Fin.completa);
    });

    test('una respuesta del asistente mientras suena el curso no lo interrumpe', () async {
      final fuente = rapida(manual: true);
      final banco = Banco([fuente]);
      final curso = await banco.motor.decir('hello', uso: UsoVoz.curso);
      await cedeElTurno();
      expect(fuente.sonando, isTrue);

      // `hablar` se calla; `decir` avisa.
      await banco.motor.hablar('Respuesta');
      expect(fuente.cortes, 0);
      expect(fuente.peticiones, hasLength(1));
      await expectLater(
        banco.motor.decir('Hola', uso: UsoVoz.asistente, variante: Variante.esMX),
        throwsA(isA<OcupadoPorOtroUso>()),
      );
      fuente.terminarTurno();
      expect(await curso.terminada, Fin.completa);
    });

    test('dos respuestas seguidas del asistente se dicen en orden', () async {
      final fuente = rapida();
      final banco = Banco([fuente]);
      final a = banco.motor.hablar('primera');
      final b = banco.motor.hablar('segunda');
      await Future.wait([a, b]);
      expect(fuente.peticiones.map((p) => p.texto), ['primera', 'segunda']);
    });

    test('detener corta lo que suena y vacía la cola', () async {
      final fuente = rapida(manual: true);
      final banco = Banco([fuente]);
      final a = banco.motor.hablar('primera');
      final b = banco.motor.hablar('segunda');
      await cedeElTurno();
      await cedeElTurno();
      expect(fuente.sonando, isTrue);
      await banco.motor.detener();
      await Future.wait([a, b]);
      expect(fuente.sonando, isFalse);
      expect(fuente.peticiones.map((p) => p.texto), ['primera']);
    });
  });

  group('la cadena de fuentes (criterios 32 y 34)', () {
    test('por omisión: curso C, B, A; asistente A, B', () {
      expect(cadenaPorOmision(UsoVoz.curso), [
        Fuente.pregrabado,
        Fuente.modelo,
        Fuente.dispositivo,
      ]);
      expect(cadenaPorOmision(UsoVoz.asistente), [
        Fuente.dispositivo,
        Fuente.modelo,
      ]);
    });

    test('la preferida pasa al frente y las demás siguen en el mismo orden', () {
      expect(
        cadenaDe(
          UsoVoz.curso,
          const PreferenciasDeUso(fuente: Fuente.dispositivo),
        ),
        [Fuente.dispositivo, Fuente.pregrabado, Fuente.modelo],
      );
      expect(
        cadenaDe(UsoVoz.curso, const PreferenciasDeUso(fuente: Fuente.modelo)),
        [Fuente.modelo, Fuente.pregrabado, Fuente.dispositivo],
      );
    });

    test('solo esta fuente quita el respaldo', () {
      expect(
        cadenaDe(
          UsoVoz.curso,
          const PreferenciasDeUso(
            fuente: Fuente.modelo,
            soloEstaFuente: true,
          ),
        ),
        [Fuente.modelo],
      );
      expect(
        cadenaDe(
          UsoVoz.curso,
          const PreferenciasDeUso(soloEstaFuente: true),
        ),
        cadenaPorOmision(UsoVoz.curso),
        reason: 'sin fuente elegida, "solo" no hace nada',
      );
    });

    test('una fuente preferida que no aplica al uso no cambia la cadena', () {
      expect(
        cadenaDe(
          UsoVoz.asistente,
          const PreferenciasDeUso(fuente: Fuente.pregrabado),
        ),
        cadenaPorOmision(UsoVoz.asistente),
      );
    });

    test('el motor usa la preferida si sirve y el respaldo si no', () async {
      final a = rapida(tipo: Fuente.dispositivo);
      final b = rapida(
        tipo: Fuente.modelo,
        voces: [for (var i = 0; i < 5; i++) v('m$i', Genero.sinDato, f: Fuente.modelo)],
      );
      final banco = Banco(
        [a, b],
        prefs: const PreferenciasVoz(
          curso: PreferenciasDeUso(fuente: Fuente.modelo),
        ),
      );
      final r = await banco.motor.decir('hello', uso: UsoVoz.curso);
      expect(r.fuente, Fuente.modelo);
      await r.terminada;

      // Si la preferida falla, sigue la cadena.
      b.motivo = Motivo.modeloNoInstalado;
      final r2 = await banco.motor.decir('hello', uso: UsoVoz.curso);
      expect(r2.fuente, Fuente.dispositivo);
      await r2.terminada;
    });

    test('soloFuente sin esa fuente disponible no usa otra (criterio 34)', () async {
      final a = rapida(tipo: Fuente.dispositivo);
      final b = rapida(tipo: Fuente.modelo)..motivo = Motivo.modeloNoInstalado;
      final banco = Banco([a, b]);
      await expectLater(
        banco.motor.decir('hello', uso: UsoVoz.curso, soloFuente: Fuente.modelo),
        throwsA(
          isA<SinFuenteDisponible>().having(
            (e) => e.motivos,
            'motivos',
            {Fuente.modelo: Motivo.modeloNoInstalado},
          ),
        ),
      );
      expect(a.reproducciones, 0);
      final r = await banco.motor.decir(
        'hello',
        uso: UsoVoz.curso,
        soloFuente: Fuente.dispositivo,
      );
      expect(r.fuente, Fuente.dispositivo);
      await r.terminada;
    });

    test('sin ninguna fuente lanza SinFuenteDisponible con el motivo de cada una (criterio 33)', () async {
      final banco = Banco([]);
      await expectLater(
        banco.motor.decir('hello', uso: UsoVoz.curso),
        throwsA(
          isA<SinFuenteDisponible>().having((e) => e.motivos, 'motivos', {
            Fuente.pregrabado: Motivo.sinPaqueteDeAudio,
            Fuente.modelo: Motivo.modeloNoInstalado,
            Fuente.dispositivo: Motivo.plataformaNoSoportada,
          }),
        ),
      );
    });

    test('disponibilidad dice qué usaría y por qué no sirve cada una', () async {
      final banco = Banco([rapida()]);
      final d = await banco.motor.disponibilidad(UsoVoz.curso);
      expect(d.disponible, isTrue);
      expect(d.usaria, Fuente.dispositivo);
      expect(d.descartadas, {
        Fuente.pregrabado: Motivo.sinPaqueteDeAudio,
        Fuente.modelo: Motivo.modeloNoInstalado,
      });
      final sin = await Banco([]).motor.disponibilidad(UsoVoz.asistente);
      expect(sin.disponible, isFalse);
      expect(sin.usaria, isNull);
    });

    test('un equipo sin motor de voz se descarta con su motivo', () async {
      final f = rapida()..errorAlListar = const FalloDeSintesis(Fuente.dispositivo, 'sin_motor_de_voz');
      final d = await Banco([f]).motor.disponibilidad(UsoVoz.asistente);
      expect(d.descartadas[Fuente.dispositivo], Motivo.sinMotorDeVoz);
      expect(await Banco([f]).motor.voces(Fuente.dispositivo), isEmpty);
    });

    test('sin voces en el idioma: sinVozEnElIdioma', () async {
      final f = rapida(voces: [v('solo-ingles', Genero.mujer)]);
      final d = await Banco([f]).motor.disponibilidad(UsoVoz.asistente);
      expect(d.descartadas[Fuente.dispositivo], Motivo.sinVozEnElIdioma);
    });
  });

  group('voces de red (criterio 35)', () {
    test('una voz con local false no aparece en voces() ni se asigna nunca', () async {
      final f = rapida(
        voces: [
          v('red-1', Genero.mujer, local: false),
          v('red-2', Genero.hombre, local: false),
          v('local-1', Genero.mujer),
          v('local-2', Genero.hombre),
        ],
      );
      final banco = Banco([f]);
      final voces = await banco.motor.voces(Fuente.dispositivo, variante: Variante.enUS);
      expect(voces.map((x) => x.id), ['local-1', 'local-2']);
      final repro = await banco.motor.reproducir(
        dialogo([VozDeGuion.f1, VozDeGuion.m1]),
      );
      await repro.terminada;
      expect(f.peticiones.map((p) => p.idVozMotor), ['local-1', 'local-2']);
      final a = await banco.motor.asignacion(Fuente.dispositivo, Variante.enUS);
      expect(a!.idVozMotor.values, everyElement(startsWith('local')));
    });

    test('si todas necesitan red no hay voz', () async {
      final f = rapida(voces: [v('red', Genero.mujer, local: false)]);
      final banco = Banco([f]);
      final d = await banco.motor.disponibilidad(UsoVoz.curso, variante: Variante.enUS);
      expect(d.descartadas[Fuente.dispositivo], Motivo.sinVozEnElIdioma);
      await expectLater(
        banco.motor.decir('hello', uso: UsoVoz.curso),
        throwsA(isA<SinFuenteDisponible>()),
      );
    });
  });

  group('preferencias de voz del usuario', () {
    test('la voz elegida por la persona suena en lugar de la propuesta', () async {
      final f = rapida();
      final banco = Banco(
        [f],
        prefs: const PreferenciasVoz().conAsignacion(
          Fuente.dispositivo,
          Variante.enUS,
          {VozDeGuion.f1: 'us-mujer-2'},
        ),
      );
      final r = await banco.motor.reproducir(dialogo([VozDeGuion.f1, VozDeGuion.f2]));
      await r.terminada;
      expect(f.peticiones.map((p) => p.idVozMotor), ['us-mujer-2', 'us-mujer-1']);
    });
  });

  group('fallas y registro (criterios 10 y 16)', () {
    test('una falla a mitad completa terminada con el error y no cambia de fuente', () async {
      final a = rapida()..fallarEnTurno = 1;
      final b = rapida(tipo: Fuente.modelo);
      final banco = Banco([a, b]);
      final repro = await banco.motor.reproducir(
        dialogo([VozDeGuion.f1, VozDeGuion.m1]),
        soloFuente: Fuente.dispositivo,
      );
      await expectLater(repro.terminada, throwsA(isA<FalloDeSintesis>()));
      expect(b.reproducciones, 0);
    });

    test('ningún error ni registro lleva el texto hablado', () async {
      const secreto = 'ELTEXTOSECRETO-98765';
      final a = rapida()..fallarEnTurno = 0;
      final banco = Banco([a]);
      final registro = <String>[];
      final anterior = debugPrint;
      debugPrint = (String? m, {int? wrapWidth}) => registro.add(m ?? '');
      addTearDown(() => debugPrint = anterior);

      final repro = await banco.motor.decir(
        secreto,
        uso: UsoVoz.curso,
        soloFuente: Fuente.dispositivo,
      );
      Object? error;
      try {
        await repro.terminada;
      } catch (e) {
        error = e;
      }
      expect(error, isA<FalloDeSintesis>());
      expect(error.toString(), isNot(contains(secreto)));

      // Por la vía del asistente la falla se registra sin el texto.
      await banco.motor.hablar(secreto);
      expect(registro.join('\n'), isNot(contains(secreto)));

      // Sin fuentes disponibles tampoco.
      await expectLater(
        Banco([]).motor.decir(secreto, uso: UsoVoz.curso),
        throwsA(
          predicate((Object e) => !e.toString().contains(secreto)),
        ),
      );
    });

    test('reproducir con una fuente simulada no abre ninguna conexión (criterio 10)', () async {
      final f = rapida();
      final banco = Banco([f]);
      await HttpOverrides.runZoned(() async {
        final repro = await banco.motor.reproducir(
          dialogo([VozDeGuion.f1, VozDeGuion.m1]),
        );
        expect(await repro.terminada, Fin.completa);
        await banco.motor.hablar('Hola');
        // Si algo intentara una conexión, el cliente de aquí fallaría.
        expect(() => HttpClient().getUrl(Uri.parse('https://ejemplo.invalid')), throwsA(anything));
      }, createHttpClient: (_) => throw StateError('conexión no permitida'));
    });
  });

  test('refrescar vuelve a preguntar al sistema y avisa del cambio', () async {
    final f = rapida();
    final banco = Banco([f]);
    final avisos = <void>[];
    final sub = banco.motor.cambios.listen(avisos.add);
    await banco.motor.refrescar();
    await cedeElTurno();
    expect(f.refrescos, 1);
    expect(avisos, hasLength(1));
    await sub.cancel();
    await banco.motor.cerrar();
  });

  test('diagnóstico: todas las voces del sistema, también las de red', () async {
    final f = rapida(
      voces: [v('a', Genero.mujer), v('b', Genero.hombre, local: false)],
    );
    final d = await Banco([f]).motor.diagnostico(Fuente.dispositivo);
    expect(d.map((x) => x.nombre), ['a', 'b']);
    expect(d.last.requiereRed, isTrue);
    expect(await Banco([f]).motor.diagnostico(Fuente.modelo), isEmpty);
  });
}
