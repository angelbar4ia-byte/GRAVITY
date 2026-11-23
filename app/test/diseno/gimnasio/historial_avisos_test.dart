// Barras de historial y récords (E7 y E8, 6.2 y 6.3), «Contenido en revisión»
// (PG-25) y avisos de molestia sin diagnosticar (CA-G-03, CA-G-22 y 5.10).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/diseno/diseno.dart';

import '../ayuda_pruebas.dart' show recolectarDesbordes;
import 'ayuda_gimnasio.dart';

const _barras = [
  BarraHistorialVista(
    etiqueta: 'Semana del 9 nov',
    valor: 3,
    valorTexto: 'Placa 3',
  ),
  BarraHistorialVista(
    etiqueta: 'Semana del 16 nov',
    valor: 5,
    valorTexto: 'Placa 5',
    esRecord: true,
  ),
  BarraHistorialVista(
    etiqueta: 'Semana del 23 nov',
    valor: 4,
    valorTexto: 'Placa 4',
    tipoSemana: TipoSemanaVista.descarga,
  ),
];

const _records = [
  RecordVista(
    ejercicio: 'Press de pecho',
    varianteTexto: 'En la estación',
    tipo: TipoRecordVista.mejorCarga,
    valorTexto: 'Placa 6',
    fechaTexto: '23 nov',
    reciente: true,
  ),
  RecordVista(
    ejercicio: 'Plancha',
    tipo: TipoRecordVista.mejorTiempo,
    valorTexto: '45 s',
  ),
];

