// Preferencias de voz por persona (criterio 36) y su almacén.
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/diseno/proveedores.dart' show personaEnPantallaProvider;
import 'package:gravity/modulos/gravity/voz/preferencias.dart';
import 'package:gravity/modulos/gravity/voz/tipos.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PersonaActual extends Notifier<String?> {
  @override
  String? build() => null;
  void poner(String? id) => state = id;
}

final _persona = NotifierProvider<_PersonaActual, String?>(_PersonaActual.new);

ProviderContainer contenedor(AlmacenVoz almacen) {
  final c = ProviderContainer(
    overrides: [
      almacenVozProvider.overrideWithValue(almacen),
      personaEnPantallaProvider.overrideWith((ref) => ref.watch(_persona)),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('por omisión: automática, sin "solo", velocidad normal, sin voces elegidas', () {
    final c = contenedor(AlmacenVozMemoria());
    final p = c.read(preferenciasVozProvider);
    expect(p.curso.fuente, isNull);
    expect(p.curso.soloEstaFuente, isFalse);
    expect(p.asistente.velocidad, 1.0);
    expect(p.asignaciones, isEmpty);
  });

  test('la lectura en voz alta es por persona, apagada por omisión, y sobrevive al reinicio', () {
    final almacen = AlmacenVozMemoria();
    final c = contenedor(almacen);
    expect(c.read(preferenciasVozProvider).leerRespuestas, isFalse);
    c.read(_persona.notifier).poner('ana');
    c.read(preferenciasVozProvider.notifier).fijarLeerRespuestas(true);
    c.read(_persona.notifier).poner('beto');
    expect(c.read(preferenciasVozProvider).leerRespuestas, isFalse);
    // Reinicio de la app: contenedor nuevo, mismo almacén.
    final otra = contenedor(almacen);
    otra.read(_persona.notifier).poner('ana');
    expect(otra.read(preferenciasVozProvider).leerRespuestas, isTrue);
    // Encenderla no cambia el resto de lo guardado.
    c.read(_persona.notifier).poner('ana');
    c.read(preferenciasVozProvider.notifier).fijarVelocidad(UsoVoz.asistente, 0.7);
    expect(c.read(preferenciasVozProvider).leerRespuestas, isTrue);
    c.read(preferenciasVozProvider.notifier).fijarLeerRespuestas(false);
    expect(
      PreferenciasVoz.deJson(
        jsonDecode(jsonEncode(c.read(preferenciasVozProvider).aJson())),
      ).leerRespuestas,
      isFalse,
    );
  });

  test('dos personas en el mismo equipo tienen preferencias distintas y la cuenta Casa, las suyas (criterio 36)', () {
    final almacen = AlmacenVozMemoria();
    final c = contenedor(almacen);
    final n = c.read(preferenciasVozProvider.notifier);

    c.read(_persona.notifier).poner('ana');
    n.fijarVelocidad(UsoVoz.asistente, 0.7);
    n.fijarAsignacion(Fuente.dispositivo, Variante.esMX, {VozDeGuion.f1: 'voz-ana'});
    expect(c.read(preferenciasVozProvider).asistente.velocidad, 0.7);

    c.read(_persona.notifier).poner('beto');
    // Cambiar de persona cambia la voz sin reiniciar.
    expect(c.read(preferenciasVozProvider).asistente.velocidad, 1.0);
    expect(c.read(preferenciasVozProvider).asignaciones, isEmpty);
    c.read(preferenciasVozProvider.notifier).fijarVelocidad(UsoVoz.asistente, 1.3);

    c.read(_persona.notifier).poner(null); // tablet de la casa
    expect(c.read(preferenciasVozProvider).asistente.velocidad, 1.0);
    c.read(preferenciasVozProvider.notifier).fijarVelocidad(UsoVoz.asistente, 0.9);

    c.read(_persona.notifier).poner('ana');
    expect(c.read(preferenciasVozProvider).asistente.velocidad, 0.7);
    expect(
      c.read(preferenciasVozProvider).asignacionDe(Fuente.dispositivo, Variante.esMX),
      {VozDeGuion.f1: 'voz-ana'},
    );
    c.read(_persona.notifier).poner('beto');
    expect(c.read(preferenciasVozProvider).asistente.velocidad, 1.3);
    c.read(_persona.notifier).poner(null);
    expect(c.read(preferenciasVozProvider).asistente.velocidad, 0.9);
  });

  test('lo guardado sobrevive a un contenedor nuevo (reinicio de la app)', () {
    final almacen = AlmacenVozMemoria();
    final c1 = contenedor(almacen);
    c1.read(_persona.notifier).poner('ana');
    c1.read(preferenciasVozProvider.notifier)
      ..fijarFuente(UsoVoz.curso, Fuente.dispositivo)
      ..fijarSoloEstaFuente(UsoVoz.curso, true)
      ..fijarVelocidad(UsoVoz.asistente, 0.8);
    c1.dispose();

    final c2 = contenedor(almacen);
    c2.read(_persona.notifier).poner('ana');
    final p = c2.read(preferenciasVozProvider);
    expect(p.curso.fuente, Fuente.dispositivo);
    expect(p.curso.soloEstaFuente, isTrue);
    expect(p.asistente.velocidad, 0.8);
  });

  test('quitar la fuente elegida apaga "solo esta fuente"', () {
    final c = contenedor(AlmacenVozMemoria());
    final n = c.read(preferenciasVozProvider.notifier)
      ..fijarFuente(UsoVoz.curso, Fuente.modelo)
      ..fijarSoloEstaFuente(UsoVoz.curso, true);
    expect(c.read(preferenciasVozProvider).curso.soloEstaFuente, isTrue);
    n.fijarFuente(UsoVoz.curso, null);
    expect(c.read(preferenciasVozProvider).curso.fuente, isNull);
    expect(c.read(preferenciasVozProvider).curso.soloEstaFuente, isFalse);
  });

  test('la velocidad se limita a lo que se ofrece', () {
    final c = contenedor(AlmacenVozMemoria());
    final n = c.read(preferenciasVozProvider.notifier);
    n.fijarVelocidad(UsoVoz.asistente, 9);
    expect(c.read(preferenciasVozProvider).asistente.velocidad, velocidadVozMaxima);
    n.fijarVelocidad(UsoVoz.asistente, 0);
    expect(c.read(preferenciasVozProvider).asistente.velocidad, velocidadVozMinima);
  });

  test('cambiar la asignación de una fuente y variante no toca las demás', () {
    final c = contenedor(AlmacenVozMemoria());
    final n = c.read(preferenciasVozProvider.notifier)
      ..fijarAsignacion(Fuente.dispositivo, Variante.enUS, {VozDeGuion.f1: 'a', VozDeGuion.m1: 'b'})
      ..fijarAsignacion(Fuente.dispositivo, Variante.enGB, {VozDeGuion.f1: 'g'})
      ..fijarAsignacion(Fuente.dispositivo, Variante.enUS, {VozDeGuion.f1: 'c'});
    final p = c.read(preferenciasVozProvider);
    expect(p.asignacionDe(Fuente.dispositivo, Variante.enUS), {VozDeGuion.f1: 'c'});
    expect(p.asignacionDe(Fuente.dispositivo, Variante.enGB), {VozDeGuion.f1: 'g'});
    expect(n, isNotNull);
  });

  group('lo guardado se lee con cuidado', () {
    test('un texto dañado deja los valores por omisión', () {
      final almacen = AlmacenVozMemoria()..guardar('hogar', '{no es json');
      final c = contenedor(almacen);
      expect(c.read(preferenciasVozProvider).asistente.velocidad, 1.0);
    });

    test('valores de tipo equivocado se ignoran uno por uno', () {
      final p = PreferenciasVoz.deJson(
        jsonDecode(
          jsonEncode({
            'curso': {'fuente': 'inventada', 'solo': 'sí', 'vel': 'rápido'},
            'asistente': {'fuente': 'dispositivo', 'vel': 99},
            'asig': {'dispositivo/en-US/F1': 'x', 'mala': 3, 'otra': ''},
          }),
        ),
      );
      expect(p.curso.fuente, isNull);
      expect(p.curso.soloEstaFuente, isFalse);
      expect(p.curso.velocidad, 1.0);
      expect(p.asistente.fuente, Fuente.dispositivo);
      expect(p.asistente.velocidad, velocidadVozMaxima);
      expect(p.asignaciones, {'dispositivo/en-US/F1': 'x'});
      expect(PreferenciasVoz.deJson(42).asistente.velocidad, 1.0);
      expect(PreferenciasVoz.deJson(null).asignaciones, isEmpty);
    });

    test('no se guarda nada sensible: solo fuente, velocidad y voces', () {
      final almacen = AlmacenVozMemoria();
      final c = contenedor(almacen);
      c.read(preferenciasVozProvider.notifier).fijarVelocidad(UsoVoz.asistente, 0.9);
      final texto = almacen.leer('hogar')!;
      expect(jsonDecode(texto), {
        'v': 1,
        'curso': {'solo': false, 'vel': 1.0},
        'asistente': {'solo': false, 'vel': 0.9},
        'asig': <String, Object?>{},
      });
    });
  });

  group('AlmacenVozPersistente (shared_preferences)', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('guarda y lee con el prefijo voz/ y borra con null', () async {
      final a = await AlmacenVozPersistente.abrir();
      expect(a.leer('ana'), isNull);
      a.guardar('ana', '{"v":1}');
      expect(a.leer('ana'), '{"v":1}');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('voz/ana'), '{"v":1}');
      a.guardar('ana', null);
      expect(a.leer('ana'), isNull);
    });

    test('lo guardado por una instancia lo lee la siguiente', () async {
      final a = await AlmacenVozPersistente.abrir();
      a.guardar('hogar', 'x');
      await Future<void>.delayed(Duration.zero);
      final b = await AlmacenVozPersistente.abrir();
      expect(b.leer('hogar'), 'x');
    });
  });
}
