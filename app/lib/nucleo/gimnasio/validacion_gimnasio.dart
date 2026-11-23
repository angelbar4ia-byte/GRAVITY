/// Validación de las filas de «Mi gimnasio» **antes** de guardarlas y
/// encolarlas: las mismas reglas que las restricciones de la migración
/// `20261152000000_habitos_gimnasio.sql`. Así una fila que el servidor
/// rechazaría con 23514 (permanente: queda en «requiere atención») ni siquiera
/// entra a la cola.
///
/// Los errores dicen **qué campo** falló, nunca su valor.
library;

import 'dart:convert';

import '../cola/contrato_gimnasio.dart';

/// Una fila no cumple las reglas de su tabla. El mensaje nombra la tabla y el
/// campo, no el valor (R6).
class FilaGimnasioInvalida extends ArgumentError {
  FilaGimnasioInvalida(this.tabla, this.campo)
    : super('Dato inválido en $tabla: $campo.');

  final String tabla;
  final String campo;
}

final _idCatalogo = RegExp(r'^[a-z0-9][a-z0-9_.:-]{0,59}$');
final _itemInventario = RegExp(r'^[a-z0-9][a-z0-9_.:-]{0,59}$');
final _puestoSuelto = RegExp(r'^otro:[^\x00-\x1f\x7f]{1,55}$');
final _fecha = RegExp(r'^\d{4}-\d{2}-\d{2}$');
final _hora = RegExp(r'^([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$');
final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);
final _campoConfirmado = RegExp(r'^[a-z][a-z0-9_]{0,39}$');
final _fichaConfirmada = RegExp(r'^[a-z0-9][a-z0-9_.:/-]{0,39}$');

const _versiones = {'auto', 'corta', 'estandar', 'larga'};
const _ventanas = {'manana', 'noche', 'flexible'};
const _plantillas = {'A', 'B', 'C', 'R1', 'R2'};

/// ¿Es una fecha `AAAA-MM-DD` real?
bool esFechaIso(Object? v) {
  if (v is! String || !_fecha.hasMatch(v)) return false;
  final d = DateTime.tryParse(v);
  return d != null && d.toIso8601String().startsWith(v);
}

bool _esLunes(String f) => DateTime.parse(f).weekday == DateTime.monday;

