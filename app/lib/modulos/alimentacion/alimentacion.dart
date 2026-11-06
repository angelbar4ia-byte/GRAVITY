/// Módulo **Alimentación** de GRAVITY (agente alimentacion, Fase 4, versión
/// mínima): menú de la semana y lista de compras.
///
/// [rutasAlimentacion]: rutas **relativas** a `/alimentacion` (raíz = menú;
/// `compras`). Sin dinero, sin datos clínicos, sin IA. Contrato del servidor:
/// `docs/specs/fase-4-alimentacion.md`, sección 6.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'pantallas/compras.dart';
import 'pantallas/menu.dart';

export 'estado/proveedores.dart'
    show repositorioAlimentacionProvider, servicioAlimentacionProvider;

Page<void> Function(BuildContext, GoRouterState) _pagina(Widget Function() b) =>
    (context, state) => NoTransitionPage<void>(key: state.pageKey, child: b());

List<RouteBase> rutasAlimentacion() => [
  GoRoute(path: '/', pageBuilder: _pagina(() => const PantallaMenuSemana())),
  GoRoute(
    path: 'compras',
    pageBuilder: _pagina(() => const PantallaListaCompras()),
  ),
];
