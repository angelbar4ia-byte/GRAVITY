// I10 (revisión de calidad, Fase 1): una carga fallida de Finanzas se queda en
// "Cargando Finanzas…" unos 40 segundos antes de mostrar el error o el aviso
// de "sin conexión".
//
// Riverpod 3 reintenta solo los proveedores que fallan (hasta 10 veces, con
// espera creciente de 200 ms a 6.4 s) y mientras reintenta el estado es de
// carga. Nadie configura `retry` (ni en el `ProviderScope` ni en
// `cargaFinanzasProvider`). Sin señal y sin copia local (primer uso, o la
// persona acaba de entrar en un teléfono nuevo) la persona ve el círculo
// girando casi un minuto y el servidor recibe 11 consultas iguales.
// `ErrorFinanzas.conexion` ya dice si se puede reintentar a mano: el botón
// "Reintentar" existe.
//
// Resuelto (sin etiqueta `hallazgo`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/finanzas/datos/repositorio.dart';
import 'package:gravity/modulos/finanzas/datos/repositorio_memoria.dart';
import 'package:gravity/modulos/finanzas/estado/proveedores.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/contratos/rutas.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_demostracion.dart';

import '../app/ayuda_plataforma.dart';
import '../modulos/finanzas/ayuda_finanzas.dart';
import 'ayuda_calidad.dart' show irA;

class _RepoSinSenal extends RepositorioFinanzasEnMemoria {
  int intentos = 0;

  @override
  Future<CargaFinanzas> cargar() async {
    intentos++;
    throw ErrorFinanzas.conexion;
  }
}

void main() {
  testWidgets(
    'sin señal ni copia: a los 3 segundos ya dice "sin conexión" y no insiste',
    (tester) async {
      final repo = _RepoSinSenal();
      addTearDown(repo.cerrar);
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.telefono,
        sesion: ServicioSesionDemostracion(inicial: sesionDe(Rol.dueno)),
        extras: [repositorioFinanzasProvider.overrideWithValue(repo)],
      );
      await irA(tester, Rutas.finanzas);
      await tester.pump(const Duration(seconds: 3));

      expect(
        find.byKey(const ValueKey('finanzas-sin-conexion')),
        findsOneWidget,
        reason:
            'sigue en "Cargando Finanzas…" (${repo.intentos} intentos ya): '
            'falta `retry: (_, _) => null` en cargaFinanzasProvider',
      );
      expect(repo.intentos, lessThanOrEqualTo(2));
    },
  );
}
