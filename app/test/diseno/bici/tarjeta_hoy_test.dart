// Tarjeta «Bicicleta» de Hoy (B1): la víspera invita a preparar; el sábado
// muestra salida, regreso y revisión; *Salí* es 1 toque; lo que no salió se
// dice sin culpa; con el modo foco no presiona; letra grande sin desbordes.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/diseno/diseno.dart';

import '../ayuda_pruebas.dart' show recolectarDesbordes;
import 'ayuda_bici.dart';

TarjetaBiciHoy _sabado({
  MomentoSalida momento = MomentoSalida.diaDeSalida,
  EncajeRevision encaje = EncajeRevision.cabe,
  String encajeTexto = 'Sobran 60 min',
  VoidCallback? alSali,
  VoidCallback? alEmpezar,
  VoidCallback? alPosponer,
  VoidCallback? alPreparar,
  VoidCallback? alRegistrar,
  VoidCallback? alDeshacer,
  VoidCallback? alTerminar,
  bool modoFoco = false,
  String? nota = 'Hoy toca tu salida en bici. ¿Todo listo?',
}) => TarjetaBiciHoy(
  momento: momento,
  salidaTexto: '8:00',
  detalleTexto: 'Sábado · unas 4 h',
  regresoTexto: '12:00',
  revisionTexto: '14:30',
  encaje: encaje,
  encajeTexto: encajeTexto,
  preparacionTexto: '10 de 10',
  notaTexto: nota,
  modoFoco: modoFoco,
  alSali: alSali,
  alEmpezar: alEmpezar,
  alPosponerRevision: alPosponer,
  alPreparar: alPreparar,
  alRegistrar: alRegistrar,
  alDeshacer: alDeshacer,
  alTerminar: alTerminar,
);

