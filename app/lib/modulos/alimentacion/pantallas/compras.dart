/// Lista de compras de la semana por pasillo, para usarla en el súper (el
/// teléfono). Los precios base se rotulan "estimado"; sin precio no hay costo.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/pantallas/marco_pantalla.dart';
import '../../../diseno/diseno.dart';
import '../../../nucleo/contratos/roles.dart';
import '../../../nucleo/contratos/rutas.dart';
import '../casos_uso/lista_compras.dart';
import '../casos_uso/servicio_alimentacion.dart'
    show RegistroCompra, ServicioAlimentacion;
import '../../finanzas/datos/repositorio.dart' show ErrorFinanzas;
import '../datos/modelos.dart';
import '../datos/repositorio.dart'
    show ErrorAlimentacionServidor, RepositorioAlimentacionEnMemoria;
import '../estado/proveedores.dart';
import 'historial_precios.dart';
import 'hay_presupuesto.dart';
import 'solicitudes_papa.dart';
import 'selector_menu.dart';

class PantallaListaCompras extends ConsumerWidget {
  const PantallaListaCompras({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permitidos = ref.watch(servicioAlimentacionProvider).menusConCompras;
    final menu = menuEfectivo(ref.watch(menuElegidoProvider), permitidos);
    return TemaModulo(
      modulo: Modulo.alimentacion,
      child: MarcoPantalla(
        titulo: 'Lista de compras',
        rutaAnterior: Rutas.alimentacion,
        cuerpo: menu == null
            ? const EstadoVacio(
                mensaje: 'No tienes listas para ver',
                icono: Icons.lock_outline,
              )
            : ref.watch(alimentacionSinServidorProvider)
            ? const EstadoVacio(
                mensaje: 'Sin menú todavía',
                detalle: 'La lista de compras saldrá del menú cuando Alimentación esté activa en tu hogar.',
                icono: Icons.shopping_cart_outlined,
              )
            : Column(
                children: [
                  SelectorMenu(
                    menus: permitidos,
                    actual: menu,
                    alElegir: (m) =>
                        ref.read(menuElegidoProvider.notifier).state = m,
                  ),
                  Expanded(
                    child: ref
                        .watch(listaComprasProvider(menu))
                        .when(
                          loading: () => const EstadoCargando(),
                          error: (_, _) => EstadoError(
                            mensaje: 'No pudimos armar la lista.',
                            alReintentar: () =>
                                ref.invalidate(listaComprasProvider(menu)),
                          ),
                          data: (items) => items.isEmpty
                              ? const EstadoVacio(
                                  mensaje: 'La lista está vacía',
                                  detalle: 'Agrega platillos al menú de la semana y aquí aparecerán los ingredientes.',
                                  icono: Icons.shopping_cart_outlined,
                                )
                              : _Contenido(menu: menu, items: items),
                        ),
                  ),
                ],
              ),
      ),
    );
  }
}

String _textoPrecio(ItemCompra i) {
  final c = i.costoCentavos;
  if (c == null) return 'Sin precio';
  return costoTexto(c, estimado: i.costoEstimado);
}

/// "12.50" o "12" -> centavos; `null` si no es un monto válido y positivo.
int? centavosDeTexto(String t) {
  final m = RegExp(r'^\s*\$?\s*(\d{1,7})(?:[.,](\d{1,2}))?\s*$').firstMatch(t);
  if (m == null) return null;
  final c = int.parse(m.group(1)!) * 100 +
      (m.group(2) == null ? 0 : int.parse(m.group(2)!.padRight(2, '0')));
  return c > 0 ? c : null;
}

Future<void> _registrar(BuildContext context, WidgetRef ref, ItemCompra i) async {
  final menu = menuEfectivo(
    ref.read(menuElegidoProvider),
    ref.read(servicioAlimentacionProvider).menusConCompras,
  );
  if (menu == null) return;
  final total = TextEditingController();
  final cantidad = TextEditingController(text: cantidadTexto(i.cantidad));
  final servicio = ref.read(servicioAlimentacionProvider);
  final cuenta = servicio.cuentaPorOmisionDe(menu);
  // Cuentas de pago: la de omisión viene marcada y la persona puede elegir otra.
  var ofrecidas = const <CuentaPago>[];
  try {
    ofrecidas = await servicio.cuentasDePago(menu);
  } on Exception {
    // Sin cuentas legibles: el servidor avisará al guardar.
  }
  if (!context.mounted) return;
  String? cuentaPagoId = ServicioAlimentacion.cuentaEfectiva(ofrecidas, null)?.id;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Compra de ${i.nombre}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: cantidad,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Cantidad comprada (${i.unidad})'),
          ),
          TextField(
            controller: total,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Total pagado (pesos)'),
          ),
          if (cuenta == CuentaCompra.papa)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Sin cuenta: la compra queda pendiente de pago del albacea.',
              ),
            )
          else if (ofrecidas.isNotEmpty)
            StatefulBuilder(
              builder: (ctx, setState) => DropdownButtonFormField<String>(
                key: const Key('cuenta_pago'),
                initialValue: cuentaPagoId,
                decoration: const InputDecoration(labelText: 'Pagar con'),
                items: [
                  for (final c in ofrecidas)
                    DropdownMenuItem(value: c.id, child: Text(c.nombre)),
                ],
                onChanged: (c) => setState(() => cuentaPagoId = c),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Guardar compra'),
        ),
      ],
    ),
  );
  final centavos = centavosDeTexto(total.text);
  final cant = double.tryParse(cantidad.text.replaceAll(',', '.'));
  if (ok != true) return;
  if (centavos == null || cant == null || cant <= 0) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe una cantidad y un total válidos.')),
      );
    }
    return;
  }
  final RegistroCompra registro;
  try {
    registro = await ref
        .read(servicioAlimentacionProvider)
        .registrarCompra(
          menu,
          ref.read(semanaAlimentacionProvider),
          i.clave,
          cantidadComprada: cant,
          totalCentavos: centavos,
          nombre: i.nombre,
          unidad: i.unidad,
          cuenta: cuenta,
          cuentaPagoId: cuentaPagoId,
        );
  } on Exception catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se registró la compra: $e')),
      );
    }
    return;
  }
  ref.read(versionAlimentacionProvider.notifier).state++;
  if (registro.pendienteAlbacea && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        key: Key('pendiente_albacea'),
        content: Text('Pendiente de pago del albacea'),
      ),
    );
  }
  final alerta = registro.alerta;
  // Alerta local: solo porcentaje y precios unitarios, sin saldos.
  if (alerta != null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: const Key('alerta_precio'),
        duration: const Duration(seconds: 8),
        content: Text(alerta.texto),
      ),
    );
  }
}

