// Conexión real para el indicador "En línea" (E1 de la Fase 4, D22).
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/base_local/base_local.dart';
import 'package:gravity/nucleo/cola/proveedores_cola.dart';
import 'package:gravity/nucleo/conectividad/conectividad.dart';
import 'package:gravity/nucleo/conectividad/conectividad_plus.dart';

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
  group('ResumenConexion', () {
    test('los cuatro estados del indicador', () {
      expect(
        const ResumenConexion(hayRed: true, porSubir: 0).estado,
        EstadoConexion.enLinea,
      );
      expect(
        const ResumenConexion(hayRed: true, porSubir: 3).estado,
        EstadoConexion.sincronizando,
      );
      expect(
        const ResumenConexion(hayRed: false, porSubir: 0).estado,
        EstadoConexion.sinConexion,
      );
      expect(
        const ResumenConexion(hayRed: false, porSubir: 2).estado,
        EstadoConexion.porSubir,
      );
    });

    test('textos del indicador', () {
      expect(const ResumenConexion(hayRed: true, porSubir: 0).texto, 'En línea');
      expect(
        const ResumenConexion(hayRed: true, porSubir: 1).texto,
        'Sincronizando',
      );
      expect(
        const ResumenConexion(hayRed: false, porSubir: 0).texto,
        'Sin conexión',
      );
      expect(
        const ResumenConexion(hayRed: false, porSubir: 1).texto,
        '1 por subir',
      );
      expect(
        const ResumenConexion(hayRed: false, porSubir: 4).texto,
        '4 por subir',
      );
    });

    test('"en línea" es solo "hay red" (sincronizando también está conectado)', () {
      expect(const ResumenConexion(hayRed: true, porSubir: 5).enLinea, isTrue);
      expect(const ResumenConexion(hayRed: false, porSubir: 5).enLinea, isFalse);
    });
  });

  group('hayRedProvider', () {
    test('sigue a la fuente: se cae la red y vuelve', () async {
      final fuente = FuenteConectividadFalsa();
      addTearDown(fuente.cerrar);
      final contenedor = ProviderContainer(
        overrides: [fuenteConectividadProvider.overrideWithValue(fuente)],
      );
      addTearDown(contenedor.dispose);
      contenedor.listen(hayRedProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);
      expect(contenedor.read(hayRedProvider), isTrue);
      fuente.poner(false);
      await Future<void>.delayed(Duration.zero);
      expect(contenedor.read(hayRedProvider), isFalse);
      fuente.poner(true);
      await Future<void>.delayed(Duration.zero);
      expect(contenedor.read(hayRedProvider), isTrue);
    });

    test('si arranca sin red, lo dice en cuanto responde la fuente', () async {
      final fuente = FuenteConectividadFalsa(hayRed: false);
      addTearDown(fuente.cerrar);
      final contenedor = ProviderContainer(
        overrides: [fuenteConectividadProvider.overrideWithValue(fuente)],
      );
      addTearDown(contenedor.dispose);
      contenedor.listen(hayRedProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);
      expect(contenedor.read(hayRedProvider), isFalse);
    });
  });

  group('estadoConexionProvider con la cola', () {
    test('sin red y con registros por subir dice "N por subir"', () async {
      final fuente = FuenteConectividadFalsa(hayRed: false);
      final base = BaseLocal.enMemoria();
      addTearDown(fuente.cerrar);
      addTearDown(base.close);
      final contenedor = ProviderContainer(
        overrides: [
          fuenteConectividadProvider.overrideWithValue(fuente),
          baseLocalProvider.overrideWithValue(base),
        ],
      );
      addTearDown(contenedor.dispose);
      contenedor.listen(estadoConexionProvider, (_, _) {});
      final cola = contenedor.read(colaSinConexionProvider);
      await cola.encolar(tipo: 'prueba.registro', carga: {'x': 1}, personaId: 'ana');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      var resumen = contenedor.read(estadoConexionProvider);
      expect(resumen.hayRed, isFalse);
      expect(resumen.porSubir, 1);
      expect(resumen.estado, EstadoConexion.porSubir);
      fuente.poner(true);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      resumen = contenedor.read(estadoConexionProvider);
      expect(resumen.enLinea, isTrue);
    });
  });

  group('FuenteConectividadPlus', () {
    test('hay red si alguna conexión no es "ninguna"', () async {
      final sim = _ConectividadSimulada([ConnectivityResult.wifi]);
      expect(await FuenteConectividadPlus(sim).hayRed(), isTrue);
      sim.actual = [ConnectivityResult.none];
      expect(await FuenteConectividadPlus(sim).hayRed(), isFalse);
      sim.actual = [ConnectivityResult.none, ConnectivityResult.vpn];
      expect(await FuenteConectividadPlus(sim).hayRed(), isTrue);
    });

    test('si el sistema no responde, no afirma que no hay red', () async {
      final sim = _ConectividadSimulada([])..falla = true;
      expect(await FuenteConectividadPlus(sim).hayRed(), isTrue);
    });

    test('los cambios llegan como sí/no y sin repetirse', () async {
      final sim = _ConectividadSimulada([])
        ..cambiosDeRed.addAll([
          [ConnectivityResult.wifi],
          [ConnectivityResult.mobile],
          [ConnectivityResult.none],
          [ConnectivityResult.none],
          [ConnectivityResult.ethernet],
        ]);
      expect(
        await FuenteConectividadPlus(sim).cambios.toList(),
        [true, false, true],
      );
    });
  });
}
