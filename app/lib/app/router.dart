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
import '../nucleo/permisos/permisos.dart';
import 'cascarones/cascaron.dart';
import 'dispositivo.dart';
import 'navegacion.dart';
import 'pantalla_segura.dart';
import 'avisos/pantalla_bandeja_avisos.dart';
import 'pantallas/pantalla_entrar.dart';
import 'pantallas/pantalla_invitacion.dart';
import 'pantallas/pantalla_inicio.dart';
import 'pantallas/pantalla_mas.dart';
import 'pantallas/pantalla_proximamente.dart';
import 'pantallas/pantalla_solicitudes.dart';
import 'pantallas/registros_atencion.dart';
import 'pantallas_externas.dart';
import 'sesion_efectiva.dart';

/// Rutas de Finanzas (agente finanzas, `pantallas_externas.dart`). Las pruebas
/// la sustituyen para revisar los permisos con rutas de ejemplo.
final rutasFinanzasProvider = Provider<List<RouteBase>>(
  (ref) => rutasFinanzas(),
);

/// Rutas de Hábitos (agente habitos, `pantallas_externas.dart`).
final rutasHabitosProvider = Provider<List<RouteBase>>((ref) => rutasHabitos());

final routerProvider = Provider<GoRouter>((ref) {
  // Cada cambio de rol (entrar, salir, PIN en la tablet) vuelve a evaluar
  // las redirecciones.
  final aviso = ValueNotifier<int>(0);
  ref.listen(rolEfectivoProvider, (_, _) => aviso.value++);
  ref.listen(esCuentaMaestraProvider, (_, _) => aviso.value++);
  final router = GoRouter(
    initialLocation: Rutas.inicio,
    refreshListenable: aviso,
    redirect: (context, estado) => calcularRedireccion(
      ubicacion: estado.uri.path,
      rol: ref.read(rolEfectivoProvider),
      dispositivo: ref.read(tipoDispositivoProvider),
      accion: accionExigida(estado.metadata),
      esMaestra: ref.read(esCuentaMaestraProvider),
      enAccionDeTabletCasa: ref.read(enAccionDeTabletCasaProvider),
    ),
    routes: rutasDeGravity(
      finanzas: ref.read(rutasFinanzasProvider),
      habitos: ref.read(rutasHabitosProvider),
    ),
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

GoRoute _modulo(
  String ruta,
  Modulo modulo, {
  List<RouteBase> rutas = const [],
}) => GoRoute(
  path: ruta,
  pageBuilder: (context, estado) =>
      _sinAnimacion(estado, PantallaProximamente.modulo(modulo)),
  routes: rutas,
);

/// Monta las rutas que exporta un módulo bajo [base] (p. ej. `/finanzas`).
///
/// [rutas] son relativas a [base] y la pantalla de inicio del módulo es la
/// raíz: un `GoRoute` de primer nivel con `path: '/'` (también se acepta
/// `path: base`). La raíz queda en [base] con sus subrutas, y las demás rutas
/// de primer nivel (relativas, o `ShellRoute` con rutas relativas) quedan
/// debajo. Sin raíz, [base] lleva a la primera ruta del módulo; sin rutas,
/// muestra "Próximamente".
///
/// Los permisos no dependen de esto: el redirect del router revisa cualquier
/// ruta bajo [base] con el espejo de permisos y con `exigeAccion`.
List<RouteBase> montarRutasDeModulo(
  String base,
  List<RouteBase> rutas, {
  required Modulo modulo,
}) {
  bool esRaiz(RouteBase ruta) =>
      ruta is GoRoute && (ruta.path == '/' || ruta.path == base);
  final raiz = rutas.where(esRaiz).cast<GoRoute>().firstOrNull;
  final resto = [
    for (final ruta in rutas)
      if (!identical(ruta, raiz)) ruta,
  ];
  if (raiz == null) {
    final primera = resto.whereType<GoRoute>().firstOrNull;
    if (primera == null) return [_modulo(base, modulo, rutas: resto)];
    return [
      GoRoute(
        path: base,
        redirect: (context, estado) =>
            estado.uri.path == base ? '$base/${primera.path}' : null,
        routes: resto,
      ),
    ];
  }
  final pageBuilder = raiz.pageBuilder;
  final builder = raiz.builder;
  return [
    GoRoute(
      path: base,
      name: raiz.name,
      pageBuilder:
          pageBuilder ??
          (builder == null
              ? null
              : (context, estado) =>
                    _sinAnimacion(estado, builder(context, estado))),
      redirect: raiz.redirect,
      metadata: raiz.metadata,
      onExit: raiz.onExit,
      parentNavigatorKey: raiz.parentNavigatorKey,
      caseSensitive: raiz.caseSensitive,
      routes: [...raiz.routes, ...resto],
    ),
  ];
}

/// Navegador de las pantallas dentro del cascarón. Con él y el navegador raíz
/// se cierran las hojas y diálogos de una persona al cambiar de persona en la
/// tablet (revisión de la Fase 0, B2).
final navegadorCascaronKey = GlobalKey<NavigatorState>(debugLabel: 'cascaron');

/// Cierra todo lo que está encima de las pantallas (hojas, diálogos, menús y
/// avisos), sin tocar las pantallas mismas.
void cerrarLoQueEstaEncima(BuildContext context) {
  bool esPantalla(Route<dynamic> ruta) => ruta.settings is Page || ruta.isFirst;
  navegadorCascaronKey.currentState?.popUntil(esPantalla);
  Navigator.maybeOf(context, rootNavigator: true)?.popUntil(esPantalla);
  ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
}

/// Todas las rutas de la app. [finanzas] son las del módulo (relativas a
/// `Rutas.finanzas`, ver [montarRutasDeModulo]).
List<RouteBase> rutasDeGravity({
  required List<RouteBase> finanzas,
  List<RouteBase> habitos = const [],
}) => [
  GoRoute(
    path: Rutas.entrar,
    builder: (context, estado) => const PantallaEntrar(),
  ),
  GoRoute(
    path: RutasApp.invitacion,
    builder: (context, estado) => const PantallaInvitacion(),
  ),
  ShellRoute(
    navigatorKey: navegadorCascaronKey,
    builder: (context, estado, child) => GuardiaDePantallaSegura(
      ubicacion: estado.uri.path,
      child: CascaronSegunDispositivo(ubicacion: estado.uri.path, child: child),
    ),
    routes: [
      GoRoute(
        path: Rutas.inicio,
        pageBuilder: (context, estado) =>
            _sinAnimacion(estado, const PantallaInicio()),
      ),
      ...montarRutasDeModulo(Rutas.finanzas, finanzas, modulo: Modulo.finanzas),
      if (habitos.isEmpty)
        _modulo(Rutas.habitos, Modulo.habitos)
      else
        ...montarRutasDeModulo(Rutas.habitos, habitos, modulo: Modulo.habitos),
      ...montarRutasDeModulo(
        Rutas.cuidados,
        rutasCuidados(),
        modulo: Modulo.cuidados,
      ),
      ...montarRutasDeModulo(
        Rutas.alimentacion,
        rutasAlimentacion(),
        modulo: Modulo.alimentacion,
      ),
      _modulo(Rutas.casa, Modulo.casa),
      GoRoute(
        path: RutasApp.pendientes,
        pageBuilder: (context, estado) =>
            _sinAnimacion(estado, const PantallaRegistrosAtencion()),
      ),
      GoRoute(
        path: RutasApp.solicitudes,
        pageBuilder: (context, estado) =>
            _sinAnimacion(estado, const PantallaSolicitudes()),
      ),
      GoRoute(
        path: RutasApp.avisos,
        pageBuilder: (context, estado) =>
            _sinAnimacion(estado, const PantallaBandejaAvisos()),
      ),
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
