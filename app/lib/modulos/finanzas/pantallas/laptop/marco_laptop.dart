/// Finanzas en la laptop (`DISENO_UX_UI.md` sección 8): barra lateral con el
/// selector de libro y las secciones del módulo, área principal con la acción
/// principal arriba a la derecha. Si la ventana es angosta, la barra lateral
/// se vuelve menú.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/pantallas/marco_pantalla.dart';
import '../../../../diseno/diseno.dart';
import '../../../../nucleo/contratos/roles.dart';
import '../../../../nucleo/contratos/rutas.dart';
import '../../estado/proveedores.dart';
import '../comunes.dart';

/// Secciones de Finanzas en la laptop (especificación 6.1).
enum SeccionFinanzas {
  tablero('tablero', 'Tablero', Icons.dashboard_outlined),
  semana('semana', 'Semana', Icons.date_range_outlined),
  movimientos('movimientos', 'Movimientos', Icons.receipt_long_outlined),
  cuentas('cuentas', 'Cuentas', Icons.account_balance_outlined),
  ingresos('ingresos', 'Ingresos', Icons.savings_outlined),
  categorias('categorias', 'Gastos y categorías', Icons.category_outlined),
  compromisos(
    'compromisos',
    'Compromisos y deudas',
    Icons.event_repeat_outlined,
  ),
  arranque('arranque', 'Asistente de arranque', Icons.rocket_launch_outlined),
  importar('importar', 'Importar datos', Icons.upload_file_outlined),
  ajustes('ajustes', 'Ajustes de Finanzas', Icons.tune);

  const SeccionFinanzas(this.segmento, this.titulo, this.icono);

  final String segmento;
  final String titulo;
  final IconData icono;

  /// Ruta de la sección. El tablero es el inicio del módulo en la laptop
  /// (`/finanzas`).
  String get ruta => this == SeccionFinanzas.tablero
      ? Rutas.finanzas
      : '${Rutas.finanzas}/$segmento';

  /// `true` si la sección solo cambia la configuración (la ruta exige
  /// administrar: `exigeAccion`).
  bool get esDeConfiguracion => switch (this) {
    SeccionFinanzas.arranque ||
    SeccionFinanzas.importar ||
    SeccionFinanzas.ajustes => true,
    _ => false,
  };

  /// Si la sección aparece para el contexto (lo que es solo de configurar no
  /// se muestra a quien solo lee).
  bool visiblePara(ContextoFinanzas c) => switch (this) {
    SeccionFinanzas.arranque => c.puedeAdministrar,
    SeccionFinanzas.importar => c.administraHogar && !c.permiso.comoMaestra,
    SeccionFinanzas.ajustes => c.puedeAdministrar || c.administraHogar,
    _ => true,
  };
}

/// Ancho a partir del cual la barra lateral se queda fija.
const double anchoBarraLateral = 900;

/// Ancho de la barra lateral: cabe un libro con nombre largo y su marca
/// ("Solo lectura", "Albacea") en el selector.
const double anchoBarraLateralFija = 300;

class MarcoFinanzasLaptop extends ConsumerWidget {
  const MarcoFinanzasLaptop({
    super.key,
    required this.seccion,
    required this.builder,
    this.acciones,
  });

  final SeccionFinanzas seccion;
  final Widget Function(BuildContext context, ContextoFinanzas contexto)
  builder;

  /// Acción principal (arriba a la derecha), según el contexto.
  final List<Widget> Function(BuildContext context, ContextoFinanzas contexto)?
  acciones;

