import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/diseno/diseno.dart';
import 'package:gravity/modulos/gravity/pantalla/hoy_telefono.dart';

import 'ayuda_estilos.dart';
import 'ayuda_pruebas.dart';

void main() {
  group('Estilo Bento: valores', () {
    test('está en el catálogo con día y noche y su id estable', () {
      expect(estilosIncluidos.map((e) => e.id), ['futurista', 'bento']);
      expect(estiloPorId('bento'), estiloBento);
      expect(estiloBento.dia.brillo, Brightness.light);
      expect(estiloBento.noche.brillo, Brightness.dark);
      expect(estiloPorDefecto, estiloFuturista);
    });

    test(
      'esquinas muy redondeadas, borde suave, letra limpia y cuadrícula',
      () {
        for (final v in [bentoDia, bentoNoche]) {
          expect(v.radioMediano, greaterThanOrEqualTo(20));
          expect(v.grosorBorde, 1);
          expect(v.marcasEsquina, isFalse);
          expect(v.etiquetaSticker, isFalse);
          expect(v.cuadricula, isTrue);
          expect(v.nucleo, VarianteNucleo.orbe);
          expect(v.fuenteTitulos, 'Inter');
          expect(v.fuenteLectura, 'Inter');
        }
      },
    );

    test('las cifras de dinero usan cifras tabulares', () {
      expect(
        bentoNoche.numero().fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
    });

    test('contraste: texto 4.5:1 y componentes 3:1, de día y de noche', () {
      for (final (nombre, v) in [('día', bentoDia), ('noche', bentoNoche)]) {
        for (final entrada in v.superficiesConSemaforo.entries) {
          for (final (que, color) in [
            ('texto', v.texto),
            ('textoFuerte', v.textoFuerte),
            ('textoTenue', v.textoTenue),
            ('etiqueta', v.etiqueta),
            ('acento', v.acento),
            ('exito', v.exito),
            ('alerta', v.alerta),
            ('peligro', v.peligro),
          ]) {
            expect(
              razonContraste(color, entrada.value),
              greaterThanOrEqualTo(4.5),
              reason:
                  'Bento $nombre $que/${entrada.key} '
                  '${hex(color)} / ${hex(entrada.value)}',
            );
          }
        }
        expect(
          razonContraste(v.sobreAcento, v.acento),
          greaterThanOrEqualTo(4.5),
          reason: 'Bento $nombre sobreAcento/acento',
        );
      }
    });

    test('modo alto 7:1 con todas las personalidades', () {
      for (final brillo in Brightness.values) {
        for (final p in PersonalidadModulo.todas) {
          final v = valoresPara(
            estilo: estiloBento,
            brillo: p.brilloEfectivo(brillo),
            personalidad: p,
            altoContrasteGlobal: true,
          );
          for (final fondo in [v.fondo, v.panel]) {
            for (final color in [
              v.texto,
              v.textoFuerte,
              v.textoTenue,
              v.etiqueta,
              v.acento,
              v.exito,
              v.alerta,
              v.peligro,
            ]) {
              expect(
                razonContraste(color, fondo),
                greaterThanOrEqualTo(contrasteMinimoAlto),
                reason: '${p.nombre} $brillo ${hex(color)}/${hex(fondo)}',
              );
            }
          }
        }
      }
    });

    test('Inter está incluida con su licencia', () {
      expect(File('assets/fonts/Inter/Inter-Regular.ttf').existsSync(), isTrue);
      expect(licenciasFuentes.keys, contains('Inter'));
    });
  });

  group('Cuadrícula bento', () {
    test('2 columnas en el teléfono, 4 desde 600 dp y 1 con letra grande', () {
      expect(CuadriculaBento.columnasPara(360, 1), 2);
      expect(CuadriculaBento.columnasPara(599, 1.3), 2);
      expect(CuadriculaBento.columnasPara(360, 2), 1);
      expect(CuadriculaBento.columnasPara(600, 1), 4);
      expect(CuadriculaBento.columnasPara(900, 2), 4);
    });

    testWidgets('acomoda las teselas: dos medias y una completa', (
      tester,
    ) async {
      fijarVentana(tester, const Size(800, 900));
      await montarConEstilo(
        tester,
        Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: CuadriculaBento(
              teselas: [
                TeselaBento(
                  key: const ValueKey('a'),
                  columnas: 4,
                  child: const TarjetaModulo(titulo: 'A', child: Text('uno')),
                ),
                const TeselaBento(
                  key: ValueKey('b'),
                  columnas: 2,
                  child: TarjetaModulo(titulo: 'B', child: Text('dos')),
                ),
                const TeselaBento(
                  key: ValueKey('c'),
                  columnas: 2,
                  child: TarjetaModulo(titulo: 'C', child: Text('tres')),
                ),
              ],
            ),
          ),
        ),
        estilo: estiloBento,
        brillo: Brightness.light,
      );
      final a = tester.getSize(find.byKey(const ValueKey('a')));
      final b = tester.getSize(find.byKey(const ValueKey('b')));
      final c = tester.getSize(find.byKey(const ValueKey('c')));
      expect(a.width, closeTo(768, 1));
      expect(b.width, closeTo(c.width, 0.5));
      expect(b.width * 2, lessThan(a.width));
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('b'))).dy,
        tester.getTopLeft(find.byKey(const ValueKey('c'))).dy,
      );
    });

    testWidgets('en el teléfono una tesela de 2 columnas ocupa todo el ancho', (
      tester,
    ) async {
      fijarVentana(tester, const Size(360, 800));
      await montarConEstilo(
        tester,
        const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: CuadriculaBento(
              teselas: [
                TeselaBento(
                  key: ValueKey('a'),
                  child: TarjetaModulo(titulo: 'A', child: Text('uno')),
                ),
                TeselaBento(
                  key: ValueKey('b'),
                  columnas: 1,
                  child: TarjetaModulo(titulo: 'B', child: Text('dos')),
                ),
                TeselaBento(
                  key: ValueKey('c'),
                  columnas: 1,
                  child: TarjetaModulo(titulo: 'C', child: Text('tres')),
                ),
              ],
            ),
          ),
        ),
        estilo: estiloBento,
        brillo: Brightness.dark,
      );
      expect(tester.getSize(find.byKey(const ValueKey('a'))).width, 328);
      expect(
        tester.getSize(find.byKey(const ValueKey('b'))).width,
        lessThan(170),
      );
    });

    testWidgets('la tarjeta llena la altura de su tesela', (tester) async {
      fijarVentana(tester, const Size(360, 800));
      await montarConEstilo(
        tester,
        const Scaffold(
          body: CuadriculaBento(
            teselas: [
              TeselaBento(
                filas: 2,
                child: TarjetaModulo(titulo: 'A', child: Text('uno')),
              ),
            ],
          ),
        ),
        estilo: estiloBento,
        brillo: Brightness.light,
      );
      expect(
        tester.getSize(find.byType(TarjetaModulo)).height,
        greaterThanOrEqualTo(2 * 120 + 12),
      );
    });
  });

  group('Bento en pantallas', () {
    testWidgets('Hoy del teléfono acomoda sus tarjetas en cuadrícula', (
      tester,
    ) async {
      fijarVentana(tester, const Size(800, 1000));
      await montarConEstilo(
        tester,
        const PantallaHoyTelefono(),
        estilo: estiloBento,
        brillo: Brightness.dark,
      );
      expect(find.byType(CuadriculaBento), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('con Futurista, Hoy sigue siendo una columna', (tester) async {
      fijarVentana(tester, const Size(800, 1000));
      await montarConEstilo(
        tester,
        const PantallaHoyTelefono(),
        estilo: estiloFuturista,
        brillo: Brightness.dark,
      );
      expect(find.byType(CuadriculaBento), findsNothing);
    });

    testWidgets('Apariencia: la vista previa de Bento es una cuadrícula', (
      tester,
    ) async {
      fijarVentana(tester, const Size(1000, 1400));
      await montarConEstilo(
        tester,
        const Scaffold(body: SingleChildScrollView(child: SeccionApariencia())),
        estilo: estiloBento,
        brillo: Brightness.light,
      );
      expect(find.byType(CuadriculaBento), findsOneWidget);
      expect(find.text('Swagger'), findsNothing);
      expect(find.text('Bento'), findsOneWidget);
    });

    testWidgets('el núcleo de Bento respira y se detiene con reducir '
        'movimiento', (tester) async {
      await montarConEstilo(
        tester,
        const Center(child: NucleoGravity(tamano: 200)),
        estilo: estiloBento,
        brillo: Brightness.dark,
      );
      final pintor = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((p) => p.painter)
          .whereType<PintorNucleo>()
          .first;
      expect(pintor.variante, VarianteNucleo.orbe);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.hasScheduledFrame, isTrue);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    });
  });
}
