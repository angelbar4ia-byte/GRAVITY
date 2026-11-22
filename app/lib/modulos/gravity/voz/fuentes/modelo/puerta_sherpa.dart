/// La puerta real a la síntesis: `sherpa_onnx` 2.0.1 en un `Isolate` de larga
/// vida. **Es, junto con la fuente B, lo único que importa el paquete.**
///
/// - `generate` es síncrona y bloquea al hilo que la llama (`tts.dart:376`):
///   por eso todo corre en otro `Isolate` y la pantalla no se congela.
/// - **Cada isolate llama `initBindings()`**: sin eso `OfflineTts` lanza
///   "Please initialize sherpa-onnx first" (spec 4.2.3).
/// - Voces VITS (Piper) con lexicón: `OfflineTtsVitsModelConfig(model, lexicon,
///   tokens)`; `dataDir` se ignora desde 2.0.0 (spec 4.2.5).
/// - Se mantienen cargados a lo sumo [maximoCargados] modelos a la vez (un
///   diálogo de dos voces de dos modelos distintos no recarga en cada turno;
///   si se piden más, se libera el más viejo).
/// - **Ningún error lleva el texto, las rutas ni el mensaje de la biblioteca**
///   (R6): el `Isolate` solo contesta códigos cortos.
///
/// Sin verificar en un aparato (spec 14, "Para probar en dispositivo"): que la
/// biblioteca nativa cargue en Android (`libsherpa-onnx-c-api.so`) y en
/// Windows (`sherpa-onnx-c-api.dll`), la latencia y la memoria.
library;

import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../../tipos.dart';
import 'puerta_sintesis.dart';

class PuertaSintesisSherpa implements PuertaSintesis {
  PuertaSintesisSherpa({
    this.tiempoMaximoPorPeticion = const Duration(minutes: 2),
  });

  /// Si el `Isolate` no contesta en este tiempo, se considera perdido.
  final Duration tiempoMaximoPorPeticion;

  Isolate? _isolate;
  SendPort? _envio;
  ReceivePort? _recibo;
  ReceivePort? _salida;
  Future<void>? _arrancando;
  int _siguiente = 0;
  final _pendientes = <int, Completer<List<Object?>>>{};

  Future<void> _asegurar() => _arrancando ??= _arrancar();

  Future<void> _arrancar() async {
    final recibo = ReceivePort();
    final salida = ReceivePort();
    _recibo = recibo;
    _salida = salida;
    final listo = Completer<SendPort>();
    recibo.listen((m) {
      if (m is SendPort) {
        if (!listo.isCompleted) listo.complete(m);
      } else if (m is List) {
        final id = m.first as int;
        _pendientes.remove(id)?.complete(m);
      }
    });
    salida.listen((_) => _perderIsolate());
    try {
      _isolate = await Isolate.spawn<SendPort>(
        _trabajador,
        recibo.sendPort,
        onExit: salida.sendPort,
        debugName: 'gravity-voz-sherpa',
      );
      _envio = await listo.future.timeout(const Duration(seconds: 20));
    } on Object {
      _perderIsolate();
      throw const FalloDeSintesis(Fuente.modelo, 'isolate_no_arranco');
    }
  }