  @override
  Widget build(BuildContext context, WidgetRef ref) => TemaModulo(
    modulo: Modulo.finanzas,
    child: MarcoPantalla(
      titulo: 'Finanzas › ${seccion.titulo}',
      acciones: const [BotonMontos()],
      cuerpo: ConDatosFinanzas(
        builder: (context, c) => LayoutBuilder(
          builder: (context, limites) {
            final ancho = limites.maxWidth >= anchoBarraLateral;
            final principal = _Principal(
              seccion: seccion,
              contexto: c,
              acciones: acciones?.call(context, c) ?? const [],
              conMenu: !ancho,
              child: builder(context, c),
            );
            if (!ancho) return principal;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: anchoBarraLateralFija,
                  child: _BarraLateral(seccion: seccion, contexto: c),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: principal),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class _BarraLateral extends StatelessWidget {
  const _BarraLateral({required this.seccion, required this.contexto});

  final SeccionFinanzas seccion;
  final ContextoFinanzas contexto;

  @override
  Widget build(BuildContext context) => ListView(
    key: const ValueKey('finanzas-barra-lateral'),
    padding: const EdgeInsets.symmetric(vertical: 12),
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: SelectorLibroFinanzas(contexto: contexto, comoMenu: true),
      ),
      for (final s in SeccionFinanzas.values)
        if (s.visiblePara(contexto))
          ListTile(
            key: ValueKey('finanzas-seccion-${s.segmento}'),
            leading: Icon(s.icono),
            title: Text(s.titulo),
            selected: s == seccion,
            minTileHeight: 48,
            onTap: () => context.go(s.ruta),
          ),
    ],
  );
}

class _Principal extends StatelessWidget {
  const _Principal({
    required this.seccion,
    required this.contexto,
    required this.acciones,
    required this.conMenu,
    required this.child,
  });

  final SeccionFinanzas seccion;
  final ContextoFinanzas contexto;
  final List<Widget> acciones;
  final bool conMenu;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(v.espacio * 3, v.espacio * 2, v.espacio * 3, 0),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              // Wrap, no Row: con letra grande o en una ventana angosta el
              // título y la marca ("Solo lectura", "En nombre de…") pasan a
              // otra línea en lugar de desbordarse (I7 y M7).
              Wrap(
                spacing: 12,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (conMenu)
                    PopupMenuButton<SeccionFinanzas>(
                      key: const ValueKey('finanzas-menu-secciones'),
                      tooltip: 'Secciones de Finanzas',
                      icon: const Icon(Icons.menu),
                      onSelected: (s) => context.go(s.ruta),
                      itemBuilder: (_) => [
                        for (final s in SeccionFinanzas.values)
                          if (s.visiblePara(contexto))
                            PopupMenuItem(value: s, child: Text(s.titulo)),
                      ],
                    ),
                  Text(
                    seccion.titulo,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  marcaDe(contexto),
                ],
              ),
              if (acciones.isNotEmpty)
                Wrap(spacing: 8, runSpacing: 8, children: acciones),
            ],
          ),
        ),
        // Con los montos ocultos por falta de uso: la marca para verlos.
        Padding(
          padding: EdgeInsets.fromLTRB(v.espacio * 3, 0, v.espacio * 3, 0),
          child: const Align(
            alignment: AlignmentDirectional.centerStart,
            child: MarcaMontosOcultos(),
          ),
        ),
        if (conMenu)
          Padding(
            padding: EdgeInsets.fromLTRB(v.espacio * 3, v.espacio, v.espacio * 3, 0),
            child: SelectorLibroFinanzas(contexto: contexto),
          ),
        SizedBox(height: v.espacio),
        Expanded(child: child),
      ],
    );
  }
}

/// Contenido desplazable con márgenes de la laptop.
class ContenidoLaptop extends StatelessWidget {
  const ContenidoLaptop({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final e = ValoresDiseno.de(context).espacio;
    return ListView(
      padding: EdgeInsets.fromLTRB(e * 3, e, e * 3, e * 4),
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(height: e * 2),
          children[i],
        ],
      ],
    );
  }
}

/// Tarjetas en columnas que se acomodan al ancho.
class Rejilla extends StatelessWidget {
  const Rejilla({super.key, required this.children, this.anchoMinimo = 320});

  final List<Widget> children;
  final double anchoMinimo;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, limites) {
      final e = ValoresDiseno.de(context).espacio * 2;
      final columnas = (limites.maxWidth / anchoMinimo).floor().clamp(1, 4);
      final ancho = (limites.maxWidth - e * (columnas - 1)) / columnas;
      return Wrap(
        spacing: e,
        runSpacing: e,
        children: [
          for (final c in children) SizedBox(width: ancho, child: c),
        ],
      );
    },
  );
}
