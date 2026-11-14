/// Simulador de estrategias de pago e intereses (Fase 8, bloque 2). Compara
/// bola de nieve, avalancha y por fecha de vencimiento; recomienda la de
/// menores intereses, pero **el pago lo confirma la persona**. Si falta un
/// dato, la estrategia dice "Falta un dato para esta estrategia" y no estima.
library;

import 'package:finanzas_dominio/finanzas_dominio.dart'
    show
        DeudaSimulable,
        EstadoEstrategia,
        EstrategiaPago,
        ResultadoEstrategia,
        ResultadoSoloMinimos,
        interesesConPagoMinimo,
        recomendar,
        simularTodas,
        sumaDeMinimos;
import 'package:flutter/material.dart';

import '../../../../diseno/diseno.dart';
import '../../casos_uso/simulador_deudas.dart';
import '../../estado/proveedores.dart' show ContextoFinanzas;
import '../comunes.dart';

class VistaSimulador extends StatefulWidget {
  const VistaSimulador({super.key, required this.contexto});

  final ContextoFinanzas contexto;

  @override
  State<VistaSimulador> createState() => _SimuladorState();
}

class _SimuladorState extends State<VistaSimulador> {
  final _extra = TextEditingController();

  /// Monto pedido por la persona (centavos); `null` = el por omisión, que es
  /// la suma de los pagos mínimos.
  int? _pedidoCentavos;

  @override
  void dispose() {
    _extra.dispose();
    super.dispose();
  }

  void _cambiarExtra(String texto) {
    final limpio = texto.replaceAll(RegExp(r'[^0-9.]'), '');
    final v = double.tryParse(limpio);
    setState(() => _pedidoCentavos = v == null ? null : (v * 100).round());
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.contexto;
    final deudas = deudasSimulables(c.datos, c.libroId, c.hoy);
    final hueco = SizedBox(height: ValoresDiseno.de(context).espacio * 2);
    if (deudas.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          EstadoVacio(mensaje: 'Sin deudas con saldo para simular.'),
        ],
      );
    }
    final porOmision = sumaDeMinimos(deudas);
    final noAlcanza =
        _pedidoCentavos != null &&
        porOmision != null &&
        _pedidoCentavos! < porOmision;
    // Lo que se simula (y se enviaría a fin_simular_estrategias): el monto
    // pedido o nulo para el por omisión.
    final resultados = simularTodas(
      deudas,
      presupuestoMensual: _pedidoCentavos,
    );
    final minimos = interesesConPagoMinimo(deudas);
    final mejor = recomendar(resultados);
    return ListView(
      key: const ValueKey('simulador-lista'),
      padding: const EdgeInsets.all(16),
      children: [
        TarjetaModulo(
          key: const ValueKey('simulador-extra'),
          titulo: 'Presupuesto mensual para deudas',
          icono: Icons.tune,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (porOmision != null)
                DatoConMonto('Por omisión (suma de pagos mínimos)', porOmision),
              TextField(
                key: const ValueKey('simulador-extra-campo'),
                controller: _extra,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Otro monto mensual (opcional)',
                  prefixText: '\$ ',
                  helperText:
                      'Vacío usa la suma de tus pagos mínimos. Es una '
                      'simulación: la app no paga por ti.',
                ),
                onChanged: _cambiarExtra,
              ),
              if (noAlcanza)
                Text(
                  'No alcanza: ese monto es menor que la suma de tus pagos '
                  'mínimos.',
                  key: const ValueKey('simulador-no-alcanza'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
        hueco,
        TarjetaModulo(
          key: const ValueKey('simulador-minimos'),
          titulo: 'Intereses con solo el pago mínimo',
          icono: Icons.hourglass_bottom_outlined,
          child: _FilaMinimos(minimos),
        ),
        hueco,
        if (mejor != null)
          TarjetaModulo(
            key: const ValueKey('simulador-recomendacion'),
            titulo: 'La de menores intereses',
            icono: Icons.recommend_outlined,
            child: Text(
              '${mejor.estrategia.nombre} es la que menos intereses cuesta. '
              'Es una sugerencia: tú decides y tú confirmas cada pago.',
            ),
          ),
        if (mejor != null) hueco,
        for (final r in resultados) ...[
          _TarjetaEstrategia(
            resultado: r,
            recomendada: mejor?.estrategia == r.estrategia,
            interesesMinimos: minimos.calculado
                ? minimos.interesesTotales
                : null,
            deudas: deudas,
          ),
          hueco,
        ],
      ],
    );
  }
}

