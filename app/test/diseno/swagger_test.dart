import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/diseno/diseno.dart';

import 'ayuda_estilos.dart';
import 'ayuda_pruebas.dart';

void main() {
  group('Estilo Swagger: valores', () {
    test('está en el catálogo con día y noche y su id estable', () {
      expect(estilosIncluidos.map((e) => e.id), contains('swagger'));
      expect(estiloPorId('swagger'), estiloSwagger);
      expect(estiloSwagger.dia.brillo, Brightness.light);
      expect(estiloSwagger.noche.brillo, Brightness.dark);
      expect(estiloPorId('inexistente'), estiloPorDefecto);
    });

    test('Futurista sigue siendo el estilo por omisión', () {
      expect(estiloPorDefecto, estiloFuturista);
    });

    test('lleva Anton en títulos, Inter en lectura y bordes gruesos', () {
      for (final v in [swaggerDia, swaggerNoche]) {
        expect(v.fuenteTitulos, 'Anton');
        expect(v.fuenteLectura, 'Inter');
        expect(v.grosorBorde, greaterThan(1));
        expect(v.etiquetaSticker, isTrue);
        expect(v.marcasEsquina, isFalse);
        expect(v.nucleo, VarianteNucleo.pulso);
      }
    });

    test('las cifras de dinero usan cifras tabulares (ancho fijo)', () {
      final estilo = swaggerNoche.numero();
      expect(estilo.fontFeatures, contains(const FontFeature.tabularFigures()));
    });

    test('contraste: texto 4.5:1 sobre fondo y panel, de día y de noche', () {
      for (final (nombre, v) in [
        ('día', swaggerDia),
        ('noche', swaggerNoche),
      ]) {
        for (final (sup, fondo) in v.superficiesConSemaforo.entries.map(
          (e) => (e.key, e.value),
        )) {
          for (final (que, color) in [
            ('texto', v.texto),
            ('textoFuerte', v.textoFuerte),
            ('textoTenue', v.textoTenue),
            ('etiqueta', v.etiqueta),
            ('exito', v.exito),
            ('alerta', v.alerta),
            ('peligro', v.peligro),
          ]) {
            expect(
              razonContraste(color, fondo),
              greaterThanOrEqualTo(4.5),
              reason: 'Swagger $nombre $que/$sup ${hex(color)} / ${hex(fondo)}',
            );
          }
        }
        expect(
          razonContraste(v.sobreAcento, v.acento),
          greaterThanOrEqualTo(4.5),
          reason: 'Swagger $nombre sobreAcento/acento (sticker y botones)',
        );
        expect(
          razonContraste(v.acento, v.panel),
          greaterThanOrEqualTo(4.5),
          reason: 'Swagger $nombre acento/panel',
        );
        expect(
          razonContraste(v.borde, v.fondo),
          greaterThanOrEqualTo(3),
          reason: 'Swagger $nombre borde/fondo (componentes 3:1)',
        );
      }
    });

    test('alto contraste (modo alto, 7:1) en Swagger con todas las '
        'personalidades', () {
      for (final brillo in Brightness.values) {
        for (final p in PersonalidadModulo.todas) {
          final v = valoresPara(
            estilo: estiloSwagger,
            brillo: brillo,
            personalidad: p,
            altoContrasteGlobal: true,
          );
          for (final fondo in [v.fondo, v.panel]) {
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
                razonContraste(color, fondo),
                greaterThanOrEqualTo(contrasteMinimoAlto),
                reason: '${p.nombre} $brillo $que ${hex(color)}/${hex(fondo)}',
              );
            }
          }
        }
      }
    });
  });

  group('Estilo Swagger: fuentes incluidas', () {
    test(
      'Anton, Inter y Plus Jakarta Sans están en el proyecto con licencia',
      () {
        final pubspec = File('pubspec.yaml').readAsStringSync();
        for (final familia in ['Anton', 'Inter', 'PlusJakartaSans']) {
          expect(pubspec, contains('family: $familia'), reason: familia);
        }
        for (final ruta in licenciasFuentes.values) {
          expect(File(ruta).existsSync(), isTrue, reason: ruta);
          expect(pubspec, contains(ruta));
        }
        expect(
          licenciasFuentes.keys,
          containsAll(['Anton', 'Inter', 'Plus Jakarta Sans']),
        );
      },
    );

    test('las fuentes no se descargan: no hay google_fonts ni red', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec.contains('google_fonts'), isFalse);
    });

    test('las fuentes nuevas pesan menos de 3 MB (y todas, menos de 4 MB)', () {
      int peso(Iterable<String> carpetas) {
        var bytes = 0;
        for (final c in carpetas) {
          for (final f in Directory('assets/fonts/$c').listSync()) {
            if (f is File && f.path.endsWith('.ttf')) bytes += f.lengthSync();
          }
        }
        return bytes;
      }

      final nuevas = peso(['Anton', 'Inter', 'PlusJakartaSans']);
      final todas = peso(
        Directory('assets/fonts').listSync().map((d) => d.path.split('/').last),
      );
      expect(nuevas, lessThan(3 * 1024 * 1024), reason: '$nuevas bytes');
      expect(todas, lessThan(4 * 1024 * 1024), reason: '$todas bytes');
    });
  });

  group('Estilo Swagger: pantallas', () {
    testWidgets('el estilo cambia sin reiniciar y conserva el estado', (
      tester,
    ) async {
      await montar(tester, const _Contador());
      await tester.tap(find.text('sumar'));
      await tester.pump();
      final estado = tester.state(find.byType(_Contador));
      final c = contenedorDe(tester, find.byType(_Contador));
      expect(
        ValoresDiseno.de(tester.element(find.byType(_Contador))).fuenteTitulos,
        FuentesGravity.titulos,
      );

      c.read(estiloProvider.notifier).elegir(estiloSwagger);
      await tester.pump();
      await tester.pump(duracionCambioTema);

      final v = ValoresDiseno.de(tester.element(find.byType(_Contador)));
      expect(v.fuenteTitulos, 'Anton');
      expect(v.acento, swaggerNoche.acento);
      expect(find.text('cuenta 1'), findsOneWidget);
      expect(tester.state(find.byType(_Contador)), same(estado));
    });

    testWidgets('la etiqueta de panel es un sticker con el acento', (
      tester,
    ) async {
      await montarConEstilo(
        tester,
        const Center(child: EtiquetaPanel('Hoy')),
        estilo: estiloSwagger,
        brillo: Brightness.dark,
      );
      final caja = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(EtiquetaPanel),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect((caja.decoration as BoxDecoration).color, swaggerNoche.acento);
    });

    testWidgets(
      'las tarjetas dibujan el borde grueso y sin marcas de esquina',
      (tester) async {
        await montarConEstilo(
          tester,
          const Center(
            child: TarjetaModulo(titulo: 'Prueba', child: Text('x')),
          ),
          estilo: estiloSwagger,
          brillo: Brightness.light,
        );
        final material = tester.widget<Material>(
          find
              .descendant(
                of: find.byType(TarjetaModulo),
                matching: find.byType(Material),
              )
              .first,
        );
        final forma = material.shape! as RoundedRectangleBorder;
        expect(forma.side.width, swaggerDia.grosorBorde);
        expect(forma.side.color, swaggerDia.borde);
      },
    );

    testWidgets('el núcleo de Swagger pulsa y se detiene con reducir '
        'movimiento', (tester) async {
      await montarConEstilo(
        tester,
        const Center(child: NucleoGravity(tamano: 200)),
        estilo: estiloSwagger,
        brillo: Brightness.dark,
      );
      final pintor = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((p) => p.painter)
          .whereType<PintorNucleo>()
          .first;
      expect(pintor.variante, VarianteNucleo.pulso);
      // Animándose: el siguiente cuadro sigue programado.
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.hasScheduledFrame, isTrue);

      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle(); // termina: no queda nada animándose
    });

    testWidgets('el modo privado sustituye la cifra también en Swagger', (
      tester,
    ) async {
      await montarConEstilo(
        tester,
        const Center(child: MontoOcultable(centavos: 123456)),
        estilo: estiloSwagger,
        brillo: Brightness.dark,
      );
      final handle = tester.ensureSemantics();
      expect(find.textContaining('1,234.56'), findsNothing);
      expect(find.bySemanticsLabel(RegExp('1,234')), findsNothing);
      handle.dispose();
    });
  });

  group('Estilo Swagger: lector de pantalla', () {
    testWidgets('los gadgets nuevos dicen su valor con palabras', (
      tester,
    ) async {
      fijarVentana(tester, const Size(400, 4000));
      final handle = tester.ensureSemantics();
      await montarConEstilo(
        tester,
        muestraDeGadgets(),
        estilo: estiloSwagger,
        brillo: Brightness.dark,
      );
      for (final patron in [
        'Reloj del turno. De turno',
        'Cronómetro: 3 minutos 27 segundos',
        r'Velocímetro: 24 kilómetros por hora',
        'Sentadilla, serie 3 de 4',
        'Estado: En línea · 3 por subir',
      ]) {
        expect(
          find.bySemanticsLabel(RegExp(patron)),
          findsWidgets,
          reason: patron,
        );
      }
      // La lista dice si cada renglón está listo o pendiente.
      expect(find.bySemanticsLabel(RegExp('Jitomate.*Listo')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Avena.*Pendiente')), findsOneWidget);
      // Hoy se marca con palabra, no solo con color.
      expect(find.bySemanticsLabel(RegExp('Miércoles, hoy')), findsOneWidget);
      handle.dispose();
    });
  });
}

class _Contador extends StatefulWidget {
  const _Contador();

  @override
  State<_Contador> createState() => _ContadorState();
}

class _ContadorState extends State<_Contador> {
  int cuenta = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        Text('cuenta $cuenta'),
        TextButton(
          onPressed: () => setState(() => cuenta++),
          child: const Text('sumar'),
        ),
      ],
    ),
  );
}
