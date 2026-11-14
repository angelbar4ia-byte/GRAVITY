/// Huella (opcional) con `local_auth`, solo para el bloqueo del teléfono
/// personal (`bloqueo.dart`, I8).
///
/// Ojo: Android no dice **de quién** es la huella; cualquier dedo registrado
/// en el dispositivo la acepta. Por eso la tablet compartida **no** abre con
/// huella: solo con el PIN de cada persona (revisión de la Fase 0, B3).
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
      if (!await _autenticacion.isDeviceSupported() ||
          !await _autenticacion.canCheckBiometrics) {
        return false;
      }
      // Con hardware pero sin ninguna huella registrada no hay nada que pedir.
      return (await _autenticacion.getAvailableBiometrics()).isNotEmpty;
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