/// Escanea un código: si está en el catálogo local y en la lista, abre la
/// compra; si no existe, pide capturarlo a mano y lo guarda con el código.
Future<void> _escanear(
  BuildContext context,
  WidgetRef ref,
  List<ItemCompra> items,
) async {
  final servicio = ref.read(servicioAlimentacionProvider);
  final codigo = await ref.read(lectorCodigoProvider).leer();
  if (!context.mounted) return;
  if (codigo == null || codigo.trim().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No se leyó ningún código.')),
    );
    return;
  }
  final ing = await servicio.buscarPorCodigoBarras(codigo);
  if (!context.mounted) return;
  if (ing != null) {
    final item = items.where((i) => i.clave == ing.clave).firstOrNull;
    if (item == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${ing.nombre} no está en la lista de esta semana.')),
      );
      return;
    }
    await _registrar(context, ref, item);
    return;
  }
  final nombre = TextEditingController();
  final unidad = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Código nuevo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('El código $codigo no está en tu catálogo. Escribe qué es.'),
          TextField(
            key: const Key('captura_nombre'),
            controller: nombre,
            decoration: const InputDecoration(labelText: 'Nombre del producto'),
          ),
          TextField(
            key: const Key('captura_unidad'),
            controller: unidad,
            decoration: const InputDecoration(labelText: 'Unidad (g, ml, pza...)'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Guardar con el código'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  try {
    final r = await servicio.guardarConCodigo(
      codigo: codigo,
      nombre: nombre.text,
      unidad: unidad.text,
    );
    final existente = r.existente;
    if (existente != null && context.mounted) {
      await _ficha(context, ref, existente);
      return;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            // Solo con el repositorio de memoria (sin servidor) el código
            // queda pendiente; con el del servidor ya quedó guardado.
            !r.enServidor ||
                    ref.read(repositorioAlimentacionProvider)
                        is RepositorioAlimentacionEnMemoria
                ? 'El código se guarda cuando el servidor lo tenga.'
                : 'Producto guardado con su código.',
          ),
        ),
      );
    }
  } on ArgumentError {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe el nombre y la unidad.')),
      );
    }
  } on ErrorAlimentacionServidor catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje)));
    }
  } on ErrorFinanzas catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje)));
    }
  }
}

