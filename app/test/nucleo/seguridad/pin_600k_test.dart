// PIN de 600 000 vueltas (P10 del dueño, D22): en hilo aparte, con migración
// de los PIN guardados con 100 000 (y 10 000) y medición del costo.
//
// La medición de esta máquina se imprime en el reporte de la prueba; la del
// Galaxy A52 la hace el dueño con el medidor de la app (fase 4, sección 16).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/seguridad/cifrado.dart';
import 'package:gravity/nucleo/seguridad/pin.dart';
import 'package:gravity/nucleo/seguridad/serie_pin.dart';

void main() {
  final porOmision = HashPin.iteracionesPorDefecto;
  tearDown(() => HashPin.iteracionesPorDefecto = porOmision);

  test('los hashes nuevos llevan 600 000 vueltas y verifican (hilo aparte)', () async {
    HashPin.iteracionesPorDefecto = HashPin.iteracionesActuales;
    final reloj = Stopwatch()..start();
    final hash = await HashPin.crearAsync('738291');
    final crear = reloj.elapsedMilliseconds;
    reloj
      ..reset()
      ..start();
    final bueno = await HashPin.verificarAsync('738291', hash);
    final malo = await HashPin.verificarAsync('738290', hash);
    final verificar = reloj.elapsedMilliseconds ~/ 2;
    expect(hash, contains(r'$600000$'));
    expect(bueno, isTrue);
    expect(malo, isFalse);
    // ignore: avoid_print
    print(
      'MEDICIÓN (esta máquina, hilo aparte): crear 600 000 vueltas = $crear ms; '
      'verificar = $verificar ms.',
    );
    // Tope generoso para no depender de la máquina que corra la prueba.
    expect(crear, lessThan(30000), reason: 'crear: $crear ms');
    expect(verificar, lessThan(30000), reason: 'verificar: $verificar ms');
  });

  test('la versión asíncrona da el mismo hash que la síncrona', () async {
    HashPin.iteracionesPorDefecto = 6000; // pasa el umbral del hilo aparte
    final sal = List<int>.generate(16, (i) => i);
    final sincrono = HashPin.crear('738291', sal: sal);
    final asincrono = await HashPin.crearAsync('738291', sal: sal);
    expect(asincrono, sincrono);
    expect(await HashPin.verificarAsync('738291', sincrono), isTrue);
    expect(await HashPin.verificarAsync('000001', sincrono), isFalse);
    final llaveS = HashPin.derivarLlave('738291', sal);
    final llaveA = await HashPin.derivarLlaveAsync('738291', sal);
    expect(llaveA, llaveS);
  });

  test('un PIN guardado con 100 000 vueltas sigue verificando y pide rehacerse', () async {
    final viejo = HashPin.crear(
      '738291',
      iteraciones: HashPin.iteraciones100k,
    );
    HashPin.iteracionesPorDefecto = HashPin.iteracionesActuales;
    expect(HashPin.iteracionesDe(viejo), 100000);
    expect(HashPin.necesitaActualizarse(viejo), isTrue);
    expect(await HashPin.verificarAsync('738291', viejo), isTrue);
    expect(await HashPin.verificarAsync('738292', viejo), isFalse);
    // Se rehace con las de hoy al escribir el PIN.
    final nuevo = await HashPin.crearAsync('738291');
    expect(HashPin.iteracionesDe(nuevo), 600000);
    expect(HashPin.necesitaActualizarse(nuevo), isFalse);
    expect(await HashPin.verificarAsync('738291', nuevo), isTrue);
  });

  test('un sobre del PIN hecho con 100 000 vueltas se abre y se vuelve a cifrar con 600 000', () async {
    final llaveVieja = LlavePin.derivar(
      '738291',
      iteraciones: HashPin.iteraciones100k,
    );
    final sobre = CifradoPin.cifrar(llaveVieja, 'credencial-de-ejemplo');
    expect(jsonDecode(sobre)['it'], 100000);
    HashPin.iteracionesPorDefecto = HashPin.iteracionesActuales;
    final abierto = await CifradoPin.descifrarAsync('738291', sobre);
    expect(abierto, isNotNull);
    expect(abierto!.$2, 'credencial-de-ejemplo');
    expect(abierto.$1.iteraciones, 100000);
    expect(await CifradoPin.descifrarAsync('111111', sobre), isNull);
    final llaveNueva = await LlavePin.derivarAsync('738291');
    expect(llaveNueva.iteraciones, 600000);
    final nuevo = CifradoPin.cifrar(llaveNueva, 'credencial-de-ejemplo');
    expect(jsonDecode(nuevo)['it'], 600000);
    expect((await CifradoPin.descifrarAsync('738291', nuevo))!.$2, 'credencial-de-ejemplo');
  });

  test('SerieDePin: las verificaciones van una tras otra', () async {
    final serie = SerieDePin();
    final orden = <String>[];
    final a = serie.correr(() async {
      orden.add('a1');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      orden.add('a2');
      return 1;
    });
    final b = serie.correr(() async {
      orden.add('b1');
      return 2;
    });
    final c = serie.correr<int>(() async => throw StateError('falla'));
    final d = serie.correr(() async {
      orden.add('d1');
      return 4;
    });
    expect(await a, 1);
    expect(await b, 2);
    await expectLater(c, throwsStateError);
    expect(await d, 4);
    expect(orden, ['a1', 'a2', 'b1', 'd1']);
  });
}