  /// El `Isolate` murió o no arrancó: lo pendiente falla y la próxima petición
  /// vuelve a arrancarlo.
  void _perderIsolate() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _envio = null;
    _arrancando = null;
    _recibo?.close();
    _salida?.close();
    _recibo = null;
    _salida = null;
    final pendientes = List.of(_pendientes.values);
    _pendientes.clear();
    for (final p in pendientes) {
      if (!p.isCompleted) p.complete([-1, false, 'isolate_perdido']);
    }
  }

  Future<List<Object?>> _pedir(List<Object?> Function(int id) armar) async {
    await _asegurar();
    final id = _siguiente++;
    final c = Completer<List<Object?>>();
    _pendientes[id] = c;
    _envio!.send(armar(id));
    return c.future.timeout(
      tiempoMaximoPorPeticion,
      onTimeout: () {
        _pendientes.remove(id);
        return [id, false, 'tiempo_agotado'];
      },
    );
  }

  Never _fallar(List<Object?> r) =>
      throw FalloDeSintesis(Fuente.modelo, '${r.length > 2 ? r[2] : 'error'}');

  @override
  Future<void> cargar(CargaDeModelo carga) async {
    final r = await _pedir(
      (id) => [
        id,
        'cargar',
        carga.idModelo,
        carga.rutaModelo,
        carga.rutaTokens,
        carga.rutaLexicon,
        carga.hilos,
      ],
    );
    if (r[1] != true) _fallar(r);
  }

  @override
  Future<MuestrasDeAudio> sintetizar({
    required String idModelo,
    required int sid,
    required String texto,
    required double velocidad,
  }) async {
    final r = await _pedir(
      (id) => [id, 'sintetizar', idModelo, sid, texto, velocidad],
    );
    if (r[1] != true) _fallar(r);
    return MuestrasDeAudio(r[2]! as Float32List, r[3]! as int);
  }

  @override
  Future<void> descargar(String idModelo) async {
    if (_envio == null) return;
    await _pedir((id) => [id, 'liberar', idModelo]);
  }

  @override
  Future<void> cerrar() async {
    if (_envio != null) {
      try {
        await _pedir((id) => [id, 'cerrar']);
      } on Object {
        // Se cierra igual.
      }
    }
    _perderIsolate();
  }
}

/// Punto de entrada del `Isolate`. Todo lo que contesta son listas de datos
/// simples: `[id, true, ...]` o `[id, false, código]`.
void _trabajador(SendPort principal) {
  final entrada = ReceivePort();
  principal.send(entrada.sendPort);

  String? errorDeBiblioteca;
  try {
    sherpa.initBindings();
  } on Object {
    errorDeBiblioteca = 'biblioteca_no_disponible';
  }

  final motores = <String, sherpa.OfflineTts>{};
  final orden = <String>[]; // del más viejo al más nuevo

  void liberar(String id) {
    motores.remove(id)?.free();
    orden.remove(id);
  }

  entrada.listen((mensaje) {
    final m = mensaje as List;
    final id = m[0] as int;
    final accion = m[1] as String;
    switch (accion) {
      case 'cargar':
        if (errorDeBiblioteca != null) {
          principal.send([id, false, errorDeBiblioteca]);
          return;
        }
        final idModelo = m[2] as String;
        if (motores.containsKey(idModelo)) {
          orden
            ..remove(idModelo)
            ..add(idModelo);
          principal.send([id, true]);
          return;
        }
        try {
          while (motores.length >= maximoCargados && orden.isNotEmpty) {
            liberar(orden.first);
          }
          final config = sherpa.OfflineTtsConfig(
            model: sherpa.OfflineTtsModelConfig(
              vits: sherpa.OfflineTtsVitsModelConfig(
                model: m[3] as String,
                tokens: m[4] as String,
                lexicon: m[5] as String,
              ),
              numThreads: m[6] as int,
              debug: false,
            ),
          );
          motores[idModelo] = sherpa.OfflineTts(config);
          orden.add(idModelo);
          principal.send([id, true]);
        } on Object {
          principal.send([id, false, 'carga_fallida']);
        }
      case 'sintetizar':
        final tts = motores[m[2] as String];
        if (tts == null) {
          principal.send([id, false, 'modelo_no_cargado']);
          return;
        }
        try {
          final audio = tts.generate(
            text: m[4] as String,
            sid: m[3] as int,
            speed: m[5] as double,
          );
          principal.send([id, true, audio.samples, audio.sampleRate]);
        } on Object {
          principal.send([id, false, 'sintesis_fallida']);
        }
      case 'liberar':
        liberar(m[2] as String);
        principal.send([id, true]);
      case 'cerrar':
        for (final k in motores.keys.toList()) {
          liberar(k);
        }
        principal.send([id, true]);
        entrada.close();
      default:
        principal.send([id, false, 'orden_desconocida']);
    }
  });
}
