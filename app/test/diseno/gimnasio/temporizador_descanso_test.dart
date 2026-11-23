// Temporizador de descanso (CA-G-35, 7.2 y 10): cuenta hacia un instante
// final, sobrevive a girar y a segundo plano, vibra una vez y no suena,
// anuncia de 15 en 15 s, no anima con «reducir movimiento» y no usa
// `Timer.periodic`.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/diseno/diseno.dart';

import '../ayuda_pruebas.dart' show recolectarDesbordes;
import 'ayuda_gimnasio.dart';

void main() {
  final base = DateTime(2026, 11, 23, 19, 30);

  group('DescansoPlanificado (valor puro)', () {
    test('cuenta contra el instante final, nunca baja de cero', () {
      final d = DescansoPlanificado.iniciar(base, const Duration(seconds: 60));
      expect(d.instanteFinal, base.add(const Duration(seconds: 60)));
      expect(d.restante(base), const Duration(seconds: 60));
      expect(
        d.restante(base.add(const Duration(seconds: 45))),
        const Duration(seconds: 15),
      );
      expect(d.restante(base.add(const Duration(seconds: 90))), Duration.zero);
      expect(d.haTerminado(base.add(const Duration(seconds: 59))), isFalse);
      expect(d.haTerminado(base.add(const Duration(seconds: 60))), isTrue);
    });

    test('el avance va de 0 a 1', () {
      final d = DescansoPlanificado.iniciar(base, const Duration(seconds: 60));
      expect(d.avance(base), 0);
      expect(
        d.avance(base.add(const Duration(seconds: 30))),
        closeTo(0.5, 1e-9),
      );
      expect(d.avance(base.add(const Duration(seconds: 120))), 1);
    });

    test('+15 s y −15 s mueven el instante final', () {
      final d = DescansoPlanificado.iniciar(base, const Duration(seconds: 60));
      final mas = d.ajustar(const Duration(seconds: 15), base);
      expect(mas.restante(base), const Duration(seconds: 75));
      expect(mas.duracionTotal, const Duration(seconds: 75));
      final menos = d.ajustar(const Duration(seconds: -15), base);
      expect(menos.restante(base), const Duration(seconds: 45));
    });

    test('quitar más de lo que queda termina el descanso (caso malo)', () {
      final d = DescansoPlanificado.iniciar(base, const Duration(seconds: 60));
      final tarde = base.add(const Duration(seconds: 50));
      final r = d.ajustar(const Duration(seconds: -15), tarde);
      expect(r.haTerminado(tarde), isTrue);
      expect(r.restante(tarde), Duration.zero);
    });

    test('Saltar termina el descanso en el acto', () {
      final d = DescansoPlanificado.iniciar(base, const Duration(seconds: 60));
      expect(d.saltar(base).haTerminado(base), isTrue);
    });

    test('formato mm:ss redondea hacia arriba y se anuncia de 15 en 15', () {
      expect(formatoDescanso(const Duration(milliseconds: 48000)), '00:48');
      expect(formatoDescanso(const Duration(milliseconds: 47100)), '00:48');
      expect(formatoDescanso(const Duration(milliseconds: 100)), '00:01');
      expect(formatoDescanso(Duration.zero), '00:00');
      expect(formatoDescanso(const Duration(seconds: 75)), '01:15');
      expect(segundosAnunciados(const Duration(seconds: 48)), 45);
      expect(segundosAnunciados(const Duration(seconds: 30)), 30);
      expect(segundosAnunciados(const Duration(seconds: 14)), 0);
    });
  });

  group('TemporizadorDescanso (widget)', () {
    testWidgets('cuenta hacia el instante final y avisa el fin una sola vez', (
      tester,
    ) async {
      final reloj = RelojGimnasio(base);
      final vibraciones = escucharVibraciones(tester);
      var terminados = 0;
      await montarGim(
        tester,
        TemporizadorDescanso(
          descanso: DescansoPlanificado.iniciar(
            base,
            const Duration(seconds: 5),
          ),
          ahora: reloj.ahora,
          alTerminar: () => terminados++,
        ),
        sport: true,
      );
      expect(find.text('00:05'), findsOneWidget);
      await reloj.avanzar(tester, const Duration(seconds: 2));
      expect(find.text('00:03'), findsOneWidget);
      expect(vibraciones, isEmpty);
      await reloj.avanzar(tester, const Duration(seconds: 3));
      await tester.pump();
      expect(find.text('00:00'), findsOneWidget);
      expect(find.text(TextosGimnasio.descansoTerminado), findsOneWidget);
      // Vibra una vez y no hay sonido (solo HapticFeedback).
      expect(vibraciones, ['HapticFeedbackType.heavyImpact']);
      expect(terminados, 1);
      await reloj.avanzar(tester, const Duration(seconds: 10));
      expect(vibraciones, hasLength(1));
      expect(terminados, 1);
      await desmontar(tester);
    });

    testWidgets('sobrevive a girar la pantalla: el mismo instante da el mismo '
        'número', (tester) async {
      final reloj = RelojGimnasio(base);
      final d = DescansoPlanificado.iniciar(base, const Duration(seconds: 48));
      await montarGim(
        tester,
        TemporizadorDescanso(descanso: d, ahora: reloj.ahora),
        sport: true,
        ancho: 360,
      );
      await reloj.avanzar(tester, const Duration(seconds: 10));
      expect(find.text('00:38'), findsOneWidget);
      // Gira: la ventana pasa a horizontal y el árbol se vuelve a armar.
      await montarGim(
        tester,
        TemporizadorDescanso(descanso: d, ahora: reloj.ahora),
        sport: true,
        ventana: const Size(800, 360),
      );
      expect(find.text('00:38'), findsOneWidget);
      await desmontar(tester);
    });

    testWidgets('al volver de segundo plano pone el número que toca, aunque '
        'pasaran 30 s', (tester) async {
      final reloj = RelojGimnasio(base);
      final vibraciones = escucharVibraciones(tester);
      var terminados = 0;
      await montarGim(
        tester,
        TemporizadorDescanso(
          descanso: DescansoPlanificado.iniciar(
            base,
            const Duration(seconds: 48),
          ),
          ahora: reloj.ahora,
          alTerminar: () => terminados++,
        ),
        sport: true,
      );
      expect(find.text('00:48'), findsOneWidget);
      // La app pasa a segundo plano y el reloj sigue corriendo 30 s.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      reloj.momento = reloj.momento.add(const Duration(seconds: 30));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text('00:18'), findsOneWidget);
      expect(terminados, 0);
      // Pasa mucho más tiempo de lo que quedaba: ya terminó.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      reloj.momento = reloj.momento.add(const Duration(minutes: 5));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();
      expect(find.text(TextosGimnasio.descansoTerminado), findsOneWidget);
      expect(terminados, 1);
      // Terminó hace rato: no vibra «tarde» al volver.
      expect(vibraciones, isEmpty);
      await desmontar(tester);
    });

    testWidgets(
      '+15 s, −15 s y Saltar llaman a la pantalla con botones de 56 dp '
      'y etiqueta',
      (tester) async {
        final reloj = RelojGimnasio(base);
        final llamadas = <String>[];
        await montarGim(
          tester,
          TemporizadorDescanso(
            descanso: DescansoPlanificado.iniciar(
              base,
              const Duration(seconds: 48),
            ),
            ahora: reloj.ahora,
            alMasQuince: () => llamadas.add('+15'),
            alMenosQuince: () => llamadas.add('-15'),
            alSaltar: () => llamadas.add('saltar'),
          ),
          sport: true,
        );
        for (final texto in [
          TextosGimnasio.mas15,
          TextosGimnasio.menos15,
          TextosGimnasio.saltar,
        ]) {
          final boton = find.widgetWithText(OutlinedButton, texto);
          expect(boton, findsOneWidget);
          final tamano = tester.getSize(boton);
          expect(tamano.height, greaterThanOrEqualTo(56), reason: texto);
          expect(tamano.width, greaterThanOrEqualTo(56), reason: texto);
          await tester.tap(boton);
        }
        expect(llamadas, ['+15', '-15', 'saltar']);
        final handle = tester.ensureSemantics();
        expect(
          etiquetasAccesibles(tester),
          containsAll([
            'Agregar 15 segundos al descanso',
            'Quitar 15 segundos al descanso',
            'Saltar el descanso',
          ]),
        );
        // El lector de pantalla puede activarlos: llevan la acción de tocar.
        for (final etiqueta in [
          'Agregar 15 segundos al descanso',
          'Quitar 15 segundos al descanso',
          'Saltar el descanso',
        ]) {
          expect(
            tester
                .getSemantics(find.bySemanticsLabel(etiqueta))
                .getSemanticsData()
                .hasAction(SemanticsAction.tap),
            isTrue,
            reason: etiqueta,
          );
        }
        handle.dispose();
        await desmontar(tester);
      },
    );

    testWidgets('el lector de pantalla oye el tiempo de 15 en 15 s, no cada '
        'segundo', (tester) async {
      final handle = tester.ensureSemantics();
      final reloj = RelojGimnasio(base);
      await montarGim(
        tester,
        TemporizadorDescanso(
          descanso: DescansoPlanificado.iniciar(
            base,
            const Duration(seconds: 60),
          ),
          ahora: reloj.ahora,
        ),
        sport: true,
      );
      expect(etiquetasAccesibles(tester), contains('Descanso: 60 segundos'));
      await reloj.avanzar(tester, const Duration(seconds: 3));
      // Sigue diciendo 45 hasta llegar a 45: la etiqueta no cambia por segundo.
      expect(etiquetasAccesibles(tester), contains('Descanso: 45 segundos'));
      await reloj.avanzar(tester, const Duration(seconds: 20));
      expect(etiquetasAccesibles(tester), contains('Descanso: 30 segundos'));
      await reloj.avanzar(tester, const Duration(seconds: 40));
      await tester.pump();
      expect(etiquetasAccesibles(tester), contains('Descanso terminado'));
      handle.dispose();
      await desmontar(tester);
    });

    testWidgets('con «reducir movimiento» no dibuja el aro: solo el número', (
      tester,
    ) async {
      final reloj = RelojGimnasio(base);
      final d = DescansoPlanificado.iniciar(base, const Duration(seconds: 48));
      await montarGim(
        tester,
        TemporizadorDescanso(descanso: d, ahora: reloj.ahora),
        sport: true,
      );
      bool hayAro() => tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .any((p) => p.painter.runtimeType.toString() == '_AroDescanso');
      expect(hayAro(), isTrue);
      await montarGim(
        tester,
        TemporizadorDescanso(descanso: d, ahora: reloj.ahora),
        sport: true,
        reducirMovimiento: true,
      );
      expect(hayAro(), isFalse);
      expect(find.text('00:48'), findsOneWidget);
      await desmontar(tester);
    });

    testWidgets('la marca de fin lleva icono y palabras, no solo color', (
      tester,
    ) async {
      final reloj = RelojGimnasio(base);
      await montarGim(
        tester,
        TemporizadorDescanso(
          descanso: DescansoPlanificado.iniciar(
            base,
            const Duration(seconds: 1),
          ),
          ahora: reloj.ahora,
        ),
        sport: true,
      );
      await reloj.avanzar(tester, const Duration(seconds: 2));
      await tester.pump();
      expect(find.byKey(const ValueKey('descanso-terminado')), findsOneWidget);
      expect(find.byIcon(Icons.notifications_active_outlined), findsOneWidget);
      expect(find.text('Descanso terminado'), findsOneWidget);
      await desmontar(tester);
    });

    testWidgets('en la tablet el número mide más de 96 dp y en la sesión el '
        'temporizador mide 64 dp o más', (tester) async {
      final reloj = RelojGimnasio(base);
      final d = DescansoPlanificado.iniciar(base, const Duration(seconds: 48));
      expect(EscalaTemporizador.tablet.tamanoNumero, greaterThan(96));
      expect(EscalaTemporizador.sesion.tamanoNumero, greaterThanOrEqualTo(48));
      await montarGim(
        tester,
        TemporizadorDescanso(
          descanso: d,
          ahora: reloj.ahora,
          escala: EscalaTemporizador.tablet,
        ),
        sport: true,
        ancho: 900,
      );
      final texto = tester.widget<Text>(
        find.byKey(const ValueKey('descanso-restante')),
      );
      expect(texto.style!.fontSize, greaterThan(96));
      await montarGim(
        tester,
        TemporizadorDescanso(descanso: d, ahora: reloj.ahora),
        sport: true,
      );
      expect(
        tester.getSize(find.byType(TemporizadorDescanso)).height,
        greaterThanOrEqualTo(64),
      );
      await desmontar(tester);
    });

    testWidgets('estados: sin descanso, cargando, sin conexión y error', (
      tester,
    ) async {
      var reintentos = 0;
      for (final (estado, texto) in [
        (EstadoVistaGimnasio.vacio, TextosGimnasio.sinDescanso),
        (EstadoVistaGimnasio.cargando, 'Preparando el descanso…'),
        (
          EstadoVistaGimnasio.sinConexion,
          'Sin conexión. El descanso funciona igual.',
        ),
        (
          EstadoVistaGimnasio.error,
          'No se pudo iniciar el descanso. Puedes seguir sin él.',
        ),
      ]) {
        await montarGim(
          tester,
          TemporizadorDescanso(
            descanso: null,
            estado: estado,
            alReintentar: () => reintentos++,
          ),
          sport: true,
        );
        expect(find.text(texto), findsOneWidget, reason: '$estado');
      }
      await tester.tap(find.text(TextosGimnasio.reintentar));
      expect(reintentos, 1);
      // Sin descanso (null) en estado listo muestra el vacío.
      await montarGim(
        tester,
        const TemporizadorDescanso(descanso: null),
        sport: true,
      );
      expect(find.text(TextosGimnasio.sinDescanso), findsOneWidget);
      await desmontar(tester);
    });

    testWidgets('letra al 200 % en 360 dp sin desbordes', (tester) async {
      final reloj = RelojGimnasio(base);
      final desbordes = await recolectarDesbordes(() async {
        await montarGim(
          tester,
          TemporizadorDescanso(
            descanso: DescansoPlanificado.iniciar(
              base,
              const Duration(seconds: 48),
            ),
            ahora: reloj.ahora,
            alMasQuince: () {},
            alMenosQuince: () {},
            alSaltar: () {},
          ),
          sport: true,
          letra: 2.0,
        );
      });
      expect(desbordes, isEmpty);
      await desmontar(tester);
    });
  });

  test('el código no usa Timer.periodic ni reproduce sonidos', () {
    final fuente = File('lib/diseno/gimnasio/temporizador_descanso.dart')
        .readAsStringSync();
    final codigo = fuente
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');
    expect(codigo.contains('Timer.periodic'), isFalse);
    expect(codigo.contains('audioplayers'), isFalse);
    expect(codigo.contains('SystemSound'), isFalse);
    expect(codigo.contains('HapticFeedback'), isTrue);
  });
}
