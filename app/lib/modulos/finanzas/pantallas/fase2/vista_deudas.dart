/// Deudas a detalle (Fase 2, 5.1): cuánto cuesta deber, el orden de pago por
/// costo con su motivo, y cada deuda con su saldo, su tasa, su próximo pago y
/// el uso del límite. En la laptop se capturan estados de cuenta, tasas y
/// compras a meses; en el teléfono, tocar una deuda abre la hoja corta de pago.
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
import '../../casos_uso/servicio_fase2.dart';
import '../../estado/proveedores.dart';
import '../../estado/proveedores_fase2.dart';
import '../comunes.dart';
import 'ayuda_fase2.dart';
import 'dialogos_fase2.dart';
import 'hoja_pago.dart';

class VistaDeudas extends ConsumerWidget {
  const VistaDeudas({super.key, required this.contexto, this.telefono = false});

  final ContextoFinanzas contexto;
  final bool telefono;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = contexto;
    final svc = ref.watch(servicioFase2Provider);
    final resumenes = svc.deudas(c.libroId);
    final orden = svc.ordenDePago(c.libroId);
    final costo = svc.costoDeDeberDe(c.libroId);
    final ocultos = ref.watch(montosOcultosProvider);
    final hueco = SizedBox(height: ValoresDiseno.de(context).espacio * 2);

    if (resumenes.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          EstadoVacio(
            mensaje: 'Sin deudas registradas.',
            detalle: c.puedeAdministrar
                ? 'Agrega tus deudas en Compromisos y deudas, o una compra a '
                      'meses aquí.'
                : null,
            textoAccion: c.puedeAdministrar && !telefono
                ? 'Importar mi ficha'
                : null,
            alAccionar: c.puedeAdministrar && !telefono
                ? () => showDialog<void>(
                    context: context,
                    builder: (_) => DialogoImportarFicha(contexto: c),
                  )
                : null,
          ),
        ],
      );
    }

    return ListView(
      key: const ValueKey('deudas-lista'),
      padding: const EdgeInsets.all(16),
      children: [
        if (c.puedeAdministrar && !telefono)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('deudas-importar-ficha'),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => DialogoImportarFicha(contexto: c),
                  ),
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text('Importar ficha'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('deudas-nuevo-msi'),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => DialogoMsi(contexto: c),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Compra a meses'),
                ),
              ],
            ),
          ),
        TarjetaModulo(
          key: const ValueKey('deudas-costo'),
          titulo: 'Cuánto cuesta deber',
          icono: Icons.hourglass_bottom_outlined,
          child: costo.semanal == 0
              ? const Text(
                  'Sin intereses calculados: captura la tasa de tus deudas '
                  'con costo.',
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DatoConMonto('Por semana (estimado)', costo.semanal),
                    DatoConMonto(
                      'Por mes (referencia)',
                      costo.mensualDeReferencia.values.fold(0, (a, b) => a + b),
                    ),
                  ],
                ),
        ),
        hueco,
        if (resumenes.any((r) => (r.saldo ?? 0) > 0)) ...[
          _TarjetaAbonoExtra(contexto: c),
          hueco,
        ],
        if (orden.isNotEmpty)
          TarjetaModulo(
            key: const ValueKey('deudas-orden'),
            titulo: 'En qué orden pagar',
            icono: Icons.format_list_numbered,
            child: OrdenPago(
              lugares: [
                for (final l in orden)
                  LugarOrdenPago(
                    acreedor: l.deuda.nombre,
                    motivo: l.motivo,
                    fijo: l.deuda.tipo != TipoDeuda.conCosto,
                  ),
              ],
            ),
          ),
        if (orden.isNotEmpty) hueco,
        for (final r in resumenes) ...[
          _TarjetaDeDeuda(
            resumen: r,
            contexto: c,
            ocultos: ocultos,
            telefono: telefono,
            interesMensual: costo.mensualDeReferencia[r.deuda.id],
          ),
          hueco,
        ],
      ],
    );
  }
}

class _TarjetaDeDeuda extends ConsumerWidget {
  const _TarjetaDeDeuda({
    required this.resumen,
    required this.contexto,
    required this.ocultos,
    required this.telefono,
    this.interesMensual,
  });

