// Gadgets de la Fase 2 de Finanzas (deudas, ahorro, avisos): lógica pura,
// montos ocultos, 48 dp, semáforos con texto, letra al 200 % en 360 dp sin
// desbordes y contraste, de día y de noche.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/diseno/diseno.dart';

import '../ayuda_pruebas.dart';
import 'ayuda_finanzas.dart';

/// Todos los gadgets con datos de ejemplo (nunca datos reales), para barridos.
Map<String, Widget Function()> _todos() => {
  'BarraLimite': () => const BarraLimite(
    usadoCentavos: 4500000,
    limiteCentavos: 10000000,
    etiqueta: 'Tarjeta de ejemplo con un nombre bastante largo',
  ),
  'BarraLimite sin límite': () => BarraLimite(
    usadoCentavos: 100,
    limiteCentavos: null,
    alCapturarLimite: () {},
  ),
  'EscaleraFondo': () => EscaleraFondo(
    nivelActual: 2,
    nivelMeta: 3,
    nivelSugerido: 4,
    semanasCubiertas: 6.9,
    estado: EstadoSemaforo.ambar,
    metasCentavos: const [700000, 1400000, 4550000, 9100000, 18200000],
    alElegirNivel: (_) {},
  ),
  'TarjetaDeuda': () => TarjetaDeuda(
    acreedor: 'Crédito automotriz de ejemplo con nombre largo',
    clase: 'Crédito',
    saldoCentavos: 18500000,
    tasaAnualPuntosBase: 1850,
    interesMensualCentavos: 285000,
    proximoPagoTexto: 'jue 12 nov',
    proximoPagoCentavos: 520000,
    avance: 0.35,
    alTocar: () {},
  ),
  'TarjetaDeuda sin tasa': () => TarjetaDeuda(
    acreedor: 'Tarjeta B',
    clase: 'Tarjeta',
    saldoCentavos: 1200000,
    alCapturarTasa: () {},
  ),
  'LineaVencimientos': () => LineaVencimientos(
    semanas: const [
      SemanaVencimientos(
        etiqueta: 'Sem 45 · 2 al 8 nov',
        actual: true,
        eventos: [
          EventoVencimiento(
            tipo: TipoVencimiento.limite,
            titulo: 'Tarjeta de ejemplo',
            diaTexto: 'jue 5 nov',
            montoCentavos: 123400,
          ),
          EventoVencimiento(
            tipo: TipoVencimiento.msi,
            titulo: 'Celular a 12 MSI',
            diaTexto: 'vie 6 nov',
            montoCentavos: 83333,
            vencido: true,
          ),
        ],
      ),
      SemanaVencimientos(etiqueta: 'Sem 46 · 9 al 15 nov'),
      SemanaVencimientos(
        etiqueta: 'Sem 47 · 16 al 22 nov',
        eventos: [
          EventoVencimiento(
            tipo: TipoVencimiento.corte,
            titulo: 'Tarjeta de ejemplo',
            diaTexto: 'lun 16 nov',
          ),
        ],
      ),
      SemanaVencimientos(etiqueta: 'Sem 48 · 23 al 29 nov'),
    ],
    totalesMsi: const [
      TotalMsiDelMes('Noviembre', 83333),
      TotalMsiDelMes('Diciembre', 83333),
    ],
    alTocarEvento: (_) {},
  ),
  'BolsaAhorro': () => BolsaAhorro(
    nombre: 'Viaje de ejemplo con un nombre largo para probar',
    tipo: TipoBolsa.metaConFecha,
    saldoCentavos: 350000,
    metaCentavos: 1000000,
    pendienteCentavos: 25000,
    proyeccionCentavos: 1000000,
    proyeccionFechaTexto: '12 de marzo',
    estado: EstadoSemaforo.ambar,
    textoEstado: 'En camino',
    alTocar: () {},
  ),
  'OrdenPago': () => OrdenPago(
    lugares: const [
      LugarOrdenPago(
        acreedor: 'Tarjeta B de ejemplo',
        motivo: 'tasa 60 %',
        abonoCentavos: 150000,
      ),
      LugarOrdenPago(acreedor: 'Papá (préstamo)', motivo: 'familiar: al final'),
      LugarOrdenPago(
        acreedor: 'Celular a MSI',
        motivo: 'MSI: no recibe extra',
        fijo: true,
      ),
    ],
    alSubir: (_) {},
    alBajar: (_) {},
  ),
  'ChipNivelAlerta': () => const Wrap(
    spacing: 8,
    children: [
      ChipNivelAlerta(nivel: NivelAlerta.critica),
      ChipNivelAlerta(nivel: NivelAlerta.importante),
      ChipNivelAlerta(nivel: NivelAlerta.informativa),
    ],
  ),
  'FilaAviso': () => FilaAviso(
    nivel: NivelAlerta.critica,
    titulo: 'Pago de deuda próximo con un título algo largo',
    libro: 'Gastos de la casa',
    cuandoTexto: 'hoy 8:00',
    alTocar: () {},
  ),
  'VistaPreviaAviso bloqueo': () => VistaPreviaAviso(
    titulo: 'Tienes un pago próximo',
    superficie: SuperficieAviso.bloqueo,
  ),
  'VistaPreviaAviso pulsera': () => VistaPreviaAviso(
    titulo: 'Tienes un pago próximo',
    superficie: SuperficieAviso.pulsera,
  ),
  'EstadoCargando': () => const EstadoCargando(),
  'EstadoError': () => EstadoError(
    mensaje: 'No pudimos cargar tus deudas',
    detalle: 'Revisa tu conexión e inténtalo de nuevo.',
    sinConexion: true,
    alReintentar: () {},
  ),
};

