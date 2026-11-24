/// La tarjeta del aviso del banco (spec 3.2, G6-M3): sale **una sola vez por
/// persona**, antes de la primera sesión que usa el banco, y se confirma con
/// *Ya lo revisé*. Sin diagnóstico y sin culpa; no impide empezar.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../diseno/valores_diseno.dart';
import '../casos_uso/aviso_banco.dart';
import '../datos/modelos_gimnasio.dart';
import '../estado/proveedores_gimnasio.dart';
import 'comun.dart';

class TarjetaAvisoBanco extends ConsumerWidget {
  const TarjetaAvisoBanco({super.key, required this.h});

  final EntrenamientoHoy h;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicio = ref.watch(servicioGimnasioProvider);
    final sesion = h.sesion;
    if (servicio == null || !h.esFuerza || sesion == null) {
      return const SizedBox.shrink();
    }
    if (!sesionUsaBanco(sesion, servicio.catalogo)) {
      return const SizedBox.shrink();
    }
    final revisado = ref.watch(avisoBancoRevisadoProvider).value ?? true;
    if (revisado) return const SizedBox.shrink();
    final v = ValoresDiseno.de(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        key: const ValueKey('aviso-banco'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: v.alerta),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 20, color: v.alerta),
                const SizedBox(width: 8),
                const Expanded(child: Text(TextosHabitosGimnasio.avisoBanco)),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton(
                key: const ValueKey('aviso-banco-revise'),
                onPressed: () async {
                  await ref
                      .read(avisoBancoLocalProvider)
                      ?.marcarRevisado(servicio.ahora);
                  ref.invalidate(avisoBancoRevisadoProvider);
                },
                style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
                child: const Text(TextosHabitosGimnasio.yaLoRevise),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
