/// Compras de Papá pendientes de pago. Solo la ve el albacea (la suplente y el
/// resto no): aprueba con una cuenta del libro de Papá o rechaza con motivo.
/// No muestra saldos, solo lo comprado y su monto.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/pantallas/marco_pantalla.dart';
import '../../../diseno/diseno.dart';
import '../../../nucleo/contratos/roles.dart';
import '../../../nucleo/contratos/rutas.dart';
import '../casos_uso/servicio_alimentacion.dart' show PermisoDenegado, ServicioAlimentacion;
import '../datos/modelos.dart';
import '../estado/proveedores.dart';

class PantallaSolicitudesPapa extends ConsumerWidget {
  const PantallaSolicitudesPapa({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TemaModulo(
      modulo: Modulo.alimentacion,
      child: MarcoPantalla(
        titulo: 'Pagos pendientes de Papá',
        rutaAnterior: Rutas.alimentacion,
        cuerpo: ref
            .watch(solicitudesPapaProvider)
            .when(
              loading: () => const EstadoCargando(),
              error: (e, _) => e is PermisoDenegado
                  ? const EstadoVacio(
                      mensaje: 'Solo el albacea ve estos pagos',
                      icono: Icons.lock_outline,
                    )
                  : EstadoError(
                      mensaje: 'No pudimos cargar los pagos.',
                      alReintentar: () => ref.invalidate(solicitudesPapaProvider),
                    ),
              data: (lista) => lista.isEmpty
                  ? const EstadoVacio(
                      mensaje: 'Nada pendiente',
                      detalle: 'Las compras de Papá por pagar aparecerán aquí.',
                      icono: Icons.check_circle_outline,
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        for (final s in lista) _Tarjeta(solicitud: s),
                      ],
                    ),
            ),
      ),
    );
  }
}

class _Tarjeta extends ConsumerWidget {
  const _Tarjeta({required this.solicitud});
  final SolicitudPago solicitud;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        title: Text(
          '${solicitud.ingrediente} · ${cantidadTexto(solicitud.cantidad)} ${solicitud.unidad}',
        ),
        subtitle: Text(costoTexto(solicitud.montoCentavos, estimado: false)),
        trailing: Wrap(
          children: [
            IconButton(
              key: Key('rechazar_${solicitud.id}'),
              icon: const Icon(Icons.close),
              tooltip: 'Rechazar',
              onPressed: () => _rechazar(context, ref),
            ),
            IconButton(
              key: Key('aprobar_${solicitud.id}'),
              icon: const Icon(Icons.check),
              tooltip: 'Aprobar y pagar',
              onPressed: () => _aprobar(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _aprobar(BuildContext context, WidgetRef ref) async {
    final servicio = ref.read(servicioAlimentacionProvider);
    final cuentas = await servicio.cuentasDelLibroDePapa();
    if (!context.mounted) return;
    if (cuentas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El libro de Papá no tiene cuentas para pagar.')),
      );
      return;
    }
    String? elegida = ServicioAlimentacion.cuentaEfectiva(cuentas, null)?.id;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pagar con'),
        content: StatefulBuilder(
          builder: (ctx, setState) => DropdownButtonFormField<String>(
            key: const Key('cuenta_papa'),
            initialValue: elegida,
            items: [
              for (final c in cuentas)
                DropdownMenuItem(value: c.id, child: Text(c.nombre)),
            ],
            onChanged: (c) => setState(() => elegida = c),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Aprobar'),
          ),
        ],
      ),
    );
    if (ok != true || elegida == null || !context.mounted) return;
    await _resolver(
      context,
      ref,
      () => servicio.aprobarSolicitud(solicitud.id, cuentaPagoId: elegida!),
    );
  }

  Future<void> _rechazar(BuildContext context, WidgetRef ref) async {
    final motivo = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rechazar compra'),
        content: TextField(
          key: const Key('motivo_rechazo'),
          controller: motivo,
          maxLength: 200,
          decoration: const InputDecoration(labelText: 'Motivo (3 caracteres o más)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await _resolver(
      context,
      ref,
      () => ref
          .read(servicioAlimentacionProvider)
          .rechazarSolicitud(solicitud.id, motivo: motivo.text),
    );
  }

  Future<void> _resolver(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() accion,
  ) async {
    try {
      await accion();
      ref.read(versionAlimentacionProvider.notifier).state++;
    } on ArgumentError {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Escribe un motivo de al menos 3 caracteres.')),
        );
      }
    } on Exception catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se resolvió: $e')),
        );
      }
    }
  }
}
