// G6-A1 · Sin señal, Mi gimnasio sigue con lo local (R7, 9.1, CA-G-32, H-12).
//
// A diferencia de las pruebas de G5 (agenda y registros siempre en memoria), aquí
// la agenda y los registros de Hábitos FALLAN como lo haría el cliente de
// Supabase sin conexión (SocketException):
//
// - abrir «lo de hoy» usa el plan y el equipo guardados, avisa sin culpa que la
//   agenda no se pudo leer y NO inventa que no cabe la sesión;
// - terminar la sesión guarda primero en el equipo y deja el registro del día y
//   el objetivo «Entrenamiento» en la cola (tipos `habitos.registro` y
//   `habitos.objetivo`), sin lanzar y diciendo que se enviará después;
// - nada se escribe dos veces ni pisa lo que la persona ya cambió en el
//   objetivo.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/habitos/datos/modelos.dart';
import 'package:gravity/modulos/habitos/datos/modelos_agenda.dart';
import 'package:gravity/modulos/habitos/datos/repositorio.dart';
import 'package:gravity/modulos/habitos/datos/repositorio_agenda.dart';
import 'package:gravity/modulos/habitos/gimnasio/casos_uso/servicio_gimnasio.dart';
import 'package:gravity/modulos/habitos/gimnasio/pantallas/comun.dart'
    show TextosHabitosGimnasio, avisosDe;
import 'package:gravity/nucleo/base_local/base_local.dart'
    show RegistroPendiente;
import 'package:gravity/nucleo/cola/cola_sin_conexion.dart';
import 'package:gravity/nucleo/cola/contrato_habitos.dart';
import 'package:gravity/nucleo/cola/proveedores_cola.dart'
    show EnviadorSinServidor;
import 'package:habitos_dominio/habitos_dominio.dart';

import 'ayuda_gimnasio_app.dart';

class AgendaSinRed implements RepositorioAgenda {
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw const SocketException('Failed host lookup: supabase.co');
}

/// Lee bien, pero escribir (y listar objetivos) falla: sin señal a medias.
class RegistrosSinRed implements RepositorioHabitos {
  RegistrosSinRed({this.leeBien = false}) : _memoria = RepositorioHabitosEnMemoria();

  final bool leeBien;
  final RepositorioHabitosEnMemoria _memoria;
  int intentosDeEscritura = 0;

  static const _error = SocketException('Failed host lookup: supabase.co');

  @override
  Future<List<ObjetivoHab>> objetivos() async =>
      leeBien ? _memoria.objetivos() : throw _error;

  @override
  Future<void> guardarObjetivo(ObjetivoHab o) async {
    intentosDeEscritura++;
    throw _error;
  }

  @override
  Future<List<RegistroHab>> registros(DateTime desde, DateTime hasta) async =>
      throw _error;

  @override
  Future<void> guardarRegistro(RegistroHab r) async {
    intentosDeEscritura++;
    throw _error;
  }
}

