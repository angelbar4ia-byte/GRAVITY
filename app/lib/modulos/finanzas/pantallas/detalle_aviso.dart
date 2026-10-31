/// Detalle de un aviso dentro de la bandeja: lo que el aviso no dice afuera
/// (acreedor, monto, fecha) se ve aquí, dentro de la app y con el monto
/// ocultable. El aviso en sí solo trae el título del catálogo (D3).
library;

import 'package:finanzas_dominio/finanzas_dominio.dart' as dom;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../diseno/diseno.dart' show MontoOcultable, montosOcultosProvider;
import '../../../nucleo/avisos/aviso.dart';
import '../../../nucleo/contratos/rutas.dart';
import '../estado/proveedores.dart';

class DetalleAvisoFinanzas extends ConsumerWidget {
  const DetalleAvisoFinanzas({super.key, required this.aviso});

  final Aviso aviso;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datos = ref.watch(cargaFinanzasProvider).value?.datos;
    final ocultos = ref.watch(montosOcultosProvider);
    if (datos == null) return const _SinDetalle();
    final objeto = aviso.objetoId;
    String? titulo;
    int? monto;
    dom.Fecha? fecha;
    String ruta = '${Rutas.finanzas}/deudas';

    final oc = datos.ocurrencias.where((o) => o.id == objeto).firstOrNull;
    if (oc != null) {
      final d = datos.deudas.where((x) => x.id == oc.origenId).firstOrNull;
      titulo = d?.titulo;
      monto = oc.montoEsperado;
      fecha = oc.fechaAjustada;
    }
    if (titulo == null) {
      final e = datos.estadosDeCuenta.where((x) => x.id == objeto).firstOrNull;
      final d = e == null
          ? null
          : datos.deudas.where((x) => x.id == e.deudaId).firstOrNull;
      if (e != null) {
        titulo = d?.titulo;
        monto = e.pagoSinIntereses;
        fecha = e.fechaLimitePago;
      }
    }
    if (titulo == null) {
      final d = datos.deudas.where((x) => x.id == objeto).firstOrNull;
      if (d != null) {
        titulo = d.titulo;
        monto = d.minimo > 0 ? d.minimo : d.abono;
      }
    }
    if (titulo == null) {
      final b = datos.bolsas.where((x) => x.id == objeto).firstOrNull;
      if (b != null) {
        titulo = b.nombre;
        monto = datos.vista(b.libroId).saldo(b.cuentaId);
        ruta = '${Rutas.finanzas}/ahorro';
      }
    }
    if (titulo == null) return const _SinDetalle();
    return Column(
      key: const ValueKey('detalle-aviso-finanzas'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: Theme.of(context).textTheme.titleSmall),
        if (monto != null)
          Row(
            children: [
              const Text('Monto: '),
              MontoOcultable(centavos: monto, oculto: ocultos),
            ],
          ),
        if (fecha != null) Text('Fecha: $fecha'),
        TextButton(
          key: const ValueKey('detalle-aviso-abrir'),
          onPressed: () => context.go(ruta),
          child: const Text('Abrir en Finanzas'),
        ),
      ],
    );
  }
}

class _SinDetalle extends StatelessWidget {
  const _SinDetalle();

  @override
  Widget build(BuildContext context) => const Align(
    alignment: Alignment.centerLeft,
    child: Text('Abre Finanzas para ver el detalle.'),
  );
}
