/// El tipo de red con `connectivity_plus` (Android y Windows). Separado de
/// `tipo_de_red.dart` para que las pruebas no dependan del plugin.
library;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import 'tipo_de_red.dart';

/// El tipo más barato de los que informa el sistema: Wi-Fi, luego Ethernet,
/// luego datos móviles; lo demás (VPN, Bluetooth) es [TipoDeRed.otra].
TipoDeRed tipoDeRedDe(List<ConnectivityResult> resultados) {
  final r = resultados.where((e) => e != ConnectivityResult.none).toSet();
  if (r.isEmpty) return TipoDeRed.sinRed;
  if (r.contains(ConnectivityResult.wifi)) return TipoDeRed.wifi;
  if (r.contains(ConnectivityResult.ethernet)) return TipoDeRed.ethernet;
  if (r.contains(ConnectivityResult.mobile)) return TipoDeRed.datosMoviles;
  return TipoDeRed.otra;
}

class FuenteTipoDeRedPlus implements FuenteTipoDeRed {
  FuenteTipoDeRedPlus([Connectivity? conectividad])
    : _conectividad = conectividad ?? Connectivity();

  final Connectivity _conectividad;

  @override
  Future<TipoDeRed> tipo() async {
    try {
      return tipoDeRedDe(await _conectividad.checkConnectivity());
    } catch (error) {
      // Si el sistema no responde no se afirma que hay Wi-Fi: se trata como
      // "otra" y la descarga pide confirmación.
      debugPrint('Tipo de red: ${error.runtimeType}');
      return TipoDeRed.otra;
    }
  }

  @override
  Stream<TipoDeRed> get cambios =>
      _conectividad.onConnectivityChanged.map(tipoDeRedDe).distinct();
}
