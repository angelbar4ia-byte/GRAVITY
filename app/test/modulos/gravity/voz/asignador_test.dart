// Asignación de voces del motor a las voces de un guion (criterio 4).
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/gravity/voz/asignador.dart';
import 'package:gravity/modulos/gravity/voz/fuente_falsa.dart';
import 'package:gravity/modulos/gravity/voz/tipos.dart';

VozMotor voz(String id, Genero genero, {Variante v = Variante.enUS}) => VozMotor(
  id: id,
  fuente: Fuente.dispositivo,
  nombre: id,
  variante: v,
  genero: genero,
  local: true,
);

void main() {
  const asignador = AsignadorPorGenero();

  test('mujeres para F1 y F2, hombres para M1 y M2, N con la que sobre', () {
    final voces = [
      voz('h1', Genero.hombre),
      voz('m1', Genero.mujer),
      voz('m2', Genero.mujer),
      voz('h2', Genero.hombre),
      voz('x', Genero.sinDato),
    ];
    final a = asignador.proponer(Fuente.dispositivo, Variante.enUS, voces);
    expect(a.idVozMotor, {
      VozDeGuion.f1: 'm1',
      VozDeGuion.f2: 'm2',
      VozDeGuion.m1: 'h1',
      VozDeGuion.m2: 'h2',
      VozDeGuion.n: 'x',
    });
    expect(a.sinRepetidas, isTrue);
  });

  test('con las voces de ejemplo en inglés americano nunca repite una voz', () {
    final voces = vocesDeEjemplo()
        .where((v) => v.variante == Variante.enUS)
        .toList();
    final a = asignador.proponer(Fuente.dispositivo, Variante.enUS, voces);
    expect(a.idVozMotor.length, 5);
    expect(a.sinRepetidas, isTrue);
  });

  test('sin dato de género (Android): voces distintas en orden', () {
    final voces = [for (var i = 0; i < 3; i++) voz('v$i', Genero.sinDato)];
    final a = asignador.proponer(
      Fuente.dispositivo,
      Variante.enUS,
      voces,
      roles: {VozDeGuion.f1, VozDeGuion.m1},
    );
    expect(a.idVozMotor, {VozDeGuion.f1: 'v0', VozDeGuion.m1: 'v1'});
  });

  test('una voz con género conocido no ocupa el lugar del otro género', () {
    // Solo hay mujeres: M1 queda sin voz en vez de repetir o cruzar género.
    final voces = [voz('m1', Genero.mujer), voz('m2', Genero.mujer)];
    final a = asignador.proponer(
      Fuente.dispositivo,
      Variante.enUS,
      voces,
      roles: {VozDeGuion.f1, VozDeGuion.m1},
    );
    expect(a.idVozMotor, {VozDeGuion.f1: 'm1'});
  });

  test('una voz sin género no le quita su lugar a quien sí lo necesita', () {
    final voces = [voz('x', Genero.sinDato), voz('h', Genero.hombre)];
    final a = asignador.proponer(
      Fuente.dispositivo,
      Variante.enUS,
      voces,
      roles: {VozDeGuion.m1, VozDeGuion.f1},
    );
    // M1 toma al hombre; F1, como no hay mujer, toma la voz sin dato.
    expect(a.idVozMotor, {VozDeGuion.m1: 'h', VozDeGuion.f1: 'x'});
  });

  test('con menos voces que papeles, los que faltan quedan sin voz', () {
    final voces = [voz('a', Genero.sinDato), voz('b', Genero.sinDato)];
    final a = asignador.proponer(Fuente.dispositivo, Variante.enUS, voces);
    expect(a.idVozMotor.length, 2);
    expect(a.sinRepetidas, isTrue);
  });

  group('resolverAsignacion', () {
    final voces = [
      voz('a', Genero.sinDato),
      voz('b', Genero.sinDato),
      voz('c', Genero.sinDato),
    ];

    test('respeta lo elegido y completa el resto sin repetir', () {
      final a = resolverAsignacion(
        asignador: asignador,
        fuente: Fuente.dispositivo,
        variante: Variante.enUS,
        voces: voces,
        roles: {VozDeGuion.f1, VozDeGuion.m1},
        guardadas: {VozDeGuion.f1: 'c'},
      );
      expect(a.idVozMotor[VozDeGuion.f1], 'c');
      expect(a.idVozMotor[VozDeGuion.m1], isNot('c'));
      expect(a.sinRepetidas, isTrue);
    });

    test('ignora una voz guardada que ya no existe', () {
      final a = resolverAsignacion(
        asignador: asignador,
        fuente: Fuente.dispositivo,
        variante: Variante.enUS,
        voces: voces,
        roles: {VozDeGuion.f1},
        guardadas: {VozDeGuion.f1: 'borrada'},
      );
      expect(a.idVozMotor[VozDeGuion.f1], 'a');
    });

    test('una misma voz guardada para dos papeles solo vale para el primero', () {
      final a = resolverAsignacion(
        asignador: asignador,
        fuente: Fuente.dispositivo,
        variante: Variante.enUS,
        voces: voces,
        roles: {VozDeGuion.f1, VozDeGuion.f2},
        guardadas: {VozDeGuion.f1: 'b', VozDeGuion.f2: 'b'},
      );
      expect(a.idVozMotor[VozDeGuion.f1], 'b');
      expect(a.idVozMotor[VozDeGuion.f2], isNot('b'));
      expect(a.sinRepetidas, isTrue);
    });

    test('solo asigna los papeles que pide el guion', () {
      final a = resolverAsignacion(
        asignador: asignador,
        fuente: Fuente.dispositivo,
        variante: Variante.enUS,
        voces: voces,
        roles: {VozDeGuion.n},
      );
      expect(a.idVozMotor.keys, [VozDeGuion.n]);
    });
  });
}
