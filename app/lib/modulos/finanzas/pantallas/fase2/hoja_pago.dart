/// Hoja corta de pago de una deuda (teléfono y laptop): monto sugerido
/// (para no generar intereses, mínimo o el abono planeado) o el que teclees,
/// cuenta de donde sale y Guardar. Al pagar, la ocurrencia queda cumplida y se
/// retiran sus avisos (regla 38).
library;

import 'package:finanzas_dominio/finanzas_dominio.dart'
    hide
        Semaforo,
        formatearCentavos,
        TipoLibro,
        VisibilidadLibro,
        puntosBaseEnCien,
        BolsaAhorro,
        NivelFondo,
        NivelAlerta;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../diseno/diseno.dart';
import '../../estado/proveedores.dart';
import '../../estado/proveedores_fase2.dart';
import '../comunes.dart';
import '../registro/marco_hoja.dart';
import 'ayuda_fase2.dart';

Future<void> mostrarHojaPago(BuildContext context, {required Deuda deuda}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => HojaPagarDeuda(deuda: deuda),
    );

class HojaPagarDeuda extends ConsumerStatefulWidget {
  const HojaPagarDeuda({super.key, required this.deuda});

  final Deuda deuda;

  @override
  ConsumerState<HojaPagarDeuda> createState() => _HojaPagoState();
}

class _HojaPagoState extends ConsumerState<HojaPagarDeuda> {
  int _monto = 0;
  int _clave = 0;
  String? _cuentaId;
  bool _guardando = false;

  @override
  Widget build(BuildContext context) {
    final contexto = ref.watch(contextoFinanzasProvider).value;
    if (contexto == null) {
      return const SizedBox(height: 120, child: EstadoCargando());
    }
    final c = contexto;
    final d = widget.deuda;
    final libro = d.libroId;
    final proximo = proximoPagoDe(c.datos, d, c.hoy);
    final estado = c.datos.ultimoEstadoDeCuenta(d.id);
    final sugeridos = <(String, int)>[
      if (estado != null && estado.pagoSinIntereses > 0)
        ('Para no generar intereses', estado.pagoSinIntereses),
      if (estado != null && estado.pagoMinimo > 0)
        ('Mínimo', estado.pagoMinimo)
      else if (d.minimo > 0)
        ('Mínimo', d.minimo),
      if (d.abono > 0) ('Abono planeado', d.abono),
    ];
    final cuentas = [
      for (final x in c.datos.cuentasDe(libro))
        if ((x.tipo == TipoCuenta.efectivo || x.tipo == TipoCuenta.banco) &&
            x.estado == EstadoCuenta.activa)
          x,
    ];
    final puede = _monto > 0 && _cuentaId != null && !_guardando;
    return MarcoHojaRegistro(
      titulo: 'Pagar ${d.titulo}',
      tituloDerecha: Text(
        formatearCentavos(_monto),
        key: const ValueKey('pago-monto'),
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      barra: BarraAccionesRegistro(
        llaveGuardar: const ValueKey('pago-guardar'),
        alGuardar: puede ? () => _guardar(proximo?.vencimiento) : null,
      ),
      cuerpo: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (sugeridos.isNotEmpty)
            Wrap(
              spacing: 8,
              children: [
                for (final (texto, valor) in sugeridos)
                  ActionChip(
                    key: ValueKey('pago-sug-$valor'),
                    label: Text('$texto ${formatearCentavos(valor)}'),
                    onPressed: () => setState(() {
                      _monto = valor;
                      _clave++;
                    }),
                  ),
              ],
            ),
          TecladoMonto(
            key: ValueKey('pago-teclado-$_clave'),
            centavosIniciales: _monto,
            alCambiar: (v) => setState(() => _monto = v),
            compacto: true,
          ),
          const SizedBox(height: 8),
          const EtiquetaPanel('Sale de'),
          if (cuentas.isEmpty)
            const Text('Este libro aún no tiene una cuenta de pago.')
          else
            Wrap(
              spacing: 8,
              children: [
                for (final x in cuentas)
                  ChoiceChip(
                    key: ValueKey('pago-cuenta-${x.id}'),
                    label: Text(x.nombre),
                    selected: _cuentaId == x.id,
                    onSelected: (_) => setState(() => _cuentaId = x.id),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _guardar(Vencimiento? v) async {
    setState(() => _guardando = true);
    final navegador = Navigator.of(context);
    try {
      await ref
          .read(servicioFase2Provider)
          .pagarDeuda(
            deudaId: widget.deuda.id,
            cuentaOrigenId: _cuentaId!,
            monto: _monto,
            vencimiento: v,
          );
      navegador.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        avisarError(context, e);
      }
    }
  }
}
