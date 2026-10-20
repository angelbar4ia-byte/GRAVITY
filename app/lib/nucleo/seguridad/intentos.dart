/// Límite de intentos fallidos de un PIN (tablet de la casa y bloqueo del
/// teléfono). Los fallos y los bloqueos se guardan en el almacenamiento seguro:
/// cerrar y abrir la app no los borra (revisión de la Fase 0, I2).
///
/// Cada [PoliticaIntentos.intentosAntesDeBloquear] fallos seguidos, el PIN se
/// bloquea; la espera empieza en [PoliticaIntentos.primeraEspera] y se duplica
/// en cada bloqueo siguiente hasta [PoliticaIntentos.esperaMaxima]. Un PIN
/// correcto reinicia la cuenta.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'almacen_seguro.dart';

class PoliticaIntentos {
  const PoliticaIntentos({
    this.intentosAntesDeBloquear = 5,
    this.primeraEspera = const Duration(seconds: 30),
    this.esperaMaxima = const Duration(minutes: 15),
  });

  final int intentosAntesDeBloquear;
  final Duration primeraEspera;
  final Duration esperaMaxima;

  /// Espera del bloqueo número [bloqueo] (1 = el primero): 30 s, 1 min,
  /// 2 min, 4 min, 8 min y luego 15 min.
  Duration esperaDelBloqueo(int bloqueo) {
    final ms =
        primeraEspera.inMilliseconds * pow(2, max(0, bloqueo - 1)).toDouble();
    return Duration(
      milliseconds: min(ms, esperaMaxima.inMilliseconds.toDouble()).round(),
    );
  }
}

/// Estado guardado de un PIN.
class EstadoIntentos {
  const EstadoIntentos({this.fallos = 0, this.bloqueos = 0, this.hasta});

  /// Fallos seguidos desde el último bloqueo (o desde el último acierto).
  final int fallos;

  /// Bloqueos seguidos (sin un acierto en medio): definen la espera.
  final int bloqueos;

  /// Hasta cuándo dura el bloqueo actual.
  final DateTime? hasta;

  bool get vacio => fallos == 0 && bloqueos == 0 && hasta == null;

  Map<String, Object?> aJson() => {
    'fallos': fallos,
    'bloqueos': bloqueos,
    if (hasta != null) 'hasta': hasta!.toUtc().toIso8601String(),
  };

  factory EstadoIntentos.desdeJson(Map<String, Object?> json) => EstadoIntentos(
    fallos: (json['fallos'] as int?) ?? 0,
    bloqueos: (json['bloqueos'] as int?) ?? 0,
    hasta: DateTime.tryParse('${json['hasta']}'),
  );
}

/// Resultado de anotar un fallo.
enum ResultadoFallo { otraVez, bloqueado }

/// Lleva la cuenta de fallos por identificador (p. ej. la persona) y la guarda
/// en [AlmacenSeguro] bajo [clave].
class LimiteIntentos {
  LimiteIntentos(
    this._almacen, {
    required this.clave,
    this.politica = const PoliticaIntentos(),
    DateTime Function()? reloj,
  }) : _reloj = reloj ?? DateTime.now;

  final AlmacenSeguro _almacen;
  final String clave;
  final PoliticaIntentos politica;
  final DateTime Function() _reloj;
  final _estados = <String, EstadoIntentos>{};

  /// Lee lo guardado. Llamar antes de usarlo.
  Future<void> cargar() async {
    final texto = await _almacen.leer(clave);
    _estados.clear();
    if (texto == null) return;
    try {
      final json = (jsonDecode(texto) as Map).cast<String, Object?>();
      for (final MapEntry(:key, :value) in json.entries) {
        _estados[key] = EstadoIntentos.desdeJson(
          (value! as Map).cast<String, Object?>(),
        );
      }
    } catch (_) {
      // Dato dañado: se empieza de cero (el PIN sigue haciendo falta).
    }
  }

  EstadoIntentos estadoDe(String id) => _estados[id] ?? const EstadoIntentos();

  /// Cuánto falta para poder intentar de nuevo, o `null` si no está bloqueado.
  Duration? esperaRestante(String id) {
    final hasta = estadoDe(id).hasta;
    if (hasta == null) return null;
    final falta = hasta.difference(_reloj());
    return falta > Duration.zero ? falta : null;
  }

  bool bloqueado(String id) => esperaRestante(id) != null;

  /// Anota un PIN incorrecto. Al llegar al límite, bloquea.
  ResultadoFallo anotarFallo(String id) {
    final actual = estadoDe(id);
    final fallos = actual.fallos + 1;
    if (fallos < politica.intentosAntesDeBloquear) {
      _fijar(
        id,
        EstadoIntentos(
          fallos: fallos,
          bloqueos: actual.bloqueos,
          hasta: actual.hasta,
        ),
      );
      return ResultadoFallo.otraVez;
    }
    final bloqueos = actual.bloqueos + 1;
    _fijar(
      id,
      EstadoIntentos(
        bloqueos: bloqueos,
        hasta: _reloj().add(politica.esperaDelBloqueo(bloqueos)),
      ),
    );
    return ResultadoFallo.bloqueado;
  }

  /// PIN correcto: se reinicia la cuenta.
  void anotarAcierto(String id) {
    if (_estados.containsKey(id)) _fijar(id, null);
  }

  /// Olvida a [id] (p. ej. al quitar a la persona).
  void olvidar(String id) => anotarAcierto(id);

  void _fijar(String id, EstadoIntentos? estado) {
    if (estado == null || estado.vacio) {
      _estados.remove(id);
    } else {
      _estados[id] = estado;
    }
    // Se guarda en cuanto cambia; el almacén ordena las escrituras.
    unawaited(_guardar());
  }

  Future<void> _guardar() => _estados.isEmpty
      ? _almacen.borrar(clave)
      : _almacen.escribir(
          clave,
          jsonEncode({
            for (final MapEntry(:key, :value) in _estados.entries)
              key: value.aJson(),
          }),
        );
}

/// Texto corto de una espera: «30 segundos», «2 minutos».
String textoEspera(Duration espera) {
  final segundos = (espera.inMilliseconds / 1000).ceil();
  if (segundos < 60) return segundos == 1 ? '1 segundo' : '$segundos segundos';
  final minutos = (segundos / 60).ceil();
  return minutos == 1 ? '1 minuto' : '$minutos minutos';
}
