import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/diseno/diseno.dart';

import 'ayuda_estilos.dart';
import 'ayuda_pruebas.dart';

void main() {
  setUp(GestorEsmerilado.instancia.reiniciar);
  tearDown(GestorEsmerilado.instancia.reiniciar);

  group('Estilo Glass: catálogo y valores', () {
    test(
      'se ofrece con día y noche; Bento está en pausa y Swagger no existe',
      () {
        expect(estilosIncluidos.map((e) => e.id), ['futurista', 'glass']);
        expect(estilosEnPausa.map((e) => e.id), ['bento']);
        expect(estiloPorId('glass'), estiloGlass);
        expect(estiloPorId('swagger'), estiloPorDefecto);
        expect(estiloGlass.dia.brillo, Brightness.light);
        expect(estiloGlass.noche.brillo, Brightness.dark);
        expect(estiloPorDefecto, estiloFuturista);
      },
    );

    test('Swagger se eliminó por completo: código, fuentes y licencias', () {
      expect(File('lib/diseno/estilos/swagger.dart').existsSync(), isFalse);
      expect(Directory('assets/fonts/Anton').existsSync(), isFalse);
      expect(licenciasFuentes.keys, isNot(contains('Anton')));
      expect(File('pubspec.yaml').readAsStringSync(), isNot(contains('Anton')));
    });

    test('lleva Plus Jakarta Sans en el proyecto y cifras tabulares', () {
      for (final v in [glassDia, glassNoche]) {
        expect(v.fuenteTitulos, 'PlusJakartaSans');
        expect(v.fuenteLectura, 'PlusJakartaSans');
        expect(
          v.numero().fontFeatures,
          contains(const FontFeature.tabularFigures()),
        );
        expect(v.esmerilado, greaterThan(0));
        expect(v.panelTranslucido, isNotNull);
        expect(v.fondoFin, isNotNull);
        expect(v.nucleo, VarianteNucleo.cristal);
      }
      expect(
        File('pubspec.yaml').readAsStringSync(),
        contains('family: PlusJakartaSans'),
      );
      expect(licenciasFuentes.keys, contains('Plus Jakarta Sans'));
    });

    test('el panel translúcido tiene transparencia y el panel sólido no', () {
      for (final v in [glassDia, glassNoche]) {
        expect(v.panelTranslucido!.a, lessThan(1));
        expect(v.panel.a, 1);
      }
    });
  });

  group('Estilo Glass: contraste contra el peor fondo (4.5:1)', () {
    for (final brillo in Brightness.values) {
      test('${brillo.name}: texto sobre cada fondo extremo y sobre el panel '
          'de vidrio encima de cada uno', () {
        final v = (brillo == Brightness.dark ? glassNoche : glassDia);
        final textos = {
          'texto': v.texto,
          'textoFuerte': v.textoFuerte,
          'textoTenue': v.textoTenue,
          'etiqueta': v.etiqueta,
          'acento': v.acento,
          'exito': v.exito,
          'alerta': v.alerta,
          'peligro': v.peligro,
        };
        expect(v.fondosExtremos.length, 3);
        for (final extremo in v.fondosExtremos) {
          for (final MapEntry(key: que, value: color) in textos.entries) {
            // Sobre el fondo mismo (títulos y cifras fuera de un panel).
            expect(
              razonContraste(color, extremo),
              greaterThanOrEqualTo(4.5),
              reason: 'Glass ${brillo.name} $que sobre fondo ${hex(extremo)}',
            );
            // Sobre el panel de vidrio puesto encima de ese fondo.
            final panel = v.panelSobre(extremo);
            expect(
              razonContraste(color, panel),
              greaterThanOrEqualTo(4.5),
              reason:
                  'Glass ${brillo.name} $que sobre vidrio ${hex(panel)} '
                  '(fondo ${hex(extremo)})',
            );
          }
        }
        // El panel sólido del teléfono.
        for (final MapEntry(key: que, value: color) in textos.entries) {
          expect(
            razonContraste(color, v.panel),
            greaterThanOrEqualTo(4.5),
            reason: 'Glass ${brillo.name} $que sobre panel sólido',
          );
        }
        expect(
          razonContraste(v.sobreAcento, v.acento),
          greaterThanOrEqualTo(4.5),
        );
      });
    }

    test('con la personalidad de cada módulo también (acento propio)', () {
      for (final brillo in Brightness.values) {
        for (final p in PersonalidadModulo.todas) {
          final v = valoresPara(
            estilo: estiloGlass,
            brillo: p.brilloEfectivo(brillo),
            personalidad: p,
          );
          for (final extremo in v.fondosExtremos) {
            final panel = v.panelSobre(extremo);
            for (final (que, color) in [
              ('texto', v.texto),
              ('textoTenue', v.textoTenue),
              ('etiqueta', v.etiqueta),
              ('acento', v.acento),
              ('exito', v.exito),
              ('alerta', v.alerta),
              ('peligro', v.peligro),
            ]) {
              for (final fondo in [extremo, panel]) {
                expect(
                  razonContraste(color, fondo),
                  greaterThanOrEqualTo(4.5),
                  reason:
                      '${p.nombre} ${brillo.name} $que ${hex(color)} / ${hex(fondo)}',
                );
              }
            }
          }
        }
      }
    });
  });

  group('Estilo Glass: modo alto y excepciones por función', () {
    test('alto contraste 7:1: sin vidrio, sin degradado y liso', () {
      for (final brillo in Brightness.values) {
        for (final p in PersonalidadModulo.todas) {
          final v = valoresPara(
            estilo: estiloGlass,
            brillo: p.brilloEfectivo(brillo),
            personalidad: p,
            altoContrasteGlobal: true,
          );
          expect(v.esmerilado, 0);
          expect(v.panelTranslucido, isNull);
          expect(v.fondoFin, isNull);
          for (final fondo in [v.fondo, v.panel]) {
            for (final color in [v.texto, v.textoTenue, v.etiqueta, v.acento]) {
              expect(
                razonContraste(color, fondo),
                greaterThanOrEqualTo(contrasteMinimoAlto),
                reason: '${p.nombre} $brillo',
              );
            }
          }
        }
      }
    });

    test('Cuidados y la bici (alto contraste) nunca llevan vidrio', () {
      for (final p in [
        PersonalidadModulo.claraCalida,
        PersonalidadModulo.sport,
      ]) {
        for (final brillo in Brightness.values) {
          final v = valoresPara(
            estilo: estiloGlass,
            brillo: p.brilloEfectivo(brillo),
            personalidad: p,
          );
          expect(v.esmerilado, 0, reason: p.nombre);
          expect(v.panelTranslucido, isNull, reason: p.nombre);
          expect(v.altoContraste, isTrue);
        }
      }
    });

    test('en el teléfono no se esmerila, en laptop y tablet sí', () {
      final telefono = valoresPara(
        estilo: estiloGlass,
        brillo: Brightness.dark,
        esmerilar: false,
      );
      final laptop = valoresPara(estilo: estiloGlass, brillo: Brightness.dark);
      expect(telefono.esmerilado, 0);
      expect(telefono.panel.a, 1); // translúcido sólido
      expect(laptop.esmerilado, greaterThan(0));
    });
  });

  group('Estilo Glass: pantallas', () {
    Scaffold varias(int n) => Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            for (var i = 0; i < n; i++)
              TarjetaModulo(titulo: 'Tarjeta $i', child: const Text('x')),
          ],
        ),
      ),
    );

    testWidgets('en el teléfono ninguna tarjeta usa BackdropFilter', (
      tester,
    ) async {
      fijarVentana(tester, const Size(360, 900));
      await montarConEstilo(
        tester,
        varias(5),
        estilo: estiloGlass,
        brillo: Brightness.dark,
        densidad: Densidad.comoda,
      );
      expect(find.byType(BackdropFilter), findsNothing);
      expect(GestorEsmerilado.instancia.capasActivas, 0);
    });

    testWidgets('en laptop se esmerila con un máximo de 3 capas', (
      tester,
    ) async {
      fijarVentana(tester, const Size(1200, 1400));
      await montarConEstilo(
        tester,
        varias(5),
        estilo: estiloGlass,
        brillo: Brightness.dark,
        densidad: Densidad.compacta,
      );
      expect(find.byType(BackdropFilter), findsNWidgets(3));
      expect(GestorEsmerilado.instancia.capasActivas, 3);
      // Las otras dos se ven, pero en su versión translúcida sólida.
      expect(find.byType(TarjetaModulo), findsNWidgets(5));
    });

    testWidgets('en tablet también se esmerila', (tester) async {
      fijarVentana(tester, const Size(1000, 900));
      await montarConEstilo(
        tester,
        varias(2),
        estilo: estiloGlass,
        brillo: Brightness.light,
        densidad: Densidad.grande,
      );
      expect(find.byType(BackdropFilter), findsNWidgets(2));
    });

    testWidgets('al apagarse por rendimiento deja de esmerilar y avisa en '
        'Apariencia', (tester) async {
      fijarVentana(tester, const Size(1200, 1600));
      await montarConEstilo(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [varias(2).body!, const SeccionApariencia()],
            ),
          ),
        ),
        estilo: estiloGlass,
        brillo: Brightness.dark,
        densidad: Densidad.compacta,
      );
      expect(find.byType(BackdropFilter), findsWidgets);
      expect(find.byKey(const ValueKey('esmerilado-apagado')), findsNothing);

      GestorEsmerilado.instancia.apagarPorRendimiento();
      await tester.pump();
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byKey(const ValueKey('esmerilado-apagado')), findsOneWidget);
      expect(GestorEsmerilado.instancia.apagadoAutomatico, isTrue);

      await tester.ensureVisible(
        find.byKey(const ValueKey('esmerilado-reactivar')),
      );
      await tester.tap(find.byKey(const ValueKey('esmerilado-reactivar')));
      await tester.pump();
      expect(find.byType(BackdropFilter), findsWidgets);
      expect(find.byKey(const ValueKey('esmerilado-apagado')), findsNothing);
    });

    testWidgets('alto contraste global quita el vidrio de la laptop', (
      tester,
    ) async {
      fijarVentana(tester, const Size(1200, 900));
      await montarConEstilo(
        tester,
        varias(2),
        estilo: estiloGlass,
        brillo: Brightness.dark,
        densidad: Densidad.compacta,
        altoContraste: true,
      );
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('el fondo de vidrio es un degradado y el de Futurista, liso', (
      tester,
    ) async {
      await montarConEstilo(
        tester,
        const FondoEstilo(child: SizedBox.expand()),
        estilo: estiloGlass,
        brillo: Brightness.dark,
      );
      expect(
        find.descendant(
          of: find.byType(FondoEstilo),
          matching: find.byType(CustomPaint),
        ),
        findsWidgets,
      );
      await montarConEstilo(
        tester,
        const FondoEstilo(child: SizedBox.expand()),
        estilo: estiloFuturista,
        brillo: Brightness.dark,
      );
      expect(
        find.descendant(
          of: find.byType(FondoEstilo),
          matching: find.byType(ColoredBox),
        ),
        findsWidgets,
      );
    });

    testWidgets('lo oculto se sustituye, no se difumina, también en Glass', (
      tester,
    ) async {
      fijarVentana(tester, const Size(1200, 900));
      await montarConEstilo(
        tester,
        const Scaffold(
          body: TarjetaModulo(
            titulo: 'Dinero',
            child: MontoOcultable(centavos: 123456),
          ),
        ),
        estilo: estiloGlass,
        brillo: Brightness.dark,
        densidad: Densidad.compacta,
      );
      final handle = tester.ensureSemantics();
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(find.textContaining('1,234.56'), findsNothing);
      expect(find.bySemanticsLabel(RegExp('1,234')), findsNothing);
      handle.dispose();
    });

    testWidgets(
      'el núcleo de Glass flota y se detiene con reducir movimiento',
      (tester) async {
        await montarConEstilo(
          tester,
          const Center(child: NucleoGravity(tamano: 200)),
          estilo: estiloGlass,
          brillo: Brightness.dark,
        );
        final pintor = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((p) => p.painter)
            .whereType<PintorNucleo>()
            .first;
        expect(pintor.variante, VarianteNucleo.cristal);
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
      },
    );
  });

  group('Monitor de rendimiento (apagado automático)', () {
    const cuadro = Duration(milliseconds: 10);
    const lento = Duration(milliseconds: 30);

    /// Corre [n] cuadros de [duracion], uno cada 16 ms, y dice si pidió apagar.
    bool correr(MonitorRendimiento m, int n, Duration duracion) {
      var apagar = false;
      for (var i = 0; i < n; i++) {
        apagar |= m.cuadro(duracion, Duration(milliseconds: 16 * i));
      }
      return apagar;
    }

    test('cuadros rápidos durante 5 s no apagan nada', () {
      expect(correr(MonitorRendimiento(), 400, cuadro), isFalse);
    });

    test('cuadros de 30 ms (33 por segundo) durante 5 s apagan', () {
      expect(correr(MonitorRendimiento(), 400, lento), isTrue);
    });

    test('antes de cumplir los 5 s no se decide', () {
      expect(correr(MonitorRendimiento(), 200, lento), isFalse); // 3.2 s
    });

    test('con pocos cuadros (app quieta) no cuenta', () {
      final m = MonitorRendimiento();
      expect(m.cuadro(lento, Duration.zero), isFalse);
      expect(m.cuadro(lento, const Duration(seconds: 6)), isFalse);
    });

    test('el umbral es de 45 por segundo (22.2 ms)', () {
      expect(MonitorRendimiento().umbral.inMicroseconds, closeTo(22222, 1));
      expect(
        correr(MonitorRendimiento(), 400, const Duration(milliseconds: 22)),
        isFalse,
      );
      expect(
        correr(MonitorRendimiento(), 400, const Duration(milliseconds: 23)),
        isTrue,
      );
    });

    test('una ventana lenta seguida de una rápida no deja marcada la '
        'siguiente', () {
      final m = MonitorRendimiento();
      expect(correr(m, 400, lento), isTrue);
      var apagar = false;
      for (var i = 0; i < 400; i++) {
        apagar |= m.cuadro(cuadro, Duration(seconds: 7, milliseconds: 16 * i));
      }
      expect(apagar, isFalse);
    });

    test('el gestor limita a 3 capas y las devuelve', () {
      final g = GestorEsmerilado();
      final a = Object(), b = Object(), c = Object(), d = Object();
      expect([
        g.solicitar(a),
        g.solicitar(b),
        g.solicitar(c),
      ], everyElement(isTrue));
      expect(g.solicitar(d), isFalse);
      expect(g.solicitar(a), isTrue); // idempotente
      g.liberar(a);
      expect(g.solicitar(d), isTrue);
      expect(g.capasActivas, 3);
      g.apagarPorRendimiento();
      expect(g.solicitar(Object()), isFalse);
      expect(g.capasActivas, 0);
    });
  });
}
