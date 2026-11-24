// Casos de uso de «Mi gimnasio» (G5): el estado sale del repositorio local, se
// calcula con el dominio y lo hecho se guarda primero en el equipo.
//
// CA-G-33 (toques), CA-G-34 (registro de series), CA-G-37 (agenda), CA-G-43
// (modo foco) y la parte de sesión de CA-G-32 (el mismo id al reintentar).
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/habitos/datos/modelos.dart';
import 'package:gravity/modulos/habitos/datos/modelos_agenda.dart';
import 'package:gravity/nucleo/gimnasio/repositorio_gimnasio.dart';
import 'package:gravity/modulos/habitos/gimnasio/casos_uso/controlador_sesion.dart';
import 'package:gravity/modulos/habitos/gimnasio/casos_uso/modo_foco.dart';
import 'package:gravity/modulos/habitos/gimnasio/casos_uso/servicio_gimnasio.dart';
import 'package:gravity/diseno/gimnasio/gimnasio.dart' show EstadoDiaPlan;
import 'package:gravity/modulos/habitos/gimnasio/datos/modelos_gimnasio.dart';
import 'package:gravity/modulos/habitos/gimnasio/pantallas/hoy_gimnasio.dart' show diasDeLaSemana;
import 'package:gravity/nucleo/avisos/repositorio_avisos.dart' show TipoEquipoAvisos;
import 'package:gravity/nucleo/gimnasio/ids_gimnasio.dart';
import 'package:habitos_dominio/habitos_dominio.dart' hide EstadoDiaPlan;

import 'ayuda_gimnasio_app.dart';

