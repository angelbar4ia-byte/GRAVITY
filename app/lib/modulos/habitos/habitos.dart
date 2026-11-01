/// Módulo **Hábitos** de GRAVITY (agente habitos, Fase 3).
///
/// Lo que la plataforma conecta en `app/lib/app/pantallas_externas.dart`:
///
/// - [rutasHabitos]: rutas **relativas** a `/habitos` (raíz = Hoy; `objetivos`
///   y `pausa`).
/// - [hojaPausa]: el SOS como pantalla completa (atajo y botón del (+)).
/// - [servicioHabitosProvider], [hoyHabitosProvider] y
///   [repositorioHabitosProvider]: estado.
/// - [consultaLocalHabitos]: texto discreto para `habitos.resumen_hoy`
///   (nunca incluye hábitos sensibles ni sale del equipo, D3/D13).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'estado/proveedores.dart';
import 'pantallas/hoy.dart';
import 'pantallas/objetivos.dart';
import 'pantallas/pausa.dart';

export 'cifrado/cifrador_real.dart' show CifradorReal;
export 'cifrado/frase.dart' show fraseValida, generarFrase, listaDePalabras;
export 'cifrado/llaves.dart' show desenvolverLlave, envolverLlave;
export 'estado/proveedores.dart'
    show hoyHabitosProvider, repositorioHabitosProvider, servicioHabitosProvider;

Page<void> Function(BuildContext, GoRouterState) _pagina(
        Widget Function(BuildContext) b) =>
    (context, state) => NoTransitionPage<void>(key: state.pageKey, child: b(context));

List<RouteBase> rutasHabitos() => [
      GoRoute(path: '/', pageBuilder: _pagina((_) => const PantallaHoyHabitos())),
      GoRoute(path: 'objetivos', pageBuilder: _pagina((_) => const PantallaObjetivos())),
      GoRoute(path: 'pausa', pageBuilder: _pagina((_) => const PantallaPausa())),
    ];

Widget hojaPausa() => const PantallaPausa();

/// Respuesta de `habitos.resumen_hoy` (solo lo no sensible).
final consultaLocalHabitos = FutureProvider<String>(
    (ref) => ref.watch(servicioHabitosProvider).resumenHoy());
