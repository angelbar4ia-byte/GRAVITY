// Fase 8, bloque 7 (docs/specs/fase-8-habitos-gimnasio.md, 8.5 y 17, G7): la
// orden «abre el entrenamiento» y «qué toca hoy en el gimnasio». Solo navega:
// sin IA, sin leer series, cargas ni molestias, sin historial.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/navegacion.dart' show esRutaReservadaDeHabitos;
import 'package:gravity/app/pantallas_externas.dart'
    show consultaLocalHabitosProvider;
import 'package:gravity/app/sesion_efectiva.dart';
import 'package:gravity/modulos/gravity/conversacion/cliente_asistente.dart';
import 'package:gravity/modulos/gravity/conversacion/conversacion.dart';
import 'package:gravity/modulos/gravity/ordenes/barra_ordenes.dart';
import 'package:gravity/modulos/gravity/ordenes/interprete_ordenes.dart';
import 'package:gravity/modulos/gravity/ordenes/orden_entrenamiento.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/herramientas/herramientas.dart';

const _nombre = 'habitos.abrir_entrenamiento';

/// Un cliente de la IA que falla la prueba si alguien lo llama.
final class _ClienteQueNoDebeLlamarse implements ClienteAsistente {
  int llamadas = 0;

  @override
  Future<RespuestaAsistente> preguntar({
    required String mensaje,
    required String sesion,
    List<TurnoConversacion> historial = const [],
  }) async {
    llamadas++;
    throw StateError('La barra de órdenes no habla con la IA');
  }

  @override
  Future<Object?> sugerirRecetas(Map<String, Object?> contexto) async {
    llamadas++;
    throw StateError('La barra de órdenes no habla con la IA');
  }
}

InterpreteOrdenes _interprete(
  Rol rol, {
  bool esMaestra = false,
  TipoDispositivo? dispositivo = TipoDispositivo.telefono,
}) => InterpreteOrdenes(
  rol: rol,
  dispositivo: dispositivo,
  esMaestra: esMaestra,
  catalogo: catalogoDeOrdenes(),
);

String? _destino(ResultadoOrden r) => switch (r) {
  OrdenEntendida(:final destino) => destino.nombre,
  _ => null,
};

