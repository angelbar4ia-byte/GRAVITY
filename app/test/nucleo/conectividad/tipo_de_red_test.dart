// Tipo de red para el gestor de descargas del motor de voz (P3.2a-1).
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/conectividad/tipo_de_red.dart';
import 'package:gravity/nucleo/conectividad/tipo_de_red_plus.dart';

class _ConectividadSimulada implements Connectivity {
  _ConectividadSimulada(this.actual);

  List<ConnectivityResult> actual;
  bool falla = false;
  final cambiosDeRed = <List<ConnectivityResult>>[];

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async {
    if (falla) throw StateError('sin respuesta');
    return actual;
  }

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      Stream.fromIterable(cambiosDeRed);
}

void main() {
  group('tipoDeRedDe', () {
    test('sin red, wifi, ethernet y datos móviles', () {
      expect(tipoDeRedDe([ConnectivityResult.none]), TipoDeRed.sinRed);
      expect(tipoDeRedDe([]), TipoDeRed.sinRed);
      expect(tipoDeRedDe([ConnectivityResult.wifi]), TipoDeRed.wifi);
      expect(tipoDeRedDe([ConnectivityResult.ethernet]), TipoDeRed.ethernet);
      expect(tipoDeRedDe([ConnectivityResult.mobile]), TipoDeRed.datosMoviles);
    });

    test('con varias redes cuenta la más barata', () {
      expect(
        tipoDeRedDe([ConnectivityResult.mobile, ConnectivityResult.wifi]),
        TipoDeRed.wifi,
      );
      expect(
        tipoDeRedDe([ConnectivityResult.vpn, ConnectivityResult.mobile]),
        TipoDeRed.datosMoviles,
      );
    });

    test('VPN o Bluetooth solos: no se sabe si cuestan datos', () {
      expect(tipoDeRedDe([ConnectivityResult.vpn]), TipoDeRed.otra);
      expect(tipoDeRedDe([ConnectivityResult.bluetooth]), TipoDeRed.otra);
    });

    test('solo Wi-Fi y Ethernet no cuestan datos', () {
      expect(TipoDeRed.wifi.esSinCostoDeDatos, isTrue);
      expect(TipoDeRed.ethernet.esSinCostoDeDatos, isTrue);
      expect(TipoDeRed.datosMoviles.esSinCostoDeDatos, isFalse);
      expect(TipoDeRed.otra.esSinCostoDeDatos, isFalse);
      expect(TipoDeRed.sinRed.esSinCostoDeDatos, isFalse);
    });
  });

  group('FuenteTipoDeRedPlus', () {
    test('lee el tipo y avisa los cambios distintos', () async {
      final conectividad = _ConectividadSimulada([ConnectivityResult.wifi])
        ..cambiosDeRed.addAll([
          [ConnectivityResult.wifi],
          [ConnectivityResult.mobile],
          [ConnectivityResult.mobile],
          [ConnectivityResult.none],
        ]);
      final fuente = FuenteTipoDeRedPlus(conectividad);
      expect(await fuente.tipo(), TipoDeRed.wifi);
      expect(await fuente.cambios.toList(), [
        TipoDeRed.wifi,
        TipoDeRed.datosMoviles,
        TipoDeRed.sinRed,
      ]);
    });

    test('si el sistema no responde, no afirma que hay Wi-Fi', () async {
      final conectividad = _ConectividadSimulada([ConnectivityResult.wifi])
        ..falla = true;
      expect(await FuenteTipoDeRedPlus(conectividad).tipo(), TipoDeRed.otra);
    });
  });

  test('la fuente falsa cambia y avisa', () async {
    final fuente = FuenteTipoDeRedFalsa();
    expect(await fuente.tipo(), TipoDeRed.wifi);
    final avisos = <TipoDeRed>[];
    final sub = fuente.cambios.listen(avisos.add);
    fuente.poner(TipoDeRed.datosMoviles);
    await Future<void>.delayed(Duration.zero);
    expect(await fuente.tipo(), TipoDeRed.datosMoviles);
    expect(avisos, [TipoDeRed.datosMoviles]);
    await sub.cancel();
    await fuente.cerrar();
  });
}
