/// Lista de compras de la semana, agrupada por sección. Sin precios.
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

class PantallaListaCompras extends ConsumerWidget {
  const PantallaListaCompras({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => TemaModulo(
    modulo: Modulo.alimentacion,
    child: MarcoPantalla(
      titulo: 'Lista de compras',
      rutaAnterior: Rutas.alimentacion,
      cuerpo: ref
          .watch(listaComprasProvider)
          .when(
            loading: () => const EstadoCargando(),
            error: (_, _) => EstadoError(
              mensaje: 'No pudimos armar la lista.',
              alReintentar: () => ref.invalidate(listaComprasProvider),
            ),
            data: (items) => items.isEmpty
                ? const EstadoVacio(
                    mensaje: 'La lista está vacía',
                    detalle: 'Agrega platillos al menú de la semana y aquí aparecerán los ingredientes.',
                    icono: Icons.shopping_cart_outlined,
                  )
                : _Contenido(items: items),
          ),
    ),
  );
}

class _Contenido extends ConsumerWidget {
  const _Contenido({required this.items});
  final List<ItemCompra> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ValoresDiseno.de(context);
    final editar = ref.watch(puedeEditarAlimentacionProvider);
    final grupos = agruparPorSeccion(items);
    final hechos = items.where((i) => i.comprado).length;
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
        const SizedBox(height: 8),
        for (final g in grupos.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Text(
              g.key.etiqueta,
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
                          .marcar(semana, i.clave, marca ?? false);
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
              subtitle: i.comprado ? const Text('Comprado') : null,
            ),
        ],
      ],
    );
  }
}