void main() {
  group('BarrasHistorial', () {
    testWidgets('una fila por registro, con valor en texto y texto alternativo '
        'de toda la gráfica', (tester) async {
      final handle = tester.ensureSemantics();
      await montarGim(
        tester,
        const BarrasHistorial(titulo: 'Press de pecho', barras: _barras),
      );
      expect(find.text('Placa 3'), findsOneWidget);
      expect(find.text('Placa 5'), findsOneWidget);
      expect(
        etiquetasAccesibles(tester).any(
          (e) =>
              e.startsWith('Press de pecho. 3 registros.') &&
              e.contains('Semana del 16 nov, Placa 5, récord') &&
              e.contains('Semana del 23 nov, Placa 4, semana de descarga'),
        ),
        isTrue,
      );
      handle.dispose();
    });

    testWidgets('la descarga y el récord llevan icono y palabra: una caída no '
        'se lee como retroceso', (tester) async {
      await montarGim(
        tester,
        const BarrasHistorial(titulo: 'Press de pecho', barras: _barras),
      );
      expect(find.text('Descarga'), findsOneWidget);
      expect(find.byIcon(TipoSemanaVista.descarga.icono), findsOneWidget);
      expect(find.text('Récord'), findsOneWidget);
      expect(find.byIcon(Icons.emoji_events_outlined), findsWidgets);
    });

    testWidgets('el texto alternativo se puede reemplazar', (tester) async {
      final handle = tester.ensureSemantics();
      await montarGim(
        tester,
        const BarrasHistorial(
          titulo: 'Press de pecho',
          barras: _barras,
          resumenAccesible: 'Subiste de la placa 3 a la 5.',
        ),
      );
      expect(
        etiquetasAccesibles(tester),
        contains('Subiste de la placa 3 a la 5.'),
      );
      handle.dispose();
    });

    testWidgets('con todo en cero no falla y el valor sigue visible', (
      tester,
    ) async {
      await montarGim(
        tester,
        const BarrasHistorial(
          titulo: 'Plancha',
          barras: [
            BarraHistorialVista(
              etiqueta: 'Semana',
              valor: 0,
              valorTexto: '0 s',
            ),
          ],
        ),
      );
      expect(find.text('0 s'), findsOneWidget);
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
          BarrasHistorial(
            titulo: 'Press de pecho',
            barras: const [],
            estado: estado,
            alReintentar: () => reintentos++,
          ),
        );
        expect(find.byType(CuerpoEstadoGimnasio), findsOneWidget);
      }
      await tester.tap(find.text(TextosGimnasio.reintentar));
      expect(reintentos, 1);
      // Sin barras en estado listo se ve el vacío.
      await montarGim(
        tester,
        const BarrasHistorial(titulo: 'Press de pecho', barras: []),
      );
      expect(
        find.text('Todavía no hay sesiones de este ejercicio.'),
        findsOneWidget,
      );
      await desmontar(tester);
    });

    for (final ancho in [360.0, 900.0]) {
      testWidgets('letra al 200 % en ${ancho.toInt()} dp sin desbordes', (
        tester,
      ) async {
        final desbordes = await recolectarDesbordes(() async {
          await montarGim(
            tester,
            Column(
              children: [
                const BarrasHistorial(
                  titulo: 'Press de pecho',
                  subtitulo: 'Carga por semana',
                  barras: _barras,
                ),
                ListaSesionesHistorial(
                  sesiones: const [
                    SesionHistorialVista(
                      fechaTexto: 'lun 23 nov',
                      plantillaTexto: 'Fuerza A · estándar',
                      resumenTexto: '9 de 12 series · 38 min',
                      tipoSemana: TipoSemanaVista.reentrada,
                      esfuerzoTexto: 'Esfuerzo 3 de 5',
                    ),
                  ],
                  alTocarSesion: (_) {},
                ),
                ListaRecords(records: _records, alTocarRecord: (_) {}),
              ],
            ),
            ancho: ancho,
            letra: 2.0,
          );
        });
        expect(desbordes, isEmpty);
      });
    }
  });

  group('ListaRecords y ListaSesionesHistorial', () {
    testWidgets('el récord reciente dice «Nuevo récord» y todo se lee con su '
        'tipo', (tester) async {
      final handle = tester.ensureSemantics();
      await montarGim(
        tester,
        ListaRecords(records: _records, alTocarRecord: (_) {}),
      );
      expect(find.text(TextosGimnasio.nuevoRecord), findsOneWidget);
      expect(find.text('Placa 6'), findsOneWidget);
      expect(
        etiquetasAccesibles(tester),
        contains(
          'Press de pecho, En la estación, Mejor carga, Placa 6, 23 nov, nuevo récord',
        ),
      );
      expect(
        etiquetasAccesibles(tester),
        contains('Plancha, Mejor tiempo, 45 s'),
      );
      handle.dispose();
    });

    testWidgets('las filas tocables miden 56 dp o más', (tester) async {
      final tocados = <int>[];
      await montarGim(
        tester,
        ListaRecords(records: _records, alTocarRecord: tocados.add),
      );
      for (final e in find.byType(InkWell).evaluate()) {
        expect(
          tester.getSize(find.byWidget(e.widget)).height,
          greaterThanOrEqualTo(56),
        );
      }
      await tester.tap(find.text('Plancha'));
      expect(tocados, [1]);
    });

    testWidgets('estados de récords y de sesiones', (tester) async {
      for (final estado in [
        EstadoVistaGimnasio.vacio,
        EstadoVistaGimnasio.cargando,
        EstadoVistaGimnasio.sinConexion,
        EstadoVistaGimnasio.error,
      ]) {
        await montarGim(
          tester,
          Column(
            children: [
              ListaRecords(
                records: const [],
                estado: estado,
                alReintentar: () {},
              ),
              ListaSesionesHistorial(
                sesiones: const [],
                estado: estado,
                alReintentar: () {},
              ),
            ],
          ),
        );
        expect(find.byType(CuerpoEstadoGimnasio), findsNWidgets(2));
      }
      await desmontar(tester);
    });

    testWidgets('la sesión de descarga lleva la marca con icono y palabra', (
      tester,
    ) async {
      await montarGim(
        tester,
        const ListaSesionesHistorial(
          sesiones: [
            SesionHistorialVista(
              fechaTexto: 'lun 30 nov',
              plantillaTexto: 'Fuerza A · corta',
              resumenTexto: '8 de 8 series · 27 min',
              tipoSemana: TipoSemanaVista.descarga,
            ),
          ],
        ),
      );
      expect(find.text('Descarga'), findsOneWidget);
    });
  });

  group('TarjetaContenidoEnRevision', () {
    testWidgets('completa dice «Contenido en revisión» y que no sustituye a un '
        'profesional', (tester) async {
      await montarGim(tester, const TarjetaContenidoEnRevision());
      expect(find.text('Contenido en revisión'), findsOneWidget);
      expect(find.textContaining('profesional'), findsOneWidget);
    });

    testWidgets('compacta es una sola línea', (tester) async {
      await montarGim(tester, const TarjetaContenidoEnRevision(compacta: true));
      expect(find.text('Contenido en revisión'), findsOneWidget);
      expect(find.textContaining('profesional'), findsNothing);
    });

    testWidgets('con acción se toca, mide 48 dp y se lee como botón', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var abre = 0;
      await montarGim(
        tester,
        TarjetaContenidoEnRevision(compacta: true, alAbrir: () => abre++),
      );
      final zona = find.byType(InkWell);
      expect(tester.getSize(zona).height, greaterThanOrEqualTo(48));
      await tester.tap(zona);
      expect(abre, 1);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Contenido en revisión')),
        isNotNull,
      );
      handle.dispose();
    });

    testWidgets('estados: todo revisado, cargando, sin conexión y error', (
      tester,
    ) async {
      for (final estado in [
        EstadoVistaGimnasio.vacio,
        EstadoVistaGimnasio.cargando,
        EstadoVistaGimnasio.sinConexion,
        EstadoVistaGimnasio.error,
      ]) {
        await montarGim(
          tester,
          TarjetaContenidoEnRevision(estado: estado, alReintentar: () {}),
        );
        expect(find.byType(CuerpoEstadoGimnasio), findsOneWidget);
      }
      await desmontar(tester);
    });
  });

  group('AvisoMolestia (sin diagnosticar)', () {
    testWidgets('cada intensidad nombra a un profesional, un médico o un '
        'entrenador y ningún texto diagnostica', (tester) async {
      for (final nivel in NivelMolestia.values) {
        await montarGim(
          tester,
          AvisoMolestia(zonaTexto: 'Hombro', nivel: nivel),
        );
        final textos = textosVisibles(tester).join('\n');
        expect(
          RegExp('profesional|médico|entrenador').hasMatch(textos),
          isTrue,
          reason: '$nivel',
        );
        expect(patronMedico.hasMatch(textos), isFalse, reason: '$nivel');
        expect(textos.contains('!'), isFalse, reason: '$nivel');
        expect(find.text(nivel.texto), findsOneWidget);
        expect(
          find.text(TextosGimnasio.molestiaSoloEnEsteEquipo),
          findsOneWidget,
        );
      }
    });

    testWidgets('la fuerte manda a un médico o a un entrenador y propone la '
        'regenerativa', (tester) async {
      var regenerativa = 0;
      await montarGim(
        tester,
        AvisoMolestia(
          zonaTexto: 'Hombro',
          nivel: NivelMolestia.fuerte,
          alProponerRegenerativa: () => regenerativa++,
        ),
      );
      expect(find.text(TextosGimnasio.molestiaFuerte), findsOneWidget);
      expect(find.textContaining('médico'), findsOneWidget);
      expect(find.textContaining('entrenador'), findsOneWidget);
      expect(
        find.text(TextosGimnasio.molestiaProponerRegenerativa),
        findsOneWidget,
      );
      final boton = find.widgetWithText(
        FilledButton,
        'Ver la sesión regenerativa',
      );
      expect(tester.getSize(boton).height, greaterThanOrEqualTo(48));
      await tester.tap(boton);
      expect(regenerativa, 1);
    });

    testWidgets('la leve y la moderada no proponen la regenerativa', (
      tester,
    ) async {
      for (final nivel in [NivelMolestia.leve, NivelMolestia.moderada]) {
        await montarGim(
          tester,
          AvisoMolestia(zonaTexto: 'Rodilla', nivel: nivel),
        );
        expect(
          find.text(TextosGimnasio.molestiaProponerRegenerativa),
          findsNothing,
        );
      }
    });

    testWidgets('«¿Sigue esta molestia?» con Sigue y Ya no de 48 dp', (
      tester,
    ) async {
      var sigue = 0;
      var yaNo = 0;
      await montarGim(
        tester,
        AvisoMolestia(
          zonaTexto: 'Codo',
          nivel: NivelMolestia.leve,
          alSigue: () => sigue++,
          alYaNo: () => yaNo++,
        ),
      );
      expect(find.text(TextosGimnasio.molestiaPreguntaSigue), findsOneWidget);
      for (final t in [
        TextosGimnasio.molestiaSigue,
        TextosGimnasio.molestiaYaNo,
      ]) {
        final b = find.widgetWithText(OutlinedButton, t);
        expect(tester.getSize(b).height, greaterThanOrEqualTo(48));
        await tester.tap(b);
      }
      expect((sigue, yaNo), (1, 1));
    });

    testWidgets('la intensidad no depende solo del color: icono y palabra', (
      tester,
    ) async {
      await montarGim(
        tester,
        const Column(
          children: [
            AvisoMolestia(zonaTexto: 'Hombro', nivel: NivelMolestia.leve),
            AvisoMolestia(zonaTexto: 'Hombro', nivel: NivelMolestia.fuerte),
          ],
        ),
      );
      expect(find.text('Leve'), findsOneWidget);
      expect(find.text('Fuerte'), findsOneWidget);
      expect(find.byIcon(Icons.looks_one_outlined), findsOneWidget);
      expect(find.byIcon(Icons.looks_3_outlined), findsOneWidget);
    });

    testWidgets(
      'estados: vacío con una acción, cargando, sin conexión y error',
      (tester) async {
        var agregar = 0;
        for (final estado in [
          EstadoVistaGimnasio.vacio,
          EstadoVistaGimnasio.cargando,
          EstadoVistaGimnasio.sinConexion,
          EstadoVistaGimnasio.error,
        ]) {
          await montarGim(
            tester,
            AvisoMolestia(
              zonaTexto: 'Hombro',
              nivel: NivelMolestia.leve,
              estado: estado,
              alAccionVacia: () => agregar++,
              alReintentar: () {},
            ),
          );
          expect(find.byType(CuerpoEstadoGimnasio), findsOneWidget);
          final textos = textosVisibles(tester).join('\n');
          expect(patronMedico.hasMatch(textos), isFalse);
        }
        await montarGim(
          tester,
          AvisoMolestia(
            zonaTexto: 'Hombro',
            nivel: NivelMolestia.leve,
            estado: EstadoVistaGimnasio.vacio,
            alAccionVacia: () => agregar++,
          ),
        );
        await tester.tap(find.text('Agregar una molestia'));
        expect(agregar, 1);
        await desmontar(tester);
      },
    );

    testWidgets(
      'FilaMolestia dice zona, intensidad y estado, y se toca a 56 dp',
      (tester) async {
        final handle = tester.ensureSemantics();
        var toques = 0;
        await montarGim(
          tester,
          FilaMolestia(
            zonaTexto: 'Hombro',
            nivel: NivelMolestia.moderada,
            desdeTexto: 'desde el 20 nov',
            alTocar: () => toques++,
          ),
        );
        expect(find.text('Moderada'), findsOneWidget);
        expect(
          tester.getSize(find.byType(InkWell)).height,
          greaterThanOrEqualTo(56),
        );
        expect(
          etiquetasAccesibles(tester),
          contains('Hombro, moderada, activa, desde el 20 nov'),
        );
        await tester.tap(find.byType(InkWell));
        expect(toques, 1);
        handle.dispose();
      },
    );

    for (final ancho in [360.0, 900.0]) {
      testWidgets('letra al 200 % en ${ancho.toInt()} dp sin desbordes', (
        tester,
      ) async {
        final desbordes = await recolectarDesbordes(() async {
          await montarGim(
            tester,
            Column(
              children: [
                AvisoMolestia(
                  zonaTexto: 'Hombro',
                  nivel: NivelMolestia.fuerte,
                  alProponerRegenerativa: () {},
                  alSigue: () {},
                  alYaNo: () {},
                ),
                const TarjetaContenidoEnRevision(),
                FilaMolestia(
                  zonaTexto: 'Espalda baja',
                  nivel: NivelMolestia.moderada,
                  desdeTexto: 'desde el 20 nov',
                  alTocar: () {},
                ),
              ],
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