/// Verifica [fila] (ya normalizada, con **todas** las columnas de la tabla)
/// contra las reglas de [tabla]. Lanza [FilaGimnasioInvalida].
void validarFilaGimnasio(String tabla, Map<String, Object?> fila) {
  final permitidas = columnasQueSeMandanGimnasio[tabla];
  if (permitidas == null) throw FilaGimnasioInvalida(tabla, 'tabla');
  Never mal(String c) => throw FilaGimnasioInvalida(tabla, c);

  for (final k in fila.keys) {
    if (!permitidas.contains(k)) mal(k);
    // Ninguna columna habla de molestias, zonas ni dolor (PG-03, CA-G-28).
    if (raicesProhibidasEnCarga.any(k.contains)) mal(k);
  }
  bool entero(String c, int min, int max, {bool nulo = false}) {
    final v = fila[c];
    if (v == null) return nulo ? true : mal(c);
    return v is int && v >= min && v <= max ? true : mal(c);
  }

  void unoDe(String c, Set<String> validos, {bool nulo = false}) {
    final v = fila[c];
    if (v == null) {
      if (!nulo) mal(c);
      return;
    }
    if (v is! String || !validos.contains(v)) mal(c);
  }

  void patron(String c, RegExp re, {bool nulo = false}) {
    final v = fila[c];
    if (v == null) {
      if (!nulo) mal(c);
      return;
    }
    if (v is! String || !re.hasMatch(v)) mal(c);
  }

  void fecha(String c, {bool nulo = false}) {
    final v = fila[c];
    if (v == null) {
      if (!nulo) mal(c);
      return;
    }
    if (!esFechaIso(v)) mal(c);
  }

  void instante(String c, {bool nulo = false}) {
    final v = fila[c];
    if (v == null) {
      if (!nulo) mal(c);
      return;
    }
    if (v is! String || DateTime.tryParse(v) == null) mal(c);
  }

  void booleano(String c) {
    if (fila[c] is! bool) mal(c);
  }

  instante('modificado_en');

  switch (tabla) {
    case 'hab_ent_perfil':
      entero('dias_plan', 3, 5);
      unoDe('version_pref', _versiones);
      unoDe('ventana', _ventanas);
      patron('noche_desde', _hora);
      unoDe('objetivo', {'fuerza', 'masa', 'perdida_grasa', 'salud_general'});
      unoDe('nivel', {'principiante', 'intermedio'});
      fecha('inicio_ciclo', nulo: true);
      if (fila['inicio_ciclo'] != null &&
          !_esLunes(fila['inicio_ciclo']! as String)) {
        mal('inicio_ciclo');
      }
      final ciclo = fila['ciclo_semanas'];
      if (ciclo is! int || !(ciclo == 0 || (ciclo >= 3 && ciclo <= 8))) {
        mal('ciclo_semanas');
      }
      entero('descanso_s', 30, 120, nulo: true);
      entero('margen_dormir_min', 0, 240);
      fecha('prueba_desde', nulo: true);
      unoDe('prueba_ventana', {'manana', 'noche'}, nulo: true);
      if ((fila['prueba_desde'] == null) != (fila['prueba_ventana'] == null)) {
        mal('prueba_ventana');
      }
      booleano('voz_descanso');
      instante('aviso_visto_en', nulo: true);
    case 'hab_ent_plan_dias':
      entero('dia_semana', 1, 7);
      unoDe('tipo', {'A', 'B', 'C', 'R1', 'R2', 'bici', 'descanso'});
      unoDe('version', _versiones);
      patron('hora', _hora, nulo: true);
    case 'hab_ent_inventario':
      final id = fila['item_id'];
      if (id is! String ||
          id.isEmpty ||
          id.length > 60 ||
          !(_itemInventario.hasMatch(id) || _puestoSuelto.hasMatch(id))) {
        mal('item_id');
      }
      unoDe('estado', {'disponible', 'no_disponible', 'futuro'});
      final conf = fila['confirmado'];
      if (conf is! Map || utf8.encode(jsonEncode(conf)).length > 2048) {
        mal('confirmado');
      }
      if (conf.length > 20) mal('confirmado');
      for (final e in conf.entries) {
        final v = e.value;
        if (e.key is! String ||
            !_campoConfirmado.hasMatch(e.key as String) ||
            raicesProhibidasEnCarga.any((r) => (e.key as String).contains(r)) ||
            !(v == null ||
                v is num ||
                v is bool ||
                (v is String && _fichaConfirmada.hasMatch(v)))) {
          mal('confirmado');
        }
      }
      final notas = fila['notas'];
      if (notas != null && (notas is! String || notas.length > 200)) {
        mal('notas');
      }
    case 'hab_ent_bandas':
      patron('id', _uuid);
      final nombre = fila['nombre'];
      if (nombre is! String ||
          nombre.trim().isEmpty ||
          nombre.length > 40) {
        mal('nombre');
      }
      entero('orden', 1, 20);
      entero('resistencia_kg_x10', 1, 2000, nulo: true);
      entero('cantidad', 1, 10);
      booleano('activa');
    case 'hab_ent_sesiones':
      patron('id', _uuid);
      fecha('fecha');
      unoDe('plantilla', _plantillas);
      unoDe('version', {'corta', 'estandar', 'larga'});
      unoDe('semana_tipo', {'carga', 'descarga', 'reentrada', 'foco'});
      unoDe('ventana', {'manana', 'noche'});
      patron('bloque_id', _uuid, nulo: true);
      instante('inicio');
      instante('fin', nulo: true);
      unoDe('estado', {'en_curso', 'completa', 'parcial'});
      if ((fila['estado'] == 'en_curso') != (fila['fin'] == null)) mal('fin');
      if (fila['fin'] != null &&
          DateTime.parse(fila['fin']! as String).isBefore(
            DateTime.parse(fila['inicio']! as String),
          )) {
        mal('fin');
      }
      entero('esfuerzo', 1, 5, nulo: true);
      entero('energia', 1, 5, nulo: true);
      final plan = fila['plan'];
      if (plan is! List ||
          plan.length > 40 ||
          utf8.encode(jsonEncode(plan)).length > 2048) {
        mal('plan');
      }
      for (final e in plan) {
        if (e is! Map ||
            e['ejercicio'] is! String ||
            !_idCatalogo.hasMatch(e['ejercicio'] as String)) {
          mal('plan');
        }
        for (final k in e.keys) {
          if (!const {
            'ejercicio',
            'variante',
            'series',
            'reps_min',
            'reps_max',
          }.contains(k)) {
            mal('plan');
          }
        }
        final v = e['variante'];
        if (v != null && (v is! String || !_idCatalogo.hasMatch(v))) {
          mal('plan');
        }
        for (final k in const ['series', 'reps_min', 'reps_max']) {
          final n = e[k];
          if (n != null && (n is! int || n < 0 || n > (k == 'series' ? 12 : 100))) {
            mal('plan');
          }
        }
        final mn = e['reps_min'];
        final mx = e['reps_max'];
        if (mn is int && mx is int && mn > mx) mal('plan');
      }
      final cv = fila['catalogo_version'];
      if (cv is! int || cv < 1) mal('catalogo_version');
    case 'hab_ent_series':
      patron('id', _uuid);
      patron('sesion_id', _uuid);
      patron('ejercicio_id', _idCatalogo);
      patron('variante_id', _idCatalogo);
      entero('n', 1, 12);
      unoDe('lado', {'izquierdo', 'derecho'}, nulo: true);
      entero('reps', 0, 100, nulo: true);
      entero('segundos', 0, 900, nulo: true);
      entero('carga_pasos', 0, 60, nulo: true);
      patron('banda_id', _uuid, nulo: true);
      entero('esfuerzo', 1, 5, nulo: true);
      entero('descanso_real_s', 0, 900, nulo: true);
      patron('sustituye_a', _idCatalogo, nulo: true);
      // PG-19: el motivo «molestia» no existe; el servidor ve «otra».
      unoDe('motivo_cambio', {'no_disponible', 'preferencia', 'otra'}, nulo: true);
    default:
      mal('tabla');
  }
}
