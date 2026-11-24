// Barras de historial (B5) con texto alternativo, lista de salidas, casillas
// de clima y meta mensual: sin racha semanal ni culpa; una semana sin salida
// o una salida omitida por clima se dice con icono y palabras neutras.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/diseno/diseno.dart';

import '../ayuda_pruebas.dart' show recolectarDesbordes;
import 'ayuda_bici.dart';

const _barras = [
  BarraSalidaVista(
    etiqueta: 'Semana del 9 nov',
    valor: 55,
    valorTexto: '55,2 km',
    detalleTexto: '3 h 50 min · mixta',
  ),
  BarraSalidaVista(
    etiqueta: 'Semana del 16 nov',
    valor: 0,
    valorTexto: 'Sin salida',
    estado: EstadoSemanaBici.omitidaPorClima,
  ),
  BarraSalidaVista(
    etiqueta: 'Semana del 23 nov',
    valor: 62.4,
    valorTexto: '62,4 km',
  ),
  BarraSalidaVista(
    etiqueta: 'Semana del 30 nov',
    valor: 0,
    valorTexto: 'Sin salida',
    estado: EstadoSemanaBici.sinSalida,
  ),
];

void main() {
  group('BarrasHistorialBici', () {
    testWidgets('lleva su texto alternativo completo con cada semana', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await montarBici(tester, const BarrasHistorialBici(barras: _barras));
      final etiquetas = etiquetasAccesibles(tester);
      final alt = etiquetas.firstWhere(
        (e) => e.startsWith('Kilómetros por semana. 4 semanas.'),
      );
      expect(alt, contains('Semana del 9 nov, 55,2 km, 3 h 50 min · mixta'));
      expect(alt, contains('Semana del 16 nov, Sin salida, omitida por clima'));
      expect(alt, contains('Semana del 30 nov, Sin salida, sin salida'));
      expect(alt, contains('Semana del 23 nov, 62,4 km'));
      handle.dispose();
    });

    testWidgets('una semana sin salida lleva icono y palabras, sin barra '
        'llena', (tester) async {
      await montarBici(tester, const BarrasHistorialBici(barras: _barras));
      expect(find.text('Omitida por clima'), findsOneWidget);
      expect(find.text('Sin salida'), findsWidgets);
      expect(
        find.byIcon(EstadoSemanaBici.omitidaPorClima.icono),
        findsOneWidget,
      );
      expect(find.byIcon(EstadoSemanaBici.sinSalida.icono), findsOneWidget);
    });

    testWidgets('sin racha, sin culpa y sin comparar con nadie', (
      tester,
    ) async {
      await montarBici(
        tester,
        const BarrasHistorialBici(
          barras: _barras,
          subtitulo: 'Últimas semanas',
        ),
      );
      final todo = textosVisibles(tester).join(' ').toLowerCase();
      for (final p in [...palabrasProhibidas, 'racha', 'rota', 'ranking']) {
        expect(todo.contains(p), isFalse, reason: p);
      }
    });

    testWidgets('la nota de progresión es informativa y se oculta con el modo '
        'foco', (tester) async {
      const nota = 'Esta salida fue bastante más larga que tus últimas.';
      await montarBici(
        tester,
        const BarrasHistorialBici(barras: _barras, notaProgresionTexto: nota),
      );
      expect(find.byKey(const ValueKey('historial-nota')), findsOneWidget);
      await montarBici(
        tester,
        const BarrasHistorialBici(
          barras: _barras,
          notaProgresionTexto: nota,
          modoFoco: true,
        ),
      );
      expect(find.byKey(const ValueKey('historial-nota')), findsNothing);
    });

    testWidgets('estados: vacío, cargando, sin conexión y error', (
      tester,
    ) async {
      var reintentos = 0;
      for (final estado in estadosSinContenido) {
        await montarBici(
          tester,
          BarrasHistorialBici(
            barras: const [],
            estado: estado,
            alReintentar: () => reintentos++,
          ),
        );
        expect(find.byType(CuerpoEstadoBici), findsOneWidget);
        if (estado == EstadoVistaBici.error) {
          await tester.tap(find.text(TextosBici.reintentar));
        }
      }
      expect(reintentos, 1);
      await desmontar(tester);
    });

    for (final ancho in [360.0, 900.0]) {
      testWidgets('letra al 200 % en ${ancho.toInt()} dp sin desbordes', (
        tester,
      ) async {
        final desbordes = await recolectarDesbordes(() async {
          await montarBici(
            tester,
            const BarrasHistorialBici(
              barras: _barras,
              subtitulo: 'Últimas 4 semanas',
              notaProgresionTexto:
                  'Esta salida fue bastante más larga que tus últimas.',
            ),
            ancho: ancho,
            letra: 2.0,
          );
        });
        expect(desbordes, isEmpty);
      });
    }
  });

  group('ListaSalidasHistorial', () {
    const salidas = [
      SalidaHistorialVista(
        fechaTexto: 'sáb 21 nov',
        resumenTexto: '4 h 05 min · 62,4 km',
        superficie: SuperficieSalida.mixta,
        esfuerzoTexto: 'Esfuerzo 3 de 5',
        climaTexto: 'Despejado',
        acompanado: true,
      ),
    ];

    testWidgets('cada salida se lee completa y se toca con 48 dp o más', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final tocadas = <int>[];
      await montarBici(
        tester,
        ListaSalidasHistorial(salidas: salidas, alTocarSalida: tocadas.add),
      );
      expect(
        etiquetasAccesibles(tester),
        contains(
          'sáb 21 nov, 4 h 05 min · 62,4 km, ruta mixta, Esfuerzo 3 de 5, '
          'Despejado, acompañado',
        ),
      );
      final fila = find.ancestor(
        of: find.text('4 h 05 min · 62,4 km'),
        matching: find.byType(InkWell),
      );
      expect(tester.getSize(fila.first).height, greaterThanOrEqualTo(48));
      await tester.tap(find.text('4 h 05 min · 62,4 km'));
      expect(tocadas, [0]);
      handle.dispose();
    });

    testWidgets('estados: vacío, cargando, sin conexión y error', (
      tester,
    ) async {
      for (final estado in estadosSinContenido) {
        await montarBici(
          tester,
          ListaSalidasHistorial(
            salidas: const [],
            estado: estado,
            alReintentar: () {},
          ),
        );
        expect(find.byType(CuerpoEstadoBici), findsOneWidget);
      }
      await desmontar(tester);
    });

    testWidgets('letra al 200 % en 360 dp sin desbordes', (tester) async {
      final desbordes = await recolectarDesbordes(() async {
        await montarBici(
          tester,
          ListaSalidasHistorial(salidas: salidas, alTocarSalida: (_) {}),
          letra: 2.0,
        );
      });
      expect(desbordes, isEmpty);
    });
  });

  group('CasillasClima', () {
    testWidgets('cinco casillas de 48 dp con icono y palabra', (tester) async {
      await montarBici(tester, CasillasClima(alElegir: (_) {}));
      for (final c in ClimaBici.values) {
        expect(find.text(c.texto), findsOneWidget);
        final op = find.ancestor(
          of: find.text(c.texto),
          matching: find.byType(InkWell),
        );
        expect(tester.getSize(op.first).height, greaterThanOrEqualTo(48));
        expect(find.byIcon(c.icono), findsWidgets);
      }
      expect(ClimaBici.values, hasLength(5));
    });

    testWidgets('elegir una casilla avisa; elegirla otra vez la quita', (
      tester,
    ) async {
      final elegidas = <ClimaBici?>[];
      await montarBici(
        tester,
        CasillasClima(seleccionado: ClimaBici.lluvia, alElegir: elegidas.add),
      );
      await tester.tap(find.text('Posible lluvia'));
      await tester.tap(find.text('Frío'));
      expect(elegidas, [null, ClimaBici.frio]);
    });

    testWidgets('muestra la respuesta fija solo con una casilla elegida', (
      tester,
    ) async {
      const respuesta =
          'Con lluvia el piso resbala y se ve menos. Considera dejarlo para '
          'otro día o salir en calle por un rato corto.';
      await montarBici(
        tester,
        const CasillasClima(
          seleccionado: ClimaBici.lluvia,
          respuestaTexto: respuesta,
        ),
      );
      expect(find.text(respuesta), findsOneWidget);
      await montarBici(tester, const CasillasClima(respuestaTexto: respuesta));
      expect(find.text(respuesta), findsNothing);
    });

    testWidgets('la casilla elegida se dice con marca y para el lector de '
        'pantalla, no solo con color', (tester) async {
      final handle = tester.ensureSemantics();
      await montarBici(
        tester,
        CasillasClima(seleccionado: ClimaBici.calor, alElegir: (_) {}),
      );
      expect(find.byIcon(Icons.check), findsOneWidget);
      final nodo = tester.getSemantics(
        find
            .ancestor(
              of: find.text('Mucho calor'),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(nodo.label, 'Clima: Mucho calor');
      expect(nodo, isSemantics(isSelected: true));
      handle.dispose();
    });

    testWidgets('*Ver el clima* abre la app de la persona; sin enlace se ve '
        'apagado y lo dice', (tester) async {
      var ver = 0;
      await montarBici(tester, CasillasClima(alVerClima: () => ver++));
      final boton = find.widgetWithText(OutlinedButton, TextosBici.verElClima);
      expect(tester.getSize(boton).height, greaterThanOrEqualTo(48));
      await tester.tap(boton);
      expect(ver, 1);

      await montarBici(
        tester,
        CasillasClima(alVerClima: () => ver++, hayEnlace: false),
      );
      expect(
        find.text('${TextosBici.verElClima} (sin enlace)'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(
                OutlinedButton,
                '${TextosBici.verElClima} (sin enlace)',
              ),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('las casillas funcionan también sin conexión: se ven y '
        'responden', (tester) async {
      final elegidas = <ClimaBici?>[];
      await montarBici(tester, CasillasClima(alElegir: elegidas.add));
      await tester.tap(find.text('Nublado'));
      expect(elegidas, [ClimaBici.nublado]);
    });

    testWidgets('estados cargando, sin conexión y error', (tester) async {
      var reintentos = 0;
      for (final estado in [
        EstadoVistaBici.cargando,
        EstadoVistaBici.sinConexion,
        EstadoVistaBici.error,
      ]) {
        await montarBici(
          tester,
          CasillasClima(estado: estado, alReintentar: () => reintentos++),
        );
        expect(find.byType(CuerpoEstadoBici), findsOneWidget);
      }
      await tester.tap(find.text(TextosBici.reintentar));
      expect(reintentos, 1);
      await desmontar(tester);
    });

    for (final ancho in [360.0, 900.0]) {
      testWidgets('letra al 200 % en ${ancho.toInt()} dp sin desbordes', (
        tester,
      ) async {
        final desbordes = await recolectarDesbordes(() async {
          await montarBici(
            tester,
            CasillasClima(
              seleccionado: ClimaBici.lluvia,
              respuestaTexto: 'Con lluvia el piso resbala y se ve menos.',
              alElegir: (_) {},
              alVerClima: () {},
            ),
            ancho: ancho,
            letra: 2.0,
          );
        });
        expect(desbordes, isEmpty);
      });
    }
  });

  group('MetaMensualBici', () {
    testWidgets('dice cuántas van de la meta, sin racha semanal', (
      tester,
    ) async {
      await montarBici(
        tester,
        const MetaMensualBici(
          mesTexto: 'noviembre',
          hechas: 2,
          meta: 3,
          mensajeTexto: 'Llevas 2 de 3 salidas este mes.',
        ),
      );
      expect(find.text('2 de 3 salidas'), findsOneWidget);
      expect(find.text('Llevas 2 de 3 salidas este mes.'), findsOneWidget);
      expect(find.text('Meta cumplida'), findsNothing);
      final todo = textosVisibles(tester).join(' ').toLowerCase();
      expect(todo.contains('racha'), isFalse);
      expect(todo.contains('semana'), isFalse);
    });

    testWidgets('lo omitido por clima o seguridad se cuenta aparte, con icono '
        'y palabras, y no rompe nada', (tester) async {
      await montarBici(
        tester,
        const MetaMensualBici(
          mesTexto: 'noviembre',
          hechas: 1,
          meta: 3,
          omitidasPorClima: 2,
          omitidasPorSeguridad: 1,
        ),
      );
      expect(find.text('Omitidas por clima: 2'), findsOneWidget);
      expect(find.text('Omitidas por seguridad: 1'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_outlined), findsOneWidget);
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
      final todo = textosVisibles(tester).join(' ').toLowerCase();
      for (final p in [...palabrasProhibidas, 'rota', 'rompe', 'racha']) {
        expect(todo.contains(p), isFalse, reason: p);
      }
    });

    testWidgets('al llegar a la meta lo dice en voz baja, con icono', (
      tester,
    ) async {
      await montarBici(
        tester,
        const MetaMensualBici(mesTexto: 'noviembre', hechas: 3, meta: 3),
      );
      expect(find.text('Meta cumplida'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsWidgets);
    });

    testWidgets('lee su resumen al lector de pantalla', (tester) async {
      final handle = tester.ensureSemantics();
      await montarBici(
        tester,
        const MetaMensualBici(
          mesTexto: 'noviembre',
          hechas: 2,
          meta: 3,
          omitidasPorClima: 1,
        ),
      );
      expect(
        etiquetasAccesibles(tester),
        contains('Meta de noviembre: 2 de 3 salidas, 1 omitidas por clima'),
      );
      handle.dispose();
    });

    testWidgets('estados: vacío (sin meta), cargando, sin conexión y error', (
      tester,
    ) async {
      for (final estado in estadosSinContenido) {
        await montarBici(
          tester,
          MetaMensualBici(
            mesTexto: 'noviembre',
            hechas: 0,
            meta: 3,
            estado: estado,
            alReintentar: () {},
          ),
        );
        expect(find.byType(CuerpoEstadoBici), findsOneWidget);
      }
      await montarBici(
        tester,
        const MetaMensualBici(mesTexto: 'noviembre', hechas: 0, meta: 0),
      );
      expect(find.byType(CuerpoEstadoBici), findsOneWidget);
      await desmontar(tester);
    });

    for (final ancho in [360.0, 900.0]) {
      testWidgets('letra al 200 % en ${ancho.toInt()} dp sin desbordes', (
        tester,
      ) async {
        final desbordes = await recolectarDesbordes(() async {
          await montarBici(
            tester,
            const MetaMensualBici(
              mesTexto: 'noviembre',
              hechas: 2,
              meta: 3,
              omitidasPorClima: 1,
              omitidasPorSeguridad: 1,
              mensajeTexto: 'Llevas 2 de 3 salidas este mes.',
            ),
            ancho: ancho,
            letra: 2.0,
          );
        });
        expect(desbordes, isEmpty);
      });
    }
  });
}
