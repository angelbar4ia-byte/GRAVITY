// Avisos de la Fase 2 (D20): catálogo discreto, preferencias, recepción por
// FCM simulado, reglas por equipo y recordatorios locales.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/avisos/aviso.dart';
import 'package:gravity/nucleo/avisos/catalogo_avisos.dart';
import 'package:gravity/nucleo/avisos/fuente_push.dart';
import 'package:gravity/nucleo/avisos/notificador.dart';
import 'package:gravity/nucleo/avisos/recordatorios.dart';
import 'package:gravity/nucleo/avisos/repositorio_avisos.dart';
import 'package:gravity/nucleo/avisos/servicio_avisos.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';

const uuid = '3f2b8a52-6f0e-4b1b-9c52-1d7d5a2b9e10';

Aviso aviso({
  String id = uuid,
  String tipo = 'pago_proximo',
  String? clave,
  EstadoAviso estado = EstadoAviso.pendiente,
}) => Aviso(
  id: id,
  tipo: tipo,
  clave: clave ?? '$tipo:o1:2026-11-12:1',
  estado: estado,
  creadoEn: DateTime.utc(2026, 11, 1),
);

void main() {
  group('catálogo discreto (reglas 42 y 43)', () {
    test('todo título: máximo 40 caracteres, sin dígitos, sin "\$"', () {
      for (final e in titulosDeAviso.entries) {
        expect(
          textoDeAvisoEsDiscreto(e.value),
          isTrue,
          reason: '${e.key}: ${e.value}',
        );
      }
      expect(textoDeAvisoEsDiscreto(textoAvisoGenerico), isTrue);
      expect(textoDeAvisoEsDiscreto(textoAvisoPublico), isTrue);
      expect(textoDeAvisoEsDiscreto('Pagas \$500'), isFalse);
      expect(textoDeAvisoEsDiscreto('Vence en 3 días'), isFalse);
      expect(textoDeAvisoEsDiscreto('x' * 41), isFalse);
    });

    test('todo tipo tiene severidad y canal, y la lista es la de la especificación', () {
      expect(titulosDeAviso.keys.toSet(), severidadDeAviso.keys.toSet());
      expect(titulosDeAviso, hasLength(29));
      expect(canalDe('compra_papa_albacea'), CanalAviso.avisos);
      expect(canalDe('reposicion_suplemento'), CanalAviso.avisos);
      expect(canalDe('votacion_abierta'), CanalAviso.informativos);
      expect(canalDe('votacion_empate'), CanalAviso.informativos);
      expect(avisosDeAlimentacion.every(titulosDeAviso.containsKey), isTrue);
      expect(canalDe('pago_proximo'), CanalAviso.urgentes);
      expect(canalDe('partida_100'), CanalAviso.avisos);
      expect(canalDe('partida_80'), CanalAviso.informativos);
      expect(canalDe('resumen_lunes'), CanalAviso.resumen);
      expect(canalDe('recordatorio_cierre'), CanalAviso.resumen);
      expect(CanalAviso.values.map((c) => c.nombre), [
        'Finanzas · Urgentes',
        'Finanzas · Avisos',
        'Finanzas · Informativos',
        'Finanzas · Resumen',
        'Hábitos · Recordatorios',
        'Hábitos · Reservados',
        'Hábitos · Revisión',
      ]);
    });

    test('los títulos de Alimentación no llevan dígitos ni nombres', () {
      for (final tipo in avisosDeAlimentacion) {
        final t = titulosDeAviso[tipo]!;
        expect(RegExp(r'[0-9]').hasMatch(t), isFalse, reason: t);
        expect(textoDeAvisoEsDiscreto(t), isTrue, reason: t);
        for (final nombre in ['Papá', 'Mamá', 'Alex', 'Familiar']) {
          expect(t, isNot(contains(nombre)), reason: t);
        }
      }
    });

    test(
      'un tipo desconocido se muestra como el genérico, nunca como texto ajeno',
      () {
        expect(tituloDeAviso('inventado'), textoAvisoGenerico);
        expect(tituloDeAviso(null), textoAvisoGenerico);
      },
    );

    test(
      'id de la notificación: hash estable de la clave, sin choques simples',
      () {
        final a = idDeNotificacion('pago_proximo:o1:2026-11-12:1');
        expect(idDeNotificacion('pago_proximo:o1:2026-11-12:1'), a);
        expect(a, inInclusiveRange(0, 0x7FFFFFFF));
        expect(idDeNotificacion('pago_proximo:o1:2026-11-12:2'), isNot(a));
        final ids = {
          for (var i = 0; i < 2000; i++) idDeNotificacion('clave:$i'),
        };
        expect(ids.length, greaterThan(1990));
      },
    );

    test('ningún archivo de los avisos arma un cuerpo con datos', () {
      for (final archivo in Directory(
        'lib/nucleo/avisos',
      ).listSync().whereType<File>()) {
        final texto = archivo.readAsStringSync();
        expect(
          RegExp(r'cuerpo:\s*[^\s,)]').hasMatch(texto),
          isFalse,
          reason: archivo.path,
        );
      }
    });
  });

  group('MensajePush: solo {v, id}', () {
    test('acepta la forma exacta', () {
      expect(MensajePush.desdeDatos({'v': '1', 'id': uuid})?.id, uuid);
      expect(MensajePush.desdeDatos({'v': 1, 'id': uuid})?.id, uuid);
    });

    test('rechaza versión distinta, id que no es uuid o ausente', () {
      expect(MensajePush.desdeDatos({'v': '2', 'id': uuid}), isNull);
      expect(MensajePush.desdeDatos({'id': uuid}), isNull);
      expect(MensajePush.desdeDatos({'v': '1', 'id': 'hola'}), isNull);
      expect(
        MensajePush.desdeDatos({'v': '1', 'id': 'Pago de \$500 a BBVA'}),
        isNull,
      );
      expect(MensajePush.desdeDatos({'v': '1'}), isNull);
    });
  });

  group('preferencias', () {
    test('horas silenciosas que cruzan la medianoche', () {
      const p = PreferenciasAvisos();
      expect(p.enSilencio(const HoraDelDia(22)), isTrue);
      expect(p.enSilencio(const HoraDelDia(23, 59)), isTrue);
      expect(p.enSilencio(const HoraDelDia(3)), isTrue);
      expect(p.enSilencio(const HoraDelDia(6, 59)), isTrue);
      expect(p.enSilencio(const HoraDelDia(7)), isFalse);
      expect(p.enSilencio(const HoraDelDia(21, 59)), isFalse);
      expect(
        p
            .copiarCon(
              silencioDesde: const HoraDelDia(13),
              silencioHasta: const HoraDelDia(15),
            )
            .enSilencio(const HoraDelDia(14)),
        isTrue,
      );
    });

    test(
      'ida y vuelta por JSON y valores por omisión de la especificación',
      () {
        const p = PreferenciasAvisos();
        expect(p.topeNoCriticas, 3);
        expect(p.diasAvisoDeuda, [3, 1]);
        expect(p.criticasEnSilencio, isFalse);
        expect(p.horaVencimientos, const HoraDelDia(9));
        final otra = p.copiarCon(
          topeNoCriticas: 5,
          tiposSilenciados: {'partida_80'},
          criticasEnSilencio: true,
        );
        final vuelta = PreferenciasAvisos.desdeJson(
          (jsonDecode(jsonEncode(otra.aJson())) as Map).cast<String, Object?>(),
        );
        expect(vuelta.topeNoCriticas, 5);
        expect(vuelta.tiposSilenciados, {'partida_80'});
        expect(vuelta.criticasEnSilencio, isTrue);
        expect(
          PreferenciasAvisos.desdeJson({}).silencioDesde,
          const HoraDelDia(22),
        );
      },
    );

    test('validación de rangos', () {
      const p = PreferenciasAvisos();
      expect(p.error, isNull);
      expect(p.copiarCon(topeNoCriticas: 11).error, isNotNull);
      expect(p.copiarCon(topeNoCriticas: -1).error, isNotNull);
      expect(p.copiarCon(recordatorioCierreDia: 8).error, isNotNull);
      expect(p.copiarCon(diasAvisoDeuda: [1, 2, 3, 4]).error, isNotNull);
      expect(p.copiarCon(diasAvisoDeuda: [15]).error, isNotNull);
      expect(HoraDelDia.desdeTexto('22:00:00'), const HoraDelDia(22));
      expect(HoraDelDia.desdeTexto('25:00'), isNull);
    });
  });

  group('decidirPresentacion', () {
    const p = PreferenciasAvisos();
    Presentacion decide(
      String tipo,
      HoraDelDia hora, {
      int hoy = 0,
      PreferenciasAvisos? prefs,
    }) => decidirPresentacion(
      tipo: tipo,
      preferencias: prefs ?? p,
      ahora: hora,
      noCriticasHoy: hoy,
    );

    test('una crítica suena de día y llega en silencio de noche', () {
      expect(decide('pago_proximo', const HoraDelDia(12)), Presentacion.sonar);
      expect(
        decide('pago_proximo', const HoraDelDia(23)),
        Presentacion.silenciosa,
      );
      expect(
        decide(
          'pago_proximo',
          const HoraDelDia(23),
          prefs: p.copiarCon(criticasEnSilencio: true),
        ),
        Presentacion.sonar,
      );
    });

    test('Cuidados: toma, comida y cambio urgente suenan también de noche', () {
      for (final t in [
        'recordatorio_toma',
        'recordatorio_comida',
        'cambio_urgente_cuidados',
      ]) {
        expect(decide(t, const HoraDelDia(23), hoy: 99), Presentacion.sonar);
        expect(decide(t, const HoraDelDia(3)), Presentacion.sonar);
      }
      // La entrega de turno (informativa) sí respeta el silencio.
      expect(
        decide('entrega_turno', const HoraDelDia(23)),
        Presentacion.silenciosa,
      );
    });

    test('las críticas no tienen tope', () {
      expect(
        decide('pago_vencido', const HoraDelDia(12), hoy: 99),
        Presentacion.sonar,
      );
    });

    test(
      'del tercer aviso no crítico en adelante se agrupa (no sale de la app)',
      () {
        expect(
          decide('partida_80', const HoraDelDia(12), hoy: 2),
          Presentacion.sonar,
        );
        expect(
          decide('partida_80', const HoraDelDia(12), hoy: 3),
          Presentacion.soloBandeja,
        );
        expect(
          decide('fondo_bajo', const HoraDelDia(12), hoy: 3),
          Presentacion.soloBandeja,
        );
      },
    );

    test('los fijos (resumen y cierre) no cuentan para el tope', () {
      expect(
        decide('resumen_lunes', const HoraDelDia(8), hoy: 9),
        Presentacion.sonar,
      );
      expect(
        decide('recordatorio_cierre', const HoraDelDia(19), hoy: 9),
        Presentacion.sonar,
      );
    });

    test('tope 0: nada no crítico sale de la app', () {
      expect(
        decide(
          'partida_80',
          const HoraDelDia(12),
          prefs: p.copiarCon(topeNoCriticas: 0),
        ),
        Presentacion.soloBandeja,
      );
    });

    test(
      'un tipo silenciado solo queda en la bandeja, también si es crítico',
      () {
        final s = p.copiarCon(tiposSilenciados: {'pago_proximo'});
        expect(
          decide('pago_proximo', const HoraDelDia(12), prefs: s),
          Presentacion.soloBandeja,
        );
      },
    );
  });

  group('ServicioAvisos con FCM simulado', () {
    late NotificadorEnMemoria notificador;
    late FuentePushFalsa push;
    late RepositorioAvisosEnMemoria repo;
    late AlmacenSeguroEnMemoria almacen;
    late ContextoAvisos contexto;
    late ServicioAvisos servicio;
    late List<String?> abiertos;
    var reloj = (fecha: DateTime(2026, 11, 3), hora: const HoraDelDia(12));

    ServicioAvisos crear({RepositorioAvisos? Function()? repositorio}) =>
        ServicioAvisos(
          notificador: notificador,
          fuentePush: push,
          repositorio: repositorio ?? () => repo,
          almacen: almacen,
          contexto: () => contexto,
          alAbrirAviso: abiertos.add,
          reloj: (_) => reloj,
          esperaMaximaDeLectura: const Duration(milliseconds: 200),
        );

    setUp(() {
      notificador = NotificadorEnMemoria();
      push = FuentePushFalsa();
      repo = RepositorioAvisosEnMemoria();
      almacen = AlmacenSeguroEnMemoria();
      abiertos = [];
      reloj = (fecha: DateTime(2026, 11, 3), hora: const HoraDelDia(12));
      contexto = const ContextoAvisos(
        tipo: TipoEquipoAvisos.telefono,
        personaId: 'ana',
      );
      servicio = crear();
    });

    Future<void> llegar([String id = uuid]) async {
      await servicio.alRecibirPush(MensajePush(id));
    }

    test('lee el aviso y muestra el título del catálogo, sin cuerpo', () async {
      repo.agregar(aviso());
      await llegar();
      final n = notificador.visibles.values.single;
      expect(n.titulo, 'Tienes un pago próximo');
      expect(n.cuerpo, isEmpty);
      expect(n.canal, CanalAviso.urgentes);
      expect(n.sonar, isTrue);
      expect(n.carga, uuid);
      expect(n.id, idDeNotificacion('pago_proximo:o1:2026-11-12:1'));
    });

    test('FCM simulado de punta a punta: {v, id} → notificación', () async {
      repo.agregar(aviso());
      await servicio.iniciar();
      push.recibir({'v': '1', 'id': uuid});
      await pumpEventQueue();
      expect(
        notificador.visibles.values.single.titulo,
        'Tienes un pago próximo',
      );
      // Un mensaje con texto en vez de {v, id} no llega al servicio.
      push.recibir({'v': '1', 'id': 'Pago de \$500'});
      await pumpEventQueue();
      expect(notificador.historial, hasLength(1));
      await servicio.detener();
    });

    test(
      'el mismo aviso por Firebase y por el recordatorio es UNA notificación',
      () async {
        repo.agregar(aviso());
        await notificador.programar(
          NotificacionLocal(
            id: idDeNotificacion('pago_proximo:o1:2026-11-12:1'),
            titulo: 'Tienes un pago próximo',
            canal: CanalAviso.urgentes,
          ),
          DateTime(2026, 11, 9, 9),
          zona: 'America/Mexico_City',
        );
        await llegar();
        await llegar();
        expect(notificador.visibles, hasLength(1));
      },
    );

    test('sin sesión: el aviso genérico, sin leer nada', () async {
      contexto = const ContextoAvisos(tipo: TipoEquipoAvisos.telefono);
      repo.agregar(aviso());
      await llegar();
      expect(notificador.visibles.values.single.titulo, textoAvisoGenerico);
      expect(repo.lecturas, 0);
    });

    test(
      'sin servidor, sin señal o sin que el aviso sea suyo: el genérico',
      () async {
        servicio = crear(repositorio: () => null);
        await servicio.alRecibirPush(const MensajePush(uuid));
        expect(notificador.visibles.values.single.titulo, textoAvisoGenerico);

        notificador.visibles.clear();
        servicio = crear();
        repo.falla = const SocketException('sin señal');
        await llegar();
        expect(notificador.visibles.values.single.titulo, textoAvisoGenerico);

        notificador.visibles.clear();
        repo.falla = null; // RLS: el aviso de otra persona no se lee
        await llegar('9a9a9a9a-9a9a-4a9a-9a9a-9a9a9a9a9a9a');
        expect(notificador.visibles.values.single.titulo, textoAvisoGenerico);
      },
    );

    test('nunca lleva datos del aviso fuera del catálogo', () async {
      repo.agregar(
        aviso(tipo: 'limite_tarjeta', clave: 'limite_tarjeta:BBVA-1234:x:1'),
      );
      await llegar();
      final n = notificador.historial.single;
      expect('${n.titulo}${n.cuerpo}${n.carga}', isNot(contains('BBVA')));
      expect(textoDeAvisoEsDiscreto(n.titulo), isTrue);
    });

    test('un aviso ya resuelto o cancelado retira la notificación en lugar de mostrarla', () async {
      repo.agregar(aviso());
      await llegar();
      expect(notificador.visibles, hasLength(1));
      repo.agregar(aviso(estado: EstadoAviso.resuelta));
      await llegar();
      expect(notificador.visibles, isEmpty);
    });

    test(
      'horas silenciosas: llega sin sonido; con el permiso de críticas, suena',
      () async {
        reloj = (fecha: DateTime(2026, 11, 3), hora: const HoraDelDia(23));
        repo.agregar(aviso());
        await llegar();
        expect(notificador.visibles.values.single.sonar, isFalse);
        repo.preferenciasIniciales = const PreferenciasAvisos(
          criticasEnSilencio: true,
        );
        servicio = crear();
        await llegar();
        expect(notificador.visibles.values.single.sonar, isTrue);
      },
    );

    test(
      'tope diario: la cuarta no crítica ya no sale; las críticas siguen',
      () async {
        for (var i = 0; i < 4; i++) {
          repo.agregar(
            aviso(
              id: '3f2b8a52-6f0e-4b1b-9c52-1d7d5a2b9e0$i',
              tipo: 'partida_80',
              clave: 'partida_80:p$i:s',
            ),
          );
          await llegar('3f2b8a52-6f0e-4b1b-9c52-1d7d5a2b9e0$i');
        }
        expect(notificador.visibles, hasLength(3));
        repo.agregar(aviso());
        await llegar();
        expect(
          notificador.visibles,
          hasLength(4),
          reason: 'la crítica no tiene tope',
        );
        // Otro día vuelve a contar.
        reloj = (fecha: DateTime(2026, 11, 4), hora: const HoraDelDia(12));
        repo.agregar(
          aviso(
            id: '3f2b8a52-6f0e-4b1b-9c52-1d7d5a2b9e0a',
            tipo: 'partida_80',
            clave: 'partida_80:z',
          ),
        );
        await llegar('3f2b8a52-6f0e-4b1b-9c52-1d7d5a2b9e0a');
        expect(notificador.visibles, hasLength(5));
      },
    );

    test('sin permiso del sistema no se muestra nada', () async {
      notificador.permiso = false;
      repo.agregar(aviso());
      await llegar();
      expect(notificador.historial, isEmpty);
    });

    test('tocar la notificación abre la bandeja con el id del aviso', () async {
      repo.agregar(aviso());
      await servicio.iniciar();
      await llegar();
      notificador.tocar(uuid);
      expect(abiertos, [uuid]);
      push.inicial = const MensajePush(uuid);
      await servicio.iniciar();
      expect(abiertos, [uuid, uuid]);
      await servicio.detener();
    });

    test('aviso de prueba: el genérico (lo que ven la pantalla bloqueada y la pulsera)', () async {
      expect(await servicio.avisoDePrueba(), isTrue);
      expect(notificador.visibles.values.single.titulo, textoAvisoGenerico);
      notificador.permiso = false;
      expect(await servicio.avisoDePrueba(), isFalse);
    });
  });

  group('quién recibe en cada equipo (regla 44)', () {
    late NotificadorEnMemoria notificador;
    late FuentePushFalsa push;
    late RepositorioAvisosEnMemoria repo;
    late AlmacenSeguroEnMemoria almacen;

    ServicioAvisos con(ContextoAvisos c) => ServicioAvisos(
      notificador: notificador,
      fuentePush: push,
      repositorio: () => repo,
      almacen: almacen,
      contexto: () => c,
      reloj: (_) => (fecha: DateTime(2026, 11, 3), hora: const HoraDelDia(12)),
    );

    setUp(() {
      notificador = NotificadorEnMemoria();
      push = FuentePushFalsa();
      repo = RepositorioAvisosEnMemoria();
      almacen = AlmacenSeguroEnMemoria();
      repo.agregar(aviso());
    });

    test('tablet pública: ningún aviso, ni siquiera el genérico, y no registra equipo', () async {
      for (final persona in [null, 'ana']) {
        final s = con(
          ContextoAvisos(
            tipo: TipoEquipoAvisos.tabletPublica,
            personaId: persona,
          ),
        );
        await s.alRecibirPush(const MensajePush(uuid));
        await s.alEntrarPersona();
        expect(await s.fijarActivado(true), isFalse);
      }
      expect(notificador.historial, isEmpty);
      expect(repo.dispositivos, isEmpty);
    });

    test('tablet personal: apagada por omisión; con la persona dentro y activada, sí', () async {
      const c = ContextoAvisos(
        tipo: TipoEquipoAvisos.tabletPersonal,
        personaId: 'ana',
      );
      final s = con(c);
      await s.alRecibirPush(const MensajePush(uuid));
      await s.alEntrarPersona();
      expect(notificador.historial, isEmpty);
      expect(repo.dispositivos, isEmpty, reason: 'ni se registra');
      expect(await s.activado(), isFalse);

      expect(await s.fijarActivado(true), isTrue);
      expect(repo.dispositivos.values.single, TipoEquipoAvisos.tabletPersonal);
      await s.alRecibirPush(const MensajePush(uuid));
      expect(notificador.historial.single.titulo, 'Tienes un pago próximo');
    });

    test(
      'tablet personal sin nadie dentro (bloqueada con PIN): nada',
      () async {
        final s = con(
          const ContextoAvisos(tipo: TipoEquipoAvisos.tabletPersonal),
        );
        await s.alRecibirPush(const MensajePush(uuid));
        expect(notificador.historial, isEmpty);
      },
    );

    test(
      'la cuenta maestra y quien no ve dinero no reciben avisos de dinero',
      () async {
        for (final c in [
          const ContextoAvisos(
            tipo: TipoEquipoAvisos.telefono,
            personaId: 'm',
            esMaestra: true,
          ),
          const ContextoAvisos(
            tipo: TipoEquipoAvisos.telefono,
            personaId: 'f',
            puedeRecibir: false,
          ),
        ]) {
          final s = con(c);
          await s.alRecibirPush(const MensajePush(uuid));
          await s.alEntrarPersona();
          expect(await s.fijarActivado(true), isFalse);
        }
        expect(notificador.historial, isEmpty);
        expect(repo.dispositivos, isEmpty);
      },
    );

    test(
      'laptop: el push no se atiende; la bandeja en vivo muestra lo nuevo',
      () async {
        final s = con(
          const ContextoAvisos(tipo: TipoEquipoAvisos.laptop, personaId: 'ana'),
        );
        await s.alRecibirPush(const MensajePush(uuid));
        expect(notificador.historial, isEmpty);

        await s.alEntrarPersona();
        expect(
          repo.dispositivos,
          isEmpty,
          reason: 'la laptop no registra token',
        );
        await pumpEventQueue();
        repo.agregar(
          aviso(
            id: '3f2b8a52-6f0e-4b1b-9c52-1d7d5a2b9e11',
            tipo: 'fondo_bajo',
            clave: 'fondo_bajo:b:s',
          ),
        );
        await pumpEventQueue();
        expect(notificador.historial.single.titulo, 'Revisa tu ahorro');
        // Lo que ya había al conectar no vuelve a sonar.
        await s.alSalirPersona();
      },
    );

    test('teléfono: se registra a nombre de la persona, reasigna el token y se da de '
        'baja al salir', () async {
      final s = con(
        const ContextoAvisos(tipo: TipoEquipoAvisos.telefono, personaId: 'ana'),
      );
      await s.iniciar();
      await s.alEntrarPersona();
      expect(repo.dispositivos, {'token-de-prueba': TipoEquipoAvisos.telefono});
      // Firebase renueva el token.
      push.renovar('token-2');
      await pumpEventQueue();
      expect(repo.dispositivos.containsKey('token-2'), isTrue);

      await s.alSalirPersona();
      expect(repo.dispositivos.containsKey('token-2'), isFalse);
      expect(push.vecesOlvidar, 1);
      await s.detener();
    });

    test(
      'apagar los avisos da de baja el equipo sin cerrar la sesión',
      () async {
        final s = con(
          const ContextoAvisos(
            tipo: TipoEquipoAvisos.telefono,
            personaId: 'ana',
          ),
        );
        await s.alEntrarPersona();
        expect(repo.dispositivos, isNotEmpty);
        await s.fijarActivado(false);
        expect(repo.dispositivos, isEmpty);
        expect(push.vecesOlvidar, 0);
        expect(await s.activado(), isFalse);
        await s.alRecibirPush(const MensajePush(uuid));
        expect(notificador.historial, isEmpty);
      },
    );

    test('activar pide el permiso del sistema', () async {
      notificador.permiso = false;
      final s = con(
        const ContextoAvisos(tipo: TipoEquipoAvisos.telefono, personaId: 'ana'),
      );
      expect(await s.fijarActivado(true), isFalse);
      expect(notificador.vecesPedirPermiso, 1);
    });
  });

  group('recordatorios locales (regla 45)', () {
    const p = PreferenciasAvisos();
    // Martes 3 de noviembre de 2026, 10:00.
    final ahora = DateTime(2026, 11, 3, 10);

    test('3 y 1 día antes de cada vencimiento, sin más', () {
      final lista = calcularRecordatorios(
        preferencias: p,
        ahora: ahora,
        vencimientos: [
          Vencimiento(objetoId: 'o1', fecha: DateTime(2026, 11, 12)),
        ],
      );
      final pagos = lista.where((r) => r.tipo == 'pago_proximo').toList();
      expect(pagos, hasLength(2));
      expect(pagos.first.cuando, DateTime(2026, 11, 9, 9));
      expect(pagos.first.clave, 'pago_proximo:o1:2026-11-12:3');
      expect(pagos.last.cuando, DateTime(2026, 11, 11, 9));
      expect(pagos.last.clave, 'pago_proximo:o1:2026-11-12:1');

      // A 2 días: el de 3 días ya pasó, queda el de 1 día (paso 2).
      final cerca = calcularRecordatorios(
        preferencias: p,
        ahora: ahora,
        vencimientos: [
          Vencimiento(objetoId: 'o2', fecha: DateTime(2026, 11, 5)),
        ],
      ).where((r) => r.tipo == 'pago_proximo');
      expect(cerca.single.cuando, DateTime(2026, 11, 4, 9));
      expect(cerca.single.clave, 'pago_proximo:o2:2026-11-05:1');
    });

    test(
      'lo que vence pasado el horizonte de 14 días no se programa; una tarjeta '
      'usa el tipo de su límite',
      () {
        final lista = calcularRecordatorios(
          preferencias: p,
          ahora: ahora,
          vencimientos: [
            Vencimiento(objetoId: 'lejos', fecha: DateTime(2026, 12, 30)),
            Vencimiento(
              objetoId: 't',
              fecha: DateTime(2026, 11, 15),
              esLimiteDeTarjeta: true,
            ),
          ],
        );
        expect(lista.any((r) => r.clave.contains('lejos')), isFalse);
        expect(lista.where((r) => r.tipo == 'limite_tarjeta'), hasLength(2));
      },
    );

    test('resumen del lunes 8:00 y cierre el domingo 19:00', () {
      final lista = calcularRecordatorios(preferencias: p, ahora: ahora);
      final resumen = lista.where((r) => r.tipo == 'resumen_lunes').first;
      expect(resumen.cuando, DateTime(2026, 11, 9, 8));
      final cierre = lista.where((r) => r.tipo == 'recordatorio_cierre').first;
      expect(cierre.cuando, DateTime(2026, 11, 8, 19));
      final cuandos = lista.map((r) => r.cuando).toList();
      expect(cuandos, [...cuandos]..sort());
    });

    test('un tipo silenciado no se programa; nada en el pasado', () {
      final lista = calcularRecordatorios(
        preferencias: p.copiarCon(tiposSilenciados: {'resumen_lunes'}),
        ahora: DateTime(2026, 11, 9, 8, 30),
      );
      expect(
        lista.any((r) => r.tipo == 'resumen_lunes' && r.cuando.day == 9),
        isFalse,
      );
      expect(
        lista.every((r) => r.cuando.isAfter(DateTime(2026, 11, 9, 8, 30))),
        isTrue,
      );
    });

    test('una hora dentro del silencio espera a su fin', () {
      final lista = calcularRecordatorios(
        preferencias: p.copiarCon(horaVencimientos: const HoraDelDia(23)),
        ahora: ahora,
        vencimientos: [
          Vencimiento(objetoId: 'o', fecha: DateTime(2026, 11, 12)),
        ],
      );
      final pago = lista.firstWhere((r) => r.tipo == 'pago_proximo');
      expect(pago.cuando, DateTime(2026, 11, 10, 7));
    });

    test(
      'reprogramar cancela lo propio (no lo de otros) y programa con el texto '
      'del catálogo',
      () async {
        final n = NotificadorEnMemoria();
        final r = RecordatoriosLocales(
          notificador: n,
          vencimientos: _Fijos([
            Vencimiento(objetoId: 'o1', fecha: DateTime(2026, 11, 12)),
          ]),
        );
        // Algo programado por otro (p. ej. los recordatorios de Hábitos).
        await n.programar(
          const NotificacionLocal(
            id: 7,
            titulo: 'ajeno',
            canal: CanalAviso.avisos,
          ),
          DateTime(2027),
          zona: 'America/Mexico_City',
        );
        await r.reprogramar(preferencias: p, ahora: ahora);
        final lista = await r.reprogramar(
          preferencias: p.copiarCon(tiposSilenciados: {'resumen_lunes'}),
          ahora: ahora,
        );
        expect(
          n.programadas.containsKey(7),
          isTrue,
          reason: 'lo ajeno se respeta',
        );
        expect(n.programadas, hasLength(lista.length + 1));
        expect(
          n.programadas.values.any(
            (e) =>
                e.notificacion.titulo == 'Tu resumen de la semana está listo',
          ),
          isFalse,
          reason: 'lo anterior se canceló',
        );
        final pago =
            n.programadas[idDeNotificacion('pago_proximo:o1:2026-11-12:3')]!;
        expect(pago.notificacion.titulo, 'Tienes un pago próximo');
        expect(pago.notificacion.cuerpo, isEmpty);
        for (final e in n.programadas.values.where(
          (e) => e.notificacion.id != 7,
        )) {
          expect(textoDeAvisoEsDiscreto(e.notificacion.titulo), isTrue);
        }
      },
    );

    test('sin permiso no se programa nada', () async {
      final n = NotificadorEnMemoria(permiso: false);
      final r = RecordatoriosLocales(notificador: n);
      expect(await r.reprogramar(preferencias: p, ahora: ahora), isEmpty);
      expect(n.programadas, isEmpty);
    });
  });
}

class _Fijos implements FuenteDeVencimientos {
  _Fijos(this.lista);

  final List<Vencimiento> lista;

  @override
  Future<List<Vencimiento>> proximos({
    required DateTime desde,
    required int dias,
  }) async => lista;
}
