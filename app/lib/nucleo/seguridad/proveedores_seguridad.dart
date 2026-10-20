/// Proveedores de Riverpod para el almacenamiento seguro y la huella.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'almacen_seguro.dart';
import 'biometria.dart';

/// Se fija en el arranque (almacén del dispositivo) o en la prueba.
final almacenSeguroProvider = Provider<AlmacenSeguro>(
  (ref) => throw UnimplementedError(
    'almacenSeguroProvider se configura en el arranque o en la prueba',
  ),
);

/// Huella: en Android se usa la del dispositivo; en lo demás, no hay.
final biometriaProvider = Provider<ServicioBiometria>(
  (ref) => const BiometriaNoDisponible(),
);

/// Reloj inyectable (bloqueo por intentos fallidos del PIN).
final relojSeguridadProvider = Provider<DateTime Function()>((ref) => DateTime.now);
