// «Hecho» sin series NO cuenta para el objetivo «Entrenamiento» (decisión del
// dueño, 25/nov/2026): para sumar al objetivo y a la meta semanal hace falta al
// menos una serie registrada. Sin series queda como nota del día (la sesión y el
// bloque de la agenda), y la pantalla lo dice sin culpa.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/gimnasio/acceso_gimnasio.dart';
import 'package:gravity/modulos/habitos/datos/modelos.dart';
import 'package:gravity/modulos/habitos/gimnasio/casos_uso/servicio_gimnasio.dart';
import 'package:gravity/modulos/habitos/gimnasio/pantallas/comun.dart';
import 'package:habitos_dominio/habitos_dominio.dart' hide EstadoDiaPlan;

import 'ayuda_gimnasio_app.dart';

void main() {
  late Mundo m;
  setUp(() => m = Mundo());
  tearDown(() => m.cerrar());

  Future<List<RegistroHab>> delDia() => m.registros.registros(
    DateTime.utc(2026, 11, 30),
    DateTime.utc(2026, 11, 30),
  );

  Future<List<RegistroHab>> delObjetivo() async => [
    for (final r in await delDia())
      if (r.objetivoId == idObjetivoEntrenamiento(persona)) r,
  ];

  group('servicio', () {
    test('Hecho de un toque: la sesión y el bloque quedan, el objetivo no suma', () async {
      await m.servicio.ponerEnMiAgenda(await m.servicio.cargar());
      final h = await m.servicio.entrenamientoDe(lunes30);
      final r = await m.servicio.marcarHecho(h);
      expect(r.sinSeries, isTrue);
      expect(r.estado, EstadoSesion.completa);
      expect((await m.repo.sesiones(persona)).single.estado, 'completa');
      final regs = await delDia();
      // El bloque de la agenda sí queda hecho (la nota del día).
      expect(regs.where((x) => x.bloqueId != null).single.estado, EstadoRegistro.hecho);
      // El objetivo y su meta semanal: nada.
      expect(await delObjetivo(), isEmpty);
    });

    test('sin agenda, Hecho sin series no escribe nada en el objetivo', () async {
      final h = await m.servicio.entrenamientoDe(lunes30);
      await m.servicio.marcarHecho(h);
      expect(await delDia(), isEmpty);
      expect(await m.registros.objetivos(), isEmpty);
    });

    test('CASO MALO: con una serie registrada, la sesión sí suma al objetivo', () async {
      final d = await m.servicio.cargar();
      final h = await m.servicio.entrenamientoDe(lunes30, datos: d);
      final fila = await m.servicio.iniciarSesion(h);
      final e = h.sesion!.ejercicios.first;
      await m.servicio.registrarSerie(
        sesionId: fila.id,
        ejercicio: e,
        varianteId: e.varianteId,
        n: 1,
        reps: e.rangoMin,
      );
      final r = await m.servicio.terminarSesion(fila: fila, h: h, completa: true);
      expect(r.sinSeries, isFalse);
      final obj = await delObjetivo();
      expect(obj.single.estado, EstadoRegistro.hecho);
    });

    test('una sesión parcial con una serie suma como parcial', () async {
      final d = await m.servicio.cargar();
      final h = await m.servicio.entrenamientoDe(lunes30, datos: d);
      final fila = await m.servicio.iniciarSesion(h);
      final e = h.sesion!.ejercicios.first;
      await m.servicio.registrarSerie(
        sesionId: fila.id,
        ejercicio: e,
        varianteId: e.varianteId,
        n: 1,
        reps: e.rangoMin,
      );
      await m.servicio.terminarSesion(fila: fila, h: h, completa: false);
      expect((await delObjetivo()).single.estado, EstadoRegistro.parcial);
    });

    test('terminar sin haber registrado nada también queda como nota', () async {
      final d = await m.servicio.cargar();
      final h = await m.servicio.entrenamientoDe(lunes30, datos: d);
      final fila = await m.servicio.iniciarSesion(h);
      final r = await m.servicio.terminarSesion(fila: fila, h: h, completa: true);
      expect(r.sinSeries, isTrue);
      expect(await delObjetivo(), isEmpty);
    });

    test('deshacer Hecho sin series no toca el objetivo', () async {
      await m.servicio.ponerEnMiAgenda(await m.servicio.cargar());
      final h = await m.servicio.entrenamientoDe(lunes30);
      await m.servicio.marcarHecho(h);
      await m.servicio.deshacerHecho(await m.servicio.entrenamientoDe(lunes30));
      expect(await delObjetivo(), isEmpty);
      expect(await m.repo.sesiones(persona), isEmpty);
    });

    test('una regenerativa nunca marca sinSeries (no tiene series)', () async {
      final h = await m.servicio.entrenamientoDe(lunes30, tipo: 'R1');
      final r = await m.servicio.marcarHecho(h);
      expect(r.sinSeries, isFalse);
    });
  });

  group('pantalla', () {
    testWidgets('E1 Hecho dice sin culpa que no suma y cómo sumar', (t) async {
      await m.servicio.aceptarAviso();
      await montarPantalla(t, m, DestinoGimnasio.hoy);
      await t.tap(find.byKey(const ValueKey('entrenamiento-hecho')));
      await t.pumpAndSettle();
      expect(find.textContaining(TextosHabitosGimnasio.sinSeriesNoSuma), findsOneWidget);
      expect(await delObjetivo(), isEmpty);
      // Sin culpa: ni «no cuenta», ni «fallaste», ni signos de exclamación.
      final t0 = TextosHabitosGimnasio.sinSeriesNoSuma.toLowerCase();
      expect(t0, isNot(contains('!')));
      expect(t0, isNot(contains('fall')));
      expect(t0, isNot(contains('no cuenta')));
    });
  });
}
