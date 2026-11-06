/// PostgREST simulado para probar la cola sin conexión contra el contrato del
/// servidor (`supabase/README.md`, «Contrato para la app»).
///
/// Es un servidor HTTP real (`dart:io`) que habla lo mínimo de PostgREST y
/// aplica las reglas del servidor que importan a la cola:
///
/// - `POST … ?on_conflict=id` con `Prefer: resolution=ignore-duplicates`:
///   mismo id y mismo contenido → 201 sin cuerpo y sin tocar nada; mismo id con
///   otro contenido en un libro solo agregar → 409 `23505`; llaves foráneas
///   que faltan → 409 `23503`.
/// - Columnas que pone el servidor (sin permiso de INSERT) → 403 `42501`.
/// - `PATCH … ?id=eq.X&or=(col.neq.valor)` con `select=id`: una semana solo se
///   cierra si ya tiene su cierre (`55000`), y cerrar una semana cerrada es
///   `55000`.
/// - `GET … ?select=id&id=eq.X`.
/// - Errores forzados por tabla, respuestas perdidas y servidor caído.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:gravity/nucleo/cola/contrato_servidor.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String _b64(Object json) =>
    base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');

/// Sesión de Supabase de [uid] con un JWT sin firma válida (el cliente no la
/// comprueba), vigente una hora.
String sesionJson(String uid) {
  final vence = DateTime.now().add(const Duration(hours: 1));
  final token = [
    _b64({'alg': 'HS256', 'typ': 'JWT'}),
    _b64({
      'sub': uid,
      'aud': 'authenticated',
      'role': 'authenticated',
      'exp': vence.millisecondsSinceEpoch ~/ 1000,
    }),
    'firma',
  ].join('.');
  return jsonEncode({
    'access_token': token,
    'token_type': 'bearer',
    'expires_in': 3600,
    'expires_at': vence.millisecondsSinceEpoch ~/ 1000,
    'refresh_token': 'renovar-$uid',
    'user': {
      'id': uid,
      'aud': 'authenticated',
      'role': 'authenticated',
      'email': '$uid@ejemplo.test',
      'created_at': '2026-10-20T00:00:00Z',
      'app_metadata': <String, Object?>{},
      'user_metadata': <String, Object?>{},
    },
  });
}

/// Una petición que recibió el PostgREST simulado.
class PeticionRecibida {
  PeticionRecibida(this.metodo, this.uri, this.encabezados, this.cuerpo);

  final String metodo;
  final Uri uri;
  final Map<String, String> encabezados;
  final Object? cuerpo;

  /// Tabla a la que va (`/rest/v1/<tabla>`).
  String get tabla => uri.pathSegments.last;

  /// `id` de la fila: el del cuerpo (POST) o el del filtro `id=eq.…`.
  String? get id {
    final cuerpo = this.cuerpo;
    if (cuerpo is Map && cuerpo['id'] != null) return '${cuerpo['id']}';
    final filtro = uri.queryParameters['id'];
    return filtro != null && filtro.startsWith('eq.')
        ? filtro.substring(3)
        : null;
  }

  String get bearer =>
      (encabezados['authorization'] ?? '').replaceFirst('Bearer ', '');

  /// `sub` del JWT con el que salió la petición.
  String get sujeto {
    final partes = bearer.split('.');
    if (partes.length != 3) return '';
    final carga = utf8.decode(base64Url.decode(base64Url.normalize(partes[1])));
    return (jsonDecode(carga) as Map)['sub'] as String;
  }

  /// Columnas que trae el cuerpo (vacío si no hay cuerpo de objeto).
  Set<String> get columnas =>
      cuerpo is Map ? {...(cuerpo as Map).keys.cast<String>()} : const {};
}

/// Error que el servidor simulado devuelve en lugar de atender.
class ErrorForzado {
  const ErrorForzado(this.codigo, this.mensaje, {this.estado = 400});

  final String codigo;
  final String mensaje;
  final int estado;
}

class PostgrestSimulado {
  PostgrestSimulado._(this._servidor) {
    _servidor.listen(_atender);
  }

  static Future<PostgrestSimulado> iniciar() async => PostgrestSimulado._(
    await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
  );

  final HttpServer _servidor;

  String get url => 'http://127.0.0.1:${_servidor.port}';

  /// Lo que hay guardado: tabla → id → fila.
  final Map<String, Map<String, Map<String, Object?>>> filas = {};

  /// Todas las peticiones que llegaron, en orden.
  final List<PeticionRecibida> peticiones = [];

  /// Errores que se devuelven (uno por petición) a la siguiente petición a la
  /// tabla, antes de atenderla.
  final Map<String, List<ErrorForzado>> _errores = {};

  /// Cuántas de las siguientes peticiones se atienden pero la respuesta se
  /// pierde (el servidor guardó, el cliente no lo supo).
  int perderRespuestas = 0;

  /// `true`: responde 503 sin cuerpo de PostgREST (servidor caído).
  bool caido = false;

