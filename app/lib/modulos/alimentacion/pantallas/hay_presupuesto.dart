/// "¿Hay presupuesto para comprar?": responde solo sí o no. Nunca muestra
/// saldos, cuentas ni montos del presupuesto (spec Fase 7, v1.1).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../diseno/diseno.dart';
import '../estado/proveedores.dart';

class TarjetaHayPresupuesto extends ConsumerWidget {
  const TarjetaHayPresupuesto({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(servicioAlimentacionProvider).puedeVerPresupuesto) {
      return const SizedBox.shrink();
    }
    final v = ValoresDiseno.de(context);
    final r = ref.watch(hayPresupuestoProvider);
    final texto = r.when(
      loading: () => '...',
      error: (_, _) => 'No pudimos consultarlo.',
      data: (b) => switch (b) {
        true => 'Sí',
        false => 'No',
        null => 'Sin respuesta todavía',
      },
    );
    return Semantics(
      label: '¿Hay presupuesto para comprar? $texto',
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '¿Hay presupuesto para comprar?',
                  style: v.lectura(tamano: 16, color: v.texto),
                ),
              ),
              Text(
                texto,
                style: v.titulo(tamano: 18, color: v.textoFuerte),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
