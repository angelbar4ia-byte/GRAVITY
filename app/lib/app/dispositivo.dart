/// Tipo de dispositivo (D4, D14): Windows es la laptop; en Android, una
/// pantalla con lado corto de 600 dp o más es la tablet y lo demás, teléfono.
library;

import 'dart:ui' show FlutterView, Size;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../nucleo/contratos/dispositivo.dart';

/// Lado corto mínimo (dp) para considerar tablet.
const double ladoCortoMinimoTablet = 600;

/// Función pura: decide el cascarón según la plataforma y el tamaño lógico.
TipoDispositivo detectarTipoDispositivo({
  required TargetPlatform plataforma,
  required Size tamanoLogico,
}) => switch (plataforma) {
  // Escritorio: el sistema completo (Linux y macOS solo para desarrollo).
  TargetPlatform.windows ||
  TargetPlatform.linux ||
  TargetPlatform.macOS => TipoDispositivo.laptop,
  TargetPlatform.android || TargetPlatform.iOS || TargetPlatform.fuchsia =>
    tamanoLogico.shortestSide >= ladoCortoMinimoTablet
        ? TipoDispositivo.tablet
        : TipoDispositivo.telefono,
};

/// Interpreta `--dart-define=GRAVITY_DISPOSITIVO=tablet` (para probar otro
/// cascarón desde la laptop). Vacío o desconocido: `null`.
TipoDispositivo? tipoDispositivoForzado(String texto) =>
    switch (texto.trim().toLowerCase()) {
      'laptop' => TipoDispositivo.laptop,
      'tablet' => TipoDispositivo.tablet,
      'telefono' || 'teléfono' => TipoDispositivo.telefono,
      _ => null,
    };

/// Detecta el dispositivo con la primera vista de la app.
TipoDispositivo detectarDesdeVista(
  FlutterView? vista, {
  TargetPlatform? plataforma,
}) {
  final tamano = vista == null || vista.devicePixelRatio == 0
      ? Size.zero
      : vista.physicalSize / vista.devicePixelRatio;
  return detectarTipoDispositivo(
    plataforma: plataforma ?? defaultTargetPlatform,
    tamanoLogico: tamano,
  );
}

/// Tipo de dispositivo; se fija en el arranque y no cambia mientras la app
/// está abierta (el lado corto no cambia al girar).
final tipoDispositivoProvider = Provider<TipoDispositivo>(
  (ref) => TipoDispositivo.laptop,
);
