/// Rutas de «Mi gimnasio» (Fase 8, G3; spec 7.1). El acceso por rol y por equipo
/// está en `acceso_gimnasio.dart`.
///
/// Las pantallas reales las hace G5. Mientras tanto cada ruta muestra la
/// maqueta de G4 **marcada como provisional** ([PantallaProvisionalGimnasio]).
/// G5 las reemplaza sobrescribiendo [pantallaGimnasioProvider]; las rutas, el
/// acceso por rol y por equipo y la protección de las molestias se quedan.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../diseno/gimnasio/maquetas.dart';
import '../../nucleo/contratos/rutas.dart';
import '../pantallas/marco_pantalla.dart';
import 'acceso_gimnasio.dart';
import 'proteger_molestias.dart';

/// La maqueta de G4 con la que se muestra cada destino mientras G5 no hace la
/// real.
PantallaMaqueta maquetaDe(DestinoGimnasio destino) => switch (destino) {
  DestinoGimnasio.hoy => PantallaMaqueta.e1Hoy,
  DestinoGimnasio.inventario => PantallaMaqueta.e2Inventario,
  DestinoGimnasio.plan => PantallaMaqueta.e3Plan,
  DestinoGimnasio.sesion => PantallaMaqueta.e4SesionDeHoy,
  DestinoGimnasio.sesionEnCurso => PantallaMaqueta.e5SesionEnCurso,
  DestinoGimnasio.registro => PantallaMaqueta.e6RegistroRapido,
  DestinoGimnasio.historial => PantallaMaqueta.e7Historial,
  DestinoGimnasio.records => PantallaMaqueta.e8Records,
  DestinoGimnasio.molestias => PantallaMaqueta.e9Molestias,
  DestinoGimnasio.ajustes => PantallaMaqueta.e10Ajustes,
};

/// Cómo se arma cada pantalla. Por omisión, la maqueta de G4 marcada como
/// provisional; **G5 lo sobrescribe** con las pantallas reales (casos de uso y
/// datos). La pantalla de molestias siempre se envuelve en [ProtegerMolestias]
/// (FLAG_SECURE, modo privado y equipos que no las admiten), la construya quien
/// la construya.
final pantallaGimnasioProvider = Provider<Widget Function(DestinoGimnasio)>(
  (ref) =>
      (destino) => PantallaProvisionalGimnasio(destino: destino),
);

/// Texto fijo que marca una pantalla como maqueta provisional.
const textoPantallaProvisional =
    'Pantalla provisional: los datos son de ejemplo. La real llega con el '
    'paquete G5 de Mi gimnasio.';

/// Una maqueta de G4 dentro del marco de la app, con su aviso de provisional.
class PantallaProvisionalGimnasio extends StatelessWidget {
  const PantallaProvisionalGimnasio({super.key, required this.destino});

  final DestinoGimnasio destino;

  @override
  Widget build(BuildContext context) => MarcoPantalla(
    titulo: destino.titulo,
    rutaAnterior: destino == DestinoGimnasio.hoy
        ? Rutas.habitos
        : RutasGimnasio.hoy,
    cuerpo: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          container: true,
          child: Container(
            key: const ValueKey('gimnasio-provisional'),
            color: Theme.of(context).colorScheme.tertiaryContainer,
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                const Icon(Icons.construction_outlined),
                const SizedBox(width: 8),
                const Expanded(child: Text(textoPantallaProvisional)),
              ],
            ),
          ),
        ),
        Expanded(child: MaquetaGimnasio(pantalla: maquetaDe(destino))),
      ],
    ),
  );
}

Page<void> _pagina(GoRouterState estado, Widget pantalla) =>
    NoTransitionPage<void>(key: estado.pageKey, child: pantalla);

Widget _pantalla(DestinoGimnasio destino) => Consumer(
  builder: (context, ref, _) {
    final pantalla = ref.watch(pantallaGimnasioProvider)(destino);
    return destino == DestinoGimnasio.molestias
        ? ProtegerMolestias(child: pantalla)
        : pantalla;
  },
);

/// Rutas de «Mi gimnasio», **relativas a `/habitos`**: se suman a
/// `rutasHabitos()` en el router. `entrenamiento` es E1 y cuelga el resto.
List<RouteBase> rutasGimnasio() => [
  GoRoute(
    path: 'entrenamiento',
    pageBuilder: (context, estado) =>
        _pagina(estado, _pantalla(DestinoGimnasio.hoy)),
    routes: [
      for (final d in DestinoGimnasio.values)
        if (d != DestinoGimnasio.hoy && d != DestinoGimnasio.sesionEnCurso)
          GoRoute(
            path: d.rutaRelativa.substring('entrenamiento/'.length),
            pageBuilder: (context, estado) => _pagina(estado, _pantalla(d)),
            routes: [
              // E5 cuelga de E4: `entrenamiento/sesion/en-curso`.
              if (d == DestinoGimnasio.sesion)
                GoRoute(
                  path: 'en-curso',
                  pageBuilder: (context, estado) =>
                      _pagina(estado, _pantalla(DestinoGimnasio.sesionEnCurso)),
                ),
            ],
          ),
    ],
  ),
];
