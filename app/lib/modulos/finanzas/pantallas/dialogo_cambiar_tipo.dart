/// «Cambiar tipo…» de un ingreso (decisión 4 del dueño): pasa un ingreso
/// registrado como extra a un ingreso configurado (sueldo) o al revés, con
/// anulación y contraasiento y sin perder el historial
/// (`docs/specs/fase-8-finanzas-dispersion.md`).
library;

import 'package:finanzas_dominio/finanzas_dominio.dart'
    hide Semaforo, formatearCentavos, TipoLibro, puntosBaseEnCien;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../estado/proveedores.dart';
import '../estado/proveedores_dispersion.dart';
import 'comunes.dart';

/// `true` si el movimiento es un ingreso confirmado y sin anular del que se
/// puede cambiar el tipo con el permiso de la persona.
bool sePuedeCambiarTipo(
  Movimiento m,
  LibroMovimientos vista,
  ContextoFinanzas c,
) =>
    c.puedeEscribir &&
    m.tipo == TipoMovimiento.ingreso &&
    vista.contraasientoDe(m.id) == null &&
    vista.estadoDe(m.id) == EstadoMovimiento.confirmado;

/// Pide el tipo nuevo y el motivo, y corrige. Devuelve `true` si se corrigió.
Future<bool> mostrarDialogoCambiarTipo(
  BuildContext context, {
  required String movimientoId,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (_) => DialogoCambiarTipo(movimientoId: movimientoId),
  );
  return r ?? false;
}

class DialogoCambiarTipo extends ConsumerStatefulWidget {
  const DialogoCambiarTipo({super.key, required this.movimientoId});

  final String movimientoId;

  @override
  ConsumerState<DialogoCambiarTipo> createState() => _DialogoState();
}

class _DialogoState extends ConsumerState<DialogoCambiarTipo> {
  String? _cuentaId;
  bool _guardando = false;
  final _motivo = TextEditingController();

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    final navegador = Navigator.of(context);
    final mensajero = ScaffoldMessenger.maybeOf(context);
    try {
      await ref
          .read(servicioDispersionProvider)
          .cambiarTipo(
            movimientoId: widget.movimientoId,
            cuentaOrigenId: _cuentaId!,
            motivo: _motivo.text,
          );
      mensajero?.showSnackBar(
        const SnackBar(
          content: Text(
            'Listo: cambié el tipo. El original queda anulado en el '
            'historial.',
          ),
        ),
      );
      navegador.pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        avisarError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(contextoFinanzasProvider).value;
    final m = c?.datos.movimientos
        .where((x) => x.id == widget.movimientoId)
        .firstOrNull;
    if (c == null || m == null) {
      return const AlertDialog(content: Text('No encuentro ese ingreso.'));
    }
    final libroId = c.datos.cuenta(m.cuentaDestinoId)?.libroId;
    final configuradas = {
      for (final i in c.datos.ingresosDe(libroId ?? '')) i.cuentaOrigenId: i,
    };
    // Los tipos posibles: cada ingreso configurado del libro y "Ingreso
    // extra", menos el actual.
    final opciones = <(String cuentaId, String texto)>[
      for (final i in configuradas.values)
        if (i.cuentaOrigenId != m.cuentaOrigenId)
          (i.cuentaOrigenId, '${i.nombre} (ingreso configurado)'),
      for (final x in c.datos.cuentasDe(libroId ?? ''))
        if (x.tipo == TipoCuenta.origenIngreso &&
            x.estado == EstadoCuenta.activa &&
            !configuradas.containsKey(x.id) &&
            x.id != m.cuentaOrigenId)
          (x.id, 'Ingreso extra'),
    ];
    final repartido = ref
        .watch(dispersionesProvider)
        .any((x) => x.movimientoId == m.id && x.estado.aplicada);
    final puede =
        _cuentaId != null && motivoValido(_motivo.text) && !_guardando;
    return AlertDialog(
      title: const Text('Cambiar tipo de ingreso'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hoy es «${c.datos.cuenta(m.cuentaOrigenId)?.nombre ?? 'ingreso'}». '
              'No se borra nada: se anula el original y se registra uno '
              'nuevo con la misma fecha y monto.',
            ),
            if (repartido) ...[
              const SizedBox(height: 8),
              const Text(
                'Este ingreso ya está repartido: al cambiar el tipo se '
                'deshace su reparto (se anulan los movimientos que creó) y el '
                'ingreso nuevo queda por repartir.',
                key: ValueKey('cambiar-tipo-repartido'),
              ),
            ],
            const SizedBox(height: 8),
            if (opciones.isEmpty)
              const Text(
                'No hay otro tipo de ingreso en este libro.',
                key: ValueKey('cambiar-tipo-vacio'),
              ),
            RadioGroup<String>(
              groupValue: _cuentaId,
              onChanged: (v) => setState(() => _cuentaId = v),
              child: Column(
                children: [
                  for (final (id, texto) in opciones)
                    RadioListTile<String>(
                      key: ValueKey('cambiar-tipo-$id'),
                      value: id,
                      title: Text(texto),
                    ),
                ],
              ),
            ),
            TextField(
              key: const ValueKey('cambiar-tipo-motivo'),
              controller: _motivo,
              maxLength: 200,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Motivo (obligatorio)',
                helperText: ayudaDelMotivo,
                helperMaxLines: 3,
                errorText: errorDeMotivo(_motivo.text),
                errorMaxLines: 3,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const ValueKey('cambiar-tipo-guardar'),
          onPressed: puede ? _guardar : null,
          child: const Text('Cambiar'),
        ),
      ],
    );
  }
}
