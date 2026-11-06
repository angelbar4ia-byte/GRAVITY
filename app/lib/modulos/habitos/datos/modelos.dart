/// Modelos de datos de Hábitos en la app (filas de `hab_objetivos` y
/// `hab_registros`). Los sensibles viven en documentos cifrados, no aquí.
library;

import 'package:habitos_dominio/habitos_dominio.dart';
import 'package:uuid/uuid.dart';

enum EstadoRegistro { pendiente, hecho, parcial, omitido, pospuesto }

class ObjetivoHab {
  const ObjetivoHab({
    required this.id,
    required this.titulo,
    required this.area,
    required this.tipo,
    required this.fechaInicio,
    this.unidad,
    this.metaValor,
    this.frecuencia = Frecuencia.diaria,
    this.diasSemana = 127,
    this.minimo = false,
    this.esencial = false,
    this.motivo,
    this.estado = 'activo',
    this.fechaObjetivo,
    required this.modificadoEn,
  });

  final String id;
  final String titulo;
  final String area;
  final TipoObjetivo tipo;
  final DateTime fechaInicio;
  final String? unidad;
  final int? metaValor;
  final Frecuencia frecuencia;
  final int diasSemana;
  final bool minimo;
  final bool esencial;
  final String? motivo;
  final String estado;
  final DateTime? fechaObjetivo;
  final DateTime modificadoEn;

  bool get activo => estado == 'activo';

  /// ¿Toca este objetivo en [f]? (diarios y por días de la semana; los de
  /// N por semana y semanales aparecen todos los días hasta cumplirse).
  bool programadoEn(DateTime f) {
    final d = soloDia(f);
    if (d.isBefore(soloDia(fechaInicio))) return false;
    if (fechaObjetivo != null && d.isAfter(soloDia(fechaObjetivo!))) {
      return false;
    }
    if (frecuencia == Frecuencia.diasSemana) {
      return diasSemana & mascaraDia(d) != 0;
    }
    return true;
  }

  ObjetivoHab copiar({String? estado, DateTime? modificadoEn}) => ObjetivoHab(
    id: id,
    titulo: titulo,
    area: area,
    tipo: tipo,
    fechaInicio: fechaInicio,
    unidad: unidad,
    metaValor: metaValor,
    frecuencia: frecuencia,
    diasSemana: diasSemana,
    minimo: minimo,
    esencial: esencial,
    motivo: motivo,
    estado: estado ?? this.estado,
    fechaObjetivo: fechaObjetivo,
    modificadoEn: modificadoEn ?? this.modificadoEn,
  );

  /// Copia con los campos editables cambiados (E4). Conserva el id, el tipo,
  /// la fecha de inicio, el estado y la fecha objetivo: así los registros
  /// (que cuelgan del id) y la racha no se tocan.
  ObjetivoHab editado({
    required String titulo,
    required String area,
    String? unidad,
    int? metaValor,
    required Frecuencia frecuencia,
    required int diasSemana,
    bool minimo = false,
    bool esencial = false,
    String? motivo,
    required DateTime modificadoEn,
  }) => ObjetivoHab(
    id: id,
    titulo: titulo,
    area: area,
    tipo: tipo,
    fechaInicio: fechaInicio,
    unidad: unidad,
    metaValor: metaValor,
    frecuencia: frecuencia,
    diasSemana: diasSemana,
    minimo: minimo,
    esencial: esencial,
    motivo: motivo,
    estado: estado,
    fechaObjetivo: fechaObjetivo,
    modificadoEn: modificadoEn,
  );

  static const _frecuenciaSql = {
    Frecuencia.diaria: 'diaria',
    Frecuencia.diasSemana: 'dias_semana',
    Frecuencia.nPorSemana: 'n_por_semana',
    Frecuencia.semanal: 'semanal',
    Frecuencia.total: 'total',
  };

