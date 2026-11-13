/// Menú de la semana: 7 días por 3 tiempos. Editable solo para quien puede.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/pantallas/marco_pantalla.dart';
import '../../../diseno/diseno.dart';
import '../../../nucleo/contratos/roles.dart';
import '../../../nucleo/contratos/rutas.dart';
import '../casos_uso/servicio_alimentacion.dart';
import '../datos/perfiles.dart';
import '../datos/modelos.dart';
import '../estado/proveedores.dart';
import 'selector_menu.dart';

String _fechaCorta(DateTime d) => '${d.day}/${d.month}';

class PantallaMenuSemana extends ConsumerWidget {
  const PantallaMenuSemana({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semana = ref.watch(semanaAlimentacionProvider);
    final domingo = semana.add(const Duration(days: 6));
    final visibles = ref.watch(servicioAlimentacionProvider).menusVisibles;
    final menu = menuEfectivo(ref.watch(menuElegidoProvider), visibles);
    return TemaModulo(
      modulo: Modulo.alimentacion,
      child: MarcoPantalla(
        titulo: 'Menú de la semana',
        acciones: [
          if (ref.watch(servicioPlanFamiliarProvider).puedeVer)
            IconButton(
              icon: const Icon(Icons.how_to_vote_outlined),
              tooltip: 'Plan familiar',
              onPressed: () => context.go('${Rutas.alimentacion}/plan'),
            ),
          if (ref.watch(puedeEditarAlimentacionProvider))
            IconButton(
              icon: const Icon(Icons.upload_file_outlined),
              tooltip: 'Importar recetas',
              onPressed: () =>
                  context.go('${Rutas.alimentacion}/importar-recetas'),
            ),
          if (ref
              .watch(servicioAlimentacionProvider)
              .menusConCompras
              .isNotEmpty)
            IconButton(
              icon: const Icon(Icons.shopping_cart_outlined),
              tooltip: 'Lista de compras',
              onPressed: () => context.go('${Rutas.alimentacion}/compras'),
            ),
        ],
        cuerpo: menu == null
            ? const EstadoVacio(
                mensaje: 'No tienes menús para ver',
                detalle: 'Pide al dueño que te dé acceso.',
                icono: Icons.lock_outline,
              )
            : ref.watch(alimentacionSinServidorProvider)
            ? const EstadoVacio(
                mensaje: 'Sin menú todavía',
                detalle: 'El menú de la semana aparecerá cuando Alimentación esté activa en tu hogar.',
                icono: Icons.restaurant_menu_outlined,
              )
            : Column(
                children: [
                  SelectorMenu(
                    menus: visibles,
                    actual: menu,
                    alElegir: (m) =>
                        ref.read(menuElegidoProvider.notifier).state = m,
                  ),
                  _NavegadorSemana(
                    texto:
                        'Semana del ${_fechaCorta(semana)} al ${_fechaCorta(domingo)}',
                    alCambiar: (dias) =>
                        ref.read(semanaAlimentacionProvider.notifier).state =
                            semana.add(Duration(days: dias)),
                  ),
                  Expanded(
                    child: ref
                        .watch(platillosProvider)
                        .when(
                          loading: () => const EstadoCargando(),
                          error: (_, _) => EstadoError(
                            mensaje: 'No pudimos cargar los platillos.',
                            alReintentar: () =>
                                ref.invalidate(platillosProvider),
                          ),
                          data: (platillos) => ref
                              .watch(menuSemanaProvider(menu))
                              .when(
                                loading: () => const EstadoCargando(),
                                error: (_, _) => EstadoError(
                                  mensaje: 'No pudimos cargar el menú.',
                                  alReintentar: () =>
                                      ref.invalidate(menuSemanaProvider(menu)),
                                ),
                                data: (m) => _ListaDias(
                                  menu: menu,
                                  entradas: m,
                                  platillos: platillos,
                                ),
                              ),
                        ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _NavegadorSemana extends StatelessWidget {
  const _NavegadorSemana({required this.texto, required this.alCambiar});
  final String texto;
  final void Function(int dias) alCambiar;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    child: Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Semana anterior',
          onPressed: () => alCambiar(-7),
        ),
        Expanded(
          child: Text(
            texto,
            textAlign: TextAlign.center,
            style: ValoresDiseno.de(context).lectura(
              tamano: 16,
              peso: FontWeight.w600,
              color: ValoresDiseno.de(context).textoFuerte,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Semana siguiente',
          onPressed: () => alCambiar(7),
        ),
      ],
    ),
  );
}

class _ListaDias extends ConsumerWidget {
  const _ListaDias({
    required this.menu,
    required this.entradas,
    required this.platillos,
  });
  final MenuId menu;
  final List<EntradaMenu> entradas;
  final List<Platillo> platillos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ValoresDiseno.de(context);
    final servicio = ref.watch(servicioAlimentacionProvider);
    final editar = servicio.puedeEditarMenuDe(menu);
    final perfil = servicio.perfil(menu);
    final porId = {for (final p in platillos) p.id: p};
    Platillo? platilloDe(int dia, TiempoComida t) {
      for (final e in entradas) {
        if (e.dia == dia && e.tiempo == t) return porId[e.platilloId];
      }
      return null;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (!editar)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(Icons.visibility_outlined, size: 18, color: v.textoTenue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Solo lectura',
                    style: v.lectura(tamano: 14, color: v.textoTenue),
                  ),
                ),
              ],
            ),
          ),
        if (perfil.texturaBlanda) _TarjetaPerfil(perfil: perfil),
        for (var d = 0; d < 7; d++)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    diasSemana[d],
                    style: v.titulo(tamano: 18, color: v.textoFuerte),
                  ),
                  for (final t in TiempoComida.values)
                    _CeldaComida(
                      menu: menu,
                      dia: d,
                      tiempo: t,
                      platillo: platilloDe(d, t),
                      editable: editar,
                      platillos: platillos,
                      textura: perfil.texturaBlanda,
                    ),
                ],
              ),
            ),
          ),
        _Suplementos(menu: menu, editable: servicio.puedeEditar),
      ],
    );
  }
}

