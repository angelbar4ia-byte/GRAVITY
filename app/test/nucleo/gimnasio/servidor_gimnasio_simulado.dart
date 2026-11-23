/// PostgREST simulado de las seis tablas `hab_ent_*` (migración
/// `20261152000000_habitos_gimnasio.sql`) para probar la cola sin conexión de
/// «Mi gimnasio» contra el contrato del servidor.
///
/// Aplica lo que importa a la cola:
///
/// - `POST /rest/v1/<tabla>?on_conflict=<llave>` con `Prefer:
///   resolution=merge-duplicates` (upsert): la llave debe ser la de la tabla;
///   **último gana** por `modificado_en` (uno más viejo se ignora sin error);
///   columnas que pone el servidor (`persona_id`, `hogar_id`, `actualizado_en`)
///   → 42501.
/// - Únicos naturales: el mismo día y plantilla, o la misma serie, con **otro
///   id** → 23505.
/// - Llaves foráneas: serie sin su sesión o con una banda que no existe, y
///   sesión con un bloque que no existe → 23503.
/// - `DELETE …?id=eq.X` (con cascada de series al borrar una sesión).
/// - Cuota de filas (54000), errores forzados, respuestas perdidas y caída.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:gravity/nucleo/cola/contrato_gimnasio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../cola/postgrest_simulado.dart' show sesionJson;

class PeticionGim {
  PeticionGim(this.metodo, this.uri, this.encabezados, this.cuerpo);

  final String metodo;
  final Uri uri;
  final Map<String, String> encabezados;
  final Object? cuerpo;

  String get tabla => uri.pathSegments.last;
  String? get onConflict => uri.queryParameters['on_conflict'];
  String get prefer => encabezados['prefer'] ?? '';
  Map<String, Object?> get fila => (cuerpo as Map).cast<String, Object?>();

  String get sujeto {
    final partes = (encabezados['authorization'] ?? '')
        .replaceFirst('Bearer ', '')
        .split('.');
    if (partes.length != 3) return '';
    final carga = utf8.decode(base64Url.decode(base64Url.normalize(partes[1])));
    return (jsonDecode(carga) as Map)['sub'] as String;
  }
}

class ErrorGim {
  const ErrorGim(this.codigo, this.mensaje, {this.estado = 400});
  final String codigo;
  final String mensaje;
  final int estado;
}

class ServidorGimnasioSimulado {
  ServidorGimnasioSimulado._(this._http) {
    _http.listen(_atender);
  }

  static Future<ServidorGimnasioSimulado> iniciar() async =>
      ServidorGimnasioSimulado._(
        await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
      );

  final HttpServer _http;
  String get url => 'http://127.0.0.1:${_http.port}';

  /// tabla → (persona|llave) → fila guardada.
  final Map<String, Map<String, Map<String, Object?>>> filas = {};

  /// Todo lo que llegó, en orden.
  final List<PeticionGim> peticiones = [];

  /// Bloques de Hábitos que existen (para `bloque_id`).
  final Set<String> bloques = {};

  /// Tope de filas por tabla (54000 al pasarlo).
  final Map<String, int> topes = {};

  final Map<String, List<ErrorGim>> _errores = {};
  int perderRespuestas = 0;
  bool caido = false;

  Future<void> cerrar() => _http.close(force: true);

