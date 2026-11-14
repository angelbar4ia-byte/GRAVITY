/// "Crear cuenta nueva" dentro de la hoja de registro (respuestas del dueño del
/// 23/oct/2026): un gasto sale de una **cuenta existente** del libro activo; si
/// no hay ninguna, la hoja ofrece crearla ahí mismo (nombre, tipo y saldo
/// inicial opcional) y sigue con el gasto sin salir.
library;

import 'package:finanzas_dominio/finanzas_dominio.dart'
    hide
        Semaforo,
        formatearCentavos,
        TipoLibro,
        VisibilidadLibro,
        puntosBaseEnCien;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../estado/proveedores.dart';
import '../comunes.dart';

/// Formulario corto para crear una cuenta del libro [libroId]. Al crearla
/// llama [alCrear] con su id (la hoja la deja elegida).
class NuevaCuentaEnHoja extends ConsumerStatefulWidget {
  const NuevaCuentaEnHoja({
    super.key,
    required this.libroId,
    required this.alCrear,
    this.tipos = const [
      TipoCuenta.efectivo,
      TipoCuenta.banco,
      TipoCuenta.tarjeta,
    ],
  });

  final String libroId;
  final ValueChanged<String> alCrear;

  /// Tipos que se ofrecen (un gasto: efectivo, banco o tarjeta; un ingreso:
  /// efectivo o banco).
  final List<TipoCuenta> tipos;

  @override
  ConsumerState<NuevaCuentaEnHoja> createState() => _NuevaCuentaEnHojaState();
}

class _NuevaCuentaEnHojaState extends ConsumerState<NuevaCuentaEnHoja> {
  final _nombre = TextEditingController();
  final _saldo = TextEditingController();
  late TipoCuenta _tipo = widget.tipos.first;
  bool _guardando = false;

  @override
  void dispose() {
    _nombre.dispose();
    _saldo.dispose();
    super.dispose();
  }

  static String _nombreCorto(TipoCuenta t) => switch (t) {
    TipoCuenta.efectivo => 'Efectivo',
    TipoCuenta.banco => 'Banco',
    TipoCuenta.tarjeta => 'Tarjeta',
    _ => nombreTipoCuenta(t),
  };

  bool get _saldoValido =>
      _saldo.text.trim().isEmpty || centavosDeTexto(_saldo.text) != null;

  bool get _puedeCrear =>
      _nombre.text.trim().isNotEmpty && _saldoValido && !_guardando;

  Future<void> _crear() async {
    setState(() => _guardando = true);
    String? id;
    final ok = await intentar(context, () async {
      final cuenta = await ref
          .read(servicioFinanzasProvider)
          .crearCuenta(
            libroId: widget.libroId,
            nombre: _nombre.text,
            tipo: _tipo,
            saldoInicial: centavosDeTexto(_saldo.text) ?? 0,
          );
      id = cuenta.id;
    });
    if (!mounted) return;
    if (ok && id != null) {
      widget.alCrear(id!);
    } else {
      setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('cuenta-nueva'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      TextField(
        key: const ValueKey('cuenta-nueva-nombre'),
        controller: _nombre,
        maxLength: 60,
        textCapitalization: TextCapitalization.sentences,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(
          labelText: 'Nombre de la cuenta',
          counterText: '',
        ),
      ),
      const SizedBox(height: 8),
      if (widget.tipos.length > 1)
        SegmentedButton<TipoCuenta>(
          key: const ValueKey('cuenta-nueva-tipo'),
          segments: [
            for (final t in widget.tipos)
              ButtonSegment(value: t, label: Text(_nombreCorto(t))),
          ],
          selected: {_tipo},
          onSelectionChanged: (s) => setState(() => _tipo = s.first),
        ),
      const SizedBox(height: 8),
      TextField(
        key: const ValueKey('cuenta-nueva-saldo'),
        controller: _saldo,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: _tipo == TipoCuenta.tarjeta
              ? 'Lo que debes hoy (opcional)'
              : 'Saldo inicial (opcional)',
          prefixText: r'$ ',
          errorText: _saldoValido ? null : 'Monto no válido',
        ),
      ),
      const SizedBox(height: 8),
      Align(
        alignment: AlignmentDirectional.centerEnd,
        child: FilledButton(
          key: const ValueKey('cuenta-nueva-crear'),
          onPressed: _puedeCrear ? _crear : null,
          child: const Text('Crear cuenta'),
        ),
      ),
    ],
  );
}