class _TarjetaPerfil extends StatelessWidget {
  const _TarjetaPerfil({required this.perfil});
  final PerfilMenu perfil;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: v.acento),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    perfil.titulo,
                    style: v.titulo(tamano: 16, color: v.textoFuerte),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            for (final l in perfil.lineas)
              Text(l, style: v.lectura(tamano: 15, color: v.texto)),
          ],
        ),
      ),
    );
  }
}

class _CeldaComida extends ConsumerWidget {
  const _CeldaComida({
    required this.menu,
    required this.dia,
    required this.tiempo,
    required this.platillo,
    required this.editable,
    required this.platillos,
    required this.textura,
  });
  final MenuId menu;
  final int dia;
  final TiempoComida tiempo;
  final Platillo? platillo;
  final bool editable;
  final List<Platillo> platillos;
  final bool textura;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ValoresDiseno.de(context);
    final nombre = platillo?.nombre;
    final duros = textura
        ? (platillo?.duros ?? const <String>[])
        : const <String>[];
    // Menú compartido de dueño y pareja: un platillo, una porción por persona.
    final porciones = menu == MenuId.pareja && platillo != null
        ? ref
                  .watch(porcionesRecomendadasProvider)
                  .maybeWhen(data: (m) => m[platillo!.id], orElse: () => null) ??
              const <PorcionPersona>[]
        : const <PorcionPersona>[];
    final contenido = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              tiempo.etiqueta,
              style: v.lectura(tamano: 14, color: v.etiqueta),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre ?? 'Sin platillo',
                  style: v.lectura(
                    tamano: 16,
                    color: nombre == null ? v.textoTenue : v.texto,
                  ),
                ),
                if (porciones.isNotEmpty)
                  Text(
                    'Porción recomendada: ${[
                      for (final p in porciones) '${p.cuenta.etiqueta} ${cantidadTexto(p.porciones)}',
                    ].join(' · ')}',
                    key: Key('porciones_${platillo!.id}_${dia}_${tiempo.name}'),
                    style: v.lectura(tamano: 13, color: v.textoTenue),
                  ),
                if (editable && menu == MenuId.pareja && platillo != null)
                  TextButton.icon(
                    key: Key('cambiar_porciones_${platillo!.id}_${dia}_${tiempo.name}'),
                    icon: const Icon(Icons.tune, size: 16),
                    label: const Text('Cambiar porciones'),
                    onPressed: () => _cambiarPorciones(
                      context,
                      ref,
                      platillo!,
                      porciones,
                    ),
                  ),
                if (duros.isNotEmpty)
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: v.alerta,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Alimento duro: ${duros.join(', ')}',
                          style: v.lectura(tamano: 13, color: v.alerta),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          if (editable)
            Icon(Icons.edit_outlined, size: 18, color: v.textoTenue),
        ],
      ),
    );
    final etiqueta =
        '${diasSemana[dia]}, ${tiempo.etiqueta}: ${nombre ?? 'sin platillo'}'
        '${duros.isEmpty ? '' : '. Advertencia: alimento duro'}';
    if (!editable) {
      return Semantics(
        label: etiqueta,
        excludeSemantics: true,
        child: contenido,
      );
    }
    return Semantics(
      button: true,
      label: '$etiqueta. Toca para cambiar.',
      excludeSemantics: true,
      child: InkWell(onTap: () => _elegir(context, ref), child: contenido),
    );
  }

  Future<void> _elegir(BuildContext context, WidgetRef ref) async {
    final elegido = await mostrarHojaInferior<String>(
      context,
      titulo: '${diasSemana[dia]} · ${tiempo.etiqueta}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final p in platillos)
            ListTile(
              title: Text(p.nombre),
              subtitle: textura && p.duros.isNotEmpty
                  ? Text('Alimento duro: ${p.duros.join(', ')}')
                  : null,
              trailing: textura && p.duros.isNotEmpty
                  ? const Icon(Icons.warning_amber_rounded)
                  : null,
              onTap: () async {
                if (textura && p.duros.isNotEmpty) {
                  final seguir = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Alimento duro'),
                      content: Text(
                        '${p.nombre} tiene ${p.duros.join(', ')}. '
                        'Este menú pide alimentos blandos. ¿Usarlo de todos modos?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(c).pop(false),
                          child: const Text('Elegir otro'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.of(c).pop(true),
                          child: const Text('Usar de todos modos'),
                        ),
                      ],
                    ),
                  );
                  if (seguir != true) return;
                }
                if (context.mounted) Navigator.of(context).pop(p.id);
              },
            ),
          ListTile(
            leading: const Icon(Icons.clear),
            title: const Text('Quitar platillo'),
            onTap: () => Navigator.of(context).pop(''),
          ),
        ],
      ),
    );
    if (elegido == null || !context.mounted) return;
    final servicio = ref.read(servicioAlimentacionProvider);
    final semana = ref.read(semanaAlimentacionProvider);
    final antes = await servicio.asignar(
      menu,
      semana,
      dia,
      tiempo,
      elegido.isEmpty ? null : elegido,
    );
    ref.read(versionAlimentacionProvider.notifier).state++;
    if (!context.mounted) return;
    mostrarAvisoDeshacer(
      context,
      mensaje: elegido.isEmpty ? 'Platillo quitado' : 'Menú actualizado',
      alDeshacer: () async {
        await servicio.asignar(menu, semana, dia, tiempo, antes);
        ref.read(versionAlimentacionProvider.notifier).state++;
      },
    );
  }
}