/// Ficha de un ingrediente: se edita la unidad y la presentación del mismo
/// ingrediente (la marca no cuenta como otro producto).
Future<void> _ficha(
  BuildContext context,
  WidgetRef ref,
  FichaIngrediente ficha,
) async {
  final unidad = TextEditingController(text: ficha.unidad);
  final presentacion = TextEditingController(text: ficha.presentacion);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(ficha.nombre),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Ya existe: se edita este mismo ingrediente.'),
          TextField(
            key: const Key('ficha_unidad'),
            controller: unidad,
            decoration: const InputDecoration(labelText: 'Unidad'),
          ),
          TextField(
            key: const Key('ficha_presentacion'),
            controller: presentacion,
            decoration: const InputDecoration(
              labelText: 'Presentación (bolsa 1 kg, caja 12 pzas...)',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  try {
    await ref
        .read(servicioAlimentacionProvider)
        .editarPresentacion(
          ingredienteId: ficha.id,
          unidad: unidad.text,
          presentacion: presentacion.text,
        );
    ref.read(versionAlimentacionProvider.notifier).state++;
  } on Exception catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se guardó: $e')),
      );
    }
  }
}

Future<void> _abrirFicha(
  BuildContext context,
  WidgetRef ref,
  ItemCompra i,
) async {
  final f = await ref.read(servicioAlimentacionProvider).ficha(i.nombre);
  if (!context.mounted) return;
  if (f == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Este ingrediente aún no está en el servidor.')),
    );
    return;
  }
  await _ficha(context, ref, f);
}

/// Agrega un ingrediente a la lista (función del servidor).
Future<void> _agregar(BuildContext context, WidgetRef ref) async {
  final nombre = TextEditingController();
  final cantidad = TextEditingController();
  final unidad = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Agregar a la lista'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('agregar_nombre'),
            controller: nombre,
            decoration: const InputDecoration(labelText: 'Ingrediente'),
          ),
          TextField(
            key: const Key('agregar_cantidad'),
            controller: cantidad,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Cantidad'),
          ),
          TextField(
            key: const Key('agregar_unidad'),
            controller: unidad,
            decoration: const InputDecoration(labelText: 'Unidad (g, ml, pza...)'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Agregar'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  try {
    await ref
        .read(servicioAlimentacionProvider)
        .agregarALista(
          nombre: nombre.text,
          unidad: unidad.text,
          cantidad: double.tryParse(cantidad.text.replaceAll(',', '.')) ?? 0,
        );
    ref.read(versionAlimentacionProvider.notifier).state++;
  } on Exception catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ArgumentError
                ? 'Escribe el ingrediente, la unidad y una cantidad válida.'
                : 'No se agregó: $e',
          ),
        ),
      );
    }
  }
}