  final ResumenDeuda resumen;
  final ContextoFinanzas contexto;
  final bool ocultos;
  final bool telefono;
  final int? interesMensual;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = resumen.deuda;
    final c = contexto;
    final saldo = resumen.saldo ?? 0;
    final proximo = proximoPagoDe(c.datos, d, c.hoy);
    final sinTasa = d.tipo == TipoDeuda.conCosto && d.tasaAnualPuntosBase == 0;
    final original = d.montoOriginal;
    final avance = original == null || original <= 0
        ? null
        : ((original - saldo) / original).clamp(0.0, 1.0);
    final puedeRegistrar = c.puedeEscribir && saldo > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TarjetaDeuda(
          key: ValueKey('deuda-${d.id}'),
          acreedor: d.titulo,
          clase: nombreClaseDeuda(d.clase),
          saldoCentavos: saldo,
          tasaAnualPuntosBase: sinTasa ? null : d.tasaAnualPuntosBase,
          interesMensualCentavos: interesMensual,
          proximoPagoTexto: proximo == null
              ? null
              : 'Vence ${textoDiaMes(proximo.fecha)}',
          proximoPagoCentavos: proximo?.monto,
          avance: avance,
          liquidada: resumen.saldo != null && saldo <= 0,
          alTocar: telefono && puedeRegistrar
              ? () => mostrarHojaPago(context, deuda: d)
              : null,
          alCapturarTasa: sinTasa && c.puedeAdministrar
              ? () => showDialog<void>(
                  context: context,
                  builder: (_) => DialogoTasa(deuda: d),
                )
              : null,
        ),
        if (resumen.uso != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: BarraLimite(
              key: ValueKey('limite-${d.id}'),
              usadoCentavos: resumen.uso!.usado,
              limiteCentavos: resumen.uso!.limite,
              etiqueta: 'Uso del límite',
            ),
          ),
        if (!telefono && (puedeRegistrar || c.puedeAdministrar))
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 8,
              children: [
                if (puedeRegistrar)
                  TextButton(
                    key: ValueKey('pagar-${d.id}'),
                    onPressed: () => mostrarHojaPago(context, deuda: d),
                    child: const Text('Registrar pago'),
                  ),
                if (c.puedeEscribir &&
                    (d.clase == ClaseDeuda.tarjeta ||
                        d.clase == ClaseDeuda.credito))
                  TextButton(
                    key: ValueKey('estado-${d.id}'),
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => DialogoEstadoDeCuenta(deuda: d),
                    ),
                    child: const Text('Estado de cuenta'),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// "¿Y si abono \$X extra por semana?": ilustrativo (regla 13).
class _TarjetaAbonoExtra extends ConsumerStatefulWidget {
  const _TarjetaAbonoExtra({required this.contexto});

  final ContextoFinanzas contexto;

  @override
  ConsumerState<_TarjetaAbonoExtra> createState() => _AbonoExtraState();
}

class _AbonoExtraState extends ConsumerState<_TarjetaAbonoExtra> {
  final _monto = TextEditingController();

  @override
  void dispose() {
    _monto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.contexto;
    final extra = centavosDeTexto(_monto.text);
    final comparacion = extra == null || extra <= 0
        ? null
        : ref
              .read(servicioFase2Provider)
              .abonoExtra(c.libroId, Semana.de(c.hoy), extra);
    return TarjetaModulo(
      key: const ValueKey('deudas-abono-extra'),
      titulo: '¿Y si abono más cada semana?',
      icono: Icons.trending_down,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const ValueKey('abono-extra-monto'),
            controller: _monto,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Extra por semana',
              prefixText: r'$ ',
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (comparacion != null) ...[
            const SizedBox(height: 8),
            Text(
              comparacion.semanasAdelantadas == null
                  ? 'Con ese extra la salida de deuda cambia, pero queda '
                        'fuera de la proyección.'
                  : 'Saldrías de deuda ${comparacion.semanasAdelantadas} '
                        'semanas antes.',
              key: const ValueKey('abono-extra-semanas'),
            ),
            DatoConMonto(
              'Intereses estimados que ahorras',
              comparacion.interesesAhorrados,
            ),
            Text(
              'Ilustrativo: no es una promesa ni el simulador de estrategias.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
