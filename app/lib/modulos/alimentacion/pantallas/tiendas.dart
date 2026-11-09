/// Lista de tiendas del hogar (Fase 8, 2b): editar el nombre y borrar. Dueño
/// y pareja. Una tienda con compras no se borra: el servidor la desactiva y
/// la pantalla lo dice.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../diseno/diseno.dart';
import '../../../nucleo/contratos/roles.dart';
import '../datos/modelos.dart';
import '../estado/proveedores.dart';

class PantallaTiendas extends ConsumerWidget {
  const PantallaTiendas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editar = ref.watch(puedeEditarAlimentacionProvider);
    return TemaModulo(
      modulo: Modulo.alimentacion,
      child: Scaffold(
        appBar: AppBar(title: const Text('Tiendas')),
        body: ref
            .watch(tiendasProvider)
            .when(
              loading: () => const EstadoCargando(),
              error: (_, _) => EstadoError(
                mensaje: 'No pudimos cargar las tiendas.',
                alReintentar: () => ref.invalidate(tiendasProvider),
              ),
              data: (tiendas) => tiendas.isEmpty
                  ? const EstadoVacio(
                      mensaje: 'Sin tiendas todavía',
                      detalle:
                          'Agrega una al registrar una compra con precio.',
                      icono: Icons.storefront_outlined,
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        for (final t in tiendas)
                          ListTile(
                            key: Key('tienda_${t.id}'),
                            contentPadding: EdgeInsets.zero,
                            title: Text(t.nombre),
                            subtitle: t.activa ? null : const Text('Desactivada'),
                            trailing: editar
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        key: Key('editar_tienda_${t.id}'),
                                        icon: const Icon(Icons.edit_outlined),
                                        tooltip: 'Editar nombre',
                                        onPressed: () => _editar(context, ref, t),
                                      ),
                                      IconButton(
                                        key: Key('borrar_tienda_${t.id}'),
                                        icon: const Icon(Icons.delete_outline),
                                        tooltip: 'Borrar tienda',
                                        onPressed: () => _borrar(context, ref, t),
                                      ),
                                    ],
                                  )
                                : null,
                          ),
                      ],
                    ),
            ),
      ),
    );
  }
}

void _aviso(BuildContext context, String texto) {
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }
}

Future<void> _editar(BuildContext context, WidgetRef ref, Tienda t) async {
  final nombre = TextEditingController(text: t.nombre);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Editar tienda'),
      content: TextField(
        key: const Key('nombre_tienda'),
        controller: nombre,
        maxLength: maxCaracteresTienda,
        decoration: const InputDecoration(labelText: 'Nombre de la tienda'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('guardar_tienda'),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  try {
    await ref
        .read(servicioAlimentacionProvider)
        .editarTienda(t.id, nombre.text);
    ref.read(versionAlimentacionProvider.notifier).state++;
  } catch (e) {
    if (!context.mounted) return;
    _aviso(
      context,
      e is ArgumentError
          ? 'El nombre de la tienda lleva de 1 a $maxCaracteresTienda caracteres.'
          : 'No se guardó la tienda: $e',
    );
  }
}

Future<void> _borrar(BuildContext context, WidgetRef ref, Tienda t) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('¿Borrar ${t.nombre}?'),
      content: const Text(
        'Si la tienda tiene compras no se borra: se desactiva y el historial '
        'la conserva.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('confirmar_borrar_tienda'),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Borrar'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  try {
    final r = await ref.read(servicioAlimentacionProvider).borrarTienda(t.id);
    ref.read(versionAlimentacionProvider.notifier).state++;
    if (!context.mounted) return;
    _aviso(context, r.mensaje);
  } catch (e) {
    if (!context.mounted) return;
    _aviso(context, 'No se borró la tienda: $e');
  }
}
