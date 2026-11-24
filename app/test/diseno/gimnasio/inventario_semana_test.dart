// Tarjeta de aparato (E2) y línea de la semana (E1 y E3): estados con icono y
// palabras, lo no confirmado no se da por cierto, 48 dp, planes de 3, 4 y 5
// días y letra grande sin desbordes.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/diseno/diseno.dart';

import '../ayuda_pruebas.dart' show recolectarDesbordes;
import 'ayuda_gimnasio.dart';

TarjetaAparato _marcy({
  VoidCallback? alConfirmar,
  VoidCallback? alCambiarPuesto,
  DisponibilidadAparato disponibilidad = DisponibilidadAparato.disponible,
}) => TarjetaAparato(
  nombre: 'Estación multifuncional Marcy MWM-7119',
  detalle: 'Pila, poleas, brazos de press y cojín de curl.',
  disponibilidad: disponibilidad,
  puestos: [
    PuestoVista(nombre: 'Brazos de press', alCambiar: alCambiarPuesto),
    PuestoVista(
      nombre: 'Cojín de curl',
      disponibilidad: DisponibilidadAparato.noDisponible,
      alCambiar: alCambiarPuesto,
    ),
  ],
  datos: const [
    DatoAparatoVista(
      etiqueta: 'Peso de la pila',
      valorTexto: '68 kg aprox.',
      confirmacion: EstadoConfirmacionDato.delDiseno,
    ),
    DatoAparatoVista(etiqueta: 'Placas de la pila'),
    DatoAparatoVista(
      etiqueta: 'Tipo de polea',
      valorTexto: '1 a 1',
      confirmacion: EstadoConfirmacionDato.confirmado,
    ),
  ],
  alConfirmar: alConfirmar,
  alCambiarDisponibilidad: alCambiarPuesto,
);

/// La semana reordenada del dueño (plan de 3, 4 o 5 días): A el lunes, C el
/// martes, B el miércoles, jueves libre (R2 en el plan de 5), viernes R1 (en
/// los planes de 4 y 5), bicicleta el sábado y descanso el domingo.
///
/// La bicicleta lleva el aviso de ejemplo (el que saldría si la persona
/// pasara C al jueves); por omisión no hay aviso de 48 horas.
List<DiaSemanaVista> _semana(int dias) {
  const nombres = [
    ('lunes', 'L'),
    ('martes', 'M'),
    ('miércoles', 'X'),
    ('jueves', 'J'),
    ('viernes', 'V'),
    ('sábado', 'S'),
    ('domingo', 'D'),
  ];
  final tipos = [
    TipoDiaPlan.fuerzaA,
    TipoDiaPlan.fuerzaC,
    TipoDiaPlan.fuerzaB,
    dias >= 5 ? TipoDiaPlan.regenerativa2 : TipoDiaPlan.descanso,
    dias >= 4 ? TipoDiaPlan.regenerativa1 : TipoDiaPlan.descanso,
    TipoDiaPlan.bicicleta,
    TipoDiaPlan.descanso,
  ];
  return [
    for (var i = 0; i < 7; i++)
      DiaSemanaVista(
        nombre: nombres[i].$1,
        letra: nombres[i].$2,
        tipo: tipos[i],
        esHoy: i == 2,
        estado: i == 0 ? EstadoDiaPlan.hecho : EstadoDiaPlan.pendiente,
        conAviso: i == 5,
      ),
  ];
}

