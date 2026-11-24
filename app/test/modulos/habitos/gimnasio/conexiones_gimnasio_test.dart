// Lo que «Mi gimnasio» conecta con lo demás: el lector del servidor (sin
// conexión funciona con lo local), la fusión entre equipos, Hoy y
// `habitos.resumen_hoy`.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/avisos/con_avisos.dart'
    show tipoEquipoAvisosProvider;
import 'package:gravity/app/dispositivo.dart' show tipoDispositivoProvider;
import 'package:gravity/app/gimnasio/proveedores_gimnasio.dart'
    show
        molestiasLocalesProvider,
        personaEnPantallaProvider,
        repositorioGimnasioProvider;
import 'package:gravity/diseno/proveedores.dart'
    show RelojFijo, relojProvider;
import 'package:gravity/modulos/habitos/casos_uso/servicio_eliminar.dart';
import 'package:gravity/modulos/habitos/casos_uso/servicio_habitos.dart';
import 'package:gravity/modulos/habitos/datos/documentos_sensibles.dart';
import 'package:gravity/nucleo/sensibles/llaves_habitos.dart';
import 'package:gravity/nucleo/sensibles/sobres.dart';
import 'package:gravity/nucleo/sensibles/subida_diferida.dart';
import 'package:gravity/modulos/habitos/estado/proveedores.dart';
import 'package:gravity/modulos/habitos/gimnasio/casos_uso/servicio_gimnasio.dart';
import 'package:gravity/modulos/habitos/gimnasio/datos/lector_gimnasio.dart';
import 'package:gravity/modulos/habitos/gimnasio/casos_uso/modo_foco.dart';
import 'package:gravity/modulos/habitos/gimnasio/estado/proveedores_gimnasio.dart';
import 'package:gravity/modulos/habitos/gimnasio/pantallas/comun.dart' show TextosHabitosGimnasio;
import 'package:gravity/modulos/habitos/habitos.dart' show consultaLocalHabitos;
import 'package:gravity/modulos/habitos/pantallas/hoy.dart';
import 'package:gravity/nucleo/avisos/repositorio_avisos.dart'
    show TipoEquipoAvisos;
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/gimnasio/repositorio_gimnasio.dart';
import 'package:gravity/nucleo/seguridad/proveedores_seguridad.dart'
    show almacenSeguroProvider;
import 'package:gravity/nucleo/sesion/proveedores_sesion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_falso.dart';
import 'package:go_router/go_router.dart';
import 'package:habitos_dominio/habitos_dominio.dart' hide EstadoDiaPlan;

import 'ayuda_gimnasio_app.dart';

/// Un servidor de mentira: tablas con filas en la forma de PostgREST.
LectorGimnasio servidorCon(Map<String, List<Map<String, Object?>>> tablas) =>
    LectorGimnasioDeTablas(
      (tabla, desde, a) async => [
        ...(tablas[tabla] ?? const []).skip(desde).take(a - desde + 1),
      ],
      tramo: 2,
    );

