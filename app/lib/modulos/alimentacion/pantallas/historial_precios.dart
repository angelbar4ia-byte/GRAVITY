/// Historial de precios: por ingrediente, sus compras reales (la más reciente
/// primero). Solo precios unitarios; nunca saldos ni cuentas.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../diseno/diseno.dart';
import '../../../nucleo/contratos/roles.dart';
import '../datos/modelos.dart';
import '../estado/proveedores.dart';

final historialPreciosProvider =
    FutureProvider<Map<String, List<CompraPrecio>>>((ref) {
      ref.watch(versionAlimentacionProvider);
      return ref.watch(servicioAlimentacionProvider).historialPorIngrediente();
    });

String _fecha(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

class PantallaHistorialPrecios extends ConsumerWidget {
  const PantallaHistorialPrecios({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TemaModulo(
      modulo: Modulo.alimentacion,
      child: Scaffold(
        appBar: AppBar(title: const Text('Historial de precios')),
        body: ref
            .watch(historialPreciosProvider)
            .when(
              loading: () => const EstadoCargando(),
              error: (_, _) => EstadoError(
                mensaje: 'No pudimos cargar el historial.',
                alReintentar: () => ref.invalidate(historialPreciosProvider),
              ),
              data: (porClave) => porClave.isEmpty
                  ? const EstadoVacio(
                      mensaje: 'Sin compras con precio todavía',
                      detalle: 'Cuando registres una compra con precio aparecerá aquí.',
                      icono: Icons.history,
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        for (final e in porClave.entries)
                          ExpansionTile(
                            key: Key('historial_${e.key}'),
                            title: Text(e.value.first.nombre),
                            subtitle: Text(
                              'Última: ${unitarioTexto(e.value.first.unitarioCentavos)} por ${e.value.first.unidad}',
                            ),
                            children: [
                              for (final c in e.value)
                                ListTile(
                                  dense: true,
                                  title: Text(
                                    '${unitarioTexto(c.unitarioCentavos)} por ${c.unidad}',
                                  ),
                                  subtitle: Text(
                                    '${_fecha(c.fecha)} · ${cantidadTexto(c.cantidad)} ${c.unidad}',
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
            ),
      ),
    );
  }
}
