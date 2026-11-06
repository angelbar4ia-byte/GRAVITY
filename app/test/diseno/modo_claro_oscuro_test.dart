import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/diseno/diseno.dart';

import 'ayuda_pruebas.dart';

DateTime _a(int hora, int minuto) => DateTime(2026, 10, 20, hora, minuto);

Brightness _auto(DateTime t, [HorarioClaro h = HorarioClaro.porDefecto]) =>
    decidirBrillo(
      modo: ModoClaroOscuro.automaticoPorHora,
      ahora: t,
      horario: h,
    );

void main() {
  group('Claro/oscuro automático por hora (07:00 a 19:00 por defecto)', () {
    test('06:59 es oscuro', () {
      expect(_auto(_a(6, 59)), Brightness.dark);
    });

    test('07:00 es claro', () {
      expect(_auto(_a(7, 0)), Brightness.light);
    });

    test('18:59 es claro', () {
      expect(_auto(_a(18, 59)), Brightness.light);
    });

    test('19:00 es oscuro', () {
      expect(_auto(_a(19, 0)), Brightness.dark);
    });

    test('medianoche es oscuro y mediodía es claro', () {
      expect(_auto(_a(0, 0)), Brightness.dark);
      expect(_auto(_a(12, 0)), Brightness.light);
    });
  });

  group('Horario personalizado', () {
    const horario = HorarioClaro(
      inicio: TimeOfDay(hour: 6, minute: 30),
      fin: TimeOfDay(hour: 20, minute: 15),
    );

    test('respeta los nuevos límites', () {
      expect(_auto(_a(6, 29), horario), Brightness.dark);
      expect(_auto(_a(6, 30), horario), Brightness.light);
      expect(_auto(_a(20, 14), horario), Brightness.light);
      expect(_auto(_a(20, 15), horario), Brightness.dark);
    });

    test('un horario que cruza la medianoche', () {
      const nocturno = HorarioClaro(
        inicio: TimeOfDay(hour: 22, minute: 0),
        fin: TimeOfDay(hour: 6, minute: 0),
      );
      expect(_auto(_a(21, 59), nocturno), Brightness.dark);
      expect(_auto(_a(22, 0), nocturno), Brightness.light);
      expect(_auto(_a(5, 59), nocturno), Brightness.light);
      expect(_auto(_a(6, 0), nocturno), Brightness.dark);
    });

    test('inicio igual a fin: nunca es claro', () {
      const vacio = HorarioClaro(
        inicio: TimeOfDay(hour: 8, minute: 0),
        fin: TimeOfDay(hour: 8, minute: 0),
      );
      expect(_auto(_a(8, 0), vacio), Brightness.dark);
      expect(_auto(_a(13, 0), vacio), Brightness.dark);
    });
  });

  group('Modos fijos y del sistema', () {
    test('claro y oscuro no dependen de la hora', () {
      for (final t in [_a(3, 0), _a(12, 0), _a(23, 0)]) {
        expect(
          decidirBrillo(modo: ModoClaroOscuro.claro, ahora: t),
          Brightness.light,
        );
        expect(
          decidirBrillo(modo: ModoClaroOscuro.oscuro, ahora: t),
          Brightness.dark,
        );
      }
    });

    test('sistema sigue al sistema operativo', () {
      expect(
        decidirBrillo(
          modo: ModoClaroOscuro.sistema,
          ahora: _a(12, 0),
          brilloSistema: Brightness.dark,
        ),
        Brightness.dark,
      );
      expect(
        modoTemaPara(modo: ModoClaroOscuro.sistema, ahora: _a(12, 0)),
        ThemeMode.system,
      );
    });
  });

  group('Proveedores', () {
    ProviderContainer contenedor(DateTime momento) {
      final c = ProviderContainer(
        overrides: [relojProvider.overrideWithValue(RelojFijo(momento))],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('por defecto es automático: 19:42 da tema oscuro', () {
      final c = contenedor(_a(19, 42));
      expect(
        c.read(preferenciaClaroOscuroProvider).modo,
        ModoClaroOscuro.automaticoPorHora,
      );
      expect(c.read(modoTemaProvider), ThemeMode.dark);
    });

    test('editar el horario cambia el resultado al instante', () {
      final c = contenedor(_a(19, 42));
      c
          .read(preferenciaClaroOscuroProvider.notifier)
          .cambiarHorario(
            const HorarioClaro(fin: TimeOfDay(hour: 20, minute: 30)),
          );
      expect(c.read(modoTemaProvider), ThemeMode.light);
    });

    test('elegir un modo fijo', () {
      final c = contenedor(_a(10, 0));
      expect(c.read(modoTemaProvider), ThemeMode.light);
      c
          .read(preferenciaClaroOscuroProvider.notifier)
          .cambiarModo(ModoClaroOscuro.oscuro);
      expect(c.read(modoTemaProvider), ThemeMode.dark);
    });
  });

  testWidgets('el tema pasa a oscuro solo al dar las 19:00, sin reiniciar', (
    tester,
  ) async {
    final reloj = RelojMovible(DateTime(2026, 10, 20, 18, 59, 30));
    late Brightness brillo;
    await montar(
      tester,
      Builder(
        builder: (context) {
          brillo = Theme.of(context).brightness;
          return const SizedBox();
        },
      ),
      reloj: reloj,
    );
    expect(brillo, Brightness.light);

    reloj.momento = DateTime(2026, 10, 20, 19, 0, 0);
    await tester.pump(const Duration(seconds: 31));
    await tester.pump(duracionCambioTema);
    expect(brillo, Brightness.dark);
  });
}