void main() {
  group('el lector del servidor', () {
    test('lee las seis tablas por tramos', () async {
      final l = servidorCon({
        'hab_ent_sesiones': [
          for (var i = 0; i < 5; i++) {'id': 'id$i'},
        ],
        'hab_ent_perfil': [
          {'dias_plan': 3},
        ],
      });
      final f = (await l.leer())!;
      expect(f.sesiones, hasLength(5)); // pidió 3 tramos de 2
      expect(f.perfil, hasLength(1));
      expect(f.series, isEmpty);
      expect(f.total, 6);
    });

    test('sin conexión devuelve null y no revienta', () async {
      final l = LectorGimnasioDeTablas(
        (tabla, desde, a) => throw const SocketException('sin red'),
      );
      expect(await l.leer(), isNull);
    });

    test('bajar del servidor fusiona con lo local; sin conexión se sigue con lo local', () async {
      // El equipo A hizo una sesión; el servidor la guarda como la entrega
      // PostgREST (con las columnas del servidor).
      final a = Mundo();
      addTearDown(a.cerrar);
      final h = await a.servicio.entrenamientoDe(lunes30);
      await a.servicio.registrarDespues(
        h: h,
        hecho: [
          for (final e in h.sesion!.ejercicios)
            (
              ejercicio: e,
              series: 2,
              reps: e.objetivo,
              cargaPasos: 3,
              bandaId: null,
            ),
        ],
        completa: true,
        esfuerzo: 3,
      );
      final sesiones = [
        for (final s in await a.repo.sesiones(persona))
          {...s.aMapaServidor(), 'persona_id': persona, 'hogar_id': 'h1'},
      ];
      final series = [
        for (final s in await a.repo.todasLasSeries(persona))
          {...s.aMapaServidor(), 'persona_id': persona, 'hogar_id': 'h1'},
      ];

      final b = Mundo(
        lector: servidorCon({
          'hab_ent_sesiones': sesiones,
          'hab_ent_series': series,
        }),
      );
      addTearDown(b.cerrar);
      expect(await b.repo.sesiones(persona), isEmpty);
      expect(await b.servicio.bajarDelServidor(), isTrue);
      expect(await b.repo.sesiones(persona), hasLength(1));
      expect(
        (await b.repo.todasLasSeries(persona)).length,
        series.length,
      );
      // El historial del dominio ya lo ve el generador.
      final d = await b.servicio.cargar();
      expect(d.historial, hasLength(1));
      expect(d.historial.single.series, isNotEmpty);

      // Sin conexión: lo local sigue ahí y la app no cambia.
      final c = Mundo(
        lector: LectorGimnasioDeTablas((t, d, a) => throw StateError('caído')),
      );
      addTearDown(c.cerrar);
      await c.repo.guardarPerfil(persona, {'dias_plan': 4});
      expect(await c.servicio.bajarDelServidor(), isFalse);
      expect((await c.repo.perfil(persona))!.diasPlan, 4);
    });

    test('lo que baja nunca trae molestias: no hay columna para ellas', () {
      const f = FilasGimnasioServidor();
      expect(f.total, 0);
    });
  });

  group('dos equipos que registran series intercaladas convergen (CA-G-34)', () {
    test('mismos ids v5: el estado es el mismo en ambos', () async {
      final a = Mundo();
      final b = Mundo();
      addTearDown(a.cerrar);
      addTearDown(b.cerrar);
      final h = await a.servicio.entrenamientoDe(lunes30);
      final e = h.sesion!.ejercicios.first;
      final fila = await a.servicio.iniciarSesion(h);
      final filaB = await b.servicio.iniciarSesion(h);
      expect(fila.id, filaB.id); // el mismo día y plantilla, el mismo id

      Future<void> serie(Mundo m, String sesion, int n) =>
          m.servicio.registrarSerie(
            sesionId: sesion,
            ejercicio: e,
            varianteId: e.varianteId,
            n: n,
            reps: 10 + n,
            cargaPasos: 4,
          );
      await serie(a, fila.id, 1);
      await serie(a, fila.id, 3);
      await serie(b, fila.id, 2);

      Future<void> intercambiar(Mundo de, Mundo a) async {
        await a.repo.fusionarDelServidor(
          persona,
          sesiones: [
            for (final s in await de.repo.sesiones(persona))
              s.aMapaServidor(),
          ],
          series: [
            for (final s in await de.repo.todasLasSeries(persona))
              s.aMapaServidor(),
          ],
        );
      }

      await intercambiar(a, b);
      await intercambiar(b, a);
      List<(int, int?)> estado(List<dynamic> filas) => [
        for (final s in filas..sort((x, y) => (x.n as int).compareTo(y.n as int)))
          (s.n as int, s.reps as int?),
      ];
      final sa = estado(await a.repo.todasLasSeries(persona));
      final sb = estado(await b.repo.todasLasSeries(persona));
      expect(sa, sb);
      expect(sa.map((x) => x.$1), [1, 2, 3]);
    });
  });

  group('Hoy y habitos.resumen_hoy', () {
    Future<ProviderContainer> contenedor(Mundo m) async {
      final c = ProviderContainer(
        overrides: [
          servicioSesionProvider.overrideWithValue(ServicioSesionFalso()),
          personaEnPantallaProvider.overrideWithValue(persona),
          repositorioGimnasioProvider.overrideWithValue(m.repo),
          repositorioAgendaProvider.overrideWithValue(m.agenda),
          repositorioHabitosProvider.overrideWithValue(m.registros),
          servicioHabitosProvider.overrideWithValue(
            ServicioHabitos(m.registros, ahora: () => m.ahoraActual),
          ),
          molestiasLocalesProvider.overrideWithValue(m.molestias),
          almacenSeguroProvider.overrideWithValue(m.almacen),
          relojProvider.overrideWithValue(RelojFijo(m.ahoraActual)),
          modoFocoActivoProvider.overrideWith((ref) async => const SinModoFoco()),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('el resumen cuenta el entrenamiento como un elemento más, sin detalles', () async {
      final m = Mundo();
      addTearDown(m.cerrar);
      final c = await contenedor(m);
      expect(await c.read(consultaLocalHabitos.future), 'Hoy llevas 0 de 1.');
      final h = await m.servicio.entrenamientoDe(lunes30);
      await m.servicio.marcarHecho(h);
      c.read(versionGimnasioProvider.notifier).state++;
      expect(await c.read(consultaLocalHabitos.future), 'Hoy llevas 1 de 1.');
    });

    test('el objetivo «Entrenamiento» no se cuenta dos veces', () async {
      final m = Mundo();
      addTearDown(m.cerrar);
      await m.servicio.ponerEnMiAgenda(await m.servicio.cargar());
      final c = await contenedor(m);
      // El objetivo existe y programa hoy, pero el resumen no lo duplica.
      expect(
        (await m.registros.objetivos()).any(
          (o) => o.id == idObjetivoEntrenamiento(persona),
        ),
        isTrue,
      );
      expect(await c.read(consultaLocalHabitos.future), 'Hoy llevas 0 de 1.');
    });

    test('un día de bicicleta o de descanso no suma nada', () async {
      final m = Mundo(ahora: DateTime(2026, 12, 6, 10));
      addTearDown(m.cerrar);
      final c = await contenedor(m);
      expect(
        await c.read(consultaLocalHabitos.future),
        MensajesHabitos.diaLibre,
      );
    });

    test('el resumen no lleva cargas, series ni molestias', () async {
      final m = Mundo();
      addTearDown(m.cerrar);
      await m.molestias.guardar(
        Molestia(
          id: 'm',
          zona: Zonas.rodilla,
          intensidad: 2,
          desde: DateTime.utc(2026, 11, 28),
        ),
      );
      final c = await contenedor(m);
      final t = await c.read(consultaLocalHabitos.future);
      expect(RegExp(r'^Hoy llevas \d+ de \d+\.$').hasMatch(t), isTrue);
    });

    testWidgets('Hoy de Hábitos muestra la tarjeta (una vez vista la guía) y no el objetivo', (
      t,
    ) async {
      final m = Mundo();
      addTearDown(m.cerrar);
      await m.servicio.aceptarAviso();
      await m.servicio.ponerEnMiAgenda(await m.servicio.cargar());
      t.view.physicalSize = const Size(400, 3000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            servicioSesionProvider.overrideWithValue(ServicioSesionFalso()),
            tipoDispositivoProvider.overrideWithValue(TipoDispositivo.telefono),
            tipoEquipoAvisosProvider.overrideWithValue(
              TipoEquipoAvisos.telefono,
            ),
            personaEnPantallaProvider.overrideWithValue(persona),
            repositorioGimnasioProvider.overrideWithValue(m.repo),
            repositorioAgendaProvider.overrideWithValue(m.agenda),
            repositorioHabitosProvider.overrideWithValue(m.registros),
            servicioHabitosProvider.overrideWithValue(
              ServicioHabitos(m.registros, ahora: () => m.ahoraActual),
            ),
            molestiasLocalesProvider.overrideWithValue(m.molestias),
            almacenSeguroProvider.overrideWithValue(m.almacen),
            relojProvider.overrideWithValue(RelojFijo(m.ahoraActual)),
            modoFocoActivoProvider.overrideWith(
              (ref) async => const SinModoFoco(),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: GoRouter(
              routes: [
                GoRoute(path: '/', builder: (_, _) => const PantallaHoyHabitos()),
                GoRoute(
                  path: '/habitos/entrenamiento',
                  builder: (_, _) => const Scaffold(body: Text('E1')),
                ),
              ],
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              (w.data ?? '').toLowerCase() == 'entrenamiento de hoy',
        ),
        findsWidgets,
      );
      expect(find.byKey(const ValueKey('entrenamiento-hecho')), findsOneWidget);
      // El objetivo «Entrenamiento» no sale como un hábito más.
      expect(find.text('Entrenamiento'), findsOneWidget); // solo la entrada
      // Hecho en Hoy es un toque.
      await t.tap(find.byKey(const ValueKey('entrenamiento-hecho')));
      await t.pumpAndSettle();
      expect((await m.repo.sesiones(persona)).single.estado, 'completa');
    });
  });

  group('el modo foco se renueva al abrir lo reservado (CA-G-43)', () {
    test('abrir lo reservado deja la copia local y el gimnasio la lee', () async {
      final m = Mundo();
      addTearDown(m.cerrar);
      final almacen = m.almacen;
      final eliminar = ServicioHabitoEliminar(
        DocumentosSensibles(
          llaves: LlavesHabitos(almacen),
          sobres: AlmacenDeSobres(almacen),
          modos: ModosLocales(almacen),
          persona: persona,
          ahora: () => m.ahoraActual,
        ),
        ahora: () => m.ahoraActual,
      );
      // Día D el 25/nov con 14 días de foco: del 25/nov al 8/dic.
      await eliminar.configurar(
        ConfigHabito(
          tipo: TipoHabito.cigarrillo,
          inicio: DateTime.utc(2026, 10, 28),
          diaD: DateTime.utc(2026, 11, 25),
        ),
      );
      final c = ProviderContainer(
        overrides: [
          servicioSesionProvider.overrideWithValue(ServicioSesionFalso()),
          personaEnPantallaProvider.overrideWithValue(persona),
          almacenSeguroProvider.overrideWithValue(almacen),
          servicioEliminarProvider.overrideWithValue(eliminar),
        ],
      );
      addTearDown(c.dispose);
      // Aún sin copia: se intenta leer una vez; con la llave local se puede.
      var foco = await c.read(modoFocoActivoProvider.future);
      expect(foco.legible, isTrue);
      expect(foco.para(DateTime.utc(2026, 11, 30)), isTrue);
      expect(foco.para(DateTime.utc(2026, 12, 9)), isFalse);
      // Cambia el Día D y se vuelve a abrir lo reservado.
      await eliminar.configurar(
        ConfigHabito(
          tipo: TipoHabito.cigarrillo,
          inicio: DateTime.utc(2026, 10, 28),
          diaD: DateTime.utc(2026, 12, 20),
        ),
      );
      await c.read(estadoEliminarProvider(TipoHabito.cigarrillo).future);
      c.read(versionHabitosProvider.notifier).state++;
      foco = await c.read(modoFocoActivoProvider.future);
      expect(foco.para(DateTime.utc(2026, 11, 30)), isFalse);
      expect(foco.para(DateTime.utc(2026, 12, 21)), isTrue);
      // La copia no dice qué hábito es.
      final copiaGuardada = almacen.datos.values
          .where((v) => v.contains('gim_foco'))
          .join();
      expect(copiaGuardada, isNotEmpty);
      expect(copiaGuardada.contains('cigarrillo'), isFalse);
      expect(copiaGuardada.contains('azucar'), isFalse);
    });

    test('sin la llave en este equipo: falso y lo dice', () async {
      final m = Mundo();
      addTearDown(m.cerrar);
      final almacen = m.almacen;
      final eliminar = ServicioHabitoEliminar(
        DocumentosSensibles(
          llaves: LlavesHabitos(almacen, permitido: () => false),
          sobres: AlmacenDeSobres(almacen),
          modos: ModosLocales(almacen),
          persona: persona,
        ),
      );
      final c = ProviderContainer(
        overrides: [
          servicioSesionProvider.overrideWithValue(ServicioSesionFalso()),
          personaEnPantallaProvider.overrideWithValue(persona),
          almacenSeguroProvider.overrideWithValue(almacen),
          servicioEliminarProvider.overrideWithValue(eliminar),
        ],
      );
      addTearDown(c.dispose);
      final foco = await c.read(modoFocoActivoProvider.future);
      expect(foco.legible, isFalse);
      expect(foco.para(DateTime.utc(2026, 11, 30)), isFalse);
    });
  });

  group('sin IA ni Health Connect (CA-G-39) y tono (CA-G-40)', () {
    List<File> archivos() => [
      for (final f in Directory(
        'lib/modulos/habitos/gimnasio',
      ).listSync(recursive: true))
        if (f is File && f.path.endsWith('.dart')) f,
    ];

    test('ningún archivo del gimnasio llama a una IA, a la red ni a Health Connect', () {
      for (final f in archivos()) {
        final t = f.readAsStringSync();
        for (final prohibido in const [
          'gravity-asistente',
          'asistente/',
          'package:http',
          'package:dio',
          'health_connect',
          'package:health',
          'HealthConnect',
          'dart:io',
        ]) {
          expect(
            t.contains(prohibido),
            isFalse,
            reason: '${f.path} menciona $prohibido',
          );
        }
      }
    });

    test('el lector solo lee: ninguna escritura al servidor', () {
      final t = File(
        'lib/modulos/habitos/gimnasio/datos/lector_gimnasio.dart',
      ).readAsStringSync();
      for (final w in ['.insert(', '.upsert(', '.update(', '.delete(', '.rpc(']) {
        expect(t.contains(w), isFalse, reason: w);
      }
    });

    test('ningún texto de las pantallas culpa ni usa signos de exclamación', () {
      final comillas = RegExp(r'''(?:'([^'\n]{3,})')|(?:"([^"\n]{3,})")''');
      for (final f in archivos()) {
        for (final m in comillas.allMatches(f.readAsStringSync())) {
          // Sin lo que va dentro de ${…}: ahí hay código, no texto.
          final texto = (m.group(1) ?? m.group(2))!.replaceAll(
            RegExp(r'\$\{[^}]*\}'),
            '',
          );
          expect(texto.contains('!'), isFalse, reason: '${f.path}: $texto');
          for (final p in MensajesHabitos.prohibidas) {
            expect(
              texto.toLowerCase().contains(p.toLowerCase()),
              isFalse,
              reason: '${f.path}: $texto',
            );
          }
        }
      }
    });

    test('los textos nuevos pasan la revisión de tono', () {
      for (final t in TextosHabitosGimnasio.todos) {
        expect(t.contains('!'), isFalse, reason: t);
        for (final p in MensajesHabitos.prohibidas) {
          expect(t.toLowerCase().contains(p.toLowerCase()), isFalse, reason: t);
        }
      }
    });

    test('ninguna pantalla nombra diagnóstico, tratamiento ni medicamento', () {
      final t = [for (final f in archivos()) f.readAsStringSync()].join(' ');
      // Lo mismo que revisa el dominio, sobre lo que escriben las pantallas.
      final textos = RegExp(r"'([^'\n]{3,})'")
          .allMatches(t)
          .map((m) => m.group(1)!)
          .toList();
      expect(validarContenidoMedico(textos), isEmpty);
    });
  });
}
