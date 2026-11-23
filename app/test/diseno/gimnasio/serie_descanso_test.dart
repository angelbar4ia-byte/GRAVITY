// Gadget «Serie y descanso» (7.2, 10 y CA-G-41): serie, series con estado en
// icono y palabra, temporizador, tablet legible desde 2 m y los cuatro estados.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/diseno/diseno.dart';

import '../ayuda_pruebas.dart' show recolectarDesbordes;
import 'ayuda_gimnasio.dart';

GadgetSerieDescanso _gadget(
  RelojGimnasio reloj, {
  EscalaTemporizador escala = EscalaTemporizador.compacta,
  EstadoVistaGimnasio estado = EstadoVistaGimnasio.listo,
  VoidCallback? alReintentar,
  bool conControles = false,
}) => GadgetSerieDescanso(
  ejercicio: 'Elevaciones laterales',
  puestoTexto: 'Polea baja',
  serieActual: 2,
  seriesTotales: 3,
  repeticionesTexto: '12 repeticiones',
  cargaTexto: 'Placa 3',
  series: const [
    SerieVista(
      numero: 1,
      estado: EstadoSerie.hecha,
      repeticiones: 12,
      cargaTexto: 'placa 3',
    ),
    SerieVista(
      numero: 2,
      estado: EstadoSerie.enDescanso,
      repeticiones: 12,
      cargaTexto: 'placa 3',
    ),
    SerieVista(
      numero: 3,
      estado: EstadoSerie.pendiente,
      repeticiones: 12,
      cargaTexto: 'placa 3',
    ),
  ],
  descanso: DescansoPlanificado.iniciar(
    reloj.momento,
    const Duration(seconds: 48),
  ),
  siguiente: 'Tríceps en polea alta',
  escala: escala,
  ahora: reloj.ahora,
  estado: estado,
  alReintentar: alReintentar,
  alMasQuince: conControles ? () {} : null,
  alMenosQuince: conControles ? () {} : null,
  alSaltar: conControles ? () {} : null,
);

void main() {
  testWidgets('muestra el ejercicio, la serie, la carga y lo que sigue', (
    tester,
  ) async {
    final reloj = RelojGimnasio();
    await montarGim(tester, _gadget(reloj), sport: true);
    expect(find.text('Elevaciones laterales'), findsOneWidget);
    expect(find.text('Polea baja'), findsOneWidget);
    expect(
      find.text('Serie 2 de 3 · 12 repeticiones · Placa 3'),
      findsOneWidget,
    );
    expect(find.text('Sigue: Tríceps en polea alta'), findsOneWidget);
    expect(find.text('00:48'), findsOneWidget);
    await desmontar(tester);
  });

  testWidgets('cada serie lleva icono y palabra, y se lee con su estado', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final reloj = RelojGimnasio();
    await montarGim(tester, _gadget(reloj), sport: true);
    for (final texto in ['1 · Hecha', '2 · En descanso', '3 · Pendiente']) {
      expect(find.text(texto), findsOneWidget);
    }
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
    expect(
      etiquetasAccesibles(tester),
      containsAll([
        'Serie 1 de 3, 12 repeticiones, placa 3, hecha',
        'Serie 2 de 3, 12 repeticiones, placa 3, en descanso',
        'Serie 3 de 3, 12 repeticiones, placa 3, pendiente',
      ]),
    );
    handle.dispose();
    await desmontar(tester);
  });

  test('el anuncio de una serie es el que pide la especificación', () {
    const chip = ChipSerie(
      serie: SerieVista(
        numero: 2,
        estado: EstadoSerie.pendiente,
        repeticiones: 12,
        cargaTexto: 'placa 3',
      ),
      total: 3,
    );
    expect(chip.anuncio, 'Serie 2 de 3, 12 repeticiones, placa 3, pendiente');
  });

  testWidgets('con precaución dice la palabra, no solo el color', (
    tester,
  ) async {
    await montarGim(
      tester,
      const ChipSerie(
        serie: SerieVista(numero: 1, estado: EstadoSerie.conPrecaucion),
        total: 3,
      ),
    );
    expect(find.text('1 · Con precaución'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_outlined), findsOneWidget);
  });

  testWidgets('en la tablet el temporizador pasa a la derecha con números de '
      'más de 96 dp', (tester) async {
    final reloj = RelojGimnasio();
    await montarGim(
      tester,
      _gadget(reloj, escala: EscalaTemporizador.tablet),
      sport: true,
      ancho: 1000,
    );
    final texto = tester.widget<Text>(
      find.byKey(const ValueKey('descanso-restante')),
    );
    expect(texto.style!.fontSize, greaterThan(96));
    final x = tester
        .getCenter(find.byKey(const ValueKey('descanso-restante')))
        .dx;
    final xEjercicio = tester.getCenter(find.text('Elevaciones laterales')).dx;
    expect(x, greaterThan(xEjercicio));
    await desmontar(tester);
  });

  testWidgets('sin descanso en curso lo dice con palabras', (tester) async {
    await montarGim(
      tester,
      const GadgetSerieDescanso(
        ejercicio: 'Plancha',
        serieActual: 1,
        seriesTotales: 3,
        repeticionesTexto: '30 s',
      ),
      sport: true,
    );
    expect(find.text(TextosGimnasio.sinDescanso), findsOneWidget);
  });

  testWidgets('estados: vacío, cargando, sin conexión y error con Reintentar '
      'de 48 dp', (tester) async {
    final reloj = RelojGimnasio();
    var reintentos = 0;
    for (final estado in [
      EstadoVistaGimnasio.vacio,
      EstadoVistaGimnasio.cargando,
      EstadoVistaGimnasio.sinConexion,
      EstadoVistaGimnasio.error,
    ]) {
      await montarGim(
        tester,
        _gadget(reloj, estado: estado, alReintentar: () => reintentos++),
        sport: true,
      );
      expect(
        find.byType(CuerpoEstadoGimnasio),
        findsOneWidget,
        reason: '$estado',
      );
      expect(find.text('Elevaciones laterales'), findsNothing);
    }
    final boton = find.widgetWithText(
      OutlinedButton,
      TextosGimnasio.reintentar,
    );
    expect(tester.getSize(boton).height, greaterThanOrEqualTo(48));
    await tester.tap(boton);
    expect(reintentos, 1);
    await desmontar(tester);
  });

  for (final ancho in [360.0, 900.0]) {
    testWidgets('letra al 200 % en ${ancho.toInt()} dp sin desbordes', (
      tester,
    ) async {
      final reloj = RelojGimnasio();
      final desbordes = await recolectarDesbordes(() async {
        await montarGim(
          tester,
          _gadget(reloj, conControles: true),
          sport: true,
          ancho: ancho,
          letra: 2.0,
        );
      });
      expect(desbordes, isEmpty);
      expect(tester.takeException(), isNull);
      await desmontar(tester);
    });
  }
}
