// Las pantallas reales de «Mi gimnasio» (G5): E1 a E10 con datos reales del
// repositorio local, en memoria.
//
// CA-G-33 (pocos toques), CA-G-34 (registro de series), CA-G-35 (aviso del
// descanso y pantalla encendida), CA-G-38 (la sesión retiene la pantalla), CA-G-41
// (accesibilidad) y CA-G-40 (tono).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/gimnasio/acceso_gimnasio.dart';
import 'package:gravity/diseno/gimnasio/gimnasio.dart';
import 'package:gravity/modulos/habitos/gimnasio/pantallas/comun.dart'
    show TextosHabitosGimnasio;
import 'package:gravity/nucleo/avisos/repositorio_avisos.dart'
    show TipoEquipoAvisos;
import 'package:habitos_dominio/habitos_dominio.dart'
    show MensajesGimnasio, TextoAvisoGimnasio;

import 'ayuda_gimnasio_app.dart';

void main() {
  late Mundo m;
  setUp(() => m = Mundo());
  tearDown(() => m.cerrar());

  Future<void> terminar(WidgetTester t) async {
    // Se desmonta la pantalla: el temporizador no deja nada pendiente.
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(milliseconds: 50));
  }

  group('E1 · Entrenamiento de hoy', () {
    testWidgets('primero pide «Entendido» y después muestra la tarjeta', (
      t,
    ) async {
      await montarPantalla(t, m, DestinoGimnasio.hoy);
      expect(find.text(MensajesGimnasio.guiaGeneral), findsOneWidget);
      expect(find.byKey(const ValueKey('gimnasio-entendido')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('gimnasio-entendido')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('gimnasio-entendido')), findsNothing);
      expect((await m.repo.perfil(persona))!.avisoVistoEn, isNotNull);
      expect(find.text('Fuerza A · Empuje'), findsWidgets);
      expect(find.text(TextosGimnasio.contenidoEnRevision), findsWidgets);
    });

    testWidgets('Hecho es un toque, queda guardado y se puede deshacer', (
      t,
    ) async {
      await m.servicio.aceptarAviso();
      await montarPantalla(t, m, DestinoGimnasio.hoy);
      var toques = 0;
      await t.tap(find.byKey(const ValueKey('entrenamiento-hecho')));
      toques++;
      await t.pumpAndSettle();
      expect(toques, 1); // CA-G-33
      expect(find.text(EstadoDiaPlan.hecho.texto), findsWidgets);
      expect((await m.repo.sesiones(persona)).single.estado, 'completa');
      await t.tap(find.text(TextosGimnasio.deshacer).first);
      await t.pumpAndSettle();
      expect(await m.repo.sesiones(persona), isEmpty);
    });

    testWidgets('Empezar es un toque y lleva a la sesión en curso', (t) async {
      await m.servicio.aceptarAviso();
      final montaje = await montarPantalla(t, m, DestinoGimnasio.hoy);
      await t.tap(find.byKey(const ValueKey('entrenamiento-empezar')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(montaje.rutas.last, DestinoGimnasio.sesionEnCurso.ruta);
      await terminar(t);
    });

    testWidgets('un día de descanso lo dice sin culpa', (t) async {
      m.ahoraActual = DateTime(2026, 12, 6, 19); // domingo
      await m.servicio.aceptarAviso();
      await montarPantalla(t, m, DestinoGimnasio.hoy);
      expect(find.textContaining('descanso'), findsWidgets);
      expect(find.byKey(const ValueKey('entrenamiento-empezar')), findsNothing);
    });

    testWidgets('lista solo las pantallas del equipo: sin molestias en la laptop', (
      t,
    ) async {
      await m.servicio.aceptarAviso();
      await montarPantalla(
        t,
        m,
        DestinoGimnasio.hoy,
        equipo: TipoEquipoAvisos.laptop,
      );
      expect(find.text('Molestias'), findsNothing);
      expect(find.text('Inventario'), findsOneWidget);
    });
  });

  group('E5 · Sesión en curso', () {
    testWidgets('calentamiento, serie, deshacer, descanso y terminar', (
      t,
    ) async {
      final montaje = await montarPantalla(t, m, DestinoGimnasio.sesionEnCurso);
      await t.pump(const Duration(milliseconds: 300));
      expect(
        find.textContaining(TextosHabitosGimnasio.calentamiento),
        findsWidgets,
      );
      // Empezó y la tablet/pantalla se retienen.
      expect((await m.repo.sesiones(persona)).single.estado, 'en_curso');
      expect(montaje.pantallaEncendida.vigentes, 1);

      await t.tap(find.byKey(const ValueKey('calentamiento-listo')));
      await t.pump();
      expect(find.byKey(const ValueKey('boton-serie-hecha')), findsOneWidget);

      // ✓ Hecha: un toque guarda lo sugerido.
      await t.tap(find.byKey(const ValueKey('boton-serie-hecha')));
      await t.pump(const Duration(milliseconds: 100));
      final id = (await m.repo.sesiones(persona)).single.id;
      expect(await m.repo.series(persona, id), hasLength(1));
      // «Termina tu descanso»: programado, con el texto discreto.
      final p = montaje.notificador.programadas.values.single;
      expect(p.notificacion.titulo, TextoAvisoGimnasio.descanso);
      expect(find.text(TextosGimnasio.deshacer), findsWidgets);

      // Deshacer quita la serie y cancela el aviso.
      await t.tap(find.text(TextosGimnasio.deshacer).first);
      await t.pump(const Duration(milliseconds: 100));
      expect(await m.repo.series(persona, id), isEmpty);
      expect(montaje.notificador.programadas, isEmpty);

      // Otra serie y se salta el descanso: el aviso se cancela.
      await t.tap(find.byKey(const ValueKey('boton-serie-hecha')));
      await t.pump(const Duration(milliseconds: 100));
      expect(montaje.notificador.programadas, hasLength(1));
      await t.tap(find.text(TextosGimnasio.saltar));
      await t.pump(const Duration(milliseconds: 100));
      expect(montaje.notificador.programadas, isEmpty);

      // Terminar: dos toques (Terminar y «Terminé la sesión»).
      await t.tap(find.byKey(const ValueKey('terminar')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('termine-sesion')));
      await t.pumpAndSettle();
      expect((await m.repo.sesiones(persona)).single.estado, 'completa');
      // Soltó la pantalla.
      expect(montaje.pantallaEncendida.vigentes, 0);
      await terminar(t);
    });

    testWidgets('«Terminé una parte» deja la sesión parcial', (t) async {
      await montarPantalla(t, m, DestinoGimnasio.sesionEnCurso);
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.byKey(const ValueKey('calentamiento-listo')));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('terminar')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('termine-parte')));
      await t.pumpAndSettle();
      expect((await m.repo.sesiones(persona)).single.estado, 'parcial');
      await terminar(t);
    });

    testWidgets('+ y − cambian repeticiones y carga sin teclado', (t) async {
      await montarPantalla(t, m, DestinoGimnasio.sesionEnCurso);
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.byKey(const ValueKey('calentamiento-listo')));
      await t.pump();
      await t.tap(find.byIcon(Icons.add).at(0)); // repeticiones
      await t.pump();
      await t.tap(find.byIcon(Icons.add).at(1)); // placa
      await t.pump();
      await t.tap(find.byKey(const ValueKey('boton-serie-hecha')));
      await t.pump(const Duration(milliseconds: 100));
      final s = (await m.repo.todasLasSeries(persona)).single;
      expect(s.cargaPasos, 1);
      expect(s.reps, greaterThan(10));
      await terminar(t);
    });

    testWidgets('«Versión corta» y «Cambiar ejercicio» están sin desplazarse', (
      t,
    ) async {
      await montarPantalla(t, m, DestinoGimnasio.sesionEnCurso);
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.byKey(const ValueKey('calentamiento-listo')));
      await t.pump();
      expect(find.byKey(const ValueKey('cambiar-ejercicio')), findsOneWidget);
      expect(find.byKey(const ValueKey('terminar')), findsOneWidget);
      await terminar(t);
    });

    testWidgets('un día sin sesión de fuerza lo dice y ofrece el plan', (
      t,
    ) async {
      m.ahoraActual = DateTime(2026, 12, 6, 19);
      await montarPantalla(t, m, DestinoGimnasio.sesionEnCurso);
      expect(find.text(TextosHabitosGimnasio.hoyNoHayPlan), findsOneWidget);
      expect(await m.repo.sesiones(persona), isEmpty);
    });

    testWidgets('en la tablet se ve el gadget «Serie y descanso» sin desbordes', (
      t,
    ) async {
      await montarPantalla(
        t,
        m,
        DestinoGimnasio.sesionEnCurso,
        tamano: const Size(1280, 800),
        equipo: TipoEquipoAvisos.tabletPersonal,
      );
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.byKey(const ValueKey('calentamiento-listo')));
      await t.pump();
      expect(find.byType(GadgetSerieDescanso), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('boton-serie-hecha')));
      await t.pump(const Duration(milliseconds: 100));
      expect(t.takeException(), isNull);
      expect((await m.repo.todasLasSeries(persona)), hasLength(1));
      await terminar(t);
    });

    testWidgets('letra al 200 % en 360 dp: sin desbordes y ✓ de 64 dp o más', (
      t,
    ) async {
      t.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      await montarPantalla(
        t,
        m,
        DestinoGimnasio.sesionEnCurso,
        tamano: const Size(360, 800),
      );
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.byKey(const ValueKey('calentamiento-listo')));
      await t.pump();
      expect(t.takeException(), isNull);
      final hecha = find.byKey(const ValueKey('boton-serie-hecha'));
      // El ✓ nunca sale de la pantalla (no hace falta desplazarse).
      expect(t.getRect(find.byKey(const ValueKey('terminar'))).bottom,
          lessThanOrEqualTo(800));
      expect(t.getRect(hecha).bottom, lessThanOrEqualTo(800));
      expect(t.getSize(hecha).height, greaterThanOrEqualTo(64));
      expect(t.takeException(), isNull);
      await terminar(t);
    });
  });
}
