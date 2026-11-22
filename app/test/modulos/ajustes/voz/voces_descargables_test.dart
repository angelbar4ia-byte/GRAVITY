// Ajustes › Voz › Voces descargables (motor de voz, P3.2a-2): criterios 17 y 18
// y los mensajes de 5.5, con el gestor, la red, la síntesis y el reproductor
// simulados. No hay plugin, ni sonido, ni red.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/router.dart' show routerProvider;
import 'package:gravity/modulos/ajustes/voz/pantalla_voz.dart';
import 'package:gravity/modulos/ajustes/voz/voces_descargables.dart';
import 'package:gravity/modulos/gravity/voz/audio/reproductor_de_audio.dart';
import 'package:gravity/modulos/gravity/voz/descarga/gestor_falso.dart';
import 'package:gravity/modulos/gravity/voz/fuente_de_voz.dart';
import 'package:gravity/modulos/gravity/voz/fuente_falsa.dart';
import 'package:gravity/modulos/ajustes/voz/prueba_voz.dart'
    show dialogoDePrueba;
import 'package:gravity/modulos/gravity/voz/fuentes/modelo/frases.dart';
import 'package:gravity/modulos/gravity/voz/fuentes/modelo/fuente_modelo.dart';
import 'package:gravity/modulos/gravity/voz/fuentes/modelo/puerta_sintesis.dart';
import 'package:gravity/modulos/gravity/voz/modelos/catalogo.dart';
import 'package:gravity/modulos/gravity/voz/modelos/estado_modelo.dart';
import 'package:gravity/modulos/gravity/voz/proveedores.dart';
import 'package:gravity/modulos/gravity/voz/tipos.dart';
import 'package:gravity/nucleo/conectividad/tipo_de_red.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/contratos/rutas.dart';

import '../../../app/ayuda_plataforma.dart';
import '../../../diseno/ayuda_pruebas.dart'
    show fijarEscalaDeLetra, recolectarDesbordes;
import '../../gravity/voz/ayuda_modelos.dart';

Finder k(String clave) => find.byKey(ValueKey(clave));

String textoDe(WidgetTester tester, String clave) =>
    tester.widget<Text>(k(clave)).data!;

Future<void> asentar(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump();
  }
}

class Escenario {
  Escenario() {
    final c = ContenidoDePrueba();
    catalogo = c.catalogo();
    gestor = GestorDeModelosFalso(catalogo.modelos);
    red = FuenteTipoDeRedFalsa(TipoDeRed.wifi);
    puerta = PuertaSintesisFalsa();
    reproductor = ReproductorDeAudioFalso(duracion: Duration.zero);
    disco = SistemaDeArchivosEnMemoria();
  }

  late final CatalogoDeVoces catalogo;
  late final GestorDeModelosFalso gestor;
  late final FuenteTipoDeRedFalsa red;
  late final PuertaSintesisFalsa puerta;
  late final ReproductorDeAudioFalso reproductor;
  late final SistemaDeArchivosEnMemoria disco;

  FuenteModelo fuenteB() => FuenteModelo(
    gestor: gestor,
    puerta: puerta,
    crearReproductor: () => reproductor,
    carpetaTemporal: () async => '/tmp/gravity-voz',
    archivos: disco,
  );
}

Future<void> abrir(
  WidgetTester tester,
  Escenario e, {
  List<FuenteDeVoz>? fuentes,
  bool conGestor = true,
  Rol rol = Rol.dueno,
  TipoDispositivo dispositivo = TipoDispositivo.laptop,
  Size? ventana,
}) async {
  final List<Override> extras = [
    fuentesDeVozProvider.overrideWithValue(fuentes ?? [FuenteDeVozFalsa()]),
    fuenteTipoDeRedProvider.overrideWithValue(e.red),
    if (conGestor) gestorDeModelosProvider.overrideWithValue(e.gestor),
  ];
  await montarApp(
    tester,
    dispositivo: dispositivo,
    sesion: sesionCon(rol),
    extras: extras,
  );
  tester.view.physicalSize = ventana ?? const Size(1280, 6000);
  tester.view.devicePixelRatio = 1;
  final c = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
  c.read(routerProvider).go('${Rutas.ajustes}/voz');
  await tester.pumpAndSettle();
}

ProviderContainer contenedor(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(PantallaVoz)));

