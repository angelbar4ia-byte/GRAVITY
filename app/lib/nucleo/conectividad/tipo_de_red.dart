/// Qué tipo de red hay (Wi-Fi, datos móviles…): lo que el gestor de descargas
/// del motor de voz necesita para pedir confirmación antes de gastar datos
/// (spec `fase-8-motor-de-voz.md`, 3.5 punto 6 y 4.2.2 punto 2).
///
/// Es una puerta aparte de [FuenteConectividad] (que solo dice si hay red)
/// para no romper a sus tres implementaciones. La real, con
/// `connectivity_plus`, está en `tipo_de_red_plus.dart`.
///
/// Ojo: `connectivity_plus` informa el tipo de red pero no si es de pago: un
/// punto de acceso del teléfono cuenta como Wi-Fi. Por eso el aviso de una
/// descarga grande dice cuánto pesa aunque haya Wi-Fi.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum TipoDeRed {
  sinRed,
  wifi,
  ethernet,
  datosMoviles,

  /// VPN, Bluetooth u otra: no se sabe si cuesta datos.
  otra;

  /// `true` con Wi-Fi o Ethernet (las descargas grandes solo van aquí sin
  /// preguntar).
  bool get esSinCostoDeDatos => this == wifi || this == ethernet;
}

abstract interface class FuenteTipoDeRed {
  Future<TipoDeRed> tipo();

  /// Avisa cada vez que cambia el tipo de red.
  Stream<TipoDeRed> get cambios;
}

/// Siempre Wi-Fi (valor por omisión: pruebas y modo demostración).
class FuenteTipoDeRedSiempreWifi implements FuenteTipoDeRed {
  const FuenteTipoDeRedSiempreWifi();

  @override
  Future<TipoDeRed> tipo() async => TipoDeRed.wifi;

  @override
  Stream<TipoDeRed> get cambios => const Stream<TipoDeRed>.empty();
}

/// Red simulada para pruebas: se cambia con [poner].
class FuenteTipoDeRedFalsa implements FuenteTipoDeRed {
  FuenteTipoDeRedFalsa([this._tipo = TipoDeRed.wifi]);

  TipoDeRed _tipo;
  final _controlador = StreamController<TipoDeRed>.broadcast();

  @override
  Future<TipoDeRed> tipo() async => _tipo;

  @override
  Stream<TipoDeRed> get cambios => _controlador.stream;

  void poner(TipoDeRed tipo) {
    _tipo = tipo;
    _controlador.add(tipo);
  }

  Future<void> cerrar() => _controlador.close();
}

/// Fuente del equipo. El arranque la sustituye por la de `connectivity_plus`
/// cuando exista quien la use (la descarga de voces, P3.2a-2).
final fuenteTipoDeRedProvider = Provider<FuenteTipoDeRed>(
  (ref) => const FuenteTipoDeRedSiempreWifi(),
);
