// Fuente B del motor de voz (modelo descargable): reproducción por turnos y por
// frases, marca de carga, prueba de humo, pausa, borrado y cadena del motor.
// Todo con la puerta de síntesis, el reproductor, el gestor y el disco
// simulados: no hay biblioteca nativa, sonido ni red (la prueba con la
// biblioteca real está en `puerta_sherpa_real_test.dart`).
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/gravity/voz/asignador.dart';
import 'package:gravity/modulos/gravity/voz/audio/reproductor_de_audio.dart';
import 'package:gravity/modulos/gravity/voz/descarga/gestor_falso.dart';
import 'package:gravity/modulos/gravity/voz/fuente_falsa.dart';
import 'package:gravity/modulos/gravity/voz/fuentes/modelo/fuente_modelo.dart';
import 'package:gravity/modulos/gravity/voz/fuentes/modelo/puerta_sintesis.dart';
import 'package:gravity/modulos/gravity/voz/modelos/estado_modelo.dart';
import 'package:gravity/modulos/gravity/voz/motor.dart';
import 'package:gravity/modulos/gravity/voz/preferencias.dart';
import 'package:gravity/modulos/gravity/voz/tipos.dart';

import '../ayuda_modelos.dart';

/// Un reproductor que, al abrir un archivo, guarda cómo empezaba (para ver
/// que es un WAV de verdad) y que existía en el disco.
class ReproductorQueMira extends ReproductorDeAudioFalso {
  ReproductorQueMira(this.disco, {super.duracion, super.manual});
  final SistemaDeArchivosEnMemoria disco;
  final encabezados = <String>[];
  final existian = <bool>[];

  @override
  Future<void> abrir(String rutaDeArchivo) async {
    final b = disco.archivos[rutaDeArchivo];
    existian.add(b != null);
    encabezados.add(b == null ? '' : String.fromCharCodes(b.take(4)));
    await super.abrir(rutaDeArchivo);
  }
}

typedef Montaje = ({
  FuenteModelo fuente,
  GestorDeModelosFalso gestor,
  PuertaSintesisFalsa puerta,
  ReproductorQueMira reproductor,
  SistemaDeArchivosEnMemoria disco,
});

Guion guion(
  List<(VozDeGuion, String)> turnos, {
  Variante variante = Variante.enUS,
}) => Guion(
  id: 'g',
  variante: variante,
  pausaEntreTurnos: Duration.zero,
  turnos: [for (final (v, t) in turnos) Turno(voz: v, texto: t)],
);

const dialogo = [
  (VozDeGuion.f1, 'Good morning.'),
  (VozDeGuion.m1, 'Hello there.'),
  (VozDeGuion.f1, 'Nice day.'),
  (VozDeGuion.m1, 'Yes it is.'),
];

Asignacion asignacionAnaBeto() => const Asignacion(
  Fuente.modelo,
  Variante.enUS,
  {VozDeGuion.f1: 'ana/0', VozDeGuion.m1: 'beto/0'},
);

