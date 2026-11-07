// Cuidados, parte de plataforma (fase-5-cuidados.md §3 y §7, criterios 1 y 4):
// turnos, recordatorios solo a quien está de turno, cambio urgente al instante
// y entrega de turno. Sin datos clínicos en ninguna notificación.
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/avisos/aviso.dart';
import 'package:gravity/nucleo/avisos/catalogo_avisos.dart';
import 'package:gravity/nucleo/avisos/fuente_push.dart';
import 'package:gravity/nucleo/avisos/notificador.dart';
import 'package:gravity/nucleo/avisos/repositorio_avisos.dart';
import 'package:gravity/nucleo/avisos/servicio_avisos.dart';
import 'package:gravity/nucleo/cuidados/servicio_recordatorios_cuidados.dart';
import 'package:gravity/nucleo/cuidados/turnos.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';

const _c = RolDeTurno.cuidadoraPrincipal;
const _h = RolDeTurno.hermana;
const _d = RolDeTurno.dueno;

// Semana del lunes 2 al domingo 8 de noviembre de 2026.
DateTime f(int dia, int h, [int m = 0]) => DateTime(2026, 11, dia, h, m);

class _Fuente implements FuenteDeEventosDeCuidado {
  _Fuente(this.lista);
  final List<EventoDeCuidado> lista;
  @override
  Future<List<EventoDeCuidado>> proximos({
    required DateTime desde,
    required int dias,
  }) async => lista;
}

EventoDeCuidado toma(DateTime cuando, [String id = 'm1']) =>
    EventoDeCuidado(tipo: 'recordatorio_toma', objetoId: id, cuando: cuando);

