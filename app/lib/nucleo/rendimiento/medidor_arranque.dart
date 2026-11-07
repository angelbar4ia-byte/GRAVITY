/// Mide el arranque (Fase 4, meta: abrir en ≤ 2 s; F4 de calidad): cuánto
/// tarda cada paso de `prepararArranque` y cuándo se pinta el primer cuadro.
///
/// **No inventa cifras**: solo registra lo que ocurre en el equipo donde corre.
/// Las medidas del Galaxy A52 y de la laptop salen de correr la app en ellos
/// (modo `--profile` o release) y leer el resumen que se imprime al arrancar.
/// Sin datos personales: solo nombres de pasos y milisegundos.
library;

import 'package:flutter/foundation.dart';

/// Un paso del arranque: cuándo empezó (desde que arrancó el medidor) y cuánto
/// duró; una marca puntual (p. ej. el primer cuadro) dura cero.
@immutable
class PasoDeArranque {
  const PasoDeArranque(this.nombre, this.inicio, this.duracion);

  final String nombre;
  final Duration inicio;
  final Duration duracion;

  Duration get fin => inicio + duracion;

  Map<String, Object?> aJson() => {
    'paso': nombre,
    'inicio_ms': inicio.inMilliseconds,
    'duracion_ms': duracion.inMilliseconds,
  };
}

class MedidorArranque {
  /// [reloj] devuelve el tiempo transcurrido desde que arrancó la app; se
  /// inyecta en las pruebas.
  MedidorArranque({Duration Function()? reloj})
    : _reloj = reloj ?? _relojReal();

  static Duration Function() _relojReal() {
    final cronometro = Stopwatch()..start();
    return () => cronometro.elapsed;
  }

  final Duration Function() _reloj;
  final List<PasoDeArranque> _pasos = [];

  List<PasoDeArranque> get pasos => List.unmodifiable(_pasos);

  /// Marca un instante (p. ej. `primer_cuadro`).
  void marcar(String nombre) => _pasos.add(PasoDeArranque(nombre, _reloj(), Duration.zero));

  /// Corre [accion] y anota cuánto tardó. Si falla, también lo anota y relanza.
  Future<T> medir<T>(String nombre, Future<T> Function() accion) async {
    final inicio = _reloj();
    try {
      return await accion();
    } finally {
      _pasos.add(PasoDeArranque(nombre, inicio, _reloj() - inicio));
    }
  }

  /// Tiempo hasta el paso [nombre] (su fin), o `null` si no se registró.
  Duration? hasta(String nombre) {
    for (final paso in _pasos) {
      if (paso.nombre == nombre) return paso.fin;
    }
    return null;
  }

  /// Tiempo hasta el primer cuadro: lo que la persona espera para ver algo.
  Duration? get hastaPrimerCuadro => hasta(pasoPrimerCuadro);

  static const pasoPrimerCuadro = 'primer_cuadro';

  List<Map<String, Object?>> aJson() => [for (final p in _pasos) p.aJson()];

  /// Texto para el registro de depuración, un paso por línea.
  String resumen() {
    final salida = StringBuffer('Arranque (ms desde el inicio):\n');
    for (final p in _pasos) {
      final dura = p.duracion == Duration.zero
          ? ''
          : ' (dura ${p.duracion.inMilliseconds})';
      salida.writeln('  ${p.nombre}: ${p.fin.inMilliseconds}$dura');
    }
    return salida.toString().trimRight();
  }
}

/// El medidor de este arranque. `main` lo arranca lo primero; las pruebas
/// pasan el suyo.
final MedidorArranque medidorDeArranque = MedidorArranque();
