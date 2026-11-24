// Mantenimiento (B7), seguridad y contacto (B8), rutas guardadas (B6) y
// enlaces externos: «sin registro» no es «vencida», el contacto solo vive en
// el teléfono, nadie vigila la salida, nada se envía solo y los enlaces que
// no abren se dicen sin romper nada.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/diseno/diseno.dart';

import '../ayuda_pruebas.dart' show recolectarDesbordes;
import 'ayuda_bici.dart';

const _tareas = [
  TareaMantenimientoVista(
    id: 'lubricar_cadena',
    nombre: 'Lubricar la cadena',
    estado: EstadoTarea.alDia,
    intervaloTexto: 'Cada 150 km o 4 semanas',
    ultimaVezTexto: 'Hecha a los 350 km',
    faltaTexto: 'Faltan 30 km',
  ),
  TareaMantenimientoVista(
    id: 'revisar_frenos_llantas',
    nombre: 'Revisar frenos y llantas',
    estado: EstadoTarea.toca,
    intervaloTexto: 'Cada 300 km o 8 semanas',
    ultimaVezTexto: 'Hecha el 28 sep',
    faltaTexto: 'Ya pasaron 8 semanas',
  ),
  TareaMantenimientoVista(
    id: 'limpiar_transmision',
    nombre: 'Limpiar la transmisión',
    estado: EstadoTarea.sinRegistro,
    intervaloTexto: 'Cada 400 km o 12 semanas',
  ),
];

const _consejos = [
  ConsejoSeguridadVista(
    titulo: 'En calle',
    texto: 'En calle, usa casco, luces y ropa visible, y respeta las señales.',
    icono: Icons.traffic_outlined,
  ),
  ConsejoSeguridadVista(
    titulo: 'Si te sientes mal',
    texto: TextosBici.siTeSientesMal,
    icono: Icons.health_and_safety_outlined,
  ),
];

