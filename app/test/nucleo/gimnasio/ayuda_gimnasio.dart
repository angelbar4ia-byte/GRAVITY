/// Filas de ejemplo de «Mi gimnasio» (inventadas) con la forma del servidor,
/// como las arma el dominio (`SesionRegistrada.aJsonServidor`).
library;

import 'package:gravity/nucleo/gimnasio/ids_gimnasio.dart';

const persona = 'uid-ana';

/// La fecha de las pruebas: lunes 23 de noviembre de 2026.
final lunes = DateTime(2026, 11, 23);

String idSesion({
  String p = persona,
  DateTime? fecha,
  String plantilla = 'A',
}) => IdsGimnasio.sesion(p, fecha ?? lunes, plantilla);

/// Lo que devuelve `SesionRegistrada.aJsonServidor` (sin `modificado_en`).
Map<String, Object?> sesion({
  String p = persona,
  DateTime? fecha,
  String plantilla = 'A',
  String estado = 'en_curso',
  int? esfuerzo,
  String? bloqueId,
  String? ventana = 'noche',
}) {
  final f = fecha ?? lunes;
  final termina = estado != 'en_curso';
  return {
    'id': idSesion(p: p, fecha: f, plantilla: plantilla),
    'fecha':
        '${f.year}-${f.month.toString().padLeft(2, '0')}-${f.day.toString().padLeft(2, '0')}',
    'plantilla': plantilla,
    'version': 'estandar',
    'semana_tipo': 'carga',
    'ventana': ventana,
    'bloque_id': bloqueId,
    'inicio': DateTime(f.year, f.month, f.day, 19, 15).toIso8601String(),
    'fin': termina
        ? DateTime(f.year, f.month, f.day, 20, 0).toIso8601String()
        : null,
    'estado': estado,
    'esfuerzo': esfuerzo,
    'energia': termina ? 3 : null,
    'plan': [
      {
        'ejercicio': 'press_pecho',
        'variante': 'press_estacion',
        'series': 3,
        'reps_min': 10,
        'reps_max': 12,
      },
    ],
    'catalogo_version': 1,
  };
}

/// Lo que devuelve `SerieRegistrada.aJsonServidor` (sin `modificado_en`).
Map<String, Object?> serie({
  String p = persona,
  required String sesionId,
  String ejercicio = 'press_pecho',
  int n = 1,
  String? lado,
  int reps = 12,
  int? cargaPasos = 5,
  String? bandaId,
  String? motivo,
}) => {
  'id': IdsGimnasio.serie(p, sesionId, ejercicio, n, lado: lado),
  'sesion_id': sesionId,
  'ejercicio_id': ejercicio,
  'variante_id': 'press_estacion',
  'n': n,
  'lado': lado,
  'reps': reps,
  'segundos': null,
  'carga_pasos': cargaPasos,
  'banda_id': bandaId,
  'esfuerzo': 3,
  'descanso_real_s': 62,
  'sustituye_a': null,
  'motivo_cambio': motivo,
};
