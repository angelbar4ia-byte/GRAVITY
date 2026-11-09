/// Historial de compras completo (Fase 8, sección 1): cuatro ejes (tiempo,
/// precio, producto y tienda) con filtros combinables. Solo precios reales de
/// compra; el precio base de supuesto no entra. Los totales de cada eje suman
/// lo mismo que las compras que pasan el filtro.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../diseno/diseno.dart';
import '../../../nucleo/contratos/roles.dart';
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
