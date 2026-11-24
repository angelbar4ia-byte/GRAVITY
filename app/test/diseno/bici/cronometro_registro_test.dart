// Cronómetro (B4) y hoja de registro de la salida: el cronómetro se basa en
// instantes (sobrevive a todo, sin Timer.periodic), se empieza y se termina
// parado con botones de 64 dp; la hoja registra con tres toques, la distancia
// la escribe la persona y nada depende solo del color.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/diseno/diseno.dart';

import '../ayuda_pruebas.dart' show recolectarDesbordes;
import 'ayuda_bici.dart';

void main() {
  group('SalidaCronometrada y formatos', () {
    test('el tiempo se calcula contra el reloj y nunca es negativo', () {
      final t0 = DateTime(2026, 11, 28, 8);
      final s = SalidaCronometrada.iniciar(t0);
      expect(s.transcurrido(t0), Duration.zero);
      expect(
        s.transcurrido(t0.add(const Duration(hours: 1, minutes: 42))),
        const Duration(hours: 1, minutes: 42),
      );
      // Si el reloj se atrasa, queda en cero.
      expect(
        s.transcurrido(t0.subtract(const Duration(minutes: 5))),
        Duration.zero,
      );
    });

    test('terminar congela el tiempo y es idempotente', () {
      final t0 = DateTime(2026, 11, 28, 8);
      final s = SalidaCronometrada.iniciar(t0);
      final fin = t0.add(const Duration(hours: 4, minutes: 5));
      final t = s.terminar(fin);
      expect(t.terminada, isTrue);
      expect(
        t.transcurrido(fin.add(const Duration(hours: 9))),
        const Duration(hours: 4, minutes: 5),
      );
      expect(t.terminar(fin.add(const Duration(hours: 1))).fin, fin);
      expect(s.terminada, isFalse);
      expect(t, SalidaCronometrada(inicio: t0, fin: fin));
    });

    test('formatoCronometro: horas sin cero a la izquierda', () {
      expect(formatoCronometro(Duration.zero), '0:00:00');
      expect(formatoCronometro(const Duration(seconds: 59)), '0:00:59');
      expect(
        formatoCronometro(const Duration(hours: 1, minutes: 42, seconds: 10)),
        '1:42:10',
      );
      expect(formatoCronometro(const Duration(hours: 12)), '12:00:00');
    });

    test('el anuncio cambia por minuto, no por segundo', () {
      expect(
        anuncioCronometro(const Duration(seconds: 59)),
        'menos de un minuto',
      );
      expect(
        anuncioCronometro(const Duration(minutes: 1, seconds: 30)),
        '1 minuto',
      );
      expect(
        anuncioCronometro(const Duration(hours: 1, minutes: 42, seconds: 10)),
        '1 hora 42 minutos',
      );
      expect(anuncioCronometro(const Duration(hours: 4)), '4 horas');
      expect(
        anuncioCronometro(const Duration(minutes: 61, seconds: 5)),
        anuncioCronometro(const Duration(minutes: 61, seconds: 58)),
      );
    });
  });

  group('CronometroSalida', () {
    testWidgets('sin empezar: Empezar de 64 dp y la nota de que se hace '
        'parado', (tester) async {
      var empezar = 0;
      final reloj = RelojBici();
      await montarBici(
        tester,
        CronometroSalida(
          salida: null,
          ahora: reloj.ahora,
          alEmpezar: () => empezar++,
        ),
        sport: true,
      );
      expect(find.text('0:00:00'), findsOneWidget);
      expect(find.text(TextosBici.sinEmpezar), findsOneWidget);
      expect(find.text(TextosBici.cronometroParado), findsOneWidget);
      final boton = find.byKey(const ValueKey('cronometro-empezar'));
      expect(tester.getSize(boton).height, greaterThanOrEqualTo(64));
      await tester.tap(boton);
      expect(empezar, 1);
      await desmontar(tester);
    });

    testWidgets('en curso cuenta contra el reloj, un segundo a la vez, y '
        'ofrece Terminar de 64 dp', (tester) async {
      var terminar = 0;
      final reloj = RelojBici();
      final salida = SalidaCronometrada(
        inicio: reloj.momento.subtract(
          const Duration(hours: 1, minutes: 42, seconds: 10),
        ),
      );
      await montarBici(
        tester,
        CronometroSalida(
          salida: salida,
          ahora: reloj.ahora,
          alTerminar: () => terminar++,
        ),
        sport: true,
      );
      expect(find.text('1:42:10'), findsOneWidget);
      expect(find.text(TextosBici.enCurso), findsOneWidget);
      await reloj.avanzar(tester, const Duration(seconds: 1));
      expect(find.text('1:42:11'), findsOneWidget);
      await reloj.avanzar(tester, const Duration(seconds: 3));
      expect(find.text('1:42:14'), findsOneWidget);
      final boton = find.byKey(const ValueKey('cronometro-terminar'));
      expect(tester.getSize(boton).height, greaterThanOrEqualTo(64));
      await tester.tap(boton);
      expect(terminar, 1);
      await desmontar(tester);
    });

    testWidgets('al volver de segundo plano pone el tiempo al día de golpe', (
      tester,
    ) async {
      final reloj = RelojBici();
      final salida = SalidaCronometrada(
        inicio: reloj.momento.subtract(const Duration(minutes: 10)),
      );
      await montarBici(
        tester,
        CronometroSalida(salida: salida, ahora: reloj.ahora),
        sport: true,
      );
      expect(find.text('0:10:00'), findsOneWidget);
      // La app pasa un buen rato en segundo plano: no hay avisos corriendo
      // y, al volver, el número se calcula contra el reloj.
      reloj.momento = reloj.momento.add(const Duration(minutes: 25));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text('0:35:00'), findsOneWidget);
      await desmontar(tester);
    });

    testWidgets('terminada se queda quieta, dice «Terminado» y deja '
        'registrar; no programa ningún aviso', (tester) async {
      var registrar = 0;
      final reloj = RelojBici();
      final salida = SalidaCronometrada(
        inicio: reloj.momento.subtract(const Duration(hours: 4, minutes: 5)),
      ).terminar(reloj.momento);
      await montarBici(
        tester,
        CronometroSalida(
          salida: salida,
          ahora: reloj.ahora,
          alRegistrar: () => registrar++,
        ),
        sport: true,
      );
      expect(find.text('4:05:00'), findsOneWidget);
      expect(find.text(TextosBici.terminado), findsOneWidget);
      expect(find.byKey(const ValueKey('cronometro-terminar')), findsNothing);
      // Sin avisos pendientes: avanzar el reloj no cambia nada y no queda
      // ningún Timer corriendo.
      await reloj.avanzar(tester, const Duration(minutes: 3));
      expect(find.text('4:05:00'), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
      final boton = find.byKey(const ValueKey('cronometro-registrar'));
      expect(tester.getSize(boton).height, greaterThanOrEqualTo(64));
      await tester.tap(boton);
      expect(registrar, 1);
    });

    testWidgets('con «reducir movimiento» se ve igual: solo el número', (
      tester,
    ) async {
      final reloj = RelojBici();
      await montarBici(
        tester,
        CronometroSalida(
          salida: SalidaCronometrada(
            inicio: reloj.momento.subtract(const Duration(minutes: 3)),
          ),
          ahora: reloj.ahora,
        ),
        sport: true,
        reducirMovimiento: true,
      );
      expect(find.text('0:03:00'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await desmontar(tester);
    });

    testWidgets('el lector de pantalla oye el tiempo por minutos, no por '
        'segundos', (tester) async {
      final handle = tester.ensureSemantics();
      final reloj = RelojBici();
      await montarBici(
        tester,
        CronometroSalida(
          salida: SalidaCronometrada(
            inicio: reloj.momento.subtract(
              const Duration(hours: 1, minutes: 42, seconds: 10),
            ),
          ),
          ahora: reloj.ahora,
          alTerminar: () {},
        ),
        sport: true,
      );
      expect(
        etiquetasAccesibles(tester),
        contains('Cronómetro, en curso: 1 hora 42 minutos'),
      );
      await reloj.avanzar(tester, const Duration(seconds: 5));
      expect(
        etiquetasAccesibles(tester),
        contains('Cronómetro, en curso: 1 hora 42 minutos'),
      );
      handle.dispose();
      await desmontar(tester);
    });

    testWidgets('estados: vacío, cargando, sin conexión y error', (
      tester,
    ) async {
      var reintentos = 0;
      for (final estado in estadosSinContenido) {
        await montarBici(
          tester,
          CronometroSalida(
            salida: null,
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

    for (final escala in EscalaCronometro.values) {
      for (final ancho in [360.0, 900.0]) {
        testWidgets('${escala.name}: letra al 200 % en ${ancho.toInt()} dp '
            'sin desbordes y el número no sale de la pantalla', (tester) async {
          final reloj = RelojBici();
          final desbordes = await recolectarDesbordes(() async {
            await montarBici(
              tester,
              CronometroSalida(
                salida: SalidaCronometrada(
                  inicio: reloj.momento.subtract(
                    const Duration(hours: 12, minutes: 59, seconds: 59),
                  ),
                ),
                ahora: reloj.ahora,
                escala: escala,
                alTerminar: () {},
              ),
              sport: true,
              ancho: ancho,
              letra: 2.0,
            );
          });
          expect(desbordes, isEmpty);
          final numero = tester.getRect(
            find.byKey(const ValueKey('cronometro-tiempo')),
          );
          expect(numero.right, lessThanOrEqualTo(ancho));
          expect(numero.left, greaterThanOrEqualTo(0));
          await desmontar(tester);
        });
      }
    }
  });

  group('HojaRegistroSalida', () {
    HojaRegistroSalida hoja({
      String distancia = '',
      SuperficieSalida? superficie,
      int? esfuerzo,
      ClimaBici? clima,
      bool acompanado = false,
      VoidCallback? alTodo,
      VoidCallback? alGuardar,
      ValueChanged<String>? alDistancia,
      ValueChanged<SuperficieSalida?>? alSuperficie,
      ValueChanged<int?>? alEsfuerzo,
      ValueChanged<ClimaBici?>? alClima,
      ValueChanged<bool>? alAcompanado,
      VoidCallback? alMenos,
      VoidCallback? alMas,
    }) => HojaRegistroSalida(
      fechaTexto: 'Sábado 28 nov',
      horaTexto: '8:00',
      duracionTexto: '4 h 00 min',
      bicicletaTexto: 'Mi bici',
      distanciaTexto: distancia,
      superficie: superficie,
      esfuerzo: esfuerzo,
      clima: clima,
      respuestaClimaTexto: 'Buen día para salir. Cuídate en las calles.',
      acompanado: acompanado,
      alTodoComoPlaneado: alTodo,
      alGuardar: alGuardar,
      alCambiarDistancia: alDistancia,
      alElegirSuperficie: alSuperficie,
      alElegirEsfuerzo: alEsfuerzo,
      alElegirClima: alClima,
      alCambiarAcompanado: alAcompanado,
      alMenosDuracion: alMenos,
      alMasDuracion: alMas,
      alCancelar: () {},
    );

    testWidgets('«Todo como estaba planeado» y Guardar son botones grandes de '
        'un toque', (tester) async {
      var todo = 0;
      var guardar = 0;
      await montarBici(
        tester,
        hoja(alTodo: () => todo++, alGuardar: () => guardar++),
        sport: true,
      );
      final bTodo = find.byKey(const ValueKey('registro-todo-planeado'));
      final bGuardar = find.byKey(const ValueKey('registro-guardar'));
      expect(tester.getSize(bTodo).height, greaterThanOrEqualTo(64));
      expect(tester.getSize(bGuardar).height, greaterThanOrEqualTo(56));
      await tester.tap(bTodo);
      await tester.ensureVisible(bGuardar);
      await tester.tap(bGuardar);
      expect([todo, guardar], [1, 1]);
    });

    testWidgets('la distancia la escribe la persona y la hoja avisa lo que '
        'teclea; dice que no se revisa contra un mapa', (tester) async {
      final escritos = <String>[];
      await montarBici(tester, hoja(alDistancia: escritos.add), sport: true);
      await tester.enterText(
        find.byKey(const ValueKey('registro-distancia')),
        '62,4',
      );
      expect(escritos, ['62,4']);
      expect(
        find.textContaining('GRAVITY no la revisa contra un mapa'),
        findsOneWidget,
      );
      // Es opcional.
      expect(find.textContaining('(opcional)'), findsWidgets);
    });

    testWidgets('el tipo de ruta se elige con un toque y se puede quitar', (
      tester,
    ) async {
      final elegidas = <SuperficieSalida?>[];
      await montarBici(
        tester,
        hoja(superficie: SuperficieSalida.mixta, alSuperficie: elegidas.add),
        sport: true,
      );
      for (final s in SuperficieSalida.values) {
        expect(find.text(s.texto), findsOneWidget);
      }
      await tester.tap(find.text('Calle'));
      await tester.tap(find.text('Mixta'));
      // Tocar la ya elegida la quita.
      expect(elegidas, [SuperficieSalida.calle, null]);
    });

    testWidgets('el esfuerzo va de 1 a 5, con palabra, y no depende del '
        'color', (tester) async {
      final elegidos = <int?>[];
      await montarBici(
        tester,
        hoja(esfuerzo: 3, alEsfuerzo: elegidos.add),
        sport: true,
      );
      expect(find.text('3 de 5: moderado'), findsOneWidget);
      for (var n = 1; n <= 5; n++) {
        final op = find.ancestor(
          of: find.text('$n'),
          matching: find.byType(InkWell),
        );
        expect(tester.getSize(op.first).width, greaterThanOrEqualTo(48));
        expect(tester.getSize(op.first).height, greaterThanOrEqualTo(48));
      }
      await tester.tap(find.text('5'));
      await tester.tap(find.text('3'));
      expect(elegidos, [5, null]);
      // La elegida lleva marca de verificación, no solo color.
      expect(find.byIcon(Icons.check), findsWidgets);
    });

    testWidgets('sin esfuerzo explica la escala sin elegir nada por la '
        'persona', (tester) async {
      await montarBici(tester, hoja(alEsfuerzo: (_) {}), sport: true);
      expect(find.text('1 muy ligero · 5 al límite'), findsOneWidget);
    });

    testWidgets('el clima se elige aquí y muestra su respuesta fija', (
      tester,
    ) async {
      final elegidos = <ClimaBici?>[];
      await montarBici(
        tester,
        hoja(clima: ClimaBici.despejado, alClima: elegidos.add),
        sport: true,
      );
      expect(find.byKey(const ValueKey('clima-respuesta')), findsOneWidget);
      await tester.tap(find.text('Frío'));
      expect(elegidos, [ClimaBici.frio]);
    });

    testWidgets('«Salí acompañado» no identifica a nadie y mide 48 dp', (
      tester,
    ) async {
      final valores = <bool>[];
      await montarBici(tester, hoja(alAcompanado: valores.add), sport: true);
      final fila = find.ancestor(
        of: find.text('Salí acompañado: no'),
        matching: find.byType(InkWell),
      );
      expect(tester.getSize(fila.first).height, greaterThanOrEqualTo(48));
      await tester.tap(find.text('Salí acompañado: no'));
      expect(valores, [true]);
    });

    testWidgets('la duración se ajusta con − y + de 56 dp', (tester) async {
      var menos = 0;
      var mas = 0;
      await montarBici(
        tester,
        hoja(alMenos: () => menos++, alMas: () => mas++),
        sport: true,
      );
      final handle = tester.ensureSemantics();
      final bMenos = find.bySemanticsLabel('Quitar 15 minutos');
      final bMas = find.bySemanticsLabel('Agregar 15 minutos');
      expect(tester.getSize(bMenos).height, greaterThanOrEqualTo(56));
      await tester.tap(bMenos);
      await tester.tap(bMas);
      expect([menos, mas], [1, 1]);
      handle.dispose();
    });

    testWidgets('estados: vacío, cargando, sin conexión y error', (
      tester,
    ) async {
      var reintentos = 0;
      for (final estado in estadosSinContenido) {
        await montarBici(
          tester,
          HojaRegistroSalida(
            fechaTexto: 'Sábado',
            horaTexto: '8:00',
            duracionTexto: '4 h',
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
            hoja(
              distancia: '62,4',
              superficie: SuperficieSalida.mixta,
              esfuerzo: 3,
              clima: ClimaBici.lluvia,
              alTodo: () {},
              alGuardar: () {},
              alDistancia: (_) {},
              alSuperficie: (_) {},
              alEsfuerzo: (_) {},
              alClima: (_) {},
              alAcompanado: (_) {},
              alMenos: () {},
              alMas: () {},
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