void main() {
  group('TarjetaMantenimiento', () {
    testWidgets('el odómetro se calcula y se dice; los intervalos son '
        'borrador y piden confirmarse', (tester) async {
      await montarBici(
        tester,
        const TarjetaMantenimiento(
          bicicletaTexto: 'MI BICI',
          odometroTexto: '470 km',
          tareas: _tareas,
        ),
      );
      expect(
        find.byKey(const ValueKey('mantenimiento-odometro')),
        findsOneWidget,
      );
      expect(find.text('470 km'), findsOneWidget);
      expect(find.text(TextosBici.odometroCalculado), findsOneWidget);
      expect(find.text(TextosBici.borrador), findsOneWidget);
      expect(find.text(TextosBici.confirmaIntervalos), findsOneWidget);
    });

    testWidgets('«sin registro» y «toca» llevan icono y palabras; nunca '
        '«vencida»', (tester) async {
      await montarBici(
        tester,
        const TarjetaMantenimiento(
          bicicletaTexto: 'MI BICI',
          odometroTexto: '470 km',
          tareas: _tareas,
        ),
      );
      for (final e in [
        EstadoTarea.alDia,
        EstadoTarea.toca,
        EstadoTarea.sinRegistro,
      ]) {
        expect(find.text(e.texto), findsOneWidget, reason: '$e');
        expect(find.byIcon(e.icono), findsWidgets, reason: '$e');
      }
      final todo = textosVisibles(tester).join(' ').toLowerCase();
      expect(todo.contains('vencid'), isFalse);
      expect(todo.contains('atrasad'), isFalse);
      expect(find.text(TextosBici.sinRegistroNota), findsOneWidget);
    });

    testWidgets('*Hecho* entrega el id de la tarea y mide 48 dp', (
      tester,
    ) async {
      final hechas = <String>[];
      await montarBici(
        tester,
        TarjetaMantenimiento(
          bicicletaTexto: 'MI BICI',
          odometroTexto: '470 km',
          tareas: _tareas,
          alHecho: hechas.add,
          alAnotarLectura: () {},
          alCambiarIntervalos: () {},
        ),
      );
      final boton = find.widgetWithText(
        OutlinedButton,
        'Hecho: Revisar frenos y llantas',
      );
      expect(tester.getSize(boton).height, greaterThanOrEqualTo(48));
      await tester.tap(boton);
      expect(hechas, ['revisar_frenos_llantas']);
      expect(find.text(TextosBici.registrarLectura), findsOneWidget);
    });

    testWidgets('cada tarea se lee completa: nombre, estado, intervalo y '
        'avance', (tester) async {
      final handle = tester.ensureSemantics();
      await montarBici(
        tester,
        const TarjetaMantenimiento(
          bicicletaTexto: 'MI BICI',
          odometroTexto: '470 km',
          tareas: _tareas,
        ),
      );
      final etiquetas = etiquetasAccesibles(tester);
      expect(
        etiquetas,
        contains(
          'Lubricar la cadena, al día, Cada 150 km o 4 semanas, Hecha a los '
          '350 km, Faltan 30 km',
        ),
      );
      expect(
        etiquetas.any(
          (e) => e.startsWith('Limpiar la transmisión, sin registro'),
        ),
        isTrue,
      );
      handle.dispose();
    });

    testWidgets('estados: vacío, cargando, sin conexión y error', (
      tester,
    ) async {
      for (final estado in estadosSinContenido) {
        await montarBici(
          tester,
          TarjetaMantenimiento(
            bicicletaTexto: 'MI BICI',
            odometroTexto: '470 km',
            tareas: const [],
            estado: estado,
            alReintentar: () {},
          ),
        );
        expect(find.byType(CuerpoEstadoBici), findsOneWidget);
      }
      // Sin tareas y en «listo» muestra el estado vacío dentro de la tarjeta.
      await montarBici(
        tester,
        const TarjetaMantenimiento(
          bicicletaTexto: 'MI BICI',
          odometroTexto: '0 km',
          tareas: [],
        ),
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
            TarjetaMantenimiento(
              bicicletaTexto: 'MI BICI CON UN NOMBRE MUY LARGO',
              odometroTexto: '12 470 km',
              tareas: _tareas,
              alHecho: (_) {},
              alAnotarLectura: () {},
              alCambiarIntervalos: () {},
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

  group('TarjetaSeguridad', () {
    testWidgets('dice con palabras que nadie vigila la salida y la guía '
        'fija', (tester) async {
      await montarBici(
        tester,
        const TarjetaSeguridad(consejos: _consejos, contactoTexto: 'Ana'),
      );
      expect(find.text(TextosBici.nadieVigila), findsOneWidget);
      expect(find.text(TextosBici.guiaNoSustituye), findsOneWidget);
      expect(find.text(TextosBici.siTeSientesMal), findsOneWidget);
    });

    testWidgets('Llamar es un toque, Avisar abre mensajes; ambos de 64 dp y '
        'la tarjeta dice que tú tocas Enviar', (tester) async {
      var llamar = 0;
      var avisar = 0;
      await montarBici(
        tester,
        TarjetaSeguridad(
          consejos: _consejos,
          contactoTexto: 'Ana (ejemplo)',
          mensajeRegresoTexto: 'Salgo a las 8:00 y regreso hacia las 12:00.',
          alLlamar: () => llamar++,
          alAvisarRegreso: () => avisar++,
        ),
        sport: true,
      );
      final bLlamar = find.byKey(const ValueKey('seguridad-llamar'));
      final bAvisar = find.byKey(const ValueKey('seguridad-avisar'));
      expect(tester.getSize(bLlamar).height, greaterThanOrEqualTo(64));
      expect(tester.getSize(bAvisar).height, greaterThanOrEqualTo(64));
      expect(find.text(TextosBici.nadaSeEnviaSolo), findsOneWidget);
      expect(find.text(TextosBici.soloEnEsteEquipo), findsOneWidget);
      await tester.tap(bLlamar);
      expect(llamar, 1);
      expect(avisar, 0);
      await tester.tap(bAvisar);
      expect(avisar, 1);
    });

    testWidgets('en la laptop no muestra el contacto ni los botones y dice '
        'que está solo en el teléfono', (tester) async {
      await montarBici(
        tester,
        const TarjetaSeguridad(
          consejos: _consejos,
          contactoTexto: 'Ana (ejemplo)',
          contactoEnEsteEquipo: false,
        ),
      );
      expect(find.text(TextosBici.rutasSoloEnTelefono), findsOneWidget);
      expect(find.text('Ana (ejemplo)'), findsNothing);
      expect(find.text(TextosBici.llamarAMiContacto), findsNothing);
      expect(find.text(TextosBici.avisarMiHoraDeRegreso), findsNothing);
    });

    testWidgets('sin contacto invita a agregarlo', (tester) async {
      var agregar = 0;
      await montarBici(
        tester,
        TarjetaSeguridad(
          consejos: _consejos,
          alAgregarContacto: () => agregar++,
        ),
      );
      expect(find.text(TextosBici.llamarAMiContacto), findsNothing);
      await tester.tap(find.text(TextosBici.agregarContacto));
      expect(agregar, 1);
    });

    testWidgets('no nombra síntomas ni da cifras de comida o líquidos', (
      tester,
    ) async {
      await montarBici(
        tester,
        const TarjetaSeguridad(consejos: _consejos, contactoTexto: 'Ana'),
      );
      final todo = textosVisibles(tester).join(' ');
      expect(patronSintomas.hasMatch(todo), isFalse);
      expect(patronMedico.hasMatch(todo), isFalse);
    });

    testWidgets('estados: vacío, cargando, sin conexión y error', (
      tester,
    ) async {
      for (final estado in estadosSinContenido) {
        await montarBici(
          tester,
          TarjetaSeguridad(
            consejos: const [],
            estado: estado,
            alReintentar: () {},
          ),
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
            TarjetaSeguridad(
              consejos: _consejos,
              contactoTexto: 'Ana (ejemplo)',
              mensajeRegresoTexto:
                  'Salgo a las 8:00 y regreso hacia las 12:00.',
              alLlamar: () {},
              alAvisarRegreso: () {},
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

  group('ListaRutas', () {
    const rutas = [
      RutaVista(
        id: 'r1',
        nombre: 'Vuelta al cerro (ejemplo)',
        distanciaTexto: '42,0 km',
        desnivelTexto: '+ 310 m',
        superficie: SuperficieSalida.mixta,
        tramosTexto: '24 km de calle, 18 km de terreno',
      ),
      RutaVista(id: 'r2', nombre: 'Ciclovía (ejemplo)'),
    ];

    testWidgets('dice que viven solo en este equipo y deja elegir con 48 dp', (
      tester,
    ) async {
      final elegidas = <String>[];
      var nueva = 0;
      await montarBici(
        tester,
        ListaRutas(
          rutas: rutas,
          alElegir: elegidas.add,
          alNueva: () => nueva++,
        ),
      );
      expect(find.text(TextosBici.soloEnEsteEquipo), findsOneWidget);
      final fila = find.ancestor(
        of: find.text('Vuelta al cerro (ejemplo)'),
        matching: find.byType(InkWell),
      );
      expect(tester.getSize(fila.first).height, greaterThanOrEqualTo(48));
      await tester.tap(find.text('Vuelta al cerro (ejemplo)'));
      expect(elegidas, ['r1']);
      await tester.tap(find.text('Nueva ruta'));
      expect(nueva, 1);
    });

    testWidgets('en la laptop no muestra ninguna ruta', (tester) async {
      await montarBici(
        tester,
        const ListaRutas(rutas: rutas, enEsteEquipo: false),
      );
      expect(find.text(TextosBici.rutasSoloEnTelefono), findsOneWidget);
      expect(find.text('Vuelta al cerro (ejemplo)'), findsNothing);
    });

    testWidgets('estados: vacío con una acción, cargando, sin conexión y '
        'error', (tester) async {
      var nueva = 0;
      for (final estado in estadosSinContenido) {
        await montarBici(
          tester,
          ListaRutas(
            rutas: const [],
            estado: estado,
            alNueva: () => nueva++,
            alReintentar: () {},
          ),
        );
        expect(find.byType(CuerpoEstadoBici), findsOneWidget);
        if (estado == EstadoVistaBici.vacio) {
          await tester.tap(find.text('Nueva ruta'));
        }
      }
      expect(nueva, 1);
      await desmontar(tester);
    });

    for (final ancho in [360.0, 900.0]) {
      testWidgets('letra al 200 % en ${ancho.toInt()} dp sin desbordes', (
        tester,
      ) async {
        final desbordes = await recolectarDesbordes(() async {
          await montarBici(
            tester,
            ListaRutas(rutas: rutas, alElegir: (_) {}, alNueva: () {}),
            ancho: ancho,
            letra: 2.0,
          );
        });
        expect(desbordes, isEmpty);
      });
    }
  });

  group('ListaEnlaces', () {
    testWidgets('abre solo con un toque y cada botón mide 48 dp o más', (
      tester,
    ) async {
      var musica = 0;
      await montarBici(
        tester,
        ListaEnlaces(
          enlaces: [
            EnlaceVista(
              tipo: TipoEnlace.musica,
              texto: TextosBici.abrirMiLista,
              alAbrir: () => musica++,
            ),
            EnlaceVista(
              tipo: TipoEnlace.clima,
              texto: TextosBici.verElClima,
              alAbrir: () {},
            ),
          ],
        ),
      );
      expect(musica, 0, reason: 'nada se abre solo');
      final boton = find.widgetWithText(
        OutlinedButton,
        TextosBici.abrirMiLista,
      );
      expect(tester.getSize(boton).height, greaterThanOrEqualTo(48));
      await tester.tap(boton);
      expect(musica, 1);
      expect(find.text(TextosBici.seAbreEnOtraApp), findsOneWidget);
    });

    testWidgets('si la app no está dice «No se pudo abrir» con icono y no '
        'rompe nada', (tester) async {
      await montarBici(
        tester,
        ListaEnlaces(
          enlaces: [
            EnlaceVista(
              tipo: TipoEnlace.mapa,
              texto: TextosBici.abrirMiRuta,
              noSePudoAbrir: true,
              alAbrir: () {},
            ),
          ],
        ),
      );
      expect(find.text('Mapa: ${TextosBici.noSePudoAbrir}'), findsOneWidget);
      expect(find.byIcon(Icons.link_off), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('un enlace sin guardar se ve apagado y lo dice con palabras', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await montarBici(
        tester,
        ListaEnlaces(
          enlaces: [
            EnlaceVista(
              tipo: TipoEnlace.mapa,
              texto: TextosBici.abrirMiRuta,
              guardado: false,
              alAbrir: () {},
            ),
          ],
        ),
      );
      expect(
        find.text('${TextosBici.abrirMiRuta} (sin enlace)'),
        findsOneWidget,
      );
      final boton = find.widgetWithText(
        OutlinedButton,
        '${TextosBici.abrirMiRuta} (sin enlace)',
      );
      expect(tester.widget<OutlinedButton>(boton).onPressed, isNull);
      expect(
        etiquetasAccesibles(tester)
            .any((e) => e.contains('sin enlace guardado')),
        isTrue,
      );
      handle.dispose();
    });

    testWidgets('estados: vacío, cargando, sin conexión y error', (
      tester,
    ) async {
      for (final estado in estadosSinContenido) {
        await montarBici(
          tester,
          ListaEnlaces(enlaces: const [], estado: estado, alReintentar: () {}),
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
            ListaEnlaces(
              enlaces: [
                EnlaceVista(
                  tipo: TipoEnlace.musica,
                  texto: TextosBici.abrirMiLista,
                  nombreTexto: 'Rodadas de sábado',
                  alAbrir: () {},
                ),
                EnlaceVista(
                  tipo: TipoEnlace.clima,
                  texto: TextosBici.verElClima,
                  noSePudoAbrir: true,
                  alAbrir: () {},
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
