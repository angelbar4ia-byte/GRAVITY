/// "Registrar movimiento" en la laptop: gasto (con división por líneas),
/// ingreso, transferencia (también aportación a otro libro), pago de deuda,
/// reembolso y reclasificación (tabla de 4.3).
library;

import 'package:finanzas_dominio/finanzas_dominio.dart'
    hide Semaforo, formatearCentavos, TipoLibro, puntosBaseEnCien;
import 'package:finanzas_dominio/finanzas_dominio.dart' as dom show TipoLibro;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../diseno/diseno.dart';
import '../../../../nucleo/contratos/roles.dart';
import '../../casos_uso/servicio_finanzas.dart';
import '../../casos_uso/sugerencias.dart';
import '../../estado/proveedores.dart';
import '../comunes.dart';
import '../registro/hoja_gasto.dart';

Future<void> mostrarDialogoMovimiento(BuildContext context, ContextoFinanzas c) =>
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640, maxHeight: 760),
          child: DialogoMovimiento(contexto: c),
        ),
      ),
    );

class _Linea {
  String? categoriaId;
  final monto = TextEditingController();
}

class DialogoMovimiento extends ConsumerStatefulWidget {
  const DialogoMovimiento({super.key, required this.contexto});

  final ContextoFinanzas contexto;

  @override
  ConsumerState<DialogoMovimiento> createState() => _DialogoMovimientoState();
}

class _DialogoMovimientoState extends ConsumerState<DialogoMovimiento> {
  final _forma = GlobalKey<FormState>();
  TipoMovimiento _tipo = TipoMovimiento.gasto;
  String? _origen;
  String? _destino;
  String? _categoria;
  final _lineas = [_Linea()];
  final _monto = TextEditingController();
  final _nota = TextEditingController();
  final _motivo = TextEditingController();
  late Fecha _fecha = widget.contexto.hoy;
  bool _guardando = false;

  ContextoFinanzas get c => widget.contexto;
  DatosFinanzas get d => c.datos;

  @override
  void dispose() {
    for (final l in _lineas) {
      l.monto.dispose();
    }
    _monto.dispose();
    _nota.dispose();
    _motivo.dispose();
    super.dispose();
  }

  List<Cuenta> _cuentasLibro(bool Function(Cuenta) filtro) => [
    for (final x in d.cuentasDe(c.libroId))
      if (x.estado == EstadoCuenta.activa && filtro(x)) x,
  ];

  /// Activos de los libros donde la persona escribe (aportación a otro libro).
  List<Cuenta> _activosEscribibles() => [
    for (final l in c.libros)
      if (c.permisoEn(l).escribir)
        for (final x in d.cuentasDe(l.id))
          if (x.estado == EstadoCuenta.activa && x.clase == ClaseCuenta.activo) x,
  ];

  List<Categoria> get _categorias => [
    for (final x in d.arbol.todas)
      if (x.visible) x,
  ]..sort((a, b) => d.arbol.ruta(a.id).compareTo(d.arbol.ruta(b.id)));

  Widget _desplegableCuenta(
    String etiqueta,
    List<Cuenta> cuentas,
    String? valor,
    ValueChanged<String?> alCambiar, {
    Key? key,
  }) => DropdownButtonFormField<String>(
    key: key,
    initialValue: cuentas.any((x) => x.id == valor) ? valor : null,
    decoration: InputDecoration(labelText: etiqueta),
    items: [
      for (final x in cuentas)
        DropdownMenuItem(
          value: x.id,
          child: Text(
            x.libroId == c.libroId || x.libroId == null
                ? x.nombre
                : '${x.nombre} (${d.libro(x.libroId!)?.nombre ?? ''})',
          ),
        ),
    ],
    onChanged: alCambiar,
    validator: (v) => v == null ? 'Elige una cuenta' : null,
  );

  Widget _desplegableCategoria(
    String? valor,
    ValueChanged<String?> alCambiar, {
    bool conPorClasificar = true,
    Key? key,
  }) => DropdownButtonFormField<String?>(
    key: key,
    initialValue: valor,
    isExpanded: true,
    decoration: const InputDecoration(labelText: 'Categoría'),
    items: [
      if (conPorClasificar)
        const DropdownMenuItem<String?>(value: null, child: Text('Por clasificar')),
      for (final x in _categorias)
        DropdownMenuItem<String?>(value: x.id, child: Text(d.arbol.ruta(x.id))),
    ],
    onChanged: alCambiar,
  );

