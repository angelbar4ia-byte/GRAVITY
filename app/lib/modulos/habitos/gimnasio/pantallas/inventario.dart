/// E2 · Inventario: aparatos, puestos, bandas y accesorios, con *Confirmar en el
/// aparato* (F-E5) para lo que el diseño no confirma (3.1, 3.2 y CA-G-04).
///
/// Lo que está «sin confirmar» no entra a ningún cálculo; la carga se ve en
/// placas, sin kilos, hasta que la persona lo escribe.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habitos_dominio/habitos_dominio.dart' hide EstadoDiaPlan;

import '../../../../app/gimnasio/acceso_gimnasio.dart';
import '../../../../diseno/componentes/tarjeta_modulo.dart';
import '../../../../diseno/gimnasio/gimnasio.dart';
import '../../../../diseno/valores_diseno.dart';
import '../../../../nucleo/base_local/base_local.dart' show GimBandaFila;
import '../casos_uso/servicio_gimnasio.dart';
import '../datos/modelos_gimnasio.dart';
import '../estado/proveedores_gimnasio.dart';
import 'comun.dart';

/// Un dato del aparato que la persona confirma.
enum TipoCampo { entero, decimalX10, siNo, polea }

class CampoAparato {
  const CampoAparato(
    this.campo,
    this.etiqueta,
    this.instruccion,
    this.tipo, {
    this.maximo = 1000,
  });

  final String campo;
  final String etiqueta;
  final String instruccion;
  final TipoCampo tipo;
  final int maximo;
}

const camposDelMarcy = <CampoAparato>[
  CampoAparato(
    CamposAparato.pasosMax,
    'Placas de la pila',
    'Mueve el pasador a la última placa y cuenta las placas.',
    TipoCampo.entero,
    maximo: 60,
  ),
  CampoAparato(
    CamposAparato.kgPorPasoX10,
    'Kilos por placa',
    'Mira la etiqueta o el manual: cuántos kilos es cada placa.',
    TipoCampo.decimalX10,
    maximo: 2000,
  ),
  CampoAparato(
    CamposAparato.relacionPolea,
    'Polea',
    'Mira el manual: la polea es 1 a 1 o 2 a 1.',
    TipoCampo.polea,
  ),
  CampoAparato(
    CamposAparato.anclajeEstacion,
    'Punto de anclaje para bandas',
    '¿Hay un punto de anclaje seguro para bandas en la estación?',
    TipoCampo.siNo,
  ),
];

const camposDelBanco = <CampoAparato>[
  CampoAparato(
    CamposAparato.bancoPlano,
    'El banco se ajusta a plano',
    'Revisa si el respaldo baja hasta quedar plano.',
    TipoCampo.siNo,
  ),
  CampoAparato(
    CamposAparato.capacidadBancoKg,
    'Carga máxima del banco (kg)',
    'Mira la etiqueta o el manual: cuántos kilos aguanta.',
    TipoCampo.entero,
    maximo: 500,
  ),
];

String _textoDeCampo(CampoAparato c, int valor) => switch (c.tipo) {
  TipoCampo.entero => c.campo == CamposAparato.pasosMax
      ? '$valor placas'
      : '$valor',
  TipoCampo.decimalX10 => '${valor ~/ 10}.${valor % 10} kg',
  TipoCampo.siNo => valor == 1 ? 'Sí' : 'No',
  TipoCampo.polea => valor == 2 ? '2:1' : '1:1',
};

List<DatoAparatoVista> _datos(
  List<CampoAparato> campos,
  Inventario inv,
  List<DatoAparatoVista> antes,
) => [
  ...antes,
  for (final c in campos)
    DatoAparatoVista(
      etiqueta: c.etiqueta,
      valorTexto: inv.confirmaciones.containsKey(c.campo)
          ? _textoDeCampo(c, inv.confirmaciones[c.campo]!)
          : null,
      confirmacion: inv.confirmaciones.containsKey(c.campo)
          ? EstadoConfirmacionDato.confirmado
          : EstadoConfirmacionDato.confirmar,
    ),
];

DisponibilidadAparato _disp(EstadoItem? e) => switch (e) {
  EstadoItem.disponible => DisponibilidadAparato.disponible,
  EstadoItem.futuro => DisponibilidadAparato.futuro,
  _ => DisponibilidadAparato.noDisponible,
};