void main() {
  group('La herramienta', () {
    final h = herramientaAbrirEntrenamientoHabitos;

    test('es de Hábitos, solo local, de solo navegar y sin historial', () {
      expect(h.nombre, _nombre);
      expect(h.modulo, Modulo.habitos);
      expect(h.soloLocal, isTrue);
      expect(h.escribe, isFalse);
      expect(h.accion, Accion.leer);
      expect(h.pertenencia, Pertenencia.propia);
      expect(h.consulta, isFalse);
      expect(h.hoja, isNull);
      expect(h.guardaEnHistorial, isFalse);
      expect(h.ofreceASoloLectura, isFalse);
      expect(h.roles, {Rol.dueno, Rol.coadministrador, Rol.familiar});
      expect(h.dispositivos, isNull, reason: 'va en teléfono, tablet y laptop');
    });

    test(
      'el destino es el de la especificación y no es una ruta reservada',
      () {
        expect(destinoEntrenamiento, '/habitos/entrenamiento');
        expect(h.ruta, destinoEntrenamiento);
        expect(RutasDeHerramientas.hoyHabitos, isNot(destinoEntrenamiento));
        // No pide PIN: lo sensible (las molestias) está en otra pantalla.
        expect(esRutaReservadaDeHabitos(destinoEntrenamiento), isFalse);
        expect(
          esRutaReservadaDeHabitos('$destinoEntrenamiento/molestias'),
          isFalse,
          reason: 'esta orden nunca la nombra: la reserva es cosa de Hábitos',
        );
      },
    );

    test('nombre, descripción y palabras clave no llevan cifras ni datos de '
        'salud', () {
      final cifras = RegExp(r'[\d$]');
      expect(cifras.hasMatch(h.nombre), isFalse);
      expect(cifras.hasMatch(h.descripcion), isFalse);
      for (final p in h.palabrasClave) {
        expect(cifras.hasMatch(p), isFalse, reason: p);
        expect(
          RegExp(r'molest|dolor|lesi|serie|carga').hasMatch(p),
          isFalse,
          reason: p,
        );
      }
    });

    test('el catálogo de la barra la trae una sola vez, después de lo de '
        'Hábitos', () {
      final nombres = catalogoDeOrdenes().map((x) => x.nombre).toList();
      expect(nombres.where((n) => n == _nombre), hasLength(1));
      final i = nombres.indexOf(_nombre);
      expect(
        catalogoDeOrdenes()[i - 1].modulo,
        Modulo.habitos,
        reason: 'va pegada al resto de Hábitos',
      );
      expect(catalogoDeOrdenes()[i + 1].modulo, isNot(Modulo.habitos));
      // Lo demás del catálogo queda igual y en el mismo orden.
      expect(
        nombres.where((n) => n != _nombre).toList(),
        herramientasNavegacion
            .map((x) => x.nombre)
            .where((n) => n != _nombre)
            .toList(),
      );
    });
  });

  group('Interpretación (sin IA)', () {
    const frases = [
      'abre entrenamiento',
      'abre el entrenamiento',
      'Abre el Entrenamiento',
      'entrenamiento',
      'ábreme el entrenamiento',
      'gimnasio',
      'ir al gimnasio',
      'qué toca hoy en el gimnasio',
      'que toca hoy en el gimnasio',
      'QUÉ TOCA HOY EN EL GIMNASIO',
      '¿Qué me toca hoy en el gimnasio?',
      'qué toca hoy de entrenamiento',
      'qué toca entrenar hoy',
    ];

    for (final rol in [Rol.dueno, Rol.coadministrador, Rol.familiar]) {
      test('${rol.name}: cada frase abre el entrenamiento y solo eso', () {
        final interprete = _interprete(rol);
        for (final frase in frases) {
          expect(
            _destino(interprete.interpretar(frase)),
            _nombre,
            reason: frase,
          );
        }
      });
    }

    test('en cualquier dispositivo, también sin saber cuál', () {
      for (final d in [...TipoDispositivo.values, null]) {
        expect(
          _destino(
            _interprete(
              Rol.dueno,
              dispositivo: d,
            ).interpretar('abre el entrenamiento'),
          ),
          _nombre,
          reason: '$d',
        );
      }
    });

    test('«hoy» solo sigue llevando a Hábitos › Hoy y lo demás de Hábitos no '
        'cambia', () {
      final i = _interprete(Rol.familiar);
      expect(_destino(i.interpretar('abre hoy')), 'habitos.abrir_hoy');
      expect(_destino(i.interpretar('qué toca hoy')), 'habitos.abrir_hoy');
      expect(_destino(i.interpretar('mi agenda')), 'habitos.abrir_agenda');
      expect(_destino(i.interpretar('resumen de hoy')), 'habitos.resumen_hoy');
      expect(_destino(i.interpretar('abre hábitos')), 'habitos.abrir');
      expect(_destino(i.interpretar('tengo un antojo')), 'habitos.sos');
    });

    test('con un error de dedo ofrece opciones parecidas, no abre sola', () {
      final r = _interprete(Rol.dueno).interpretar('entrenamento');
      expect(r, isA<OrdenParecida>());
      expect(
        (r as OrdenParecida).opciones.map((o) => o.nombre),
        contains(_nombre),
      );
    });

    test('sugiere mientras se escribe', () {
      final i = _interprete(Rol.dueno);
      for (final parcial in ['entren', 'gimn', 'abre entrena']) {
        final sugerencias = i.sugerir(parcial);
        expect(
          sugerencias.map((s) => s.destino.nombre),
          contains(_nombre),
          reason: parcial,
        );
      }
      expect(i.sugerir('entren').first.destino.nombre, _nombre);
    });

    test('quien no tiene Hábitos no la recibe: cuidadora, Casa y la maestra '
        'que no es dueña', () {
      for (final (rol, maestra) in [
        (Rol.cuidador, false),
        (Rol.casa, false),
        (Rol.coadministrador, true),
      ]) {
        final i = _interprete(rol, esMaestra: maestra);
        expect(
          i.destinos.map((d) => d.nombre),
          isNot(contains(_nombre)),
          reason: rol.name,
        );
        for (final frase in frases) {
          expect(
            i.interpretar(frase),
            isNot(isA<OrdenEntendida>()),
            reason: '$frase / ${rol.name}',
          );
          expect(
            i.sugerir(frase).map((s) => s.destino.nombre),
            isNot(contains(_nombre)),
            reason: '$frase / ${rol.name}',
          );
        }
      }
    });

    test('el dueño que es también la maestra la conserva (es lo suyo)', () {
      expect(
        _interprete(Rol.dueno, esMaestra: true).destinos.map((d) => d.nombre),
        contains(_nombre),
      );
    });
  });

  group('Ejecución: solo navega', () {
    final registro = registroDeOrdenes();

    test('abre el destino y no pide nada: ni una hoja, ni una consulta '
        'local, ni nada para la IA', () async {
      // Destino simulado: lo que hay detrás de la ruta no importa aquí.
      final abiertas = <String>[];
      final hojas = <HojaDeRegistro>[];
      final consultas = <String>[];
      final r = await registro.ejecutar(
        _nombre,
        // Aunque alguien le pase datos, la herramienta no los usa.
        const {'carga': 40, 'series': 3, 'molestia': 'hombro'},
        ContextoHerramienta(
          rol: Rol.familiar,
          navegar: abiertas.add,
          abrirHoja: hojas.add,
          consultaLocal: (n) async {
            consultas.add(n);
            return 'Hoy toca A: 3 series de 10 con 40 kg';
          },
        ),
      );
      expect(abiertas, [destinoEntrenamiento]);
      expect(hojas, isEmpty);
      expect(consultas, isEmpty, reason: 'no lee nada del entrenamiento');
      expect(r.soloLocal, isTrue);
      expect(r.paraIa, isNull);
      expect(r.requiereConfirmacion, isFalse);
      expect(r.contenido, isNot(matches(RegExp(r'[\d]'))));
      expect(r.contenido, isNot(contains('serie')));
    });

    test('sin pantalla donde abrirla, avisa y no falla', () async {
      final r = await registro.ejecutar(
        _nombre,
        const {},
        const ContextoHerramienta(rol: Rol.dueno),
      );
      expect(r.contenido, contains('No hay una pantalla'));
      expect(r.paraIa, isNull);
    });

    test(
      'dueño, coadministrador y familiar la ejecutan; los demás no',
      () async {
        for (final rol in Rol.values) {
          final abiertas = <String>[];
          final intento = registro.ejecutar(
            _nombre,
            const {},
            ContextoHerramienta(rol: rol, navegar: abiertas.add),
          );
          if ({Rol.dueno, Rol.coadministrador, Rol.familiar}.contains(rol)) {
            await intento;
            expect(abiertas, [destinoEntrenamiento], reason: rol.name);
          } else {
            await expectLater(intento, throwsA(isA<HerramientaNoDisponible>()));
            expect(abiertas, isEmpty, reason: rol.name);
          }
        }
      },
    );

    test('la cuenta maestra que no es dueña no la ejecuta', () async {
      final abiertas = <String>[];
      await expectLater(
        registro.ejecutar(
          _nombre,
          const {},
          ContextoHerramienta(
            rol: Rol.coadministrador,
            esMaestra: true,
            navegar: abiertas.add,
          ),
        ),
        throwsA(
          isA<HerramientaNoDisponible>().having(
            (e) => e.motivo,
            'motivo',
            MotivoNoDisponible.cuentaMaestra,
          ),
        ),
      );
      expect(abiertas, isEmpty);
    });

    test('un módulo de Hábitos apagado no la ofrece', () {
      expect(
        registro.buscar(
          _nombre,
          rol: Rol.dueno,
          modulosActivos: const {Modulo.finanzas},
        ),
        isNull,
      );
    });
  });

  group('Historial: nunca queda lo escrito', () {
    final i = _interprete(Rol.familiar);

    test('toda orden del entrenamiento se guarda como «Orden de Hábitos '
        'reservada»', () {
      for (final orden in [
        'abre el entrenamiento',
        'qué toca hoy en el gimnasio',
        'gimnasio',
      ]) {
        expect(i.paraHistorial(orden), ordenDeHabitosReservada, reason: orden);
        expect(
          textoParaHistorial(orden),
          ordenDeHabitosReservada,
          reason: orden,
        );
      }
      // Con un error de dedo no se entiende la orden, pero podría llevar a
      // Hábitos: tampoco se guarda tal cual.
      expect(i.paraHistorial('entrenamento'), ordenDeHabitosReservada);
    });

    test('las molestias nunca se guardan tal cual, se entienda o no la '
        'orden', () {
      for (final orden in [
        'me duele el hombro',
        'tengo dolor en la rodilla',
        'registra mis molestias',
        'abre las molestias',
        'una lesión en la espalda',
      ]) {
        expect(
          textoParaHistorial(orden),
          ordenDeHabitosReservada,
          reason: orden,
        );
        expect(i.paraHistorial(orden), ordenDeHabitosReservada, reason: orden);
      }
    });

    test('lo demás se guarda igual', () {
      for (final orden in ['abre presupuesto', 'abre casa', 'ajustes']) {
        expect(
          InterpreteOrdenes(
            rol: Rol.dueno,
            catalogo: catalogoDeOrdenes(),
          ).paraHistorial(orden),
          orden,
          reason: orden,
        );
      }
    });
  });

  group('La barra de órdenes', () {
    Widget app(
      List<String> rutas,
      _ClienteQueNoDebeLlamarse cliente,
      List<String> consultas, {
      Rol rol = Rol.familiar,
    }) => ProviderScope(
      overrides: [
        esCuentaMaestraProvider.overrideWithValue(false),
        clienteAsistenteProvider.overrideWithValue(cliente),
        consultaLocalHabitosProvider.overrideWithValue((herramienta) async {
          consultas.add(herramienta);
          return null;
        }),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: BarraOrdenes(
            rol: rol,
            dispositivo: TipoDispositivo.telefono,
            onNavegar: rutas.add,
          ),
        ),
      ),
    );

    for (final frase in [
      'abre el entrenamiento',
      'qué toca hoy en el gimnasio',
    ]) {
      testWidgets('«$frase» + Enter navega sin IA y deja la barra vacía', (
        tester,
      ) async {
        final rutas = <String>[];
        final consultas = <String>[];
        final cliente = _ClienteQueNoDebeLlamarse();
        await tester.pumpWidget(app(rutas, cliente, consultas));
        await tester.tap(find.byType(TextField));
        await tester.pump();
        await tester.enterText(find.byType(TextField), frase);
        await tester.pump();
        await tester.testTextInput.receiveAction(TextInputAction.go);
        await tester.pumpAndSettle();

        expect(rutas, [destinoEntrenamiento]);
        expect(cliente.llamadas, 0, reason: 'sin IA');
        expect(consultas, isEmpty, reason: 'no lee nada de Hábitos');
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          isEmpty,
        );
      });
    }

    testWidgets('mientras se escribe ofrece «Abrir Entrenamiento» y elegirla '
        'tampoco habla con la IA', (tester) async {
      final rutas = <String>[];
      final consultas = <String>[];
      final cliente = _ClienteQueNoDebeLlamarse();
      await tester.pumpWidget(app(rutas, cliente, consultas));
      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'entren');
      await tester.pump();
      expect(find.text('Abrir Entrenamiento'), findsOneWidget);
      await tester.tap(find.text('Abrir Entrenamiento'));
      await tester.pumpAndSettle();
      expect(rutas, [destinoEntrenamiento]);
      expect(cliente.llamadas, 0);
      expect(consultas, isEmpty);
    });

    testWidgets('la cuidadora no ve el entrenamiento ni por escribirlo', (
      tester,
    ) async {
      final rutas = <String>[];
      final cliente = _ClienteQueNoDebeLlamarse();
      await tester.pumpWidget(app(rutas, cliente, [], rol: Rol.cuidador));
      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'abre el entrenamiento');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.go);
      await tester.pumpAndSettle();
      expect(rutas, isEmpty);
      expect(cliente.llamadas, 0);
    });
  });
}
