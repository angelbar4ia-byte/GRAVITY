/// Vocabulario del motor de voz de GRAVITY (Fase 8, P3.2a-1).
///
/// Especificación: `docs/specs/fase-8-motor-de-voz.md`, sección 3. Aquí solo
/// hay tipos y errores: nada de audio, nada de red.
///
/// Reglas que estos tipos ayudan a cumplir:
/// - R6: ningún error ni evento de avance lleva el texto que se dijo o se iba
///   a decir. Solo códigos.
/// - R2: nada de esto identifica ni autoriza a nadie; el motor solo produce
///   sonido.
library;

import 'package:flutter/foundation.dart' show immutable;

/// Para qué se habla. Decide qué preferencia se aplica y qué texto se acepta.
///
/// No hay valor para las bocinas: depende de D6, que sigue en estado de
/// propuesta (spec, sección 7). Mientras tanto el motor no importa nada de
/// `modulos/casa` y `PuenteCasa.hablar` solo acepta un `MensajeBocina`.
enum UsoVoz { curso, asistente }

/// Nombre de una voz DENTRO de un guion (las del formato V16 del curso).
enum VozDeGuion {
  f1('F1', 'Mujer 1'),
  f2('F2', 'Mujer 2'),
  m1('M1', 'Hombre 1'),
  m2('M2', 'Hombre 2'),
  n('N', 'Narrador');

  const VozDeGuion(this.etiqueta, this.nombre);

  /// Código del contenido (`F1`, `M1`, `N`…).
  final String etiqueta;

  /// Nombre para la pantalla.
  final String nombre;

  /// Género que se busca para esta voz de guion; `null` si da igual (N).
  Genero? get generoBuscado => switch (this) {
    f1 || f2 => Genero.mujer,
    m1 || m2 => Genero.hombre,
    n => null,
  };

  static VozDeGuion? deEtiqueta(String? etiqueta) {
    for (final v in values) {
      if (v.etiqueta == etiqueta) return v;
    }
    return null;
  }
}

/// Idioma y acento. `enUS` y `enGB` son la `variante` del contenido; `esMX`
/// agrupa el español (primero se ofrecen las voces `es-MX`).
enum Variante {
  enUS('en-US', 'en', 'Inglés americano'),
  enGB('en-GB', 'en', 'Inglés británico'),
  esMX('es-MX', 'es', 'Español');

  const Variante(this.etiqueta, this.idioma, this.nombre);

  /// Etiqueta BCP-47 (`en-US`).
  final String etiqueta;

  /// Código de idioma (`en`, `es`).
  final String idioma;

  /// Nombre para la pantalla.
  final String nombre;

  static Variante? deEtiqueta(String? etiqueta) {
    for (final v in values) {
      if (v.etiqueta == etiqueta) return v;
    }
    return null;
  }
}

/// Las tres vías. El orden es el de la cadena por omisión del curso (C, B, A).
enum Fuente {
  pregrabado('Audio pregrabado'),
  modelo('Voz descargada'),
  dispositivo('Voz del dispositivo');

  const Fuente(this.nombre);

  /// Nombre para la pantalla.
  final String nombre;

  static Fuente? deNombre(String? nombre) {
    for (final f in values) {
      if (f.name == nombre) return f;
    }
    return null;
  }
}

enum Genero { mujer, hombre, sinDato }

/// Una voz concreta de una fuente: lo que lista Ajustes › Voz.
@immutable
final class VozMotor {
  const VozMotor({
    required this.id,
    required this.fuente,
    required this.nombre,
    required this.variante,
    required this.genero,
    required this.local,
    this.locale = '',
    this.calidad = 0,
  });

  /// Estable entre ejecuciones.
  final String id;
  final Fuente fuente;

  /// Lo que ve la persona.
  final String nombre;
  final Variante variante;
  final Genero genero;

  /// `false` si para hablar necesita red. Una voz así NUNCA se usa (R8).
  final bool local;

  /// Etiqueta de idioma tal como la da el sistema (`es-MX`, `es-US`…).
  final String locale;

  /// De 0 (sin dato) a 5 (muy alta); sirve solo para ordenar.
  final int calidad;

  @override
  bool operator ==(Object other) =>
      other is VozMotor && other.id == id && other.fuente == fuente;

  @override
  int get hashCode => Object.hash(id, fuente);

  @override
  String toString() => 'VozMotor($id, ${fuente.name}, ${variante.etiqueta})';
}

/// Un turno de un guion.
@immutable
final class Turno {
  const Turno({required this.voz, required this.texto, this.pausaDespues});
  final VozDeGuion voz;
  final String texto;

  /// `null`: la pausa del guion.
  final Duration? pausaDespues;

  /// Nunca incluye el texto (R6).
  @override
  String toString() => 'Turno(${voz.etiqueta})';
}

/// Una unidad de audio, una frase suelta o una respuesta del asistente.
@immutable
final class Guion {
  const Guion({
    required this.id,
    required this.variante,
    required this.turnos,
    this.huella,
    this.pausaEntreTurnos = const Duration(milliseconds: 600),
  });

  /// Id de la unidad (o de sesión y frase): nombra el audio pregrabado.
  final String id;

  /// La escribe `compilar`; sin huella no hay audio pregrabado.
  final String? huella;
  final Variante variante;
  final List<Turno> turnos;

  /// Propuesta: se decide de oído en P3.3.
  final Duration pausaEntreTurnos;

  int get vocesDistintas => turnos.map((t) => t.voz).toSet().length;

