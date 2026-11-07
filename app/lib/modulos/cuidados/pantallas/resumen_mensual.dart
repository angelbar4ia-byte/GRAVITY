/// Resumen mensual del costo del cuidado. El dueño lo ve completo; la hermana
/// solo lectura, con autorización del albacea y **sin montos de la pareja ni
/// del dueño** (spec, sección 4).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/pantallas/marco_pantalla.dart';
import '../../../diseno/diseno.dart';
import '../../../nucleo/contratos/roles.dart';
import '../estado/proveedores.dart';
import 'comunes.dart';

class PantallaResumenMensual extends ConsumerWidget {
  const PantallaResumenMensual({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(permisosCuidadosProvider);
    final mes = ref.watch(mesResumenProvider);
    final t = Theme.of(context).textTheme;
    return TemaModulo(
      modulo: Modulo.cuidados,
      child: MarcoPantalla(
        titulo: 'Resumen del mes',
        cuerpo: !p.veResumen
            ? const SinAccesoCuidados()
            : !p.resumenDisponible
            ? const SinAccesoCuidados(
                detalle:
                    'El resumen se verá cuando quien administra lo autorice.',
              )
            : Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        tooltip: 'Mes anterior',
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () =>
                            ref.read(mesResumenProvider.notifier).state =
                                DateTime(mes.year, mes.month - 1),
                      ),
                      Flexible(
                        child: Text(
                          mesTexto(mes),
                          style: t.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Mes siguiente',
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () =>
                            ref.read(mesResumenProvider.notifier).state =
                                DateTime(mes.year, mes.month + 1),
                      ),
                    ],
                  ),
                  Expanded(
                    child: cuando(
                      ref.watch(resumenMensualProvider),
                      () => ref.invalidate(resumenMensualProvider),
                      (r) => r == null || r.lineas.isEmpty
                          ? const EstadoVacio(
                              mensaje: 'Sin gastos en este mes',
                              icono: Icons.summarize_outlined,
                            )
                          : ListView(
                              padding: const EdgeInsets.all(16),
                              children: [
                                for (final l in r.lineas)
                                  ListTile(
                                    title: Text(l.concepto),
                                    trailing: Text(
                                      formatearCentavos(l.centavos),
                                      style: t.titleMedium,
                                    ),
                                  ),
                                const Divider(),
                                ListTile(
                                  title: Text('Total', style: t.titleLarge),
                                  trailing: Text(
                                    formatearCentavos(r.totalCentavos),
                                    style: t.titleLarge,
                                  ),
                                ),
                                if (!p.administra)
                                  const Padding(
                                    padding: EdgeInsets.all(8),
                                    child: Text(
                                      'Solo lectura. No incluye gastos personales de la familia.',
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
