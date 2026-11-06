/// Recordatorios locales de Hábitos (Fase 3, reglas 113 a 119): se programan en
/// el teléfono y la tablet personal desde la copia local, sin servidor, sin
/// Firebase y sin señal, con la misma infraestructura de los avisos (canales,
/// permiso, hash de la `clave` como id). **Nada pasa por el servidor**: Google
/// no ve ni un identificador.
///
/// Discreción: título del catálogo (≤ 40 caracteres, sin dígitos ni nombres),
/// cuerpo vacío. Lo **sensible** (cualquier hábito a eliminar, el cierre de ese
/// día, el diario, el respaldo, verificar la frase) se anuncia solo como
/// *"Recordatorio"* por el canal *Hábitos · Reservados* y su único botón es
/// *Posponer 10 min*: ninguna acción escribe un dato sensible desde la pantalla
/// bloqueada.
library;

import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart';

import 'aviso.dart';
import 'catalogo_avisos.dart';
import 'notificador.dart';

/// Los tipos locales (`tipos_silenciados` los acepta con el prefijo `hab_`).
abstract final class TipoRecordatorioHabito {
  static const bloque = 'hab_bloque';
  static const lectura = 'hab_lectura';
  static const momento = 'hab_momento';
  static const reservado = 'hab_reservado';
  static const revisionPre = 'hab_revision_pre';
  static const revision = 'hab_revision';
  static const cierreDia = 'hab_cierre_dia';

  static const todos = {
    bloque,
    lectura,
    momento,
    reservado,
    revisionPre,
    revision,
    cierreDia,
  };
}

/// Catálogo cerrado de títulos (regla 114).
const Map<String, String> titulosDeHabitos = {
  TipoRecordatorioHabito.bloque: 'Tu siguiente actividad empieza pronto',
  TipoRecordatorioHabito.lectura: 'Es hora de tu lectura',
  TipoRecordatorioHabito.momento: 'Es hora de tu momento tranquilo',
  TipoRecordatorioHabito.reservado: 'Recordatorio',
  TipoRecordatorioHabito.revisionPre: 'Tu revisión semanal empieza pronto',
  TipoRecordatorioHabito.revision: 'Es hora de tu revisión semanal',
  TipoRecordatorioHabito.cierreDia: 'Es hora de cerrar tu día',
};

/// Un recordatorio que Hábitos pide programar (desde su copia local).
@immutable
class RecordatorioHabito {
  const RecordatorioHabito({
    required this.tipo,
    required this.objetoId,
    required this.cuando,
    this.sensible = false,
    this.nombreEnAviso,
    this.n = 1,
  });

  /// Uno de [TipoRecordatorioHabito.todos].
  final String tipo;

  /// Id del objetivo o bloque; entra en la `clave`, nunca en el texto.
  final String objetoId;

  /// Hora de pared en la zona de la persona.
  final DateTime cuando;

  /// Un hábito a eliminar, el diario, el respaldo o la frase: se anuncia solo
  /// como *"Recordatorio"*, sin ese nombre aunque lo haya.
  final bool sensible;

  /// `nombre_en_aviso` de un objetivo **no sensible**: sale como título
  /// (recortado a 40). Se ignora si es sensible.
  final String? nombreEnAviso;

  /// Para distinguir varios del mismo objeto y día.
  final int n;
}

/// Quién sabe qué recordar: Hábitos, con su copia local.
abstract interface class FuenteDeRecordatoriosHabitos {
  Future<List<RecordatorioHabito>> proximos({
    required DateTime desde,
    required int dias,
  });
}

class SinRecordatoriosDeHabitos implements FuenteDeRecordatoriosHabitos {
  const SinRecordatoriosDeHabitos();

  @override
  Future<List<RecordatorioHabito>> proximos({
    required DateTime desde,
    required int dias,
  }) async => const [];
}

