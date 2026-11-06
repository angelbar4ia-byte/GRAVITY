/// Cascarón de la laptop (Windows): el contenido ocupa toda la pantalla.
/// Atajos (`DISENO_UX_UI.md`, sección 15): Esc vuelve a GRAVITY,
/// Ctrl + 1 a 5 abren cada módulo que el rol puede ver y Ctrl + N registra
/// un movimiento de Finanzas (solo quien escribe en Finanzas).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../nucleo/contratos/rutas.dart';
import '../../nucleo/permisos/permisos.dart';
import '../../nucleo/contratos/roles.dart';
import '../navegacion.dart';
import '../pantallas/registro_rapido.dart';
import '../pantallas/registros_atencion.dart';
import '../sesion_efectiva.dart';

class CascaronLaptop extends ConsumerWidget {
  const CascaronLaptop({super.key, required this.child});

  final Widget child;

  static const _teclas = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rol = ref.watch(rolEfectivoProvider);
    final esMaestra = ref.watch(esCuentaMaestraProvider);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            context.go(Rutas.inicio),
        if (rol != null)
          for (var i = 0; i < modulosDeTrabajo.length; i++)
            if (puedeAbrir(rol, modulosDeTrabajo[i]))
              SingleActivator(_teclas[i], control: true): () =>
                  context.go(rutaDeModulo(modulosDeTrabajo[i])),
        if (rol != null &&
            puedeRegistrarEn(rol, Modulo.finanzas, esMaestra: esMaestra))
          const SingleActivator(LogicalKeyboardKey.keyN, control: true): () =>
              abrirRegistroEnDialogo(context),
      },
      child: Focus(
        autofocus: true,
        child: ConAvisoAtencion(child: child),
      ),
    );
  }
}
