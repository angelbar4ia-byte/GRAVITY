/// Gastos y categorías (laptop; especificación 6.1): árbol de 3 niveles con
/// prioridad, protección y cuenta de gasto, y el gasto de cada categoría en
/// el periodo. Se crean, renombran, ocultan, archivan y se eliminan solo sin
/// datos (5.2). Las categorías son del hogar (regla 2 de 4.5); el gasto que
/// se muestra es el del libro activo.
library;

import 'package:finanzas_dominio/finanzas_dominio.dart'
    hide Semaforo, formatearCentavos, TipoLibro, puntosBaseEnCien;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../diseno/diseno.dart';
import '../../estado/proveedores.dart';
import '../comunes.dart';
import 'marco_laptop.dart';

class PantallaCategorias extends StatelessWidget {
  const PantallaCategorias({super.key});

  @override
  Widget build(BuildContext context) => MarcoFinanzasLaptop(
    seccion: SeccionFinanzas.categorias,
    acciones: (context, c) => [
      if (c.administraHogar && !c.permiso.comoMaestra)
        FilledButton.icon(
          key: const ValueKey('categorias-nueva'),
          onPressed: () => crearCategoria(context, null),
          icon: const Icon(Icons.add),
          label: const Text('Nueva categoría'),
        ),
    ],
    builder: (context, c) => _Categorias(contexto: c),
  );
}

Future<void> crearCategoria(BuildContext context, Categoria? padre) async {
  final nombre = await pedirTexto(
    context,
    titulo: padre == null ? 'Nueva categoría' : 'Nueva dentro de ${padre.nombre}',
    etiqueta: 'Nombre',
    textoAccion: 'Crear',
  );
  if (nombre == null || !context.mounted) return;
  final ref = ProviderScope.containerOf(context);
  await intentar(
    context,
    () => ref.read(servicioFinanzasProvider).crearCategoria(
      nombre: nombre,
      padreId: padre?.id,
    ),
  );
}

class _Categorias extends ConsumerStatefulWidget {
  const _Categorias({required this.contexto});

  final ContextoFinanzas contexto;

  @override
  ConsumerState<_Categorias> createState() => _CategoriasState();
}

