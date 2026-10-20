/// Huella (opcional) con `local_auth`.
///
/// Ojo: Android no dice **de quién** es la huella; cualquier dedo registrado
/// en el dispositivo la acepta. Por eso en la tablet compartida la huella es
/// opcional por persona y el PIN siempre está disponible.
library;

import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

abstract interface class ServicioBiometria {
  Future<bool> disponible();

  /// `true` si la persona se identificó con huella.
  Future<bool> autenticar(String motivo);
}

/// Huella del dispositivo (solo Android).
class BiometriaDispositivo implements ServicioBiometria {
  BiometriaDispositivo([LocalAuthentication? autenticacion])
    : _autenticacion = autenticacion ?? LocalAuthentication();

  final LocalAuthentication _autenticacion;

  @override
  Future<bool> disponible() async {
    try {
      return await _autenticacion.isDeviceSupported() &&
          await _autenticacion.canCheckBiometrics;
    } catch (error) {
      debugPrint('Huella no disponible: $error');
      return false;
    }
  }

  @override
  Future<bool> autenticar(String motivo) async {
    try {
      return await _autenticacion.authenticate(
        localizedReason: motivo,
        biometricOnly: true,
      );
    } catch (error) {
      debugPrint('Huella cancelada o fallida: $error');
      return false;
    }
  }
}

/// Para dispositivos sin huella (laptop) y para pruebas.
class BiometriaNoDisponible implements ServicioBiometria {
  const BiometriaNoDisponible();

  @override
  Future<bool> disponible() async => false;

  @override
  Future<bool> autenticar(String motivo) async => false;
}

/// Huella simulada para pruebas.
class BiometriaFalsa implements ServicioBiometria {
  BiometriaFalsa({this.hayHuella = true, this.acepta = true});

  bool hayHuella;
  bool acepta;
  int intentos = 0;

  @override
  Future<bool> disponible() async => hayHuella;

  @override
  Future<bool> autenticar(String motivo) async {
    intentos++;
    return hayHuella && acepta;
  }
}
