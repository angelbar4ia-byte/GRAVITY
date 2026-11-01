import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/sesion/proveedores_sesion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_falso.dart';
import 'package:gravity/modulos/habitos/casos_uso/servicio_habitos.dart';
import 'package:gravity/modulos/habitos/datos/repositorio.dart';
import 'package:gravity/modulos/habitos/estado/proveedores.dart';
import 'package:gravity/modulos/habitos/pantallas/hoy.dart';

void main() {
  testWidgets('Hoy vacío ofrece crear un objetivo y siempre hay Pausa', (t) async {
    final repo = RepositorioHabitosEnMemoria();
    await t.pumpWidget(ProviderScope(
      overrides: [
        servicioSesionProvider.overrideWithValue(ServicioSesionFalso()),
        repositorioHabitosProvider.overrideWithValue(repo),
        servicioHabitosProvider.overrideWithValue(ServicioHabitos(repo)),
      ],
      child: const MaterialApp(home: _Cuerpo()),
    ));
    await t.pumpAndSettle();
    expect(find.text('Pausa'), findsWidgets);
  });
}

class _Cuerpo extends StatelessWidget {
  const _Cuerpo();
  @override
  Widget build(BuildContext context) => const PantallaHoyHabitos();
}