void main() {
  late Mundo m;
  setUp(() => m = Mundo());
  tearDown(() => m.cerrar());

  group('lo de hoy', () {
    test('lunes toca A con el plan por omisión; todo sale «en revisión»', () async {
      final h = await m.servicio.entrenamientoDe(lunes30);
      expect(h.tipo, 'A');
      expect(h.esFuerza, isTrue);
      expect(h.estado, EstadoEntrenamientoDia.pendiente);
      expect(h.contenidoEnRevision, isTrue); // CA-G-45: borrador
      expect(h.sesion!.ejercicios, hasLength(greaterThanOrEqualTo(3)));
    });

    test('el plan por omisión es la semana reordenada del dueño', () async {
      final d = await m.servicio.cargar();
      expect(d.dias.map((x) => x.tipo), [
        'A', 'C', 'B', 'descanso', 'descanso', 'bici', 'descanso',
      ]);
    });

    test('sin hueco en la agenda propone con el hueco libre del día', () async {
      await m.diaTipoDelDiseno();
      final h = await m.servicio.entrenamientoDe(lunes30);
      // Llega ~19:00; 15 minutos para cambiarse (CA-G-37).
      expect(h.inicioMin, 19 * 60 + 15);
      // Con 22:00 de dormir cabe la más larga (A larga ≈ 61 min + 10).
      expect(h.version, VersionSesion.larga);
    });

    test('sábado es bicicleta y domingo descanso: no hay sesión', () async {
      final sab = await m.servicio.entrenamientoDe(DateTime(2026, 12, 5));
      expect(sab.tipo, 'bici');
      expect(sab.esSesion, isFalse);
      final dom = await m.servicio.entrenamientoDe(DateTime(2026, 12, 6));
      expect(dom.tipo, 'descanso');
    });

    test('un día sin hueco avisa que no cabe y no inventa una cuarta versión', () async {
      await m.diaTipoDelDiseno();
      // Se ocupa la noche hasta casi dormir.
      await m.agenda.guardarBloque(
        BloqueHab(
          id: 'cena',
          titulo: 'Cena familiar',
          area: 'personal',
          inicioMin: 19 * 60,
          duracionMin: 170,
          dias: 1,
          desde: DateTime.utc(2026, 11, 1),
          modificadoEn: DateTime.utc(2026, 11, 1),
        ),
      );
      final h = await m.servicio.entrenamientoDe(lunes30);
      expect(h.noCabe, isTrue);
      expect(avisosDeLaSesion(h), contains(MensajesGimnasio.noCabe));
    });

    test('aviso de cercanía a dormir con la hora del plan tarde (CA-G-24)', () async {
      await m.servicio.cargar();
      final d = await m.servicio.cargar();
      await m.servicio.guardarDiaDelPlan(
        d.dia(1),
        version: 'estandar',
        horaMin: 20 * 60 + 30,
      );
      final h = await m.servicio.entrenamientoDe(lunes30);
      expect(h.inicioMin, 20 * 60 + 30);
      expect(h.avisoDormir, isNotNull); // termina ~21:06; dormir 22:00
      expect(h.avisoDormir!.opciones.first, OpcionDormir.versionMasCorta);
    });

    test('una hora más temprana no avisa', () async {
      final d = await m.servicio.cargar();
      await m.servicio.guardarDiaDelPlan(
        d.dia(1),
        version: 'estandar',
        horaMin: 19 * 60 + 15,
      );
      final h = await m.servicio.entrenamientoDe(lunes30);
      expect(h.avisoDormir, isNull);
    });
  });

  group('inventario (CA-G-04)', () {
    test('mientras no se confirma, la carga va en placas y sin tope', () async {
      var d = await m.servicio.cargar();
      expect(d.inventario.pasosMax, isNull);
      expect(d.inventario.enTopeDePila(60), isFalse);
      await m.servicio.confirmarDato(d, 'pasos_max', 12);
      await m.servicio.confirmarDato(d, 'kg_por_paso_x10', 45);
      d = await m.servicio.cargar();
      expect(d.inventario.pasosMax, 12);
      expect(d.inventario.kgPorPasoX10, 45);
      expect(d.inventario.enTopeDePila(12), isTrue);
      await m.servicio.olvidarDato(d, 'pasos_max');
      d = await m.servicio.cargar();
      expect(d.inventario.pasosMax, isNull);
      // Lo demás queda.
      expect(d.inventario.kgPorPasoX10, 45);
    });

    test('un dato que no es del aparato no se guarda', () async {
      final d = await m.servicio.cargar();
      expect(
        () => m.servicio.confirmarDato(d, 'otra_cosa', 3),
        throwsArgumentError,
      );
    });

    test('un puesto marcado no disponible cambia la sesión a banda', () async {
      var d = await m.servicio.cargar();
      await m.servicio.guardarBanda(d, nombre: 'Verde');
      await m.servicio.guardarEstadoItem(
        d,
        'marcy.press',
        EstadoItem.noDisponible,
      );
      d = await m.servicio.cargar();
      final h = await m.servicio.entrenamientoDe(lunes30, datos: d);
      final primero = h.sesion!.ejercicios.first;
      // Sin el press, el slot A1 no usa la variante de la estación.
      expect(primero.varianteId, isNot('press_pecho_estacion'));
    });

    test('equipo futuro no genera nada (CA-G-09)', () async {
      var d = await m.servicio.cargar();
      final antes = (await m.servicio.entrenamientoDe(lunes30, datos: d))
          .sesion!
          .ejercicios
          .map((e) => e.varianteId)
          .toList();
      await m.servicio.guardarEstadoItem(d, 'mancuernas', EstadoItem.futuro);
      d = await m.servicio.cargar();
      final despues = (await m.servicio.entrenamientoDe(lunes30, datos: d))
          .sesion!
          .ejercicios
          .map((e) => e.varianteId)
          .toList();
      expect(despues, antes);
      expect(d.inventario.equipoFuturo, contains('mancuernas'));
    });
  });

  group('la sesión (CA-G-33 y CA-G-34)', () {
    Future<(ControladorSesion, EntrenamientoHoy)> abrir() async {
      final s = m.servicio;
      final d = await s.cargar();
      final h = await s.entrenamientoDe(lunes30, datos: d);
      final fila = await s.iniciarSesion(h);
      final c = ControladorSesion(
        servicio: s,
        hoy: h,
        fila: fila,
        datos: d,
        ahora: () => m.ahoraActual,
      );
      await c.inicializar();
      return (c, h);
    }

    test('empezar deja la sesión guardada en curso, con id estable', () async {
      final (c, h) = await abrir();
      expect(c.fila.estado, 'en_curso');
      expect(c.fila.id, IdsGimnasio.sesion(persona, h.fecha, 'A'));
      expect(c.fase, FaseSesion.calentamiento);
      c.listo();
      expect(c.fase, FaseSesion.serie);
      c.dispose();
    });

    test('una serie es un toque con lo sugerido; sin teclado, − y + ajustan', () async {
      final (c, _) = await abrir();
      c.listo();
      final sugeridas = c.reps;
      c.masReps();
      c.masReps();
      expect(c.reps, sugeridas + 2);
      c.menosReps();
      expect(c.reps, sugeridas + 1);
      await c.hecha();
      final filas = await m.repo.series(persona, c.fila.id);
      expect(filas, hasLength(1));
      expect(filas.single.reps, sugeridas + 1);
      expect(filas.single.n, 1);
      // Empezó el descanso con el instante final de la versión.
      expect(c.descanso, isNotNull);
      c.dispose();
    });

    test('deshacer quita la última serie y vuelve a ella', () async {
      final (c, _) = await abrir();
      c.listo();
      await c.hecha();
      await c.hecha();
      expect(c.hechas, hasLength(2));
      await c.deshacer();
      expect(c.hechas, hasLength(1));
      expect(c.serie, 2);
      expect(await m.repo.series(persona, c.fila.id), hasLength(1));
      c.dispose();
    });

    test('guardar la misma serie dos veces no duplica (mismo id v5)', () async {
      final (c, _) = await abrir();
      c.listo();
      await c.hecha();
      final id = c.hechas.single.id;
      final fila = (await m.repo.series(persona, c.fila.id)).single;
      await m.repo.guardarSerie(persona, fila.aMapaServidor());
      expect(await m.repo.series(persona, c.fila.id), hasLength(1));
      expect(
        id,
        IdsGimnasio.serie(persona, c.fila.id, fila.ejercicioId, 1),
      );
      c.dispose();
    });

    test('sin carga previa no sugiere una: la primera serie la fija', () async {
      final (c, _) = await abrir();
      c.listo();
      expect(c.cargaPasos, isNull);
      c.masCarga();
      c.masCarga();
      c.masCarga();
      expect(c.cargaPasos, 3);
      await c.hecha();
      // La segunda serie arranca con la misma carga.
      expect(c.cargaPasos, 3);
      c.dispose();
    });

    test('con el tope de la pila confirmado, no se sube más (CA-G-17)', () async {
      var d = await m.servicio.cargar();
      await m.servicio.confirmarDato(d, 'pasos_max', 2);
      d = await m.servicio.cargar();
      final h = await m.servicio.entrenamientoDe(lunes30, datos: d);
      final fila = await m.servicio.iniciarSesion(h);
      final c = ControladorSesion(
        servicio: m.servicio,
        hoy: h,
        fila: fila,
        datos: d,
        ahora: () => m.ahoraActual,
      );
      await c.inicializar();
      c.listo();
      for (var i = 0; i < 6; i++) {
        c.masCarga();
      }
      expect(c.cargaPasos, 2);
      expect(c.enTope, isTrue);
      c.dispose();
    });

    test('retomar: lo ya hecho se conserva y sigue en la serie que falta', () async {
      final (c, h) = await abrir();
      c.listo();
      await c.hecha();
      await c.hecha();
      final id = c.fila.id;
      c.dispose();
      // «Se cerró la app»: se abre otra vez la misma sesión.
      final d = await m.servicio.cargar();
      final h2 = await m.servicio.entrenamientoDe(lunes30, datos: d);
      expect(h2.estado, EstadoEntrenamientoDia.enCurso);
      final fila = await m.servicio.iniciarSesion(h2);
      expect(fila.id, id);
      final c2 = ControladorSesion(
        servicio: m.servicio,
        hoy: h2,
        fila: fila,
        datos: d,
        ahora: () => m.ahoraActual,
      );
      await c2.inicializar();
      expect(c2.hechas, hasLength(2));
      expect(c2.serie, 3);
      expect(c2.fase, FaseSesion.serie);
      expect(h.tipo, h2.tipo);
      c2.dispose();
    });

    test('terminar la sesión escribe hecho en el bloque y en el objetivo', () async {
      var d = await m.servicio.cargar();
      await m.servicio.ponerEnMiAgenda(d);
      d = await m.servicio.cargar();
      final h = await m.servicio.entrenamientoDe(lunes30, datos: d);
      expect(h.bloque, isNotNull);
      final fila = await m.servicio.iniciarSesion(h);
      final c = ControladorSesion(
        servicio: m.servicio,
        hoy: h,
        fila: fila,
        datos: d,
        ahora: () => m.ahoraActual,
      );
      await c.inicializar();
      c.listo();
      await c.hecha();
      final r = await c.terminar(completa: true, esfuerzo: 3, energia: 4);
      expect(r.estado, EstadoSesion.completa);
      final s = (await m.repo.sesiones(persona)).single;
      expect(s.estado, 'completa');
      expect(s.fin, isNotNull);
      expect(s.esfuerzo, 3);
      final regs = await m.registros.registros(
        DateTime.utc(2026, 11, 30),
        DateTime.utc(2026, 11, 30),
      );
      final delBloque = regs.where((x) => x.bloqueId == h.bloque!.id);
      expect(delBloque.single.estado, EstadoRegistro.hecho);
      expect(delBloque.single.id, idRegistroBloque(h.bloque!.id, h.fecha));
      final delObjetivo = regs.where(
        (x) => x.objetivoId == idObjetivoEntrenamiento(persona),
      );
      expect(delObjetivo.single.estado, EstadoRegistro.hecho);
      c.dispose();
    });

    test('«Terminé una parte» deja el bloque parcial, sin juzgar las series', () async {
      var d = await m.servicio.cargar();
      await m.servicio.ponerEnMiAgenda(d);
      d = await m.servicio.cargar();
      final h = await m.servicio.entrenamientoDe(lunes30, datos: d);
      final fila = await m.servicio.iniciarSesion(h);
      final c = ControladorSesion(
        servicio: m.servicio,
        hoy: h,
        fila: fila,
        datos: d,
        ahora: () => m.ahoraActual,
      );
      await c.inicializar();
      c.listo();
      await c.hecha();
      final r = await c.terminar(completa: false);
      expect(r.estado, EstadoSesion.parcial);
      final regs = await m.registros.registros(
        DateTime.utc(2026, 11, 30),
        DateTime.utc(2026, 11, 30),
      );
      expect(
        regs.firstWhere((x) => x.bloqueId == h.bloque!.id).estado,
        EstadoRegistro.parcial,
      );
      c.dispose();
    });

    test('mide los tiempos de repetición y de cambio para calibrar (5.5)', () async {
      final (c, _) = await abrir();
      c.listo();
      // Serie 1 → 2: 48 s de descanso planeado, la serie tarda ~36 s.
      m.ahoraActual = m.ahoraActual.add(const Duration(seconds: 30));
      await c.hecha();
      m.ahoraActual = m.ahoraActual.add(const Duration(seconds: 61 + 36));
      await c.hecha();
      final t = c.tiemposMedidos;
      expect(t, isNotNull);
      expect(t!.segundosPorRepeticion, inInclusiveRange(1, 20));
      await c.terminar(completa: true);
      final fila = (await m.repo.sesiones(persona)).single;
      expect(fila.tiemposComoMapa, isNotNull);
      c.dispose();
    });

    test('«Versión corta» quita los extras y deja 3 series', () async {
      final s = m.servicio;
      final d = await s.cargar();
      final h = await s.entrenamientoDe(
        lunes30,
        datos: d,
        version: VersionSesion.larga,
      );
      final fila = await s.iniciarSesion(h);
      final c = ControladorSesion(
        servicio: s,
        hoy: h,
        fila: fila,
        datos: d,
        ahora: () => m.ahoraActual,
      );
      await c.inicializar();
      c.listo();
      final antes = c.seriesPlaneadas;
      await c.acortar();
      expect(c.versionCorta, isTrue);
      expect(c.seriesPlaneadas, lessThan(antes));
      expect(c.ejercicios.every((e) => e.series <= 3), isTrue);
      expect((await m.repo.sesiones(persona)).single.version, 'corta');
      c.dispose();
    });

    test('cambiar de ejercicio vale solo para esta sesión', () async {
      final (c, h) = await abrir();
      c.listo();
      final alts = c.actual.alternativas;
      if (alts.isEmpty) return; // con este inventario no hay otra opción
      final original = c.actual.varianteId;
      await c.cambiarEjercicio(alts.first);
      expect(c.actual.varianteId, alts.first.varianteId);
      await c.hecha();
      final fila = (await m.repo.series(persona, c.fila.id)).single;
      expect(fila.varianteId, alts.first.varianteId);
      expect(fila.sustituyeA, original);
      // El servidor nunca ve «molestia»: solo «otra», «preferencia» o
      // «no_disponible» (PG-19).
      expect(fila.motivoCambio, isNot('molestia'));
      // El plan no cambió.
      final de = await m.servicio.entrenamientoDe(lunes30);
      expect(de.sesion!.ejercicios.first.varianteId, original);
      expect(h.tipo, 'A');
      c.dispose();
    });
  });

  group('Hecho en un toque (F-E1)', () {
    test('marcar hecho y deshacer', () async {
      var d = await m.servicio.cargar();
      await m.servicio.ponerEnMiAgenda(d);
      final h = await m.servicio.entrenamientoDe(lunes30);
      await m.servicio.marcarHecho(h);
      var despues = await m.servicio.entrenamientoDe(lunes30);
      expect(despues.estado, EstadoEntrenamientoDia.hecho);
      var conteo = await m.servicio.conteoDeHoy();
      expect(conteo, (total: 1, hechos: 1));

      await m.servicio.deshacerHecho(despues);
      despues = await m.servicio.entrenamientoDe(lunes30);
      expect(despues.estado, EstadoEntrenamientoDia.pendiente);
      conteo = await m.servicio.conteoDeHoy();
      expect(conteo, (total: 1, hechos: 0));
      final regs = await m.registros.registros(
        DateTime.utc(2026, 11, 30),
        DateTime.utc(2026, 11, 30),
      );
      expect(regs.every((x) => x.estado == EstadoRegistro.pendiente), isTrue);
    });

    test('un «Hecho» sin series no cambia la carga sugerida', () async {
      final antes = await m.servicio.entrenamientoDe(lunes30);
      final h = await m.servicio.entrenamientoDe(lunes30);
      await m.servicio.marcarHecho(h);
      final despues = await m.servicio.entrenamientoDe(DateTime(2026, 12, 7));
      expect(
        despues.sesion!.ejercicios.map((e) => e.cargaPasos),
        antes.sesion!.ejercicios.map((e) => e.cargaPasos),
      );
    });
  });

  group('la semana sin culpa', () {
    test('antes de empezar el plan ningún día sale «Saltado»', () async {
      final d = await m.servicio.cargar();
      final miercoles = DateTime.utc(2026, 12, 2);
      final dias = diasDeLaSemana(
        datos: d,
        hoy: miercoles,
        catalogo: catalogoGimnasio,
      );
      expect(dias.every((x) => x.estado != EstadoDiaPlan.saltado), isTrue);
      expect(dias.where((x) => x.esHoy), hasLength(1));
    });

    test('con el plan empezado, un día sin hacer se dice «Saltado», sin más', () async {
      await m.servicio.iniciarPlan(); // lunes 30/nov
      final d = await m.servicio.cargar();
      final dias = diasDeLaSemana(
        datos: d,
        hoy: DateTime.utc(2026, 12, 2),
        catalogo: catalogoGimnasio,
      );
      expect(dias[0].estado, EstadoDiaPlan.saltado); // lunes A
      expect(dias[2].estado, EstadoDiaPlan.pendiente); // hoy, miércoles B
    });

    test('una regenerativa no cuenta para el objetivo «Entrenamiento»', () async {
      final h = await m.servicio.entrenamientoDe(lunes30, tipo: 'R1');
      await m.servicio.marcarHecho(h);
      final regs = await m.registros.registros(
        DateTime.utc(2026, 11, 30),
        DateTime.utc(2026, 11, 30),
      );
      expect(regs.where((r) => r.objetivoId != null), isEmpty);
      expect((await m.repo.sesiones(persona)).single.plantilla, 'R1');
    });
  });

  group('registrar después (F-E3)', () {
    test('«todo como estaba planeado» guarda las series planeadas', () async {
      final ayer = DateTime(2026, 11, 29);
      m.ahoraActual = DateTime(2026, 11, 30, 10);
      // El domingo no toca fuerza: se registra una A.
      final h = await m.servicio.entrenamientoDe(ayer, tipo: 'A');
      final r = await m.servicio.registrarDespues(
        h: h,
        hecho: [
          for (final e in h.sesion!.ejercicios)
            (
              ejercicio: e,
              series: e.series,
              reps: e.objetivo,
              cargaPasos: 4,
              bandaId: null,
            ),
        ],
        completa: true,
        esfuerzo: 3,
      );
      expect(r.estado, EstadoSesion.completa);
      final s = (await m.repo.sesiones(persona)).single;
      expect(s.fecha, '2026-11-29');
      expect(s.inicio.isBefore(s.fin!), isTrue);
      final series = await m.repo.series(persona, s.id);
      expect(
        series.length,
        h.sesion!.ejercicios.fold<int>(0, (a, e) => a + e.series),
      );
    });
  });

  group('agenda (CA-G-37)', () {
    test('el plan propone bloques a las 19:15 con duración = estimada + 10', () async {
      await m.diaTipoDelDiseno();
      final d = await m.servicio.cargar();
      final r = await m.servicio.ponerEnMiAgenda(d);
      expect(r.bloques, 3); // A, C y B (3 días)
      final bloques = (await m.agenda.bloques())
          .where((b) => b.objetivoId == idObjetivoEntrenamiento(persona))
          .toList();
      expect(bloques, hasLength(3));
      for (final b in bloques) {
        expect(b.inicioMin, 19 * 60 + 15);
        expect(b.tipo, 'actividad');
        expect(b.area, 'salud');
      }
      final lunes = bloques.firstWhere((b) => b.dias == 1);
      final h = await m.servicio.entrenamientoDe(lunes30);
      expect(
        lunes.duracionMin,
        (h.sesion!.duracionEstimadaSeg + 59) ~/ 60 + margenBloqueMin,
      );
    });

    test('un conflicto avisa y no impide guardar', () async {
      await m.diaTipoDelDiseno();
      await m.servicio.guardarDiaDelPlan(
        (await m.servicio.cargar()).dia(1),
        horaMin: 18 * 60 + 30, // se cruza con el traslado
      );
      final r = await m.servicio.ponerEnMiAgenda(await m.servicio.cargar());
      expect(r.conflictos, contains(1));
      expect(
        (await m.agenda.bloques()).any(
          (b) => b.id == idBloqueEntrenamiento(persona, 1),
        ),
        isTrue,
      );
    });

    test('volver a poner el plan actualiza, no duplica', () async {
      await m.diaTipoDelDiseno();
      await m.servicio.ponerEnMiAgenda(await m.servicio.cargar());
      await m.servicio.ponerEnMiAgenda(await m.servicio.cargar());
      final propios = (await m.agenda.bloques()).where(
        (b) => b.objetivoId == idObjetivoEntrenamiento(persona),
      );
      expect(propios, hasLength(3));
    });
  });

  group('modo foco (CA-G-43)', () {
    test('con foco no sube carga y el tipo de semana es foco', () async {
      final foco = ModoFocoDeRangos([
        RangoFoco(DateTime.utc(2026, 11, 23), DateTime.utc(2026, 12, 6)),
      ]);
      final con = Mundo(foco: foco);
      addTearDown(con.cerrar);
      final h = await con.servicio.entrenamientoDe(lunes30);
      expect(h.modoFoco, isTrue);
      expect(h.sesion!.semanaTipo, TipoSemana.foco);
      expect(h.sesion!.tiene(CodigoAviso.modoFoco), isTrue);
      final sin = await m.servicio.entrenamientoDe(lunes30);
      expect(sin.modoFoco, isFalse);
      expect(sin.sesion!.semanaTipo, isNot(TipoSemana.foco));
    });

    test('sin la llave en el equipo vale falso y lo dice', () async {
      final noLegible = Mundo(foco: const SinModoFoco(legible: false));
      addTearDown(noLegible.cerrar);
      final h = await noLegible.servicio.entrenamientoDe(lunes30);
      expect(h.modoFoco, isFalse);
      expect(h.modoFocoLegible, isFalse);
    });

    test('las semanas en foco no cuentan para el ciclo (lunesEnFoco)', () {
      final foco = ModoFocoDeRangos([
        RangoFoco(DateTime.utc(2026, 12, 9), DateTime.utc(2026, 12, 10)),
      ]);
      expect(
        foco.lunesEnFoco(DateTime.utc(2026, 11, 30), DateTime.utc(2026, 12, 20)),
        [DateTime.utc(2026, 12, 7)],
      );
      expect(foco.para(DateTime.utc(2026, 12, 9)), isTrue);
      expect(foco.para(DateTime.utc(2026, 12, 11)), isFalse);
    });

    test('la copia local guarda solo rangos y se renueva al abrir lo reservado', () async {
      final copia = CopiaLocalFoco(m.almacen, persona);
      expect(await copia.leer(), isNull);
      await copia.registrar(
        claveAnonimaDeFoco,
        diaD: DateTime.utc(2026, 11, 25),
        focoDias: 14,
      );
      final leida = (await copia.leer())!;
      expect(leida.para(DateTime.utc(2026, 11, 25)), isTrue);
      expect(leida.para(DateTime.utc(2026, 12, 8)), isTrue);
      expect(leida.para(DateTime.utc(2026, 12, 9)), isFalse);
      // Nada que diga qué hábito es ni cuánto: solo fechas.
      final guardado = m.almacen.datos.values.join(' ');
      expect(guardado.contains('cajetilla'), isFalse);
      // Sin Día D, se quita.
      await copia.registrar(claveAnonimaDeFoco, diaD: null, focoDias: 0);
      expect((await copia.leer())!.rangos, isEmpty);
    });
  });

  group('molestias (CA-G-22, R6)', () {
    test('se tienen en cuenta aquí y no quedan en lo que se guarda', () async {
      const marcador = 'MARCADOR-MOLESTIA-XQZ';
      await m.molestias.guardar(
        Molestia(
          id: 'm1',
          zona: Zonas.hombro,
          intensidad: 2,
          desde: DateTime.utc(2026, 11, 28),
          nota: marcador,
        ),
      );
      final h = await m.servicio.entrenamientoDe(lunes30);
      expect(
        h.sesion!.ejercicios.any((e) => e.conPrecaucion) ||
            h.sesion!.omitidos.isNotEmpty ||
            h.sesion!.ejercicios.length < 4,
        isTrue,
      );
      // Ni la base local de gimnasio ni ninguna fila de sesión lleva la nota.
      final fila = await m.servicio.iniciarSesion(h);
      final todo = [
        fila.aMapaServidor().toString(),
        (await m.repo.sesiones(persona)).map((s) => s.plan).join(),
        (await m.repo.todasLasSeries(persona)).join(),
      ].join();
      expect(todo.contains(marcador), isFalse);
      expect(todo.toLowerCase().contains('molest'), isFalse);
      expect(todo.toLowerCase().contains('hombro'), isFalse);
    });

    test('la laptop no las tiene en cuenta ni lo oculta', () async {
      final laptop = Mundo(equipo: TipoEquipoAvisos.laptop);
      addTearDown(laptop.cerrar);
      final h = await laptop.servicio.entrenamientoDe(lunes30);
      expect(h.molestiasLegibles, isFalse);
    });
  });
}

/// Los avisos de la sesión como los muestran las pantallas.
List<String> avisosDeLaSesion(EntrenamientoHoy h) => [
  if (h.noCabe) MensajesGimnasio.noCabe,
  if (h.avisoDormir != null) MensajesGimnasio.cercaDeDormir,
];