void main() {
  group('criterio 17: lo que muestra y que no abre ninguna conexión', () {
    testWidgets('cada voz muestra nombre, voz, tamaño total, licencia y estado', (
      tester,
    ) async {
      final e = Escenario();
      await abrir(tester, e);
      expect(k('voces-descargables'), findsOneWidget);
      expect(find.text('Voces descargables'), findsOneWidget);
      for (final id in ['ana', 'beto', 'cori']) {
        expect(k('modelo-$id'), findsOneWidget);
        expect(
          textoDe(tester, 'modelo-$id-tamano'),
          'Pesa ${formatearBytes(e.catalogo.porId(id)!.bytes)} · necesitas Wi-Fi',
        );
        expect(textoDe(tester, 'modelo-$id-estado'), 'No descargada');
        expect(
          textoDe(tester, 'modelo-$id-licencia'),
          'Licencia: dominio público (según su autor)',
        );
        expect(k('modelo-$id-descargar'), findsOneWidget);
      }
      expect(find.text('Voz Ana'), findsOneWidget);
      expect(
        find.textContaining('Voz: Ana · inglés americano · mujer'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Voz: Beto · inglés americano · hombre'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Voz: Cori · inglés británico · mujer · acento aproximado',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Descargar (${formatearBytes(e.catalogo.porId('ana')!.bytes)})',
        ),
        findsWidgets,
      );
    });

    testWidgets(
      'el aviso dice que hace falta Wi-Fi y que el sitio verá la dirección de internet',
      (tester) async {
        final e = Escenario();
        await abrir(tester, e);
        expect(find.textContaining('solo con Wi-Fi'), findsOneWidget);
        expect(
          find.textContaining('solo cuando tú tocas Descargar'),
          findsOneWidget,
        );
        expect(
          find.textContaining('la dirección de internet de este equipo'),
          findsOneWidget,
        );
        expect(find.textContaining('no se envía nada tuyo'), findsOneWidget);
      },
    );

    testWidgets('mostrar la pantalla no pide ninguna descarga', (tester) async {
      final e = Escenario();
      await abrir(tester, e);
      await tester.pumpAndSettle();
      expect(e.gestor.descargasPedidas, isEmpty);
    });

    testWidgets(
      'la atribución de cada voz se ve al abrir "Licencia y atribución"',
      (tester) async {
        final e = Escenario();
        await abrir(tester, e);
        expect(k('modelo-ana-atribucion-texto'), findsNothing);
        await tester.ensureVisible(k('modelo-ana-atribucion'));
        await tester.tap(
          find.descendant(
            of: k('modelo-ana-atribucion'),
            matching: find.text('Licencia y atribución'),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          textoDe(tester, 'modelo-ana-atribucion-texto'),
          'Voz de prueba Ana. Atribución de prueba.',
        );
      },
    );

    testWidgets(
      'sin gestor (otra plataforma) la tarjeta no aparece y se mantiene la nota "próximamente"',
      (tester) async {
        final e = Escenario();
        await abrir(tester, e, conGestor: false);
        expect(k('voces-descargables'), findsNothing);
        expect(textoVisible(tester), contains('voz descargada · próximamente'));
      },
    );

    testWidgets(
      'con gestor, la nota "próximamente" de la voz descargada desaparece; la del audio pregrabado sigue',
      (tester) async {
        final e = Escenario();
        await abrir(tester, e);
        final t = textoVisible(tester);
        expect(t, isNot(contains('voz descargada · próximamente')));
        expect(t, contains('audio pregrabado del curso · próximamente'));
      },
    );

    testWidgets(
      'aunque el equipo no tenga voz propia, las voces descargables se ofrecen',
      (tester) async {
        final e = Escenario();
        await abrir(tester, e, fuentes: const []);
        expect(
          find.textContaining('La voz todavía no está disponible'),
          findsOneWidget,
        );
        expect(k('voces-descargables'), findsOneWidget);
      },
    );
  });

  group('criterio 18: Wi-Fi, datos móviles y sin red', () {
    testWidgets(
      'con Wi-Fi, un toque en Descargar pide la descarga sin permiso de datos',
      (tester) async {
        final e = Escenario();
        await abrir(tester, e);
        await tester.ensureVisible(k('modelo-ana-descargar'));
        await tester.tap(k('modelo-ana-descargar'));
        await asentar(tester);
        expect(e.gestor.descargasPedidas, [(id: 'ana', datosMoviles: false)]);
        expect(k('voces-datos-moviles'), findsNothing);
      },
    );

    testWidgets('con Ethernet también', (tester) async {
      final e = Escenario();
      e.red.poner(TipoDeRed.ethernet);
      await abrir(tester, e);
      await tester.ensureVisible(k('modelo-ana-descargar'));
      await tester.tap(k('modelo-ana-descargar'));
      await asentar(tester);
      expect(e.gestor.descargasPedidas, hasLength(1));
    });

    testWidgets(
      'con datos móviles pregunta, dice cuántos datos gasta y espera la respuesta',
      (tester) async {
        final e = Escenario();
        e.red.poner(TipoDeRed.datosMoviles);
        await abrir(tester, e);
        await tester.ensureVisible(k('modelo-ana-descargar'));
        await tester.tap(k('modelo-ana-descargar'));
        await tester.pumpAndSettle();
        expect(k('voces-datos-moviles'), findsOneWidget);
        expect(find.text('No estás en Wi-Fi'), findsOneWidget);
        expect(
          find.text(
            'La descarga usará ${formatearBytes(e.catalogo.porId('ana')!.bytes)} de tus datos.',
          ),
          findsOneWidget,
        );
        expect(
          e.gestor.descargasPedidas,
          isEmpty,
          reason: 'nada empieza antes de que confirme',
        );
      },
    );

    testWidgets('"Esperar al Wi-Fi" no descarga nada', (tester) async {
      final e = Escenario();
      e.red.poner(TipoDeRed.datosMoviles);
      await abrir(tester, e);
      await tester.ensureVisible(k('modelo-ana-descargar'));
      await tester.tap(k('modelo-ana-descargar'));
      await tester.pumpAndSettle();
      await tester.tap(k('voces-datos-moviles-esperar'));
      await tester.pumpAndSettle();
      expect(e.gestor.descargasPedidas, isEmpty);
      expect(textoDe(tester, 'modelo-ana-estado'), 'No descargada');
    });

    testWidgets(
      '"Descargar con datos" descarga con el permiso de esa vez, y la próxima vuelve a preguntar',
      (tester) async {
        final e = Escenario();
        e.red.poner(TipoDeRed.datosMoviles);
        await abrir(tester, e);
        await tester.ensureVisible(k('modelo-ana-descargar'));
        await tester.tap(k('modelo-ana-descargar'));
        await tester.pumpAndSettle();
        await tester.tap(k('voces-datos-moviles-descargar'));
        await asentar(tester);
        expect(e.gestor.descargasPedidas, [(id: 'ana', datosMoviles: true)]);

        await tester.ensureVisible(k('modelo-beto-descargar'));
        await tester.tap(k('modelo-beto-descargar'));
        await tester.pumpAndSettle();
        expect(
          k('voces-datos-moviles'),
          findsOneWidget,
          reason: 'no se recuerda',
        );
        await tester.tap(k('voces-datos-moviles-esperar'));
        await tester.pumpAndSettle();
      },
    );

    testWidgets('sin red avisa y no abre nada', (tester) async {
      final e = Escenario();
      e.red.poner(TipoDeRed.sinRed);
      await abrir(tester, e);
      await tester.ensureVisible(k('modelo-ana-descargar'));
      await tester.tap(k('modelo-ana-descargar'));
      await asentar(tester);
      expect(e.gestor.descargasPedidas, isEmpty);
      expect(
        textoDe(tester, 'modelo-ana-mensaje'),
        'No hay conexión. Cuando vuelva, puedes continuar la descarga.',
      );
    });
  });

  group('avance, cancelar y estados', () {
    testWidgets(
      'muestra el porcentaje y los MB mientras baja, con etiqueta para el lector de pantalla',
      (tester) async {
        final e = Escenario();
        await abrir(tester, e);
        final total = e.catalogo.porId('ana')!.bytes;
        await tester.ensureVisible(k('modelo-ana-descargar'));
        await tester.tap(k('modelo-ana-descargar'));
        await asentar(tester);
        e.gestor.avanzar('ana', total ~/ 2);
        await asentar(tester);
        expect(
          textoDe(tester, 'modelo-ana-estado'),
          'Descargando 50 % (${formatearBytes(total ~/ 2)} de ${formatearBytes(total)})',
        );
        expect(k('modelo-ana-progreso'), findsOneWidget);
        final barra = tester.widget<LinearProgressIndicator>(
          k('modelo-ana-progreso'),
        );
        expect(barra.value, closeTo(0.5, 0.01));
        expect(barra.semanticsLabel, 'Avance de la descarga');
        expect(barra.semanticsValue, '50 %');
        expect(k('modelo-ana-cancelar'), findsOneWidget);
        expect(k('modelo-ana-descargar'), findsNothing);
      },
    );

    testWidgets('Cancelar detiene la descarga', (tester) async {
      final e = Escenario();
      await abrir(tester, e);
      await tester.ensureVisible(k('modelo-ana-descargar'));
      await tester.tap(k('modelo-ana-descargar'));
      await asentar(tester);
      await tester.ensureVisible(k('modelo-ana-cancelar'));
      await tester.tap(k('modelo-ana-cancelar'));
      await asentar(tester);
      expect(e.gestor.cancelados, ['ana']);
      expect(textoDe(tester, 'modelo-ana-estado'), 'No descargada');
    });

    testWidgets('al terminar queda "Instalada" con Probar, Comprobar y Borrar', (
      tester,
    ) async {
      final e = Escenario();
      await abrir(tester, e);
      await tester.ensureVisible(k('modelo-ana-descargar'));
      await tester.tap(k('modelo-ana-descargar'));
      await asentar(tester);
      await e.gestor.terminarDescarga('ana');
      await asentar(tester);
      expect(textoDe(tester, 'modelo-ana-estado'), 'Instalada');
      for (final b in ['probar', 'comprobar', 'borrar']) {
        expect(k('modelo-ana-$b'), findsOneWidget, reason: b);
      }
      expect(k('modelo-ana-descargar'), findsNothing);
      expect(
        textoDe(tester, 'voces-espacio'),
        'Espacio usado por las voces: ${formatearBytes(e.catalogo.porId('ana')!.bytes)}',
      );
    });

    testWidgets(
      'una descarga a medias ofrece Reanudar con lo que falta y Borrar lo descargado',
      (tester) async {
        final e = Escenario();
        final total = e.catalogo.porId('ana')!.bytes;
        e.gestor.parciales['ana'] = 20000;
        await abrir(tester, e);
        expect(
          textoDe(tester, 'modelo-ana-estado'),
          'Descarga a medias: ${formatearBytes(20000)} de ${formatearBytes(total)}',
        );
        expect(
          find.text('Reanudar (${formatearBytes(total - 20000)})'),
          findsOneWidget,
        );
        expect(k('modelo-ana-borrar'), findsOneWidget);
        expect(find.text('Borrar lo descargado'), findsOneWidget);
      },
    );

    testWidgets('"dañada" se dice con palabras y ofrece Reintentar y Borrar', (
      tester,
    ) async {
      final e = Escenario();
      e.gestor.poner('ana', EstadoModelo.corrupto);
      await abrir(tester, e);
      expect(textoDe(tester, 'modelo-ana-estado'), startsWith('Dañada'));
      expect(k('modelo-ana-reintentar'), findsOneWidget);
      expect(k('modelo-ana-borrar'), findsOneWidget);
      expect(k('modelo-ana-probar'), findsNothing);
      await tester.ensureVisible(k('modelo-ana-reintentar'));
      await tester.tap(k('modelo-ana-reintentar'));
      await asentar(tester);
      expect(e.gestor.reintentados, ['ana']);
      expect(textoDe(tester, 'modelo-ana-estado'), 'Instalada');
      expect(
        textoDe(tester, 'modelo-ana-mensaje'),
        'La voz está lista otra vez.',
      );
    });

    testWidgets(
      'Comprobar dice si todo está en orden o si hay que descargar de nuevo',
      (tester) async {
        final e = Escenario();
        e.gestor.poner('ana', EstadoModelo.instalado);
        await abrir(tester, e);
        await tester.ensureVisible(k('modelo-ana-comprobar'));
        await tester.tap(k('modelo-ana-comprobar'));
        await asentar(tester);
        expect(e.gestor.comprobados, ['ana']);
        expect(
          textoDe(tester, 'modelo-ana-mensaje'),
          'Todo en orden: los archivos son los esperados.',
        );
        e.gestor.huellasBien = false;
        await tester.tap(k('modelo-ana-comprobar'));
        await asentar(tester);
        expect(
          textoDe(tester, 'modelo-ana-mensaje'),
          contains('Borra la voz y vuelve a descargarla'),
        );
        expect(textoDe(tester, 'modelo-ana-estado'), startsWith('Dañada'));
      },
    );

    testWidgets(
      'Borrar pide confirmación, dice cuánto se libera y se puede conservar',
      (tester) async {
        final e = Escenario();
        e.gestor.poner('ana', EstadoModelo.instalado);
        await abrir(tester, e);
        final peso = formatearBytes(e.catalogo.porId('ana')!.bytes);
        await tester.ensureVisible(k('modelo-ana-borrar'));
        await tester.tap(k('modelo-ana-borrar'));
        await tester.pumpAndSettle();
        expect(k('voces-borrar'), findsOneWidget);
        expect(find.textContaining('Liberarás $peso'), findsOneWidget);
        await tester.tap(k('voces-borrar-cancelar'));
        await tester.pumpAndSettle();
        expect(e.gestor.borrados, isEmpty);
        expect(textoDe(tester, 'modelo-ana-estado'), 'Instalada');

        await tester.tap(k('modelo-ana-borrar'));
        await tester.pumpAndSettle();
        await tester.tap(k('voces-borrar-confirmar'));
        await asentar(tester);
        expect(e.gestor.borrados, ['ana']);
        expect(textoDe(tester, 'modelo-ana-estado'), 'No descargada');
        expect(textoDe(tester, 'modelo-ana-mensaje'), 'Liberaste $peso.');
      },
    );
  });

  group('errores dichos sin culpa (5.5) y "no disponible aún"', () {
    Future<void> conError(
      WidgetTester tester,
      ErrorVoz error,
      String esperado,
    ) async {
      final e = Escenario();
      await abrir(tester, e);
      await tester.ensureVisible(k('modelo-ana-descargar'));
      await tester.tap(k('modelo-ana-descargar'));
      await asentar(tester);
      await e.gestor.fallarDescarga('ana', error);
      await asentar(tester);
      expect(textoDe(tester, 'modelo-ana-mensaje'), esperado);
    }

    testWidgets(
      'el alojamiento todavía no tiene el archivo: "No disponible aún"',
      (tester) async {
        await conError(
          tester,
          const NoDisponibleAun(),
          'Esta voz todavía no está disponible para descargar. Cuando esté lista, aparecerá aquí.',
        );
        expect(textoDe(tester, 'modelo-ana-estado'), 'No disponible aún');
        // Se puede volver a intentar.
        expect(k('modelo-ana-descargar'), findsOneWidget);
      },
    );

    testWidgets('sin red', (tester) async {
      await conError(
        tester,
        const SinRed(),
        'No hay conexión. Cuando vuelva, puedes continuar la descarga.',
      );
    });

    testWidgets('sin espacio, con lo que hay que liberar', (tester) async {
      await conError(
        tester,
        const SinEspacio(63000000),
        'No hay espacio para esta voz. Necesitas liberar 63 MB.',
      );
    });

    testWidgets('huella incorrecta', (tester) async {
      await conError(
        tester,
        const HuellaIncorrecta('ana.onnx'),
        'El archivo no era el esperado y se borró. Vuelve a intentarlo; si sigue igual, revisa tu conexión.',
      );
    });

    testWidgets('descarga interrumpida, con el porcentaje', (tester) async {
      await conError(
        tester,
        const DescargaInterrumpida(43, 100),
        'La descarga se detuvo en 43 %.',
      );
    });

    testWidgets('Wi-Fi perdido a mitad: dice qué hacer', (tester) async {
      await conError(
        tester,
        const SinWifi(),
        'Solo se descarga con Wi-Fi, o con tu permiso si usas datos móviles. Vuelve a tocar Descargar.',
      );
    });

    testWidgets('ningún mensaje de error lleva direcciones ni rutas', (
      tester,
    ) async {
      for (final error in const <ErrorVoz>[
        SinWifi(),
        SinRed(),
        SinEspacio(5),
        HuellaIncorrecta('x.onnx'),
        DescargaInterrumpida(1, 2),
        NoDisponibleAun(),
        FalloDeSintesis(Fuente.modelo, 'x'),
      ]) {
        final t = mensajeDeErrorDeDescarga(error, const InfoDeModelo(), 100);
        expect(t, isNot(contains('http')));
        expect(t, isNot(contains('/')));
      }
    });
  });

  group('Probar una voz descargada', () {
    testWidgets(
      'suena con la voz elegida, a velocidad normal, y dice cuál sonó',
      (tester) async {
        final e = Escenario();
        e.gestor.poner('beto', EstadoModelo.instalado);
        await abrir(tester, e, fuentes: [FuenteDeVozFalsa(), e.fuenteB()]);
        await tester.ensureVisible(k('modelo-beto-probar'));
        await tester.tap(k('modelo-beto-probar'));
        await asentar(tester);
        await tester.pumpAndSettle();
        final frases = e.puerta.peticiones
            .where((p) => p.texto != fraseDePruebaDeHumo)
            .toList();
        // La frase de prueba tiene dos oraciones: dos frases, la misma voz.
        expect(frases.map((p) => p.texto), [
          'Hello, this is a test.',
          'This is how my voice sounds.',
        ]);
        expect(
          frases.every(
            (p) => p.idModelo == 'beto' && p.sid == 0 && p.velocidad == 1.0,
          ),
          isTrue,
        );
        expect(
          textoDe(tester, 'modelo-beto-mensaje'),
          'Sonó con: Voz descargada · Beto',
        );
      },
    );

    testWidgets('Probar la voz británica usa el acento británico', (
      tester,
    ) async {
      final e = Escenario();
      e.gestor.poner('cori', EstadoModelo.instalado);
      await abrir(tester, e, fuentes: [FuenteDeVozFalsa(), e.fuenteB()]);
      await tester.ensureVisible(k('modelo-cori-probar'));
      await tester.tap(k('modelo-cori-probar'));
      await asentar(tester);
      await tester.pumpAndSettle();
      expect(
        e.puerta.peticiones
            .where((p) => p.texto != fraseDePruebaDeHumo)
            .map((p) => p.idModelo)
            .toSet(),
        {'cori'},
      );
      expect(
        textoDe(tester, 'modelo-cori-mensaje'),
        'Sonó con: Voz descargada · Cori',
      );
    });

    testWidgets('mientras suena se ofrece Parar', (tester) async {
      final e = Escenario();
      e.reproductor.manual = true;
      e.gestor.poner('ana', EstadoModelo.instalado);
      await abrir(tester, e, fuentes: [FuenteDeVozFalsa(), e.fuenteB()]);
      await tester.ensureVisible(k('modelo-ana-probar'));
      await tester.tap(k('modelo-ana-probar'));
      await asentar(tester);
      await tester.pump(const Duration(milliseconds: 50));
      expect(k('modelo-ana-parar'), findsOneWidget);
      expect(
        textoDe(tester, 'modelo-ana-mensaje'),
        'Suena con: Voz descargada · Ana',
      );
      await tester.tap(k('modelo-ana-parar'));
      await asentar(tester);
      expect(e.reproductor.sonando, isFalse);
      expect(k('modelo-ana-probar'), findsOneWidget);
    });
  });

  group('Diálogo de prueba con las voces descargadas', () {
    testWidgets(
      'con una mujer y un hombre descargados suena el diálogo de 2 voces, F1 y M1 distintas',
      (tester) async {
        final e = Escenario();
        e.gestor
          ..poner('ana', EstadoModelo.instalado)
          ..poner('beto', EstadoModelo.instalado);
        await abrir(tester, e, fuentes: [FuenteDeVozFalsa(), e.fuenteB()]);
        expect(k('voces-dialogo-en-US'), findsOneWidget);
        await tester.ensureVisible(k('voces-dialogo-en-US'));
        await tester.tap(k('voces-dialogo-en-US'));
        // Entre turno y turno hay una pausa del guion (reloj de la prueba).
        for (var i = 0; i < 8; i++) {
          await asentar(tester);
          await tester.pump(const Duration(milliseconds: 700));
        }
        await asentar(tester);
        final frases = e.puerta.peticiones
            .where((p) => p.texto != fraseDePruebaDeHumo)
            .toList();
        // Seis turnos (algunos de dos oraciones): cada frase con la voz de su turno.
        final esperadas = [
          for (final t in dialogoDePrueba)
            for (final f in partirEnFrases(t.texto))
              (t.voz == VozDeGuion.f1 ? 'ana' : 'beto', f),
        ];
        expect(frases.map((p) => (p.idModelo, p.texto)).toList(), esperadas);
        expect(frases.map((p) => p.idModelo).toSet(), {
          'ana',
          'beto',
        }, reason: 'F1 es la mujer y M1 el hombre, y se alternan');
        expect(
          textoDe(tester, 'voces-dialogo-mensaje'),
          'Sonó con: Voz descargada · F1: Ana · M1: Beto',
        );
      },
    );

    testWidgets(
      'sin una mujer y un hombre no hay diálogo y la pantalla lo explica',
      (tester) async {
        final e = Escenario();
        e.gestor.poner('ana', EstadoModelo.instalado);
        await abrir(tester, e, fuentes: [FuenteDeVozFalsa(), e.fuenteB()]);
        expect(k('voces-dialogo-falta'), findsOneWidget);
        expect(
          tester.widget<OutlinedButton>(k('voces-dialogo-en-US')).onPressed,
          isNull,
        );
      },
    );

    testWidgets(
      'sin ninguna voz descargada el botón del diálogo está apagado',
      (tester) async {
        final e = Escenario();
        await abrir(tester, e);
        expect(
          tester.widget<OutlinedButton>(k('voces-dialogo-en-US')).onPressed,
          isNull,
        );
        expect(k('voces-dialogo-falta'), findsOneWidget);
      },
    );

    testWidgets('mientras suena se ofrece Parar', (tester) async {
      final e = Escenario();
      e.reproductor.manual = true;
      e.gestor
        ..poner('ana', EstadoModelo.instalado)
        ..poner('beto', EstadoModelo.instalado);
      await abrir(tester, e, fuentes: [FuenteDeVozFalsa(), e.fuenteB()]);
      await tester.ensureVisible(k('voces-dialogo-en-US'));
      await tester.tap(k('voces-dialogo-en-US'));
      await asentar(tester);
      await tester.pump(const Duration(milliseconds: 50));
      expect(k('voces-dialogo-parar'), findsOneWidget);
      await tester.tap(k('voces-dialogo-parar'));
      await asentar(tester);
      expect(e.reproductor.sonando, isFalse);
      expect(k('voces-dialogo-parar'), findsNothing);
    });
  });

  group('accesibilidad', () {
    testWidgets(
      'el estado tiene una etiqueta con palabras para el lector de pantalla',
      (tester) async {
        final e = Escenario();
        e.gestor.poner('ana', EstadoModelo.instalado);
        final semantica = tester.ensureSemantics();
        await abrir(tester, e);
        expect(find.bySemanticsLabel('Estado: Instalada'), findsOneWidget);
        expect(
          find.bySemanticsLabel('Estado: No descargada'),
          findsNWidgets(2),
        );
        semantica.dispose();
      },
    );

    testWidgets('cada botón tiene texto (no solo icono ni color)', (
      tester,
    ) async {
      final e = Escenario();
      e.gestor
        ..poner('ana', EstadoModelo.instalado)
        ..poner('beto', EstadoModelo.corrupto);
      await abrir(tester, e);
      for (final texto in ['Probar', 'Comprobar', 'Borrar', 'Reintentar']) {
        expect(find.text(texto), findsWidgets, reason: texto);
      }
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_outlined), findsOneWidget);
    });

    for (final (nombre, dispositivo, ventana) in [
      ('teléfono', TipoDispositivo.telefono, const Size(390, 20000)),
      ('laptop estrecha', TipoDispositivo.laptop, const Size(700, 20000)),
    ]) {
      testWidgets('con letra al doble en $nombre no se desborda nada', (
        tester,
      ) async {
        fijarEscalaDeLetra(tester, 2.0);
        final e = Escenario();
        e.gestor
          ..poner('ana', EstadoModelo.instalado)
          ..poner('beto', EstadoModelo.corrupto);
        e.gestor.parciales['cori'] = 10000;
        final desbordes = await recolectarDesbordes(() async {
          await abrir(tester, e, dispositivo: dispositivo, ventana: ventana);
          await tester.tap(k('modelo-ana-borrar'));
          await tester.pumpAndSettle();
          await tester.tap(k('voces-borrar-cancelar'));
          await tester.pumpAndSettle();
        });
        expect(desbordes, isEmpty);
        expect(k('voces-descargables'), findsOneWidget);
      });
    }
  });

  group('quién la ve', () {
    testWidgets(
      'también la ve quien no usa el curso ni conversa: es del equipo, no de la persona',
      (tester) async {
        final e = Escenario();
        await abrir(tester, e, rol: Rol.cuidador);
        expect(k('voces-descargables'), findsOneWidget);
      },
    );
  });
}