String _meses(int m) {
  final a = m ~/ 12;
  final r = m % 12;
  if (a == 0) return '$m ${m == 1 ? 'mes' : 'meses'}';
  return r == 0 ? '$a ${a == 1 ? 'año' : 'años'}' : '$a a. $r m.';
}

class _FilaMinimos extends StatelessWidget {
  const _FilaMinimos(this.m);

  final ResultadoSoloMinimos m;

  @override
  Widget build(BuildContext context) {
    if (!m.calculado) {
      return Text(
        'Falta un dato para estimarlo (${m.faltantes.join(', ')}).',
        key: const ValueKey('simulador-minimos-falta'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DatoConMonto('Intereses', m.interesesTotales),
        Text(
          m.liquidada
              ? 'Terminarías en ${_meses(m.meses)}.'
              : 'Con solo el mínimo no terminas de pagar en ${_meses(m.meses)}.',
        ),
      ],
    );
  }
}

class _TarjetaEstrategia extends StatelessWidget {
  const _TarjetaEstrategia({
    required this.resultado,
    required this.recomendada,
    required this.interesesMinimos,
    required this.deudas,
  });

  final ResultadoEstrategia resultado;
  final bool recomendada;
  final int? interesesMinimos;
  final List<DeudaSimulable> deudas;

  @override
  Widget build(BuildContext context) {
    final r = resultado;
    final clave = r.estrategia.clave;
    return TarjetaModulo(
      key: ValueKey('estrategia-$clave'),
      titulo: recomendada
          ? '${r.estrategia.nombre} · recomendada'
          : r.estrategia.nombre,
      icono: switch (r.estrategia) {
        EstrategiaPago.bolaDeNieve => Icons.circle_outlined,
        EstrategiaPago.avalancha => Icons.trending_down,
        EstrategiaPago.porVencimiento => Icons.event_outlined,
      },
      child: r.estado == EstadoEstrategia.noAlcanza
          ? Text(
              'No alcanza para cubrir los pagos mínimos',
              key: ValueKey('estrategia-$clave-no-alcanza'),
            )
          : !r.calculada
          ? Text(
              'Falta un dato para esta estrategia',
              key: ValueKey('estrategia-$clave-falta'),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DatoConMonto('Total pagado', r.totalPagado),
                DatoConMonto('Intereses totales', r.interesesTotales),
                if (interesesMinimos != null &&
                    r.liquidada &&
                    interesesMinimos! > r.interesesTotales)
                  DatoConMonto(
                    'Menos intereses que con el mínimo',
                    interesesMinimos! - r.interesesTotales,
                  ),
                Text(
                  r.liquidada
                      ? 'Libre de deuda en ${_meses(r.meses)}.'
                      : 'No termina de pagarse en ${_meses(r.meses)}: sube el '
                            'pago.',
                ),
                const SizedBox(height: 8),
                Text(
                  'Orden de pago',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                for (var i = 0; i < r.orden.length; i++)
                  Text(
                    '${i + 1}. ${r.orden[i].nombre}'
                    '${r.orden[i].mesDeLiquidacion == null ? '' : ' (mes ${r.orden[i].mesDeLiquidacion})'}',
                  ),
              ],
            ),
    );
  }
}