class _Contenido extends ConsumerWidget {
  const _Contenido({required this.menu, required this.items});
  final MenuId menu;
  final List<ItemCompra> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ValoresDiseno.de(context);
    final editar = ref.watch(puedeEditarAlimentacionProvider);
    final grupos = agruparPorSeccion(items);
    final hechos = items.where((i) => i.comprado).length;
    final costo = costoDeLista(items);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TarjetaHayPresupuesto(montoCentavos: costo?.centavos),
        Text(
          '$hechos de ${items.length} comprados',
          style: v.lectura(
            tamano: 16,
            peso: FontWeight.w600,
            color: v.textoFuerte,
          ),
        ),
        if (costo != null)
          Text(
            'Costo de la lista: ${costoTexto(costo.centavos, estimado: costo.estimado)}'
            '${costo.sinPrecio > 0 ? ' · ${costo.sinPrecio} sin precio' : ''}',
            style: v.lectura(tamano: 15, color: v.texto),
          )
        else
          Text(
            'Sin precios todavía: no se calcula el costo.',
            style: v.lectura(tamano: 14, color: v.textoTenue),
          ),
        if (items.any((i) => i.costoEstimado && i.costoCentavos != null))
          Text(
            'Precios base de supuesto: $notaPrecioBase.',
            style: v.lectura(tamano: 14, color: v.textoTenue),
          ),
        if (editar)
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                key: const Key('agregar_a_lista'),
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Agregar a la lista'),
                onPressed: () => _agregar(context, ref),
              ),
              if (menu == MenuId.papa &&
                  (ref.watch(esAlbaceaAlimentacionProvider).value ?? false))
                OutlinedButton.icon(
                  key: const Key('solicitudes_papa'),
                  icon: const Icon(Icons.approval_outlined),
                  label: const Text('Pagos pendientes de Papá'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PantallaSolicitudesPapa(),
                    ),
                  ),
                ),
              OutlinedButton.icon(
                key: const Key('escanear_codigo'),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Escanear código'),
                onPressed: () => _escanear(context, ref, items),
              ),
              OutlinedButton.icon(
                key: const Key('historial_precios'),
                icon: const Icon(Icons.history),
                label: const Text('Historial de precios'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PantallaHistorialPrecios(),
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: 8),
        for (final g in grupos.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Text(
              'Pasillo · ${g.key.etiqueta}',
              style: v.titulo(tamano: 18, color: v.etiqueta),
            ),
          ),
          for (final i in g.value)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: i.comprado,
              onChanged: editar
                  ? (marca) async {
                      final semana = ref.read(semanaAlimentacionProvider);
                      await ref
                          .read(servicioAlimentacionProvider)
                          .marcar(menu, semana, i.clave, marca ?? false);
                      ref.read(versionAlimentacionProvider.notifier).state++;
                    }
                  : null,
              title: Text(
                '${i.nombre} · ${cantidadTexto(i.cantidad)} ${i.unidad}',
                style: v
                    .lectura(
                      tamano: 16,
                      color: i.comprado ? v.textoTenue : v.texto,
                    )
                    .copyWith(
                      decoration: i.comprado
                          ? TextDecoration.lineThrough
                          : null,
                    ),
              ),
              subtitle: Text(
                [
                  if (i.pendienteAlbacea)
                    'Pendiente de pago del albacea'
                  else if (i.comprado)
                    'Comprado',
                  _textoPrecio(i),
                ].join(' · '),
              ),
              secondary: editar
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Ficha del ingrediente',
                          onPressed: () => _abrirFicha(context, ref, i),
                        ),
                        IconButton(
                          icon: const Icon(Icons.price_check_outlined),
                          tooltip: 'Registrar compra con precio',
                          onPressed: () => _registrar(context, ref, i),
                        ),
                      ],
                    )
                  : null,
            ),
        ],
      ],
    );
  }
}
