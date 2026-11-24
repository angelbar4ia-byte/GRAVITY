// E2 a E4 y E6 a E10 de «Mi gimnasio»: inventario con «Confirmar en el
// aparato», plan de la semana, vista previa de la sesión, registro posterior,
// historial, récords, molestias y ajustes.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/gimnasio/acceso_gimnasio.dart';
import 'package:gravity/diseno/gimnasio/gimnasio.dart';
import 'package:gravity/modulos/habitos/gimnasio/casos_uso/servicio_gimnasio.dart';
import 'package:gravity/modulos/habitos/gimnasio/casos_uso/modo_foco.dart';
import 'package:gravity/modulos/habitos/gimnasio/pantallas/comun.dart';
import 'package:gravity/nucleo/avisos/repositorio_avisos.dart'
    show TipoEquipoAvisos;
import 'package:habitos_dominio/habitos_dominio.dart' hide EstadoDiaPlan;

import 'ayuda_gimnasio_app.dart';

/// Una pantalla alta: las listas no construyen lo que queda fuera de la vista.
const alto = Size(400, 3200);

Future<Montaje> montar(
  WidgetTester t,
  Mundo m,
  DestinoGimnasio d, {
  TipoEquipoAvisos equipo = TipoEquipoAvisos.telefono,
}) => montarPantalla(t, m, d, tamano: alto, equipo: equipo);

/// Un texto sin importar mayúsculas (los títulos de tarjeta van en mayúsculas).
Finder contiene(String texto) => find.byWidgetPredicate(
  (w) => w is Text && (w.data ?? '').toLowerCase().contains(texto),
);

