// Lista de preparación (B3), aviso con acciones y «Contenido en revisión»:
// cada punto lleva icono y palabra, se marca con un toque, nada bloquea y el
// lector de pantalla anuncia «Casco, marcado» o «Casco, pendiente».
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/diseno/diseno.dart';

import '../ayuda_pruebas.dart' show recolectarDesbordes;
import 'ayuda_bici.dart';

const _puntos = [
  PuntoPreparacionVista(id: 'casco', texto: 'Casco', marcado: true),
  PuntoPreparacionVista(id: 'luces', texto: 'Luces puestas'),
  PuntoPreparacionVista(
    id: 'ropa',
    texto: 'En calle, luces encendidas y ropa visible',
    ambito: AmbitoPunto.calle,
  ),
  PuntoPreparacionVista(
    id: 'terreno',
    texto: 'Llantas y frenos revisados para terreno',
    ambito: AmbitoPunto.terreno,
  ),
];

void main() {
  group('ListaPreparacion', () {
    testWidgets('dice cuántos puntos van marcados y la guía fija', (
      tester,
    ) async {
      await montarBici(
        tester,
        const ListaPreparacion(
          momento: MomentoPreparacion.vispera,
          puntos: _puntos,
        ),
      );
      expect(find.text('Preparación (1 de 4)'), findsOneWidget);
      expect(find.text(MomentoPreparacion.vispera.texto), findsOneWidget);
      expect(find.text(TextosBici.guiaNoSustituye), findsOneWidget);
    });

    testWidgets('cada punto lleva icono y palabra, no solo color', (
      tester,
    ) async {
      await montarBici(
        tester,
        const ListaPreparacion(
          momento: MomentoPreparacion.antesDeSalir,
          puntos: _puntos,
        ),
      );
      expect(find.text(EstadoPunto.marcado.texto), findsOneWidget);
      expect(find.text(EstadoPunto.pendiente.texto), findsNWidgets(3));
      expect(find.byIcon(EstadoPunto.marcado.icono), findsOneWidget);
      expect(find.byIcon(EstadoPunto.pendiente.icono), findsNWidgets(3));
      // Lo que solo aplica a calle o a terreno lo dice con palabras.
      expect(find.text('Solo en calle'), findsOneWidget);
      expect(find.text('Solo en terreno'), findsOneWidget);
    });

    testWidgets('marcar es un toque, se puede deshacer y mide 48 dp', (
      tester,
    ) async {
      final cambios = <String, bool>{};
      await montarBici(
        tester,
        ListaPreparacion(
          momento: MomentoPreparacion.vispera,
          puntos: _puntos,
          alCambiar: (id, marcado) => cambios[id] = marcado,
        ),
      );
      for (final texto in ['Casco', 'Luces puestas']) {
        final fila = find.ancestor(
          of: find.text(texto),
          matching: find.byType(InkWell),
        );
        expect(tester.getSize(fila.first).height, greaterThanOrEqualTo(48));
      }
      await tester.tap(find.text('Luces puestas'));
      await tester.tap(find.text('Casco'));
      expect(cambios, {'luces': true, 'casco': false});
    });

    testWidgets('un punto sin marcar no bloquea: Listo siempre se puede '
        'tocar', (tester) async {
      var listo = 0;
      await montarBici(
        tester,
        ListaPreparacion(
          momento: MomentoPreparacion.vispera,
          puntos: const [
            PuntoPreparacionVista(id: 'a', texto: 'Algo pendiente'),
          ],
          alListo: () => listo++,
        ),
      );
      final boton = find.byKey(const ValueKey('preparacion-listo'));
      expect(tester.widget<FilledButton>(boton).onPressed, isNotNull);
      expect(tester.getSize(boton).height, greaterThanOrEqualTo(56));
      await tester.tap(boton);
      expect(listo, 1);
    });

    testWidgets('el lector de pantalla anuncia «Casco, marcado» y «Luces '
        'puestas, pendiente»', (tester) async {
      final handle = tester.ensureSemantics();
      await montarBici(
        tester,
        ListaPreparacion(
          momento: MomentoPreparacion.vispera,
          puntos: _puntos,
          alCambiar: (_, _) {},
        ),
      );
      final etiquetas = etiquetasAccesibles(tester);
      expect(etiquetas, contains('Casco, marcado'));
      expect(etiquetas, contains('Luces puestas, pendiente'));
      expect(
        etiquetas,
        contains(
          'En calle, luces encendidas y ropa visible, pendiente, '
          'solo en calle',
        ),
      );
      handle.dispose();
    });

    testWidgets('estados: vacío con una acción, cargando, sin conexión y '
        'error', (tester) async {
      var agregar = 0;
      var reintentos = 0;
      for (final estado in estadosSinContenido) {
        await montarBici(
          tester,
          ListaPreparacion(
            momento: MomentoPreparacion.vispera,
            puntos: const [],
            estado: estado,
            alAccionVacia: () => agregar++,
            alReintentar: () => reintentos++,
          ),
        );
        expect(find.byType(CuerpoEstadoBici), findsOneWidget);
        if (estado == EstadoVistaBici.vacio) {
          await tester.tap(find.text('Agregar un punto'));
        }
        if (estado == EstadoVistaBici.error) {
          await tester.tap(find.text(TextosBici.reintentar));
        }
      }
      expect(agregar, 1);
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
            ListaPreparacion(
              momento: MomentoPreparacion.antesDeSalir,
              puntos: _puntos,
              alCambiar: (_, _) {},
              alListo: () {},
              alEditar: () {},
            ),
            ancho: ancho,
            letra: 2.0,
          );
        });
        expect(desbordes, isEmpty);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('AvisoBici', () {
    testWidgets('lleva icono, la palabra «Aviso» y acciones de 48 dp', (
      tester,
    ) async {
      var opciones = 0;
      var dejar = 0;
      await montarBici(
        tester,
        AvisoBici(
          texto: 'La sesión C queda a 36 h 45 min de la ruta.',
          acciones: [
            AccionAvisoBici(
              texto: TextosBici.verOpciones,
              alTocar: () => opciones++,
            ),
            AccionAvisoBici(
              texto: TextosBici.dejarloAsi,
              alTocar: () => dejar++,
            ),
          ],
        ),
      );
      expect(
        find.text('Aviso: La sesión C queda a 36 h 45 min de la ruta.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
      final b = find.widgetWithText(TextButton, TextosBici.dejarloAsi);
      expect(tester.getSize(b).height, greaterThanOrEqualTo(48));
      await tester.tap(find.text(TextosBici.verOpciones));
      await tester.tap(b);
      expect([opciones, dejar], [1, 1]);
    });
  });

  group('TarjetaContenidoEnRevisionBici', () {
    testWidgets('dice «Contenido en revisión» y que no sustituye a un '
        'profesional', (tester) async {
      var abrir = 0;
      await montarBici(
        tester,
        TarjetaContenidoEnRevisionBici(alAbrir: () => abrir++),
      );
      expect(find.text(TextosBici.contenidoEnRevision), findsOneWidget);
      expect(find.text(TextosBici.contenidoEnRevisionDetalle), findsOneWidget);
      final tarjeta = find.byType(InkWell);
      expect(tester.getSize(tarjeta.first).height, greaterThanOrEqualTo(48));
      await tester.tap(tarjeta.first);
      expect(abrir, 1);
    });

    testWidgets('compacta es una sola línea', (tester) async {
      await montarBici(
        tester,
        const TarjetaContenidoEnRevisionBici(compacta: true),
      );
      expect(find.text(TextosBici.contenidoEnRevision), findsOneWidget);
      expect(find.text(TextosBici.contenidoEnRevisionDetalle), findsNothing);
    });

    testWidgets('estados: vacío (todo revisado), cargando, sin conexión y '
        'error', (tester) async {
      for (final estado in estadosSinContenido) {
        await montarBici(
          tester,
          TarjetaContenidoEnRevisionBici(estado: estado, alReintentar: () {}),
        );
        expect(find.byType(CuerpoEstadoBici), findsOneWidget);
      }
      await desmontar(tester);
    });

    for (final ancho in [360.0, 900.0]) {
      testWidgets('letra al 200 % en ${ancho.toInt()} dp sin desbordes', (
        tester,
      ) async {
        final desbordes = await recolectarDesbordes(() async {
          await montarBici(
            tester,
            TarjetaContenidoEnRevisionBici(alAbrir: () {}),
            ancho: ancho,
            letra: 2.0,
          );
        });
        expect(desbordes, isEmpty);
      });
    }
  });
}
