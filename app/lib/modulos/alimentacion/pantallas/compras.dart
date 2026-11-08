/// Lista de compras de la semana por pasillo, para usarla en el súper (el
/// teléfono). Los precios base se rotulan "estimado"; sin precio no hay costo.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/pantallas/marco_pantalla.dart';
import '../../../diseno/diseno.dart';
import '../../../nucleo/contratos/roles.dart';
import '../../../nucleo/contratos/rutas.dart';
import '../casos_uso/lista_compras.dart';
import '../datos/modelos.dart';
import '../estado/proveedores.dart';
import 'selector_menu.dart';

class PantallaListaCompras extends ConsumerWidget {
  const PantallaListaCompras({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permitidos = ref.watch(servicioAlimentacionProvider).menusConCompras;
    final menu = menuEfectivo(ref.watch(menuElegidoProvider), permitidos);
    return TemaModulo(
      modulo: Modulo.alimentacion,
      child: MarcoPantalla(
        titulo: 'Lista de compras',
        rutaAnterior: Rutas.alimentacion,
        cuerpo: menu == null
            ? const EstadoVacio(
                mensaje: 'No tienes listas para ver',
                icono: Icons.lock_outline,
              )
            : ref.watch(alimentacionSinServidorProvider)
            ? const EstadoVacio(
                mensaje: 'Sin menú todavía',
                detalle: 'La lista de compras saldrá del menú cuando Alimentación esté activa en tu hogar.',
                icono: Icons.shopping_cart_outlined,
              )
            : Column(
                children: [
                  SelectorMenu(
                    menus: permitidos,
                    actual: menu,
                    alElegir: (m) =>
                        ref.read(menuElegidoProvider.notifier).state = m,
                  ),
                  Expanded(
                    child: ref
                        .watch(listaComprasProvider(menu))
                        .when(
                          loading: () => const EstadoCargando(),
                          error: (_, _) => EstadoError(
                            mensaje: 'No pudimos armar la lista.',
                            alReintentar: () =>
                                ref.invalidate(listaComprasProvider(menu)),
                          ),
                          data: (items) => items.isEmpty
                              ? const EstadoVacio(
                                  mensaje: 'La lista está vacía',
                                  detalle: 'Agrega platillos al menú de la semana y aquí aparecerán los ingredientes.',
                                  icono: Icons.shopping_cart_outlined,
                                )
                              : _Contenido(menu: menu, items: items),
                        ),
                  ),
                ],
              ),
      ),
    );
  }
}

String _textoPrecio(ItemCompra i) {
  final c = i.costoCentavos;
  if (c == null) return 'Sin precio';
  return costoTexto(c, estimado: i.costoEstimado);
}

/// "12.50" o "12" -> centavos; `null` si no es un monto válido y positivo.
int? centavosDeTexto(String t) {
  final m = RegExp(r'^\s*\$?\s*(\d{1,7})(?:[.,](\d{1,2}))?\s*$').firstMatch(t);
  if (m == null) return null;
  final c = int.parse(m.group(1)!) * 100 +
      (m.group(2) == null ? 0 : int.parse(m.group(2)!.padRight(2, '0')));
  return c > 0 ? c : null;
}

Future<void> _registrar(BuildContext context, WidgetRef ref, ItemCompra i) async {
  final menu = menuEfectivo(
    ref.read(menuElegidoProvider),
    ref.read(servicioAlimentacionProvider).menusConCompras,
  );
  if (menu == null) return;
  final total = TextEditingController();
  final cantidad = TextEditingController(text: cantidadTexto(i.cantidad));
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Compra de ${i.nombre}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: cantidad,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Cantidad comprada (${i.unidad})'),
          ),
          TextField(
            controller: total,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Total pagado (pesos)'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Guardar compra'),
        ),
      ],
    ),
  );
  final centavos = centavosDeTexto(total.text);
  final cant = double.tryParse(cantidad.text.replaceAll(',', '.'));
  if (ok != true) return;
  if (centavos == null || cant == null || cant <= 0) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe una cantidad y un total válidos.')),
      );
    }
    return;
  }
  await ref
      .read(servicioAlimentacionProvider)
      .registrarCompra(
        menu,
        ref.read(semanaAlimentacionProvider),
        i.clave,
        cantidadComprada: cant,
        totalCentavos: centavos,
      );
  ref.read(versionAlimentacionProvider.notifier).state++;
}

class _Contenido extends ConsumerWidget {
  const _Contenido({required this.menu, required this.items});
  final MenuId menu;
  final List<ItemCompra> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ValoresDiseno.de(context);
    final editar = ref.watch(puedeEditarAlimentacionProvider);
    final grupos = agruparPorSeccion(items);
    final hechos = items.where((i) => i.comprado).length;
    final costo = costoDeLista(items);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '$hechos de ${items.length} comprados',
          style: v.lectura(
            tamano: 16,
            peso: FontWeight.w600,
            color: v.textoFuerte,
          ),
        ),
        if (costo != null)
          Text(
            'Costo de la lista: ${costoTexto(costo.centavos, estimado: costo.estimado)}'
            '${costo.sinPrecio > 0 ? ' · ${costo.sinPrecio} sin precio' : ''}',
            style: v.lectura(tamano: 15, color: v.texto),
          )
        else
          Text(
            'Sin precios todavía: no se calcula el costo.',
            style: v.lectura(tamano: 14, color: v.textoTenue),
          ),
        const SizedBox(height: 8),
        for (final g in grupos.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Text(
              'Pasillo · ${g.key.etiqueta}',
              style: v.titulo(tamano: 18, color: v.etiqueta),
            ),
          ),
          for (final i in g.value)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: i.comprado,
              onChanged: editar
                  ? (marca) async {
                      final semana = ref.read(semanaAlimentacionProvider);
                      await ref
                          .read(servicioAlimentacionProvider)
                          .marcar(menu, semana, i.clave, marca ?? false);
                      ref.read(versionAlimentacionProvider.notifier).state++;
                    }
                  : null,
              title: Text(
                '${i.nombre} · ${cantidadTexto(i.cantidad)} ${i.unidad}',
                style: v
                    .lectura(
                      tamano: 16,
                      color: i.comprado ? v.textoTenue : v.texto,
                    )
                    .copyWith(
                      decoration: i.comprado
                          ? TextDecoration.lineThrough
                          : null,
                    ),
              ),
              subtitle: Text(
                [
                  if (i.comprado) 'Comprado',
                  _textoPrecio(i),
                ].join(' · '),
              ),
              secondary: editar
                  ? IconButton(
                      icon: const Icon(Icons.price_check_outlined),
                      tooltip: 'Registrar compra con precio',
                      onPressed: () => _registrar(context, ref, i),
                    )
                  : null,
            ),
        ],
      ],
    );
  }
}
