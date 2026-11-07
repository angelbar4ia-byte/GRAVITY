/// Bitácora y gastos de cuidado (teléfono). La cuidadora y la hermana solo ven
/// lo que ellas registraron; el gasto queda **pendiente de confirmación del
/// dueño**, que lo confirma o lo rechaza.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/pantallas/marco_pantalla.dart';
import '../../../diseno/diseno.dart';
import '../../../nucleo/contratos/roles.dart';
import '../casos_uso/permisos_cuidados.dart';
import '../datos/modelos.dart';
import '../estado/proveedores.dart';
import 'comunes.dart';
import 'mi_turno.dart' show pedirTexto;

/// Convierte "123.45" o "123" en centavos; `null` si no es un monto válido.
int? centavosDeTexto(String texto) {
  final t = texto.trim().replaceAll(',', '').replaceAll(r'$', '');
  final m = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(t);
  if (m == null) return null;
  final pesos = int.parse(m[1]!);
  final cent = int.parse((m[2] ?? '').padRight(2, '0').isEmpty ? '0' : (m[2] ?? '').padRight(2, '0'));
  return pesos * 100 + cent;
}

class PantallaBitacora extends ConsumerWidget {
  const PantallaBitacora({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(permisosCuidadosProvider);
    final pestanas = <(String, Widget)>[
      if (p.veBitacora) ('Bitácora', const _ListaBitacora()),
      if (p.veGastos) ('Gastos', const _ListaGastos()),
    ];
    return TemaModulo(
      modulo: Modulo.cuidados,
      child: pestanas.isEmpty
          ? const MarcoPantalla(titulo: 'Bitácora', cuerpo: SinAccesoCuidados())
          : DefaultTabController(
              length: pestanas.length,
              child: MarcoPantalla(
                titulo: 'Bitácora y gastos',
                cuerpo: Column(
                  children: [
                    TabBar(tabs: [for (final e in pestanas) Tab(text: e.$1)]),
                    Expanded(
                      child: TabBarView(children: [for (final e in pestanas) e.$2]),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _ListaBitacora extends ConsumerWidget {
  const _ListaBitacora();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(permisosCuidadosProvider);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: p.escribeBitacora
          ? FloatingActionButton.extended(
              onPressed: () => _nueva(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Nueva nota', style: TextStyle(fontSize: 18)),
            )
          : null,
      body: cuando(
        ref.watch(bitacoraProvider),
        () => ref.invalidate(bitacoraProvider),
        (entradas) => entradas.isEmpty
            ? const EstadoVacio(
                mensaje: 'Sin notas todavía',
                detalle: 'Escribe qué pasó durante el turno.',
                icono: Icons.menu_book_outlined,
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  for (final e in entradas)
                    Card(
                      child: ListTile(
                        title: Text(e.texto, style: t.titleMedium),
                        subtitle: Text(
                          '${e.autorNombre} · ${fechaLarga(e.creadaEn)} ${horaTexto(e.creadaEn)}',
                          style: t.bodyMedium,
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Future<void> _nueva(BuildContext context, WidgetRef ref) async {
    final texto = await pedirTexto(
      context,
      titulo: 'Nueva nota',
      pista: '¿Qué pasó?',
      lineas: 4,
    );
    if (texto == null || !context.mounted) return;
    await ejecutarCuidados(
      context,
      ref,
      () => ref.read(servicioCuidadosProvider).agregarNota(texto),
      ok: 'Nota guardada',
    );
  }
}

class _ListaGastos extends ConsumerWidget {
  const _ListaGastos();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(permisosCuidadosProvider);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: p.registraGasto
          ? FloatingActionButton.extended(
              onPressed: () => _nuevo(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Registrar gasto', style: TextStyle(fontSize: 18)),
            )
          : null,
      body: cuando(
        ref.watch(gastosProvider),
        () => ref.invalidate(gastosProvider),
        (gastos) => gastos.isEmpty
            ? const EstadoVacio(
                mensaje: 'Sin gastos registrados',
                icono: Icons.receipt_long_outlined,
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  for (final g in gastos) _TarjetaGasto(g: g, p: p, t: t),
                ],
              ),
      ),
    );
  }

  Future<void> _nuevo(BuildContext context, WidgetRef ref) async {
    final r = await showModalBottomSheet<(String, int)>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _HojaGasto(),
    );
    if (r == null || !context.mounted) return;
    await ejecutarCuidados(
      context,
      ref,
      () => ref.read(servicioCuidadosProvider).registrarGasto(concepto: r.$1, centavos: r.$2),
      ok: 'Gasto registrado, pendiente de confirmación',
    );
  }
}

class _TarjetaGasto extends ConsumerWidget {
  const _TarjetaGasto({required this.g, required this.p, required this.t});

  final GastoCuidado g;
  final PermisosCuidados p;
  final TextTheme t;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendiente = g.estado == EstadoGasto.pendiente;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${g.concepto} · ${formatearCentavos(g.centavos)}', style: t.titleMedium),
            Text(
              '${g.registradoNombre} · ${fechaLarga(g.fecha)}',
              style: t.bodyMedium,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(pendiente ? Icons.hourglass_empty : Icons.check_circle_outline, size: 20),
                const SizedBox(width: 6),
                Text(g.estado.etiqueta, style: t.titleSmall),
              ],
            ),
            if (pendiente && p.confirmaGasto) ...[
              const SizedBox(height: 8),
              Row(
                spacing: 8,
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => ejecutarCuidados(
                        context,
                        ref,
                        () => ref.read(servicioCuidadosProvider).resolverGasto(g.id, confirmar: true),
                        ok: 'Gasto confirmado',
                      ),
                      child: const Text('Confirmar'),
                    ),
                  ),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => ejecutarCuidados(
                        context,
                        ref,
                        () => ref.read(servicioCuidadosProvider).resolverGasto(g.id, confirmar: false),
                        ok: 'Gasto rechazado',
                      ),
                      child: const Text('Rechazar'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HojaGasto extends StatefulWidget {
  const _HojaGasto();

  @override
  State<_HojaGasto> createState() => _HojaGastoState();
}

class _HojaGastoState extends State<_HojaGasto> {
  final _concepto = TextEditingController();
  final _monto = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _concepto.dispose();
    _monto.dispose();
    super.dispose();
  }

  void _guardar() {
    final c = centavosDeTexto(_monto.text);
    if (_concepto.text.trim().isEmpty) {
      setState(() => _error = 'Escribe en qué se gastó.');
    } else if (c == null || c <= 0) {
      setState(() => _error = 'Escribe un monto válido, por ejemplo 150.50');
    } else {
      Navigator.pop(context, (_concepto.text.trim(), c));
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        Text('Registrar gasto de cuidado', style: Theme.of(context).textTheme.titleLarge),
        TextField(
          controller: _concepto,
          autofocus: true,
          style: const TextStyle(fontSize: 20),
          decoration: const InputDecoration(labelText: '¿En qué se gastó?', border: OutlineInputBorder()),
        ),
        TextField(
          controller: _monto,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 20),
          decoration: const InputDecoration(labelText: 'Monto en pesos', prefixText: r'$ ', border: OutlineInputBorder()),
        ),
        if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 16)),
        const Text('Queda pendiente de confirmación del dueño.'),
        BotonGrande(texto: 'Guardar', onPressed: _guardar),
      ],
    ),
  );
}
