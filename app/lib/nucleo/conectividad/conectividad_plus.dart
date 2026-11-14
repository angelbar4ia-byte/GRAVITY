/// La conexión del equipo con `connectivity_plus` (Android y Windows).
///
/// Dice si hay *alguna* red (wifi, datos, ethernet, VPN); no prueba que el
/// servidor responda (eso lo dice la cola al subir). Separado de
/// `conectividad.dart` para que las pruebas no dependan del plugin.
library;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import 'conectividad.dart';

bool _hayAlgunaRed(List<ConnectivityResult> resultados) =>
    resultados.any((r) => r != ConnectivityResult.none);

class FuenteConectividadPlus implements FuenteConectividad {
  FuenteConectividadPlus([Connectivity? conectividad])
    : _conectividad = conectividad ?? Connectivity();

  final Connectivity _conectividad;

  @override
  Future<bool> hayRed() async {
    try {
      return _hayAlgunaRed(await _conectividad.checkConnectivity());
    } catch (error) {
      // Si el sistema no responde, no se afirma lo contrario: se deja "en línea"
      // y la cola dirá si algo no sube.
      debugPrint('Conectividad: $error');
      return true;
    }
  }

  @override
  Stream<bool> get cambios =>
      _conectividad.onConnectivityChanged.map(_hayAlgunaRed).distinct();
}
