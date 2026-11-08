/// Gasto desde un recibo fotografiado (Fase 8, bloque 4). Muestra lo que se
/// **propone** (monto, concepto y fecha leídos en el teléfono) para que la
/// persona lo corrija y lo confirme; **nada se guarda** hasta *Guardar*. La
/// foto se guarda como comprobante solo en este teléfono.
library;

import 'package:finanzas_dominio/finanzas_dominio.dart'
    hide
        Semaforo,
        formatearCentavos,
        TipoLibro,
        VisibilidadLibro,
        puntosBaseEnCien;
import 'package:finanzas_dominio/finanzas_dominio.dart' as dom show TipoLibro;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../diseno/diseno.dart';
import '../../casos_uso/gasto_desde_recibo.dart';
import '../../casos_uso/sugerencias.dart';
import '../../estado/proveedores.dart';
import '../../estado/proveedores_recibo.dart';
import '../comunes.dart';
import 'hoja_gasto.dart' show avisarGuardado, librosParaRegistrar;
import 'marco_hoja.dart';

class HojaGastoDesdeRecibo extends ConsumerStatefulWidget {
  const HojaGastoDesdeRecibo({super.key, required this.recibo});

  final ReciboImagen recibo;

  @override
  ConsumerState<HojaGastoDesdeRecibo> createState() => _HojaReciboState();
}

class _HojaReciboState extends ConsumerState<HojaGastoDesdeRecibo> {
  final _monto = TextEditingController();
  final _concepto = TextEditingController();
  final _motivo = TextEditingController();
  PropuestaGasto? _propuesta;
  Fecha? _fecha;
  String? _libroId;
  String? _cuentaId;
  String? _categoriaId;
  bool _guardando = false;

  @override
  void dispose() {
    _monto.dispose();
    _concepto.dispose();
    _motivo.dispose();
    super.dispose();
  }

  void _iniciar(ContextoFinanzas c) {
    if (_propuesta != null) return;
    final p = proponerGastoDeRecibo(widget.recibo.textoLeido, c.hoy);
    _propuesta = p;
    _fecha = p.fecha;
    _concepto.text = p.concepto;
    if (p.montoCentavos != null) {
      _monto.text = (p.montoCentavos! / 100).toStringAsFixed(2);
    }
  }

