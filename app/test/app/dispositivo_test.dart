import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/dispositivo.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';

void main() {
  group('detectarTipoDispositivo', () {
    test('Windows es la laptop, sin importar el tamaño', () {
      for (final tamano in const [Size(360, 640), Size(1920, 1080)]) {
        expect(
          detectarTipoDispositivo(
            plataforma: TargetPlatform.windows,
            tamanoLogico: tamano,
          ),
          TipoDispositivo.laptop,
        );
      }
    });

    test('Android con lado corto de 600 dp o más es tablet', () {
      expect(
        detectarTipoDispositivo(
          plataforma: TargetPlatform.android,
          tamanoLogico: const Size(1280, 800),
        ),
        TipoDispositivo.tablet,
      );
      // Vertical: el lado corto sigue siendo 800.
      expect(
        detectarTipoDispositivo(
          plataforma: TargetPlatform.android,
          tamanoLogico: const Size(800, 1280),
        ),
        TipoDispositivo.tablet,
      );
      expect(
        detectarTipoDispositivo(
          plataforma: TargetPlatform.android,
          tamanoLogico: const Size(600, 960),
        ),
        TipoDispositivo.tablet,
      );
    });

    test('Android con lado corto menor a 600 dp es teléfono', () {
      expect(
        detectarTipoDispositivo(
          plataforma: TargetPlatform.android,
          tamanoLogico: const Size(599, 1200),
        ),
        TipoDispositivo.telefono,
      );
      expect(
        detectarTipoDispositivo(
          plataforma: TargetPlatform.android,
          tamanoLogico: const Size(915, 412),
        ),
        TipoDispositivo.telefono,
      );
      expect(
        detectarTipoDispositivo(
          plataforma: TargetPlatform.android,
          tamanoLogico: Size.zero,
        ),
        TipoDispositivo.telefono,
      );
    });

    test('Linux y macOS (desarrollo) se tratan como laptop', () {
      for (final plataforma in [TargetPlatform.linux, TargetPlatform.macOS]) {
        expect(
          detectarTipoDispositivo(
            plataforma: plataforma,
            tamanoLogico: const Size(400, 800),
          ),
          TipoDispositivo.laptop,
        );
      }
    });
  });

  test('tipoDispositivoForzado interpreta GRAVITY_DISPOSITIVO', () {
    expect(tipoDispositivoForzado('tablet'), TipoDispositivo.tablet);
    expect(tipoDispositivoForzado(' Telefono '), TipoDispositivo.telefono);
    expect(tipoDispositivoForzado('teléfono'), TipoDispositivo.telefono);
    expect(tipoDispositivoForzado('laptop'), TipoDispositivo.laptop);
    expect(tipoDispositivoForzado(''), isNull);
    expect(tipoDispositivoForzado('reloj'), isNull);
  });
}
