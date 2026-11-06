/// Bloques de la agenda, ajustes y revisiones (filas de `hab_bloques`,
/// `hab_ajustes` y `hab_revisiones`). Los bloques de hábitos sensibles NO
/// viven aquí (regla 63).
library;

import 'package:habitos_dominio/habitos_dominio.dart';

class BloqueHab {
  const BloqueHab({
    required this.id,
    required this.titulo,
    required this.area,
    required this.inicioMin,
    required this.duracionMin,
    required this.dias,
    required this.desde,
    required this.modificadoEn,
    this.tipo = 'actividad',
    this.hasta,
    this.cadaSemanas = 1,
    this.minimo = false,
    this.esencial = false,
    this.recordarMin,
    this.objetivoId,
    this.activo = true,
  });

  final String id;
  final String titulo;
  final String area;
  final String tipo; // actividad | trabajo | traslado | revision | cita
  final int inicioMin;
  final int duracionMin;
  final int dias;
  final DateTime desde;
  final DateTime? hasta;
  final int cadaSemanas;
  final bool minimo;
  final bool esencial;
  final int? recordarMin;
  final String? objetivoId;
  final bool activo;
  final DateTime modificadoEn;

  /// Los fijos (trabajo y traslado) restan tiempo libre (regla 25).
  bool get fijo => tipo == 'trabajo' || tipo == 'traslado';

  BloqueRecurrente get recurrente => BloqueRecurrente(
        id: id,
        inicioMin: inicioMin,
        duracionMin: duracionMin,
        dias: dias,
        desde: desde,
        hasta: hasta,
        cadaSemanas: cadaSemanas,
        minimo: minimo,
      );

  BloqueHab copiar({bool? activo, DateTime? modificadoEn}) => BloqueHab(
        id: id,
        titulo: titulo,
        area: area,
        inicioMin: inicioMin,
        duracionMin: duracionMin,
        dias: dias,
        desde: desde,
        hasta: hasta,
        cadaSemanas: cadaSemanas,
        minimo: minimo,
        esencial: esencial,
        recordarMin: recordarMin,
        objetivoId: objetivoId,
        tipo: tipo,
        activo: activo ?? this.activo,
        modificadoEn: modificadoEn ?? this.modificadoEn,
      );

  Map<String, Object?> aFila() => {
        'id': id,
        'titulo': titulo,
        'area': area,
        'tipo': tipo,
        'objetivo_id': objetivoId,
        'inicio': _hora(inicioMin),
        'duracion_min': duracionMin,
        'dias': dias,
        'cada_semanas': cadaSemanas,
        'desde': _fecha(desde),
        'hasta': hasta == null ? null : _fecha(hasta!),
        'minimo': minimo,
        'esencial': esencial,
        'recordar_min': recordarMin,
        'activo': activo,
        'modificado_en': modificadoEn.toUtc().toIso8601String(),
      };

  static BloqueHab deFila(Map<String, dynamic> f) => BloqueHab(
        id: f['id'] as String,
        titulo: f['titulo'] as String,
        area: f['area'] as String,
        tipo: f['tipo'] as String,
        objetivoId: f['objetivo_id'] as String?,
        inicioMin: _min(f['inicio'] as String),
        duracionMin: f['duracion_min'] as int,
        dias: f['dias'] as int,
        cadaSemanas: (f['cada_semanas'] as int?) ?? 1,
        desde: DateTime.parse(f['desde'] as String),
        hasta: f['hasta'] == null ? null : DateTime.parse(f['hasta'] as String),
        minimo: (f['minimo'] as bool?) ?? false,
        esencial: (f['esencial'] as bool?) ?? false,
        recordarMin: f['recordar_min'] as int?,
        activo: (f['activo'] as bool?) ?? true,
        modificadoEn: DateTime.parse(f['modificado_en'] as String),
      );
}

class AjustesHab {
  const AjustesHab({
    this.despertarMin = 360,
    this.dormirMin = 1320,
    this.areasActivas = const ['espiritual', 'salud', 'educacion', 'personal', 'laboral', 'proyectos'],
    this.minimosModo = ModoMinimos.porArea,
    this.graciaSemanal = 1,
    this.revisionDia = 6,
    this.revisionHoraMin = 870,
    this.revisionAvisoMin = 15,
    this.darActivo = false,
    this.asistente = const {},
  });

