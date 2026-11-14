/// Historial de compras completo (Fase 8, sección 1): cuatro ejes (tiempo,
/// precio, producto y tienda) con filtros combinables. Solo precios reales de
/// compra; el precio base de supuesto no entra. Los totales de cada eje suman
/// lo mismo que las compras que pasan el filtro.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../diseno/diseno.dart';
import '../../../nucleo/contratos/roles.dart';
import '../casos_uso/servicio_alimentacion.dart';
import '../datos/modelos.dart';
import '../estado/proveedores.dart';

/// "12.50" -> 1250.0 centavos por unidad; `null` si vacío o inválido.
double? _centavosOpcional(String t) {
  final v = double.tryParse(t.trim().replaceAll(',', '.'));
  return v == null || v < 0 ? null : v * 100;
}

class PantallaHistorialCompleto extends ConsumerStatefulWidget {
  const PantallaHistorialCompleto({super.key, required this.menu});
  final MenuId menu;

  @override
  ConsumerState<PantallaHistorialCompleto> createState() => _Estado();
}

class _Estado extends ConsumerState<PantallaHistorialCompleto> {
  EscalaTiempo _escala = EscalaTiempo.mes;
  String? _producto;
  String? _tienda;
  final _min = TextEditingController();
  final _max = TextEditingController();

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  FiltroHistorial get _filtro => FiltroHistorial(
    escala: _escala,
    claveProducto: _producto,
    tienda: _tienda,
    unitarioMinCentavos: _centavosOpcional(_min.text),
    unitarioMaxCentavos: _centavosOpcional(_max.text),
  );

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    return TemaModulo(
      modulo: Modulo.alimentacion,
      child: Scaffold(
        appBar: AppBar(title: const Text('Historial de compras')),
        body: ref
            .watch(historialCompletoProvider(widget.menu))
            .when(
              loading: () => const EstadoCargando(),
              error: (_, _) => EstadoError(
                mensaje: 'No pudimos cargar el historial.',
                alReintentar: () =>
                    ref.invalidate(historialCompletoProvider(widget.menu)),
              ),
              data: (todas) {
                if (todas.isEmpty) {
                  return const EstadoVacio(
                    mensaje: 'Sin compras con precio todavía',
                    detalle: 'Cuando registres una compra con precio y tienda aparecerá aquí.',
                    icono: Icons.history,
                  );
                }
                final resumen = resumirHistorial(todas, _filtro);
                final productos = {for (final c in todas) c.clave: c.nombre};
                final tiendas = <String, String>{};
                var haySinTienda = false;
                for (final c in todas) {
                  if (c.tiendaId == null) {
                    haySinTienda = true;
                  } else {
                    tiendas[c.tiendaId!] = c.tienda ?? etiquetaSinTienda;
                  }
                }
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const _ReenviosRechazados(),
                    Text(
                      'Solo precios reales de compra (el precio estimado no entra).',
                      style: v.lectura(tamano: 14, color: v.textoTenue),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final e in EscalaTiempo.values)
                          ChoiceChip(
                            key: Key('escala_${e.name}'),
                            label: Text(e.etiqueta),
                            selected: _escala == e,
                            onSelected: (_) => setState(() => _escala = e),
                          ),
                      ],
                    ),
                    DropdownButtonFormField<String?>(
                      key: const Key('filtro_producto'),
                      initialValue: _producto,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Producto'),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Todos'),
                        ),
                        for (final e in productos.entries)
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                      ],
                      onChanged: (x) => setState(() => _producto = x),
                    ),
                    DropdownButtonFormField<String?>(
                      key: const Key('filtro_tienda'),
                      initialValue: _tienda,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Tienda'),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Todas'),
                        ),
                        for (final e in tiendas.entries)
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                        if (haySinTienda)
                          const DropdownMenuItem(
                            value: filtroSinTienda,
                            child: Text(etiquetaSinTienda),
                          ),
                      ],
                      onChanged: (x) => setState(() => _tienda = x),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const Key('precio_min'),
                            controller: _min,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Precio unitario desde (pesos)',
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            key: const Key('precio_max'),
                            controller: _max,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'hasta (pesos)',
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      key: const Key('total_historial'),
                      'Total: ${pesosTexto(resumen.totalCentavos)} en '
                      '${resumen.compras} '
                      '${resumen.compras == 1 ? 'compra' : 'compras'}',
                      style: v.titulo(tamano: 20, color: v.textoFuerte),
                    ),
                    if (resumen.compras == 0)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text('Ninguna compra coincide con los filtros.'),
                      )
                    else ...[
                      _Seccion(v, 'Por ${_escala.etiqueta.toLowerCase()}', [
                        for (final f in resumen.porPeriodo)
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(f.etiqueta),
                            subtitle: Text('${f.compras} compras'),
                            trailing: Text(pesosTexto(f.totalCentavos)),
                          ),
                      ]),
                      _Seccion(v, 'Por producto y precio', [
                        for (final f in resumen.porProducto)
                          ListTile(
                            key: Key('producto_${f.clave}'),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(f.nombre),
                            subtitle: Text(_detalleProducto(f)),
                            trailing: Text(pesosTexto(f.totalCentavos)),
                          ),
                      ]),
                      _Seccion(v, 'Por tienda', [
                        for (final f in resumen.porTienda)
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(f.nombre),
                            subtitle: Text('${f.compras} compras'),
                            trailing: Text(pesosTexto(f.totalCentavos)),
                          ),
                      ]),
                    ],
                    _Seccion(v, 'Compras', [
                      for (final c in [
                        ...todas.where(
                          (c) =>
                              c.revertida ||
                              filtrarHistorial(todas, _filtro).contains(c),
                        ),
                      ]..sort((a, b) => b.fecha.compareTo(a.fecha)))
                        ListTile(
                          key: Key(
                            'compra_${c.clave}_${c.fecha.millisecondsSinceEpoch}',
                          ),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${c.nombre} · ${cantidadTexto(c.cantidad)} ${c.unidad}',
                          ),
                          subtitle: Text(
                            [
                              '${c.fecha.day}/${c.fecha.month}/${c.fecha.year}',
                              c.tienda ?? etiquetaSinTienda,
                              if (c.cuentaPago != null)
                                'Pagada con ${c.cuentaPago}',
                              if (c.revertida) 'Revertida',
                            ].join(' · '),
                          ),
                          trailing: Text(
                            pesosTexto(c.totalCentavos),
                            style: c.revertida
                                ? const TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                  )
                                : null,
                          ),
                        ),
                    ]),
                  ],
                );
              },
            ),
      ),
    );
  }
}

