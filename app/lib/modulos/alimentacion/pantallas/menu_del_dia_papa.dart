/// Tarjeta del menú del día de Papá para la cuenta Casa (D28): solo los
/// nombres de los platillos de hoy. Sin perfil clínico (D3), sin suplementos,
/// sin alimentos duros y sin ingredientes.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../diseno/diseno.dart';
import '../estado/proveedores.dart';

class TarjetaMenuDelDiaPapa extends ConsumerWidget {
  const TarjetaMenuDelDiaPapa({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ValoresDiseno.de(context);
    return ref
        .watch(menuDelDiaPapaProvider)
        .when(
          loading: () => const EstadoCargando(),
          error: (_, _) => const EstadoVacio(
            mensaje: 'No hay menú de hoy para mostrar',
            icono: Icons.restaurant_menu_outlined,
          ),
          data: (comidas) => comidas.isEmpty
              ? const EstadoVacio(
                  mensaje: 'Sin menú para hoy',
                  icono: Icons.restaurant_menu_outlined,
                )
              : Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Menú de hoy',
                          style: v.titulo(tamano: 20, color: v.textoFuerte),
                        ),
                        const SizedBox(height: 8),
                        for (final c in comidas)
                          Text(
                            '${c.tiempo.etiqueta}: ${c.platillo}',
                            style: v.lectura(tamano: 18, color: v.texto),
                          ),
                      ],
                    ),
                  ),
                ),
        );
  }
}
