/// Tarjetas de la persona y sus beneficios (puntos, cashback, meses sin
/// intereses) con su vigencia (Fase 8, bloque 2). Lo que se captura a mano
/// queda marcado "Capturado, no verificado".
library;

import 'package:finanzas_dominio/finanzas_dominio.dart'
    show BeneficioTarjeta, Fecha, OrigenDato, Tarjeta, TipoBeneficio;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../diseno/diseno.dart';
import '../../datos/tarjetas.dart';
import '../../estado/proveedores.dart' show ContextoFinanzas;
import '../../estado/proveedores_deudas_intereses.dart';

class VistaTarjetas extends ConsumerWidget {
  const VistaTarjetas({super.key, required this.contexto});

  final ContextoFinanzas contexto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = contexto;
    final datos = ref.watch(tarjetasProvider);
    final hueco = SizedBox(height: ValoresDiseno.de(context).espacio * 2);
    return datos.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const Center(child: Text('No se pudieron cargar.')),
      data: (d) {
        final tarjetas = d.deLibro(c.libroId);
        return ListView(
          key: const ValueKey('tarjetas-lista'),
          padding: const EdgeInsets.all(16),
          children: [
            if (c.puedeEscribir)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: OutlinedButton.icon(
                  key: const ValueKey('tarjetas-nueva'),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => _DialogoTarjeta(libroId: c.libroId),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar tarjeta'),
                ),
              ),
            if (tarjetas.isEmpty)
              const EstadoVacio(
                mensaje: 'Sin tarjetas registradas.',
                detalle:
                    'Agrégalas a mano; quedan como capturadas, no verificadas.',
              ),
            for (final t in tarjetas) ...[
              _TarjetaConBeneficios(
                tarjeta: t,
                beneficios: d.deTarjeta(t.id),
                contexto: c,
              ),
              hueco,
            ],
          ],
        );
      },
    );
  }
}

String etiquetaVigencia(BeneficioTarjeta b, Fecha hoy) {
  final v = b.vigenteEn(hoy);
  final rango = b.hasta == null
      ? 'desde ${b.desde}'
      : '${b.desde} a ${b.hasta}';
  return v ? 'Vigente · $rango' : 'Fuera de vigencia · $rango';
}

class _TarjetaConBeneficios extends ConsumerWidget {
  const _TarjetaConBeneficios({
    required this.tarjeta,
    required this.beneficios,
    required this.contexto,
  });

  final Tarjeta tarjeta;
  final List<BeneficioTarjeta> beneficios;
  final ContextoFinanzas contexto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = tarjeta;
    final sub = t.banco ?? '';
    return TarjetaModulo(
      key: ValueKey('tarjeta-${t.id}'),
      titulo: t.nombre,
      icono: Icons.credit_card_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sub.isNotEmpty) Text(sub),
          Text(
            t.origen.etiqueta,
            key: ValueKey('origen-${t.id}'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          if (beneficios.isEmpty) const Text('Sin beneficios registrados.'),
          for (final b in beneficios)
            ListTile(
              key: ValueKey('beneficio-${b.id}'),
              contentPadding: EdgeInsets.zero,
              title: Text('${b.tipo.etiqueta}: ${b.descripcion}'),
              subtitle: Text(
                '${etiquetaVigencia(b, contexto.hoy)} · ${b.origen.etiqueta}',
              ),
              trailing: contexto.puedeEscribir
                  ? IconButton(
                      tooltip: 'Quitar beneficio',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => ref
                          .read(tarjetasProvider.notifier)
                          .quitarBeneficio(b.id),
                    )
                  : null,
            ),
          if (contexto.puedeEscribir)
            TextButton(
              key: ValueKey('beneficio-nuevo-${t.id}'),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => _DialogoBeneficio(tarjetaId: t.id),
              ),
              child: const Text('Agregar beneficio'),
            ),
        ],
      ),
    );
  }
}

class _DialogoTarjeta extends ConsumerStatefulWidget {
  const _DialogoTarjeta({required this.libroId});

  final String libroId;

