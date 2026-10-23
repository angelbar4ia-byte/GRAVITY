// HALLAZGO I2 (IMPORTANTE) · docs/revisiones/fase-0.md
//
// Prueba de regresión: el hallazgo se resolvió el 20/oct/2026 (docs/revisiones/fase-0.md, sección 11).
// Excluir mientras tanto: flutter test --exclude-tags hallazgo
//
// Los intentos fallidos del PIN de la tablet viven solo en memoria
// (`_fallos` y `_bloqueadoHasta` en ControladorTablet): al cerrar y abrir la
// app se borran. Además la espera es fija (30 s) y no crece: un PIN de 4
// dígitos se recorre en horas, y reiniciando la app, en menos.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';
import 'package:gravity/nucleo/seguridad/proveedores_seguridad.dart';
import 'package:gravity/nucleo/sesion/proveedores_sesion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_demostracion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_falso.dart';
import 'package:gravity/nucleo/tablet/controlador_tablet.dart';

import '../app/ayuda_plataforma.dart';

void main() {
  late AlmacenSeguroEnMemoria almacen;
  late DateTime ahora;
  final dueno = sesionDeEjemplo(Rol.dueno).persona.id;

  /// Abre la app (un contenedor nuevo con el mismo almacén = reiniciar).
  Future<ControladorTablet> abrirApp() async {
    final contenedor = ProviderContainer(
      overrides: [
        almacenSeguroProvider.overrideWithValue(almacen),
        servicioSesionProvider.overrideWithValue(
          ServicioSesionFalso(inicial: sesionDeEjemplo(Rol.casa)),
        ),
        relojSeguridadProvider.overrideWithValue(() => ahora),
      ],
    );
    addTearDown(contenedor.dispose);
    final controlador = contenedor.read(controladorTabletProvider.notifier);
    await controlador.listo;
    return controlador;
  }

  setUp(() async {
    almacen = await almacenConPersonas({Rol.dueno: '246813'});
    ahora = DateTime(2026, 10, 20, 9);
  });

  test('reiniciar la app no borra el bloqueo por intentos fallidos', () async {
    final antes = await abrirApp();
    for (var i = 0; i < ControladorTablet.intentosAntesDeBloquear; i++) {
      antes.desbloquearConPin(dueno, '0000');
    }
    expect(antes.desbloquearConPin(dueno, '1234'), ResultadoDesbloqueo.bloqueado);

    final despues = await abrirApp(); // misma tablet, app reiniciada
    expect(
      despues.desbloquearConPin(dueno, '1234'),
      ResultadoDesbloqueo.bloqueado,
      reason: 'el bloqueo debe sobrevivir al reinicio',
    );
  });

  test('la espera crece si siguen los intentos fallidos', () async {
    final tablet = await abrirApp();
    for (var ronda = 0; ronda < 4; ronda++) {
      for (var i = 0; i < ControladorTablet.intentosAntesDeBloquear; i++) {
        tablet.desbloquearConPin(dueno, '0000');
      }
      ahora = ahora.add(ControladorTablet.duracionBloqueo);
    }
    // Tras 20 intentos fallidos, 30 s después ya no debería bastar.
    expect(
      tablet.desbloquearConPin(dueno, '0000'),
      ResultadoDesbloqueo.bloqueado,
    );
  });
}
