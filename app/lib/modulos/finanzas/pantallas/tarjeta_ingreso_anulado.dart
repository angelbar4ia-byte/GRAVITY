/// Tarjeta «Ingreso anulado con reparto» (teléfono y laptop, junto a «Por
/// repartir»; hallazgo H-03, decisión del dueño del 20/nov/2026, opción B con
/// alternativa A; `docs/specs/fase-8-finanzas-dispersion.md`).
///
/// Cuando se anuló un ingreso que ya estaba repartido, los movimientos que creó
/// el reparto (abono extra y ahorro) **siguen vigentes**. La app **no deshace
/// nada sola**: avisa con claridad y la persona elige:
/// - **Deshacer reparto:** anula con contraasiento y motivo esos movimientos
///   (en el libro de Papá pide el motivo y va en su nombre). Necesita señal.
/// - **Dejarlo así:** descarta el aviso de ese reparto sin tocar dinero y no
///   vuelve a salir. Necesita señal (se guarda en el servidor).
///
/// **Sin cifras:** no muestra ni dice montos (ni en el lector de pantalla),
/// estén ocultos o no. Los botones solo aparecen con permiso de escribir.
library;

import 'dart:async';

import 'package:finanzas_dominio/finanzas_dominio.dart'
    as dom
    show TipoLibro, ayudaDelMotivo;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../diseno/diseno.dart';
import '../casos_uso/servicio_dispersion.dart';
import '../estado/proveedores.dart';
import '../estado/proveedores_dispersion.dart';
import 'comunes.dart';

/// El texto de la tarjeta (el mismo que dijo el dueño).
const textoIngresoAnuladoConReparto =
    'Anulaste un ingreso que ya estaba repartido. '
    'Los movimientos del reparto siguen vigentes.';

class TarjetaIngresoAnuladoConReparto extends ConsumerStatefulWidget {
  const TarjetaIngresoAnuladoConReparto({super.key});

  @override
  ConsumerState<TarjetaIngresoAnuladoConReparto> createState() =>
      _TarjetaIngresoAnuladoState();
}

class _TarjetaIngresoAnuladoState
    extends ConsumerState<TarjetaIngresoAnuladoConReparto> {
  /// Claves del aviso que ya se intentaron en esta pantalla (el servidor
  /// tampoco duplica).
  final Set<String> _avisados = {};
  final Set<String> _ocupados = {};

  void _emitirAvisos(String libroId, List<RepartoAnuladoPendiente> lista) {
    final nuevos = [
      for (final r in lista)
        if (!_avisados.contains(claveAvisoRepartoAnulado(r.movimientoId))) r,
    ];
    if (nuevos.isEmpty) return;
    _avisados.addAll([
      for (final r in nuevos) claveAvisoRepartoAnulado(r.movimientoId),
    ]);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref
            .read(servicioDispersionProvider)
            .emitirAvisosRepartosAnulados(libroId)
            .then((hechas) {
              // Sin señal no se encola: se vuelve a intentar al ver la tarjeta.
              for (final r in nuevos) {
                final c = claveAvisoRepartoAnulado(r.movimientoId);
                if (!hechas.contains(c)) _avisados.remove(c);
              }
            }, onError: (Object _) {}),
      );
    });
  }

  Future<void> _deshacer(
    RepartoAnuladoPendiente r, {
    required bool representado,
    required String nombreLibro,
  }) async {
    String? motivo;
    if (representado) {
      motivo = await pedirTexto(
        context,
        titulo: 'Deshacer el reparto',
        etiqueta: 'Motivo (obligatorio)',
        ayuda: '${dom.ayudaDelMotivo} Se registra en nombre de $nombreLibro.',
        textoAccion: 'Deshacer reparto',
        esMotivo: true,
      );
      if (motivo == null) return;
    }
    if (!mounted) return;
    final mensajero = ScaffoldMessenger.maybeOf(context);
    final servicio = ref.read(servicioDispersionProvider);
    setState(() => _ocupados.add(r.dispersionId));
    try {
      await servicio.deshacerRepartoAnulado(r.dispersionId, motivo: motivo);
      mensajero?.showSnackBar(
        const SnackBar(
          content: Text(
            'Listo: deshice el reparto. Los movimientos quedaron anulados y '
            'el historial se conserva.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) avisarError(context, e);
    } finally {
      if (mounted) setState(() => _ocupados.remove(r.dispersionId));
    }
  }

  Future<void> _dejarAsi(RepartoAnuladoPendiente r) async {
    final mensajero = ScaffoldMessenger.maybeOf(context);
    final servicio = ref.read(servicioDispersionProvider);
    setState(() => _ocupados.add(r.dispersionId));
    try {
      await servicio.dejarRepartoAnulado(r.dispersionId);
      mensajero?.showSnackBar(
        const SnackBar(
          content: Text('Listo: lo dejé así. No volveré a avisarte de este.'),
        ),
      );
    } catch (e) {
      if (mounted) avisarError(context, e);
    } finally {
      if (mounted) setState(() => _ocupados.remove(r.dispersionId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(contextoFinanzasProvider).value;
    if (c == null || c.libro == null || !c.permiso.leer) {
      return const SizedBox.shrink();
    }
    final pendientes = ref.watch(repartosAnuladosPendientesProvider);
    if (pendientes.isEmpty) return const SizedBox.shrink();
    if (c.puedeEscribir) _emitirAvisos(c.libroId, pendientes);
    final tema = Theme.of(context);
    final representado = c.libro!.tipo == dom.TipoLibro.representado;
    return TarjetaModulo(
      key: const ValueKey('finanzas-ingreso-anulado-reparto'),
      titulo: 'Ingreso anulado con reparto',
      icono: Icons.report_problem_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            textoIngresoAnuladoConReparto,
            key: const ValueKey('anulado-texto'),
            style: tema.textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          for (final r in pendientes)
            Padding(
              key: ValueKey('anulado-${r.dispersionId}'),
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    [
                      if (r.nombre.isNotEmpty) r.nombre else 'Ingreso',
                      if (r.fecha != null) textoFecha(r.fecha!),
                    ].join(' · '),
                    key: ValueKey('anulado-nombre-${r.dispersionId}'),
                    style: tema.textTheme.titleSmall,
                  ),
                  if (c.puedeEscribir)
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton.tonal(
                          key: ValueKey('anulado-deshacer-${r.dispersionId}'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(48, 48),
                          ),
                          onPressed: _ocupados.contains(r.dispersionId)
                              ? null
                              : () => _deshacer(
                                  r,
                                  representado: representado,
                                  nombreLibro: c.libro!.nombre,
                                ),
                          child: const Text('Deshacer reparto'),
                        ),
                        TextButton(
                          key: ValueKey('anulado-dejar-${r.dispersionId}'),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(48, 48),
                          ),
                          onPressed: _ocupados.contains(r.dispersionId)
                              ? null
                              : () => _dejarAsi(r),
                          child: const Text('Dejarlo así'),
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