void main() {
  group('cuidadorDeTurno (sección 3)', () {
    test('lunes: cuidadora de 9:00 a 15:00, dueño desde las 15:00', () {
      expect(cuidadorDeTurno(f(2, 8, 59)), isNull);
      expect(cuidadorDeTurno(f(2, 9)), _c);
      expect(cuidadorDeTurno(f(2, 14, 59)), _c);
      expect(cuidadorDeTurno(f(2, 15)), _d);
    });

    test(
      'martes: cuidadora 7:30 a 15:00; hermana de 15:00 al miércoles 7:00',
      () {
        expect(cuidadorDeTurno(f(3, 7, 29)), isNull);
        expect(cuidadorDeTurno(f(3, 7, 30)), _c);
        expect(cuidadorDeTurno(f(3, 15)), _h);
        expect(cuidadorDeTurno(f(3, 23, 59)), _h);
        expect(cuidadorDeTurno(f(4, 6, 59)), _h);
        expect(cuidadorDeTurno(f(4, 7)), isNull);
        expect(cuidadorDeTurno(f(4, 7, 30)), _c);
      },
    );

    test('miércoles a viernes 7:30 a 18:30', () {
      for (final dia in [4, 5, 6]) {
        expect(cuidadorDeTurno(f(dia, 12)), _c);
        expect(cuidadorDeTurno(f(dia, 18, 29)), _c);
        expect(cuidadorDeTurno(f(dia, 18, 30)), isNull);
      }
    });

    test('sábado: cuidadora hasta las 15:00, luego el dueño; domingo, el dueño todo el día', () {
      expect(cuidadorDeTurno(f(7, 10)), _c);
      expect(cuidadorDeTurno(f(7, 15)), _d);
      expect(cuidadorDeTurno(f(8, 0)), _d);
      expect(cuidadorDeTurno(f(8, 23, 59)), _d);
      expect(cuidadorDeTurno(f(9, 8)), isNull); // lunes antes de las 9:00
    });

    test('acepta una lista de turnos propia', () {
      final turnos = [
        const Turno(
          cuidador: 'x',
          dia: 1,
          desde: HoraDelDia(1),
          hasta: HoraDelDia(2),
        ),
      ];
      expect(cuidadorDeTurno(f(2, 1, 30), turnos), 'x');
      expect(cuidadorDeTurno(f(2, 9), turnos), isNull);
    });
  });

  group('criterio 1: sin turno no hay recordatorio', () {
    final ahora = f(2, 7); // lunes
    final eventos = [
      toma(f(2, 8), 'a'), // nadie de turno
      toma(f(2, 10), 'b'), // cuidadora
      toma(f(2, 16), 'c'), // dueño
      toma(f(3, 16), 'd'), // hermana
      toma(f(2, 6), 'e'), // ya pasó
    ];

    List<String> para(String quien) => [
      for (final r in recordatoriosParaCuidador(
        cuidador: quien,
        eventos: eventos,
        ahora: ahora,
      ))
        r.clave.split(':')[2],
    ];

    test('cada quien recibe solo lo de su turno', () {
      expect(para(_c), ['b']);
      expect(para(_d), ['c']);
      expect(para(_h), ['d']);
      expect(para('otra_persona'), isEmpty);
    });

    test('el recordatorio es genérico y sin medicamento (D6)', () {
      final r = recordatoriosParaCuidador(
        cuidador: _c,
        eventos: [toma(f(2, 10), 'ibuprofeno-400')],
        ahora: ahora,
      ).single;
      expect(r.titulo, 'Hora de la toma de Papá');
      expect(r.titulo.toLowerCase(), isNot(contains('ibuprofeno')));
      expect(textoDeAvisoEsDiscreto(r.titulo), isTrue);
    });

    test(
      'el servicio programa solo en el teléfono de quien está de turno',
      () async {
        final prefs = const PreferenciasAvisos();
        Future<NotificadorEnMemoria> corre(String? quien) async {
          final n = NotificadorEnMemoria();
          final s = ServicioRecordatoriosCuidados(
            notificador: n,
            almacen: AlmacenSeguroEnMemoria(),
            fuente: _Fuente(eventos),
          );
          await s.reprogramar(
            cuidador: quien,
            ahora: ahora,
            preferencias: prefs,
          );
          return n;
        }

        final cuidadora = await corre(_c);
        final tomas = cuidadora.programadas.values.where(
          (p) => p.notificacion.titulo == 'Hora de la toma de Papá',
        );
        expect(tomas.map((p) => p.cuando), [f(2, 10)]);
        final hermana = await corre(_h);
        expect(
          hermana.programadas.values.where(
            (p) => p.notificacion.titulo == 'Hora de la toma de Papá',
          ),
          hasLength(1),
        );
        expect((await corre('otra_persona')).programadas, isEmpty);
        expect((await corre(null)).programadas, isEmpty);
      },
    );

    test(
      'reprogramar reemplaza lo anterior y sin permiso no programa',
      () async {
        final n = NotificadorEnMemoria();
        final s = ServicioRecordatoriosCuidados(
          notificador: n,
          almacen: AlmacenSeguroEnMemoria(),
          fuente: _Fuente(eventos),
        );
        const p = PreferenciasAvisos();
        final a = await s.reprogramar(
          cuidador: _c,
          ahora: ahora,
          preferencias: p,
        );
        final b = await s.reprogramar(
          cuidador: _c,
          ahora: ahora,
          preferencias: p,
        );
        expect(n.programadas, hasLength(b.length));
        expect(a.length, b.length);
        n.permiso = false;
        expect(
          await s.reprogramar(cuidador: _c, ahora: ahora, preferencias: p),
          isEmpty,
        );
        expect(n.programadas, isEmpty);
      },
    );
  });

  group('entrega de turno', () {
    test('recuerda al final de cada turno, uniendo tramos pegados', () {
      final hermana = entregasDeTurno(cuidador: _h, ahora: f(2, 7));
      // Martes 15:00 a miércoles 7:00 es un solo turno.
      expect(hermana.map((r) => r.cuando), [f(4, 7)]);
      final dueno = entregasDeTurno(cuidador: _d, ahora: f(2, 7));
      // Lunes 15 a 24:00; sábado 15:00 a domingo 24:00 (un turno seguido).
      expect(dueno.map((r) => r.cuando), [f(3, 0), f(9, 0)]);
      final cuidadora = entregasDeTurno(cuidador: _c, ahora: f(2, 16));
      expect(cuidadora.first.cuando, f(3, 15));
    });

    test(
      'solo recuerdo: título del catálogo, sin contenido clínico, cuerpo vacío',
      () async {
        final r = entregasDeTurno(cuidador: _c, ahora: f(2, 7)).first;
        expect(r.tipo, 'entrega_turno');
        expect(r.titulo, 'Es hora de dejar tus notas');
        expect(textoDeAvisoEsDiscreto(r.titulo), isTrue);
        final n = NotificadorEnMemoria();
        await ServicioRecordatoriosCuidados(
          notificador: n,
          almacen: AlmacenSeguroEnMemoria(),
        ).reprogramar(
          cuidador: _c,
          ahora: f(2, 7),
          preferencias: const PreferenciasAvisos(),
        );
        expect(n.programadas.values.first.notificacion.cuerpo, isEmpty);
        expect(n.programadas.values.first.cuando, f(2, 15));
      },
    );

    test('quien no es cuidador no recibe entregas', () {
      expect(entregasDeTurno(cuidador: 'otra', ahora: f(2, 7)), isEmpty);
    });
  });

  group('criterio 4: cambio urgente', () {
    const uuid = '3f2b8a52-6f0e-4b1b-9c52-1d7d5a2b9e10';

    test(
      'catálogo: crítico, discreto, sin nombres clínicos, por el canal urgente',
      () {
        const t = 'cambio_urgente_cuidados';
        expect(severidadDe(t), SeveridadAviso.critica);
        expect(canalDe(t), CanalAviso.urgentes);
        expect(textoDeAvisoEsDiscreto(tituloDeAviso(t)), isTrue);
        expect(avisosDeCuidados, contains(t));
        expect(titulosDeAviso.keys.toSet(), severidadDeAviso.keys.toSet());
        for (final k in avisosDeCuidados) {
          expect(textoDeAvisoEsDiscreto(titulosDeAviso[k]!), isTrue, reason: k);
        }
      },
    );

    test('el destinatario es quien está de turno', () {
      expect(destinatarioDeCambioUrgente(f(4, 10)), _c);
      expect(destinatarioDeCambioUrgente(f(3, 20)), _h);
      expect(destinatarioDeCambioUrgente(f(8, 12)), _d);
      expect(destinatarioDeCambioUrgente(f(4, 22)), isNull);
    });

    test(
      'llega al instante al teléfono del cuidador, aunque no vea dinero',
      () async {
        final notificador = NotificadorEnMemoria();
        final repo = RepositorioAvisosEnMemoria()
          ..agregar(
            Aviso(
              id: uuid,
              tipo: 'cambio_urgente_cuidados',
              clave: 'cui:cambio:$uuid',
              estado: EstadoAviso.pendiente,
              creadoEn: DateTime.utc(2026, 11, 4),
            ),
          );
        final servicio = ServicioAvisos(
          notificador: notificador,
          fuentePush: FuentePushFalsa(),
          repositorio: () => repo,
          almacen: AlmacenSeguroEnMemoria(),
          contexto: () => const ContextoAvisos(
            tipo: TipoEquipoAvisos.telefono,
            personaId: 'cuidadora',
            puedeRecibir: false,
            recibeCuidados: true,
          ),
          reloj: (_) =>
              (fecha: DateTime(2026, 11, 4), hora: const HoraDelDia(10)),
        );
        await servicio.alRecibirPush(const MensajePush(uuid));
        final n = notificador.visibles.values.single;
        expect(n.titulo, 'Cambio urgente en los cuidados');
        expect(n.cuerpo, isEmpty);
        expect(n.canal, CanalAviso.urgentes);
        expect(n.sonar, isTrue);
        expect(n.carga, uuid); // solo el id: ningún dato clínico viaja ni se ve
      },
    );

    test('un cuidador no recibe avisos de Finanzas', () async {
      final notificador = NotificadorEnMemoria();
      final repo = RepositorioAvisosEnMemoria()
        ..agregar(
          Aviso(
            id: uuid,
            tipo: 'pago_proximo',
            clave: 'pago_proximo:o1:2026-11-12:1',
            estado: EstadoAviso.pendiente,
            creadoEn: DateTime.utc(2026, 11, 4),
          ),
        );
      final servicio = ServicioAvisos(
        notificador: notificador,
        fuentePush: FuentePushFalsa(),
        repositorio: () => repo,
        almacen: AlmacenSeguroEnMemoria(),
        contexto: () => const ContextoAvisos(
          tipo: TipoEquipoAvisos.telefono,
          personaId: 'cuidadora',
          puedeRecibir: false,
          recibeCuidados: true,
        ),
        reloj: (_) =>
            (fecha: DateTime(2026, 11, 4), hora: const HoraDelDia(10)),
      );
      await servicio.alRecibirPush(const MensajePush(uuid));
      expect(notificador.historial, isEmpty);
    });
  });
}
