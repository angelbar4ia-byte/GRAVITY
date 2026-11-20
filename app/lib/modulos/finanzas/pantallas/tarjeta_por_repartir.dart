/// Tarjeta «Por repartir» (teléfono y laptop): los ingresos del libro activo
/// que aún no se reparten, con su estado, su monto y los botones **Repartir**
/// y **Cambiar tipo…** (`docs/specs/fase-8-finanzas-dispersion.md`).
///
/// No dibuja nada si no hay nada pendiente. Los botones solo aparecen con
/// permiso de escribir. Con los montos ocultos no hay cifras ni en el texto ni
/// en el lector de pantalla (`Monto` respeta el modo privado).
library;

import 'dart:async';

import 'package:finanzas_dominio/finanzas_dominio.dart'
    hide Semaforo, formatearCentavos, TipoLibro, puntosBaseEnCien;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../diseno/diseno.dart';
import '../estado/proveedores.dart';
import '../estado/proveedores_dispersion.dart';
import 'comunes.dart';
import 'dialogo_cambiar_tipo.dart';
import 'fila_texto_monto.dart';
import 'registro/hoja_repartir_ingreso.dart';

String textoEstadoDispersion(IngresoPorRepartir i) => switch (i.estado) {
  EstadoDispersion.porRepartir => 'Por repartir',
  EstadoDispersion.propuesta => 'Propuesta',
  EstadoDispersion.confirmada => 'Confirmado · queda por repartir',
  EstadoDispersion.automatica => 'Automático · queda por repartir',
  EstadoDispersion.anulada => 'Anulado',
  EstadoDispersion.reemplazada => 'Reemplazado',
};

class TarjetaPorRepartir extends ConsumerStatefulWidget {
  const TarjetaPorRepartir({super.key});

  @override
  ConsumerState<TarjetaPorRepartir> createState() => _TarjetaPorRepartirState();
}

class _TarjetaPorRepartirState extends ConsumerState<TarjetaPorRepartir> {
  String? _automaticoRevisado;

  /// Modo automático (decisión 1): al ver la tarjeta, asigna lo comprometido
  /// de los ingresos que cubren todo. Una vez por libro y sesión.
  void _revisarAutomaticos(ContextoFinanzas c) {
    if (_automaticoRevisado == c.libroId || !c.puedeEscribir) return;
    _automaticoRevisado = c.libroId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref
            .read(servicioDispersionProvider)
            .aplicarAutomaticas(c.libroId)
            .then((_) => 0, onError: (_) => 0),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(contextoFinanzasProvider).value;
    if (c == null || c.libro == null || !c.permiso.leer) {
      return const SizedBox.shrink();
    }
    _revisarAutomaticos(c);
    final pendientes = ref.watch(ingresosPendientesProvider);
    if (pendientes.isEmpty) return const SizedBox.shrink();
    final total = pendientes.fold<int>(0, (t, i) => t + i.pendiente);
    final tema = Theme.of(context);
    return TarjetaModulo(
      key: const ValueKey('finanzas-por-repartir'),
      titulo: 'Por repartir',
      icono: Icons.call_split,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilaTextoMonto(
            texto: 'Total por repartir',
            monto: Monto(
              total,
              key: const ValueKey('por-repartir-total'),
              estilo: tema.textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 4),
          for (final i in pendientes)
            Padding(
              key: ValueKey('por-repartir-${i.movimientoId}'),
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilaTextoMonto(
                    texto: '${i.nombre} · ${textoFecha(i.fecha)}',
                    monto: Monto(i.pendiente),
                  ),
                  Text(
                    textoEstadoDispersion(i),
                    key: ValueKey('por-repartir-estado-${i.movimientoId}'),
                    style: tema.textTheme.bodySmall,
                  ),
                  if (c.puedeEscribir)
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton.tonal(
                          key: ValueKey(
                            'por-repartir-repartir-${i.movimientoId}',
                          ),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(48, 48),
                          ),
                          onPressed: () => mostrarHojaRepartir(
                            context,
                            libroId: c.libroId,
                            movimientoId: i.movimientoId,
                          ),
                          child: Text(
                            i.estado.aplicada ? 'Cambiar reparto' : 'Repartir',
                          ),
                        ),
                        TextButton(
                          key: ValueKey('por-repartir-tipo-${i.movimientoId}'),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(48, 48),
                          ),
                          onPressed: () => mostrarDialogoCambiarTipo(
                            context,
                            movimientoId: i.movimientoId,
                          ),
                          child: const Text('Cambiar tipo…'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
