/// Puntos de conexión con lo que construyen otros agentes.
///
/// Integrado por el arquitecto (Fase 0): cada función devuelve la pantalla real
/// del agente dueño. Para cambiar una conexión, cambia solo este archivo.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../diseno/diseno.dart';
import '../modulos/ajustes/desarrollador/pantalla_desarrollador.dart';
import '../modulos/gravity/ordenes/barra_ordenes.dart';
import '../modulos/gravity/pantalla/hoy_telefono.dart';
import '../modulos/gravity/pantalla/pantalla_principal.dart';
import '../nucleo/contratos/roles.dart';

/// Pantalla principal de GRAVITY en la laptop (agente diseno).
Widget pantallaPrincipalGravity({Widget? barraOrdenes}) =>
    PantallaPrincipalGravity(barraOrdenes: barraOrdenes);

/// "Hoy" del teléfono y de la tablet por persona (agente diseno).
Widget pantallaHoyTelefono() => const PantallaHoyTelefono();

/// Barra de órdenes de navegación (agente asistente).
Widget barraOrdenes({
  required Rol rol,
  required void Function(String ruta) onNavegar,
}) => BarraOrdenes(rol: rol, onNavegar: onNavegar);

/// Ajustes › Desarrollador (agente asistente).
Widget pantallaDesarrollador() => const PantallaDesarrollador();

/// Estilo, claro/oscuro y personalidad para Ajustes › Apariencia (agente diseno).
Widget? seccionApariencia() => const SeccionApariencia();

/// Tema de la app.
class TemaExterno {
  const TemaExterno({
    required this.claro,
    required this.oscuro,
    this.modo = ThemeMode.system,
    this.duracion = kThemeAnimationDuration,
  });

  final ThemeData claro;
  final ThemeData oscuro;
  final ThemeMode modo;
  final Duration duracion;
}

/// Tema de la app (agente diseno: sistema de estilos, claro/oscuro por hora).
TemaExterno temaExterno(WidgetRef ref) => TemaExterno(
  claro: ref.watch(temaClaroProvider),
  oscuro: ref.watch(temaOscuroProvider),
  modo: ref.watch(modoTemaProvider),
  duracion: duracionCambioTema,
);
