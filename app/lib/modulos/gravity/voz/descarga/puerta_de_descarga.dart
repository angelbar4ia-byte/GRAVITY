/// Puerta HTTP del gestor de descargas (spec 4.2.2).
///
/// **Es lo único de todo el motor de voz que habla con la red** (R8, criterio
/// 11), y solo cuando la persona toca *Descargar*. La petición es un `GET`
/// sin credenciales, cookies ni identificadores, a la dirección exacta del
/// catálogo, con cabeceras de una lista cerrada ([cabecerasPermitidas]):
/// `Range`, `If-Range`, `Accept-Encoding` y un `User-Agent` fijo y genérico
/// (R9, criterio 15). El sitio que aloja el archivo ve la dirección de
/// internet del equipo; el aviso previo lo dice.
library;

import 'dart:async';
import 'dart:io';

/// Lo único que una petición de descarga puede llevar (en minúscula).
const cabecerasPermitidas = {
  'range',
  'if-range',
  'accept-encoding',
  'user-agent',
};

/// Genérico: no dice ni la versión de la app ni el equipo.
const userAgentDeDescarga = 'GRAVITY-voces/1';

/// La respuesta a un `GET`.
abstract interface class RespuestaDeDescarga {
  /// Código HTTP (200, 206, 404…).
  int get codigo;

  /// `Content-Length` del cuerpo (lo que falta bajar en una respuesta 206).
  int? get largoDelCuerpo;

  /// `ETag` del archivo, si el servidor lo da.
  String? get etag;

  /// `Content-Range` (`bytes 100-999/1000`), si el servidor lo da.
  String? get contentRange;

  /// El cuerpo, tal como llega (sin descomprimir).
  Stream<List<int>> get cuerpo;

  /// Aborta lo que falte (cancelar). No falla si ya terminó.
  Future<void> cerrar();
}

abstract interface class PuertaDeDescarga {
  /// Un `GET` a [direccion] con [cabeceras] (solo de [cabecerasPermitidas]).
  /// Sigue las redirecciones a direcciones `https`. Lanza una excepción de
  /// `dart:io` o [TimeoutException] si no logra una respuesta.
  Future<RespuestaDeDescarga> pedir(
    Uri direccion, {
    required Map<String, String> cabeceras,
  });
}

/// La implementación real, con `dart:io`.
///
/// - Nunca envía cookies ni `Authorization` (no hay forma de agregarlas por
///   aquí: solo se copian cabeceras permitidas).
/// - Sigue hasta [maximoRedirecciones] redirecciones y solo a `https`.
///   (La dirección firmada a la que redirige un alojamiento caduca: la
///   reanudación empieza siempre de nuevo por la dirección del catálogo.)
/// - `autoUncompress` apagado y `Accept-Encoding: identity`: los bytes que
///   llegan son los del archivo, así `Range` y las huellas cuadran.
class PuertaDeDescargaHttp implements PuertaDeDescarga {
  PuertaDeDescargaHttp({
    this.tiempoDeConexion = const Duration(seconds: 20),
    this.tiempoSinDatos = const Duration(seconds: 30),
    this.maximoRedirecciones = 5,
    this.permitirHttp = false,
  });

  final Duration tiempoDeConexion;

  /// Si el servidor no manda nada en este tiempo, se considera cortada.
  final Duration tiempoSinDatos;
  final int maximoRedirecciones;

  /// Solo para pruebas con un servidor en el propio equipo (`127.0.0.1`).
  final bool permitirHttp;

  HttpClient _cliente() {
    final c = HttpClient()
      ..autoUncompress = false
      ..connectionTimeout = tiempoDeConexion
      ..userAgent = userAgentDeDescarga;
    return c;
  }

  @override
  Future<RespuestaDeDescarga> pedir(
    Uri direccion, {
    required Map<String, String> cabeceras,
  }) async {
    for (final nombre in cabeceras.keys) {
      if (!cabecerasPermitidas.contains(nombre.toLowerCase())) {
        throw ArgumentError('Cabecera no permitida');
      }
    }
    final cliente = _cliente();
    try {
      var actual = direccion;
      for (var salto = 0; salto <= maximoRedirecciones; salto++) {
        if (actual.scheme != 'https' &&
            !(permitirHttp && actual.scheme == 'http')) {
          throw const HttpException('Solo se permite https');
        }
        final peticion = await cliente.getUrl(actual).timeout(tiempoDeConexion);
        peticion.followRedirects = false;
        peticion.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
        cabeceras.forEach((k, v) {
          if (k.toLowerCase() != 'accept-encoding') peticion.headers.set(k, v);
        });
        final respuesta = await peticion.close().timeout(tiempoDeConexion);
        final codigo = respuesta.statusCode;
        if (codigo >= 300 && codigo < 400 && codigo != 304) {
          final destino = respuesta.headers.value(HttpHeaders.locationHeader);
          await respuesta.drain<void>();
          if (destino == null) {
            throw const HttpException('Redirección sin destino');
          }
          actual = actual.resolve(destino);
          continue;
        }
        return _RespuestaHttp(respuesta, cliente, tiempoSinDatos);
      }
      throw const HttpException('Demasiadas redirecciones');
    } catch (_) {
      cliente.close(force: true);
      rethrow;
    }
  }
}

class _RespuestaHttp implements RespuestaDeDescarga {
  _RespuestaHttp(this._respuesta, this._cliente, this._sinDatos);

  final HttpClientResponse _respuesta;
  final HttpClient _cliente;
  final Duration _sinDatos;

  @override
  int get codigo => _respuesta.statusCode;

  @override
  int? get largoDelCuerpo {
    final n = _respuesta.contentLength;
    return n < 0 ? null : n;
  }

  @override
  String? get etag => _respuesta.headers.value(HttpHeaders.etagHeader);

  @override
  String? get contentRange =>
      _respuesta.headers.value(HttpHeaders.contentRangeHeader);

  @override
  Stream<List<int>> get cuerpo => _respuesta.timeout(
    _sinDatos,
    onTimeout: (sink) {
      sink.addError(TimeoutException('Sin datos'));
      sink.close();
    },
  );

  @override
  Future<void> cerrar() async {
    _cliente.close(force: true);
  }
}
