// Gadgets de Hábitos (Fase 3): lógica pura, sensibles ocultos, 48 dp, texto
// además del color, letra al 200 % en 360 dp y 900 dp sin desbordes, contraste
// con las tres personalidades (Hábitos, contemplativa y empática).
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/diseno/diseno.dart';
import 'package:gravity/nucleo/contratos/roles.dart';

import '../ayuda_pruebas.dart';
import '../finanzas/ayuda_finanzas.dart' show valoresDe;

/// Monta [hijo] con la personalidad pedida, a [ancho] dp.
Future<void> _montar(
  WidgetTester tester,
  Widget hijo, {
  Submodulo? submodulo,
  double ancho = 360,
  bool visibles = true,
  DateTime? momento,
}) => montar(
  tester,
  Scaffold(
    body: TemaModulo(
      modulo: Modulo.habitos,
      submodulo: submodulo,
      child: SingleChildScrollView(
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: ancho,
            child: Padding(padding: const EdgeInsets.all(16), child: hijo),
          ),
        ),
      ),
    ),
  ),
  montosVisibles: visibles,
  momento: momento,
);

Map<String, (Widget Function(), Submodulo?)> _todos() => {
  'AnillosDia': (
    () => const AnillosDia(
      anillos: [
        AnilloDia('Cuerpo', 0.6, textoValor: '3 de 5'),
        AnilloDia('Espíritu y estudio', 1),
        AnilloDia('Trabajo', 0),
      ],
    ),
    null,
  ),
  'MedidorCarga': (
    () => const MedidorCarga(planeadosMin: 540, disponiblesMin: 480),
    null,
  ),
  'FilaHabito': (
    () => FilaHabito(
      titulo: 'Leer un capítulo completo del libro del mes con notas',
      horaTexto: '20:00',
      detalle: '30 min',
      racha: 12,
      alHecho: () {},
      alPosponer: () {},
      alOmitir: () {},
    ),
    null,
  ),
  'TarjetaSigue': (
    () => TarjetaSigue(
      titulo: 'Inglés: lección del día con un nombre largo',
      horaTexto: '20:00',
      enCurso: true,
      transcurridoTexto: '12 min',
      alHecho: () {},
      alPosponer: () {},
    ),
    null,
  ),
  'ChipRacha': (
    () => const Wrap(
      spacing: 8,
      children: [
        ChipRacha(dias: 12, graciaUsada: true),
        ChipRacha(dias: 0, retomemos: true),
        ChipRacha(dias: 40, global: true),
      ],
    ),
    null,
  ),
  'CalendarioConstancia': (
    () => const CalendarioConstancia(
      dias: [
        DiaConstancia('L', EstadoDiaConstancia.cumplido),
        DiaConstancia('M', EstadoDiaConstancia.gracia),
        DiaConstancia('M', EstadoDiaConstancia.noCumplido),
        DiaConstancia('J', EstadoDiaConstancia.noAplica),
        DiaConstancia('V', EstadoDiaConstancia.cumplido, hoy: true),
        DiaConstancia('S', EstadoDiaConstancia.noAplica),
        DiaConstancia('D', EstadoDiaConstancia.noAplica),
      ],
    ),
    null,
  ),
  'PanelHabitoEliminar': (
    () => PanelHabitoEliminar(
      nombre: 'Cigarrillo',
      fase: FaseHabito.libre,
      estadoHoyTexto: 'Cero hoy',
      rachaActual: 5,
      mejorRacha: 9,
      diasLibresAcumulados: 21,
      alRegistrar: () {},
      alAntojo: () {},
    ),
    Submodulo.habitosEliminar,
  ),
  'PanelReduccion': (
    () => PanelHabitoEliminar(
      nombre: 'Azúcar',
      fase: FaseHabito.reduccion,
      estadoHoyTexto: 'Hoy: 7 de 6',
      preguntaSuave: '¿Qué te ayudaría mañana?',
      diasParaDiaD: 9,
      semaforo: const SemaforoRefresco(usadas: 3, limite: 4),
      alRegistrar: () {},
      alAntojo: () {},
    ),
    Submodulo.habitosEliminar,
  ),
  'ContadorDiasLibres': (
    () => const ContadorDiasLibres(
      rachaActual: 128,
      mejorRacha: 128,
      acumulados: 130,
    ),
    Submodulo.habitosEliminar,
  ),
  'BotonPausa': (() => BotonPausa(alTocar: () {}, expandido: true), null),
  'RespiracionGuiada': (() => const RespiracionGuiada(), null),
  'TemporizadorSos': (() => const TemporizadorSos(), null),
  'LectorBiblico': (
    () => LectorBiblico(
      referencia: 'Salmo 23',
      version: 'Versión de ejemplo',
      versiculos: const [
        VersiculoLector(1, 'El Señor es mi pastor; nada me faltará.'),
        VersiculoLector(
          2,
          'En lugares de delicados pastos me hará descansar; junto a aguas '
          'de reposo me pastoreará.',
          subrayado: true,
        ),
      ],
      alTocarVersiculo: (_) {},
    ),
    Submodulo.espiritual,
  ),
  'TarjetaPlanLectura': (
    () => TarjetaPlanLectura(
      titulo: 'La Biblia en un año',
      avance: 0.3,
      lecturaDeHoy: 'Salmo 23 · Juan 1:1-18',
      diaTexto: 'Día 110 de 365',
      diasAtrasado: 3,
      alLeer: () {},
      alPonerseAlDia: () {},
    ),
    Submodulo.espiritual,
  ),
  'TarjetaDevocional': (
    () => TarjetaDevocional(
      referencia: 'Filipenses 4:6-7',
      pensamiento: 'Hoy entrego lo que me preocupa.',
      alLeer: () {},
    ),
    Submodulo.espiritual,
  ),
  'FilaOracion': (
    () => FilaOracion(
      texto: 'Por la salud de la familia y por el trabajo de esta semana',
      respondida: true,
      fechaTexto: 'hace 2 semanas',
      alTocar: () {},
    ),
    Submodulo.espiritual,
  ),
  'TarjetaObjetivo': (
    () => TarjetaObjetivo(
      titulo: 'Terminar el curso de inglés nivel intermedio',
      area: 'Estudio',
      avance: 0.4,
      avanceTexto: '12 de 30 lecciones',
      ritmoTexto: 'Necesitas 2 por semana',
      racha: 6,
      alTocar: () {},
    ),
    null,
  ),
  'ResumenSemanal': (
    () => ResumenSemanal(
      areas: const [
        CumplimientoArea('Cuerpo', 0.8),
        CumplimientoArea('Espíritu', 1),
        CumplimientoArea('Estudio', 0.35),
      ],
      alCerrar: () {},
    ),
    null,
  ),
  'EstadoVacioHabitos': (
    () => EstadoVacioHabitos(
      tipo: VacioHabitos.soloTelefono,
      textoAccion: 'Cómo activar la nube cifrada',
      alAccionar: () {},
    ),
    null,
  ),
};