  Future<void> _guardar(ContextoFinanzas c, Libro libro) async {
    if (_guardando) return;
    final monto = centavosDeTexto(_monto.text);
    if (monto == null || monto <= 0 || _cuentaId == null) return;
    setState(() => _guardando = true);
    final navegador = Navigator.of(context);
    final servicio = ref.read(servicioFinanzasProvider);
    try {
      final r = await confirmarGastoDeRecibo(
        servicio: servicio,
        comprobantes: ref.read(comprobanteLocalProvider),
        personaId: c.personaId,
        recibo: widget.recibo,
        libroId: libro.id,
        cuentaOrigenId: _cuentaId!,
        montoCentavos: monto,
        concepto: _concepto.text,
        fecha: _fecha ?? c.hoy,
        categoriaId: _categoriaId,
        motivo: libro.tipo == dom.TipoLibro.representado ? _motivo.text : null,
      );
      if (mounted) avisarGuardado(context, r, servicio);
      if (navegador.canPop()) navegador.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        avisarError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final asincrono = ref.watch(contextoFinanzasProvider);
    final c = asincrono.value;
    if (c == null) {
      return MarcoHojaRegistro(
        titulo: 'Gasto desde recibo',
        cuerpo: asincrono.hasError
            ? Text('No se pudo abrir Finanzas: ${asincrono.error}')
            : const Center(child: CircularProgressIndicator()),
      );
    }
    final libros = librosParaRegistrar(c);
    if (libros.isEmpty) {
      return const MarcoHojaRegistro(
        titulo: 'Gasto desde recibo',
        cuerpo: Text(
          'Solo lectura: no tienes un libro donde registrar gastos.',
        ),
      );
    }
    _iniciar(c);
    final libro = libros.firstWhere(
      (l) => l.id == _libroId,
      orElse: () => libros.first,
    );
    final sug = sugerenciasDeGasto(
      c.datos,
      libroId: libro.id,
      personaId: c.personaId,
      hoy: c.hoy,
    );
    _cuentaId ??= sug.ultimaCuentaId;
    if (_cuentaId != null && !sug.cuentas.any((x) => x.id == _cuentaId)) {
      _cuentaId = sug.ultimaCuentaId;
    }
    final representado = libro.tipo == dom.TipoLibro.representado;
    final monto = centavosDeTexto(_monto.text);
    final puedeGuardar =
        monto != null &&
        monto > 0 &&
        _cuentaId != null &&
        !_guardando &&
        (!representado || motivoValido(_motivo.text));
    final fecha = _fecha ?? c.hoy;
    return MarcoHojaRegistro(
      titulo: 'Gasto desde recibo',
      barra: BarraAccionesRegistro(
        llaveGuardar: const ValueKey('recibo-guardar'),
        textoGuardar: 'Confirmar y guardar',
        alGuardar: puedeGuardar ? () => _guardar(c, libro) : null,
      ),
      cuerpo: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _propuesta?.montoCentavos == null
                ? 'No se pudo leer el monto: escríbelo tú.'
                : 'Esto es lo que se leyó del recibo. Revísalo: no se guarda '
                      'nada hasta que confirmes.',
            key: const ValueKey('recibo-aviso'),
          ),
          const SizedBox(height: 8),
          if (libros.length > 1)
            Wrap(
              spacing: 8,
              children: [
                for (final l in libros)
                  ChoiceChip(
                    key: ValueKey('recibo-libro-${l.id}'),
                    label: Text(l.nombre),
                    selected: l.id == libro.id,
                    onSelected: (_) => setState(() {
                      _libroId = l.id;
                      _cuentaId = null;
                    }),
                  ),
              ],
            ),
          TextField(
            key: const ValueKey('recibo-monto'),
            controller: _monto,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Monto'),
          ),
          TextField(
            key: const ValueKey('recibo-concepto'),
            controller: _concepto,
            maxLength: 200,
            decoration: const InputDecoration(labelText: 'Concepto'),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: ActionChip(
              key: const ValueKey('recibo-fecha'),
              avatar: const Icon(Icons.event_outlined, size: 18),
              label: Text(fecha == c.hoy ? 'Hoy' : textoFecha(fecha)),
              onPressed: () async {
                final f = await elegirFecha(context, fecha);
                if (f != null) setState(() => _fecha = f);
              },
            ),
          ),
          const SizedBox(height: 8),
          const EtiquetaPanel('Categoría (opcional)'),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final cat in sug.categorias)
                ChoiceChip(
                  key: ValueKey('recibo-categoria-${cat.id}'),
                  label: Text(cat.nombre),
                  selected: _categoriaId == cat.id,
                  onSelected: (s) =>
                      setState(() => _categoriaId = s ? cat.id : null),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const EtiquetaPanel('Cuenta'),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final cuenta in sug.cuentas)
                ChoiceChip(
                  key: ValueKey('recibo-cuenta-${cuenta.id}'),
                  label: Text(cuenta.nombre),
                  selected: _cuentaId == cuenta.id,
                  onSelected: (_) => setState(() => _cuentaId = cuenta.id),
                ),
            ],
          ),
          if (representado)
            TextField(
              key: const ValueKey('recibo-motivo'),
              controller: _motivo,
              maxLength: 200,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Motivo (obligatorio)',
              ),
            ),
          const SizedBox(height: 8),
          const Text(
            'La foto queda como comprobante solo en este teléfono.',
            key: ValueKey('recibo-aviso-foto'),
          ),
        ],
      ),
    );
  }
}