  final int despertarMin;
  final int dormirMin;
  final List<String> areasActivas;
  final ModoMinimos minimosModo;
  final int graciaSemanal;
  final int revisionDia;
  final int revisionHoraMin;
  final int revisionAvisoMin;
  final bool darActivo;
  final Map<String, Object?> asistente;

  AjustesHab copiar({
    int? despertarMin,
    int? dormirMin,
    List<String>? areasActivas,
    int? revisionDia,
    int? revisionHoraMin,
    int? revisionAvisoMin,
    bool? darActivo,
    Map<String, Object?>? asistente,
  }) =>
      AjustesHab(
        despertarMin: despertarMin ?? this.despertarMin,
        dormirMin: dormirMin ?? this.dormirMin,
        areasActivas: areasActivas ?? this.areasActivas,
        minimosModo: minimosModo,
        graciaSemanal: graciaSemanal,
        revisionDia: revisionDia ?? this.revisionDia,
        revisionHoraMin: revisionHoraMin ?? this.revisionHoraMin,
        revisionAvisoMin: revisionAvisoMin ?? this.revisionAvisoMin,
        darActivo: darActivo ?? this.darActivo,
        asistente: asistente ?? this.asistente,
      );

  /// Solo lo que la app puede cambiar (UPDATE de `hab_ajustes`).
  Map<String, Object?> aCambios(DateTime ahora) => {
        'despertar': _hora(despertarMin),
        'dormir': _hora(dormirMin),
        'areas_activas': areasActivas,
        'minimos_modo': minimosModo == ModoMinimos.porArea ? 'por_area' : 'marcados',
        'gracia_semanal': graciaSemanal,
        'revision_dia': revisionDia,
        'revision_hora': _hora(revisionHoraMin),
        'revision_aviso_min': revisionAvisoMin,
        'dar_activo': darActivo,
        'asistente': asistente,
        'modificado_en': ahora.toUtc().toIso8601String(),
      };

  static AjustesHab deFila(Map<String, dynamic> f) => AjustesHab(
        despertarMin: f['despertar'] == null ? 360 : _min(f['despertar'] as String),
        dormirMin: f['dormir'] == null ? 1320 : _min(f['dormir'] as String),
        areasActivas: (f['areas_activas'] as List).cast<String>(),
        minimosModo: f['minimos_modo'] == 'marcados' ? ModoMinimos.marcados : ModoMinimos.porArea,
        graciaSemanal: f['gracia_semanal'] as int,
        revisionDia: f['revision_dia'] as int,
        revisionHoraMin: _min(f['revision_hora'] as String),
        revisionAvisoMin: f['revision_aviso_min'] as int,
        darActivo: f['dar_activo'] as bool,
        asistente: ((f['asistente'] as Map?) ?? const {}).cast<String, Object?>(),
      );
}

class RevisionHab {
  const RevisionHab({
    required this.id,
    required this.semana,
    required this.estado,
    required this.modificadoEn,
    this.resumen = const {},
    this.ajustes = const [],
    this.darCumplido,
  });
  final String id;
  final DateTime semana; // lunes
  final EstadoRevision estado;
  final DateTime modificadoEn;
  final Map<String, Object?> resumen;
  final List<Object?> ajustes;
  final bool? darCumplido;

  static const _estados = {
    EstadoRevision.pendiente: 'pendiente',
    EstadoRevision.enCurso: 'en_curso',
    EstadoRevision.completada: 'completada',
    EstadoRevision.omitida: 'omitida',
  };

  Map<String, Object?> aFila() => {
        'id': id,
        'semana': _fecha(semana),
        'estado': _estados[estado],
        'resumen': resumen,
        'ajustes': ajustes,
        'dar_cumplido': darCumplido,
        'completada_en': estado == EstadoRevision.completada
            ? modificadoEn.toUtc().toIso8601String()
            : null,
        'modificado_en': modificadoEn.toUtc().toIso8601String(),
      };
}

String _fecha(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String _hora(int min) =>
    '${(min ~/ 60).toString().padLeft(2, '0')}:${(min % 60).toString().padLeft(2, '0')}';
int _min(String h) => int.parse(h.substring(0, 2)) * 60 + int.parse(h.substring(3, 5));