void main() {
  group('EstadoRefresco (regla 45)', () {
    test('límite 4: 0 a 2 verde, 3 y 4 ámbar, 5 terracota', () {
      final r = [
        for (var u = 0; u <= 5; u++) EstadoRefresco.de(usadas: u, limite: 4),
      ];
      expect(r, [
        EstadoRefresco.verde,
        EstadoRefresco.verde,
        EstadoRefresco.verde,
        EstadoRefresco.ambar,
        EstadoRefresco.ambar,
        EstadoRefresco.terracota,
      ]);
    });

    test('límite 1 y límite 0', () {
      expect(EstadoRefresco.de(usadas: 0, limite: 1), EstadoRefresco.verde);
      expect(EstadoRefresco.de(usadas: 1, limite: 1), EstadoRefresco.ambar);
      expect(EstadoRefresco.de(usadas: 2, limite: 1), EstadoRefresco.terracota);
      expect(EstadoRefresco.de(usadas: 0, limite: 0), EstadoRefresco.verde);
      expect(EstadoRefresco.de(usadas: 1, limite: 0), EstadoRefresco.terracota);
    });
  });

  test('CargaDia: ligero, lleno y cargado', () {
    EstadoSemaforo e(int p) =>
        CargaDia(planeadosMin: p, disponiblesMin: 400).estado;
    expect(e(200), EstadoSemaforo.verde);
    expect(e(201), EstadoSemaforo.ambar);
    expect(e(340), EstadoSemaforo.ambar);
    expect(e(341), EstadoSemaforo.rojo);
  });

  group('contenido y accesibilidad', () {
    testWidgets('TextoSensible oculto: ni texto ni longitud al lector', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      await _montar(
        tester,
        const TextoSensible('Cigarrillo: 12 al día'),
        visibles: false,
      );
      expect(find.text('Cigarrillo: 12 al día'), findsNothing);
      expect(find.text('••••'), findsOneWidget);
      expect(find.bySemanticsLabel('Contenido privado'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Cigarrillo')), findsNothing);
      semantica.dispose();
    });

    testWidgets('TextoSensible visible y modo privado lo oculta', (
      tester,
    ) async {
      await _montar(tester, const TextoSensible('Oración privada'));
      expect(find.text('Oración privada'), findsOneWidget);
      contenedorDe(
        tester,
        find.byType(TextoSensible),
      ).read(modoPrivadoProvider.notifier).fijar(true);
      await tester.pump();
      expect(find.text('Oración privada'), findsNothing);
    });

    testWidgets('BloqueSensible: tarjeta "Contenido privado" y Ver pide '
        'revelar', (tester) async {
      var pedidos = 0;
      await montar(
        tester,
        Scaffold(body: BloqueSensible(child: const Text('secreto'))),
        overrides: [
          revelarMontosProvider.overrideWithValue((c) async {
            pedidos++;
            return false;
          }),
        ],
      );
      expect(find.text('secreto'), findsNothing);
      expect(find.text('Contenido privado'), findsOneWidget);
      await tester.tap(find.text('Ver'));
      expect(pedidos, 1);
    });

    testWidgets('Panel de hábito oculto: Registrar y Pausa siguen visibles', (
      tester,
    ) async {
      var antojos = 0;
      await _montar(
        tester,
        PanelHabitoEliminar(
          nombre: 'Cigarrillo',
          fase: FaseHabito.libre,
          estadoHoyTexto: 'Cero hoy',
          rachaActual: 5,
          alAntojo: () => antojos++,
          alRegistrar: () {},
        ),
        submodulo: Submodulo.habitosEliminar,
        visibles: false,
      );
      expect(find.text('Cigarrillo'), findsNothing);
      expect(find.text('Cero hoy'), findsNothing);
      expect(find.text('Registrar'), findsOneWidget);
      await tester.tap(find.text('Pausa'));
      expect(antojos, 1);
      expect(
        tester.getSize(find.byType(FilledButton)).height,
        greaterThanOrEqualTo(56),
      );
    });

    testWidgets('línea base: "Solo observamos", sin racha ni semáforo', (
      tester,
    ) async {
      await _montar(
        tester,
        const PanelHabitoEliminar(
          nombre: 'Azúcar',
          fase: FaseHabito.lineaBase,
          rachaActual: 3,
          semaforo: SemaforoRefresco(usadas: 9, limite: 1),
        ),
        submodulo: Submodulo.habitosEliminar,
      );
      expect(find.text('Solo observamos'), findsOneWidget);
      expect(find.text('Días libres'), findsNothing);
      expect(find.textContaining('límite'), findsNothing);
      expect(find.byType(SemaforoRefresco), findsNothing);
    });

    testWidgets('la pregunta suave no usa rojo de alarma ni dice "perdiste"', (
      tester,
    ) async {
      await _montar(
        tester,
        _todos()['PanelReduccion']!.$1(),
        submodulo: Submodulo.habitosEliminar,
      );
      expect(find.text('¿Qué te ayudaría mañana?'), findsOneWidget);
      expect(find.textContaining('perdiste'), findsNothing);
      expect(find.text('Faltan 9 días para el Día D'), findsOneWidget);
      expect(find.text('Cerca de tu límite'), findsOneWidget);
    });

    testWidgets('FilaHabito: Hecho a un toque, menú con Posponer y Omitir', (
      tester,
    ) async {
      final eventos = <String>[];
      await _montar(
        tester,
        FilaHabito(
          titulo: 'Devocional',
          horaTexto: '07:00',
          alHecho: () => eventos.add('hecho'),
          alPosponer: () => eventos.add('posponer'),
          alOmitir: () => eventos.add('omitir'),
        ),
      );
      await tester.tap(find.byTooltip('Hecho'));
      await tester.tap(find.byTooltip('Más acciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Omitir'));
      await tester.pumpAndSettle();
      expect(eventos, ['hecho', 'omitir']);
    });

    testWidgets('FilaHabito: deslizar a la derecha marca Hecho', (
      tester,
    ) async {
      final eventos = <String>[];
      await _montar(
        tester,
        FilaHabito(
          titulo: 'Agua',
          alHecho: () => eventos.add('hecho'),
          alPosponer: () => eventos.add('posponer'),
        ),
      );
      await tester.drag(find.text('Agua'), const Offset(300, 0));
      await tester.pumpAndSettle();
      expect(eventos, ['hecho']);
      await tester.drag(find.text('Agua'), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(eventos, ['hecho', 'posponer']);
    });

    testWidgets('FilaHabito: el lector oye título, hora, estado y racha', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      await _montar(
        tester,
        FilaHabito(
          titulo: 'Devocional',
          horaTexto: '07:00',
          estado: EstadoFila.hecho,
          racha: 3,
          alHecho: () {},
          alPosponer: () {},
        ),
      );
      final nodo = tester.getSemantics(
        find.bySemanticsLabel('Devocional, 07:00, hecho, racha de 3 días'),
      );
      expect(nodo, isSemantics(isChecked: true));
      expect(nodo.hasAction(SemanticsAction.customAction), isTrue);
      for (final e in EstadoFila.values) {
        await _montar(
          tester,
          FilaHabito(titulo: 'X', estado: e),
          visibles: true,
        );
        expect(
          find.bySemanticsLabel(RegExp(e.etiqueta.toLowerCase())),
          findsWidgets,
          reason: e.name,
        );
      }
      semantica.dispose();
    });

    testWidgets(
      'FilaHabito y TarjetaSigue sensibles dicen "Contenido privado"',
      (tester) async {
        final semantica = tester.ensureSemantics();
        await _montar(
          tester,
          const Column(
            children: [
              FilaHabito(titulo: 'Cigarrillo', sensible: true),
              TarjetaSigue(
                titulo: 'Cigarrillo',
                horaTexto: '20:00',
                sensible: true,
              ),
            ],
          ),
          visibles: false,
        );
        expect(find.bySemanticsLabel(RegExp('Cigarrillo')), findsNothing);
        expect(
          find.bySemanticsLabel(RegExp('Contenido privado, pendiente')),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel('Sigue, Contenido privado, 20:00'),
          findsOneWidget,
        );
        semantica.dispose();
      },
    );

    testWidgets('FilaHabito sensible oculta el título', (tester) async {
      await _montar(
        tester,
        const FilaHabito(titulo: 'Cigarrillo', sensible: true),
        visibles: false,
      );
      expect(find.text('Cigarrillo'), findsNothing);
      expect(find.text('••••'), findsOneWidget);
    });

    testWidgets('ChipRacha: texto de gracia y Retomemos (sin "perdiste")', (
      tester,
    ) async {
      await _montar(tester, _todos()['ChipRacha']!.$1());
      expect(find.text('12 días · día de gracia'), findsOneWidget);
      expect(find.text('Retomemos'), findsOneWidget);
      expect(find.text('40 días'), findsOneWidget);
    });

    testWidgets('Calendario de constancia: símbolo y texto para el lector', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      await _montar(tester, _todos()['CalendarioConstancia']!.$1());
      expect(find.byIcon(Icons.check), findsNWidgets(2));
      expect(find.bySemanticsLabel('V (hoy): Cumplido'), findsOneWidget);
      expect(find.bySemanticsLabel('M: Día de gracia'), findsOneWidget);
      semantica.dispose();
    });

    testWidgets('TemporizadorSos cuenta atrás y pregunta al terminar', (
      tester,
    ) async {
      var siguio = 0;
      var paso = 0;
      await _montar(
        tester,
        TemporizadorSos(
          duracion: const Duration(minutes: 1),
          alSigue: () => siguio++,
          alYaPaso: () => paso++,
        ),
      );
      expect(find.text('01:00'), findsOneWidget);
      expect(find.text('Si en 1 minutos sigue, repetimos.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 30));
      expect(find.text('00:30'), findsOneWidget);
      await tester.pump(const Duration(seconds: 30));
      expect(find.text('¿Sigue el antojo?'), findsWidgets);
      await tester.tap(find.text('Sigue'));
      await tester.tap(find.text('Ya pasó'));
      expect((siguio, paso), (1, 1));
    });

    testWidgets('RespiracionGuiada: anima y alterna el texto; quieta con '
        '"reducir movimiento"', (tester) async {
      await _montar(tester, const RespiracionGuiada());
      expect(find.text('Inhala'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('Exhala'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('RespiracionGuiada sin animación', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await _montar(tester, const RespiracionGuiada(segundosPorFase: 5));
      expect(
        find.text('Inhala 5 segundos · exhala 5 segundos'),
        findsOneWidget,
      );
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('LectorBiblico: letra grande, subrayado con texto y sin '
        'animación', (tester) async {
      final semantica = tester.ensureSemantics();
      await _montar(
        tester,
        _todos()['LectorBiblico']!.$1(),
        submodulo: Submodulo.espiritual,
      );
      expect(tester.hasRunningAnimations, isFalse);
      expect(find.bySemanticsLabel('Versículo 2, subrayado'), findsOneWidget);
      expect(find.bySemanticsLabel('Versículo 1'), findsOneWidget);
      semantica.dispose();
    });

    testWidgets('Plan de lectura: atraso sin reproche', (tester) async {
      await _montar(
        tester,
        _todos()['TarjetaPlanLectura']!.$1(),
        submodulo: Submodulo.espiritual,
      );
      expect(find.text('Llevas 3 días de atraso. Sin prisa.'), findsOneWidget);
      expect(find.text('Ponerme al día'), findsOneWidget);
    });

    testWidgets('Oración y devocional ocultos: el texto personal no sale', (
      tester,
    ) async {
      await _montar(
        tester,
        Column(
          children: [
            _todos()['TarjetaDevocional']!.$1(),
            _todos()['FilaOracion']!.$1(),
          ],
        ),
        submodulo: Submodulo.espiritual,
        visibles: false,
      );
      expect(find.text('Hoy entrego lo que me preocupa.'), findsNothing);
      expect(find.textContaining('salud de la familia'), findsNothing);
      expect(find.text('Filipenses 4:6-7'), findsOneWidget);
      expect(find.textContaining('Respondida'), findsOneWidget);
    });

    testWidgets('EstadoVacioHabitos: mensajes sin culpa', (tester) async {
      for (final t in VacioHabitos.values) {
        final texto = '${t.mensaje} ${t.detalle}'.toLowerCase();
        for (final prohibido in ['perdiste', 'fallaste', 'fracaso', 'culpa']) {
          expect(texto, isNot(contains(prohibido)), reason: t.name);
        }
      }
      await _montar(tester, _todos()['EstadoVacioHabitos']!.$1());
      expect(find.text('Este dato está solo en tu teléfono'), findsOneWidget);
      expect(find.text('Cómo activar la nube cifrada'), findsOneWidget);
    });

    testWidgets('mostrarHojaInferior abre y cierra con 48 dp', (tester) async {
      await montar(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => mostrarHojaInferior<void>(
                context,
                titulo: 'Posponer',
                child: const Text('10 minutos'),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      expect(find.text('10 minutos'), findsOneWidget);
      expect(
        tester.getSize(find.byTooltip('Cerrar')).height,
        greaterThanOrEqualTo(zonaTactilMinima),
      );
      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();
      expect(find.text('10 minutos'), findsNothing);
    });
  });

  group('sin desbordes: 360 dp con letra al 200 % y 900 dp', () {
    for (final (ancho, escala) in [
      (360.0, 1.0),
      (360.0, 1.3),
      (360.0, 2.0),
      (900.0, 1.0),
    ]) {
      for (final (hora, momento) in [
        ('noche', momentoNoche),
        ('día', momentoDia),
      ]) {
        for (final nombre in _todos().keys) {
          testWidgets('$nombre · $ancho dp x$escala · $hora', (tester) async {
            fijarVentana(tester, Size(ancho, 1200));
            fijarEscalaDeLetra(tester, escala);
            final desbordes = await recolectarDesbordes(() async {
              final (construir, sub) = _todos()[nombre]!;
              await _montar(
                tester,
                construir(),
                submodulo: sub,
                ancho: ancho,
                momento: momento,
              );
              await tester.pump(const Duration(milliseconds: 300));
            });
            expect(desbordes, isEmpty);
            for (final t in find.byType(Text).evaluate()) {
              final r = tester.getRect(find.byWidget(t.widget));
              expect(r.right, lessThanOrEqualTo(ancho + 0.5), reason: nombre);
            }
            // Nada queda corriendo al salir (el temporizador y la respiración).
            await tester.pumpWidget(const SizedBox());
          });
        }
      }
    }
  });

  group('contraste del texto (4.5:1) con las tres personalidades', () {
    for (final sub in [null, Submodulo.espiritual, Submodulo.habitosEliminar]) {
      for (final (hora, momento) in [
        ('noche', momentoNoche),
        ('día', momentoDia),
      ]) {
        testWidgets('${sub?.name ?? 'habitos'} · $hora', (tester) async {
          await _montar(
            tester,
            const ChipRacha(dias: 1),
            submodulo: sub,
            momento: momento,
          );
          final v = valoresDe(tester, find.byType(ChipRacha));
          for (final c in [v.texto, v.textoFuerte, v.textoTenue]) {
            expect(
              razonContraste(c, v.panel),
              greaterThanOrEqualTo(contrasteMinimoTexto),
            );
          }
          // El texto del chip sobre su relleno mezclado.
          final fondo = Color.alphaBlend(
            v.acento.withValues(alpha: 0.10),
            v.panel,
          );
          expect(
            razonContraste(v.textoFuerte, fondo),
            greaterThanOrEqualTo(contrasteMinimoTexto),
          );
          // Los estados del semáforo del refresco y de la carga con su texto.
          for (final e in EstadoRefresco.values) {
            expect(
              razonContraste(v.textoFuerte, v.panel),
              greaterThanOrEqualTo(contrasteMinimoTexto),
              reason: e.texto,
            );
          }
        });
      }
    }
  });
}