class _Suplementos extends ConsumerWidget {
  const _Suplementos({required this.menu, required this.editable});
  final MenuId menu;
  final bool editable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ValoresDiseno.de(context);
    final lista =
        ref.watch(suplementosProvider(menu)).value ?? const <Suplemento>[];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Suplementos',
              style: v.titulo(tamano: 18, color: v.textoFuerte),
            ),
            if (lista.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Sin suplementos',
                  style: v.lectura(tamano: 15, color: v.textoTenue),
                ),
              ),
            for (final s in lista)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(s.nombre),
                subtitle: Text('${s.dosis} · ${s.horario}'),
                onTap: editable ? () => _editar(context, ref, s) : null,
                trailing: editable
                    ? IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Quitar ${s.nombre}',
                        onPressed: () async {
                          await ref
                              .read(servicioAlimentacionProvider)
                              .quitarSuplemento(menu, s.id);
                          ref
                              .read(versionAlimentacionProvider.notifier)
                              .state++;
                        },
                      )
                    : null,
              ),
            if (editable)
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Agregar suplemento'),
                onPressed: () => _editar(context, ref, null),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _editar(
    BuildContext context,
    WidgetRef ref,
    Suplemento? actual,
  ) async {
    final nombre = TextEditingController(text: actual?.nombre);
    final dosis = TextEditingController(text: actual?.dosis);
    final horario = TextEditingController(text: actual?.horario);
    final ok = await mostrarHojaInferior<bool>(
      context,
      titulo: actual == null ? 'Nuevo suplemento' : 'Editar suplemento',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombre,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            TextField(
              controller: dosis,
              decoration: const InputDecoration(labelText: 'Dosis'),
            ),
            TextField(
              controller: horario,
              decoration: const InputDecoration(labelText: 'Horario'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || nombre.text.trim().isEmpty) return;
    await ref
        .read(servicioAlimentacionProvider)
        .guardarSuplemento(
          menu,
          Suplemento(
            id: actual?.id ?? 's${DateTime.now().microsecondsSinceEpoch}',
            nombre: nombre.text.trim(),
            dosis: dosis.text.trim(),
            horario: horario.text.trim(),
          ),
        );
    ref.read(versionAlimentacionProvider.notifier).state++;
  }
}

/// Texto de una porción para editar: "1.5", "0.25", "2.0" (sin redondear).
String _textoPorcion(List<PorcionPersona> l, CuentaCompra c) {
  for (final p in l) {
    if (p.cuenta == c) return p.porciones.toString();
  }
  return '1.0';
}

/// Cambia la porción de dueño y de pareja de un platillo del menú compartido.
/// Cada persona se guarda solo si cambió; la otra conserva la suya.
Future<void> _cambiarPorciones(
  BuildContext context,
  WidgetRef ref,
  Platillo platillo,
  List<PorcionPersona> actuales,
) async {
  final semana = ref.read(semanaAlimentacionProvider);
  final campos = {
    for (final c in [CuentaCompra.dueno, CuentaCompra.pareja])
      c: TextEditingController(text: _textoPorcion(actuales, c)),
  };
  final error = ValueNotifier<String?>(null);
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Porciones de ${platillo.nombre}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final c in [CuentaCompra.dueno, CuentaCompra.pareja])
            TextField(
              controller: campos[c],
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: c.etiqueta),
            ),
          ValueListenableBuilder<String?>(
            valueListenable: error,
            builder: (_, m, _) => m == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(m, key: const Key('error_porciones')),
                  ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () async {
            final servicio = ref.read(servicioAlimentacionProvider);
            try {
              for (final c in [CuentaCompra.dueno, CuentaCompra.pareja]) {
                final nuevo = double.tryParse(
                  campos[c]!.text.trim().replaceAll(',', '.'),
                );
                if (nuevo == null) {
                  throw ArgumentError('Escribe una porción para ${c.etiqueta}.');
                }
                if (nuevo == double.tryParse(_textoPorcion(actuales, c))) {
                  continue;
                }
                await servicio.fijarPorcion(
                  platilloId: platillo.id,
                  semana: semana,
                  cuenta: c,
                  porciones: nuevo,
                );
              }
              ref.read(versionAlimentacionProvider.notifier).state++;
              if (ctx.mounted) Navigator.of(ctx).pop();
            } on ArgumentError catch (e) {
              error.value = '${e.message}';
            } on PermisoDenegado {
              error.value = 'Solo dueño y pareja cambian las porciones.';
            } catch (_) {
              error.value = 'No se pudo guardar. Inténtalo más tarde.';
            }
          },
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
  for (final c in campos.values) {
    c.dispose();
  }
  error.dispose();
}
