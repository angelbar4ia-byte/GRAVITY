/// Programa en el teléfono de quien está de turno los recordatorios de Papá
/// (tomas, comidas y entrega de turno). Local: sin servidor ni Firebase. Lo
/// que se ve sale del catálogo (genérico, sin medicamento, cuerpo vacío).
/// Quien no está de turno no recibe nada. Se reprograma al abrir la app, al
/// sincronizar y al cambiar los turnos.
library;

import 'dart:convert';

import '../avisos/aviso.dart';
import '../avisos/catalogo_avisos.dart';
import '../avisos/notificador.dart';
import '../seguridad/almacen_seguro.dart';
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
          // Las horas silenciosas llegan sin sonido, pero llegan.
          sonar: !preferencias.enSilencio(
            HoraDelDia(r.cuando.hour, r.cuando.minute),
          ),
          carga: r.clave,
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