class PantallaInventario extends ConsumerWidget {
  const PantallaInventario({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicio = ref.watch(servicioGimnasioProvider);
    return MarcoGimnasio(
      destino: DestinoGimnasio.inventario,
      cuerpo: servicio == null
          ? const SinPersonaGimnasio()
          : vistaAsincrona<DatosGimnasio?>(
              ref.watch(datosGimnasioProvider),
              alReintentar: () => ref.invalidate(datosGimnasioProvider),
              listo: (d) => d == null
                  ? const SinPersonaGimnasio()
                  : _CuerpoInventario(datos: d, servicio: servicio),
            ),
    );
  }
}

class _CuerpoInventario extends ConsumerWidget {
  const _CuerpoInventario({required this.datos, required this.servicio});

  final DatosGimnasio datos;
  final ServicioGimnasio servicio;

  Future<void> _guardar(WidgetRef ref, Future<void> Function() f) async {
    await f();
    ref.read(versionGimnasioProvider.notifier).state++;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inv = datos.inventario;
    final c = servicio.catalogo;
    final v = ValoresDiseno.de(context);
    final gap = SizedBox(height: v.espacio * 2);
    EstadoItem? estado(String id) => inv.estadoDe(id);

    PuestoVista puesto(ItemEquipo i) => PuestoVista(
      nombre: i.nombre,
      disponibilidad: _disp(estado(i.id)),
      alCambiar: () => _guardar(
        ref,
        () => servicio.guardarEstadoItem(
          datos,
          i.id,
          estado(i.id) == EstadoItem.disponible
              ? EstadoItem.noDisponible
              : EstadoItem.disponible,
        ),
      ),
    );

    final marcy = c.item('marcy_mwm7119')!;
    final puestos = [
      for (final i in c.items)
        if (i.padre == marcy.id && i.id != 'marcy.otros') puesto(i),
      for (final e in inv.items.entries)
        if (e.key.startsWith('otro:'))
          PuestoVista(
            nombre: e.key.substring(5),
            disponibilidad: _disp(e.value),
            alCambiar: () => _guardar(
              ref,
              () => servicio.guardarEstadoItem(
                datos,
                e.key,
                e.value == EstadoItem.disponible
                    ? EstadoItem.noDisponible
                    : EstadoItem.disponible,
              ),
            ),
          ),
    ];

    final futuros = {
      ...inv.equipoFuturo,
      if (c.items.any((i) => i.soloDato)) ...[
        for (final i in c.items)
          if (i.soloDato) i.id,
      ],
    }.toList()..sort();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TarjetaAparato(
          nombre: marcy.nombre,
          categoriaTexto: 'Estación',
          detalle: 'Pila, poleas alta y baja, brazos de press y cojín de curl.',
          disponibilidad: _disp(estado(marcy.id)),
          puestos: puestos,
          datos: _datos(
            camposDelMarcy,
            inv,
            [
              DatoAparatoVista(
                etiqueta: 'Peso de la pila',
                valorTexto: textoPilaAproximada(c),
                confirmacion: EstadoConfirmacionDato.delDiseno,
              ),
            ],
          ),
          alConfirmar: () => _confirmar(context, ref, 'Estación Marcy', camposDelMarcy),
          alCambiarDisponibilidad: () => _guardar(
            ref,
            () => servicio.guardarEstadoItem(
              datos,
              marcy.id,
              estado(marcy.id) == EstadoItem.disponible
                  ? EstadoItem.noDisponible
                  : EstadoItem.disponible,
            ),
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            key: const ValueKey('agregar-puesto'),
            onPressed: () => _agregarPuesto(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Agregar un puesto del Marcy'),
          ),
        ),
        gap,
        TarjetaAparato(
          nombre: c.item('banco_inclinado')!.nombre,
          categoriaTexto: 'Banco',
          icono: Icons.event_seat_outlined,
          disponibilidad: _disp(estado('banco_inclinado')),
          datos: _datos(camposDelBanco, inv, const []),
          alConfirmar: () => _confirmar(context, ref, 'Banco inclinado', camposDelBanco),
          alCambiarDisponibilidad: () => _guardar(
            ref,
            () => servicio.guardarEstadoItem(
              datos,
              'banco_inclinado',
              estado('banco_inclinado') == EstadoItem.disponible
                  ? EstadoItem.noDisponible
                  : EstadoItem.disponible,
            ),
          ),
        ),
        gap,
        TarjetaAparato(
          nombre: c.item('caminadora')!.nombre,
          categoriaTexto: 'Caminadora',
          icono: Icons.directions_walk,
          disponibilidad: _disp(estado('caminadora')),
          alCambiarDisponibilidad: () => _guardar(
            ref,
            () => servicio.guardarEstadoItem(
              datos,
              'caminadora',
              estado('caminadora') == EstadoItem.disponible
                  ? EstadoItem.noDisponible
                  : EstadoItem.disponible,
            ),
          ),
        ),
        gap,
        _TarjetaBandas(datos: datos, servicio: servicio),
        gap,
        TarjetaModulo(
          titulo: 'Accesorios',
          icono: Icons.handyman_outlined,
          child: Column(
            children: [
              for (final id in const [
                'ancla_puerta',
                'colchoneta',
                'tobillera_polea',
              ])
                SwitchListTile(
                  key: ValueKey('accesorio-$id'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(c.item(id)!.nombre),
                  subtitle: Text(
                    estado(id) == EstadoItem.disponible
                        ? DisponibilidadAparato.disponible.texto
                        : 'Todavía no',
                  ),
                  value: estado(id) == EstadoItem.disponible,
                  onChanged: (si) => _guardar(
                    ref,
                    () => servicio.guardarEstadoItem(
                      datos,
                      id,
                      si ? EstadoItem.disponible : EstadoItem.noDisponible,
                    ),
                  ),
                ),
            ],
          ),
        ),
        for (final id in futuros) ...[
          gap,
          TarjetaAparato(
            key: ValueKey('futuro-$id'),
            nombre: c.item(id)?.nombre ?? id,
            categoriaTexto: 'Equipo futuro',
            icono: Icons.fitness_center,
            detalle: TextosGimnasio.equipoFuturoNota,
            disponibilidad: DisponibilidadAparato.futuro,
          ),
        ],
        gap,
        const TarjetaContenidoEnRevision(compacta: true),
      ],
    );
  }

