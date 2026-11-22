/// Abre la conversación con GRAVITY en una hoja (teléfono, tablet y laptop):
/// el mismo [PanelConversacion] de la pantalla principal, con el mismo filtro
/// de D3 (el servidor oculta cifras de dinero y de salud antes de mandar nada
/// a la IA), el mismo envío con un toque explícito y los mismos avisos cuando
/// el servidor no tiene clave de IA.
///
/// La **voz** (hablar y que te conteste) todavía no existe; esto es la
/// conversación por texto, con dictado donde el teléfono lo permite.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/sesion_efectiva.dart';
import 'panel_conversacion.dart';

export 'panel_conversacion.dart' show rolesQueConversan;

/// Mensaje de quien no conversa con GRAVITY (la cuenta Casa y la cuidadora,
/// D5 y D18): el servidor responde 403 `rol_sin_conversacion` con lo mismo.
const mensajeSinConversacion =
    'Esta cuenta no conversa con GRAVITY. Entra con tu PIN o tu cuenta para '
    'escribirle.';

/// Abre la conversación. Si la persona en pantalla no conversa con GRAVITY,
/// lo dice en un aviso en vez de abrir un panel vacío.
Future<void> abrirConversacionGravity(BuildContext context) {
  final contenedor = ProviderScope.containerOf(context, listen: false);
  final rol = contenedor.read(rolEfectivoProvider);
  if (rol == null || !rolesQueConversan.contains(rol)) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text(mensajeSinConversacion)));
    return Future.value();
  }
  final router = GoRouter.maybeOf(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (contexto) => Padding(
      key: const ValueKey('hoja-conversacion'),
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(contexto).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Conversación con GRAVITY',
                style: Theme.of(contexto).textTheme.titleLarge,
              ),
            ),
            PanelConversacion(
              compacto: true,
              // Si el asistente elige abrir una pantalla, la hoja se cierra.
              navegar: (ruta) {
                Navigator.of(contexto).pop();
                router?.go(ruta);
              },
            ),
          ],
        ),
      ),
    ),
  );
}
