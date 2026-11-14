// Spec fase-5 8g: tomas de noche suenan y se pueden posponer.
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/avisos/aviso.dart';
import 'package:gravity/nucleo/avisos/notificador.dart';
import 'package:gravity/nucleo/avisos/servicio_avisos.dart';
import 'package:gravity/nucleo/cuidados/posponer_toma.dart';
import 'package:gravity/nucleo/cuidados/servicio_recordatorios_cuidados.dart';
import 'package:gravity/nucleo/cuidados/turnos.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';

class _Fuente implements FuenteDeEventosDeCuidado {
  _Fuente(this.lista);
  final List<EventoDeCuidado> lista;
  @override
  Future<List<EventoDeCuidado>> proximos({
    required DateTime desde,
    required int dias,
  }) async => lista;
}

void main() {
  final ahora = DateTime(2026, 11, 2, 7);
  final noche = DateTime(2026, 11, 2, 23, 30); // lunes: dueño
  final eventos = [
    EventoDeCuidado(tipo: 'recordatorio_toma', objetoId: 't1', cuando: noche),
    EventoDeCuidado(
      tipo: 'recordatorio_comida',
      objetoId: 'c1',
      cuando: DateTime(2026, 11, 2, 22),
    ),
  ];

  Future<List<NotificacionLocal>> programa() async {
    final n = NotificadorEnMemoria();
    await ServicioRecordatoriosCuidados(
      notificador: n,
      almacen: AlmacenSeguroEnMemoria(),
      fuente: _Fuente(eventos),
    ).reprogramar(
      cuidador: RolDeTurno.dueno,
      ahora: ahora,
      // Silencio nocturno activo por omisión o explícito.
      preferencias: const PreferenciasAvisos(),
    );
    return [for (final p in n.programadas.values) p.notificacion];
  }

  test('la toma NO se programa localmente (la avisa el servidor)', () async {
    final tomas = (await programa()).where(
      (x) => x.titulo == 'Hora de un recordatorio de cuidado',
    );
    expect(tomas, isEmpty);
    // El botón de posponer sigue existiendo para el aviso de toma.
    expect(
      AccionDeNotificacion.posponerTurno.etiqueta,
      textoPosponerAlSiguienteTurno,
    );
  });

  test('la comida de noche también suena y no ofrece posponer', () async {
    final comida = (await programa()).firstWhere(
      (x) => x.titulo == 'Hora de la comida',
    );
    expect(comida.sonar, isTrue);
    expect(comida.acciones, isEmpty);
  });

  test('por push, toma y comida suenan aunque sea hora silenciosa', () {
    for (final t in ['recordatorio_toma', 'recordatorio_comida']) {
      expect(
        decidirPresentacion(
          tipo: t,
          preferencias: const PreferenciasAvisos(),
          ahora: const HoraDelDia(23, 30),
          noCriticasHoy: 99,
        ),
        Presentacion.sonar,
      );
    }
  });

  test('posponer llama a cui_posponer_toma(toma)', () {
    final clave = 'cui:recordatorio_toma:t1:2026-11-02:2330';
    final l = llamadaDePosponerToma(clave, AccionDeNotificacion.posponerTurno)!;
    expect(l.rpc, 'cui_posponer_toma');
    expect(l.params, {'p_toma': 't1'});
    expect(llamadaDePosponerToma(clave, AccionDeNotificacion.hecho), isNull);
    expect(
      llamadaDePosponerToma(
        'cui:recordatorio_comida:c1:2026-11-02:2200',
        AccionDeNotificacion.posponerTurno,
      ),
      isNull,
    );
    expect(
      llamadaDePosponerToma(null, AccionDeNotificacion.posponerTurno),
      isNull,
    );
  });
}
