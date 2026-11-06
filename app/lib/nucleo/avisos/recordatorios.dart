/// Recordatorios locales (regla 45): sin servidor, sin costo y sin señal.
/// Vencimientos de deudas de los próximos 14 días, resumen del lunes y
/// recordatorio de cierre. Se reprograman al abrir la app, al sincronizar, al
/// cambiar las preferencias y al reiniciar el teléfono (el receptor de arranque
/// de `flutter_local_notifications`).
///
/// El id de cada notificación es el hash de su `clave`: si el mismo aviso llega
/// después por Firebase, **reemplaza** al recordatorio y se ve una sola.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../seguridad/almacen_seguro.dart';

import 'aviso.dart';
import 'catalogo_avisos.dart';
import 'notificador.dart';

/// Un pago que vence (lo entrega Finanzas desde su copia local).
@immutable
class Vencimiento {
  const Vencimiento({
    required this.objetoId,
    required this.fecha,
    this.esLimiteDeTarjeta = false,
  });

  /// Id de la ocurrencia; entra en la `clave`, nunca en el texto.
  final String objetoId;

  /// Día de la `fecha_ajustada` (hora local de la persona; solo cuenta el día).
  final DateTime fecha;
  final bool esLimiteDeTarjeta;
}

/// Quién sabe qué vence: Finanzas, con la copia local. Por omisión, nadie.
abstract interface class FuenteDeVencimientos {
  Future<List<Vencimiento>> proximos({
    required DateTime desde,
    required int dias,
  });
}

class SinVencimientos implements FuenteDeVencimientos {
  const SinVencimientos();

  @override
  Future<List<Vencimiento>> proximos({
    required DateTime desde,
    required int dias,
  }) async => const [];
}

@immutable
class RecordatorioLocal {
  const RecordatorioLocal({
    required this.clave,
    required this.tipo,
    required this.cuando,
  });

  final String clave;
  final String tipo;

  /// Hora de pared en la zona de la persona.
  final DateTime cuando;

  @override
  String toString() => '$tipo $clave @ $cuando';
}

