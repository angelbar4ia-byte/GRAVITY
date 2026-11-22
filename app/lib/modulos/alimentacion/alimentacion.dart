/// Módulo **Alimentación** de GRAVITY (agente alimentacion, Fase 4, versión
/// mínima; Fase 7, primera tanda): menú de la semana, lista de compras por
/// pasillo con precios, recetas por archivo y plan familiar por votación.
///
/// [rutasAlimentacion]: rutas **relativas** a `/alimentacion` (raíz = menú;
/// `compras`, `importar-recetas`, `plan`). Precios en centavos, sin datos
/// clínicos, sin IA. Contrato del servidor:
/// `docs/specs/fase-4-alimentacion.md`, sección 6.
///
/// Para otros módulos expone, con la menor superficie, el menú de Papá en solo
/// lectura ([MenuDePapaSoloLectura], lo usa Cuidados, D23) y la tarjeta del día
/// para Casa ([TarjetaMenuDelDiaPapa]); el perfil clínico sigue pintándose solo
/// desde aquí (D3).
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'pantallas/compras.dart';
import 'pantallas/importar_recetas.dart';
import 'pantallas/plan_familiar.dart';
import 'pantallas/menu.dart';

export 'estado/proveedores.dart'
    show
        consultaLocalAlimentacionProvider,
        repositorioAlimentacionProvider,
        menuDelDiaPapaProvider,
        servicioAlimentacionProvider;

export 'pantallas/menu.dart' show MenuDePapaSoloLectura;
export 'pantallas/menu_del_dia_papa.dart' show TarjetaMenuDelDiaPapa;

Page<void> Function(BuildContext, GoRouterState) _pagina(Widget Function() b) =>
    (context, state) => NoTransitionPage<void>(key: state.pageKey, child: b());

List<RouteBase> rutasAlimentacion() => [
  GoRoute(path: '/', pageBuilder: _pagina(() => const PantallaMenuSemana())),
  GoRoute(
    path: 'compras',
    pageBuilder: _pagina(() => const PantallaListaCompras()),
  ),
  GoRoute(
    path: 'importar-recetas',
    pageBuilder: _pagina(() => const PantallaImportarRecetas()),
  ),
  GoRoute(
    path: 'plan',
    pageBuilder: _pagina(() => const PantallaPlanFamiliar()),
  ),
];