  /// Las voces de guion que usa, en el orden canónico (F1, F2, M1, M2, N).
  Set<VozDeGuion> get vocesUsadas => {
    for (final v in VozDeGuion.values)
      if (turnos.any((t) => t.voz == v)) v,
  };

  /// Nunca incluye el texto (R6).
  @override
  String toString() => 'Guion($id, ${turnos.length} turnos)';
}

/// Avance de una reproducción. NUNCA lleva el texto: el curso oculta el guion
/// hasta que la persona contesta (plan 3.5).
@immutable
final class Avance {
  const Avance({
    required this.turno,
    required this.totalTurnos,
    required this.voz,
    required this.posicion,
    this.duracion,
  });

  /// De 0 a `totalTurnos - 1`.
  final int turno;
  final int totalTurnos;
  final VozDeGuion voz;

  /// Desde el inicio de la reproducción.
  final Duration posicion;

  /// La fuente pregrabada la conoce; el dispositivo, no.
  final Duration? duracion;

  @override
  String toString() => 'Avance(turno ${turno + 1}/$totalTurnos, ${voz.etiqueta})';
}

enum Fin { completa, parada }

/// Lo que devuelven `reproducir` y `decir`. Es independiente de las pantallas.
abstract interface class Reproduccion {
  /// La fuente que se usó (el curso la registra en las pruebas con valor).
  Fuente get fuente;

  /// Un evento por turno. Un solo oyente (los eventos se guardan hasta que
  /// alguien escucha). Se cierra al terminar o al parar.
  Stream<Avance> get avance;

  /// Completa al terminar o al parar. Si falla, completa con un [ErrorVoz].
  Future<Fin> get terminada;
  Future<void> pausar();
  Future<void> reanudar();
  Future<void> parar();
}

/// Por qué una fuente no sirve para un uso.
enum Motivo {
  plataformaNoSoportada,

  /// El equipo no tiene motor de texto a voz (o no responde).
  sinMotorDeVoz,
  sinVozEnElIdioma,
  vocesInsuficientes,
  modeloNoInstalado,
  sinPaqueteDeAudio,
  audioCaducado,
  formatoNoSoportado,
  excluidaPorLaPersona,
}

@immutable
final class Disponibilidad {
  const Disponibilidad({required this.cadena, required this.descartadas});

  /// Las que sirven, en orden de uso.
  final List<Fuente> cadena;

  /// Las que no, y por qué.
  final Map<Fuente, Motivo> descartadas;

  bool get disponible => cadena.isNotEmpty;
  Fuente? get usaria => cadena.isEmpty ? null : cadena.first;
}

/// Ningún error lleva el texto que se iba a decir (R6).
sealed class ErrorVoz implements Exception {
  const ErrorVoz();
}

final class SinFuenteDisponible extends ErrorVoz {
  const SinFuenteDisponible(this.motivos);
  final Map<Fuente, Motivo> motivos;

  @override
  String toString() =>
      'SinFuenteDisponible(${motivos.entries.map((e) => '${e.key.name}: ${e.value.name}').join(', ')})';
}

final class OcupadoPorOtroUso extends ErrorVoz {
  const OcupadoPorOtroUso();

  @override
  String toString() => 'OcupadoPorOtroUso';
}

final class FalloDeSintesis extends ErrorVoz {
  const FalloDeSintesis(this.fuente, this.codigo);
  final Fuente fuente;

  /// Un código corto (`speak_error`, `voz_no_encontrada`…), nunca texto de la
  /// persona.
  final String codigo;

  @override
  String toString() => 'FalloDeSintesis(${fuente.name}, $codigo)';
}

// ── Errores del gestor de descargas (P3.2a-2, spec 3.2 punto 4) ─────────────
//
// Ninguno lleva texto de la persona, la dirección completa ni lo que contestó
// el servidor: solo códigos y nombres de archivo del catálogo (R6, R7).

/// Hay datos móviles (o una red de la que no se sabe si cuesta datos) y la
/// persona no lo confirmó. No se abrió ninguna conexión.
final class SinWifi extends ErrorVoz {
  const SinWifi();

  @override
  String toString() => 'SinWifi';
}

/// No hay conexión (o no se pudo abrir). Lo ya descargado se conserva.
final class SinRed extends ErrorVoz {
  const SinRed();

  @override
  String toString() => 'SinRed';
}

/// El disco está lleno. [bytesNecesarios] es lo que faltaba bajar.
final class SinEspacio extends ErrorVoz {
  const SinEspacio(this.bytesNecesarios);
  final int bytesNecesarios;

  @override
  String toString() => 'SinEspacio($bytesNecesarios)';
}

/// El archivo no es el esperado (tamaño o sha256). Se borró lo descargado.
final class HuellaIncorrecta extends ErrorVoz {
  const HuellaIncorrecta(this.archivo);

  /// Nombre del archivo en el catálogo (nunca una dirección).
  final String archivo;

  @override
  String toString() => 'HuellaIncorrecta($archivo)';
}

/// La descarga se cortó. Lo descargado se conserva para reanudar.
final class DescargaInterrumpida extends ErrorVoz {
  const DescargaInterrumpida(this.bytes, this.total);
  final int bytes;
  final int total;

  @override
  String toString() => 'DescargaInterrumpida($bytes/$total)';
}

/// El alojamiento todavía no tiene el archivo (404 u otra respuesta que dice
/// que no existe o no es público). No es un fallo de la red de la persona.
final class NoDisponibleAun extends ErrorVoz {
  const NoDisponibleAun();

  @override
  String toString() => 'NoDisponibleAun';
}