void main() {
  late ContenidoDePrueba contenido;

  setUp(() => contenido = ContenidoDePrueba());

  Montaje montar({
    List<String> instalados = const ['ana', 'beto'],
    bool manual = false,
    Duration duracion = Duration.zero,
  }) {
    final disco = SistemaDeArchivosEnMemoria();
    final gestor = GestorDeModelosFalso(
      contenido.catalogo().modelos,
      estados: {for (final id in instalados) id: EstadoModelo.instalado},
    );
    final puerta = PuertaSintesisFalsa();
    final reproductor = ReproductorQueMira(
      disco,
      manual: manual,
      duracion: duracion,
    );
    final fuente = FuenteModelo(
      gestor: gestor,
      puerta: puerta,
      crearReproductor: () => reproductor,
      carpetaTemporal: () async => '/tmp/gravity-voz',
      archivos: disco,
    );
    return (
      fuente: fuente,
      gestor: gestor,
      puerta: puerta,
      reproductor: reproductor,
      disco: disco,
    );
  }

  /// Las peticiones de la puerta sin la prueba de humo.
  List<PeticionDeSintesis> frases(Montaje m) => [
    for (final p in m.puerta.peticiones)
      if (p.texto != fraseDePruebaDeHumo) p,
  ];

  /// Deja pasar el tiempo para que corran las tareas pendientes.
  Future<void> dejarCorrer() async {
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  group('voces y disponibilidad', () {
    test('sin modelos instalados no ofrece ninguna voz', () async {
      final m = montar(instalados: const []);
      expect(await m.fuente.voces(Variante.enUS), isEmpty);
      expect(m.fuente.tipo, Fuente.modelo);
    });

    test(
      'ofrece las voces de los modelos instalados, con género y acento',
      () async {
        final m = montar(instalados: const ['ana', 'beto', 'cori']);
        final us = await m.fuente.voces(Variante.enUS);
        expect(us.map((v) => v.id), ['ana/0', 'beto/0']);
        expect(us.map((v) => v.nombre), ['Ana', 'Beto']);
        expect(us.map((v) => v.genero), [Genero.mujer, Genero.hombre]);
        expect(us.every((v) => v.local && v.fuente == Fuente.modelo), isTrue);
        final gb = await m.fuente.voces(Variante.enGB);
        expect(gb.single.id, 'cori/0');
        expect(await m.fuente.voces(Variante.esMX), isEmpty);
      },
    );

    test('un modelo dañado o a medias no ofrece sus voces', () async {
      final m = montar(instalados: const ['ana']);
      m.gestor.poner('beto', EstadoModelo.corrupto);
      m.gestor.poner('cori', EstadoModelo.descargando);
      expect((await m.fuente.voces(Variante.enUS)).map((v) => v.id), ['ana/0']);
      expect(await m.fuente.voces(Variante.enGB), isEmpty);
    });

    test(
      'dice por qué no hay voces: no descargada, o no hay modelo en ese idioma',
      () {
        final m = montar(instalados: const []);
        expect(
          m.fuente.motivoSinVoces(Variante.enUS),
          Motivo.modeloNoInstalado,
        );
        expect(
          m.fuente.motivoSinVoces(Variante.enGB),
          Motivo.modeloNoInstalado,
        );
        expect(m.fuente.motivoSinVoces(Variante.esMX), Motivo.sinVozEnElIdioma);
      },
    );

    test('motivoNoDisponible: sin modelo, con voces de menos y con una voz repetida', () async {
      final solo = montar(instalados: const []);
      expect(
        await solo.fuente.motivoNoDisponible(
          guion(dialogo),
          asignacionAnaBeto(),
        ),
        Motivo.modeloNoInstalado,
      );
      final una = montar(instalados: const ['ana']);
      expect(
        await una.fuente.motivoNoDisponible(
          guion(dialogo),
          asignacionAnaBeto(),
        ),
        Motivo.vocesInsuficientes,
      );
      final dos = montar();
      expect(
        await dos.fuente.motivoNoDisponible(
          guion(dialogo),
          asignacionAnaBeto(),
        ),
        isNull,
      );
      const repetida = Asignacion(Fuente.modelo, Variante.enUS, {
        VozDeGuion.f1: 'ana/0',
        VozDeGuion.m1: 'ana/0',
      });
      expect(
        await dos.fuente.motivoNoDisponible(guion(dialogo), repetida),
        Motivo.vocesInsuficientes,
        reason: 'nunca la misma voz para dos papeles (criterio 4)',
      );
    });

    test('el asignador por género reparte una mujer y un hombre', () async {
      final m = montar();
      final voces = await m.fuente.voces(Variante.enUS);
      final a = const AsignadorPorGenero().proponer(
        Fuente.modelo,
        Variante.enUS,
        voces,
        roles: {VozDeGuion.f1, VozDeGuion.m1},
      );
      expect(a.idVozMotor, {VozDeGuion.f1: 'ana/0', VozDeGuion.m1: 'beto/0'});
    });

    test('capacidades: sin tono ni avance por palabra, con pausa', () {
      final c = montar().fuente.capacidades;
      expect(c.tono, isFalse);
      expect(c.progresoPorPalabra, isFalse);
      expect(c.pausa, isTrue);
      expect(c.ajustarVelocidad(2.0), 1.5);
      expect(c.ajustarVelocidad(0.1), 0.5);
    });
  });

  group('criterios 3, 5 y 6: un diálogo de dos voces', () {
    test(
      'cada turno suena con la voz asignada, en orden, y con modelos distintos',
      () async {
        final m = montar();
        final r = await m.fuente.reproducir(
          guion(dialogo),
          asignacionAnaBeto(),
          1.0,
        );
        expect(await r.terminada, Fin.completa);
        final f = frases(m);
        expect(f.map((p) => (p.idModelo, p.sid, p.texto)), [
          ('ana', 0, 'Good morning.'),
          ('beto', 0, 'Hello there.'),
          ('ana', 0, 'Nice day.'),
          ('beto', 0, 'Yes it is.'),
        ]);
        expect(r.fuente, Fuente.modelo);
        expect(m.reproductor.abiertos, hasLength(4));
      },
    );

    test(
      'criterio 5: el avance emite los turnos en orden y sin el texto',
      () async {
        final m = montar();
        final r = await m.fuente.reproducir(
          guion(dialogo),
          asignacionAnaBeto(),
          1.0,
        );
        final avances = await r.avance.toList();
        expect(avances.map((a) => a.turno), [0, 1, 2, 3]);
        expect(avances.map((a) => a.voz), [
          VozDeGuion.f1,
          VozDeGuion.m1,
          VozDeGuion.f1,
          VozDeGuion.m1,
        ]);
        for (final a in avances) {
          final t = a.toString();
          for (final palabra in ['Good', 'morning', 'Hello', 'Nice', 'Yes']) {
            expect(t, isNot(contains(palabra)));
          }
        }
      },
    );

    test('criterio 6: la velocidad llega a cada síntesis tal cual', () async {
      for (final v in [0.8, 1.0]) {
        final m = montar();
        final r = await m.fuente.reproducir(
          guion(dialogo),
          asignacionAnaBeto(),
          v,
        );
        await r.terminada;
        expect(frases(m).map((p) => p.velocidad).toSet(), {v}, reason: '$v');
      }
    });

    test(
      'el reproductor recibe un WAV de verdad y se borra al terminar',
      () async {
        final m = montar();
        final r = await m.fuente.reproducir(
          guion(dialogo),
          asignacionAnaBeto(),
          1.0,
        );
        await r.terminada;
        await dejarCorrer();
        expect(m.reproductor.encabezados, everyElement('RIFF'));
        expect(m.reproductor.existian, everyElement(isTrue));
        expect(
          m.disco.archivos.keys.where((k) => k.endsWith('.wav')),
          isEmpty,
          reason: 'los temporales se borran',
        );
      },
    );

    test('un turno largo se parte en frases y se genera una por una', () async {
      final m = montar();
      final r = await m.fuente.reproducir(
        guion([(VozDeGuion.f1, 'One two. Three four five? Six!')]),
        asignacionAnaBeto(),
        1.0,
      );
      await r.terminada;
      expect(frases(m).map((p) => p.texto), [
        'One two.',
        'Three four five?',
        'Six!',
      ]);
      expect(m.reproductor.abiertos, hasLength(3));
      expect((await r.avance.toList()).map((a) => a.turno), [
        0,
      ], reason: 'un turno, un avance, aunque tenga varias frases');
    });

    test(
      'mientras suena una frase ya se genera la siguiente (adelanto de una)',
      () async {
        final m = montar(manual: true);
        final r = await m.fuente.reproducir(
          guion([(VozDeGuion.f1, 'One. Two. Three.')]),
          asignacionAnaBeto(),
          1.0,
        );
        await dejarCorrer();
        expect(m.reproductor.sonando, isTrue);
        expect(frases(m).map((p) => p.texto), [
          'One.',
          'Two.',
        ], reason: 'suena la 1 y la 2 ya está pedida; la 3 espera');
        m.reproductor.terminarArchivo();
        await dejarCorrer();
        expect(frases(m).map((p) => p.texto), ['One.', 'Two.', 'Three.']);
        m.reproductor.terminarArchivo();
        await dejarCorrer();
        m.reproductor.terminarArchivo();
        expect(await r.terminada, Fin.completa);
      },
    );

    test('un texto sin nada que decir no suena ni pide nada', () async {
      final m = montar();
      final r = await m.fuente.reproducir(
        guion([(VozDeGuion.f1, '   ')]),
        asignacionAnaBeto(),
        1.0,
      );
      expect(await r.terminada, Fin.completa);
      expect(m.reproductor.abiertos, isEmpty);
    });

    test(
      'una voz que no existe en la asignación falla con un código',
      () async {
        final m = montar();
        await expectLater(
          m.fuente.reproducir(
            guion(dialogo),
            const Asignacion(Fuente.modelo, Variante.enUS, {
              VozDeGuion.f1: 'ana/0',
            }),
            1.0,
          ),
          throwsA(
            isA<FalloDeSintesis>().having(
              (e) => e.codigo,
              'código',
              'voz_no_encontrada',
            ),
          ),
        );
        await expectLater(
          m.fuente.reproducir(
            guion([(VozDeGuion.f1, 'x')]),
            const Asignacion(Fuente.modelo, Variante.enUS, {
              VozDeGuion.f1: 'no/9',
            }),
            1.0,
          ),
          throwsA(isA<FalloDeSintesis>()),
        );
      },
    );
  });

  group('criterio 7: pausar, reanudar y parar', () {
    test(
      'pausar corta la frase y reanudar la repite sin volver a sintetizar',
      () async {
        final m = montar(manual: true);
        final r = await m.fuente.reproducir(
          guion([(VozDeGuion.f1, 'One. Two.')]),
          asignacionAnaBeto(),
          1.0,
        );
        await dejarCorrer();
        expect(m.reproductor.sonando, isTrue);
        final pedidas = frases(m).length;
        await r.pausar();
        await dejarCorrer();
        expect(m.reproductor.sonando, isFalse);
        expect(m.reproductor.cortes, 1);
        await r.reanudar();
        await dejarCorrer();
        expect(m.reproductor.sonando, isTrue);
        expect(
          frases(m).length,
          pedidas,
          reason: 'lo ya sintetizado no se vuelve a pedir',
        );
        expect(
          m.reproductor.abiertos.first,
          m.reproductor.abiertos[1],
          reason: 'repite la misma frase, desde su principio',
        );
        m.reproductor.terminarArchivo();
        await dejarCorrer();
        m.reproductor.terminarArchivo();
        expect(await r.terminada, Fin.completa);
      },
    );

    test('pausar en la segunda frase retoma en la segunda, no en el principio del turno', () async {
      final m = montar(manual: true);
      final r = await m.fuente.reproducir(
        guion([(VozDeGuion.f1, 'One. Two.')]),
        asignacionAnaBeto(),
        1.0,
      );
      await dejarCorrer();
      m.reproductor.terminarArchivo(); // termina la 1
      await dejarCorrer();
      await r.pausar();
      await dejarCorrer();
      await r.reanudar();
      await dejarCorrer();
      // Se abrieron: la 1, la 2 y la 2 otra vez; la 1 no se repite.
      expect(m.reproductor.abiertos, hasLength(3));
      expect(m.reproductor.abiertos[1], m.reproductor.abiertos[2]);
      m.reproductor.terminarArchivo();
      expect(await r.terminada, Fin.completa);
    });

    test(
      'parar completa con Fin.parada, corta el audio y borra los temporales',
      () async {
        final m = montar(manual: true);
        final r = await m.fuente.reproducir(
          guion(dialogo),
          asignacionAnaBeto(),
          1.0,
        );
        await dejarCorrer();
        expect(m.reproductor.sonando, isTrue);
        await r.parar();
        expect(await r.terminada, Fin.parada);
        await dejarCorrer();
        expect(m.reproductor.cortes, 1);
        expect(m.disco.archivos.keys.where((k) => k.endsWith('.wav')), isEmpty);
        // Después se puede reproducir otra cosa.
        m.reproductor.manual = false;
        final otra = await m.fuente.reproducir(
          guion(dialogo),
          asignacionAnaBeto(),
          1.0,
        );
        expect(await otra.terminada, Fin.completa);
      },
    );

    test('parar mientras todavía se sintetiza no deja sonar nada', () async {
      final m = montar();
      m.puerta.compuerta = Completer<void>();
      final r = await m.fuente.reproducir(
        guion([(VozDeGuion.f1, 'One. Two.')]),
        asignacionAnaBeto(),
        1.0,
      );
      await dejarCorrer();
      await r.parar();
      m.puerta.compuerta!.complete();
      expect(await r.terminada, Fin.parada);
      await dejarCorrer();
      expect(m.reproductor.abiertos, isEmpty);
    });
  });

  group('criterio 26: marca de carga y prueba de humo', () {
    test('la primera vez marca la carga, prueba una frase fija y la desmarca; las siguientes no', () async {
      final m = montar();
      final r = await m.fuente.reproducir(
        guion(dialogo),
        asignacionAnaBeto(),
        1.0,
      );
      await r.terminada;
      expect(m.gestor.cargasIniciadas, ['ana', 'beto']);
      expect(m.gestor.cargasTerminadas, ['ana', 'beto']);
      expect(
        m.puerta.peticiones
            .where((p) => p.texto == fraseDePruebaDeHumo)
            .map((p) => p.idModelo),
        ['ana', 'beto'],
      );
      // La prueba de humo va antes de lo que se dice.
      expect(m.puerta.peticiones.first.texto, fraseDePruebaDeHumo);
      final otra = await m.fuente.reproducir(
        guion(dialogo),
        asignacionAnaBeto(),
        1.0,
      );
      await otra.terminada;
      expect(m.gestor.cargasIniciadas, [
        'ana',
        'beto',
      ], reason: 'ya probados en esta sesión');
    });

    test(
      'carga solo las rutas que da el gestor, con el lexicón (R10)',
      () async {
        final m = montar();
        final r = await m.fuente.reproducir(
          guion(dialogo),
          asignacionAnaBeto(),
          1.0,
        );
        await r.terminada;
        final c = m.puerta.cargas.first;
        expect(c.idModelo, 'ana');
        expect(c.rutaModelo, '/falso/ana/ana.onnx');
        expect(c.rutaTokens, '/falso/ana/tokens.txt');
        expect(c.rutaLexicon, '/falso/ana/lexicon-en-us.txt');
        expect(c.hilos, 2);
      },
    );

    test('si el modelo ya no está instalado no se carga', () async {
      final m = montar();
      m.gestor.poner('ana', EstadoModelo.corrupto);
      final r = await m.fuente.reproducir(
        guion(dialogo),
        asignacionAnaBeto(),
        1.0,
      );
      await expectLater(
        r.terminada,
        throwsA(
          isA<FalloDeSintesis>().having(
            (e) => e.codigo,
            'código',
            'modelo_no_instalado',
          ),
        ),
      );
      expect(m.puerta.cargas, isEmpty);
    });

    test('si la carga falla de forma atrapable, el modelo queda dañado y no se desmarca', () async {
      final m = montar();
      m.puerta.fallarAlCargar = 'carga_fallida';
      final r = await m.fuente.reproducir(
        guion(dialogo),
        asignacionAnaBeto(),
        1.0,
      );
      await expectLater(r.terminada, throwsA(isA<FalloDeSintesis>()));
      expect(m.gestor.marcadosCorruptos, ['ana']);
      expect(await m.gestor.estado('ana'), EstadoModelo.corrupto);
      expect(m.gestor.cargasTerminadas, isEmpty);
      // Ya no ofrece su voz hasta que se reintente.
      expect((await m.fuente.voces(Variante.enUS)).map((v) => v.id), [
        'beto/0',
      ]);
    });

    test('la prueba de humo atrapa el audio vacío y marca el modelo', () async {
      final m = montar();
      m.puerta.audioVacio = true;
      final r = await m.fuente.reproducir(
        guion(dialogo),
        asignacionAnaBeto(),
        1.0,
      );
      await expectLater(
        r.terminada,
        throwsA(
          isA<FalloDeSintesis>().having(
            (e) => e.codigo,
            'código',
            'prueba_de_humo',
          ),
        ),
      );
      expect(m.gestor.marcadosCorruptos, ['ana']);
    });

    test('si falla el entorno (sin biblioteca nativa) el modelo NO se marca dañado', () async {
      final m = montar();
      m.puerta.fallarAlCargar = 'biblioteca_no_disponible';
      final r = await m.fuente.reproducir(
        guion(dialogo),
        asignacionAnaBeto(),
        1.0,
      );
      await expectLater(r.terminada, throwsA(isA<FalloDeSintesis>()));
      expect(m.gestor.marcadosCorruptos, isEmpty);
      expect(m.gestor.cargasTerminadas, [
        'ana',
      ], reason: 'se quita la marca: no fue culpa del modelo');
      expect(await m.gestor.estado('ana'), EstadoModelo.instalado);
    });

    test(
      'audio vacío en una frase del curso es un fallo con código, no silencio',
      () async {
        final m = montar();
        final r = await m.fuente.reproducir(
          guion(dialogo),
          asignacionAnaBeto(),
          1.0,
        );
        await r.terminada; // la primera pasa (humo y frases con audio)
        m.puerta.audioVacio = true;
        final otra = await m.fuente.reproducir(
          guion(dialogo),
          asignacionAnaBeto(),
          1.0,
        );
        await expectLater(
          otra.terminada,
          throwsA(
            isA<FalloDeSintesis>().having(
              (e) => e.codigo,
              'código',
              'audio_vacio',
            ),
          ),
        );
      },
    );
  });

  group('criterio 16: ningún error ni registro lleva el texto', () {
    test('un fallo de síntesis no deja el texto en el error ni en lo que se registra', () async {
      final registro = <String>[];
      final anterior = debugPrint;
      debugPrint = (String? mensaje, {int? wrapWidth}) =>
          registro.add(mensaje ?? '');
      addTearDown(() => debugPrint = anterior);

      final m = montar();
      m.puerta.fallarEnLaPeticion = 2; // 0 es la prueba de humo
      final r = await m.fuente.reproducir(
        guion([
          (VozDeGuion.f1, 'Primera SECRETO-XYZ. Segunda SECRETO-XYZ. Tercera.'),
        ]),
        asignacionAnaBeto(),
        1.0,
      );
      Object? error;
      try {
        await r.terminada;
      } on Object catch (e) {
        error = e;
      }
      expect(error, isA<FalloDeSintesis>());
      expect('$error', isNot(contains('SECRETO')));
      expect(registro.join('\n'), isNot(contains('SECRETO')));
      final avances = await r.avance.toList();
      for (final a in avances) {
        expect('$a', isNot(contains('SECRETO')));
      }
      expect(m.puerta.cargas.toString(), isNot(contains('SECRETO')));
    });

    test('un fallo del reproductor tampoco lleva el texto', () async {
      final m = montar();
      final falla = _ReproductorQueFalla();
      final fuente = FuenteModelo(
        gestor: m.gestor,
        puerta: m.puerta,
        crearReproductor: () => falla,
        carpetaTemporal: () async => '/tmp/x',
        archivos: m.disco,
      );
      final r = await fuente.reproducir(
        guion([(VozDeGuion.f1, 'Texto SECRETO-XYZ.')]),
        asignacionAnaBeto(),
        1.0,
      );
      Object? error;
      try {
        await r.terminada;
      } on Object catch (e) {
        error = e;
      }
      expect(error, isA<FalloDeSintesis>());
      expect('$error', isNot(contains('SECRETO')));
      expect((error! as FalloDeSintesis).codigo, 'reproduccion');
    });
  });

  group('criterio 10: sin conexión', () {
    test('con un modelo ya descargado, reproducir no abre ninguna conexión ni pide descargar nada', () async {
      final m = montar();
      await HttpOverrides.runWithHttpOverrides(() async {
        final r = await m.fuente.reproducir(
          guion(dialogo),
          asignacionAnaBeto(),
          1.0,
        );
        expect(await r.terminada, Fin.completa);
      }, _SinRed());
      expect(m.gestor.descargasPedidas, isEmpty);
    });
  });

  group('con el motor: cadena y borrado (criterios 25, 32 y 34)', () {
    MotorDeVoz motor(
      Montaje m, {
      FuenteDeVozFalsa? a,
      PreferenciasVoz? prefs,
    }) => MotorDeVoz(
      fuentes: [a ?? FuenteDeVozFalsa(), m.fuente],
      preferencias: () => prefs ?? const PreferenciasVoz(),
    );

    test('con B instalado entra en la cadena del curso, antes de A', () async {
      final m = montar();
      final d = await motor(m)
          .disponibilidad(UsoVoz.curso, variante: Variante.enUS);
      expect(d.cadena, [Fuente.modelo, Fuente.dispositivo]);
      expect(d.descartadas[Fuente.pregrabado], Motivo.sinPaqueteDeAudio);
    });

    test('en la cadena del asistente (español) A va primero y B dice que no hay voz en ese idioma', () async {
      final m = montar();
      final d = await motor(m).disponibilidad(UsoVoz.asistente);
      expect(d.cadena, [Fuente.dispositivo]);
      expect(d.descartadas[Fuente.modelo], Motivo.sinVozEnElIdioma);
    });

    test(
      'sin B descargado, dice "no está descargada" y la cadena sigue con A',
      () async {
        final m = montar(instalados: const []);
        final d = await motor(m)
            .disponibilidad(UsoVoz.curso, variante: Variante.enUS);
        expect(d.cadena, [Fuente.dispositivo]);
        expect(d.descartadas[Fuente.modelo], Motivo.modeloNoInstalado);
      },
    );

    test(
      'criterio 34: con "solo esta fuente" y B sin instalar no usa otra',
      () async {
        final m = montar(instalados: const []);
        final a = FuenteDeVozFalsa();
        final mo = motor(m, a: a);
        await expectLater(
          mo.reproducir(guion(dialogo), soloFuente: Fuente.modelo),
          throwsA(
            isA<SinFuenteDisponible>().having((e) => e.motivos, 'motivos', {
              Fuente.modelo: Motivo.modeloNoInstalado,
            }),
          ),
        );
        expect(a.reproducciones, 0);
      },
    );

    test(
      'criterio 32: con B preferida y "solo esta fuente", no hay respaldo',
      () async {
        final m = montar(instalados: const []);
        const prefs = PreferenciasVoz(
          curso: PreferenciasDeUso(fuente: Fuente.modelo, soloEstaFuente: true),
        );
        final d = await motor(
          m,
          prefs: prefs,
        ).disponibilidad(UsoVoz.curso, variante: Variante.enUS);
        expect(d.cadena, isEmpty);
      },
    );

    test(
      'reproduce con B cuando está disponible y Reproduccion.fuente lo dice',
      () async {
        final m = montar();
        final a = FuenteDeVozFalsa();
        final r = await motor(m, a: a).reproducir(guion(dialogo));
        expect(r.fuente, Fuente.modelo);
        expect(await r.terminada, Fin.completa);
        expect(a.reproducciones, 0);
        expect(frases(m).map((p) => p.idModelo).toSet(), {'ana', 'beto'});
      },
    );

    test('"Probar" una voz concreta: vocesElegidas fija la voz sin tocar las preferencias', () async {
      final m = montar();
      final r = await motor(m).reproducir(
        guion([(VozDeGuion.m1, 'Probando.')]),
        soloFuente: Fuente.modelo,
        vocesElegidas: {VozDeGuion.m1: 'beto/0'},
      );
      await r.terminada;
      expect(frases(m).single.idModelo, 'beto');
    });

    test(
      'vocesElegidas con una voz que no existe descarta la fuente',
      () async {
        final m = montar();
        await expectLater(
          motor(m).reproducir(
            guion([(VozDeGuion.m1, 'x')]),
            soloFuente: Fuente.modelo,
            vocesElegidas: {VozDeGuion.m1: 'nadie/3'},
          ),
          throwsA(
            isA<SinFuenteDisponible>().having(
              (e) => e.motivos[Fuente.modelo],
              'motivo',
              Motivo.vocesInsuficientes,
            ),
          ),
        );
      },
    );

    test('criterio 25: borrar el modelo que suena lo para, lo suelta y la cadena cae a A', () async {
      final m = montar(manual: true);
      final a = FuenteDeVozFalsa();
      final mo = motor(m, a: a);
      final r = await mo.reproducir(guion(dialogo), soloFuente: Fuente.modelo);
      await dejarCorrer();
      expect(m.reproductor.sonando, isTrue);

      final liberados = await m.gestor.borrar('ana');
      expect(liberados, greaterThan(0));
      await dejarCorrer();
      expect(m.reproductor.sonando, isFalse, reason: 'se paró antes de borrar');
      expect(await r.terminada, Fin.parada);
      expect(m.puerta.liberados, [
        'ana',
      ], reason: 'el modelo se soltó de la memoria');
      expect(await m.gestor.estado('ana'), EstadoModelo.noDescargado);

      final d = await mo.disponibilidad(
        UsoVoz.curso,
        variante: Variante.enUS,
        vocesNecesarias: 2,
      );
      expect(d.cadena, [
        Fuente.dispositivo,
      ], reason: 'ya no hay dos voces de B');
      expect(d.descartadas[Fuente.modelo], Motivo.vocesInsuficientes);
      expect(
        (await mo.voces(
          Fuente.modelo,
          variante: Variante.enUS,
        )).map((v) => v.id),
        ['beto/0'],
        reason: 'la voz borrada ya no se ofrece',
      );
      m.reproductor.manual = false;
      final siguiente = await mo.reproducir(guion(dialogo));
      expect(siguiente.fuente, Fuente.dispositivo);
      await siguiente.terminada;
    });

    test('borrar un modelo que no suena no toca lo que suena', () async {
      final m = montar(manual: true, instalados: const ['ana', 'beto', 'cori']);
      final mo = motor(m);
      final r = await mo.reproducir(
        guion([(VozDeGuion.f1, 'Hola mundo.')]),
        soloFuente: Fuente.modelo,
        vocesElegidas: {VozDeGuion.f1: 'ana/0'},
      );
      await dejarCorrer();
      await m.gestor.borrar('cori');
      await dejarCorrer();
      expect(m.reproductor.sonando, isTrue);
      m.reproductor.terminarArchivo();
      expect(await r.terminada, Fin.completa);
    });
  });

  group('limpieza', () {
    test('limpiarTemporales borra la carpeta de WAV', () async {
      final m = montar();
      m.disco.archivos['/tmp/gravity-voz/7.wav'] = [1, 2, 3];
      m.disco.archivos['/otra/cosa.txt'] = [1];
      await m.fuente.limpiarTemporales();
      expect(m.disco.archivos.keys, ['/otra/cosa.txt']);
    });

    test(
      'cerrar libera la puerta y el reproductor y para lo que suene',
      () async {
        final m = montar(manual: true);
        final r = await m.fuente.reproducir(
          guion(dialogo),
          asignacionAnaBeto(),
          1.0,
        );
        await dejarCorrer();
        await m.fuente.cerrar();
        expect(await r.terminada, Fin.parada);
        expect(m.puerta.cerrada, isTrue);
        expect(m.reproductor.liberado, isTrue);
      },
    );
  });
}

class _ReproductorQueFalla extends ReproductorDeAudioFalso {
  @override
  Future<void> abrir(String rutaDeArchivo) async =>
      throw StateError('Texto SECRETO-XYZ en el mensaje del plugin');
}

class _SinRed extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      throw StateError('Se abrió una conexión');
}