void main() {
  group('TarjetaBiciHoy', () {
    testWidgets('el viernes en la noche dice «Prepara tu salida» y ofrece '
        'Preparar de 64 dp', (tester) async {
      var preparar = 0;
      await montarBici(
        tester,
        TarjetaBiciHoy(
          momento: MomentoSalida.vispera,
          salidaTexto: 'Mañana · 8:00',
          detalleTexto: 'Unas 4 h',
          preparacionTexto: '6 de 10',
          alPreparar: () => preparar++,
        ),
        sport: true,
      );
      expect(find.text(TextosBici.prepararSalida), findsOneWidget);
      expect(find.text('Mañana · 8:00'), findsOneWidget);
      expect(find.text('Preparación: 6 de 10'), findsOneWidget);
      // En la víspera no se ofrece salir todavía.
      expect(find.text(TextosBici.sali), findsNothing);
      final boton = find.byKey(const ValueKey('bici-preparar'));
      expect(tester.getSize(boton).height, greaterThanOrEqualTo(64));
      await tester.tap(boton);
      expect(preparar, 1);
    });

    testWidgets('el sábado muestra salida, regreso estimado y revisión con '
        'icono y palabras', (tester) async {
      await montarBici(tester, _sabado(), sport: true);
      expect(find.text('8:00'), findsOneWidget);
      expect(find.text('12:00'), findsOneWidget);
      expect(find.text('14:30'), findsOneWidget);
      expect(find.text('Cabe · Sobran 60 min'), findsOneWidget);
      expect(find.byIcon(EncajeRevision.cabe.icono), findsWidgets);
      expect(
        find.text('Hoy toca tu salida en bici. ¿Todo listo?'),
        findsOneWidget,
      );
    });

    testWidgets('*Salí* es un toque y mide 64 dp; Empezar también', (
      tester,
    ) async {
      var sali = 0;
      var empezar = 0;
      await montarBici(
        tester,
        _sabado(alSali: () => sali++, alEmpezar: () => empezar++),
        sport: true,
      );
      final bSali = find.byKey(const ValueKey('bici-sali'));
      final bEmpezar = find.byKey(const ValueKey('bici-empezar'));
      expect(tester.getSize(bSali).height, greaterThanOrEqualTo(64));
      expect(tester.getSize(bEmpezar).height, greaterThanOrEqualTo(64));
      await tester.tap(bSali);
      expect(sali, 1);
      expect(empezar, 0);
      await tester.tap(bEmpezar);
      expect(empezar, 1);
    });

    testWidgets('«Pasar mi revisión a más tarde» solo sale si no cabe', (
      tester,
    ) async {
      var posponer = 0;
      await montarBici(
        tester,
        _sabado(alPosponer: () => posponer++),
        sport: true,
      );
      expect(find.text(TextosBici.posponerRevision), findsNothing);

      await montarBici(
        tester,
        _sabado(
          encaje: EncajeRevision.noCabe,
          encajeTexto: 'Faltan 30 min',
          alPosponer: () => posponer++,
        ),
        sport: true,
      );
      expect(find.text('No cabe · Faltan 30 min'), findsOneWidget);
      final boton = find.text(TextosBici.posponerRevision);
      expect(boton, findsOneWidget);
      await tester.tap(boton);
      expect(posponer, 1);
    });

    testWidgets('en curso ofrece Terminar de 64 dp y la marca «En curso»', (
      tester,
    ) async {
      var terminar = 0;
      await montarBici(
        tester,
        _sabado(momento: MomentoSalida.enCurso, alTerminar: () => terminar++),
        sport: true,
      );
      expect(find.text(TextosBici.enCurso), findsOneWidget);
      expect(find.text(TextosBici.sali), findsNothing);
      final boton = find.byKey(const ValueKey('bici-terminar'));
      expect(tester.getSize(boton).height, greaterThanOrEqualTo(64));
      await tester.tap(boton);
      expect(terminar, 1);
    });

    testWidgets('hecha dice «Hecha» y deja deshacer; ya no pide salir', (
      tester,
    ) async {
      var deshacer = 0;
      await montarBici(
        tester,
        _sabado(
          momento: MomentoSalida.hecha,
          nota: 'Salida registrada. Gracias por avisar.',
          alDeshacer: () => deshacer++,
          alRegistrar: () {},
        ),
        sport: true,
      );
      expect(find.text('Hecha'), findsOneWidget);
      expect(find.byKey(const ValueKey('bici-sali')), findsNothing);
      expect(
        find.text('Salida registrada. Gracias por avisar.'),
        findsOneWidget,
      );
      await tester.tap(find.text(TextosBici.deshacer));
      expect(deshacer, 1);
    });

    testWidgets('lo que no salió se dice sin culpa y sin mensaje de ruptura', (
      tester,
    ) async {
      await montarBici(
        tester,
        _sabado(
          momento: MomentoSalida.omitida,
          nota: 'Hoy no salió la ruta. Cuando quieras, la retomamos.',
          alDeshacer: () {},
        ),
        sport: true,
      );
      expect(find.text('No salió hoy'), findsOneWidget);
      final todo = textosVisibles(tester).join(' ').toLowerCase();
      for (final p in [...palabrasProhibidas, 'racha', 'rota', 'perdida']) {
        expect(todo.contains(p), isFalse, reason: p);
      }
      expect(find.byKey(const ValueKey('bici-sali')), findsNothing);
    });

    testWidgets('con el modo foco dice «Hoy puedes salir o dejarlo» y sigue '
        'ofreciendo la salida', (tester) async {
      await montarBici(
        tester,
        _sabado(modoFoco: true, alSali: () {}),
        sport: true,
      );
      expect(
        find.text('Hoy puedes salir o dejarlo: ambos están bien.'),
        findsOneWidget,
      );
      expect(
        find.text('Hoy toca tu salida en bici. ¿Todo listo?'),
        findsNothing,
      );
      expect(find.text(TextosBici.sali), findsOneWidget);
    });

    testWidgets('lee su resumen al lector de pantalla', (tester) async {
      final handle = tester.ensureSemantics();
      await montarBici(tester, _sabado(alSali: () {}), sport: true);
      expect(
        etiquetasAccesibles(tester).any(
          (e) =>
              e.contains('Regreso estimado 12:00') &&
              e.contains('Revisión semanal 14:30') &&
              e.contains('Cabe, sobran 60 min'),
        ),
        isTrue,
      );
      handle.dispose();
    });

    testWidgets('con la personalidad de la bici va siempre en alto contraste', (
      tester,
    ) async {
      await montarBici(
        tester,
        _sabado(),
        sport: true,
        brillo: Brightness.light,
      );
      final v = ValoresDiseno.de(tester.element(find.byType(TarjetaBiciHoy)));
      expect(v.altoContraste, isTrue);
    });

    testWidgets('estados: vacío, cargando, sin conexión y error', (
      tester,
    ) async {
      var reintentos = 0;
      for (final estado in estadosSinContenido) {
        await montarBici(
          tester,
          TarjetaBiciHoy(
            momento: MomentoSalida.diaDeSalida,
            salidaTexto: '8:00',
            estado: estado,
            alReintentar: () => reintentos++,
          ),
          sport: true,
        );
        expect(find.byType(CuerpoEstadoBici), findsOneWidget);
        if (estado == EstadoVistaBici.error) {
          await tester.tap(find.text(TextosBici.reintentar));
        }
      }
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
            _sabado(
              encaje: EncajeRevision.noCabe,
              encajeTexto: 'Faltan 30 min',
              alSali: () {},
              alEmpezar: () {},
              alPosponer: () {},
              alRegistrar: () {},
            ),
            sport: true,
            ancho: ancho,
            letra: 2.0,
          );
        });
        expect(desbordes, isEmpty);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
