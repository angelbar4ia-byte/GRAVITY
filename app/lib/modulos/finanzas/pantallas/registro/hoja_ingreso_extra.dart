/// (+) Ingreso extra en el teléfono: monto → cuenta → fecha (hoy) → Guardar
/// (5.1 bis, punto 4: los extras cuentan en la semana en que llegan).
library;

import 'package:finanzas_dominio/finanzas_dominio.dart'
    hide Semaforo, formatearCentavos, TipoLibro, puntosBaseEnCien;
import 'package:finanzas_dominio/finanzas_dominio.dart' as dom show TipoLibro;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../diseno/diseno.dart';
import '../../../../nucleo/contratos/roles.dart';
import '../../casos_uso/sugerencias.dart';
import '../../estado/proveedores.dart';
import '../comunes.dart';
import 'hoja_gasto.dart';

class HojaIngresoExtra extends ConsumerStatefulWidget {
  const HojaIngresoExtra({super.key});

  @override
  ConsumerState<HojaIngresoExtra> createState() => _HojaIngresoExtraState();
}

class _HojaIngresoExtraState extends ConsumerState<HojaIngresoExtra> {
  int _monto = 0;
  String? _libroId;
  String? _cuentaId;
  Fecha? _fecha;
  final _nota = TextEditingController();
  final _motivo = TextEditingController();
  bool _guardando = false;

  @override
  void dispose() {
    _nota.dispose();
    _motivo.dispose();
    super.dispose();
  }

  Future<void> _guardar(Libro libro) async {
    setState(() => _guardando = true);
    final navegador = Navigator.of(context);
    final servicio = ref.read(servicioFinanzasProvider);
    try {
      final r = await servicio.registrarIngresoExtra(
        libroId: libro.id,
        monto: _monto,
        cuentaDestinoId: _cuentaId!,
        fecha: _fecha,
        nota: _nota.text,
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
    final c = ref.watch(contextoFinanzasProvider).value;
    final v = ValoresDiseno.de(context);
    Widget cuerpo;
    if (c == null) {
      cuerpo = const Center(child: CircularProgressIndicator());
    } else if (librosParaRegistrar(c).isEmpty) {
      cuerpo = const Text('Solo lectura: no tienes un libro donde registrar.');
    } else {
      final libros = librosParaRegistrar(c);
      final libro = libros.firstWhere(
        (l) => l.id == _libroId,
        orElse: () => libros.first,
      );
      final cuentas = cuentasParaRecibir(c.datos, libro.id);
      if (!cuentas.any((x) => x.id == _cuentaId)) {
        _cuentaId = cuentas.firstOrNull?.id;
      }
      final representado = libro.tipo == dom.TipoLibro.representado;
      final fecha = _fecha ?? c.hoy;
      cuerpo = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (libros.length > 1)
            Wrap(
              spacing: 8,
              children: [
                for (final l in libros)
                  ChoiceChip(
                    key: ValueKey('extra-libro-${l.id}'),
                    label: Text(opcionDe(l, c.permisoEn(l), c.personaId).etiqueta),
                    selected: l.id == libro.id,
                    onSelected: (_) => setState(() => _libroId = l.id),
                  ),
              ],
            ),
          Text(
            formatearCentavos(_monto),
            key: const ValueKey('extra-monto'),
            textAlign: TextAlign.center,
            style: v.numero(tamano: 36, peso: FontWeight.w600, color: v.textoFuerte),
          ),
          TecladoMonto(
            alCambiar: (centavos) => setState(() => _monto = centavos),
            autofocus: true,
          ),
          const SizedBox(height: 12),
          const EtiquetaPanel('Entró a'),
          Wrap(
            spacing: 8,
            children: [
              for (final cuenta in cuentas)
                ChoiceChip(
                  key: ValueKey('extra-cuenta-${cuenta.id}'),
                  label: Text(cuenta.nombre),
                  selected: _cuentaId == cuenta.id,
                  onSelected: (_) => setState(() => _cuentaId = cuenta.id),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: ActionChip(
              key: const ValueKey('extra-fecha'),
              avatar: const Icon(Icons.event_outlined, size: 18),
              label: Text(fecha == c.hoy ? 'Hoy' : textoFecha(fecha)),
              onPressed: () async {
                final f = await elegirFecha(context, fecha);
                if (f != null) setState(() => _fecha = f);
              },
            ),
          ),
          TextField(
            controller: _nota,
            maxLength: 200,
            decoration: const InputDecoration(labelText: 'De qué es (opcional)'),
          ),
          if (representado)
            TextField(
              key: const ValueKey('extra-motivo'),
              controller: _motivo,
              maxLength: 200,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Motivo (obligatorio)',
                helperText: 'Se registra en nombre de ${libro.nombre}.',
              ),
            ),
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Cancelar'),
              ),
              const Spacer(),
              FilledButton.icon(
                key: const ValueKey('extra-guardar'),
                onPressed:
                    _monto > 0 &&
                        _cuentaId != null &&
                        !_guardando &&
                        (!representado || _motivo.text.trim().isNotEmpty)
                    ? () => _guardar(libro)
                    : null,
                icon: const Icon(Icons.check),
                label: const Text('Guardar'),
              ),
            ],
          ),
        ],
      );
    }
    return TemaModulo(
      modulo: Modulo.finanzas,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Ingreso extra', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              cuerpo,
            ],
          ),
        ),
      ),
    );
  }
}
