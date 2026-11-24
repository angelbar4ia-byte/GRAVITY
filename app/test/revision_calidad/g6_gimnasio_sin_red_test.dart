// G6 · Revisión de cierre del gimnasio: SIN RED (R7, 9.1, CA-G-32, H-12).
//
// La especificación dice que «todo lo de la sesión funciona sin red» y que
// Hábitos no puede arrastrar a la sesión al patrón de escribir directo a
// Supabase (H-12). Las pruebas de G5 usan siempre la agenda y los registros de
// Hábitos EN MEMORIA, así que nunca ven el caso real: en la app, esos dos
// repositorios (`RepositorioAgendaSupabase` y `RepositorioHabitosSupabase`)
// piden y escriben a la red, y `ServicioGimnasio` los llama sin protección para
// armar «lo de hoy» (`entrenamientoDe`) y al terminar (`terminarSesion`).
//
// Aquí se simula la falta de señal con repositorios que lanzan `SocketException`
// (lo que lanza el cliente de Supabase sin conexión). Corregido: ya no llevan la
// etiqueta `hallazgo`.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/habitos/datos/repositorio.dart';
import 'package:gravity/modulos/habitos/datos/repositorio_agenda.dart';
import 'package:gravity/modulos/habitos/gimnasio/casos_uso/servicio_gimnasio.dart';

import '../modulos/habitos/gimnasio/ayuda_gimnasio_app.dart';

/// Cualquier llamada falla como lo haría el cliente de Supabase sin señal.
class AgendaSinRed implements RepositorioAgenda {
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw const SocketException('Failed host lookup: supabase.co');
}

class RegistrosSinRed implements RepositorioHabitos {
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw const SocketException('Failed host lookup: supabase.co');
}

void main() {
  late Mundo m;
  setUp(() => m = Mundo());
  tearDown(() => m.cerrar());

  ServicioGimnasio sinRed({bool agenda = true, bool registros = true}) =>
      ServicioGimnasio(
        repo: m.repo,
        persona: persona,
        agenda: agenda ? AgendaSinRed() : m.agenda,
        registros: registros ? RegistrosSinRed() : m.registros,
        molestias: m.molestias,
        ahora: () => m.ahoraActual,
      );

  group('G6-A1 · sin señal, Mi gimnasio debe seguir con lo local', () {
    test(
      'abrir «lo de hoy» sin red no lanza: usa el plan y el equipo guardados '
      'en el teléfono',
      () async {
        final h = await sinRed().entrenamientoDe(lunes30);
        expect(h.tipo, 'A');
        expect(h.sesion, isNotNull);
      },
    );

    test(
      'terminar la sesión sin red no lanza (la sesión ya quedó guardada y el '
      'registro del día espera la señal)',
      () async {
        // Con señal se abre y se empieza (el día queda en el teléfono).
        final conRed = m.servicio;
        final d = await conRed.cargar();
        final h = await conRed.entrenamientoDe(lunes30, datos: d);
        final fila = await conRed.iniciarSesion(h);
        // Sin señal se termina.
        await sinRed(agenda: false).terminarSesion(
          fila: fila,
          h: h,
          completa: true,
          esfuerzo: 3,
          energia: 3,
        );
        expect((await m.repo.sesiones(persona)).single.estado, 'completa');
      },
    );

    test(
      'control: la sesión SÍ queda guardada en el teléfono antes de que falle '
      'el registro del día (no se pierde nada)',
      () async {
        final d = await m.servicio.cargar();
        final h = await m.servicio.entrenamientoDe(lunes30, datos: d);
        final fila = await m.servicio.iniciarSesion(h);
        Object? error;
        try {
          await sinRed(agenda: false)
              .terminarSesion(fila: fila, h: h, completa: true);
        } catch (e) {
          error = e;
        }
        expect((await m.repo.sesiones(persona)).single.estado, 'completa');
        // Hoy lanza (ese es el hallazgo); el control solo exige que no se
        // perdió la sesión.
        expect(error == null || error is SocketException, isTrue);
      },
    );
  });
}
