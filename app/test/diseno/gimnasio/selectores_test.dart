// Selectores de la sesión (CA-G-04, CA-G-33, CA-G-34 y 10): repeticiones y
// carga en pasos, el estado «confirmar en el aparato», el tope de la pila y el
// botón ✓ de 64 dp.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/diseno/diseno.dart';

import '../ayuda_pruebas.dart' show recolectarDesbordes;
import 'ayuda_gimnasio.dart';

void main() {
  group('SelectorPasos', () {
    testWidgets('− y + miden 56 dp, cambian sin teclado y tienen etiqueta', (
      tester,
    ) async {
      var reps = 12;
      await montarGim(
        tester,
        StatefulBuilder(
          builder: (context, setState) => SelectorPasos(
            etiqueta: 'REPS',
            valorTexto: '$reps',
            descripcionAccesible: '$reps repeticiones',
            etiquetaMenos: 'Quitar una repetición',
            etiquetaMas: 'Agregar una repetición',
            alMenos: () => setState(() => reps--),
            alMas: () => setState(() => reps++),
          ),
        ),
        sport: true,
      );
      for (final icono in [Icons.remove, Icons.add]) {
        final boton = find.ancestor(
          of: find.byIcon(icono),
          matching: find.byType(InkWell),
        );
        final tamano = tester.getSize(boton);
        expect(tamano.width, greaterThanOrEqualTo(56));
        expect(tamano.height, greaterThanOrEqualTo(56));
      }
      await tester.tap(find.byIcon(Icons.add));
      await tester.tap(find.byIcon(Icons.add));
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();
      expect(find.text('13'), findsOneWidget);
      final handle = tester.ensureSemantics();
      expect(
        etiquetasAccesibles(tester),
        containsAll([
          'Quitar una repetición',
          'Agregar una repetición',
          '13 repeticiones',
        ]),
      );
      handle.dispose();
    });

    testWidgets('un botón sin acción se dice apagado y no responde', (
      tester,
    ) async {
      var toques = 0;
      await montarGim(
        tester,
        SelectorPasos(
          etiqueta: 'REPS',
          valorTexto: '1',
          etiquetaMenos: 'Quitar una repetición',
          etiquetaMas: 'Agregar una repetición',
          alMas: () => toques++,
        ),
        sport: true,
      );
      await tester.tap(find.byIcon(Icons.remove), warnIfMissed: false);
      expect(toques, 0);
      final handle = tester.ensureSemantics();
      final apagado = tester.getSemantics(
        find.bySemanticsLabel('Quitar una repetición'),
      );
      final encendido = tester.getSemantics(
        find.bySemanticsLabel('Agregar una repetición'),
      );
      expect(
        apagado.getSemanticsData().hasAction(SemanticsAction.tap),
        isFalse,
      );
      expect(
        encendido.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );
      handle.dispose();
    });
  });

  group('SelectorCarga', () {
    testWidgets('sin confirmar: carga en placas, sin kilos, con «Confirmar en '
        'el aparato» (CA-G-04)', (tester) async {
      var confirmar = 0;
      await montarGim(
        tester,
        SelectorCarga(
          valorTexto: 'Placa 3',
          // Aunque la pantalla pasara kilos, sin confirmar no se muestran.
          equivalenciaTexto: '≈ 20 kg',
          confirmacion: EstadoConfirmacionDato.confirmar,
          alMenos: () {},
          alMas: () {},
          alConfirmar: () => confirmar++,
        ),
        sport: true,
      );
      expect(find.text('Placa 3'), findsOneWidget);
      expect(find.text('≈ 20 kg'), findsNothing);
      expect(find.textContaining('kg'), findsNothing);
      expect(find.text(TextosGimnasio.sinKgHastaConfirmar), findsOneWidget);
      expect(find.text(EstadoConfirmacionDato.confirmar.texto), findsOneWidget);
      await tester.tap(
        find.widgetWithText(
          OutlinedButton,
          TextosGimnasio.confirmarEnElAparato,
        ),
      );
      expect(confirmar, 1);
    });

    testWidgets('confirmado muestra la equivalencia y el botón desaparece', (
      tester,
    ) async {
      await montarGim(
        tester,
        SelectorCarga(
          valorTexto: 'Placa 3',
          equivalenciaTexto: '≈ 20 kg',
          confirmacion: EstadoConfirmacionDato.confirmado,
          alMenos: () {},
          alMas: () {},
          alConfirmar: () {},
        ),
        sport: true,
      );
      expect(find.text('≈ 20 kg'), findsOneWidget);
      expect(find.text(TextosGimnasio.confirmarEnElAparato), findsNothing);
      expect(find.text(TextosGimnasio.confirmado), findsOneWidget);
    });

    testWidgets(
      'el botón Confirmar en el aparato mide 48 dp o más y responde',
      (tester) async {
        var confirmar = 0;
        await montarGim(
          tester,
          SelectorCarga(
            valorTexto: 'Placa 3',
            alMenos: () {},
            alMas: () {},
            alConfirmar: () => confirmar++,
          ),
          sport: true,
        );
        final boton = find.widgetWithText(
          OutlinedButton,
          TextosGimnasio.confirmarEnElAparato,
        );
        expect(tester.getSize(boton).height, greaterThanOrEqualTo(48));
        await tester.tap(boton);
        expect(confirmar, 1);
      },
    );

    testWidgets('en el tope no deja subir y lo dice con palabras', (
      tester,
    ) async {
      var sube = 0;
      await montarGim(
        tester,
        SelectorCarga(
          valorTexto: 'Placa 6',
          confirmacion: EstadoConfirmacionDato.confirmado,
          enTope: true,
          alMenos: () {},
          alMas: () => sube++,
        ),
        sport: true,
      );
      await tester.tap(find.byIcon(Icons.add), warnIfMissed: false);
      expect(sube, 0);
      expect(find.text('Última placa'), findsOneWidget);
      expect(find.text(TextosGimnasio.topeDePila), findsOneWidget);
    });

    testWidgets('sin punto de partida pide elegir una carga con esfuerzo 3', (
      tester,
    ) async {
      await montarGim(
        tester,
        const SelectorCarga(valorTexto: null),
        sport: true,
      );
      expect(find.text('Elige tu placa'), findsOneWidget);
      expect(find.text(TextosGimnasio.eligeTuCarga), findsOneWidget);
    });

    testWidgets('las bandas usan sus propias etiquetas', (tester) async {
      await montarGim(
        tester,
        SelectorCarga(
          unidad: UnidadCarga.banda,
          valorTexto: 'Banda verde',
          confirmacion: EstadoConfirmacionDato.confirmado,
          alMenos: () {},
          alMas: () {},
        ),
        sport: true,
      );
      final handle = tester.ensureSemantics();
      expect(
        etiquetasAccesibles(tester),
        containsAll(['Banda anterior', 'Banda siguiente']),
      );
      expect(find.text('BANDA'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('estados: vacío, cargando, sin conexión y error', (
      tester,
    ) async {
      var reintentos = 0;
      for (final estado in [
        EstadoVistaGimnasio.vacio,
        EstadoVistaGimnasio.cargando,
        EstadoVistaGimnasio.sinConexion,
        EstadoVistaGimnasio.error,
      ]) {
        await montarGim(
          tester,
          SelectorCarga(estado: estado, alReintentar: () => reintentos++),
          sport: true,
        );
        expect(find.byType(CuerpoEstadoGimnasio), findsOneWidget);
      }
      await tester.tap(find.text(TextosGimnasio.reintentar));
      expect(reintentos, 1);
      await desmontar(tester);
    });
  });

  group('BotonSerieHecha y PanelRegistroSerie', () {
    testWidgets('✓ mide 64 dp o más y guardar una serie cuesta un toque', (
      tester,
    ) async {
      var hechas = 0;
      await montarGim(
        tester,
        PanelRegistroSerie(
          serieActual: 2,
          seriesTotales: 3,
          repeticionesTexto: '12',
          alMenosReps: () {},
          alMasReps: () {},
          carga: SelectorCarga(
            valorTexto: 'Placa 3',
            alMenos: () {},
            alMas: () {},
          ),
          alHecha: () => hechas++,
        ),
        sport: true,
      );
      final boton = find.byKey(const ValueKey('boton-serie-hecha'));
      expect(tester.getSize(boton).height, greaterThanOrEqualTo(64));
      await tester.tap(boton);
      expect(hechas, 1);
      final handle = tester.ensureSemantics();
      expect(
        etiquetasAccesibles(tester),
        contains('Marcar la serie 2 de 3 como hecha'),
      );
      expect(
        tester
            .getSemantics(
              find.bySemanticsLabel('Marcar la serie 2 de 3 como hecha'),
            )
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );
      handle.dispose();
    });

    testWidgets('tras guardar muestra «Serie guardada» y Deshacer de 48 dp', (
      tester,
    ) async {
      var deshacer = 0;
      await montarGim(
        tester,
        BotonSerieHecha(
          alHecha: () {},
          guardada: true,
          alDeshacer: () => deshacer++,
        ),
        sport: true,
      );
      expect(find.text(TextosGimnasio.serieGuardada), findsOneWidget);
      final boton = find.widgetWithText(TextButton, TextosGimnasio.deshacer);
      expect(tester.getSize(boton).height, greaterThanOrEqualTo(48));
      await tester.tap(boton);
      expect(deshacer, 1);
    });

    testWidgets('letra al 200 % en 360 dp sin desbordes', (tester) async {
      final desbordes = await recolectarDesbordes(() async {
        await montarGim(
          tester,
          PanelRegistroSerie(
            serieActual: 12,
            seriesTotales: 12,
            repeticionesTexto: '100',
            alMenosReps: () {},
            alMasReps: () {},
            carga: SelectorCarga(
              valorTexto: 'Placa 12',
              equivalenciaTexto: '≈ 120 kg',
              confirmacion: EstadoConfirmacionDato.confirmado,
              enTope: true,
              alMenos: () {},
              alMas: () {},
            ),
            alHecha: () {},
            guardada: true,
            alDeshacer: () {},
          ),
          sport: true,
          letra: 2.0,
        );
      });
      expect(desbordes, isEmpty);
    });
  });
}