void main() {
  group('TarjetaAparato', () {
    testWidgets('lo no confirmado se dice «Sin confirmar» y nunca se da por '
        'cierto', (tester) async {
      var confirmar = 0;
      await montarGim(tester, _marcy(alConfirmar: () => confirmar++));
      // El dato del diseño va como orientación, con la marca «aprox.».
      expect(find.text('68 kg aprox.'), findsOneWidget);
      expect(find.text(EstadoConfirmacionDato.delDiseno.texto), findsOneWidget);
      // El que falta no inventa valor.
      expect(find.text('—'), findsOneWidget);
      expect(find.text(EstadoConfirmacionDato.confirmar.texto), findsOneWidget);
      expect(
        find.text(EstadoConfirmacionDato.confirmado.texto),
        findsOneWidget,
      );
      final boton = find.widgetWithText(
        FilledButton,
        TextosGimnasio.confirmarEnElAparato,
      );
      expect(tester.getSize(boton).height, greaterThanOrEqualTo(48));
      await tester.tap(boton);
      expect(confirmar, 1);
    });

    testWidgets('sin datos por confirmar no ofrece Confirmar en el aparato', (
      tester,
    ) async {
      await montarGim(
        tester,
        TarjetaAparato(
          nombre: 'Banco inclinado',
          alConfirmar: () {},
          datos: const [
            DatoAparatoVista(
              etiqueta: 'Capacidad',
              valorTexto: '120 kg',
              confirmacion: EstadoConfirmacionDato.confirmado,
            ),
          ],
        ),
      );
      expect(find.text(TextosGimnasio.confirmarEnElAparato), findsNothing);
    });

    testWidgets('las filas de puesto y los botones miden 48 dp y cambian el '
        'estado', (tester) async {
      var cambios = 0;
      await montarGim(tester, _marcy(alCambiarPuesto: () => cambios++));
      for (final texto in ['Brazos de press', 'Cojín de curl']) {
        final fila = find.ancestor(
          of: find.text(texto),
          matching: find.byType(InkWell),
        );
        expect(tester.getSize(fila.first).height, greaterThanOrEqualTo(48));
      }
      await tester.tap(find.text('Cojín de curl'));
      expect(cambios, 1);
      expect(find.text(TextosGimnasio.marcarNoDisponible), findsOneWidget);
      final boton = find.widgetWithText(
        TextButton,
        TextosGimnasio.marcarNoDisponible,
      );
      expect(tester.getSize(boton).height, greaterThanOrEqualTo(48));
    });

    testWidgets('disponible, no disponible y futuro llevan icono y palabras', (
      tester,
    ) async {
      for (final d in DisponibilidadAparato.values) {
        await montarGim(
          tester,
          TarjetaAparato(nombre: 'Aparato', disponibilidad: d),
        );
        expect(find.text(d.texto), findsOneWidget, reason: '$d');
        expect(find.byIcon(d.icono), findsWidgets, reason: '$d');
      }
      // El equipo futuro dice que por ahora no genera nada (CA-G-09).
      expect(find.text(TextosGimnasio.equipoFuturoNota), findsOneWidget);
    });

    testWidgets('lee su resumen al lector de pantalla', (tester) async {
      final handle = tester.ensureSemantics();
      await montarGim(tester, _marcy(alConfirmar: () {}));
      expect(
        etiquetasAccesibles(tester).any(
          (e) =>
              e.contains('Estación multifuncional Marcy MWM-7119') &&
              e.contains('Disponible') &&
              e.contains('Confirmar en el aparato'),
        ),
        isTrue,
      );
      handle.dispose();
    });

    testWidgets(
      'estados: vacío con una acción, cargando, sin conexión y error',
      (tester) async {
        var agregar = 0;
        var reintentos = 0;
        for (final estado in [
          EstadoVistaGimnasio.vacio,
          EstadoVistaGimnasio.cargando,
          EstadoVistaGimnasio.sinConexion,
          EstadoVistaGimnasio.error,
        ]) {
          await montarGim(
            tester,
            TarjetaAparato(
              nombre: 'Aparato',
              estado: estado,
              alAccionVacia: () => agregar++,
              alReintentar: () => reintentos++,
            ),
          );
          expect(find.byType(CuerpoEstadoGimnasio), findsOneWidget);
          if (estado == EstadoVistaGimnasio.vacio) {
            await tester.tap(find.text('Agregar un aparato'));
          }
          if (estado == EstadoVistaGimnasio.error) {
            await tester.tap(find.text(TextosGimnasio.reintentar));
          }
        }
        expect(agregar, 1);
        expect(reintentos, 1);
        await desmontar(tester);
      },
    );

    for (final ancho in [360.0, 900.0]) {
      testWidgets('letra al 200 % en ${ancho.toInt()} dp sin desbordes', (
        tester,
      ) async {
        final desbordes = await recolectarDesbordes(() async {
          await montarGim(
            tester,
            _marcy(alConfirmar: () {}, alCambiarPuesto: () {}),
            ancho: ancho,
            letra: 2.0,
          );
        });
        expect(desbordes, isEmpty);
      });
    }
  });

  group('LineaSemana', () {
    for (final dias in [3, 4, 5]) {
      testWidgets('plan de $dias días: los siete días, la bicicleta el sábado '
          'y el descanso el domingo', (tester) async {
        final semana = _semana(dias);
        await montarGim(tester, LineaSemana(dias: semana), ancho: 420);
        final fuerza = semana.where((d) => d.tipo.esFuerza).length;
        expect(fuerza, 3);
        // La semana reordenada: A lunes, C martes, B miércoles.
        expect(semana[0].tipo, TipoDiaPlan.fuerzaA);
        expect(semana[1].tipo, TipoDiaPlan.fuerzaC);
        expect(semana[2].tipo, TipoDiaPlan.fuerzaB);
        final regenerativas = semana
            .where(
              (d) =>
                  d.tipo == TipoDiaPlan.regenerativa1 ||
                  d.tipo == TipoDiaPlan.regenerativa2,
            )
            .length;
        expect(regenerativas, dias - 3);
        expect(semana[5].tipo, TipoDiaPlan.bicicleta);
        expect(semana[6].tipo, TipoDiaPlan.descanso);
        expect(find.text('Bici'), findsOneWidget);
        expect(find.text('R1'), dias >= 4 ? findsOneWidget : findsNothing);
        expect(find.text('R2'), dias >= 5 ? findsOneWidget : findsNothing);
      });
    }

    testWidgets('con ancho suficiente dibuja una tira; con letra grande, una '
        'lista de filas de 56 dp', (tester) async {
      final semana = _semana(3);
      await montarGim(
        tester,
        LineaSemana(dias: semana, alTocarDia: (_) {}),
        ancho: 420,
      );
      expect(find.text('L'), findsOneWidget); // la tira usa la letra del día
      await montarGim(
        tester,
        LineaSemana(dias: semana, alTocarDia: (_) {}),
        ancho: 420,
        letra: 2.0,
      );
      expect(find.text('L'), findsNothing);
      expect(find.text('lunes'), findsOneWidget);
      final fila = find.ancestor(
        of: find.text('lunes'),
        matching: find.byType(InkWell),
      );
      expect(tester.getSize(fila.first).height, greaterThanOrEqualTo(56));
    });

    testWidgets('las celdas de la tira se tocan y miden 48 dp', (tester) async {
      final tocados = <int>[];
      await montarGim(
        tester,
        LineaSemana(dias: _semana(3), alTocarDia: tocados.add),
        ancho: 420,
      );
      final celdas = find.byType(InkWell);
      expect(celdas, findsNWidgets(7));
      for (final e in celdas.evaluate()) {
        final t = tester.getSize(find.byWidget(e.widget));
        expect(t.width, greaterThanOrEqualTo(48));
        expect(t.height, greaterThanOrEqualTo(48));
      }
      await tester.tap(celdas.at(4));
      expect(tocados, [4]);
    });

    testWidgets('cada día se lee completo: día, hoy, qué toca y su estado', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await montarGim(tester, LineaSemana(dias: _semana(4)), ancho: 420);
      final etiquetas = etiquetasAccesibles(tester);
      expect(etiquetas, contains('lunes, Fuerza A, hecho'));
      expect(etiquetas, contains('martes, Fuerza C, pendiente'));
      expect(etiquetas, contains('miércoles, hoy, Fuerza B, pendiente'));
      expect(etiquetas, contains('viernes, Regenerativa 1, pendiente'));
      expect(etiquetas, contains('sábado, Bicicleta, pendiente, con aviso'));
      handle.dispose();
    });

    testWidgets('la leyenda dice con palabras los estados que aparecen', (
      tester,
    ) async {
      await montarGim(tester, LineaSemana(dias: _semana(3)), ancho: 420);
      expect(find.text('Hecho'), findsOneWidget);
      expect(find.text('Pendiente'), findsOneWidget);
      expect(find.text('Hoy'), findsOneWidget);
      expect(find.text('Con aviso'), findsOneWidget);
    });

    testWidgets('el aviso de 48 horas va con icono y la palabra «Aviso»', (
      tester,
    ) async {
      await montarGim(
        tester,
        LineaSemana(
          dias: _semana(3),
          avisos: const ['A y B comparten hombro; mejor 30 min más tarde.'],
        ),
        ancho: 420,
      );
      expect(
        find.text('Aviso: A y B comparten hombro; mejor 30 min más tarde.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.info_outline), findsWidgets);
    });

    testWidgets('estados: vacío, cargando, sin conexión y error', (
      tester,
    ) async {
      var reintentos = 0;
      var armar = 0;
      for (final estado in [
        EstadoVistaGimnasio.vacio,
        EstadoVistaGimnasio.cargando,
        EstadoVistaGimnasio.sinConexion,
        EstadoVistaGimnasio.error,
      ]) {
        await montarGim(
          tester,
          LineaSemana(
            dias: const [],
            estado: estado,
            alReintentar: () => reintentos++,
            alAccionVacia: () => armar++,
          ),
        );
        expect(find.byType(CuerpoEstadoGimnasio), findsOneWidget);
      }
      await tester.tap(find.text(TextosGimnasio.reintentar));
      expect(reintentos, 1);
      await montarGim(
        tester,
        LineaSemana(dias: const [], alAccionVacia: () => armar++),
      );
      await tester.tap(find.text('Armar mi semana'));
      expect(armar, 1);
      await desmontar(tester);
    });

    for (final (ancho, letra) in [(360.0, 2.0), (900.0, 2.0), (420.0, 1.0)]) {
      testWidgets('ancho ${ancho.toInt()} dp con letra $letra sin desbordes', (
        tester,
      ) async {
        final desbordes = await recolectarDesbordes(() async {
          await montarGim(
            tester,
            LineaSemana(
              dias: _semana(5),
              avisos: const ['Fuerza C y la bicicleta comparten piernas.'],
              alTocarDia: (_) {},
            ),
            ancho: ancho,
            letra: letra,
          );
        });
        expect(desbordes, isEmpty);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
