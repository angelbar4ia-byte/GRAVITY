// F8-7.1, grupo 4: la pantalla del módulo Casa (laptop y tablet): estado del
// puente con Home Assistant y frases fijas de las bocinas (D6, D9), solo
// lectura y sin inventar integraciones.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/casa/estado/estado_puente.dart';
import 'package:gravity/modulos/casa/pantallas/pantalla_casa.dart';
import 'package:gravity/modulos/casa/puente/frases.dart';
import 'package:gravity/modulos/casa/puente/mensaje_bocina.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/contratos/rutas.dart';
import 'package:gravity/nucleo/herramientas/alimentacion_voz.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:gravity/app/router.dart';

import '../../app/ayuda_plataforma.dart';
import '../../app/tablet_tipos_test.dart'
    show contenedorDe, montarPublica, ubicacion;

Future<void> irACasa(WidgetTester tester) async {
  contenedorDe(tester).read(routerProvider).go(Rutas.casa);
  await tester.pumpAndSettle();
}

void main() {
  List<Override> puente(InformePuente informe) => [
    fuentePuenteProvider.overrideWithValue(FuentePuenteEnMemoria(informe)),
  ];

  group('estado del puente', () {
    testWidgets('sin puente: estado vacío honesto y cómo configurarlo', (
      tester,
    ) async {
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.laptop,
        sesion: sesionCon(Rol.dueno),
      );
      await irACasa(tester);
      expect(find.byType(PantallaCasa), findsOneWidget);
      expect(find.text('Próximamente'), findsNothing);
      expect(find.text('Aún no hay puente configurado'), findsOneWidget);
      // Los pasos están dentro de "Cómo configurarlo".
      await tester.tap(find.byKey(const ValueKey('como-configurar-puente')));
      await tester.pumpAndSettle();
      for (final paso in pasosParaConfigurarPuente) {
        expect(find.text(paso), findsOneWidget);
      }
      // Nunca se pide ni se muestra un token o una dirección: no hay campos.
      expect(find.byType(TextField), findsNothing);
      expect(textoVisible(tester), contains('no abras puertos'));
    });

    testWidgets('puente conectado muestra la última respuesta', (tester) async {
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.laptop,
        sesion: sesionCon(Rol.dueno),
        extras: puente(
          InformePuente(
            EstadoDelPuente.conectado,
            ultimaRespuesta: DateTime(2026, 10, 20, 9, 5),
          ),
        ),
      );
      await irACasa(tester);
      expect(find.text('Puente conectado'), findsOneWidget);
      expect(find.textContaining('Última respuesta: 09:05'), findsOneWidget);
      expect(find.text('Aún no hay puente configurado'), findsNothing);
    });

    testWidgets(
      'puente que no responde lo dice y se puede volver a comprobar',
      (tester) async {
        final fuente = FuentePuenteEnMemoria(
          const InformePuente(EstadoDelPuente.sinRespuesta),
        );
        await montarApp(
          tester,
          dispositivo: TipoDispositivo.laptop,
          sesion: sesionCon(Rol.dueno),
          extras: [fuentePuenteProvider.overrideWithValue(fuente)],
        );
        await irACasa(tester);
        expect(find.text('El puente no responde'), findsOneWidget);
        fuente.informe = const InformePuente(EstadoDelPuente.conectado);
        await tester.tap(
          find.byKey(const ValueKey('volver-a-comprobar-puente')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Puente conectado'), findsOneWidget);
      },
    );
  });

  group('frases fijas (D6)', () {
    testWidgets('lista exactamente las frases aprobadas, ninguna más', (
      tester,
    ) async {
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.laptop,
        sesion: sesionCon(Rol.dueno),
      );
      await irACasa(tester);
      expect(frasesFijas, hasLength(5));
      for (final frase in frasesFijas) {
        expect(find.byKey(ValueKey('frase-${frase.id}')), findsOneWidget);
        expect(find.text('“Hey Google, ${frase.texto}”'), findsOneWidget);
        // Cada frase trae lo que hace (la descripción de su herramienta).
        final herramienta = herramientasVozAlimentacion.firstWhere(
          (h) => h.nombre == frase.herramienta,
        );
        expect(find.textContaining(herramienta.descripcion), findsOneWidget);
      }
      // La pantalla no deja escribir frases libres ni mandar texto.
      expect(find.byType(TextField), findsNothing);
      // La cuidadora no usa este canal (D5, D18): no aparece entre los roles.
      expect(textoVisible(tester), isNot(contains('cuidador')));
    });

    testWidgets('dice que nunca hay dinero ni datos clínicos en la bocina', (
      tester,
    ) async {
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.laptop,
        sesion: sesionCon(Rol.dueno),
      );
      await irACasa(tester);
      final nota = find.byKey(const ValueKey('nota-limites-bocina'));
      expect(nota, findsOneWidget);
      expect(
        find.descendant(
          of: nota,
          matching: find.textContaining('nunca se dicen montos de dinero'),
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('${FiltroBocina.maximoCaracteres} caracteres'),
        findsOneWidget,
      );
    });

    test('ninguna frase ni su descripción lleva cifras ni dinero', () {
      final filtro = FiltroBocina();
      for (final frase in frasesFijas) {
        final r = filtro.validar(
          TipoMensajeBocina.pasoReceta,
          'Hey Google, ${frase.texto}',
        );
        expect(r.aceptado, isTrue, reason: frase.texto);
      }
    });
  });

  group('quién la abre (D5)', () {
    for (final rol in [Rol.dueno, Rol.coadministrador, Rol.familiar]) {
      testWidgets('${rol.name} la ve, en el teléfono también', (tester) async {
        await montarApp(
          tester,
          dispositivo: TipoDispositivo.telefono,
          sesion: sesionCon(rol),
        );
        await irACasa(tester);
        expect(ubicacion(tester), Rutas.casa);
        expect(find.byType(PantallaCasa), findsOneWidget);
      });
    }

    testWidgets('la cuidadora no entra (va a su turno)', (tester) async {
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.telefono,
        sesion: sesionCon(Rol.cuidador),
      );
      await irACasa(tester);
      expect(find.byType(PantallaCasa), findsNothing);
      expect(ubicacion(tester), isNot(Rutas.casa));
    });

    testWidgets('la cuenta Casa de la tablet la ve, sin dinero', (
      tester,
    ) async {
      await montarPublica(tester);
      await irACasa(tester);
      expect(ubicacion(tester), Rutas.casa);
      expect(find.byType(PantallaCasa), findsOneWidget);
      revisarSinDinero(tester);
    });
  });
}
