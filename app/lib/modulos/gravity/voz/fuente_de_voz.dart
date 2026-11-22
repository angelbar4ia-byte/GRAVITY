/// Lo que ofrece una fuente de voz al motor (spec, sección 3.2, punto 8).
library;

import 'package:flutter/foundation.dart' show immutable;

import 'asignador.dart';
import 'tipos.dart';

@immutable
final class Capacidades {
  const Capacidades({
    required this.tono,
    required this.progresoPorPalabra,
    required this.pausa,
    required this.velocidadMin,
    required this.velocidadMax,
  });

  /// La fuente puede cambiar el tono de una voz.
  final bool tono;
  final bool progresoPorPalabra;
  final bool pausa;

  /// Factor de velocidad (1.0 es la normal).
  final double velocidadMin;
  final double velocidadMax;

  double ajustarVelocidad(double factor) =>
      factor.clamp(velocidadMin, velocidadMax).toDouble();
}

/// Una vía de audio (A: dispositivo, B: modelo, C: pregrabado).
abstract interface class FuenteDeVoz {
  Fuente get tipo;
  Capacidades get capacidades;

  /// Voces de la variante. Las que necesitan red (`local == false`) pueden
  /// venir, pero el motor las descarta siempre (R8).
  ///
  /// Si el equipo no tiene motor de voz, lanza [FalloDeSintesis].
  Future<List<VozMotor>> voces(Variante variante);

  /// `null` si esta fuente puede con TODO el guion; si no, por qué no.
  Future<Motivo?> motivoNoDisponible(Guion guion, Asignacion asignacion);

  Future<Reproduccion> reproducir(
    Guion guion,
    Asignacion asignacion,
    double velocidad,
  );
}

/// Una voz tal como la reporta el sistema, sin filtrar. Es lo que muestra
/// Ajustes › Voz › Detalles técnicos y sirve para ver qué voces trae cada
/// aparato (spec 9.2, V4 y V6).
@immutable
final class VozDelSistema {
  const VozDelSistema({
    required this.nombre,
    required this.locale,
    this.calidad,
    this.requiereRed,
    this.instalada = true,
    this.genero = Genero.sinDato,
  });

  final String nombre;
  final String locale;

  /// Texto del sistema (`high`, `normal`…), si lo da.
  final String? calidad;

  /// `null` si la plataforma no lo dice (Windows).
  final bool? requiereRed;

  /// `false` si los datos de la voz no están instalados (Android: `features`
  /// con `notInstalled`).
  final bool instalada;
  final Genero genero;
}

/// Fuente que sabe listar todas las voces del sistema, también las que no se
/// ofrecen.
abstract interface class FuenteConDiagnostico {
  /// Vuelve a preguntar al sistema (las voces cambian cuando la persona
  /// instala una).
  Future<void> refrescar();

  Future<List<VozDelSistema>> diagnostico();
}
