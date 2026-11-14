import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/diseno/diseno.dart';

import 'ayuda_pruebas.dart';

void main() {
  testWidgets('cada estado dice su texto y lleva un icono distinto', (
    tester,
  ) async {
    final iconos = <IconData>{};
    for (final estado in EstadoConexion.values) {
      await montar(tester, Center(child: IndicadorConexion(estado: estado)));
      expect(find.text(estado.texto), findsOneWidget);
      expect(find.byIcon(estado.icono), findsOneWidget);
      iconos.add(estado.icono);
    }
    expect(iconos.length, EstadoConexion.values.length);
  });

  testWidgets('muestra los registros por subir y lo anuncia al lector', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await montar(
      tester,
      const Center(
        child: IndicadorConexion(
          estado: EstadoConexion.sinConexion,
          pendientes: 3,
        ),
      ),
    );
    expect(find.text('Sin conexión · 3 por subir'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Estado: Sin conexión · 3 por subir'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('se conecta al proveedor de conectividad de plataforma', (
    tester,
  ) async {
    await montar(
      tester,
      const Center(child: IndicadorConexionConectado()),
      overrides: [
        conectividadProvider.overrideWithValue(
          const EstadoConectividad(EstadoConexion.sincronizando, pendientes: 2),
        ),
      ],
    );
    expect(find.text('Sincronizando · 2 por subir'), findsOneWidget);
  });
}
