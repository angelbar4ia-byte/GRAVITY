/// Router (go_router) con las rutas del contrato (`nucleo/contratos/rutas.dart`)
/// y redirecciones por rol con el espejo de permisos.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../modulos/ajustes/pantalla_ajustes.dart';
import '../modulos/ajustes/secciones_ajustes.dart';
import '../nucleo/contratos/roles.dart';
import '../nucleo/contratos/rutas.dart';
import 'cascarones/cascaron.dart';
import 'dispositivo.dart';
import 'navegacion.dart';
import 'pantallas/pantalla_entrar.dart';
import 'pantallas/pantalla_inicio.dart';
import 'pantallas/pantalla_mas.dart';
import 'pantallas/pantalla_proximamente.dart';
import 'sesion_efectiva.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Cada cambio de rol (entrar, salir, PIN en la tablet) vuelve a evaluar
  // las redirecciones.
  final aviso = ValueNotifier<int>(0);
  ref.listen(rolEfectivoProvider, (_, _) => aviso.value++);
  final router = GoRouter(
    initialLocation: Rutas.inicio,
    refreshListenable: aviso,
    redirect: (context, estado) => calcularRedireccion(
      ubicacion: estado.uri.path,
      rol: ref.read(rolEfectivoProvider),
      dispositivo: ref.read(tipoDispositivoProvider),
    ),
    routes: rutasGravity,
    errorBuilder: (context, estado) => const _PantallaNoEncontrada(),
  );
  ref.onDispose(() {
    router.dispose();
    aviso.dispose();
  });
  return router;
});

/// Página sin animación para cambiar de pestaña.
Page<void> _sinAnimacion(GoRouterState estado, Widget pantalla) =>
    NoTransitionPage<void>(key: estado.pageKey, child: pantalla);

GoRoute _modulo(String ruta, Modulo modulo, {List<RouteBase> rutas = const []}) =>
    GoRoute(
      path: ruta,
      pageBuilder: (context, estado) =>
          _sinAnimacion(estado, PantallaProximamente.modulo(modulo)),
      routes: rutas,
    );

GoRoute _cuidados(String segmento, String titulo, IconData icono) => GoRoute(
  path: segmento,
  pageBuilder: (context, estado) => _sinAnimacion(
    estado,
    PantallaProximamente(titulo: titulo, icono: icono, fase: 5),
  ),
);

final List<RouteBase> rutasGravity = [
  GoRoute(
    path: Rutas.entrar,
    builder: (context, estado) => const PantallaEntrar(),
  ),
  ShellRoute(
    builder: (context, estado, child) =>
        CascaronSegunDispositivo(ubicacion: estado.uri.path, child: child),
    routes: [
      GoRoute(
        path: Rutas.inicio,
        pageBuilder: (context, estado) =>
            _sinAnimacion(estado, const PantallaInicio()),
      ),
      _modulo(Rutas.finanzas, Modulo.finanzas),
      _modulo(Rutas.habitos, Modulo.habitos),
      GoRoute(
        path: Rutas.cuidados,
        pageBuilder: (context, estado) => _sinAnimacion(
          estado,
          const PantallaProximamente(
            titulo: 'Mi turno',
            icono: Icons.assignment_ind_outlined,
            fase: 5,
            detalle:
                'Entrega de turno, siguiente medicamento, comidas y gastos '
                'de cuidado.',
          ),
        ),
        routes: [
          _cuidados('medicamentos', 'Medicamentos', Icons.medication_outlined),
          _cuidados('comidas', 'Comidas', Icons.restaurant_outlined),
          _cuidados('bitacora', 'Bitácora', Icons.menu_book_outlined),
        ],
      ),
      _modulo(Rutas.alimentacion, Modulo.alimentacion),
      _modulo(Rutas.casa, Modulo.casa),
      GoRoute(
        path: RutasApp.mas,
        pageBuilder: (context, estado) =>
            _sinAnimacion(estado, const PantallaMas()),
      ),
      GoRoute(
        path: Rutas.ajustes,
        pageBuilder: (context, estado) =>
            _sinAnimacion(estado, const PantallaAjustes()),
        routes: [
          for (final seccion in SeccionAjustes.values)
            GoRoute(
              path: infoSecciones[seccion]!.segmento,
              builder: (context, estado) => pantallaDeSeccion(seccion),
            ),
        ],
      ),
    ],
  ),
];

class _PantallaNoEncontrada extends StatelessWidget {
  const _PantallaNoEncontrada();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('No encontramos esa pantalla.'),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => context.go(Rutas.inicio),
            child: const Text('Ir al inicio'),
          ),
        ],
      ),
    ),
  );
}
