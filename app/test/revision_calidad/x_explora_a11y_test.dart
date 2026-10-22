import 'package:finanzas_dominio/finanzas_dominio.dart' hide Semaforo, formatearCentavos, puntosBaseEnCien;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gravity/app/app_gravity.dart';
import 'package:gravity/app/router.dart';
import 'package:gravity/modulos/finanzas/datos/demostracion.dart';
import 'package:gravity/modulos/finanzas/datos/repositorio_memoria.dart';
import 'package:gravity/modulos/finanzas/estado/proveedores.dart';
import 'package:gravity/modulos/finanzas/finanzas.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/contratos/rutas.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_demostracion.dart';
import 'package:gravity/nucleo/sesion/sesion.dart';

import '../app/ayuda_plataforma.dart';
import '../modulos/finanzas/ayuda_finanzas.dart';

GoRouter _router(WidgetTester t) =>
    ProviderScope.containerOf(t.element(find.byType(AppGravity))).read(routerProvider);

Future<void> _ir(WidgetTester t, String ruta) async {
  _router(t).go(ruta);
  await t.pumpAndSettle();
}

void main() {
  final dueno = sesionDe(Rol.dueno);
  for (final escala in [1.0, 2.0]) {
    for (final dispositivo in [TipoDispositivo.telefono, TipoDispositivo.laptop]) {
      testWidgets('explora $dispositivo x$escala', (tester) async {
        final base = repositorioDe(dueno);
        final datos = base.datos;
        final largo = 'Gastos de la casa de los abuelos y primos de la familia extendida 2026';
        final libros = [
          for (final l in datos.libros)
            Libro(
              id: l.id,
              nombre: l.tipo == TipoLibro.compartido ? largo : l.nombre,
              tipo: l.tipo,
              titularId: l.titularId,
              activo: l.activo,
              miembros: l.miembros,
            ),
        ];
        final repo = RepositorioFinanzasEnMemoria(
          datos: datos.copiar(libros: libros),
          personaId: dueno.persona.id,
          personas: personasDeDemostracion(),
          adultosConFinanzas: adultosDeEjemplo,
        );
        addTearDown(repo.cerrar);
        tester.platformDispatcher.textScaleFactorTestValue = escala;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await montarApp(
          tester,
          dispositivo: dispositivo,
          sesion: ServicioSesionDemostracion(inicial: dueno),
          extras: [repositorioFinanzasProvider.overrideWithValue(repo)],
        );
        final rutas = dispositivo == TipoDispositivo.laptop
            ? [for (final s in SeccionFinanzas.values) s.ruta]
            : [Rutas.finanzas, SeccionFinanzas.movimientos.ruta];
        final original = FlutterError.onError;
        final vistos = <String>{};
        String ruta0 = '';
        FlutterError.onError = (d) {
          final linea = d.exception.toString().split('\n').first;
          final marco = d.stack?.toString().split('\n').firstWhere((l) => l.contains('package:gravity'), orElse: () => '-') ?? '-';
          final clave = '$linea @ $ruta0 | $marco';
          if (vistos.add(clave)) {
            // ignore: avoid_print
            print('HALLAZGO[$dispositivo x$escala] $clave');
          }
        };
        addTearDown(() => FlutterError.onError = original);
        for (final ruta in rutas) {
          ruta0 = ruta;
          await _ir(tester, ruta);
        }
      });
    }
  }
}
