/// Servidor simulado para las pruebas de descarga (spec 11.1,
/// `DescargadorFalso`): habla `Range`, `If-Range` y `ETag`, puede cortarse a la
/// mitad, entregar bytes alterados, ignorar `Range` y contestar un código fijo
/// (404). Guarda las cabeceras de cada petición. No abre ningún `Socket`.
library;

import 'dart:async';
import 'dart:io';

import 'puerta_de_descarga.dart';

/// Lo que recibió el servidor simulado.
final class PeticionDeDescarga {
  const PeticionDeDescarga(this.direccion, this.cabeceras);
  final Uri direccion;

  /// Con las claves en minúscula.
  final Map<String, String> cabeceras;
}

class PuertaDeDescargaFalsa implements PuertaDeDescarga {
  PuertaDeDescargaFalsa(this.contenido);

  /// Dirección completa -> bytes del archivo.
  final Map<String, List<int>> contenido;

  final peticiones = <PeticionDeDescarga>[];

  /// Dirección -> código que se contesta siempre (404, 500…).
  final codigoFijo = <String, int>{};

  /// Dirección -> bytes que se entregan en la próxima respuesta antes de
  /// cortar la conexión (una sola vez por dirección y por vez que se asigna).
  final cortarDespuesDe = <String, int>{};

  /// Direcciones cuyos bytes se entregan alterados (mismo tamaño, otra huella).
  final alterar = <String>{};

  /// Si es `true`, el servidor ignora `Range` y contesta 200 completo.
  bool ignorarRange = false;

  /// Si es `true`, el servidor no manda `ETag`.
  bool sinEtag = false;

  /// Si no es `null`, toda petición falla como si no hubiera red.
  Object? falloAlPedir;

  /// Cuántas veces se pidió cada dirección.
  int pedidasDe(String direccion) =>
      peticiones.where((p) => p.direccion.toString() == direccion).length;

  /// Detiene el cuerpo de la respuesta hasta que la prueba lo suelte.
  Completer<void>? pausaDelCuerpo;

  String _etagDe(String direccion) {
    final datos = contenido[direccion]!;
    return '"${datos.length}-${direccion.hashCode.toUnsigned(32).toRadixString(16)}"';
  }

  @override
  Future<RespuestaDeDescarga> pedir(
    Uri direccion, {
    required Map<String, String> cabeceras,
  }) async {
    final minuscula = {
      for (final e in cabeceras.entries) e.key.toLowerCase(): e.value,
    };
    peticiones.add(PeticionDeDescarga(direccion, minuscula));
    final fallo = falloAlPedir;
    if (fallo != null) throw fallo;
    final clave = direccion.toString();
    final fijo = codigoFijo[clave];
    if (fijo != null) return _RespuestaFalsa(fijo, const [], null, null);
    final datos = contenido[clave];
    if (datos == null) return _RespuestaFalsa(404, const [], null, null);
    var cuerpo = datos;
    if (alterar.contains(clave)) {
      cuerpo = [for (final b in datos) b ^ 0xFF];
    }
    final etag = sinEtag ? null : _etagDe(clave);
    var inicio = 0;
    var codigo = 200;
    String? rango;
    final pedido = minuscula['range'];
    if (!ignorarRange && pedido != null) {
      final m = RegExp(r'^bytes=(\d+)-$').firstMatch(pedido);
      final ifRange = minuscula['if-range'];
      final vale = ifRange == null || ifRange == etag;
      if (m != null && vale) {
        inicio = int.parse(m.group(1)!);
        if (inicio >= datos.length) {
          return _RespuestaFalsa(416, const [], etag, null);
        }
        codigo = 206;
        rango = 'bytes $inicio-${datos.length - 1}/${datos.length}';
      }
    }
    final resto = cuerpo.sublist(inicio);
    final corte = cortarDespuesDe.remove(clave);
    return _RespuestaFalsa(
      codigo,
      resto,
      etag,
      rango,
      cortarEn: corte,
      pausa: pausaDelCuerpo,
    );
  }
}

class _RespuestaFalsa implements RespuestaDeDescarga {
  _RespuestaFalsa(
    this.codigo,
    this._bytes,
    this.etag,
    this.contentRange, {
    this.cortarEn,
    this.pausa,
  });

  @override
  final int codigo;
  final List<int> _bytes;
  @override
  final String? etag;
  @override
  final String? contentRange;
  final int? cortarEn;
  final Completer<void>? pausa;
  final _cierre = Completer<void>();
  bool _cerrada = false;

  @override
  int? get largoDelCuerpo => _bytes.length;

  @override
  Stream<List<int>> get cuerpo async* {
    const trozo = 4096;
    var enviados = 0;
    while (enviados < _bytes.length && !_cerrada) {
      final p = pausa;
      // Si cierran la respuesta mientras espera, se suelta.
      if (p != null && !p.isCompleted) {
        await Future.any([p.future, _cierre.future]);
      }
      if (_cerrada) return;
      final limite = cortarEn;
      var hasta = enviados + trozo;
      if (hasta > _bytes.length) hasta = _bytes.length;
      if (limite != null && hasta > limite) hasta = limite;
      if (hasta > enviados) {
        yield _bytes.sublist(enviados, hasta);
        enviados = hasta;
      }
      if (limite != null && enviados >= limite && enviados < _bytes.length) {
        throw const SocketException('Conexión cortada (simulada)');
      }
      // Cede el turno para que la prueba pueda cancelar a media descarga.
      await Future<void>.delayed(Duration.zero);
    }
  }

  @override
  Future<void> cerrar() async {
    _cerrada = true;
    if (!_cierre.isCompleted) _cierre.complete();
  }
}
