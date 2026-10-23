// HALLAZGO B3 (BLOQUEANTE) · docs/revisiones/fase-0.md
//
// Prueba de regresión: el hallazgo se resolvió el 20/oct/2026 (docs/revisiones/fase-0.md, sección 11).
// Excluir mientras tanto: flutter test --exclude-tags hallazgo
//
// En la tablet compartida, Android acepta cualquier huella registrada en el
// equipo y no dice de quién es (lo reconocen biometria.dart y app/README.md).
// Si el Dueño activa "entrar con huella", cualquier persona con su dedo
// registrado en la tablet (la cuidadora, un hijo) entra como el Dueño y ve
// sus pantallas (dinero desde la Fase 1). D5: "la voz no identifica de forma
// segura a una persona"; la huella del equipo compartido tampoco.
//
// La simulación no distingue dedos, igual que Android: `BiometriaFalsa`
// acepta cualquiera. Lo esperado es que la huella SOLA no abra a una persona
// en la tablet compartida (p. ej., huella + PIN, o sin huella en la tablet).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/seguridad/biometria.dart';
import 'package:gravity/nucleo/seguridad/proveedores_seguridad.dart';
import 'package:gravity/nucleo/sesion/proveedores_sesion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_demostracion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_falso.dart';
import 'package:gravity/nucleo/tablet/controlador_tablet.dart';

import '../app/ayuda_plataforma.dart';

void main() {
  test('una huella cualquiera no abre la sesión del Dueño en la tablet', () async {
    // La cuidadora registró su dedo en la tablet para su propio turno; el
    // Dueño activó la huella para sí.
    final almacen = await almacenConPersonas(
      {Rol.dueno: '1234', Rol.cuidador: '5678'},
      conHuella: {Rol.dueno, Rol.cuidador},
    );
    final dedoDeLaCuidadora = BiometriaFalsa(acepta: true);
    final contenedor = ProviderContainer(
      overrides: [
        almacenSeguroProvider.overrideWithValue(almacen),
        servicioSesionProvider.overrideWithValue(
          ServicioSesionFalso(inicial: sesionDeEjemplo(Rol.casa)),
        ),
        biometriaProvider.overrideWithValue(dedoDeLaCuidadora),
      ],
    );
    addTearDown(contenedor.dispose);
    final controlador = contenedor.read(controladorTabletProvider.notifier);
    await controlador.listo;

    final dueno = sesionDeEjemplo(Rol.dueno).persona.id;
    final resultado = await controlador.desbloquearConHuella(dueno);

    expect(resultado, isNot(ResultadoDesbloqueo.abierto));
    expect(contenedor.read(controladorTabletProvider).usuarioActivo, isNull);
  });
}