  /// Tablas de solo agregar: mismo id con otro contenido es 23505.
  static const soloAgregar = {
    'fin_movimientos',
    'fin_conciliaciones',
    'fin_cierres',
    'fin_cierre_partidas',
    'fin_cierre_abonos',
    'fin_importaciones',
  };

  /// Llaves foráneas: tabla → columna → tabla a la que apunta.
  static const referencias = {
    'fin_movimientos': {
      'cuenta_origen_id': 'fin_cuentas',
      'cuenta_destino_id': 'fin_cuentas',
      'anula_a': 'fin_movimientos',
    },
    'fin_conciliaciones': {
      'cuenta_id': 'fin_cuentas',
      'ajuste_movimiento_id': 'fin_movimientos',
    },
    'fin_cierres': {'semana_id': 'fin_semanas'},
    'fin_cierre_partidas': {'cierre_id': 'fin_cierres'},
    'fin_cierre_abonos': {'cierre_id': 'fin_cierres'},
  };

  /// No se comparan al decidir si un reenvío es el mismo contenido (el
  /// servidor las pone o las acepta distintas).
  static const _noSeComparan = {'creado_en', 'cerrado_en', 'libro_id'};

  Future<void> cerrar() => _servidor.close(force: true);

  /// Cliente de Supabase de [uid] que habla con este servidor.
  Future<SupabaseClient> cliente(String uid) async {
    final cliente = SupabaseClient(
      url,
      'llave-publica-de-prueba',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    await cliente.auth.recoverSession(sesionJson(uid));
    return cliente;
  }

  /// Deja [fila] ya guardada (como si la hubiera subido otro dispositivo).
  void sembrar(String tabla, Map<String, Object?> fila) {
    (filas[tabla] ??= {})['${fila['id']}'] = {...fila};
  }

  /// La siguiente petición a [tabla] recibe [error] (una vez por cada uno).
  void fallar(String tabla, ErrorForzado error, {int veces = 1}) {
    (_errores[tabla] ??= []).addAll([for (var i = 0; i < veces; i++) error]);
  }

  /// Ids guardados de [tabla].
  List<String> idsDe(String tabla) => [...?filas[tabla]?.keys];

  /// Tablas de las peticiones que llegaron, en orden (sin repetir seguidas).
  List<String> get ordenDeTablas {
    final orden = <String>[];
    for (final p in peticiones) {
      final etiqueta = p.metodo == 'POST' ? p.tabla : '${p.tabla}#${p.metodo}';
      if (orden.isEmpty || orden.last != etiqueta) orden.add(etiqueta);
    }
    return orden;
  }

  // ------------------------------------------------------------- servidor

  Future<void> _atender(HttpRequest peticion) async {
    final texto = await utf8.decodeStream(peticion);
    final encabezados = <String, String>{};
    peticion.headers.forEach(
      (nombre, valores) => encabezados[nombre] = valores.join(','),
    );
    final cuerpo = texto.isEmpty ? null : jsonDecode(texto);
    final recibida = PeticionRecibida(
      peticion.method,
      peticion.uri,
      encabezados,
      cuerpo,
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
    final tabla = recibida.tabla;
    final forzados = _errores[tabla];
    if (forzados != null && forzados.isNotEmpty) {
      final error = forzados.removeAt(0);
      return responder(error.estado, {
        'code': error.codigo,
        'message': error.mensaje,
        'details': null,
        'hint': null,
      });
    }

    try {
      final resultado = switch (peticion.method) {
        'POST' when peticion.uri.path.contains('/rpc/') => _funcion(recibida),
        'POST' => _insertar(recibida, encabezados),
        'PATCH' => _actualizar(recibida),
        'GET' => _leer(recibida),
        _ => (HttpStatus.methodNotAllowed, null),
      };
      if (perderRespuestas > 0) {
        perderRespuestas--;
        // Ya se guardó; el cliente nunca recibe la respuesta.
        final socket = await peticion.response.detachSocket(
          writeHeaders: false,
        );
        socket.destroy();
        return;
      }
      await responder(resultado.$1, resultado.$2);
    } on _ErrorDelServidor catch (error) {
      await responder(error.estado, {
        'code': error.codigo,
        'message': error.mensaje,
        'details': null,
        'hint': null,
      });
    }
  }

  /// Funciones (`/rest/v1/rpc/<nombre>`): responden con [respuestasDeFunciones]
  /// y guardan lo que recibieron en [llamadas].
  final Map<String, Object?> respuestasDeFunciones = {};

  (int, Object?) _funcion(PeticionRecibida p) =>
      (HttpStatus.ok, respuestasDeFunciones[p.tabla] ?? <String, Object?>{});

  (int, Object?) _insertar(PeticionRecibida p, Map<String, String> cabeceras) {
    final fila = p.cuerpo;
    if (fila is! Map) {
      throw _ErrorDelServidor('22P02', 'Se esperaba un objeto');
    }
    final nueva = fila.cast<String, Object?>();
    final prohibidas = columnasQuePoneElServidor[p.tabla];
    if (prohibidas != null) {
      final enviadas = nueva.keys.where(prohibidas.contains).toList();
      if (enviadas.isNotEmpty) {
        throw _ErrorDelServidor(
          '42501',
          'permission denied for table ${p.tabla} '
              '(columnas del servidor: ${enviadas.join(', ')})',
          estado: 403,
        );
      }
    }
    final id = '${nueva['id']}';
    final existente = filas[p.tabla]?[id];
    if (existente != null) {
      if (_mismoContenido(p.tabla, existente, nueva)) return (201, null);
      if (soloAgregar.contains(p.tabla)) {
        throw _ErrorDelServidor(
          '23505',
          'Ya existe un registro $id en ${p.tabla} con otro contenido.',
          estado: 409,
        );
      }
      // Configuración y plan: ON CONFLICT DO NOTHING lo ignora.
      return (201, null);
    }
    for (final MapEntry(key: columna, value: destino)
        in (referencias[p.tabla] ?? const <String, String>{}).entries) {
      final valor = nueva[columna];
      if (valor != null && filas[destino]?['$valor'] == null) {
        throw _ErrorDelServidor(
          '23503',
          'Falta ${destino.replaceFirst('fin_', '')} $valor '
              '(${p.tabla}.$columna; ¿aún no se sube?).',
          estado: 409,
        );
      }
    }
    if (p.tabla == 'fin_cierres') {
      final semana = filas['fin_semanas']?['${nueva['semana_id']}'];
      if (semana != null && semana['estado'] == 'cerrada') {
        throw _ErrorDelServidor(
          '55000',
          'La semana ya está cerrada: reábrela para cerrarla otra vez.',
        );
      }
    }
    final guardada = {...nueva};
    if (p.tabla == 'fin_movimientos') {
      // Lo que pone el servidor.
      guardada['recibido_en'] = '2026-10-22T00:00:00Z';
      guardada['libro_origen_id'] = 'libro-del-servidor';
    }
    (filas[p.tabla] ??= {})[id] = guardada;
    return (201, null);
  }

  bool _mismoContenido(
    String tabla,
    Map<String, Object?> guardada,
    Map<String, Object?> nueva,
  ) {
    final ignoradas = {..._noSeComparan, ...?columnasQuePoneElServidor[tabla]};
    Map<String, Object?> comparable(Map<String, Object?> m) => _ordenado({
      for (final e in m.entries)
        if (!ignoradas.contains(e.key)) e.key: e.value,
    });
    return jsonEncode(comparable(guardada)) == jsonEncode(comparable(nueva));
  }

  Map<String, Object?> _ordenado(Map<String, Object?> m) => {
    for (final k in m.keys.toList()..sort()) k: m[k],
  };

  (int, Object?) _actualizar(PeticionRecibida p) {
    final cambios = (p.cuerpo as Map).cast<String, Object?>();
    final fila = filas[p.tabla]?[p.id];
    final distintos = _condicionesOr(p.uri.queryParameters['or']);
    final cumple =
        fila != null &&
        (distintos.isEmpty || distintos.any((cumple) => cumple(fila)));
    if (!cumple) return (200, <Object>[]);
    if (p.tabla == 'fin_semanas' && cambios['estado'] == 'cerrada') {
      if (fila['estado'] == 'cerrada') {
        throw _ErrorDelServidor(
          '55000',
          'La semana está cerrada: se corrige con anulación y contraasiento, '
              'o se reabre.',
        );
      }
      final conCierre = (filas['fin_cierres'] ?? {}).values.any(
        (c) => c['semana_id'] == p.id,
      );
      if (!conCierre) {
        throw _ErrorDelServidor(
          '55000',
          'Antes de cerrar la semana guarda su cierre (versión 1).',
        );
      }
    }
    fila.addAll(cambios);
    return (
      200,
      [
        {'id': p.id},
      ],
    );
  }

  /// `(col.neq.valor,otra.not.is.null)` → una condición por parte; la fila
  /// entra si cumple alguna.
  List<bool Function(Map<String, Object?>)> _condicionesOr(String? or) {
    if (or == null) return const [];
    final dentro = or.substring(1, or.length - 1);
    return [
      for (final parte in dentro.split(','))
        if (parte.endsWith('.not.is.null'))
          (fila) => fila[parte.split('.').first] != null
        else
          (fila) =>
              '${fila[parte.split('.').first]}' != parte.split('.neq.').last,
    ];
  }

  (int, Object?) _leer(PeticionRecibida p) {
    final filtros = {
      for (final e in p.uri.queryParameters.entries)
        if (e.value.startsWith('eq.')) e.key: e.value.substring(3),
    };
    final coinciden = [
      for (final fila in (filas[p.tabla] ?? {}).values)
        if (filtros.entries.every((f) => '${fila[f.key]}' == f.value))
          {'id': fila['id']},
    ];
    return (200, coinciden);
  }
}

class _ErrorDelServidor implements Exception {
  _ErrorDelServidor(this.codigo, this.mensaje, {this.estado = 400});

  final String codigo;
  final String mensaje;
  final int estado;
}
