// CA-G-32: la sesión, el registro y el historial funcionan sin red; lo hecho se
// encola con los tipos habitos.gim_* y SUBE CON EL MISMO ID al volver la
// señal; el reintento no duplica. Contra un PostgREST simulado que aplica las
// reglas de la migración 20261152 (upsert último gana, únicos naturales, llaves
// foráneas, cuota) y el contrato de errores de la cola:
//
// - 23514, 23505 (otro id), 42501 y 54000: permanentes (requieren atención, no
//   se reintentan);
// - 23503: se reintenta y no detiene la ronda;
// - orden: perfil, inventario, bandas y plan; luego sesiones; luego series.
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/base_local/base_local.dart';
import 'package:gravity/nucleo/cola/cola_sin_conexion.dart';
import 'package:gravity/nucleo/cola/contrato_gimnasio.dart';
import 'package:gravity/nucleo/cola/enviador_supabase.dart';
import 'package:gravity/nucleo/gimnasio/ids_gimnasio.dart';
import 'package:gravity/nucleo/gimnasio/repositorio_gimnasio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'ayuda_gimnasio.dart' as ej;
import 'servidor_gimnasio_simulado.dart';

void main() {
  // Una prueba abre dos bases (dos equipos).
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late ServidorGimnasioSimulado servidor;
  late SupabaseClient cliente;
  late BaseLocal base;
  late DateTime ahora;
  late ColaSinConexion cola;
  late RepositorioGimnasio repo;

  setUp(() async {
    servidor = await ServidorGimnasioSimulado.iniciar();
    cliente = await servidor.cliente(ej.persona);
    base = BaseLocal.enMemoria();
    ahora = DateTime(2026, 11, 23, 19, 15);
    cola = ColaSinConexion(
      base: base,
      enviador: EnviadorSupabase(
        cliente,
        tablas: const {},
        upserts: destinosUpsertGimnasio,
        borrados: borradosGimnasio,
      ),
      reloj: () => ahora,
    );
    repo = RepositorioGimnasio(base, cola: cola, reloj: () => ahora);
  });

  tearDown(() async {
    await cola.cerrar();
    await cliente.dispose();
    await base.close();
    await servidor.cerrar();
  });

  Future<RegistroPendiente> registro(String tipo, {int cual = 0}) async =>
      (await cola.registros()).where((r) => r.tipo == tipo).toList()[cual];

  List<PeticionGim> posts(String tabla) => [
    for (final p in servidor.peticiones)
      if (p.metodo == 'POST' && p.tabla == tabla) p,
  ];

  Future<String> unaSesionConUnaSerie() async {
    final ses = (await repo.guardarSesion(ej.persona, ej.sesion())).id;
    await repo.guardarSerie(ej.persona, ej.serie(sesionId: ses));
    return ses;
  }

  group('sin conexión primero, luego sube con el mismo id', () {
    test(
      'con el servidor caído todo queda local y en la cola; no es un error',
      () async {
        servidor.caido = true;
        final ses = await unaSesionConUnaSerie();
        // Local: se lee al instante.
        expect((await repo.sesion(ej.persona, ses))!.estado, 'en_curso');
        expect(await repo.series(ej.persona, ses), hasLength(1));

        final r = await cola.procesar();
        expect(r.enviados, 0);
        expect(r.rechazados, 0);
        expect(await cola.requierenAtencion(), isEmpty);
        expect(servidor.filas, isEmpty);

        // Vuelve la señal (pasa la espera).
        servidor.caido = false;
        ahora = ahora.add(const Duration(hours: 1));
        final r2 = await cola.procesar();
        expect(r2.rechazados, 0);
        expect(r2.restantes, 0);
        final sesionesDelServidor = servidor.de('hab_ent_sesiones', ej.persona);
        expect(sesionesDelServidor.map((s) => s['id']), [ses]);
        expect(servidor.de('hab_ent_series', ej.persona), hasLength(1));
        // La serie subió con SU id v5, el mismo que tiene en el equipo.
        expect(
          servidor.de('hab_ent_series', ej.persona).single['id'],
          (await repo.series(ej.persona, ses)).single.id,
        );
      },
    );

    test(
      'la respuesta se pierde, el servidor sí guardó: el reintento no duplica',
      () async {
        final ses = await unaSesionConUnaSerie();
        servidor.perderRespuestas = 1;
        await cola.procesar();
        ahora = ahora.add(const Duration(minutes: 5));
        await cola.procesar();
        ahora = ahora.add(const Duration(minutes: 5));
        final r = await cola.procesar();
        expect(r.restantes, 0);
        expect(servidor.de('hab_ent_sesiones', ej.persona), hasLength(1));
        expect(servidor.de('hab_ent_series', ej.persona), hasLength(1));
        expect(servidor.de('hab_ent_sesiones', ej.persona).single['id'], ses);
      },
    );

    test('dos equipos registran la misma sesión: mismo id y converge (último gana)', () async {
      // El equipo B (otra base) hace lo mismo con otro contenido y otra hora.
      final baseB = BaseLocal.enMemoria();
      addTearDown(baseB.close);
      var ahoraB = ahora.add(const Duration(minutes: 30));
      final colaB = ColaSinConexion(
        base: baseB,
        enviador: EnviadorSupabase(
          await servidor.cliente(ej.persona),
          tablas: const {},
          upserts: destinosUpsertGimnasio,
          borrados: borradosGimnasio,
        ),
        reloj: () => ahoraB,
      );
      addTearDown(colaB.cerrar);
      final repoB = RepositorioGimnasio(
        baseB,
        cola: colaB,
        reloj: () => ahoraB,
      );

      await repo.guardarSesion(
        ej.persona,
        ej.sesion(estado: 'completa', esfuerzo: 2),
      );
      await repoB.guardarSesion(
        ej.persona,
        ej.sesion(estado: 'completa', esfuerzo: 5),
      );
      expect(
        (await repo.sesionDelDia(ej.persona, '2026-11-23', 'A'))!.id,
        (await repoB.sesionDelDia(ej.persona, '2026-11-23', 'A'))!.id,
      );
      // B (más nuevo) llega primero; A (más viejo) después: se queda el de B.
      await colaB.procesar();
      await cola.procesar();
      final s = servidor.de('hab_ent_sesiones', ej.persona);
      expect(s, hasLength(1));
      expect(s.single['esfuerzo'], 5);
      ahoraB = ahoraB.add(const Duration(minutes: 1));
    });
  });

  group('orden de subida por llaves', () {
    test('creado al revés (series, sesión, banda, perfil), sube en orden en UNA ronda sin 23503', () async {
      final ses = ej.idSesion();
      final banda = IdsGimnasio.banda();
      // Se encolan en el peor orden posible: primero lo que depende de todo.
      await repo.guardarSesion(ej.persona, ej.sesion());
      await repo.guardarBanda(ej.persona, id: banda, nombre: 'Verde', orden: 1);
      await repo.guardarSerie(
        ej.persona,
        ej.serie(sesionId: ses, bandaId: banda),
      );
      await repo.guardarPlanDia(ej.persona, diaSemana: 1, tipo: 'A');
      await repo.guardarItemInventario(
        ej.persona,
        itemId: 'caminadora',
        estado: 'disponible',
      );
      await repo.guardarPerfil(ej.persona, {});

      final r = await cola.procesar();
      expect(
        (r.enviados, r.reintentos, r.rechazados, r.restantes),
        (6, 0, 0, 0),
      );
      final niveles = [
        for (final p in servidor.peticiones.where((p) => p.metodo == 'POST'))
          nivelesDeSubidaGimnasio[p.tabla]!,
      ];
      expect(
        niveles,
        [...niveles]..sort(),
        reason: servidor.ordenDeTablas.join(' > '),
      );
      expect(servidor.ordenDeTablas.last, 'hab_ent_series');
      expect(
        servidor.ordenDeTablas[servidor.ordenDeTablas.length - 2],
        'hab_ent_sesiones',
      );
    });

    test('un borrado sube después de las altas de la ronda', () async {
      final ses = (await repo.guardarSesion(ej.persona, ej.sesion())).id;
      final s1 = await repo.guardarSerie(ej.persona, ej.serie(sesionId: ses));
      await repo.borrarSerie(ej.persona, s1); // deshacer antes de que suba
      await cola.procesar();
      expect(servidor.de('hab_ent_series', ej.persona), isEmpty);
      expect(servidor.ordenDeTablas, [
        'hab_ent_sesiones',
        'hab_ent_series',
        'hab_ent_series#DELETE',
      ]);
    });
  });

  group('contrato de las peticiones', () {
    test('upsert por la llave de cada tabla, con merge-duplicates y sin columnas del servidor', () async {
      final ses = await unaSesionConUnaSerie();
      await repo.guardarPerfil(ej.persona, {});
      await repo.guardarPlanDia(ej.persona, diaSemana: 2, tipo: 'B');
      await repo.guardarItemInventario(
        ej.persona,
        itemId: 'caminadora',
        estado: 'disponible',
      );
      await repo.guardarBanda(ej.persona, nombre: 'Verde', orden: 1);
      await cola.procesar();

      final esperadas = {
        'hab_ent_perfil': 'persona_id',
        'hab_ent_plan_dias': 'persona_id,dia_semana',
        'hab_ent_inventario': 'persona_id,item_id',
        'hab_ent_bandas': 'id',
        'hab_ent_sesiones': 'id',
        'hab_ent_series': 'id',
      };
      for (final e in esperadas.entries) {
        final p = posts(e.key).single;
        expect(p.onConflict, e.value, reason: e.key);
        expect(p.prefer, contains('resolution=merge-duplicates'));
        expect(
          p.fila.keys.toSet().difference(columnasQueSeMandanGimnasio[e.key]!),
          isEmpty,
          reason: 'columnas de más en ${e.key}',
        );
        expect(
          p.fila.keys.toSet().intersection(
            columnasQuePoneElServidorGimnasio[e.key]!,
          ),
          isEmpty,
        );
        expect(p.fila, isNot(contains('tiempos')));
      }
      expect(posts('hab_ent_sesiones').single.fila['id'], ses);
    });

    test(
      'ninguna carga ni petición habla de molestias, zonas o dolor',
      () async {
        await unaSesionConUnaSerie();
        await repo.guardarPerfil(ej.persona, {});
        await cola.procesar();
        for (final r in await cola.registros()) {
          for (final raiz in raicesProhibidasEnCarga) {
            expect(
              r.carga.toLowerCase(),
              isNot(contains(raiz)),
              reason: r.tipo,
            );
          }
        }
        for (final p in servidor.peticiones) {
          final texto = '${p.uri} ${p.cuerpo}'.toLowerCase();
          for (final raiz in raicesProhibidasEnCarga) {
            expect(texto, isNot(contains(raiz)));
          }
        }
      },
    );

    test(
      'editar: se sube en_curso y después completa, con el MISMO id',
      () async {
        final ses = (await repo.guardarSesion(ej.persona, ej.sesion())).id;
        await cola.procesar();
        expect(
          servidor.de('hab_ent_sesiones', ej.persona).single['estado'],
          'en_curso',
        );
        ahora = ahora.add(const Duration(minutes: 45));
        await repo.guardarSesion(
          ej.persona,
          ej.sesion(estado: 'completa', esfuerzo: 4),
        );
        await cola.procesar();
        final s = servidor.de('hab_ent_sesiones', ej.persona).single;
        expect(s['id'], ses);
        expect(s['estado'], 'completa');
        expect(s['esfuerzo'], 4);
        expect(posts('hab_ent_sesiones'), hasLength(2));
      },
    );

    test(
      'deshacer una serie ya subida la borra también en el servidor',
      () async {
        final ses = (await repo.guardarSesion(ej.persona, ej.sesion())).id;
        final s1 = await repo.guardarSerie(ej.persona, ej.serie(sesionId: ses));
        await cola.procesar();
        expect(servidor.de('hab_ent_series', ej.persona), hasLength(1));
        await repo.borrarSerie(ej.persona, s1);
        await cola.procesar();
        expect(servidor.de('hab_ent_series', ej.persona), isEmpty);
        final borrado = servidor.peticiones.last;
        expect(borrado.metodo, 'DELETE');
        expect(borrado.uri.queryParameters['id'], 'eq.$s1');
      },
    );

    test('borrar lo que ya no está no es un error (idempotente)', () async {
      await repo.borrarSerie(ej.persona, IdsGimnasio.banda());
      final r = await cola.procesar();
      expect((r.enviados, r.rechazados), (1, 0));
    });
  });

  group('errores del servidor', () {
    Future<void> permanente(String codigo, ErrorGim error) async {
      servidor.fallar('hab_ent_perfil', error);
      await repo.guardarPerfil(ej.persona, {});
      final r = await cola.procesar();
      expect(
        (r.enviados, r.reintentos, r.rechazados),
        (0, 0, 1),
        reason: codigo,
      );
      final fila = await registro(TipoColaGimnasio.perfil);
      expect(fila.estado, EstadoPendiente.rechazado);
      expect(fila.ultimoError, contains(codigo));
      expect(await cola.requierenAtencion(), hasLength(1));
      // No se reintenta solo.
      final antes = servidor.peticiones.length;
      ahora = ahora.add(const Duration(days: 1));
      await cola.procesar();
      expect(servidor.peticiones, hasLength(antes));
    }

    test(
      '23514 (regla de la tabla): permanente',
      () => permanente(
        '23514',
        const ErrorGim('23514', 'check violation', estado: 400),
      ),
    );

    test(
      '42501 (sin permiso): permanente',
      () => permanente(
        '42501',
        const ErrorGim('42501', 'permission denied', estado: 403),
      ),
    );

    test(
      '54000 (cuota de filas): permanente',
      () => permanente(
        '54000',
        const ErrorGim('54000', 'Se llegó al tope de filas', estado: 400),
      ),
    );

    test(
      'cuota real de bandas (el tope del servidor simulado): permanente',
      () async {
        servidor.topes['hab_ent_bandas'] = 1;
        await repo.guardarBanda(ej.persona, nombre: 'Verde', orden: 1);
        await repo.guardarBanda(ej.persona, nombre: 'Azul', orden: 2);
        final r = await cola.procesar();
        expect((r.enviados, r.rechazados), (1, 1));
        expect(
          (await cola.requierenAtencion()).single.ultimoError,
          contains('54000'),
        );
      },
    );

    test('23505 con OTRO id (mismo día y plantilla): permanente, sin datos en el mensaje', () async {
      // Otro dispositivo (versión vieja) ya subió esa sesión con otro id.
      servidor.filas['hab_ent_sesiones'] = {
        '${ej.persona}|${IdsGimnasio.banda()}': {
          'id': IdsGimnasio.banda(),
          'fecha': '2026-11-23',
          'plantilla': 'A',
          'modificado_en': '2026-11-23T00:00:00Z',
        },
      };
      await repo.guardarSesion(ej.persona, ej.sesion());
      final r = await cola.procesar();
      expect((r.enviados, r.reintentos, r.rechazados), (0, 0, 1));
      final fila = await registro(TipoColaGimnasio.sesion);
      expect(fila.estado, EstadoPendiente.rechazado);
      expect(fila.ultimoError, contains('23505'));
      expect(fila.ultimoError, isNot(contains(ej.persona)));
      // La serie que depende de esa sesión no se pierde: espera (23503).
      final ses = ej.idSesion();
      await repo.guardarSerie(ej.persona, ej.serie(sesionId: ses));
      ahora = ahora.add(const Duration(minutes: 1));
      final r2 = await cola.procesar();
      expect(r2.rechazados, 0);
      expect(r2.reintentos, 1);
    });

    test('23503 (falta la sesión de la serie): se reintenta; no requiere atención y no detiene la ronda', () async {
      // La serie se encola sola, sin su sesión (otro equipo la sube después).
      final ses = ej.idSesion();
      await repo.guardarSerie(ej.persona, ej.serie(sesionId: ses));
      await repo.guardarPerfil(ej.persona, {});
      final r = await cola.procesar();
      expect((r.enviados, r.reintentos, r.rechazados), (1, 1, 0));
      final s = await registro(TipoColaGimnasio.serie);
      expect(s.estado, EstadoPendiente.pendiente);
      expect(s.ultimoError, contains('23503'));
      expect(await cola.requierenAtencion(), isEmpty);

      // Llega la sesión (otro equipo) y, pasada la espera, la serie sube.
      servidor.filas['hab_ent_sesiones'] = {
        '${ej.persona}|$ses': {
          'id': ses,
          'modificado_en': '2026-11-23T00:00:00Z',
        },
      };
      ahora = ahora.add(const Duration(minutes: 1));
      final r2 = await cola.procesar();
      expect((r2.enviados, r2.restantes), (1, 0));
    });

    test(
      '23503 (el bloque de la agenda aún no existe): se reintenta y luego sube',
      () async {
        final bloque = IdsGimnasio.banda();
        await repo.guardarSesion(ej.persona, ej.sesion(bloqueId: bloque));
        await cola.procesar();
        expect(
          (await registro(TipoColaGimnasio.sesion)).estado,
          EstadoPendiente.pendiente,
        );
        servidor.bloques.add(bloque);
        ahora = ahora.add(const Duration(minutes: 1));
        await cola.procesar();
        expect(servidor.de('hab_ent_sesiones', ej.persona), hasLength(1));
        expect(
          (await registro(TipoColaGimnasio.sesion)).estado,
          EstadoPendiente.enviado,
        );
      },
    );

    test('un servidor caído (503) se reintenta con espera creciente, nunca se rechaza', () async {
      await repo.guardarPerfil(ej.persona, {});
      servidor.caido = true;
      for (var i = 0; i < 5; i++) {
        await cola.procesar();
        ahora = ahora.add(const Duration(hours: 1));
      }
      expect(await cola.requierenAtencion(), isEmpty);
      expect(
        (await registro(TipoColaGimnasio.perfil)).estado,
        EstadoPendiente.pendiente,
      );
    });
  });

  group('la tablet pública no sube lo personal solo con el nombre (D14)', () {
    test(
      'el tipo habitos.gim_* es personal: encolar con origen de la casa lanza',
      () async {
        expect(
          () => cola.encolar(
            tipo: TipoColaGimnasio.sesion,
            carga: ej.sesion(),
            personaId: ej.persona,
            origen: OrigenRegistro.tabletCasa,
          ),
          throwsArgumentError,
        );
      },
    );
  });

  group('sin sesión no se envía nada', () {
    test(
      'sin sesión del servidor, el enviador espera y no cuenta intentos',
      () async {
        final sinSesion = SupabaseClient(
          servidor.url,
          'llave-publica-de-prueba',
        );
        addTearDown(sinSesion.dispose);
        final c = ColaSinConexion(
          base: base,
          enviador: EnviadorSupabase(
            sinSesion,
            tablas: const {},
            upserts: destinosUpsertGimnasio,
          ),
          reloj: () => ahora,
        );
        addTearDown(c.cerrar);
        await repo.guardarPerfil(ej.persona, {});
        await c.procesar();
        expect(servidor.peticiones, isEmpty);
        expect((await registro(TipoColaGimnasio.perfil)).intentos, 0);
      },
    );
  });
}
