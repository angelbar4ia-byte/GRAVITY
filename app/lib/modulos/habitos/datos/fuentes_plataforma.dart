/// Lo que Hábitos entrega a plataforma: datos para exportar y borrar (regla
/// 95) y recordatorios locales (regla 113).
library;

import 'package:habitos_dominio/habitos_dominio.dart';

import '../../../nucleo/avisos/recordatorios_habitos.dart';
import '../../../nucleo/sensibles/llaves_habitos.dart' show TipoSensible;
import '../../../nucleo/sensibles/mis_datos.dart';
import '../casos_uso/servicio_eliminar.dart';
import 'documentos_sensibles.dart';
import 'repositorio.dart';
import 'repositorio_agenda.dart';

class FuenteDeDatosDeHabitos implements FuenteDeDatosHabitos {
  FuenteDeDatosDeHabitos(
    this._repo,
    this._agenda,
    this._docs, {
    DateTime Function()? ahora,
  }) : _ahora = ahora ?? DateTime.now;
  final RepositorioHabitos _repo;
  final RepositorioAgenda _agenda;
  final DocumentosSensibles? _docs;
  final DateTime Function() _ahora;

  @override
  Future<Map<String, Object?>> datosEnClaro() async {
    final hoy = soloDia(_ahora());
    return {
      'objetivos': [for (final o in await _repo.objetivos()) o.aFila()],
      'bloques': [for (final b in await _agenda.bloques()) b.aFila()],
      'registros': [
        for (final r in await _repo.registros(sumarDias(hoy, -800), hoy))
          r.aFila(),
      ],
      'planes_lectura': [
        for (final p in await _agenda.planes())
          {...p.aPlanJson(_ahora()), 'dias': p.aDiasJson()},
      ],
      'ajustes': (await _agenda.ajustes()).aCambios(_ahora()),
    };
  }

  @override
  Future<Map<String, Object?>> datosSensibles(TipoSensible tipo) async {
    final d = _docs;
    if (d == null) return {};
    final todos = await d.todos(tipo);
    return {for (final e in todos.entries) e.key: e.value.aJson()};
  }
}

/// Recordatorios locales de los próximos días. Lo sensible sale con el tipo
/// `hab_reservado` (texto "Recordatorio"), sin nombre ni cantidad.
class FuenteDeRecordatoriosDeHabitos implements FuenteDeRecordatoriosHabitos {
  FuenteDeRecordatoriosDeHabitos(this._agenda, this._eliminar);
  final RepositorioAgenda _agenda;
  final ServicioHabitoEliminar? _eliminar;

  @override
  Future<List<RecordatorioHabito>> proximos({
    required DateTime desde,
    required int dias,
  }) async {
    final r = <RecordatorioHabito>[];
    final aj = await _agenda.ajustes();
    final bloques = [
      for (final b in await _agenda.bloques())
        if (b.activo && b.recordarMin != null && !b.fijo) b,
    ];
    final base = soloDia(desde);
    bool tieneHabito = false;
    try {
      tieneHabito =
          await _eliminar?.config(TipoHabito.cigarrillo) != null ||
          await _eliminar?.config(TipoHabito.azucar) != null;
    } catch (_) {
      tieneHabito = false; // llaves bloqueadas: no se programa lo reservado
    }
    for (var i = 0; i < dias; i++) {
      final f = sumarDias(base, i);
      // Minutos negativos o de más de un día se normalizan al día anterior/siguiente (F3-7).
      DateTime en(int min) => DateTime(f.year, f.month, f.day, 0, min);
      for (final b in bloques.where((b) => b.recurrente.ocurreEn(f))) {
        final t = en(b.inicioMin - b.recordarMin!);
        if (t.isAfter(desde)) {
          r.add(
            RecordatorioHabito(
              tipo: TipoRecordatorioHabito.bloque,
              objetoId: b.id,
              cuando: t,
            ),
          );
        }
      }
      if (f.weekday == aj.revisionDia) {
        final pre = en(aj.revisionHoraMin - aj.revisionAvisoMin);
        final ya = en(aj.revisionHoraMin);
        if (pre.isAfter(desde)) {
          r.add(
            RecordatorioHabito(
              tipo: TipoRecordatorioHabito.revisionPre,
              objetoId: 'revision',
              cuando: pre,
            ),
          );
        }
        if (ya.isAfter(desde)) {
          r.add(
            RecordatorioHabito(
              tipo: TipoRecordatorioHabito.revision,
              objetoId: 'revision',
              cuando: ya,
            ),
          );
        }
      }
      // Recordatorio de dar (E11): apagado por omisión; solo el título genérico
      // "Recordatorio", sin montos ni nombres (Hábitos no maneja dinero).
      if (aj.darActivo &&
          aj.darDia != null &&
          aj.darHoraMin != null &&
          f.weekday == aj.darDia) {
        final t = en(aj.darHoraMin!);
        if (t.isAfter(desde)) {
          r.add(
            RecordatorioHabito(
              tipo: TipoRecordatorioHabito.reservado,
              objetoId: 'dar',
              cuando: t,
              sensible: true,
            ),
          );
        }
      }
      if (tieneHabito) {
        final t = en(aj.dormirMin - 60);
        if (t.isAfter(desde)) {
          r.add(
            RecordatorioHabito(
              tipo: TipoRecordatorioHabito.reservado,
              objetoId: 'cierre',
              cuando: t,
              sensible: true,
            ),
          );
        }
      }
    }
    return r;
  }
}