String _detalleProducto(FilaProducto f) {
  final partes = <String>[
    '${f.compras} ${f.compras == 1 ? 'vez' : 'veces'} · '
        '${cantidadTexto(f.cantidad)} ${f.unidad}',
    'Último: ${unitarioTexto(f.ultimoUnitario)} por ${f.unidad}',
  ];
  final var_ = f.variacionPorcentaje;
  if (var_ != null) {
    partes.add(
      var_ == 0
          ? 'Sin cambio de precio'
          : '${var_ > 0 ? 'Subió' : 'Bajó'} ${var_.abs()}%',
    );
  }
  if (f.tiendaMasBarata != null) {
    partes.add('Más barata: ${f.tiendaMasBarata}');
  }
  return partes.join(' · ');
}

class _Seccion extends StatelessWidget {
  const _Seccion(this.v, this.titulo, this.hijos);
  final ValoresDiseno v;
  final String titulo;
  final List<Widget> hijos;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 4),
        child: Text(titulo, style: v.titulo(tamano: 18, color: v.etiqueta)),
      ),
      ...hijos,
    ],
  );
}

/// Compras de Papá rechazadas por el albacea y lo que toca hacer con cada una:
/// reenviar (quien compró, una vez), registrar el gasto propio, anularlo tras
/// la reclasificación (quien compró) o reembolsar / reclasificar (albacea).
class _ReenviosRechazados extends ConsumerWidget {
  const _ReenviosRechazados();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ValoresDiseno.de(context);
    final reenviables = ref
        .watch(solicitudesRechazadasMiasProvider)
        .maybeWhen(data: (l) => l, orElse: () => const <SolicitudPago>[]);
    final gastos = ref
        .watch(gastosRechazadosProvider)
        .maybeWhen(data: (l) => l, orElse: () => const <GastoRechazado>[]);
    if (reenviables.isEmpty && gastos.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Compras de Papá rechazadas', style: v.lectura(tamano: 16, color: v.texto)),
          for (final s in reenviables)
            ListTile(
              key: Key('reenviar_${s.id}'),
              contentPadding: EdgeInsets.zero,
              title: Text('${s.ingrediente} · \$${(s.montoCentavos / 100).toStringAsFixed(2)}'),
              subtitle: const Text('Puedes reenviarla una vez, con justificación.'),
              trailing: TextButton(
                onPressed: () => _reenviar(context, ref, s),
                child: const Text('Reenviar'),
              ),
            ),
          for (final g in gastos) _FilaGasto(gasto: g),
        ],
      ),
    );
  }

  Future<void> _reenviar(BuildContext context, WidgetRef ref, SolicitudPago s) async {
    final texto = TextEditingController();
    final error = ValueNotifier<String?>(null);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reenviar: ${s.ingrediente}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: texto,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'Justificación (3 a 200 caracteres)'),
            ),
            ValueListenableBuilder<String?>(
              valueListenable: error,
              builder: (_, m, _) => m == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(m, key: const Key('error_reenvio')),
                    ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              try {
                await ref.read(servicioAlimentacionProvider).reenviarSolicitud(
                      s.id,
                      justificacion: texto.text,
                    );
                ref.read(versionAlimentacionProvider.notifier).state++;
                if (ctx.mounted) Navigator.of(ctx).pop();
              } on ArgumentError catch (e) {
                error.value = '${e.message}';
              } on PermisoDenegado {
                error.value = 'Solo quien compró puede reenviarla.';
              } catch (e) {
                error.value = '$e';
              }
            },
            child: const Text('Reenviar'),
          ),
        ],
      ),
    );
    texto.dispose();
    error.dispose();
  }
}