  @override
  ConsumerState<_DialogoTarjeta> createState() => _DialogoTarjetaState();
}

class _DialogoTarjetaState extends ConsumerState<_DialogoTarjeta> {
  final _nombre = TextEditingController();
  final _banco = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    _banco.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    try {
      final t = tarjetaCapturada(
        id: const Uuid().v4(),
        libroId: widget.libroId,
        nombre: _nombre.text,
        banco: _banco.text,
      );
      await ref.read(tarjetasProvider.notifier).guardarTarjeta(t);
      if (mounted) Navigator.of(context).pop();
    } on ArgumentError catch (e) {
      setState(() => _error = '${e.message}');
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Agregar tarjeta'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey('tarjeta-nombre'),
            controller: _nombre,
            decoration: const InputDecoration(labelText: 'Nombre'),
          ),
          TextField(
            key: const ValueKey('tarjeta-banco'),
            controller: _banco,
            decoration: const InputDecoration(labelText: 'Banco'),
          ),
          const Text('Se guarda como capturada, no verificada.'),
          if (_error != null) Text(_error!),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        key: const ValueKey('tarjeta-guardar'),
        onPressed: _guardar,
        child: const Text('Guardar'),
      ),
    ],
  );
}

class _DialogoBeneficio extends ConsumerStatefulWidget {
  const _DialogoBeneficio({required this.tarjetaId});

  final String tarjetaId;

  @override
  ConsumerState<_DialogoBeneficio> createState() => _DialogoBeneficioState();
}

class _DialogoBeneficioState extends ConsumerState<_DialogoBeneficio> {
  final _descripcion = TextEditingController();
  final _desde = TextEditingController();
  final _hasta = TextEditingController();
  TipoBeneficio _tipo = TipoBeneficio.puntos;
  String? _error;

  @override
  void dispose() {
    _descripcion.dispose();
    _desde.dispose();
    _hasta.dispose();
    super.dispose();
  }

  Fecha? _fecha(String texto) {
    final t = texto.trim();
    if (t.isEmpty) return null;
    try {
      return Fecha.parse(t);
    } on Object {
      throw ArgumentError('Escribe las fechas como AAAA-MM-DD');
    }
  }

  Future<void> _guardar() async {
    try {
      final b = beneficioCapturado(
        id: const Uuid().v4(),
        tarjetaId: widget.tarjetaId,
        tipo: _tipo,
        descripcion: _descripcion.text,
        desde:
            _fecha(_desde.text) ??
            (throw ArgumentError('Escribe desde cuándo vale')),
        hasta: _fecha(_hasta.text),
      );
      await ref.read(tarjetasProvider.notifier).guardarBeneficio(b);
      if (mounted) Navigator.of(context).pop();
    } on ArgumentError catch (e) {
      setState(() => _error = '${e.message}');
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Agregar beneficio'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<TipoBeneficio>(
            key: const ValueKey('beneficio-tipo'),
            initialValue: _tipo,
            decoration: const InputDecoration(labelText: 'Tipo'),
            items: [
              for (final t in TipoBeneficio.values)
                DropdownMenuItem(value: t, child: Text(t.etiqueta)),
            ],
            onChanged: (t) => setState(() => _tipo = t ?? _tipo),
          ),
          TextField(
            key: const ValueKey('beneficio-descripcion'),
            controller: _descripcion,
            decoration: const InputDecoration(labelText: 'Descripción'),
          ),
          TextField(
            key: const ValueKey('beneficio-desde'),
            controller: _desde,
            decoration: const InputDecoration(
              labelText: 'Vigente desde (AAAA-MM-DD)',
            ),
          ),
          TextField(
            key: const ValueKey('beneficio-hasta'),
            controller: _hasta,
            decoration: const InputDecoration(
              labelText: 'Vigente hasta (AAAA-MM-DD, opcional)',
            ),
          ),
          Text('${OrigenDato.capturado.etiqueta}.'),
          if (_error != null) Text(_error!),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        key: const ValueKey('beneficio-guardar'),
        onPressed: _guardar,
        child: const Text('Guardar'),
      ),
    ],
  );
}