  Future<SupabaseClient> cliente(String uid) async {
    final c = SupabaseClient(
      url,
      'llave-publica-de-prueba',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    await c.auth.recoverSession(sesionJson(uid));
    return c;
  }

  void fallar(String tabla, ErrorGim error, {int veces = 1}) =>
      (_errores[tabla] ??= []).addAll([for (var i = 0; i < veces; i++) error]);

  /// Filas de [tabla] de [persona].
  List<Map<String, Object?>> de(String tabla, String persona) => [
    for (final e in (filas[tabla] ?? {}).entries)
      if (e.key.startsWith('$persona|')) e.value,
  ];

  /// Tablas de los POST que llegaron, en orden, sin repetir seguidas.
  List<String> get ordenDeTablas {
    final orden = <String>[];
    for (final p in peticiones) {
      final etiqueta = p.metodo == 'POST' ? p.tabla : '${p.tabla}#${p.metodo}';
      if (orden.isEmpty || orden.last != etiqueta) orden.add(etiqueta);
    }
    return orden;
  }

  Future<void> _atender(HttpRequest peticion) async {
    final texto = await utf8.decodeStream(peticion);
    final encabezados = <String, String>{};
    peticion.headers.forEach((n, v) => encabezados[n] = v.join(','));
    final recibida = PeticionGim(
      peticion.method,
      peticion.uri,
      encabezados,
      texto.isEmpty ? null : jsonDecode(texto),
    );
    peticiones.add(recibida);

    Future<void> responder(int estado, [Object? json]) async {
      peticion.response.statusCode = estado;
      if (json != null) {
        peticion.response.headers.contentType = ContentType.json;
        peticion.response.write(jsonEncode(json));
      }
      await peticion.response.close();
    }

    if (caido) {
      peticion.response.statusCode = HttpStatus.serviceUnavailable;
      peticion.response.write('Service Unavailable');
      await peticion.response.close();
      return;
    }
    final forzados = _errores[recibida.tabla];
    if (forzados != null && forzados.isNotEmpty) {
      final e = forzados.removeAt(0);
      return responder(e.estado, {
        'code': e.codigo,
        'message': e.mensaje,
        'details': null,
        'hint': null,
      });
    }
    try {
      final resultado = switch (recibida.metodo) {
        'POST' => _upsert(recibida),
        'DELETE' => _borrar(recibida),
        _ => (HttpStatus.methodNotAllowed, null),
      };
      if (perderRespuestas > 0) {
        perderRespuestas--;
        final socket = await peticion.response.detachSocket(
          writeHeaders: false,
        );
        socket.destroy();
        return;
      }
      await responder(resultado.$1, resultado.$2);
    } on _ErrorServidor catch (e) {
      await responder(e.estado, {
        'code': e.codigo,
        'message': e.mensaje,
        'details': null,
        'hint': null,
      });
    }
  }

  static const _llaves = {
    'hab_ent_perfil': ['persona_id'],
    'hab_ent_plan_dias': ['persona_id', 'dia_semana'],
    'hab_ent_inventario': ['persona_id', 'item_id'],
    'hab_ent_bandas': ['id'],
    'hab_ent_sesiones': ['id'],
    'hab_ent_series': ['id'],
  };

  (int, Object?) _upsert(PeticionGim p) {
    final tabla = p.tabla;
    final permitidas = columnasQueSeMandanGimnasio[tabla];
    if (permitidas == null) throw _ErrorServidor('42P01', 'No existe $tabla.');
    if (!p.prefer.contains('resolution=merge-duplicates')) {
      throw _ErrorServidor(
        '23505',
        'Se esperaba un upsert con merge-duplicates (último gana).',
        estado: 409,
      );
    }
    final esperadas = _llaves[tabla]!.join(',');
    if (p.onConflict != esperadas) {
      throw _ErrorServidor(
        '42P10',
        'ON CONFLICT (${p.onConflict}) no es una llave única de $tabla.',
      );
    }
    final fila = p.fila;
    final prohibidas = fila.keys.where((k) => !permitidas.contains(k)).toList();
    if (prohibidas.isNotEmpty) {
      throw _ErrorServidor(
        '42501',
        'permission denied for table $tabla (${prohibidas.join(', ')})',
        estado: 403,
      );
    }
    if (fila['motivo_cambio'] == 'molestia') {
      throw _ErrorServidor('23514', 'motivo_cambio no admite molestia.');
    }
    final persona = p.sujeto;
    final llave = _llaves[tabla]!
        .map((c) => c == 'persona_id' ? persona : '${fila[c]}')
        .join('|');
    final clave = '$persona|$llave';
    final propias = filas[tabla] ??= {};
    final existente = propias[clave];

    // Únicos naturales con otro id: duplicado real.
    if (tabla == 'hab_ent_sesiones') {
      for (final e in propias.entries) {
        if (e.key.startsWith('$persona|') &&
            e.value['id'] != fila['id'] &&
            e.value['fecha'] == fila['fecha'] &&
            e.value['plantilla'] == fila['plantilla']) {
          throw _ErrorServidor(
            '23505',
            'duplicate key value violates unique constraint '
                '"hab_ent_sesiones_dia_plantilla"',
            estado: 409,
          );
        }
      }
    }
    if (tabla == 'hab_ent_series') {
      for (final e in propias.entries) {
        if (e.key.startsWith('$persona|') &&
            e.value['id'] != fila['id'] &&
            e.value['sesion_id'] == fila['sesion_id'] &&
            e.value['ejercicio_id'] == fila['ejercicio_id'] &&
            e.value['n'] == fila['n'] &&
            (e.value['lado'] ?? '') == (fila['lado'] ?? '')) {
          throw _ErrorServidor(
            '23505',
            'duplicate key value violates unique constraint '
                '"hab_ent_series_natural"',
            estado: 409,
          );
        }
      }
    }
    // Llaves foráneas.
    if (tabla == 'hab_ent_series') {
      if (de(
        'hab_ent_sesiones',
        persona,
      ).every((s) => s['id'] != fila['sesion_id'])) {
        throw _ErrorServidor(
          '23503',
          'Falta la sesión de la serie.',
          estado: 409,
        );
      }
      final banda = fila['banda_id'];
      if (banda != null &&
          de('hab_ent_bandas', persona).every((b) => b['id'] != banda)) {
        throw _ErrorServidor(
          '23503',
          'Falta la banda de la serie.',
          estado: 409,
        );
      }
    }
    if (tabla == 'hab_ent_sesiones') {
      final bloque = fila['bloque_id'];
      if (bloque != null && !bloques.contains(bloque)) {
        throw _ErrorServidor(
          '23503',
          'Falta el bloque de la sesión.',
          estado: 409,
        );
      }
    }
    // Último gana.
    if (existente != null) {
      final nuevo = DateTime.parse(fila['modificado_en']! as String);
      final viejo = DateTime.parse(existente['modificado_en']! as String);
      if (nuevo.isBefore(viejo)) return (HttpStatus.created, null);
      propias[clave] = {...existente, ...fila};
      return (HttpStatus.created, null);
    }
    final tope = topes[tabla];
    if (tope != null && de(tabla, persona).length >= tope) {
      throw _ErrorServidor(
        '54000',
        'Se llegó al tope de $tope filas en $tabla.',
      );
    }
    propias[clave] = {...fila};
    return (HttpStatus.created, null);
  }

  (int, Object?) _borrar(PeticionGim p) {
    final filtro = p.uri.queryParameters['id'];
    if (filtro == null || !filtro.startsWith('eq.')) {
      throw _ErrorServidor('22023', 'Falta el filtro id.');
    }
    final id = filtro.substring(3);
    final persona = p.sujeto;
    filas[p.tabla]?.removeWhere(
      (k, v) => k.startsWith('$persona|') && v['id'] == id,
    );
    if (p.tabla == 'hab_ent_sesiones') {
      filas['hab_ent_series']?.removeWhere(
        (k, v) => k.startsWith('$persona|') && v['sesion_id'] == id,
      );
    }
    return (HttpStatus.noContent, null);
  }
}

class _ErrorServidor implements Exception {
  _ErrorServidor(this.codigo, this.mensaje, {this.estado = 400});
  final String codigo;
  final String mensaje;
  final int estado;
}
