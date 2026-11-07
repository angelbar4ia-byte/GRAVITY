/// Medicamentos de Papá (teléfono): horario del día; tocar una dosis para
/// marcarla como dada o no dada. Solo lectura para la hermana y la pareja.
/// La confirmación es discreta: no nombra el medicamento (pantallas de
/// bloqueo, D3).
library;

import '../../../nucleo/cuidados/turnos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/pantallas/marco_pantalla.dart';
import '../../../diseno/diseno.dart';
import '../../../nucleo/contratos/roles.dart';
import '../datos/modelos.dart';
import '../estado/proveedores.dart';
import 'comunes.dart';

class PantallaMedicamentos extends ConsumerWidget {
  const PantallaMedicamentos({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(permisosCuidadosProvider);
    final t = Theme.of(context).textTheme;
    return TemaModulo(
      modulo: Modulo.cuidados,
      child: MarcoPantalla(
        titulo: 'Medicamentos',
        cuerpo: !p.veMedicamentos
            ? const SinAccesoCuidados()
            : cuando(
                ref.watch(dosisHoyProvider),
                () => ref.invalidate(dosisHoyProvider),
                (dosis) => dosis.isEmpty
                    ? const EstadoVacio(
                        mensaje: 'Sin medicamentos para hoy',
                        icono: Icons.medication_outlined,
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Text(
                            p.marcaTomaA(
                                  cuidadorDeTurno(
                                    ref.watch(relojDeCuidados),
                                  ),
                                )
                                ? 'Toca una dosis para marcarla.'
                                : 'Solo lectura.',
                            style: t.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          for (final d in dosis)
                            _FilaDosis(
                              dosis: d,
                              puedeMarcar: p.marcaTomaA(
                                cuidadorDeTurno(ref.watch(relojDeCuidados)),
                              ),
                              ahora: ref.watch(relojDeCuidados),
                            ),
                        ],
                      ),
              ),
      ),
    );
  }
}

class _FilaDosis extends ConsumerWidget {
  const _FilaDosis({
    required this.dosis,
    required this.puedeMarcar,
    required this.ahora,
  });

  final Dosis dosis;
  final bool puedeMarcar;
  final DateTime ahora;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final retrasada =
        dosis.estado == EstadoToma.pendiente &&
        dosis.hora.isBefore(ahora.subtract(const Duration(minutes: 30)));
    final (icono, texto) = switch (dosis.estado) {
      EstadoToma.dado => (Icons.check_circle, 'Ya se dio'),
      EstadoToma.noDado => (Icons.cancel_outlined, 'No se dio'),
      EstadoToma.pendiente => (
        Icons.schedule,
        retrasada ? 'Pendiente · pasó la hora' : 'Pendiente',
      ),
    };
    return Card(
      child: ListTile(
        minVerticalPadding: 16,
        leading: Icon(icono, size: 36),
        title: Text(
          '${horaTexto(dosis.hora)} · ${dosis.medicamento.nombre}',
          style: t.titleLarge,
        ),
        subtitle: Text(
          '${dosis.medicamento.dosis}\n$texto',
          style: t.titleMedium,
        ),
        isThreeLine: true,
        onTap: puedeMarcar ? () => _marcar(context, ref) : null,
      ),
    );
  }

  Future<void> _marcar(BuildContext context, WidgetRef ref) async {
    final dado = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            Text(
              'Dosis de las ${horaTexto(dosis.hora)}',
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
            BotonGrande(
              texto: 'Ya se dio',
              icono: Icons.check,
              onPressed: () => Navigator.pop(ctx, true),
            ),
            BotonGrande(
              texto: 'No se dio',
              icono: Icons.close,
              tonal: true,
              onPressed: () => Navigator.pop(ctx, false),
            ),
          ],
        ),
      ),
    );
    if (dado == null || !context.mounted) return;
    await ejecutarCuidados(
      context,
      ref,
      () => ref.read(servicioCuidadosProvider).marcarToma(dosis, dado: dado),
      ok: dado ? 'Registrado' : 'Registrado como no dado',
    );
  }
}
