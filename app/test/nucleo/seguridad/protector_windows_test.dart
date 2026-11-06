// Bloqueo de capturas en Windows (E15, P7 del dueño, D22): activo por omisión,
// editable en Ajustes › Privacidad.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/dispositivo.dart';
import 'package:gravity/modulos/ajustes/privacidad/pantalla_privacidad.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';
import 'package:gravity/nucleo/seguridad/pantalla_segura.dart';
import 'package:gravity/nucleo/seguridad/protector_windows.dart';
import 'package:gravity/nucleo/seguridad/proveedores_seguridad.dart';
import 'package:gravity/nucleo/sesion/proveedores_sesion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_falso.dart';

void main() {
  group('ProtectorDePantallaWindows', () {
    test('protege con "excluir de la captura" y quita al soltar', () async {
      final llamadas = <int>[];
      final p = ProtectorDePantallaWindows(
        aplicar: (a) {
          llamadas.add(a);
          return true;
        },
      );
      await p.establecer(segura: true);
      await p.establecer(segura: false);
      expect(llamadas, [wdaExcluirDeCaptura, wdaNinguna]);
    });

    test('en un Windows viejo cae a "monitor" (sale en negro)', () async {
      final llamadas = <int>[];
      final p = ProtectorDePantallaWindows(
        aplicar: (a) {
          llamadas.add(a);
          return a != wdaExcluirDeCaptura;
        },
      );
      await p.establecer(segura: true);
      expect(llamadas, [wdaExcluirDeCaptura, wdaMonitor]);
    });

    test('un fallo nativo no tira la app', () async {
      final p = ProtectorDePantallaWindows(
        aplicar: (_) => throw StateError('sin user32'),
      );
      await p.establecer(segura: true);
    });
  });

  group('con el ajuste', () {
    late AlmacenSeguroEnMemoria almacen;
    late List<bool> aplicadas;

    ProviderContainer contenedor() {
      final c = ProviderContainer(
        overrides: [
          almacenSeguroProvider.overrideWithValue(almacen),
          protectorDePantallaProvider.overrideWithValue(
            ProtectorDePantallaWindows(
              aplicar: (a) {
                aplicadas.add(a != wdaNinguna);
                return true;
              },
            ),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    setUp(() {
      almacen = AlmacenSeguroEnMemoria();
      aplicadas = [];
    });

    test('activo por omisión', () async {
      final c = contenedor();
      expect(c.read(capturasBloqueadasProvider), isTrue);
      final controlador = c.read(controladorPantallaSeguraProvider);
      final soltar = controlador.pedir();
      await controlador.aplicado;
      expect(aplicadas, [true]);
      soltar();
      await controlador.aplicado;
      expect(aplicadas, [true, false]);
    });

    test('apagado no protege nada, y se recuerda', () async {
      final c = contenedor();
      c.listen(capturasBloqueadasProvider, (_, _) {});
      await c.read(capturasBloqueadasProvider.notifier).fijar(false);
      final controlador = c.read(controladorPantallaSeguraProvider);
      controlador.pedir();
      await controlador.aplicado;
      expect(aplicadas, isEmpty);
      // Otro arranque: lee lo guardado.
      final otro = contenedor();
      otro.listen(capturasBloqueadasProvider, (_, _) {});
      await otro.read(capturasBloqueadasProvider.notifier).listo;
      expect(otro.read(capturasBloqueadasProvider), isFalse);
    });

    test('apagarlo con la pantalla ya protegida la desprotege al instante', () async {
      final c = contenedor();
      c.listen(capturasBloqueadasProvider, (_, _) {});
      final controlador = c.read(controladorPantallaSeguraProvider);
      controlador.pedir();
      await controlador.aplicado;
      expect(aplicadas, [true]);
      await c.read(capturasBloqueadasProvider.notifier).fijar(false);
      await controlador.aplicado;
      expect(aplicadas, [true, false]);
      await c.read(capturasBloqueadasProvider.notifier).fijar(true);
      await controlador.aplicado;
      expect(aplicadas, [true, false, true]);
    });
  });

  testWidgets('Privacidad en la laptop ofrece apagar el bloqueo; el teléfono no', (
    tester,
  ) async {
    Future<void> montar(TipoDispositivo d) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tipoDispositivoProvider.overrideWithValue(d),
            almacenSeguroProvider.overrideWithValue(AlmacenSeguroEnMemoria()),
            servicioSesionProvider.overrideWithValue(
              ServicioSesionFalso.con(Rol.dueno),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: PantallaPrivacidad())),
        ),
      );
      await tester.pumpAndSettle();
    }

    await montar(TipoDispositivo.telefono);
    expect(find.byKey(const ValueKey('privacidad-capturas')), findsNothing);
    await montar(TipoDispositivo.laptop);
    final interruptor = find.byKey(const ValueKey('privacidad-capturas'));
    expect(interruptor, findsOneWidget);
    expect(tester.widget<SwitchListTile>(interruptor).value, isTrue);
    await tester.tap(interruptor);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(interruptor).value, isFalse);
  });
}
