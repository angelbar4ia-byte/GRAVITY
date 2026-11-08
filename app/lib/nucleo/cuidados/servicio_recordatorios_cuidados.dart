/// Programa en el teléfono de quien está de turno los recordatorios locales de
/// Papá (comidas y entrega de turno; las TOMAS las avisa el servidor, ver
/// [ServicioRecordatoriosCuidados.reprogramar]). Sin Firebase propio. Lo
/// que se ve sale del catálogo (genérico, sin medicamento, cuerpo vacío).
/// Quien no está de turno no recibe nada. Se reprograma al abrir la app, al
/// sincronizar y al cambiar los turnos.
library;

import 'dart:convert';

import '../avisos/aviso.dart';
import '../avisos/catalogo_avisos.dart';
import '../avisos/notificador.dart';
import '../seguridad/almacen_seguro.dart';
import 'posponer_toma.dart';
import 'turnos.dart';

/// Quién sabe qué tomas y comidas vienen (Cuidados, con su copia local).
abstract interface class FuenteDeEventosDeCuidado {
  Future<List<EventoDeCuidado>> proximos({
    required DateTime desde,
    required int dias,
  });
}

class SinEventosDeCuidado implements FuenteDeEventosDeCuidado {
  const SinEventosDeCuidado();

  @override
  Future<List<EventoDeCuidado>> proximos({
    required DateTime desde,
    required int dias,
  }) async => const [];
}

class ServicioRecordatoriosCuidados {
  ServicioRecordatoriosCuidados({
    required this.notificador,
    required this.almacen,
    this.fuente = const SinEventosDeCuidado(),
  });

  final NotificadorLocal notificador;
  final AlmacenSeguro almacen;
  final FuenteDeEventosDeCuidado fuente;

  static const _claveIds = 'cuidados.recordatorios.ids';

  /// Cancela lo anterior y programa lo que le toca a [cuidador] (clave de
  /// turno, ver [RolDeTurno]). Con `cuidador == null` (no es cuidador) solo
  /// cancela. Devuelve lo programado.
  Future<List<RecordatorioCuidado>> reprogramar({
    required String? cuidador,
    required DateTime ahora,
    required PreferenciasAvisos preferencias,
    List<Turno> turnos = turnosPorOmision,
  }) async {
    final previos = await almacen.leer(_claveIds);
    if (previos != null) {
      try {
        for (final id in jsonDecode(previos) as List) {
          await notificador.cancelar(id as int);
        }
      } catch (_) {}
    }
    await almacen.borrar(_claveIds);
    if (cuidador == null || !await notificador.permisoConcedido()) {
      return const [];
    }
    List<EventoDeCuidado> eventos;
    try {
      eventos = await fuente.proximos(desde: ahora, dias: 7);
    } catch (_) {
      eventos = const [];
    }
    // Las tomas ya NO se programan localmente: el servidor genera el aviso
    // `recordatorio_toma` (push, objeto 'toma') y es la única fuente; hacerlo
    // aquí también duplicaría el aviso. Las comidas y la entrega de turno
    // siguen siendo locales. Posponer desde el aviso local sigue funcionando.
    eventos = [
      for (final e in eventos)
        if (e.tipo != 'recordatorio_toma') e,
    ];
    final lista = [
      ...recordatoriosParaCuidador(
        cuidador: cuidador,
        eventos: eventos,
        ahora: ahora,
        turnos: turnos,
      ),
      ...entregasDeTurno(cuidador: cuidador, ahora: ahora, turnos: turnos),
    ]..sort((a, b) => a.cuando.compareTo(b.cuando));
    final ids = <int>[];
    for (final r in lista) {
      final id = idDeNotificacion(r.clave);
      await notificador.programar(
        NotificacionLocal(
          id: id,
          titulo: r.titulo,
          canal: canalDe(r.tipo),
          // Spec fase-5 8g: tomas y comidas suenan siempre, también de noche
          // (no se aplican las horas silenciosas). Las entregas de turno sí
          // respetan el silencio.
          sonar: r.tipo == 'recordatorio_entrega_turno' ||
                  r.tipo == 'entrega_turno'
              ? !preferencias.enSilencio(
                  HoraDelDia(r.cuando.hour, r.cuando.minute),
                )
              : true,
          carga: r.clave,
          acciones: accionesDeRecordatorio(r.tipo),
        ),
        r.cuando,
        zona: preferencias.zonaHoraria,
      );
      ids.add(id);
    }
    await almacen.escribir(_claveIds, jsonEncode(ids));
    return lista;
  }
}