String _dia(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// `hab:{tipo}:{objeto}:{fecha}:{n}` (regla 119): su hash es el id de la
/// notificación, así que un recordatorio reprogramado reemplaza al anterior.
String claveDeRecordatorio(RecordatorioHabito r) =>
    'hab:${tipoEfectivo(r)}:${r.objetoId}:${_dia(r.cuando)}:${r.n}';

/// Lo sensible siempre es `hab_reservado` (regla 114): la `clave`, que se queda
/// en el equipo, no distingue qué clase de recordatorio sensible era.
String tipoEfectivo(RecordatorioHabito r) =>
    r.sensible ? TipoRecordatorioHabito.reservado : r.tipo;

/// El tipo que lleva una clave de recordatorio, o `null` si no lo es.
String? tipoDeClaveDeHabito(String? clave) {
  if (clave == null || !clave.startsWith('hab:')) return null;
  final partes = clave.split(':');
  return partes.length >= 3 ? partes[1] : null;
}

/// Título que se muestra: el nombre opcional solo en lo no sensible.
String tituloDeRecordatorio(RecordatorioHabito r) {
  if (r.sensible) return titulosDeHabitos[TipoRecordatorioHabito.reservado]!;
  final nombre = r.nombreEnAviso?.trim();
  if (nombre != null && nombre.isNotEmpty) {
    // Por grafemas, no por unidades UTF-16: no parte un emoji ni una letra con
    // acento descompuesto (F3-8).
    final salida = StringBuffer();
    var largo = 0;
    for (final g in nombre.characters) {
      if (largo + g.length > largoMaximoTituloAviso) break;
      salida.write(g);
      largo += g.length;
    }
    return salida.toString();
  }
  return titulosDeHabitos[r.tipo] ?? textoAvisoGenerico;
}

CanalAviso canalDeRecordatorio(RecordatorioHabito r) {
  if (r.sensible || r.tipo == TipoRecordatorioHabito.reservado) {
    return CanalAviso.habitosReservados;
  }
  if (r.tipo == TipoRecordatorioHabito.revision ||
      r.tipo == TipoRecordatorioHabito.revisionPre) {
    return CanalAviso.habitosRevision;
  }
  return CanalAviso.habitosRecordatorios;
}

/// Botones: lo sensible solo ofrece *Posponer 10 min* (regla 113).
List<AccionDeNotificacion> accionesDeRecordatorio(RecordatorioHabito r) =>
    r.sensible || r.tipo == TipoRecordatorioHabito.reservado
    ? const [AccionDeNotificacion.posponer10]
    : const [
        AccionDeNotificacion.hecho,
        AccionDeNotificacion.posponer10,
        AccionDeNotificacion.omitir,
      ];

/// Calcula qué se programa. Pura.
///
/// Solo los próximos [dias] (7), sin lo pasado ni los tipos silenciados. En
/// **horas silenciosas** el recordatorio se queda en su hora pero llega sin
/// sonido ni vibración (no se cancela; regla 116); eso lo decide
/// [sonarEn]. Sin tope diario: los programó la persona.
List<RecordatorioHabito> recordatoriosAProgramar({
  required List<RecordatorioHabito> candidatos,
  required PreferenciasAvisos preferencias,
  required DateTime ahora,
  int dias = 7,
  bool modoFoco = false,
}) {
  final limite = ahora.add(Duration(days: dias));
  const esenciales = {
    TipoRecordatorioHabito.reservado,
    TipoRecordatorioHabito.revision,
    TipoRecordatorioHabito.cierreDia,
  };
  return [
    for (final r in candidatos)
      if (r.cuando.isAfter(ahora) &&
          !r.cuando.isAfter(limite) &&
          TipoRecordatorioHabito.todos.contains(r.tipo) &&
          !preferencias.tiposSilenciados.contains(r.tipo) &&
          (!modoFoco || esenciales.contains(r.tipo)))
        r,
  ]..sort((a, b) => a.cuando.compareTo(b.cuando));
}

/// ¿Suena (sonido y vibración)? No en las horas silenciosas.
bool sonarEn(PreferenciasAvisos preferencias, DateTime cuando) =>
    !preferencias.enSilencio(HoraDelDia(cuando.hour, cuando.minute));

/// Cuántos minutos se pospone con el botón *Posponer 10 min*.
const minutosDePosponer = 10;

/// Arma la notificación de un recordatorio.
NotificacionLocal notificacionDeRecordatorio(
  RecordatorioHabito r,
  PreferenciasAvisos preferencias,
) {
  final clave = claveDeRecordatorio(r);
  return NotificacionLocal(
    id: idDeNotificacion(clave),
    titulo: tituloDeRecordatorio(r),
    canal: canalDeRecordatorio(r),
    sonar: sonarEn(preferencias, r.cuando),
    carga: clave,
    acciones: accionesDeRecordatorio(r),
  );
}

// ---------------------------------------------------------------- servicio

/// Lo que ya hizo la persona desde la notificación (*Hecho* u *Omitir*); lo
/// recoge Hábitos para guardarlo. Solo de lo no sensible.
@immutable
class AccionDeRecordatorio {
  const AccionDeRecordatorio({
    required this.clave,
    required this.accion,
    required this.en,
  });

  final String clave;
  final AccionDeNotificacion accion;
  final DateTime en;

  Map<String, Object?> aJson() => {
    'clave': clave,
    'accion': accion.id,
    'en': en.toUtc().toIso8601String(),
  };
}