void main() {
  group('UsoLimite (regla 7: verde <30 %, ámbar 30 a 60 %, rojo >60 %)', () {
    EstadoSemaforo? e(int usado, [int? limite = 10000]) =>
        UsoLimite(usadoCentavos: usado, limiteCentavos: limite).estado;

    test('umbrales con la fracción exacta', () {
      expect(e(2999), EstadoSemaforo.verde);
      expect(e(3000), EstadoSemaforo.ambar);
      expect(e(6000), EstadoSemaforo.ambar);
      expect(e(6001), EstadoSemaforo.rojo);
      expect(e(0), EstadoSemaforo.verde);
      expect(e(20000), EstadoSemaforo.rojo);
    });

    test('porcentaje hacia arriba y sin límite no se calcula', () {
      expect(
        const UsoLimite(usadoCentavos: 2901, limiteCentavos: 10000).porcentaje,
        30,
      );
      expect(e(100, null), isNull);
      expect(e(100, 0), isNull);
      expect(
        const UsoLimite(usadoCentavos: 5, limiteCentavos: null).porcentaje,
        isNull,
      );
      expect(
        const UsoLimite(usadoCentavos: 20000, limiteCentavos: 10000).fraccion,
        1,
      );
    });
  });

  group('contenido y accesibilidad', () {
    testWidgets(
      'BarraLimite: porcentaje, semáforo con texto y montos ocultos',
      (tester) async {
        final semantica = tester.ensureSemantics();
        await montarEnFinanzas(
          tester,
          const BarraLimite(
            usadoCentavos: 4500000,
            limiteCentavos: 10000000,
            etiqueta: 'Tarjeta X',
          ),
          montosVisibles: false,
        );
        expect(find.text('45 % del límite'), findsOneWidget);
        expect(find.text('Uso medio'), findsOneWidget);
        expect(find.text(montoOculto), findsNWidgets(2));
        expect(find.textContaining(r'$'), findsNothing);
        expect(
          find.bySemanticsLabel('Uso del límite: Tarjeta X'),
          findsOneWidget,
        );
        semantica.dispose();
      },
    );

    testWidgets('BarraLimite: sin límite pide capturarlo y no calcula', (
      tester,
    ) async {
      var capturas = 0;
      await montarEnFinanzas(
        tester,
        BarraLimite(
          usadoCentavos: 100,
          limiteCentavos: null,
          alCapturarLimite: () => capturas++,
        ),
      );
      expect(find.text('Captura el límite de esta tarjeta'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
      await tester.tap(find.text('Capturar límite'));
      expect(capturas, 1);
    });

    testWidgets('EscaleraFondo: 5 peldaños, marcas con texto y semanas', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      final elegidos = <int>[];
      await montarEnFinanzas(
        tester,
        EscaleraFondo(
          nivelActual: 2,
          nivelMeta: 3,
          nivelSugerido: 4,
          semanasCubiertas: 2.96,
          estado: EstadoSemaforo.rojo,
          alElegirNivel: elegidos.add,
        ),
      );
      for (final n in nivelesFondo) {
        expect(find.text('${n.numero}. ${n.nombre}'), findsOneWidget);
      }
      expect(find.text('Tienes 2.9 semanas cubiertas'), findsOneWidget);
      expect(find.text('Bajo la mitad de la meta'), findsOneWidget);
      expect(find.text('Actual'), findsOneWidget);
      expect(find.text('Meta'), findsOneWidget);
      expect(find.text('Sugerido'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('Nivel 3: Tres meses.*meta')),
        findsOneWidget,
      );
      await tester.tap(find.text('4. Seis meses'));
      expect(elegidos, [4]);
      semantica.dispose();
    });

    testWidgets('EscaleraFondo: sin gasto esencial no hay semáforo', (
      tester,
    ) async {
      await montarEnFinanzas(
        tester,
        const EscaleraFondo(
          nivelActual: 0,
          nivelMeta: 3,
          estado: EstadoSemaforo.verde,
        ),
      );
      expect(find.text('Sin gasto esencial calculado'), findsOneWidget);
      expect(find.text('Meta cubierta'), findsNothing);
    });

    testWidgets('TarjetaDeuda: sin tasa pide capturarla; liquidada sugiere '
        'archivar', (tester) async {
      var capturas = 0;
      await montarEnFinanzas(
        tester,
        TarjetaDeuda(
          acreedor: 'Tarjeta B',
          clase: 'Tarjeta',
          saldoCentavos: 100000,
          alCapturarTasa: () => capturas++,
        ),
      );
      expect(find.text('Captura la tasa'), findsOneWidget);
      expect(find.text(r'$1,000.00'), findsOneWidget);
      await tester.tap(find.text('Capturar'));
      expect(capturas, 1);
    });

    testWidgets('TarjetaDeuda liquidada', (tester) async {
      await montarEnFinanzas(
        tester,
        const TarjetaDeuda(
          acreedor: 'Tarjeta B',
          clase: 'Tarjeta',
          saldoCentavos: 0,
          liquidada: true,
          proximoPagoTexto: 'jue 12 nov',
        ),
      );
      expect(find.text('Liquidada'), findsOneWidget);
      expect(find.text('Sin saldo: puedes archivarla.'), findsOneWidget);
      expect(find.textContaining('Próximo pago'), findsNothing);
    });

    testWidgets('TarjetaDeuda: la tasa se ve aunque los montos estén ocultos', (
      tester,
    ) async {
      await montarEnFinanzas(
        tester,
        const TarjetaDeuda(
          acreedor: 'Tarjeta B',
          clase: 'Tarjeta',
          saldoCentavos: 100000,
          tasaAnualPuntosBase: 6000,
          interesMensualCentavos: 5000,
          proximoPagoTexto: 'jue 12 nov',
          proximoPagoCentavos: 20000,
          avance: 0.4,
        ),
        montosVisibles: false,
      );
      expect(find.text('Tasa 60.0 %'), findsOneWidget);
      expect(find.text(montoOculto), findsNWidgets(3));
      expect(find.textContaining(r'$'), findsNothing);
    });

    testWidgets('LineaVencimientos: tipos con texto, vencido marcado y MSI', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      await montarEnFinanzas(
        tester,
        _todos()['LineaVencimientos']!(),
        montosVisibles: false,
      );
      expect(find.textContaining('Vencido · Mensualidad MSI'), findsOneWidget);
      expect(find.textContaining('Fecha límite · jue 5 nov'), findsOneWidget);
      expect(find.text('Sin vencimientos'), findsNWidgets(2));
      expect(find.text('Esta semana'), findsOneWidget);
      expect(find.text('MSI POR MES'), findsOneWidget);
      expect(find.textContaining(r'$'), findsNothing);
      expect(
        find.bySemanticsLabel(
          'Vencido, Mensualidad MSI: Celular a 12 MSI, vie 6 nov',
        ),
        findsOneWidget,
      );
      semantica.dispose();
    });

    testWidgets('LineaVencimientos sin eventos lo dice', (tester) async {
      await montarEnFinanzas(
        tester,
        const LineaVencimientos(
          semanas: [
            SemanaVencimientos(etiqueta: 'a'),
            SemanaVencimientos(etiqueta: 'b'),
            SemanaVencimientos(etiqueta: 'c'),
            SemanaVencimientos(etiqueta: 'd'),
          ],
        ),
      );
      expect(
        find.text('Sin vencimientos en las próximas 4 semanas'),
        findsOneWidget,
      );
    });

    testWidgets('BolsaAhorro: avance visible, pendiente sin castigo, montos '
        'ocultos', (tester) async {
      await montarEnFinanzas(
        tester,
        _todos()['BolsaAhorro']!(),
        montosVisibles: false,
      );
      expect(find.text('35 %'), findsOneWidget);
      expect(find.text('En camino'), findsOneWidget);
      expect(find.text('Pendiente'), findsOneWidget);
      expect(find.text('· sin intereses ni castigo'), findsOneWidget);
      expect(find.text('el 12 de marzo'), findsOneWidget);
      expect(find.textContaining(r'$'), findsNothing);
    });

    testWidgets('OrdenPago: motivo de cada lugar y botones de 48 dp', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      final subidos = <int>[];
      await montarEnFinanzas(
        tester,
        OrdenPago(
          lugares: const [
            LugarOrdenPago(acreedor: 'A', motivo: 'tasa 60 %'),
            LugarOrdenPago(acreedor: 'B', motivo: 'grupo, lugar 2'),
            LugarOrdenPago(
              acreedor: 'C',
              motivo: 'MSI: no recibe extra',
              fijo: true,
            ),
          ],
          alSubir: subidos.add,
          alBajar: (_) {},
        ),
      );
      expect(find.text('tasa 60 %'), findsOneWidget);
      expect(find.text('MSI: no recibe extra'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(
        find.bySemanticsLabel('Lugar 2: B, grupo, lugar 2'),
        findsOneWidget,
      );
      // El primero no sube; el último movible no baja si es el último.
      await tester.tap(find.byTooltip('Subir B'));
      expect(subidos, [1]);
      await tester.tap(find.byTooltip('Subir A'), warnIfMissed: false);
      expect(subidos, [1]);
      for (final boton in find.byType(IconButton).evaluate()) {
        final t = tester.getSize(find.byWidget(boton.widget));
        expect(t.width, greaterThanOrEqualTo(zonaTactilMinima));
        expect(t.height, greaterThanOrEqualTo(zonaTactilMinima));
      }
      semantica.dispose();
    });

    testWidgets('ChipNivelAlerta: icono y texto distintos por nivel', (
      tester,
    ) async {
      await montarEnFinanzas(tester, _todos()['ChipNivelAlerta']!());
      for (final n in NivelAlerta.values) {
        expect(find.text(n.etiqueta), findsOneWidget);
        expect(find.byIcon(n.icono), findsOneWidget);
      }
      expect(
        {for (final n in NivelAlerta.values) n.icono}.length,
        NivelAlerta.values.length,
      );
    });

    testWidgets('FilaAviso: sin leer en negritas y con punto; 48 dp', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      await montarEnFinanzas(
        tester,
        FilaAviso(
          nivel: NivelAlerta.importante,
          titulo: 'Fondo de emergencia bajo',
          libro: 'Mi libro',
          cuandoTexto: 'ayer',
          alTocar: () {},
        ),
      );
      final titulo = tester.widget<Text>(find.text('Fondo de emergencia bajo'));
      expect(titulo.style?.fontWeight, FontWeight.w700);
      expect(find.byIcon(Icons.circle), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Sin leer. Importante: Fondo de emergencia bajo, Mi libro, ayer',
        ),
        findsOneWidget,
      );
      expect(
        tester.getSize(find.byType(FilaAviso)).height,
        greaterThanOrEqualTo(zonaTactilMinima),
      );
      semantica.dispose();
    });

    testWidgets('VistaPreviaAviso: título genérico, sin cifras', (
      tester,
    ) async {
      await montarEnFinanzas(tester, _todos()['VistaPreviaAviso bloqueo']!());
      expect(find.text('Tienes un pago próximo'), findsOneWidget);
      expect(find.text('Finanzas · Urgentes'), findsOneWidget);
      expect(find.textContaining(RegExp(r'[\d$]')), findsNothing);
    });

    test('VistaPreviaAviso rechaza cifras en el título (D3)', () {
      expect(
        () => VistaPreviaAviso(
          titulo: r'Pago de $1,200',
          superficie: SuperficieAviso.bloqueo,
        ),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => VistaPreviaAviso(
          titulo: 'Vence en 3 días',
          superficie: SuperficieAviso.pulsera,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    testWidgets('EstadoError: Reintentar de 48 dp, sin reintento solo', (
      tester,
    ) async {
      var reintentos = 0;
      await montarEnFinanzas(
        tester,
        EstadoError(
          mensaje: 'Sin conexión',
          sinConexion: true,
          alReintentar: () => reintentos++,
        ),
      );
      expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
      expect(reintentos, 0);
      expect(
        tester.getSize(find.byType(OutlinedButton)).height,
        greaterThanOrEqualTo(zonaTactilMinima),
      );
      await tester.tap(find.text('Reintentar'));
      expect(reintentos, 1);
    });

    testWidgets('EstadoCargando se detiene con "reducir movimiento"', (
      tester,
    ) async {
      await montarEnFinanzas(tester, const EstadoCargando());
      expect(find.text('Cargando…'), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('letra al 200 % en 360 dp, de día y de noche: sin desbordes', () {
    for (final escala in [1.0, 1.3, 2.0]) {
      for (final (hora, momento) in [
        ('noche', momentoNoche),
        ('día', momentoDia),
      ]) {
        for (final nombre in _todos().keys) {
          testWidgets('$nombre · x$escala · $hora', (tester) async {
            fijarVentana(tester, const Size(360, 900));
            fijarEscalaDeLetra(tester, escala);
            final desbordes = await recolectarDesbordes(() async {
              await montarEnFinanzas(
                tester,
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _todos()[nombre]!(),
                ),
                ancho: 360,
                momento: momento,
              );
            });
            expect(desbordes, isEmpty);
            // Nada se sale por la derecha.
            for (final elemento in find.byType(Text).evaluate()) {
              final r = tester.getRect(find.byWidget(elemento.widget));
              expect(r.right, lessThanOrEqualTo(360.5), reason: nombre);
            }
          });
        }
      }
    }
  });

  group('contraste del texto (4.5:1), de día y de noche', () {
    for (final (hora, momento) in [
      ('noche', momentoNoche),
      ('día', momentoDia),
    ]) {
      testWidgets('colores de lectura sobre panel · $hora', (tester) async {
        await montarEnFinanzas(
          tester,
          const BarraLimite(usadoCentavos: 1, limiteCentavos: 100),
          momento: momento,
        );
        final v = valoresDe(tester, find.byType(BarraLimite));
        for (final color in [v.texto, v.textoFuerte, v.textoTenue]) {
          expect(
            razonContraste(color, v.panel),
            greaterThanOrEqualTo(contrasteMinimoTexto),
          );
        }
        // Chip de nivel: texto fuerte sobre el relleno mezclado de cada nivel.
        for (final n in NivelAlerta.values) {
          final fondo = Color.alphaBlend(
            n.color(v).withValues(alpha: 0.12),
            v.panel,
          );
          expect(
            razonContraste(v.textoFuerte, fondo),
            greaterThanOrEqualTo(contrasteMinimoTexto),
            reason: n.etiqueta,
          );
        }
        // Peldaño elegido de la escalera.
        expect(
          razonContraste(v.textoFuerte, v.chipSeleccionado),
          greaterThanOrEqualTo(contrasteMinimoTexto),
        );
        // Semáforos: texto del estado sobre el panel.
        for (final estado in EstadoSemaforo.values) {
          expect(
            razonContraste(v.textoFuerte, v.panel),
            greaterThanOrEqualTo(contrasteMinimoTexto),
            reason: estado.etiqueta,
          );
        }
      });
    }
  });
}
