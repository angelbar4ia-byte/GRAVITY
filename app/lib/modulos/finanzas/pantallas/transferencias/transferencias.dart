/// Transferencias entre personas (Fase 8, bloque 1): proponer por una de las
/// tres rutas permitidas y confirmar o rechazar las que llegan. Nada se mueve
/// sin que el receptor toque el botón.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../diseno/diseno.dart';
import '../../datos/transferencias.dart';
import '../../estado/proveedores_transferencias.dart';
import '../comunes.dart';
import '../laptop/marco_laptop.dart';

class PantallaTransferencias extends StatelessWidget {
  const PantallaTransferencias({super.key});

  @override
  Widget build(BuildContext context) => MarcoFinanzasLaptop(
    seccion: SeccionFinanzas.transferencias,
    builder: (context, c) => CuerpoTransferencias(personaId: c.personaId),
  );
}

class CuerpoTransferencias extends ConsumerWidget {
  const CuerpoTransferencias({super.key, required this.personaId});

  final String personaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lista = ref.watch(transferenciasProvider);
    final parte = ref.watch(parteTransferenciaProvider);
    final rutas = rutasQueOfrece(parte);
    return ContenidoLaptop(
      children: [
        if (rutas.isEmpty)
          const Text(
            'Tu rol no propone transferencias.',
            key: ValueKey('transf-sin-rutas'),
          )
        else
          FormularioTransferencia(rutas: rutas),
        lista.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => const Text(
            'No se pudo consultar. Revisa tu conexión.',
            key: ValueKey('transf-error'),
          ),
          data: (todas) => _Listas(todas: todas, personaId: personaId),
        ),
      ],
    );
  }
}

/// Proponer: ruta, monto y nota corta.
class FormularioTransferencia extends ConsumerStatefulWidget {
  const FormularioTransferencia({super.key, required this.rutas});

  final List<RutaTransferencia> rutas;

  @override
  ConsumerState<FormularioTransferencia> createState() => _EstadoFormulario();
}

class _EstadoFormulario extends ConsumerState<FormularioTransferencia> {
  final _monto = TextEditingController();
  final _nota = TextEditingController();
  late RutaTransferencia _ruta = widget.rutas.first;
  bool _enviando = false;

  @override
  void dispose() {
    _monto.dispose();
    _nota.dispose();
    super.dispose();
  }

  Future<void> _proponer() async {
    final centavos = centavosDeTexto(_monto.text);
    final error = errorAlProponer(centavos, _nota.text);
    if (error != null) {
      avisar(context, error);
      return;
    }
    setState(() => _enviando = true);
    final ok = await intentar(
      context,
      () => ref
          .read(transferenciasProvider.notifier)
          .proponer(ruta: _ruta, montoCentavos: centavos!, nota: _nota.text),
    );
    if (!mounted) return;
    setState(() => _enviando = false);
    if (ok) {
      _monto.clear();
      _nota.clear();
      avisar(context, 'Propuesta enviada. Falta que la confirme quien recibe.');
    }
  }

  @override
  Widget build(BuildContext context) => TarjetaModulo(
    key: const ValueKey('transf-formulario'),
    titulo: 'Proponer una transferencia',
    icono: Icons.swap_horiz,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final r in widget.rutas)
              ChoiceChip(
                key: ValueKey('transf-ruta-${r.codigo}'),
                label: Text(r.titulo),
                selected: _ruta == r,
                onSelected: (_) => setState(() => _ruta = r),
              ),
          ],
        ),
        const SizedBox(height: 8),
        CampoMonto(controlador: _monto, etiqueta: 'Monto'),
        TextField(
          key: const ValueKey('transf-nota'),
          controller: _nota,
          maxLength: largoMaximoNotaTransferencia,
          decoration: const InputDecoration(labelText: 'Nota corta (opcional)'),
        ),
        const SizedBox(height: 8),
        FilledButton(
          key: const ValueKey('transf-proponer'),
          onPressed: _enviando ? null : _proponer,
          child: const Text('Proponer'),
        ),
        const SizedBox(height: 4),
        const Text('No se mueve nada hasta que la otra persona confirme.'),
      ],
    ),
  );
}

class _Listas extends ConsumerWidget {
  const _Listas({required this.todas, required this.personaId});

  final List<Transferencia> todas;
  final String personaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final porConfirmar = [
      for (final t in todas)
        if (t.estado == EstadoTransferencia.pendiente &&
            t.receptorId == personaId)
          t,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (porConfirmar.isNotEmpty)
          TarjetaModulo(
            key: const ValueKey('transf-por-confirmar'),
            titulo: 'Por confirmar',
            icono: Icons.inbox_outlined,
            child: Column(
              children: [
                for (final t in porConfirmar)
                  FilaTransferencia(t: t, yo: personaId),
              ],
            ),
          ),
        const SizedBox(height: 16),
        TarjetaModulo(
          key: const ValueKey('transf-historial'),
          titulo: 'Historial',
          icono: Icons.history,
          child: todas.isEmpty
              ? const Text('Aún no hay transferencias.')
              : Column(
                  children: [
                    for (final t in todas)
                      if (!porConfirmar.contains(t))
                        FilaTransferencia(t: t, yo: personaId),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Una transferencia con su estado y, si toca, los botones.
class FilaTransferencia extends ConsumerWidget {
  const FilaTransferencia({super.key, required this.t, required this.yo});

  final Transferencia t;
  final String yo;

  Future<void> _responder(
    BuildContext context,
    WidgetRef ref,
    AccionTransferencia a,
  ) => intentar(
    context,
    () => ref.read(transferenciasProvider.notifier).responder(t.id, a),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendiente = t.estado == EstadoTransferencia.pendiente;
    final soyReceptor = t.receptorId == yo;
    final soyOrigen = t.origenId == yo;
    return ListTile(
      key: ValueKey('transf-${t.id}'),
      contentPadding: EdgeInsets.zero,
      title: Wrap(
        spacing: 8,
        children: [Text(t.ruta.titulo), Monto(t.montoCentavos)],
      ),
      subtitle: Text(
        [t.estado.titulo, if (t.nota.isNotEmpty) t.nota].join(' · '),
        key: ValueKey('transf-estado-${t.id}'),
      ),
      trailing: !pendiente
          ? null
          : Wrap(
              spacing: 8,
              children: [
                if (soyReceptor) ...[
                  FilledButton(
                    key: ValueKey('transf-confirmar-${t.id}'),
                    onPressed: () =>
                        _responder(context, ref, AccionTransferencia.confirmar),
                    child: const Text('Confirmar'),
                  ),
                  OutlinedButton(
                    key: ValueKey('transf-rechazar-${t.id}'),
                    onPressed: () =>
                        _responder(context, ref, AccionTransferencia.rechazar),
                    child: const Text('Rechazar'),
                  ),
                ],
                if (soyOrigen)
                  TextButton(
                    key: ValueKey('transf-cancelar-${t.id}'),
                    onPressed: () =>
                        _responder(context, ref, AccionTransferencia.cancelar),
                    child: const Text('Cancelar'),
                  ),
              ],
            ),
    );
  }
}
