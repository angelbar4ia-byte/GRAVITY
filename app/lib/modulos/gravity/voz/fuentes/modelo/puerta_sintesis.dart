/// Puerta a la síntesis neuronal (fuente B): lo único que la fuente conoce de
/// `sherpa_onnx`. Tiene su versión falsa para que las pruebas no necesiten la
/// biblioteca nativa.
///
/// La real corre en un `Isolate` de larga vida (`puerta_sherpa.dart`); aquí
/// solo está la forma de pedir.
///
/// Reglas (R6): **ningún error de la puerta lleva el texto, las rutas ni el
/// mensaje de la biblioteca**: solo códigos cortos (`carga_fallida`,
/// `sintesis_fallida`, `biblioteca_no_disponible`).
library;

import 'dart:async';
import 'dart:typed_data';

import '../../tipos.dart';

/// Cuántos modelos se dejan cargados a la vez en el `Isolate` (si se piden
/// más, se libera el más viejo). Dos bastan para un diálogo de dos voces de
/// dos modelos distintos sin recargar en cada turno.
const maximoCargados = 2;

/// Audio sintetizado: muestras en [-1, 1], mono.
final class MuestrasDeAudio {
  const MuestrasDeAudio(this.muestras, this.frecuencia);
  final Float32List muestras;

  /// Hz (22 050 en los modelos Piper de calidad media).
  final int frecuencia;

  bool get vacio => muestras.isEmpty || frecuencia <= 0;
}

/// Qué cargar: los archivos ya verificados del modelo.
final class CargaDeModelo {
  const CargaDeModelo({
    required this.idModelo,
    required this.rutaModelo,
    required this.rutaTokens,
    required this.rutaLexicon,
    this.hilos = 2,
  });

  final String idModelo;
  final String rutaModelo;
  final String rutaTokens;
  final String rutaLexicon;

  /// Hilos de cómputo. 2 hasta que P3.3 mida 1, 2 y 4 en el aparato (spec
  /// 4.2.3, criterio 42).
  final int hilos;

  @override
  String toString() => 'CargaDeModelo($idModelo)';
}

abstract interface class PuertaSintesis {
  /// Carga el modelo en el `Isolate` (puede tardar un par de segundos). Si ya
  /// estaba cargado, no hace nada. Lanza [FalloDeSintesis].
  Future<void> cargar(CargaDeModelo carga);

  /// Sintetiza una frase con la voz [sid] del modelo [idModelo] (ya cargado) a
  /// [velocidad] (1.0 normal). Lanza [FalloDeSintesis].
  Future<MuestrasDeAudio> sintetizar({
    required String idModelo,
    required int sid,
    required String texto,
    required double velocidad,
  });

  /// Libera el modelo cargado (memoria).
  Future<void> descargar(String idModelo);

  /// Cierra el `Isolate` y todo lo que tenga cargado.
  Future<void> cerrar();
}

/// Puerta simulada: no carga nada y devuelve ondas sencillas, con la duración
/// proporcional a las palabras del texto.
class PuertaSintesisFalsa implements PuertaSintesis {
  PuertaSintesisFalsa({
    this.frecuencia = 22050,
    this.retardo = Duration.zero,
    this.segundosPorPalabra = 0.3,
  });

  final int frecuencia;

  /// Cuánto tarda en sintetizar cada frase (reloj de la prueba).
  Duration retardo;
  double segundosPorPalabra;

  /// Si no es `null`, [cargar] falla con este código.
  String? fallarAlCargar;

  /// Si no es `null`, [sintetizar] falla con este código.
  String? fallarAlSintetizar;

  /// Si es `true`, [sintetizar] devuelve audio vacío (la prueba de humo debe
  /// atraparlo).
  bool audioVacio = false;

  /// Si no es `null`, [sintetizar] falla cuando el contador de peticiones
  /// llega a este número (0 es la primera).
  int? fallarEnLaPeticion;

  /// Cada carga pedida, en orden.
  final cargas = <CargaDeModelo>[];

  /// Cada síntesis pedida (modelo, voz, texto y velocidad), en orden.
  final peticiones = <PeticionDeSintesis>[];

  /// Modelos liberados con [descargar].
  final liberados = <String>[];

  final cargados = <String>{};
  bool cerrada = false;

  /// Si no es `null`, [sintetizar] espera a que se complete (para probar
  /// paradas a mitad).
  Completer<void>? compuerta;

  @override
  Future<void> cargar(CargaDeModelo carga) async {
    cargas.add(carga);
    final f = fallarAlCargar;
    if (f != null) throw FalloDeSintesis(Fuente.modelo, f);
    cargados.add(carga.idModelo);
  }

  @override
  Future<MuestrasDeAudio> sintetizar({
    required String idModelo,
    required int sid,
    required String texto,
    required double velocidad,
  }) async {
    final numero = peticiones.length;
    peticiones.add(
      PeticionDeSintesis(
        idModelo: idModelo,
        sid: sid,
        texto: texto,
        velocidad: velocidad,
      ),
    );
    if (retardo > Duration.zero) await Future<void>.delayed(retardo);
    final c = compuerta;
    if (c != null && !c.isCompleted) await c.future;
    final f = fallarAlSintetizar;
    if (f != null || fallarEnLaPeticion == numero) {
      throw FalloDeSintesis(Fuente.modelo, f ?? 'sintesis_fallida');
    }
    if (!cargados.contains(idModelo)) {
      throw const FalloDeSintesis(Fuente.modelo, 'modelo_no_cargado');
    }
    if (audioVacio) return MuestrasDeAudio(Float32List(0), 0);
    final palabras = texto.trim().split(RegExp(r'\s+')).length;
    final n = (palabras * segundosPorPalabra / velocidad * frecuencia).round();
    return MuestrasDeAudio(Float32List(n < 1 ? 1 : n), frecuencia);
  }

  @override
  Future<void> descargar(String idModelo) async {
    liberados.add(idModelo);
    cargados.remove(idModelo);
  }

  @override
  Future<void> cerrar() async {
    cerrada = true;
    cargados.clear();
  }
}

/// Lo que recibió la puerta simulada.
final class PeticionDeSintesis {
  const PeticionDeSintesis({
    required this.idModelo,
    required this.sid,
    required this.texto,
    required this.velocidad,
  });
  final String idModelo;
  final int sid;
  final String texto;
  final double velocidad;
}
