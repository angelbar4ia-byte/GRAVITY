/// Puntos de conexión con lo que construyen otros agentes.
///
/// Integrado por el arquitecto (Fase 0): cada función devuelve la pantalla real
/// del agente dueño. Para cambiar una conexión, cambia solo este archivo.
///
/// Fase 1: Finanzas ya está conectado (`modulos/finanzas/finanzas.dart`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:go_router/go_router.dart';

import '../diseno/diseno.dart';
import '../modulos/ajustes/desarrollador/pantalla_desarrollador.dart';
import '../modulos/gravity/ordenes/barra_ordenes.dart';
import '../modulos/gravity/pantalla/hoy_telefono.dart';
import '../modulos/gravity/pantalla/pantalla_principal.dart';
import '../modulos/finanzas/finanzas.dart' as finanzas;
import '../modulos/habitos/habitos.dart' as habitos;
import '../nucleo/contratos/dispositivo.dart';
import '../nucleo/contratos/roles.dart';

/// Pantalla principal de GRAVITY en la laptop (agente diseno).
Widget pantallaPrincipalGravity({Widget? barraOrdenes}) =>
    PantallaPrincipalGravity(barraOrdenes: barraOrdenes);

/// "Hoy" del teléfono y de la tablet por persona (agente diseno).
Widget pantallaHoyTelefono() => const PantallaHoyTelefono();

/// Barra de órdenes de navegación (agente asistente). Con el [dispositivo]
/// solo sugiere destinos que existen en él (Desarrollador, solo en la laptop;
/// revisión de la Fase 0, M6).
Widget barraOrdenes({
  required Rol rol,
  required void Function(String ruta) onNavegar,
  TipoDispositivo? dispositivo,
}) => BarraOrdenes(rol: rol, onNavegar: onNavegar, dispositivo: dispositivo);

/// Ajustes › Desarrollador (agente asistente).
Widget pantallaDesarrollador() => const PantallaDesarrollador();

/// Estilo, claro/oscuro y personalidad para Ajustes › Apariencia (agente diseno).
Widget? seccionApariencia() => const SeccionApariencia();

// ---------------------------------------------------------------------------
// Finanzas (agente finanzas, Fase 1): `app/lib/modulos/finanzas/finanzas.dart`.
// ---------------------------------------------------------------------------

/// Rutas de Finanzas, **relativas** a `Rutas.finanzas`. La pantalla de inicio
/// del módulo es la ruta raíz, `GoRoute(path: '/', …)`; las demás van con
/// segmentos relativos (`'semana'`, `'movimientos'`, …), a su lado o debajo
/// de la raíz. El router monta la raíz en `/finanzas` y lo demás debajo
/// (`montarRutasDeModulo`, en `router.dart`), dentro del cascarón: en la
/// laptop a pantalla completa y en el teléfono en la pestaña Finanzas.
///
/// El router ya deja fuera a familiar, cuidador y casa en cualquier ruta bajo
/// `/finanzas`. Las rutas que además de leer exigen administrar (asistente
/// de arranque, importar y ajustes de Finanzas) llevan
/// `metadata: exigeAccion(Accion.administrar)` de
/// `nucleo/permisos/permisos.dart`. Desde D19 el coadministrador administra
/// su libro; lo ajeno (la cuenta maestra) se resuelve en cada pantalla con
/// `puedeSobre`. Las secciones de la laptop regresan al inicio del módulo en
/// el teléfono (D4).
List<RouteBase> rutasFinanzas() => finanzas.rutasFinanzas();

/// Rutas de Hábitos: Hoy en la raíz, más objetivos y pausa (SOS).
List<RouteBase> rutasHabitos() => habitos.rutasHabitos();

/// Registro rápido de un gasto (F1). La plataforma lo muestra en una hoja
/// inferior desde el (+) del teléfono y de la tablet, y en un diálogo con
/// Ctrl + N en la laptop (`pantallas/registro_rapido.dart`). La hoja se
/// cierra sola con `Navigator.pop` al guardar o cancelar, se ajusta al
/// teclado y avisa *"Guardado · Deshacer"*.
Widget hojaRegistrarGasto() => finanzas.hojaRegistrarGasto();

/// Registro de un ingreso extra (monto → cuenta → fecha → Guardar), en una
/// hoja inferior desde el (+), igual que [hojaRegistrarGasto].
Widget hojaIngresoExtra() => finanzas.hojaIngresoExtra();

/// Tabla de Supabase por tipo de registro de la cola sin conexión (p. ej.
/// `'finanzas.movimiento': 'fin_movimientos'`). La cola sube con
/// `INSERT … ON CONFLICT (id) DO NOTHING` y la sesión de quien registró.
const Map<String, String> tablasColaFinanzas = finanzas.tablasColaFinanzas;

/// Fase 2 (D20): lo que Finanzas pone en los avisos de la plataforma, que el
/// arranque suma a los `overrides` de Riverpod: la fuente de vencimientos de
/// los recordatorios locales (`fuenteDeVencimientosProvider`) y el detalle de
/// cada aviso en la bandeja (`detalleDeAvisoProvider`).
List<Override> get sobrescriturasAvisosFinanzas =>
    finanzas.sobrescriturasAvisosFinanzas;

/// Exportar mis datos y recordatorios locales de Hábitos.
List<Override> get sobrescriturasHabitos => habitos.sobrescriturasHabitos;

/// Consultas locales de Finanzas para `ContextoHerramienta.consultaLocal`
/// (`finanzas.resumen_semana`, `finanzas.proximos_pagos`,
/// `finanzas.ahorro_avance`): texto discreto que nunca sale del equipo.
final consultaLocalFinanzasProvider = finanzas.consultaLocalFinanzasProvider;

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
