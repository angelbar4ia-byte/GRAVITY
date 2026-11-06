/// Cascarón del teléfono: app normal con barra inferior según el rol
/// (`DISENO_UX_UI.md`, sección 9).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../navegacion.dart';
import '../pantallas/hoja_registrar.dart';
import '../pantallas/registros_atencion.dart';
import '../sesion_efectiva.dart';

class CascaronTelefono extends ConsumerWidget {
  const CascaronTelefono({
    super.key,
    required this.ubicacion,
    required this.child,
  });

  final String ubicacion;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rol = ref.watch(rolEfectivoProvider);
    if (rol == null) return child;
    final esMaestra = ref.watch(esCuentaMaestraProvider);
    final destinos = destinosDe(rol, esMaestra: esMaestra);
    final cuerpo = ConAvisoAtencion(child: child);
    if (destinos.length < 2) return Scaffold(body: cuerpo);
    return Scaffold(
      body: cuerpo,
      bottomNavigationBar: NavigationBar(
        selectedIndex: indiceDestino(ubicacion, destinos) ?? 0,
        onDestinationSelected: (indice) {
          final destino = destinos[indice];
          if (destino.esRegistrar) {
            mostrarHojaRegistrar(context, rol, esMaestra: esMaestra);
          } else if (destino.ruta != null) {
            context.go(destino.ruta!);
          }
        },
        destinations: [
          for (final destino in destinos)
            NavigationDestination(
              icon: Icon(destino.icono, size: destino.esRegistrar ? 36 : 24),
              label: destino.etiqueta,
              tooltip: destino.esRegistrar ? 'Registrar (+)' : null,
            ),
        ],
      ),
    );
  }
}
