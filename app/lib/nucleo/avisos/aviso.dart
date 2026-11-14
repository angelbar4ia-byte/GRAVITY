/// Un aviso de la persona (fila de `avisos`, que solo ella lee por RLS) y sus
/// preferencias (`avisos_preferencias`). Fase 2, D20.
library;

import 'package:flutter/foundation.dart';

import 'catalogo_avisos.dart';

enum EstadoAviso {
  pendiente,
  enviada,
  agrupada,
  cancelada,
  leida,
  resuelta,
  pospuesta;

  static EstadoAviso desdeTexto(String? texto) => values.firstWhere(
    (e) => e.name == texto,
    orElse: () => EstadoAviso.pendiente,
  );

  /// Lo que aún pide atención (en la bandeja): todo menos lo cancelado y lo
  /// resuelto. Leído no es resuelto.
  bool get abierto => this != cancelada && this != resuelta;

  /// Lo que todavía puede salir como notificación: ni leído, ni agrupado (solo
  /// bandeja), ni resuelto o cancelado.
  bool get notificable =>
      this == pendiente || this == enviada || this == pospuesta;
}

@immutable
class Aviso {
  const Aviso({
    required this.id,
    required this.tipo,
    required this.clave,
    required this.estado,
    required this.creadoEn,
    this.libroId,
    this.objetoTipo,
    this.objetoId,
    this.enviarEn,
  });

  final String id;

  /// Del catálogo cerrado (`catalogo_avisos.dart`).
  final String tipo;

  /// Idempotencia: la misma clave nunca avisa dos veces.
  final String clave;
  final EstadoAviso estado;
  final DateTime creadoEn;
  final String? libroId;
  final String? objetoTipo;
  final String? objetoId;
  final DateTime? enviarEn;

  SeveridadAviso get severidad => severidadDe(tipo);

  /// Lo único que se muestra fuera de la app.
  String get titulo => tituloDeAviso(tipo);

  factory Aviso.desdeJson(Map<String, Object?> json) => Aviso(
    id: json['id']! as String,
    tipo: json['tipo']! as String,
    clave: (json['clave'] as String?) ?? json['id']! as String,
    estado: EstadoAviso.desdeTexto(json['estado'] as String?),
    creadoEn:
        DateTime.tryParse((json['creado_en'] as String?) ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    libroId: json['libro_id'] as String?,
    objetoTipo: json['objeto_tipo'] as String?,
    objetoId: json['objeto_id'] as String?,
    enviarEn: DateTime.tryParse((json['enviar_en'] as String?) ?? ''),
  );

  Aviso copiarCon({EstadoAviso? estado, DateTime? enviarEn}) => Aviso(
    id: id,
    tipo: tipo,
    clave: clave,
    estado: estado ?? this.estado,
    creadoEn: creadoEn,
    libroId: libroId,
    objetoTipo: objetoTipo,
    objetoId: objetoId,
    enviarEn: enviarEn ?? this.enviarEn,
  );
}

/// Hora del día sin fecha.
@immutable
class HoraDelDia implements Comparable<HoraDelDia> {
  const HoraDelDia(this.hora, [this.minuto = 0]);

  final int hora;
  final int minuto;

  int get minutos => hora * 60 + minuto;

  /// `"22:00"` o `"22:00:00"`.
  static HoraDelDia? desdeTexto(String? texto) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(texto ?? '');
    if (m == null) return null;
    final h = int.parse(m.group(1)!);
    final min = int.parse(m.group(2)!);
    return h > 23 || min > 59 ? null : HoraDelDia(h, min);
  }

  String get texto =>
      '${hora.toString().padLeft(2, '0')}:${minuto.toString().padLeft(2, '0')}';

  @override
  int compareTo(HoraDelDia otra) => minutos.compareTo(otra.minutos);

  @override
  bool operator ==(Object other) =>
      other is HoraDelDia && other.minutos == minutos;

  @override
  int get hashCode => minutos;

  @override
  String toString() => texto;
}

/// Preferencias de avisos de la persona (regla 48). Los valores por omisión son
/// los de la especificación.
@immutable
class PreferenciasAvisos {
  const PreferenciasAvisos({
    this.zonaHoraria = 'America/Mexico_City',
    this.silencioDesde = const HoraDelDia(22),
    this.silencioHasta = const HoraDelDia(7),
    this.criticasEnSilencio = false,
    this.topeNoCriticas = 3,
    this.horaVencimientos = const HoraDelDia(9),
    this.resumenLunes = const HoraDelDia(8),
    this.recordatorioCierreDia = 7,
    this.recordatorioCierreHora = const HoraDelDia(19),
    this.tiposSilenciados = const {},
    this.pulseraTextoCorto = true,
    this.diasAvisoDeuda = const [3, 1],
  });

  final String zonaHoraria;
  final HoraDelDia silencioDesde;
  final HoraDelDia silencioHasta;
  final bool criticasEnSilencio;

  /// De 0 a 10.
  final int topeNoCriticas;
  final HoraDelDia horaVencimientos;
  final HoraDelDia resumenLunes;