  /// Fila para `hab_objetivos` (sin `persona_id`, `hogar_id` ni
  /// `actualizado_en`: los pone el servidor o la cola).
  Map<String, Object?> aFila() => {
    'id': id,
    'titulo': titulo,
    'area': area,
    'tipo': tipo.name,
    'unidad': unidad,
    'meta_valor': metaValor,
    'frecuencia': _frecuenciaSql[frecuencia],
    'dias_semana': diasSemana,
    'fecha_inicio': _fecha(fechaInicio),
    'fecha_objetivo': fechaObjetivo == null ? null : _fecha(fechaObjetivo!),
    'minimo': minimo,
    'esencial': esencial,
    'motivo': motivo,
    'estado': estado,
    'modificado_en': modificadoEn.toUtc().toIso8601String(),
  };

  static ObjetivoHab deFila(Map<String, dynamic> f) => ObjetivoHab(
    id: f['id'] as String,
    titulo: f['titulo'] as String,
    area: f['area'] as String,
    tipo: TipoObjetivo.values.byName(f['tipo'] as String),
    unidad: f['unidad'] as String?,
    metaValor: f['meta_valor'] as int?,
    frecuencia: _frecuenciaSql.entries
        .firstWhere(
          (e) => e.value == f['frecuencia'],
          orElse: () => const MapEntry(Frecuencia.diaria, 'diaria'),
        )
        .key,
    diasSemana: (f['dias_semana'] as int?) ?? 127,
    fechaInicio: DateTime.parse(f['fecha_inicio'] as String),
    fechaObjetivo: f['fecha_objetivo'] == null
        ? null
        : DateTime.parse(f['fecha_objetivo'] as String),
    minimo: (f['minimo'] as bool?) ?? false,
    esencial: (f['esencial'] as bool?) ?? false,
    motivo: f['motivo'] as String?,
    estado: (f['estado'] as String?) ?? 'activo',
    modificadoEn: DateTime.parse(f['modificado_en'] as String),
  );
}

class RegistroHab {
  const RegistroHab({
    required this.id,
    this.objetivoId,
    this.bloqueId,
    required this.fecha,
    required this.estado,
    required this.modificadoEn,
    this.valor,
    this.movidoAMin,
    this.motivoOmision,
  });

  final String id;
  final String? objetivoId;
  final String? bloqueId;
  final DateTime fecha;
  final EstadoRegistro estado;
  final DateTime modificadoEn;
  final int? valor;
  final int? movidoAMin;
  final String? motivoOmision;

  Map<String, Object?> aFila() => {
    'id': id,
    'objetivo_id': objetivoId,
    'bloque_id': bloqueId,
    'fecha': _fecha(fecha),
    'estado': estado.name,
    'valor': valor,
    'movido_a': movidoAMin == null ? null : _hora(movidoAMin!),
    'motivo_omision': motivoOmision,
    'modificado_en': modificadoEn.toUtc().toIso8601String(),
  };

  static RegistroHab deFila(Map<String, dynamic> f) {
    final m = f['movido_a'] as String?;
    return RegistroHab(
      id: f['id'] as String,
      objetivoId: f['objetivo_id'] as String?,
      bloqueId: f['bloque_id'] as String?,
      fecha: DateTime.parse(f['fecha'] as String),
      estado: EstadoRegistro.values.byName(f['estado'] as String),
      valor: f['valor'] as int?,
      movidoAMin: m == null
          ? null
          : int.parse(m.substring(0, 2)) * 60 + int.parse(m.substring(3, 5)),
      motivoOmision: f['motivo_omision'] as String?,
      modificadoEn: DateTime.parse(f['modificado_en'] as String),
    );
  }
}

String _fecha(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String _hora(int min) =>
    '${(min ~/ 60).toString().padLeft(2, '0')}:${(min % 60).toString().padLeft(2, '0')}';

const _ns = '6b1f8e0a-4c3d-5e2f-9a7b-1d2c3e4f5a6b';

/// Id estable del registro de un elemento en un día (convención 5).
String idRegistro(String objetivoId, DateTime fecha) =>
    const Uuid().v5(_ns, 'registro|$objetivoId|${_fecha(fecha)}');
