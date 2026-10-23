/// Proveedores de Riverpod para el almacenamiento seguro y la huella.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'almacen_seguro.dart';
import 'biometria.dart';
import 'limpieza_local.dart';

/// Se fija en el arranque (almacén del dispositivo) o en la prueba.
final almacenSeguroProvider = Provider<AlmacenSeguro>(
  (ref) => throw UnimplementedError(
    'almacenSeguroProvider se configura en el arranque o en la prueba',
  ),
);

/// Limpieza de lo guardado en el equipo por persona (M5): se usa al quitar a
/// alguien de la tablet. Los módulos registran sus ganchos aquí
/// (`ref.read(limpiezaLocalProvider).registrar(...)`). El arranque fija la
/// misma instancia que usa el servicio de sesión.
final limpiezaLocalProvider = Provider<LimpiezaLocal>(
  (ref) => LimpiezaLocal(ref.watch(almacenSeguroProvider)),
);

/// Huella: en Android se usa la del dispositivo (bloqueo del teléfono); en lo
/// demás, no hay.
final biometriaProvider = Provider<ServicioBiometria>(
  (ref) => const BiometriaNoDisponible(),
);

/// Reloj inyectable (esperas por intentos fallidos del PIN y bloqueo del
/// teléfono).
final relojSeguridadProvider = Provider<DateTime Function()>((ref) => DateTime.now);