  Future<void> _agregarPuesto(BuildContext context, WidgetRef ref) async {
    final texto = await _pedirTexto(context, 'Nombre del puesto', 55);
    if (texto == null || texto.trim().isEmpty) return;
    await servicio.agregarPuestoSuelto(texto);
    ref.read(versionGimnasioProvider.notifier).state++;
  }

  Future<void> _confirmar(
    BuildContext context,
    WidgetRef ref,
    String aparato,
    List<CampoAparato> campos,
  ) async {
    final r = await showDialog<Map<String, int?>>(
      context: context,
      builder: (_) => _DialogoConfirmar(
        aparato: aparato,
        campos: campos,
        actuales: datos.inventario.confirmaciones,
      ),
    );
    if (r == null) return;
    for (final e in r.entries) {
      if (e.value == null) {
        await servicio.olvidarDato(datos, e.key);
      } else {
        await servicio.confirmarDato(datos, e.key, e.value!);
      }
    }
    ref.read(versionGimnasioProvider.notifier).state++;
  }
}

Future<String?> _pedirTexto(BuildContext context, String etiqueta, int max) =>
    showDialog<String>(
      context: context,
      builder: (context) {
        final c = TextEditingController();
        return AlertDialog(
          title: Text(etiqueta),
          content: TextField(
            controller: c,
            autofocus: true,
            maxLength: max,
            decoration: InputDecoration(labelText: etiqueta),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, c.text),
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

/// «Confirmar en el aparato» (F-E5): un campo con su instrucción por dato. Lo
/// que se deja vacío queda «sin confirmar». Devuelve campo → valor (`null`
/// quita la confirmación).
class _DialogoConfirmar extends StatefulWidget {
  const _DialogoConfirmar({
    required this.aparato,
    required this.campos,
    required this.actuales,
  });

  final String aparato;
  final List<CampoAparato> campos;
  final Map<String, int> actuales;

  @override
  State<_DialogoConfirmar> createState() => _EstadoDialogoConfirmar();
}

class _EstadoDialogoConfirmar extends State<_DialogoConfirmar> {
  late final Map<String, TextEditingController> _texto;
  late final Map<String, int?> _valor;

  @override
  void initState() {
    super.initState();
    _valor = {for (final c in widget.campos) c.campo: widget.actuales[c.campo]};
    _texto = {
      for (final c in widget.campos)
        if (c.tipo == TipoCampo.entero || c.tipo == TipoCampo.decimalX10)
          c.campo: TextEditingController(
            text: widget.actuales[c.campo] == null
                ? ''
                : c.tipo == TipoCampo.decimalX10
                ? '${widget.actuales[c.campo]! ~/ 10}.${widget.actuales[c.campo]! % 10}'
                : '${widget.actuales[c.campo]}',
          ),
    };
  }

  @override
  void dispose() {
    for (final c in _texto.values) {
      c.dispose();
    }
    super.dispose();
  }

  int? _leer(CampoAparato c) {
    final t = _texto[c.campo]!.text.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    if (c.tipo == TipoCampo.decimalX10) {
      final d = double.tryParse(t);
      if (d == null) return null;
      final x10 = (d * 10).round();
      return x10 >= 1 && x10 <= c.maximo ? x10 : null;
    }
    final n = int.tryParse(t);
    return n != null && n >= 1 && n <= c.maximo ? n : null;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('${TextosGimnasio.confirmarEnElAparato}: ${widget.aparato}'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final c in widget.campos) ...[
            Text(c.etiqueta, style: Theme.of(context).textTheme.titleSmall),
            Text(c.instruccion),
            const SizedBox(height: 4),
            switch (c.tipo) {
              TipoCampo.entero || TipoCampo.decimalX10 => TextField(
                key: ValueKey('campo-${c.campo}'),
                controller: _texto[c.campo],
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: InputDecoration(
                  labelText: c.etiqueta,
                  helperText: 'Déjalo vacío si aún no lo verificas.',
                ),
              ),
              TipoCampo.siNo => SegmentedButton<int?>(
                segments: const [
                  ButtonSegment(value: 1, label: Text('Sí')),
                  ButtonSegment(value: 0, label: Text('No')),
                  ButtonSegment(value: null, label: Text('Sin verificar')),
                ],
                selected: {_valor[c.campo]},
                emptySelectionAllowed: true,
                onSelectionChanged: (s) =>
                    setState(() => _valor[c.campo] = s.firstOrNull),
              ),
              TipoCampo.polea => SegmentedButton<int?>(
                segments: const [
                  ButtonSegment(value: 1, label: Text('1:1')),
                  ButtonSegment(value: 2, label: Text('2:1')),
                  ButtonSegment(value: null, label: Text('Sin verificar')),
                ],
                selected: {_valor[c.campo]},
                emptySelectionAllowed: true,
                onSelectionChanged: (s) =>
                    setState(() => _valor[c.campo] = s.firstOrNull),
              ),
            },
            const SizedBox(height: 16),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        key: const ValueKey('guardar-confirmacion'),
        onPressed: () {
          final r = <String, int?>{};
          for (final c in widget.campos) {
            final v = _texto.containsKey(c.campo) ? _leer(c) : _valor[c.campo];
            // Solo cambia lo que cambió.
            if (v != widget.actuales[c.campo]) r[c.campo] = v;
          }
          Navigator.pop(context, r);
        },
        child: const Text('Guardar'),
      ),
    ],
  );
}

/// Las bandas de la persona, de la más ligera a la más fuerte (ella las ordena).
class _TarjetaBandas extends ConsumerWidget {
  const _TarjetaBandas({required this.datos, required this.servicio});

  final DatosGimnasio datos;
  final ServicioGimnasio servicio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bandas = datos.bandasFilas;
    Future<void> hecho(Future<Object?> f) async {
      await f;
      ref.read(versionGimnasioProvider.notifier).state++;
    }

    return TarjetaModulo(
      titulo: 'Bandas de resistencia',
      icono: Icons.linear_scale,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (bandas.isEmpty)
            const Text(
              'Agrega tus bandas, de la más ligera a la más fuerte. Con ellas '
              'puedes hacer la sesión aunque la estación no esté.',
            ),
          for (var i = 0; i < bandas.length; i++)
            ListTile(
              key: ValueKey('banda-${bandas[i].id}'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                '${bandas[i].nombre}'
                '${bandas[i].cantidad > 1 ? ' ×${bandas[i].cantidad}' : ''}',
              ),
              subtitle: Text(
                bandas[i].resistenciaKgX10 == null
                    ? 'Sin kilos (los kilos son de la etiqueta)'
                    : '${bandas[i].resistenciaKgX10! ~/ 10}.'
                          '${bandas[i].resistenciaKgX10! % 10} kg · de la etiqueta',
              ),
              leading: Switch(
                value: bandas[i].activa,
                onChanged: (a) => hecho(
                  servicio.guardarBanda(
                    datos,
                    id: bandas[i].id,
                    nombre: bandas[i].nombre,
                    orden: bandas[i].orden,
                    resistenciaKgX10: bandas[i].resistenciaKgX10,
                    cantidad: bandas[i].cantidad,
                    activa: a,
                  ),
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Subir (más ligera)',
                    onPressed: i == 0
                        ? null
                        : () => hecho(_intercambiar(bandas[i], bandas[i - 1])),
                    icon: const Icon(Icons.arrow_upward),
                  ),
                  IconButton(
                    tooltip: 'Bajar (más fuerte)',
                    onPressed: i == bandas.length - 1
                        ? null
                        : () => hecho(_intercambiar(bandas[i], bandas[i + 1])),
                    icon: const Icon(Icons.arrow_downward),
                  ),
                  IconButton(
                    tooltip: 'Quitar esta banda',
                    onPressed: () => hecho(servicio.borrarBanda(bandas[i].id)),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: const ValueKey('agregar-banda'),
              onPressed: () async {
                final r = await showDialog<_BandaNueva>(
                  context: context,
                  builder: (_) => const _DialogoBanda(),
                );
                if (r == null) return;
                await hecho(
                  servicio.guardarBanda(
                    datos,
                    nombre: r.nombre,
                    cantidad: r.cantidad,
                    resistenciaKgX10: r.kgX10,
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Agregar banda'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _intercambiar(GimBandaFila a, GimBandaFila b) async {
    await servicio.guardarBanda(
      datos,
      id: a.id,
      nombre: a.nombre,
      orden: b.orden,
      resistenciaKgX10: a.resistenciaKgX10,
      cantidad: a.cantidad,
      activa: a.activa,
    );
    await servicio.guardarBanda(
      datos,
      id: b.id,
      nombre: b.nombre,
      orden: a.orden,
      resistenciaKgX10: b.resistenciaKgX10,
      cantidad: b.cantidad,
      activa: b.activa,
    );
  }
}

class _BandaNueva {
  const _BandaNueva(this.nombre, this.cantidad, this.kgX10);
  final String nombre;
  final int cantidad;
  final int? kgX10;
}

class _DialogoBanda extends StatefulWidget {
  const _DialogoBanda();

  @override
  State<_DialogoBanda> createState() => _EstadoDialogoBanda();
}

class _EstadoDialogoBanda extends State<_DialogoBanda> {
  final _nombre = TextEditingController();
  final _kg = TextEditingController();
  int _cantidad = 1;

  @override
  void dispose() {
    _nombre.dispose();
    _kg.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Agregar banda'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey('banda-nombre'),
            controller: _nombre,
            maxLength: 40,
            decoration: const InputDecoration(
              labelText: 'Color o etiqueta',
            ),
          ),
          TextField(
            key: const ValueKey('banda-kg'),
            controller: _kg,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Kilos de la etiqueta (opcional)',
              helperText: 'Solo si los lees de la banda.',
            ),
          ),
          Row(
            children: [
              const Expanded(child: Text('Cuántas tienes')),
              IconButton(
                tooltip: 'Una menos',
                onPressed: _cantidad > 1
                    ? () => setState(() => _cantidad--)
                    : null,
                icon: const Icon(Icons.remove),
              ),
              Text('$_cantidad'),
              IconButton(
                tooltip: 'Una más',
                onPressed: _cantidad < 10
                    ? () => setState(() => _cantidad++)
                    : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        key: const ValueKey('banda-guardar'),
        onPressed: () {
          final n = _nombre.text.trim();
          if (n.isEmpty) return;
          final d = double.tryParse(_kg.text.trim().replaceAll(',', '.'));
          final x10 = d == null ? null : (d * 10).round();
          Navigator.pop(
            context,
            _BandaNueva(
              n,
              _cantidad,
              x10 != null && x10 >= 1 && x10 <= 2000 ? x10 : null,
            ),
          );
        },
        child: const Text('Guardar'),
      ),
    ],
  );
}
