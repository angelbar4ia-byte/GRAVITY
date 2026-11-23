// Repositorio local de «Mi gimnasio»: local primero, con validación, último
// gana, ids estables, cola y borrado. Sin servidor.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/base_local/base_local.dart';
import 'package:gravity/nucleo/cola/cola_sin_conexion.dart';
import 'package:gravity/nucleo/cola/contrato_gimnasio.dart';
import 'package:gravity/nucleo/gimnasio/ids_gimnasio.dart';
import 'package:gravity/nucleo/gimnasio/repositorio_gimnasio.dart';
import 'package:gravity/nucleo/gimnasio/validacion_gimnasio.dart';

import 'ayuda_gimnasio.dart' as ej;

class _Mudo implements Enviador {
  @override
  Future<ResultadoEnvio> enviar(PeticionEnvio peticion) async =>
      ResultadoEnvio.sinSesion;
}

void main() {
  late BaseLocal base;
  late ColaSinConexion cola;
  late RepositorioGimnasio repo;
  late DateTime ahora;

  setUp(() {
    base = BaseLocal.enMemoria();
    ahora = DateTime(2026, 11, 23, 19, 15, 30);
    cola = ColaSinConexion(base: base, enviador: _Mudo(), reloj: () => ahora);
    repo = RepositorioGimnasio(base, cola: cola, reloj: () => ahora);
  });

  tearDown(() async {
    await cola.cerrar();
    await base.close();
  });

  Future<List<RegistroPendiente>> pendientes() async => (await cola.registros())
      .where((r) => r.tipo.startsWith(TipoColaGimnasio.prefijo))
      .toList();

  Map<String, Object?> carga(RegistroPendiente r) =>
      (jsonDecode(r.carga) as Map).cast<String, Object?>();

  group('perfil', () {
    test(
      'sin perfil no hay fila; el primer guardado trae los valores por omisión',
      () async {
        expect(await repo.perfil(ej.persona), isNull);
        final p = await repo.guardarPerfil(ej.persona, {});
        expect(p.diasPlan, 3);
        expect(p.ventana, 'noche');
        expect(p.nocheDesde, '19:00');
        expect(p.objetivo, 'salud_general');
        expect(p.nivel, 'principiante');
        expect(p.cicloSemanas, 4);
        expect(p.margenDormirMin, 90);
        expect(p.vozDescanso, isFalse);
      },
    );

    test(
      'un cambio parcial conserva lo demás y encola el perfil completo',
      () async {
        await repo.guardarPerfil(ej.persona, {
          'dias_plan': 4,
          'ventana': 'manana',
        });
        final p = await repo.guardarPerfil(ej.persona, {'nivel': 'intermedio'});
        expect((p.diasPlan, p.ventana, p.nivel), (4, 'manana', 'intermedio'));
        final cola_ = await pendientes();
        expect(cola_.map((r) => r.tipo), everyElement(TipoColaGimnasio.perfil));
        // La última entrada lleva el perfil completo.
        final ultima = carga(cola_.last);
        expect(
          ultima.keys.toSet(),
          columnasQueSeMandanGimnasio['hab_ent_perfil'],
        );
        expect(ultima['dias_plan'], 4);
        expect(ultima['nivel'], 'intermedio');
      },
    );

    test(
      'caso malo: valores que el servidor rechazaría no entran ni a la cola',
      () async {
        for (final malo in <Map<String, Object?>>[
          {'dias_plan': 6},
          {'dias_plan': 2},
          {'ventana': 'tarde'},
          {'ciclo_semanas': 2},
          {'ciclo_semanas': 9},
          {'descanso_s': 10},
          {'margen_dormir_min': 241},
          {'inicio_ciclo': '2026-11-24'}, // martes: debe ser lunes
          {'prueba_desde': '2026-11-23'}, // sin prueba_ventana
        ]) {
          await expectLater(
            repo.guardarPerfil(ej.persona, malo),
            throwsA(isA<FilaGimnasioInvalida>()),
            reason: '$malo',
          );
        }
        expect(await repo.perfil(ej.persona), isNull);
        expect(await pendientes(), isEmpty);
      },
    );

    test('inicio_ciclo en lunes y ciclo sin descarga (0) sí', () async {
      final p = await repo.guardarPerfil(ej.persona, {
        'inicio_ciclo': '2026-11-23',
        'ciclo_semanas': 0,
      });
      expect(p.inicioCiclo, '2026-11-23');
      expect(p.cicloSemanas, 0);
    });
  });

  group('plan, inventario y bandas', () {
    test(
      'plan: un día por fila; lunes a domingo; la hora se queda en HH:MM',
      () async {
        await repo.guardarPlanDia(
          ej.persona,
          diaSemana: 1,
          tipo: 'A',
          hora: '19:15:00',
        );
        await repo.guardarPlanDia(ej.persona, diaSemana: 3, tipo: 'B');
        await repo.guardarPlanDia(
          ej.persona,
          diaSemana: 1,
          tipo: 'A',
          version: 'corta',
        );
        final dias = await repo.planDias(ej.persona);
        expect(dias.map((d) => d.diaSemana), [1, 3]);
        expect(dias.first.version, 'corta');
        await expectLater(
          repo.guardarPlanDia(ej.persona, diaSemana: 8, tipo: 'A'),
          throwsA(isA<FilaGimnasioInvalida>()),
        );
        await expectLater(
          repo.guardarPlanDia(ej.persona, diaSemana: 2, tipo: 'X'),
          throwsA(isA<FilaGimnasioInvalida>()),
        );
      },
    );

    test('inventario: confirmado solo con datos del aparato', () async {
      await repo.guardarItemInventario(
        ej.persona,
        itemId: 'marcy_mwm7119',
        estado: 'disponible',
        confirmado: {'pasos_max': 10, 'kg_por_paso_x10': 68},
      );
      final i = (await repo.inventario(ej.persona)).single;
      expect(i.confirmadoComoMapa, {'pasos_max': 10, 'kg_por_paso_x10': 68});
      // Un puesto suelto de la persona.
      await repo.guardarItemInventario(
        ej.persona,
        itemId: 'otro:extension de pierna',
        estado: 'futuro',
      );
      expect(await repo.inventario(ej.persona), hasLength(2));
      // Caso malo: el servidor rechaza campos de salud; la app ni los encola.
      for (final campo in ['molestia_rodilla', 'dolor', 'zona', 'lesion']) {
        await expectLater(
          repo.guardarItemInventario(
            ej.persona,
            itemId: 'banco_inclinado',
            estado: 'disponible',
            confirmado: {campo: 1},
          ),
          throwsA(isA<FilaGimnasioInvalida>()),
          reason: campo,
        );
      }
      await expectLater(
        repo.guardarItemInventario(
          ej.persona,
          itemId: 'banco_inclinado',
          estado: 'roto',
        ),
        throwsA(isA<FilaGimnasioInvalida>()),
      );
      await expectLater(
        repo.guardarItemInventario(
          ej.persona,
          itemId: 'Mayúsculas',
          estado: 'disponible',
        ),
        throwsA(isA<FilaGimnasioInvalida>()),
      );
    });

    test('bandas: id v4 propio, de la más ligera a la más fuerte', () async {
      final a = await repo.guardarBanda(
        ej.persona,
        nombre: 'Verde',
        orden: 2,
        cantidad: 2,
      );
      final b = await repo.guardarBanda(
        ej.persona,
        nombre: 'Amarilla',
        orden: 1,
      );
      expect(esId4(a) && esId4(b), isTrue);
      final lista = await repo.bandas(ej.persona);
      expect(lista.map((x) => x.nombre), ['Amarilla', 'Verde']);
      await repo.guardarBanda(
        ej.persona,
        id: a,
        nombre: 'Verde',
        orden: 2,
        cantidad: 2,
        activa: false,
      );
      expect((await repo.bandas(ej.persona)).last.activa, isFalse);
      for (final (n, o, c) in [
        ('', 1, 1),
        ('x', 0, 1),
        ('x', 21, 1),
        ('x', 1, 0),
        ('x', 1, 11),
      ]) {
        await expectLater(
          repo.guardarBanda(ej.persona, nombre: n, orden: o, cantidad: c),
          throwsA(isA<FilaGimnasioInvalida>()),
          reason: '$n/$o/$c',
        );
      }
    });
  });

  group('sesiones y series', () {
    test('la sesión se guarda con el id v5 de su día y plantilla', () async {
      final fila = await repo.guardarSesion(ej.persona, ej.sesion());
      expect(fila.id, ej.idSesion());
      expect(fila.estado, 'en_curso');
      expect(fila.fin, isNull);
      expect(fila.planComoLista.single['ejercicio'], 'press_pecho');
      expect(await repo.sesionDelDia(ej.persona, '2026-11-23', 'A'), isNotNull);
      expect((await repo.sesionEnCurso(ej.persona))!.id, fila.id);
    });

    test(
      'sin id, el repositorio lo calcula; con otro id, lo rechaza',
      () async {
        final sin = {...ej.sesion()}..remove('id');
        expect((await repo.guardarSesion(ej.persona, sin)).id, ej.idSesion());
        await expectLater(
          repo.guardarSesion(ej.persona, {
            ...ej.sesion(plantilla: 'B'),
            'id': ej.idSesion(), // el de A para una sesión B
          }),
          throwsA(isA<FilaGimnasioInvalida>()),
        );
        // El id de OTRA persona tampoco vale.
        await expectLater(
          repo.guardarSesion(ej.persona, {
            ...ej.sesion(),
            'id': ej.idSesion(p: 'otra-persona'),
          }),
          throwsA(isA<FilaGimnasioInvalida>()),
        );
      },
    );

    test(
      'terminar la sesión: se actualiza la misma fila (en_curso → completa)',
      () async {
        await repo.guardarSesion(ej.persona, ej.sesion());
        ahora = ahora.add(const Duration(minutes: 45));
        final fin = await repo.guardarSesion(
          ej.persona,
          ej.sesion(estado: 'completa', esfuerzo: 4),
        );
        expect(fin.estado, 'completa');
        expect(fin.esfuerzo, 4);
        expect(await repo.sesiones(ej.persona), hasLength(1));
        expect(await repo.sesionEnCurso(ej.persona), isNull);
      },
    );

    test('la ventana que el dominio no sabe (nula o flexible) se deduce de la hora', () async {
      final tarde = await repo.guardarSesion(
        ej.persona,
        ej.sesion(ventana: null),
      );
      expect(tarde.ventana, 'noche'); // inicio 19:15
      final manana = await repo.guardarSesion(ej.persona, {
        ...ej.sesion(plantilla: 'B', ventana: 'flexible'),
        'inicio': DateTime(2026, 11, 23, 7, 30).toIso8601String(),
      });
      expect(manana.ventana, 'manana');
    });

    test(
      'inicio y fin se guardan en UTC aunque el dominio los dé sin zona',
      () async {
        final fila = await repo.guardarSesion(
          ej.persona,
          ej.sesion(estado: 'completa'),
        );
        expect(fila.inicio, DateTime(2026, 11, 23, 19, 15));
        expect(fila.aMapaServidor()['inicio'], endsWith('Z'));
        expect(fila.aMapaServidor()['fin'], endsWith('Z'));
      },
    );

    test('caso malo: en_curso con fin, fin antes del inicio, plan con claves de más', () async {
      for (final mala in <Map<String, Object?>>[
        {...ej.sesion(), 'fin': DateTime(2026, 11, 23, 20).toIso8601String()},
        {...ej.sesion(estado: 'completa'), 'fin': null},
        {
          ...ej.sesion(estado: 'completa'),
          'fin': DateTime(2026, 11, 23, 18).toIso8601String(),
        },
        {...ej.sesion(), 'esfuerzo': 6},
        {...ej.sesion(), 'estado': 'a_medias'},
        {
          ...ej.sesion(),
          'plan': [
            {'ejercicio': 'press_pecho', 'zona': 'hombro'},
          ],
        },
        {
          ...ej.sesion(),
          'plan': [
            {'ejercicio': 'Press Pecho'},
          ],
        },
      ]) {
        await expectLater(
          repo.guardarSesion(ej.persona, mala),
          throwsA(isA<FilaGimnasioInvalida>()),
        );
      }
      expect(await repo.sesiones(ej.persona), isEmpty);
      expect(await pendientes(), isEmpty);
    });

    test(
      'series: id v5 por sesión, ejercicio, número y lado; "deshacer" la quita',
      () async {
        final ses = (await repo.guardarSesion(ej.persona, ej.sesion())).id;
        final s1 = await repo.guardarSerie(ej.persona, ej.serie(sesionId: ses));
        final s2 = await repo.guardarSerie(
          ej.persona,
          ej.serie(sesionId: ses, n: 2),
        );
        expect(s1, isNot(s2));
        // Repetir lo mismo no duplica.
        expect(
          await repo.guardarSerie(ej.persona, ej.serie(sesionId: ses)),
          s1,
        );
        expect(await repo.series(ej.persona, ses), hasLength(2));
        // Por pierna.
        await repo.guardarSerie(
          ej.persona,
          ej.serie(sesionId: ses, ejercicio: 'subida_banco', lado: 'izquierdo'),
        );
        await repo.guardarSerie(
          ej.persona,
          ej.serie(sesionId: ses, ejercicio: 'subida_banco', lado: 'derecho'),
        );
        expect(await repo.series(ej.persona, ses), hasLength(4));
        await repo.borrarSerie(ej.persona, s2);
        expect(
          (await repo.series(ej.persona, ses)).map((s) => s.id),
          isNot(contains(s2)),
        );
        expect(
          await repo.todasLasSeries(ej.persona, ejercicioId: 'subida_banco'),
          hasLength(2),
        );
      },
    );

    test(
      'caso malo: id que no corresponde, rangos y el motivo «molestia»',
      () async {
        final ses = (await repo.guardarSesion(ej.persona, ej.sesion())).id;
        for (final mala in <Map<String, Object?>>[
          {...ej.serie(sesionId: ses), 'id': IdsGimnasio.banda()},
          {...ej.serie(sesionId: ses), 'n': 13},
          {...ej.serie(sesionId: ses), 'reps': 101},
          {...ej.serie(sesionId: ses), 'carga_pasos': 61},
          {...ej.serie(sesionId: ses), 'esfuerzo': 0},
          {...ej.serie(sesionId: ses), 'segundos': 901},
          {...ej.serie(sesionId: ses), 'lado': 'centro'},
          // PG-19: el motivo «molestia» no existe en el servidor.
          {...ej.serie(sesionId: ses), 'motivo_cambio': 'molestia'},
          // Ninguna columna habla de molestias.
          {...ej.serie(sesionId: ses), 'zona': 'hombro'},
          {...ej.serie(sesionId: ses), 'molestia': true},
        ]) {
          await expectLater(
            repo.guardarSerie(ej.persona, mala),
            throwsA(isA<FilaGimnasioInvalida>()),
            reason: '${mala['motivo_cambio']}${mala['zona']}${mala['n']}',
          );
        }
        expect(await repo.series(ej.persona, ses), isEmpty);
      },
    );

    test(
      'los motivos que sí existen: no_disponible, preferencia y otra',
      () async {
        final ses = (await repo.guardarSesion(ej.persona, ej.sesion())).id;
        var n = 0;
        for (final m in ['no_disponible', 'preferencia', 'otra']) {
          await repo.guardarSerie(
            ej.persona,
            ej.serie(sesionId: ses, n: ++n, motivo: m),
          );
        }
        expect(
          (await repo.series(
            ej.persona,
            ses,
          )).map((s) => s.motivoCambio).toSet(),
          {'no_disponible', 'preferencia', 'otra'},
        );
      },
    );

    test(
      'tiempos: solo locales; se quedan si no se vuelven a dar y no se encolan',
      () async {
        await repo.guardarSesion(
          ej.persona,
          ej.sesion(),
          tiempos: {'segundos_por_repeticion': 4, 'segundos_cambio': 45},
        );
        final despues = await repo.guardarSesion(
          ej.persona,
          ej.sesion(estado: 'completa'),
        );
        expect(despues.tiemposComoMapa, {
          'segundos_por_repeticion': 4,
          'segundos_cambio': 45,
        });
        for (final r in await pendientes()) {
          expect(r.carga, isNot(contains('tiempos')));
          expect(r.carga, isNot(contains('segundos_cambio')));
        }
      },
    );

    test('borrar una sesión se lleva sus series', () async {
      final ses = (await repo.guardarSesion(ej.persona, ej.sesion())).id;
      await repo.guardarSerie(ej.persona, ej.serie(sesionId: ses));
      await repo.borrarSesion(ej.persona, ses);
      expect(await repo.sesiones(ej.persona), isEmpty);
      expect(await repo.todasLasSeries(ej.persona), isEmpty);
      expect((await pendientes()).last.tipo, TipoColaGimnasio.sesionBorrar);
    });
  });

  group('cola: lo que se encola', () {
    test('cada cambio queda local Y en la cola, con su tipo y sin columnas del servidor', () async {
      await repo.guardarPerfil(ej.persona, {});
      await repo.guardarPlanDia(ej.persona, diaSemana: 1, tipo: 'A');
      await repo.guardarItemInventario(
        ej.persona,
        itemId: 'caminadora',
        estado: 'disponible',
      );
      await repo.guardarBanda(ej.persona, nombre: 'Verde', orden: 1);
      final ses = (await repo.guardarSesion(ej.persona, ej.sesion())).id;
      await repo.guardarSerie(ej.persona, ej.serie(sesionId: ses));
      final lista = await pendientes();
      expect(lista.map((r) => r.tipo).toSet(), TipoColaGimnasio.altas);
      for (final r in lista) {
        expect(r.personaId, ej.persona);
        expect(r.estado, EstadoPendiente.pendiente);
        final c = carga(r);
        final tabla = destinosUpsertGimnasio[r.tipo]!.tabla;
        expect(
          c.keys.toSet(),
          columnasQueSeMandanGimnasio[tabla],
          reason: r.tipo,
        );
        expect(
          c.keys.toSet().intersection(
            columnasQuePoneElServidorGimnasio[tabla]!,
          ),
          isEmpty,
        );
        // modificado_en es la hora del dispositivo, en UTC.
        expect(c['modificado_en'], ahora.toUtc().toIso8601String());
      }
    });

    test('el mismo cambio en el mismo instante no se encola dos veces; otro cambio sí', () async {
      await repo.guardarSesion(ej.persona, ej.sesion());
      await repo.guardarSesion(ej.persona, ej.sesion());
      expect(await pendientes(), hasLength(1));
      ahora = ahora.add(const Duration(minutes: 45));
      await repo.guardarSesion(ej.persona, ej.sesion(estado: 'completa'));
      expect(await pendientes(), hasLength(2));
    });

    test('sin cola (demostración) solo se guarda en el equipo', () async {
      final solo = RepositorioGimnasio(base, reloj: () => ahora);
      await solo.guardarPerfil(ej.persona, {'dias_plan': 5});
      expect((await solo.perfil(ej.persona))!.diasPlan, 5);
      expect(await pendientes(), isEmpty);
    });

    test(
      'modificado_en nunca retrocede para una fila (reloj atrasado)',
      () async {
        await repo.guardarSesion(ej.persona, ej.sesion());
        final primero = (await repo.sesion(
          ej.persona,
          ej.idSesion(),
        ))!.modificadoEn;
        ahora = ahora.subtract(const Duration(hours: 1));
        await repo.guardarSesion(ej.persona, ej.sesion(estado: 'completa'));
        final despues = (await repo.sesion(
          ej.persona,
          ej.idSesion(),
        ))!.modificadoEn;
        expect(despues.isBefore(primero), isFalse);
      },
    );
  });

  group('cada persona solo lo suyo (D5)', () {
    test('las filas de otra persona de la misma tablet no se ven', () async {
      await repo.guardarPerfil(ej.persona, {'dias_plan': 4});
      await repo.guardarPerfil('uid-bruno', {'dias_plan': 5});
      await repo.guardarSesion(ej.persona, ej.sesion());
      await repo.guardarSesion('uid-bruno', ej.sesion(p: 'uid-bruno'));
      expect((await repo.perfil(ej.persona))!.diasPlan, 4);
      expect((await repo.perfil('uid-bruno'))!.diasPlan, 5);
      expect(await repo.sesiones(ej.persona), hasLength(1));
      expect((await repo.sesiones('uid-bruno')).single.personaId, 'uid-bruno');
      // El id de una persona no sirve para leer la sesión desde la otra.
      expect(await repo.sesion('uid-bruno', ej.idSesion()), isNull);
    });
  });

  group('borrar mis datos', () {
    test('borrarTodoDe quita lo local y lo pendiente de esa persona, no lo de otra', () async {
      for (final p in [ej.persona, 'uid-bruno']) {
        await repo.guardarPerfil(p, {});
        await repo.guardarBanda(p, nombre: 'Verde', orden: 1);
        final ses = (await repo.guardarSesion(p, ej.sesion(p: p))).id;
        await repo.guardarSerie(p, ej.serie(p: p, sesionId: ses));
      }
      await cola.encolar(
        tipo: 'habitos.borrar',
        carga: {'p_alcance': 'entrenamiento'},
        personaId: ej.persona,
      );
      await repo.borrarTodoDe(ej.persona);
      expect(await repo.perfil(ej.persona), isNull);
      expect(await repo.bandas(ej.persona), isEmpty);
      expect(await repo.sesiones(ej.persona), isEmpty);
      expect(await repo.todasLasSeries(ej.persona), isEmpty);
      // Lo de la otra persona sigue.
      expect(await repo.sesiones('uid-bruno'), hasLength(1));
      // Lo pendiente del gimnasio de Ana se fue; el borrado en la nube sigue
      // esperando.
      final restantes = (await cola.registros());
      expect(
        restantes.where((r) => r.personaId == ej.persona).map((r) => r.tipo),
        ['habitos.borrar'],
      );
      expect(restantes.where((r) => r.personaId == 'uid-bruno'), isNotEmpty);
    });

    test('al salir o quitar a la persona (copia local) lo pendiente sigue en la cola', () async {
      await repo.guardarPerfil(ej.persona, {});
      await repo.borrarTodoDe(ej.persona, incluirCola: false);
      expect(await repo.perfil(ej.persona), isNull);
      expect(await pendientes(), hasLength(1));
    });
  });

  group('bajada desde el servidor: último gana', () {
    Map<String, Object?> remotaSesion(
      String modificadoEn, {
      String estado = 'completa',
    }) => {
      ...ej.sesion(estado: estado, esfuerzo: 4),
      // Como lo entrega PostgREST (timestamptz con zona).
      'inicio': '2026-11-24T01:15:00+00:00',
      'fin': estado == 'completa' ? '2026-11-24T02:00:00+00:00' : null,
      'modificado_en': modificadoEn,
      'persona_id': ej.persona,
      'hogar_id': 'h1',
      'actualizado_en': '2026-11-24T02:01:00+00:00',
    };

    test('trae lo que no hay y no encola nada', () async {
      final n = await repo.fusionarDelServidor(
        ej.persona,
        sesiones: [remotaSesion('2026-11-24T02:00:00Z')],
        perfil: [
          {
            ...{
              'dias_plan': 4,
              'version_pref': 'auto',
              'ventana': 'noche',
              'noche_desde': '19:00:00',
              'objetivo': 'salud_general',
              'nivel': 'principiante',
              'inicio_ciclo': null,
              'ciclo_semanas': 4,
              'descanso_s': null,
              'margen_dormir_min': 90,
              'prueba_desde': null,
              'prueba_ventana': null,
              'voz_descanso': false,
              'aviso_visto_en': null,
            },
            'modificado_en': '2026-11-24T02:00:00+00:00',
          },
        ],
      );
      expect(n, 2);
      expect((await repo.perfil(ej.persona))!.nocheDesde, '19:00');
      expect((await repo.sesiones(ej.persona)).single.estado, 'completa');
      expect(await pendientes(), isEmpty);
    });

    test('lo local más nuevo se queda; lo remoto más nuevo gana', () async {
      await repo.guardarSesion(
        ej.persona,
        ej.sesion(estado: 'completa', esfuerzo: 2),
      );
      // Remoto más viejo que lo local (ahora = 2026-11-23 19:15:30 local).
      var n = await repo.fusionarDelServidor(
        ej.persona,
        sesiones: [remotaSesion('2000-01-01T00:00:00Z')],
      );
      expect(n, 0);
      expect((await repo.sesion(ej.persona, ej.idSesion()))!.esfuerzo, 2);
      // Remoto más nuevo.
      n = await repo.fusionarDelServidor(
        ej.persona,
        sesiones: [remotaSesion('2030-01-01T00:00:00Z')],
      );
      expect(n, 1);
      expect((await repo.sesion(ej.persona, ej.idSesion()))!.esfuerzo, 4);
    });

    test(
      'no pisa los tiempos locales y omite filas ajenas inválidas',
      () async {
        await repo.guardarSesion(
          ej.persona,
          ej.sesion(),
          tiempos: {'segundos_por_repeticion': 5},
        );
        await repo.fusionarDelServidor(
          ej.persona,
          sesiones: [
            remotaSesion('2030-01-01T00:00:00Z'),
            {
              ...remotaSesion('2030-01-01T00:00:00Z'),
              'estado': 'rara',
              'id': IdsGimnasio.banda(),
            },
          ],
        );
        final f = (await repo.sesion(ej.persona, ej.idSesion()))!;
        expect(f.tiemposComoMapa, {'segundos_por_repeticion': 5});
        expect(await repo.sesiones(ej.persona), hasLength(1));
      },
    );
  });
}

bool esId4(String id) => RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
).hasMatch(id);
