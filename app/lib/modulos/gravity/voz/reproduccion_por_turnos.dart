/// Reproducción de un guion turno por turno, común a las fuentes que dicen
/// un turno a la vez (la voz del dispositivo y la fuente simulada).
///
/// Se ocupa de lo que no depende de cómo suena cada turno: el orden, la pausa
/// entre turnos, pausar, reanudar y parar (criterios 5, 7 y 8). Quien la usa
/// solo dice cómo se dice UN turno ([decirTurno]) y cómo se corta
/// ([detenerTurno]).
///
/// Decisiones:
/// - **Pausar** corta el turno que suena y, al reanudar, lo repite desde el
///   principio. Es lo que se puede garantizar igual en todas las plataformas:
///   el truco de Android que retoma "desde la última palabra" no se pudo
///   verificar en un aparato (spec 4.1, límites conocidos).
/// - Ningún evento ni error lleva el texto de los turnos (R6).
library;

import 'dart:async';

import 'tipos.dart';

/// Cómo terminó de decirse un turno.
enum ResultadoTurno {
  /// Se dijo completo.
  completo,

  /// Lo cortaron ([ReproduccionPorTurnos.pausar] o `parar`).
  interrumpido,
}

typedef DecirTurno = Future<ResultadoTurno> Function(int indice, Turno turno);

final class ReproduccionPorTurnos implements Reproduccion {
  ReproduccionPorTurnos({
    required this.fuente,
    required this.guion,
    required this._decirTurno,
    required this._detenerTurno,
  }) {
    _terminada.future.ignore();
    unawaited(_correr());
  }

  @override
  final Fuente fuente;
  final Guion guion;
  final DecirTurno _decirTurno;
  final Future<void> Function() _detenerTurno;

  final _avance = StreamController<Avance>();
  final _terminada = Completer<Fin>();
  final _reloj = Stopwatch()..start();

  bool _pausada = false;
  bool _parada = false;
  bool _fin = false;
  int _cortesPedidos = 0;
  int _cortesAtendidos = 0;
  Completer<void>? _senal;
  Completer<void>? _reanudacion;

  @override
  Stream<Avance> get avance => _avance.stream;

  @override
  Future<Fin> get terminada => _terminada.future;

  /// `true` mientras no haya terminado ni se haya parado.
  bool get activa => !_fin;

  @override
  Future<void> pausar() async {
    if (_fin || _parada || _pausada) return;
    _pausada = true;
    _cortesPedidos++;
    _reloj.stop();
    _despertar();
    await _detenerTurno();
  }

  @override
  Future<void> reanudar() async {
    if (_fin || !_pausada) return;
    _pausada = false;
    _reloj.start();
    final r = _reanudacion;
    _reanudacion = null;
    if (r != null && !r.isCompleted) r.complete();
  }

  @override
  Future<void> parar() async {
    if (_fin || _parada) return;
    _parada = true;
    _despertar();
    final r = _reanudacion;
    _reanudacion = null;
    if (r != null && !r.isCompleted) r.complete();
    await _detenerTurno();
  }

  void _despertar() {
    final s = _senal;
    _senal = null;
    if (s != null && !s.isCompleted) s.complete();
  }

  Future<void> _esperarReanudar() {
    final r = _reanudacion ??= Completer<void>();
    return r.future;
  }

  Future<void> _correr() async {
    try {
      final total = guion.turnos.length;
      for (var i = 0; i < total && !_parada; i++) {
        final turno = guion.turnos[i];
        _avance.add(
          Avance(
            turno: i,
            totalTurnos: total,
            voz: turno.voz,
            posicion: _reloj.elapsed,
          ),
        );
        while (!_parada) {
          if (_pausada) {
            await _esperarReanudar();
            continue;
          }
          final resultado = await _decirTurno(i, turno);
          if (_parada || resultado == ResultadoTurno.completo) break;
          // Interrumpido sin parar: la cortó una pausa (se repite el turno al
          // reanudar). Si nadie la pidió, la fuente falló.
          if (_cortesAtendidos < _cortesPedidos) {
            _cortesAtendidos++;
            continue;
          }
          throw FalloDeSintesis(fuente, 'interrumpido');
        }
        if (_parada) break;
        if (i < total - 1) {
          await _pausaEntre(turno.pausaDespues ?? guion.pausaEntreTurnos);
        }
      }
      _cerrar(_parada ? Fin.parada : Fin.completa);
    } on ErrorVoz catch (e) {
      _cerrar(null, e);
    } catch (_) {
      // Nunca se copia el mensaje: podría traer el texto (R6).
      _cerrar(null, FalloDeSintesis(fuente, 'error_inesperado'));
    }
  }

  Future<void> _pausaEntre(Duration espera) async {
    if (espera <= Duration.zero) return;
    while (!_parada) {
      if (_pausada) {
        await _esperarReanudar();
        continue;
      }
      final senal = _senal = Completer<void>();
      var vencio = false;
      final reloj = Timer(espera, () {
        vencio = true;
        if (!senal.isCompleted) senal.complete();
      });
      await senal.future;
      reloj.cancel();
      if (vencio && !_pausada && !_parada) return;
    }
  }

  void _cerrar(Fin? fin, [ErrorVoz? error]) {
    if (_fin) return;
    _fin = true;
    if (!_avance.isClosed) unawaited(_avance.close());
    if (_terminada.isCompleted) return;
    if (error != null) {
      _terminada.completeError(error);
    } else {
      _terminada.complete(fin);
    }
  }
}