  /// 1 = lunes … 7 = domingo.
  final int recordatorioCierreDia;
  final HoraDelDia recordatorioCierreHora;
  final Set<String> tiposSilenciados;
  final bool pulseraTextoCorto;
  final List<int> diasAvisoDeuda;

  PreferenciasAvisos copiarCon({
    String? zonaHoraria,
    HoraDelDia? silencioDesde,
    HoraDelDia? silencioHasta,
    bool? criticasEnSilencio,
    int? topeNoCriticas,
    HoraDelDia? horaVencimientos,
    HoraDelDia? resumenLunes,
    int? recordatorioCierreDia,
    HoraDelDia? recordatorioCierreHora,
    Set<String>? tiposSilenciados,
    bool? pulseraTextoCorto,
    List<int>? diasAvisoDeuda,
  }) => PreferenciasAvisos(
    zonaHoraria: zonaHoraria ?? this.zonaHoraria,
    silencioDesde: silencioDesde ?? this.silencioDesde,
    silencioHasta: silencioHasta ?? this.silencioHasta,
    criticasEnSilencio: criticasEnSilencio ?? this.criticasEnSilencio,
    topeNoCriticas: topeNoCriticas ?? this.topeNoCriticas,
    horaVencimientos: horaVencimientos ?? this.horaVencimientos,
    resumenLunes: resumenLunes ?? this.resumenLunes,
    recordatorioCierreDia: recordatorioCierreDia ?? this.recordatorioCierreDia,
    recordatorioCierreHora:
        recordatorioCierreHora ?? this.recordatorioCierreHora,
    tiposSilenciados: tiposSilenciados ?? this.tiposSilenciados,
    pulseraTextoCorto: pulseraTextoCorto ?? this.pulseraTextoCorto,
    diasAvisoDeuda: diasAvisoDeuda ?? this.diasAvisoDeuda,
  );

  /// `true` si [hora] cae en las horas silenciosas (cruzan la medianoche
  /// cuando `desde > hasta`).
  bool enSilencio(HoraDelDia hora) {
    final d = silencioDesde.minutos;
    final h = silencioHasta.minutos;
    final x = hora.minutos;
    if (d == h) return false;
    return d < h ? x >= d && x < h : x >= d || x < h;
  }

  /// Valida rangos como lo hace `avisos_actualizar_preferencias`.
  String? get error {
    if (topeNoCriticas < 0 || topeNoCriticas > 10) {
      return 'El tope diario es de 0 a 10.';
    }
    if (recordatorioCierreDia < 1 || recordatorioCierreDia > 7) {
      return 'El día del cierre es de 1 a 7.';
    }
    if (diasAvisoDeuda.length > 3 ||
        diasAvisoDeuda.any((d) => d < 0 || d > 14)) {
      return 'Hasta 3 avisos, entre 0 y 14 días antes.';
    }
    return null;
  }

  Map<String, Object?> aJson() => {
    'zona_horaria': zonaHoraria,
    'silencio_desde': silencioDesde.texto,
    'silencio_hasta': silencioHasta.texto,
    'criticas_en_silencio': criticasEnSilencio,
    'tope_no_criticas': topeNoCriticas,
    'hora_vencimientos': horaVencimientos.texto,
    'resumen_lunes': resumenLunes.texto,
    'recordatorio_cierre_dia': recordatorioCierreDia,
    'recordatorio_cierre_hora': recordatorioCierreHora.texto,
    'tipos_silenciados': tiposSilenciados.toList()..sort(),
    'pulsera_texto_corto': pulseraTextoCorto,
    'dias_aviso_deuda': diasAvisoDeuda,
  };

  factory PreferenciasAvisos.desdeJson(Map<String, Object?> json) {
    const por = PreferenciasAvisos();
    HoraDelDia hora(String clave, HoraDelDia def) =>
        HoraDelDia.desdeTexto(json[clave] as String?) ?? def;
    return PreferenciasAvisos(
      zonaHoraria: (json['zona_horaria'] as String?) ?? por.zonaHoraria,
      silencioDesde: hora('silencio_desde', por.silencioDesde),
      silencioHasta: hora('silencio_hasta', por.silencioHasta),
      criticasEnSilencio: (json['criticas_en_silencio'] as bool?) ?? false,
      topeNoCriticas: (json['tope_no_criticas'] as int?) ?? por.topeNoCriticas,
      horaVencimientos: hora('hora_vencimientos', por.horaVencimientos),
      resumenLunes: hora('resumen_lunes', por.resumenLunes),
      recordatorioCierreDia:
          (json['recordatorio_cierre_dia'] as int?) ??
          por.recordatorioCierreDia,
      recordatorioCierreHora: hora(
        'recordatorio_cierre_hora',
        por.recordatorioCierreHora,
      ),
      tiposSilenciados: {
        for (final t in (json['tipos_silenciados'] as List?) ?? const []) '$t',
      },
      pulseraTextoCorto: (json['pulsera_texto_corto'] as bool?) ?? true,
      diasAvisoDeuda: [
        for (final d in (json['dias_aviso_deuda'] as List?) ?? const [3, 1])
          d as int,
      ],
    );
  }
}