/// Una compra de Papá con su acción pendiente.
class _FilaGasto extends ConsumerWidget {
  const _FilaGasto({required this.gasto});
  final GastoRechazado gasto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monto = costoTexto(gasto.montoCentavos, estimado: false);
    final (texto, boton, accion) = switch (gasto.accion) {
      AccionGasto.reembolsar => (
        'Rechazada dos veces: reembolsar o reclasificar',
        'Decidir',
        () => _albacea(context, ref),
      ),
      AccionGasto.registrar => (
        'Rechazada: el gasto es tuyo. Regístralo en tu cuenta',
        'Registrar',
        () => _registrar(context, ref),
      ),
      AccionGasto.anular => (
        'Reclasificado al libro de Papá: anula tu gasto',
        'Anular',
        () => _anular(context, ref),
      ),
    };
    return ListTile(
      key: Key('gasto_${gasto.accion.name}_${gasto.compraId}'),
      contentPadding: EdgeInsets.zero,
      title: Text('${gasto.ingrediente} · $monto'),
      subtitle: Text(texto),
      trailing: TextButton(onPressed: accion, child: Text(boton)),
    );
  }

  void _mensaje(BuildContext context, String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  void _listo(WidgetRef ref) => ref.read(versionAlimentacionProvider.notifier).state++;

  Future<void> _albacea(BuildContext context, WidgetRef ref) async {
    final servicio = ref.read(servicioAlimentacionProvider);
    final cuentas = await servicio.cuentasDelLibroDePapa();
    if (!context.mounted) return;
    if (cuentas.isEmpty) {
      _mensaje(context, 'El libro de Papá no tiene cuentas de pago.');
      return;
    }
    String? elegida = ServicioAlimentacion.cuentaEfectiva(cuentas, null)?.id;
    final opcion = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reembolsar ${gasto.ingrediente}'),
        content: StatefulBuilder(
          builder: (ctx, setState) => DropdownButtonFormField<String>(
            key: const Key('cuenta_papa_reembolso'),
            initialValue: elegida,
            items: [
              for (final c in cuentas) DropdownMenuItem(value: c.id, child: Text(c.nombre)),
            ],
            onChanged: (c) => setState(() => elegida = c),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            key: const Key('reclasificar_papa'),
            onPressed: () => Navigator.pop(ctx, 'reclasificar'),
            child: const Text('Reclasificar al libro de Papá'),
          ),
          FilledButton(
            key: const Key('transferir_reembolso'),
            onPressed: () => Navigator.pop(ctx, 'transferir'),
            child: const Text('Pagar por transferencia'),
          ),
        ],
      ),
    );
    if (opcion == null || elegida == null || !context.mounted) return;
    try {
      if (opcion == 'transferir') {
        await servicio.autorizarReembolso(gasto.compraId, cuentaPapaId: elegida!);
        _mensaje(context, 'Transferencia propuesta. Quien compró la confirma.');
      } else {
        await servicio.reclasificarGasto(gasto.compraId, cuentaPapaId: elegida!);
        _mensaje(context, 'Gasto reclasificado. Quien compró debe anular el suyo.');
      }
      _listo(ref);
    } catch (e) {
      _mensaje(context, '$e');
    }
  }

  Future<void> _registrar(BuildContext context, WidgetRef ref) async {
    final servicio = ref.read(servicioAlimentacionProvider);
    final List<CuentaPago> cuentas;
    try {
      cuentas = await servicio.cuentasDePago(MenuId.pareja);
    } catch (e) {
      if (context.mounted) _mensaje(context, '$e');
      return;
    }
    if (!context.mounted) return;
    if (cuentas.isEmpty) {
      _mensaje(context, 'No tienes cuentas para registrar el gasto.');
      return;
    }
    String? elegida = ServicioAlimentacion.cuentaEfectiva(cuentas, null)?.id;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Registrar ${gasto.ingrediente}'),
        content: StatefulBuilder(
          builder: (ctx, setState) => DropdownButtonFormField<String>(
            key: const Key('cuenta_gasto_propio'),
            initialValue: elegida,
            items: [
              for (final c in cuentas) DropdownMenuItem(value: c.id, child: Text(c.nombre)),
            ],
            onChanged: (c) => setState(() => elegida = c),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Registrar')),
        ],
      ),
    );
    if (ok != true || elegida == null || !context.mounted) return;
    try {
      await servicio.registrarGastoRechazado(gasto.compraId, cuentaId: elegida!);
      _listo(ref);
    } catch (e) {
      _mensaje(context, '$e');
    }
  }

  Future<void> _anular(BuildContext context, WidgetRef ref) async {
    final motivo = TextEditingController();
    final error = ValueNotifier<String?>(null);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Anular mi gasto: ${gasto.ingrediente}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Se anula en tu libro y queda registrado en Papá.'),
            TextField(
              controller: motivo,
              decoration: const InputDecoration(labelText: 'Motivo (3 caracteres o más)'),
            ),
            ValueListenableBuilder<String?>(
              valueListenable: error,
              builder: (_, m, _) => m == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(m, key: const Key('error_anular')),
                    ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              try {
                await ref
                    .read(servicioAlimentacionProvider)
                    .anularGastoPropio(gasto.compraId, motivo: motivo.text);
                _listo(ref);
                if (ctx.mounted) Navigator.of(ctx).pop();
              } on ArgumentError catch (e) {
                error.value = '${e.message}';
              } catch (e) {
                error.value = '$e';
              }
            },
            child: const Text('Anular'),
          ),
        ],
      ),
    );
    motivo.dispose();
    error.dispose();
  }
}
