// D27: el fondo del estilo cubre toda la app (no solo Hoy), la apariencia
// elegida se guarda con el almacén persistente y el indicador de conexión de
// diseño sale de la conectividad real.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/conectividad_diseno.dart';
import 'package:gravity/app/router.dart';
import 'package:gravity/diseno/componentes/fondo_estilo.dart';
import 'package:gravity/diseno/componentes/indicador_conexion.dart' as diseno;
import 'package:gravity/diseno/estilos/glass.dart';
import 'package:gravity/diseno/proveedores.dart';
import 'package:gravity/nucleo/conectividad/conectividad.dart' as real;
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/contratos/rutas.dart';

import 'ayuda_plataforma.dart';

ProviderContainer contenedorDe(WidgetTester t) =>
    ProviderScope.containerOf(t.element(find.byType(MaterialApp)));

void main() {
  testWidgets('el fondo del estilo va detrás de todas las pantallas y en Glass '
      'el fondo de la pantalla es transparente', (tester) async {
    await montarApp(
      tester,
      dispositivo: TipoDispositivo.telefono,
      sesion: sesionCon(Rol.dueno),
    );
    expect(find.byType(FondoEstilo), findsWidgets);
    contenedorDe(tester).read(estiloProvider.notifier).elegir(estiloGlass);
    await tester.pumpAndSettle();
    // Otro módulo que no es Hoy: Ajustes.
    contenedorDe(tester).read(routerProvider).go(Rutas.ajustes);
    await tester.pumpAndSettle();
    expect(find.byType(FondoEstilo), findsWidgets);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    final color = scaffold.backgroundColor ??
        Theme.of(tester.element(find.byType(Scaffold).first)).scaffoldBackgroundColor;
    expect(color, Colors.transparent);
  });

  test('conectividad real → indicador de diseño', () {
    ProviderContainer con(bool hayRed, int porSubir) => ProviderContainer(
      overrides: [
        real.estadoConexionProvider.overrideWithValue(
          real.ResumenConexion(hayRed: hayRed, porSubir: porSubir),
        ),
      ],
    );
    diseno.EstadoConectividad de(bool red, int n) {
      final c = con(red, n);
      addTearDown(c.dispose);
      return c.read(conectividadRealDeDisenoProvider);
    }

    expect(de(true, 0), const diseno.EstadoConectividad(diseno.EstadoConexion.enLinea));
    expect(
      de(true, 3),
      const diseno.EstadoConectividad(diseno.EstadoConexion.sincronizando, pendientes: 3),
    );
    expect(
      de(false, 0),
      const diseno.EstadoConectividad(diseno.EstadoConexion.sinConexion),
    );
    expect(
      de(false, 2),
      const diseno.EstadoConectividad(diseno.EstadoConexion.sinConexion, pendientes: 2),
    );
  });
}