String _dia(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime _a(DateTime dia, HoraDelDia hora) =>
    DateTime(dia.year, dia.month, dia.day, hora.hora, hora.minuto);

/// Calcula qué recordatorios hay que tener programados. Pura.
///
/// [ahora] es la hora de pared de la persona. La `clave` de un vencimiento es
/// `tipo:ocurrencia_id:fecha:n`, con `n` = los días antes (3 y 1),
/// igual que la del servidor, para que uno reemplace al otro.
List<RecordatorioLocal> calcularRecordatorios({
  required PreferenciasAvisos preferencias,
  required DateTime ahora,
  List<Vencimiento> vencimientos = const [],
  int diasVencimientos = 14,
  int semanas = 2,
}) {
  final resultado = <RecordatorioLocal>[];
  final hoy = DateTime(ahora.year, ahora.month, ahora.day);

  void agregar(String clave, String tipo, DateTime cuando) {
    if (preferencias.tiposSilenciados.contains(tipo)) return;
    if (!cuando.isAfter(ahora)) return;
    resultado.add(RecordatorioLocal(clave: clave, tipo: tipo, cuando: cuando));
  }

  // Vencimientos: solo el aviso más próximo que aún no pasó (sin avalancha).
  final dias = [...preferencias.diasAvisoDeuda]..sort((a, b) => b.compareTo(a));
  for (final v in vencimientos) {
    final dia = DateTime(v.fecha.year, v.fecha.month, v.fecha.day);
    if (dia.difference(hoy).inDays > diasVencimientos) continue;
    final tipo = v.esLimiteDeTarjeta ? 'limite_tarjeta' : 'pago_proximo';
    for (var paso = 0; paso < dias.length; paso++) {
      final cuando = _a(
        dia.subtract(Duration(days: dias[paso])),
        preferencias.horaVencimientos,
      );
      if (cuando.isAfter(ahora)) {
        agregar('$tipo:${v.objetoId}:${_dia(dia)}:${dias[paso]}', tipo, cuando);
      }
    }
  }

  // Resumen del lunes y cierre de la semana (próximas ocurrencias).
  for (var s = 0; s < semanas + 1 && s < 8; s++) {
    final lunes = hoy.add(
      Duration(days: ((DateTime.monday - hoy.weekday) % 7) + 7 * s),
    );
    agregar(
      'resumen_lunes:${_dia(lunes)}',
      'resumen_lunes',
      _a(lunes, preferencias.resumenLunes),
    );
    final cierre = hoy.add(
      Duration(
        days: ((preferencias.recordatorioCierreDia - hoy.weekday) % 7) + 7 * s,
      ),
    );
    agregar(
      'recordatorio_cierre:${_dia(cierre)}',
      'recordatorio_cierre',
      _a(cierre, preferencias.recordatorioCierreHora),
    );
  }

  // Las horas silenciosas esperan a su fin, salvo críticas permitidas.
  final ajustados = [
    for (final r in resultado)
      if (preferencias.enSilencio(HoraDelDia(r.cuando.hour, r.cuando.minute)) &&
          !(severidadDe(r.tipo) == SeveridadAviso.critica &&
              preferencias.criticasEnSilencio))
        RecordatorioLocal(
          clave: r.clave,
          tipo: r.tipo,
          cuando: _a(
            r.cuando.hour * 60 + r.cuando.minute >=
                        preferencias.silencioHasta.minutos &&
                    preferencias.silencioDesde.minutos >
                        preferencias.silencioHasta.minutos
                ? DateTime(r.cuando.year, r.cuando.month, r.cuando.day + 1)
                : DateTime(r.cuando.year, r.cuando.month, r.cuando.day),
            preferencias.silencioHasta,
          ),
        )
      else
        r,
  ];
  ajustados.sort((a, b) => a.cuando.compareTo(b.cuando));
  return ajustados;
}

class RecordatoriosLocales {
  RecordatoriosLocales({
    required this.notificador,
    this.vencimientos = const SinVencimientos(),
    this.almacen,
  });

  final NotificadorLocal notificador;
  final FuenteDeVencimientos vencimientos;

  /// Donde se recuerdan los ids programados, para cancelar **solo los de
  /// Finanzas** y no los recordatorios de Hábitos (que comparten el sistema).
  final AlmacenSeguro? almacen;
  final Set<int> _propios = {};
  static const _clave = 'avisos.recordatorios.finanzas.ids';

  Future<void> _cancelarPropios() async {
    final ids = {..._propios};
    final texto = await almacen?.leer(_clave);
    if (texto != null) {
      try {
        ids.addAll([for (final i in jsonDecode(texto) as List) i as int]);
      } catch (_) {}
    }
    for (final id in ids) {
      await notificador.cancelar(id);
    }
    _propios.clear();
  }

  /// Cancela lo programado y vuelve a programar desde cero. Devuelve lo que
  /// quedó programado.
  Future<List<RecordatorioLocal>> reprogramar({
    required PreferenciasAvisos preferencias,
    required DateTime ahora,
  }) async {
    await _cancelarPropios();
    if (!await notificador.permisoConcedido()) {
      await almacen?.borrar(_clave);
      return const [];
    }
    List<Vencimiento> proximos;
    try {
      proximos = await vencimientos.proximos(desde: ahora, dias: 14);
    } catch (_) {
      proximos = const [];
    }
    final lista = calcularRecordatorios(
      preferencias: preferencias,
      ahora: ahora,
      vencimientos: proximos,
    );
    for (final r in lista) {
      await notificador.programar(
        NotificacionLocal(
          id: idDeNotificacion(r.clave),
          titulo: tituloDeAviso(r.tipo),
          canal: canalDe(r.tipo),
        ),
        r.cuando,
        zona: preferencias.zonaHoraria,
      );
      _propios.add(idDeNotificacion(r.clave));
    }
    await almacen?.escribir(_clave, jsonEncode(_propios.toList()));
    return lista;
  }
}