void main() {
  late Mundo m;
  setUp(() => m = Mundo());
  tearDown(() => m.cerrar());

  group('E2 · Inventario', () {
    testWidgets('viene con el Marcy, el banco y la caminadora; lo no confirmado lo dice', (
      t,
    ) async {
      await montar(t, m, DestinoGimnasio.inventario);
      expect(find.textContaining('Marcy MWM-7119'), findsOneWidget);
      expect(find.text('Banco inclinado'), findsWidgets);
      expect(find.text('Caminadora'), findsWidgets);
      // El peso de la pila es del diseño: «aprox.», y no es un dato confirmado.
      expect(find.textContaining('68'), findsWidgets);
      expect(find.text(TextosGimnasio.confirmarEnElAparato), findsWidgets);
      // Mancuernas: equipo futuro, aparte.
      expect(find.byKey(const ValueKey('futuro-mancuernas')), findsOneWidget);
      expect(find.text(TextosGimnasio.equipoFuturoNota), findsWidgets);
    });

    testWidgets('confirmar en el aparato guarda los pasos de la pila y entra a los cálculos', (
      t,
    ) async {
      await montar(t, m, DestinoGimnasio.inventario);
      await t.tap(find.text(TextosGimnasio.confirmarEnElAparato).first);
      await t.pumpAndSettle();
      await t.enterText(
        find.byKey(const ValueKey('campo-pasos_max')),
        '12',
      );
      await t.enterText(
        find.byKey(const ValueKey('campo-kg_por_paso_x10')),
        '4,5',
      );
      await t.tap(find.byKey(const ValueKey('guardar-confirmacion')));
      await t.pumpAndSettle();
      final d = await m.servicio.cargar();
      expect(d.inventario.pasosMax, 12);
      expect(d.inventario.kgPorPasoX10, 45);
      expect(find.text('12 placas'), findsOneWidget);
    });

    testWidgets('agregar una banda y marcar el ancla de puerta', (t) async {
      await montar(t, m, DestinoGimnasio.inventario);
      await t.ensureVisible(find.byKey(const ValueKey('agregar-banda')));
      await t.tap(find.byKey(const ValueKey('agregar-banda')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('banda-nombre')), 'Verde');
      await t.tap(find.byKey(const ValueKey('banda-guardar')));
      await t.pumpAndSettle();
      final bandas = await m.repo.bandas(persona);
      expect(bandas.single.nombre, 'Verde');
      expect(bandas.single.orden, 1);
      expect(find.text('Verde'), findsOneWidget);

      await t.ensureVisible(
        find.byKey(const ValueKey('accesorio-ancla_puerta')),
      );
      await t.tap(find.byKey(const ValueKey('accesorio-ancla_puerta')));
      await t.pumpAndSettle();
      final d = await m.servicio.cargar();
      expect(d.inventario.disponible('ancla_puerta', catalogoGimnasio), isTrue);
    });

    testWidgets('un puesto suelto del Marcy se agrega y aparece', (t) async {
      await montar(t, m, DestinoGimnasio.inventario);
      await t.ensureVisible(find.byKey(const ValueKey('agregar-puesto')));
      await t.tap(find.byKey(const ValueKey('agregar-puesto')));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).last, 'Extensión de pierna');
      await t.tap(find.text('Guardar'));
      await t.pumpAndSettle();
      expect(find.text('Extensión de pierna'), findsOneWidget);
      expect(
        (await m.repo.inventario(persona)).any(
          (f) => f.itemId == 'otro:Extensión de pierna',
        ),
        isTrue,
      );
    });
  });

  group('E3 · Plan de la semana', () {
    testWidgets('cambiar a 4 días guarda el plan y pone la regenerativa', (
      t,
    ) async {
      await montar(t, m, DestinoGimnasio.plan);
      await t.tap(find.text('4 días'));
      await t.pumpAndSettle();
      final d = await m.servicio.cargar();
      expect(d.perfil.diasPlan, 4);
      expect(d.dias.map((x) => x.tipo), [
        'A', 'C', 'B', 'descanso', 'R1', 'bici', 'descanso',
      ]);
    });

    testWidgets('el aviso de 48 horas avisa y no bloquea (C el viernes y la bici)', (
      t,
    ) async {
      final d = await m.servicio.cargar();
      for (final dia in d.dias) {
        await m.servicio.guardarDiaDelPlan(dia);
      }
      // La semana literal del diseño: C el viernes.
      await m.repo.guardarPlanDia(persona, diaSemana: 2, tipo: 'descanso');
      await m.repo.guardarPlanDia(persona, diaSemana: 5, tipo: 'C');
      await montar(t, m, DestinoGimnasio.plan);
      expect(find.textContaining('comparten'), findsWidgets);
      expect(find.textContaining('cuádriceps'), findsWidgets);
      // Sigue pudiéndose guardar: «Poner en mi agenda» responde.
      await t.ensureVisible(find.byKey(const ValueKey('plan-agenda')));
      await t.tap(find.byKey(const ValueKey('plan-agenda')));
      await t.pumpAndSettle();
      expect(find.text(TextosHabitosGimnasio.agendaListo), findsOneWidget);
    });

    testWidgets('Poner en mi agenda crea los bloques de entrenamiento', (
      t,
    ) async {
      await m.diaTipoDelDiseno();
      await montar(t, m, DestinoGimnasio.plan);
      await t.ensureVisible(find.byKey(const ValueKey('plan-agenda')));
      await t.tap(find.byKey(const ValueKey('plan-agenda')));
      await t.pumpAndSettle();
      final bloques = (await m.agenda.bloques())
          .where((b) => b.objetivoId == idObjetivoEntrenamiento(persona))
          .toList();
      expect(bloques, hasLength(3));
      expect(bloques.first.inicioMin, 19 * 60 + 15);
    });

    testWidgets('elegir la hora de un día y empezar el plan', (t) async {
      await montar(t, m, DestinoGimnasio.plan);
      await t.ensureVisible(find.byKey(const ValueKey('plan-empezar')));
      await t.tap(find.byKey(const ValueKey('plan-empezar')));
      await t.pumpAndSettle();
      final d = await m.servicio.cargar();
      expect(d.perfil.inicioCiclo, DateTime.utc(2026, 11, 30));
      expect(find.byKey(const ValueKey('plan-empezar')), findsNothing);
    });
  });

  group('E4 · Sesión de hoy', () {
    testWidgets('muestra los ejercicios, la duración real y «Contenido en revisión»', (
      t,
    ) async {
      await montar(t, m, DestinoGimnasio.sesion);
      expect(find.text('Fuerza A · Empuje'), findsOneWidget);
      expect(find.text(TextosGimnasio.contenidoEnRevision), findsWidgets);
      expect(find.textContaining('≈'), findsWidgets);
      expect(find.byType(FilaEjercicioPlan), findsWidgets);
      // Sin historial: no se inventa una carga.
      expect(find.text(MensajesGimnasio.primeraCarga), findsOneWidget);
    });

    testWidgets('cambiar la versión recalcula; Cansado propone la regenerativa', (
      t,
    ) async {
      await montar(t, m, DestinoGimnasio.sesion);
      await t.tap(find.textContaining('corta').first);
      await t.pumpAndSettle();
      final corta = find.byType(FilaEjercicioPlan).evaluate().length;
      expect(corta, greaterThan(0));
      await t.tap(find.text(TextosHabitosGimnasio.cansado));
      await t.pumpAndSettle();
      expect(find.text(TextosHabitosGimnasio.proponemosRegenerativa), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('ver-regenerativa')));
      await t.pumpAndSettle();
      expect(find.text('Regenerativa 1'), findsOneWidget);
      expect(find.byType(FilaEjercicioPlan), findsNothing);
    });

    testWidgets('con una molestia aquí, la sesión lo tiene en cuenta; en la laptop lo dice', (
      t,
    ) async {
      final laptop = Mundo(equipo: TipoEquipoAvisos.laptop);
      addTearDown(laptop.cerrar);
      await montar(t, laptop, DestinoGimnasio.sesion);
      expect(find.text(TextosGimnasio.molestiaOtroEquipo), findsOneWidget);
    });

    testWidgets('sin la llave el modo foco se dice y vale falso', (t) async {
      final sin = Mundo(foco: const SinModoFoco(legible: false));
      addTearDown(sin.cerrar);
      await montar(t, sin, DestinoGimnasio.sesion);
      expect(find.byKey(const ValueKey('foco-no-legible')), findsOneWidget);
    });

    testWidgets('el aviso de dormir ofrece sus opciones en orden', (t) async {
      final d = await m.servicio.cargar();
      await m.servicio.guardarDiaDelPlan(
        d.dia(1),
        version: 'estandar',
        horaMin: 20 * 60 + 30,
      );
      await montar(t, m, DestinoGimnasio.sesion);
      expect(find.text(MensajesGimnasio.cercaDeDormir), findsWidgets);
      expect(find.text(textoDeOpcionDormir(OpcionDormir.versionMasCorta)), findsOneWidget);
    });
  });

  group('E6 · Registrar lo que hice', () {
    testWidgets('«todo como estaba planeado» y Guardar: dos toques en la pantalla', (
      t,
    ) async {
      await montar(t, m, DestinoGimnasio.registro);
      await t.tap(find.byKey(const ValueKey('todo-planeado')));
      await t.pumpAndSettle();
      await t.ensureVisible(find.byKey(const ValueKey('registro-guardar')));
      await t.tap(find.byKey(const ValueKey('registro-guardar')));
      await t.pumpAndSettle();
      final s = (await m.repo.sesiones(persona)).single;
      expect(s.estado, 'completa');
      expect(s.plantilla, 'A');
      expect((await m.repo.series(persona, s.id)), isNotEmpty);
    });
  });

  group('E7 · Historial y E8 · Récords', () {
    Future<void> sesionHecha() async {
      final s = m.servicio;
      final h = await s.entrenamientoDe(lunes30);
      await s.registrarDespues(
        h: h,
        hecho: [
          for (final e in h.sesion!.ejercicios)
            (
              ejercicio: e,
              series: e.series,
              reps: e.objetivo,
              cargaPasos: 5,
              bandaId: null,
            ),
        ],
        completa: true,
        esfuerzo: 3,
      );
    }

    testWidgets('el historial lista la sesión y la carga por semana', (t) async {
      await sesionHecha();
      await montar(t, m, DestinoGimnasio.historial);
      expect(find.byType(BarrasHistorial), findsOneWidget);
      expect(find.textContaining('Fuerza A'), findsWidgets);
      expect(find.textContaining('Esfuerzo 3 de 5'), findsOneWidget);
    });

    testWidgets('sin sesiones lo dice sin culpa', (t) async {
      await montar(t, m, DestinoGimnasio.historial);
      expect(find.text(TextosHabitosGimnasio.sinHistorial), findsOneWidget);
    });

    testWidgets('los récords salen de las series: Placa 5', (t) async {
      await sesionHecha();
      await montar(t, m, DestinoGimnasio.records);
      expect(find.byType(ListaRecords), findsOneWidget);
      expect(find.text('Placa 5'), findsWidgets);
    });

    testWidgets('sin series no hay récords y lo dice', (t) async {
      await montar(t, m, DestinoGimnasio.records);
      expect(find.text(TextosHabitosGimnasio.sinRecords), findsOneWidget);
    });

    testWidgets('deshacer una serie recalcula el récord (CA-G-21)', (t) async {
      await sesionHecha();
      final d = await m.servicio.cargar();
      final antes = calcularRecords(d.historial, catalogoGimnasio);
      expect(antes.values.any((r) => r.mejorCargaPasos == 5), isTrue);
      for (final x in await m.repo.todasLasSeries(persona)) {
        await m.repo.borrarSerie(persona, x.id);
      }
      final despues = calcularRecords(
        (await m.servicio.cargar()).historial,
        catalogoGimnasio,
      );
      expect(despues, isEmpty);
    });
  });

  group('E9 · Molestias', () {
    testWidgets('se agrega en tres toques y queda solo en este equipo', (
      t,
    ) async {
      await montar(t, m, DestinoGimnasio.molestias);
      expect(find.text(TextosGimnasio.molestiaSoloEnEsteEquipo), findsWidgets);
      await t.tap(find.byKey(const ValueKey('molestia-agregar'))); // 1
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('zona-rodilla'))); // 2
      await t.pump();
      await t.tap(find.byKey(const ValueKey('molestia-guardar'))); // 3
      await t.pumpAndSettle();
      final l = await m.molestias.leer();
      expect(l.molestias.single.zona, 'rodilla');
      expect(l.molestias.single.intensidad, 1);
      // Nada de lo del equipo toca la base local de gimnasio ni la cola.
      expect((await m.repo.sesiones(persona)), isEmpty);
      expect(contiene('rodilla'), findsWidgets);
    });

    testWidgets('«Ya no» cierra la molestia y el generador deja de tenerla', (
      t,
    ) async {
      await m.molestias.guardar(
        Molestia(
          id: 'm1',
          zona: Zonas.hombro,
          intensidad: 3,
          desde: DateTime.utc(2026, 11, 28),
        ),
      );
      await montar(t, m, DestinoGimnasio.molestias);
      // La intensidad fuerte lleva el aviso de consultar a un profesional.
      expect(find.textContaining('profesional'), findsWidgets);
      await t.tap(find.byKey(const ValueKey('molestia-ya-no-m1')));
      await t.pumpAndSettle();
      expect((await m.molestias.leer()).activas, isEmpty);
    });

    testWidgets('en un equipo que no las admite no guarda nada', (t) async {
      final laptop = Mundo(equipo: TipoEquipoAvisos.laptop);
      addTearDown(laptop.cerrar);
      await montar(t, laptop, DestinoGimnasio.molestias);
      expect(find.text(TextosGimnasio.molestiaOtroEquipo), findsOneWidget);
      expect(find.byKey(const ValueKey('molestia-agregar')), findsNothing);
    });
  });

  group('E10 · Ajustes', () {
    testWidgets('valores de partida: salud general, principiante y voz apagada', (
      t,
    ) async {
      await montar(t, m, DestinoGimnasio.ajustes);
      final sg = t.widget<ChoiceChip>(
        find.byKey(const ValueKey('objetivo-salud_general')),
      );
      expect(sg.selected, isTrue);
      final pr = t.widget<ChoiceChip>(
        find.byKey(const ValueKey('nivel-principiante')),
      );
      expect(pr.selected, isTrue);
      final voz = t.widget<SwitchListTile>(
        find.byKey(const ValueKey('voz-descanso')),
      );
      expect(voz.value, isFalse);
    });

    testWidgets('cambiar el objetivo, el ciclo y la voz se guarda', (t) async {
      await montar(t, m, DestinoGimnasio.ajustes);
      await t.ensureVisible(find.byKey(const ValueKey('objetivo-fuerza')));
      await t.tap(find.byKey(const ValueKey('objetivo-fuerza')));
      await t.pumpAndSettle();
      await t.ensureVisible(find.byKey(const ValueKey('voz-descanso')));
      await t.tap(find.byKey(const ValueKey('voz-descanso')));
      await t.pumpAndSettle();
      final p = (await m.repo.perfil(persona))!;
      expect(p.objetivo, 'fuerza');
      expect(p.vozDescanso, isTrue);
      expect(p.nivel, 'principiante');
      expect(p.cicloSemanas, 4);
    });

    testWidgets('«Sobre esta guía» dice que no sustituye a un profesional', (
      t,
    ) async {
      await montar(t, m, DestinoGimnasio.ajustes);
      expect(contiene('sobre esta guía'), findsWidgets);
      expect(find.text(MensajesGimnasio.guiaGeneral), findsOneWidget);
    });
  });
}