  Future<void> _guardar() async {
    if (!(_forma.currentState?.validate() ?? false)) return;
    setState(() => _guardando = true);
    final servicio = ref.read(servicioFinanzasProvider);
    final navegador = Navigator.of(context);
    final motivo = _motivo.text.trim().isEmpty ? null : _motivo.text.trim();
    try {
      final ResultadoRegistro r;
      switch (_tipo) {
        case TipoMovimiento.gasto:
          r = await servicio.registrarGasto(
            libroId: c.libroId,
            cuentaOrigenId: _origen!,
            lineas: [
              for (final l in _lineas)
                LineaGasto(
                  monto: centavosDeTexto(l.monto.text)!,
                  categoriaId: l.categoriaId,
                ),
            ],
            fecha: _fecha,
            nota: _nota.text,
            motivo: motivo,
          );
        case TipoMovimiento.reembolso:
        case TipoMovimiento.reclasificacion:
          final cuentaGasto = _categoria == null
              ? null
              : d.arbol.cuentaGastoDe(_categoria!);
          final porClasificar = d.parametrosDe(c.libroId).cuentaPorClasificarId;
          r = await servicio.registrarMovimiento(
            tipo: _tipo,
            cuentaOrigenId: _tipo == TipoMovimiento.reembolso
                ? cuentaGasto!
                : porClasificar!,
            cuentaDestinoId: _tipo == TipoMovimiento.reembolso
                ? _destino!
                : cuentaGasto!,
            monto: centavosDeTexto(_monto.text)!,
            fecha: _fecha,
            categoriaId: _categoria,
            nota: _nota.text,
            motivo: motivo,
          );
        default:
          r = await servicio.registrarMovimiento(
            tipo: _tipo,
            cuentaOrigenId: _origen!,
            cuentaDestinoId: _destino!,
            monto: centavosDeTexto(_monto.text)!,
            fecha: _fecha,
            nota: _nota.text,
            motivo: motivo,
          );
      }
      if (mounted) avisarGuardado(context, r, servicio);
      navegador.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        avisarError(context, e);
      }
    }
  }

  List<Widget> _campos() {
    final pagar = cuentasParaPagar(d, c.libroId);
    final recibir = cuentasParaRecibir(d, c.libroId);
    switch (_tipo) {
      case TipoMovimiento.gasto:
        return [
          _desplegableCuenta(
            'Pagado con',
            pagar,
            _origen,
            (v) => setState(() => _origen = v),
            key: const ValueKey('movimiento-origen'),
          ),
          for (var i = 0; i < _lineas.length; i++)
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _desplegableCategoria(
                    _lineas[i].categoriaId,
                    (v) => setState(() => _lineas[i].categoriaId = v),
                    key: ValueKey('movimiento-linea-$i-categoria'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: CampoMonto(
                    key: ValueKey('movimiento-linea-$i-monto'),
                    controlador: _lineas[i].monto,
                    etiqueta: 'Monto',
                  ),
                ),
                if (_lineas.length > 1)
                  IconButton(
                    tooltip: 'Quitar línea',
                    onPressed: () => setState(() => _lineas.removeAt(i)),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
              ],
            ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: const ValueKey('movimiento-agregar-linea'),
              onPressed: () => setState(() => _lineas.add(_Linea())),
              icon: const Icon(Icons.call_split),
              label: const Text('Dividir en otra línea (otro rubro)'),
            ),
          ),
        ];
      case TipoMovimiento.ingreso:
        return [
          _desplegableCuenta(
            'Origen del ingreso',
            _cuentasLibro((x) => x.tipo == TipoCuenta.origenIngreso),
            _origen,
            (v) => setState(() => _origen = v),
          ),
          _desplegableCuenta('Entró a', recibir, _destino, (v) => setState(() => _destino = v)),
          CampoMonto(controlador: _monto, etiqueta: 'Monto'),
        ];
      case TipoMovimiento.transferencia:
        return [
          _desplegableCuenta('Sale de', recibir, _origen, (v) => setState(() => _origen = v)),
          _desplegableCuenta(
            'Entra a (puede ser otro libro: aportación)',
            [for (final x in _activosEscribibles()) if (x.id != _origen) x],
            _destino,
            (v) => setState(() => _destino = v),
          ),
          CampoMonto(controlador: _monto, etiqueta: 'Monto'),
        ];
      case TipoMovimiento.pagoDeuda:
        return [
          _desplegableCuenta('Sale de', recibir, _origen, (v) => setState(() => _origen = v)),
          _desplegableCuenta(
            'Deuda (tarjeta o préstamo)',
            _cuentasLibro((x) => x.clase == ClaseCuenta.pasivo),
            _destino,
            (v) => setState(() => _destino = v),
          ),
          CampoMonto(
            controlador: _monto,
            etiqueta: 'Capital pagado',
            ayuda: 'Los intereses van aparte, como gasto financiero.',
          ),
        ];
      case TipoMovimiento.reembolso:
        return [
          _desplegableCategoria(
            _categoria,
            (v) => setState(() => _categoria = v),
            conPorClasificar: false,
          ),
          _desplegableCuenta(
            'Regresó a',
            [...recibir, ..._cuentasLibro((x) => x.clase == ClaseCuenta.pasivo)],
            _destino,
            (v) => setState(() => _destino = v),
          ),
          CampoMonto(
            controlador: _monto,
            etiqueta: 'Monto',
            ayuda: 'Un reembolso baja el gasto; no es ingreso.',
          ),
        ];
      case TipoMovimiento.reclasificacion:
        return [
          _desplegableCategoria(
            _categoria,
            (v) => setState(() => _categoria = v),
            conPorClasificar: false,
          ),
          CampoMonto(controlador: _monto, etiqueta: 'Monto que se clasifica'),
        ];
      default:
        return const [];
    }
  }

  /// El libro representado (papá) que toca este movimiento, si lo hay: el
  /// libro activo o el de la cuenta elegida (una aportación hacia o desde su
  /// libro también va en su nombre y pide motivo).
  Libro? _libroRepresentado() {
    Libro? deCuenta(String? cuentaId) {
      final libroId = d.cuenta(cuentaId ?? '')?.libroId;
      final libro = libroId == null ? null : d.libro(libroId);
      return libro?.tipo == dom.TipoLibro.representado ? libro : null;
    }

    final activo = c.libro!;
    if (activo.tipo == dom.TipoLibro.representado) return activo;
    return deCuenta(_origen) ?? deCuenta(_destino);
  }

  @override
  Widget build(BuildContext context) {
    final representadoLibro = _libroRepresentado();
    final representado = representadoLibro != null;
    return TemaModulo(
      modulo: Modulo.finanzas,
      child: Form(
        key: _forma,
        child: ListView(
          padding: const EdgeInsets.all(24),
          shrinkWrap: true,
          children: [
            Text('Registrar movimiento', style: Theme.of(context).textTheme.titleLarge),
            Text('Libro: ${opcionDe(c.libro!, c.permiso, c.personaId).etiqueta}'),
            const SizedBox(height: 12),
            SegmentedButton<TipoMovimiento>(
              key: const ValueKey('movimiento-tipo'),
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: TipoMovimiento.gasto, label: Text('Gasto')),
                ButtonSegment(value: TipoMovimiento.ingreso, label: Text('Ingreso')),
                ButtonSegment(
                  value: TipoMovimiento.transferencia,
                  label: Text('Transferencia'),
                ),
                ButtonSegment(
                  value: TipoMovimiento.pagoDeuda,
                  label: Text('Pago de deuda'),
                ),
                ButtonSegment(value: TipoMovimiento.reembolso, label: Text('Reembolso')),
                ButtonSegment(
                  value: TipoMovimiento.reclasificacion,
                  label: Text('Clasificar'),
                ),
              ],
              selected: {_tipo},
              onSelectionChanged: (s) => setState(() {
                _tipo = s.first;
                _origen = null;
                _destino = null;
              }),
            ),
            const SizedBox(height: 12),
            ..._campos(),
            const SizedBox(height: 8),
            Row(
              children: [
                ActionChip(
                  avatar: const Icon(Icons.event_outlined, size: 18),
                  label: Text(_fecha == c.hoy ? 'Hoy' : textoFecha(_fecha)),
                  onPressed: () async {
                    final f = await elegirFecha(context, _fecha);
                    if (f != null) setState(() => _fecha = f);
                  },
                ),
              ],
            ),
            TextField(
              controller: _nota,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'Nota (opcional)'),
            ),
            if (representado)
              TextFormField(
                key: const ValueKey('movimiento-motivo'),
                controller: _motivo,
                maxLength: 200,
                decoration: InputDecoration(
                  labelText: 'Motivo (obligatorio)',
                  helperText:
                      '$ayudaDelMotivo Se registra en nombre de ${representadoLibro.nombre}.',
                  helperMaxLines: 3,
                ),
                validator: (v) => motivoValido(v) ? null : mensajeMotivoCorto,
              ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  key: const ValueKey('movimiento-guardar'),
                  onPressed: _guardando ? null : _guardar,
                  child: const Text('Guardar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