void main() {
  late Mundo m;
  late ColaSinConexion cola;
  setUp(() {
    m = Mundo();
    cola = ColaSinConexion(
      base: m.base,
      enviador: const EnviadorSinServidor(),
      reloj: () => m.ahoraActual,
    );
  });
  tearDown(() async {
    await cola.cerrar();
    await m.cerrar();
  });

  ServicioGimnasio sinRed({
    bool agenda = true,
    RepositorioHabitos? registros,
    bool conCola = true,
  }) => ServicioGimnasio(
    repo: m.repo,
    persona: persona,
    agenda: agenda ? AgendaSinRed() : m.agenda,
    registros: registros ?? RegistrosSinRed(),
    molestias: m.molestias,
    cola: conCola ? cola : null,
    ahora: () => m.ahoraActual,
  );

  Future<List<RegistroPendiente>> pendientes(String tipo) async => [
    for (final r in await cola.registros())
      if (r.tipo == tipo) r,
  ];

  group('abrir lo de hoy sin señal', () {
    test('usa el plan y el equipo locales y lo dice sin culpa', () async {
      final h = await sinRed().entrenamientoDe(lunes30);
      expect(h.tipo, 'A');
      expect(h.sesion, isNotNull);
      expect(h.agendaSinLeer, isTrue);
      // No se confunde «no pude leer» con «no cabe»: hay hora y hueco propuestos.
      expect(h.noCabe, isFalse);
      expect(h.inicioMin, isNotNull);
      expect(avisosDe(h), contains(TextosHabitosGimnasio.agendaSinLeer));
      expect(
        TextosHabitosGimnasio.agendaSinLeer,
        isNot(contains('error')),
        reason: 'sin culpa y sin tecnicismos',
      );
    });

    test('la regenerativa también abre sin señal', () async {
      final h = await sinRed().entrenamientoDe(lunes30, tipo: 'R1');
      expect(h.esRegenerativa, isTrue);
      expect(h.regenerativa, isNotNull);
      expect(h.agendaSinLeer, isTrue);
    });

    test('con señal no hay aviso de agenda', () async {
      final h = await m.servicio.entrenamientoDe(lunes30);
      expect(h.agendaSinLeer, isFalse);
      expect(avisosDe(h), isNot(contains(TextosHabitosGimnasio.agendaSinLeer)));
    });

    test('sin señal no se inventan bloques ocupados: bloqueDe devuelve nada', () async {
      expect(await sinRed().bloqueDe(lunes30), isNull);
    });

    test('un día de descanso o bici no pide la agenda', () async {
      final h = await sinRed().entrenamientoDe(DateTime(2026, 12, 6));
      expect(h.tipo, 'descanso');
      expect(h.agendaSinLeer, isFalse);
    });
  });

  group('terminar la sesión sin señal', () {
    test('queda guardada en el equipo y el registro del día en la cola', () async {
      final s = sinRed(agenda: false);
      final d = await s.cargar();
      final h = await s.entrenamientoDe(lunes30, datos: d);
      final fila = await s.iniciarSesion(h);
      final r = await s.terminarSesion(
        fila: fila,
        h: h,
        completa: true,
        esfuerzo: 3,
        energia: 3,
      );
      expect(r.enviarDespues, isTrue);
      expect((await m.repo.sesiones(persona)).single.estado, 'completa');

      // El objetivo se repone (sin pisar) y el registro del día se sube.
      final objetivos = await pendientes(TipoColaHabitos.objetivo);
      final registros = await pendientes(TipoColaHabitos.registro);
      expect(objetivos, hasLength(1));
      expect(objetivos.single.id, idObjetivoEntrenamiento(persona));
      expect(registros, hasLength(1));
      final carga = jsonDecode(registros.single.carga) as Map<String, Object?>;
      expect(carga['objetivo_id'], idObjetivoEntrenamiento(persona));
      expect(carga['estado'], 'hecho');
      expect(carga['fecha'], '2026-11-30');
      expect(carga['id'], idRegistro(idObjetivoEntrenamiento(persona), soloDia(lunes30)));
      // Nunca lo que pone el servidor.
      expect(carga.keys, isNot(contains('persona_id')));
      expect(carga.keys, isNot(contains('hogar_id')));
      expect(registros.single.personaId, persona);
    });

    test('con el bloque en la agenda también encola el registro del bloque', () async {
      // Con señal se pone el plan en la agenda; después se queda sin señal.
      final d = await m.servicio.cargar();
      await m.servicio.ponerEnMiAgenda(d);
      final s = sinRed(agenda: false);
      final h = await s.entrenamientoDe(lunes30, datos: d);
      final fila = await s.iniciarSesion(h);
      // El bloque se lee de la agenda: aquí viene del equipo con la agenda viva.
      final hConBloque = await ServicioGimnasio(
        repo: m.repo,
        persona: persona,
        agenda: m.agenda,
        registros: RegistrosSinRed(),
        molestias: m.molestias,
        cola: cola,
        ahora: () => m.ahoraActual,
      ).entrenamientoDe(lunes30, datos: d);
      expect(hConBloque.bloque, isNotNull);
      final r = await s.terminarSesion(fila: fila, h: hConBloque, completa: false);
      expect(r.enviarDespues, isTrue);
      final registros = await pendientes(TipoColaHabitos.registro);
      expect(registros, hasLength(2));
      final cargas = [
        for (final x in registros) jsonDecode(x.carga) as Map<String, Object?>,
      ];
      expect(cargas.map((c) => c['estado']), everyElement('parcial'));
      expect(cargas.where((c) => c['bloque_id'] == hConBloque.bloque!.id), hasLength(1));
    });

    test('el objetivo que ya existe no se vuelve a encolar; solo el registro', () async {
      final registros = RegistrosSinRed(leeBien: true);
      // Ya existe: se lee bien, pero escribir falla.
      await registros._memoria.guardarObjetivo(
        ObjetivoHab(
          id: idObjetivoEntrenamiento(persona),
          titulo: 'Entrenamiento',
          area: 'salud',
          tipo: TipoObjetivo.construir,
          fechaInicio: DateTime.utc(2026, 11, 1),
          modificadoEn: DateTime.utc(2026, 11, 1),
        ),
      );
      final s = sinRed(agenda: false, registros: registros);
      final h = await s.entrenamientoDe(lunes30);
      final fila = await s.iniciarSesion(h);
      final r = await s.terminarSesion(fila: fila, h: h, completa: true);
      expect(r.enviarDespues, isTrue);
      expect(await pendientes(TipoColaHabitos.objetivo), isEmpty);
      expect(await pendientes(TipoColaHabitos.registro), hasLength(1));
    });

    test('dos cierres sin señal no duplican el objetivo ni el mismo registro', () async {
      final s = sinRed(agenda: false);
      final h = await s.entrenamientoDe(lunes30);
      final fila = await s.iniciarSesion(h);
      await s.terminarSesion(fila: fila, h: h, completa: true);
      await s.terminarSesion(fila: fila, h: h, completa: true);
      expect(await pendientes(TipoColaHabitos.objetivo), hasLength(1));
      // Mismo cambio, misma entrada.
      expect(await pendientes(TipoColaHabitos.registro), hasLength(1));
    });

    test('Hecho de un toque (marcarHecho) tampoco lanza sin señal', () async {
      final s = sinRed(agenda: false);
      final h = await s.entrenamientoDe(lunes30);
      final r = await s.marcarHecho(h);
      expect(r.enviarDespues, isTrue);
      expect(r.estado, EstadoSesion.completa);
      expect((await m.repo.sesiones(persona)).single.estado, 'completa');
      expect(await pendientes(TipoColaHabitos.registro), hasLength(1));
    });

    test('deshacer Hecho sin señal queda en la cola como pendiente', () async {
      final s = sinRed(agenda: false);
      final h = await s.entrenamientoDe(lunes30);
      await s.marcarHecho(h);
      m.ahoraActual = m.ahoraActual.add(const Duration(minutes: 1));
      await s.deshacerHecho(h);
      expect(await m.repo.sesiones(persona), isEmpty);
      final cargas = [
        for (final x in await pendientes(TipoColaHabitos.registro))
          jsonDecode(x.carga) as Map<String, Object?>,
      ];
      expect(cargas.map((c) => c['estado']), containsAll(['hecho', 'pendiente']));
    });

    test('registrar lo que hice después también funciona sin señal', () async {
      final s = sinRed(agenda: false);
      final h = await s.entrenamientoDe(lunes30);
      final r = await s.registrarDespues(h: h, hecho: const [], completa: true);
      expect(r.enviarDespues, isTrue);
      expect((await m.repo.sesiones(persona)).single.estado, 'completa');
    });

    test('con señal todo va directo y la cola queda vacía', () async {
      final h = await m.servicio.entrenamientoDe(lunes30);
      final r = await m.servicio.marcarHecho(h);
      expect(r.enviarDespues, isFalse);
      expect(await cola.registros(), isEmpty);
      expect(await m.registros.objetivos(), hasLength(1));
    });

    test('sin cola (solo lo local) no lanza y dice que quedó pendiente', () async {
      final s = sinRed(agenda: false, conCola: false);
      final h = await s.entrenamientoDe(lunes30);
      final r = await s.marcarHecho(h);
      expect(r.enviarDespues, isTrue);
    });

    test('ponerEnMiAgenda sin señal falla con un error que la pantalla atrapa', () async {
      final d = await m.servicio.cargar();
      await expectLater(
        sinRed().ponerEnMiAgenda(d),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('la cola sabe subir los dos tipos de Hábitos', () {
    test('contrato: registro por upsert con su id, objetivo sin pisar', () {
      expect(destinosUpsertHabitos[TipoColaHabitos.registro]!.tabla, 'hab_registros');
      expect(destinosUpsertHabitos[TipoColaHabitos.registro]!.onConflict, 'id');
      expect(destinosUpsertHabitos[TipoColaHabitos.registro]!.llevaId, isTrue);
      expect(tablasInsertarHabitos[TipoColaHabitos.objetivo], 'hab_objetivos');
      // El objetivo sube antes que el registro (llave foránea).
      expect(
        nivelesDeSubidaHabitos['hab_objetivos']!,
        lessThan(nivelesDeSubidaHabitos['hab_registros']!),
      );
      // Personales: nunca desde la tablet de la casa sin PIN (D14).
      expect(esTipoPersonal(TipoColaHabitos.registro), isTrue);
      expect(esTipoPersonal(TipoColaHabitos.objetivo), isTrue);
    });
  });

  group('G6-M4 · dormir pasada la medianoche en lo de hoy', () {
    Future<void> dormirA(int minutos) async => m.agenda.guardarAjustes(
      const AjustesHab().copiar(dormirMin: minutos),
      m.ahoraActual,
    );

    test('con dormir a las 00:30 hay hueco, hora y sin aviso (A estándar)', () async {
      await m.diaTipoDelDiseno();
      await dormirA(30);
      final h = await m.servicio.entrenamientoDe(lunes30);
      expect(h.inicioMin, 19 * 60 + 15);
      expect(h.noCabe, isFalse);
      expect(h.avisoDormir, isNull);
      // Hasta las 00:30 hay más de 5 horas: cabe la versión larga.
      expect(h.version, VersionSesion.larga);
    });

    test('con dormir a las 22:00 sigue igual que antes (sin sumar un día)', () async {
      await m.diaTipoDelDiseno();
      await dormirA(22 * 60);
      final h = await m.servicio.entrenamientoDe(lunes30);
      expect(h.inicioMin, 19 * 60 + 15);
      expect(h.version, VersionSesion.larga);
    });

    test('con una hora del plan a las 23:15 y dormir a las 00:30: avisa (75 min)', () async {
      await m.diaTipoDelDiseno();
      await dormirA(30);
      final d = await m.servicio.cargar();
      await m.servicio.guardarDiaDelPlan(d.dia(1), horaMin: 23 * 60 + 15);
      final h = await m.servicio.entrenamientoDe(lunes30);
      expect(h.horaDelPlan, isTrue);
      expect(h.avisoDormir, isNotNull);
      expect(h.avisoDormir!.minutosAntesDeDormir, lessThan(90));
      expect(h.avisoDormir!.minutosAntesDeDormir, greaterThan(0));
    });
  });
}