class _CategoriasState extends ConsumerState<_Categorias> {
  bool _mes = false;
  bool _verArchivadas = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.contexto;
    final arbol = c.datos.arbol;
    final periodo = _mes ? Periodo.mes(c.hoy) : Periodo.semana(c.hoy);
    final vista = c.datos.vista(c.libroId);
    final gastoPorCategoria = <String, int>{};
    for (final m in vista.movimientos) {
      if (!periodo.contiene(m.fecha) || m.categoriaId == null) continue;
      final destino = vista.cuenta(m.cuentaDestinoId).clase == ClaseCuenta.gasto;
      final origen = vista.cuenta(m.cuentaOrigenId).clase == ClaseCuenta.gasto;
      final delta = (destino ? m.monto : 0) - (origen ? m.monto : 0);
      gastoPorCategoria[m.categoriaId!] = (gastoPorCategoria[m.categoriaId!] ?? 0) + delta;
    }
    int gastoDe(String id) => arbol
        .conDescendientes(id)
        .fold(0, (t, x) => t + (gastoPorCategoria[x] ?? 0));
    final editable = c.administraHogar && !c.permiso.comoMaestra;
    final raices = [
      for (final x in arbol.hijas(null))
        if (_verArchivadas || !x.archivada) x,
    ];
    if (raices.isEmpty) {
      return EstadoVacio(
        icono: Icons.category_outlined,
        mensaje: 'Aún no hay categorías.',
        detalle: 'Importa la plantilla (hoja Categorías) o crea las tuyas.',
        textoAccion: editable ? 'Importar datos' : null,
        alAccionar: editable ? () => context.go(SeccionFinanzas.importar.ruta) : null,
      );
    }
    return ContenidoLaptop(
      children: [
        Wrap(
          spacing: 12,
          children: [
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: false, label: Text('Esta semana')),
                ButtonSegment(value: true, label: Text('Este mes')),
              ],
              selected: {_mes},
              onSelectionChanged: (s) => setState(() => _mes = s.first),
            ),
            FilterChip(
              label: const Text('Ver archivadas'),
              selected: _verArchivadas,
              onSelected: (x) => setState(() => _verArchivadas = x),
            ),
          ],
        ),
        for (final raiz in raices)
          Card(
            key: ValueKey('categoria-${raiz.id}'),
            child: ExpansionTile(
              title: _Titulo(categoria: raiz, gasto: gastoDe(raiz.id)),
              subtitle: Text(
                '${nombrePrioridad(raiz.prioridad)}'
                '${raiz.protegida ? ' · Protegida' : ''}'
                '${raiz.naturaleza.isEmpty ? '' : ' · ${raiz.naturaleza}'}'
                ' · Cuenta de gasto: ${c.datos.cuenta(raiz.cuentaGastoId ?? '')?.nombre ?? '—'}',
              ),
              trailing: editable ? _Menu(categoria: raiz) : null,
              children: [
                for (final sub in arbol.hijas(raiz.id))
                  if (_verArchivadas || !sub.archivada)
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Column(
                        children: [
                          ListTile(
                            title: _Titulo(categoria: sub, gasto: gastoDe(sub.id)),
                            trailing: editable ? _Menu(categoria: sub) : null,
                          ),
                          for (final det in arbol.hijas(sub.id))
                            if (_verArchivadas || !det.archivada)
                              Padding(
                                padding: const EdgeInsets.only(left: 24),
                                child: ListTile(
                                  dense: true,
                                  title: _Titulo(categoria: det, gasto: gastoDe(det.id)),
                                  trailing: editable ? _Menu(categoria: det) : null,
                                ),
                              ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo({required this.categoria, required this.gasto});

  final Categoria categoria;
  final int gasto;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          categoria.nombre +
              (categoria.oculta ? ' (oculta)' : '') +
              (categoria.archivada ? ' (archivada)' : ''),
        ),
      ),
      Monto(gasto),
    ],
  );
}

enum _Accion { nueva, renombrar, protegida, prioridad, ocultar, archivar, eliminar }

class _Menu extends ConsumerWidget {
  const _Menu({required this.categoria});

  final Categoria categoria;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final x = categoria;
    final servicio = ref.read(servicioFinanzasProvider);
    return PopupMenuButton<_Accion>(
      key: ValueKey('categoria-menu-${x.id}'),
      tooltip: 'Opciones de ${x.nombre}',
      onSelected: (a) async {
        switch (a) {
          case _Accion.nueva:
            await crearCategoria(context, x);
          case _Accion.renombrar:
            final nombre = await pedirTexto(
              context,
              titulo: 'Renombrar',
              etiqueta: 'Nombre',
              inicial: x.nombre,
            );
            if (nombre != null && context.mounted) {
              await intentar(context, () => servicio.cambiarCategoria(x.copiar(nombre: nombre)));
            }
          case _Accion.protegida:
            await intentar(
              context,
              () => servicio.cambiarCategoria(x.copiar(protegida: !x.protegida)),
            );
          case _Accion.prioridad:
            final siguiente =
                Prioridad.values[(x.prioridad.index + 1) % Prioridad.values.length];
            await intentar(
              context,
              () => servicio.cambiarCategoria(x.copiar(prioridad: siguiente)),
            );
          case _Accion.ocultar:
            await intentar(context, () => servicio.cambiarCategoria(x.copiar(oculta: !x.oculta)));
          case _Accion.archivar:
            await intentar(
              context,
              () => servicio.cambiarCategoria(x.copiar(archivada: !x.archivada)),
            );
          case _Accion.eliminar:
            if (await confirmar(
                  context,
                  titulo: 'Eliminar ${x.nombre}',
                  mensaje: 'Solo se elimina si no tiene datos; con datos se archiva.',
                  textoAccion: 'Eliminar',
                ) &&
                context.mounted) {
              await intentar(context, () => servicio.eliminarCategoria(x.id));
            }
        }
      },
      itemBuilder: (_) => [
        if (x.nivel < 3) const PopupMenuItem(value: _Accion.nueva, child: Text('Nueva dentro…')),
        const PopupMenuItem(value: _Accion.renombrar, child: Text('Renombrar…')),
        PopupMenuItem(
          value: _Accion.protegida,
          child: Text(x.protegida ? 'Quitar protección' : 'Proteger'),
        ),
        PopupMenuItem(
          value: _Accion.prioridad,
          child: Text('Prioridad: ${nombrePrioridad(x.prioridad)} (cambiar)'),
        ),
        PopupMenuItem(value: _Accion.ocultar, child: Text(x.oculta ? 'Mostrar' : 'Ocultar')),
        PopupMenuItem(
          value: _Accion.archivar,
          child: Text(x.archivada ? 'Desarchivar' : 'Archivar'),
        ),
        const PopupMenuItem(value: _Accion.eliminar, child: Text('Eliminar (sin datos)')),
      ],
    );
  }
}
