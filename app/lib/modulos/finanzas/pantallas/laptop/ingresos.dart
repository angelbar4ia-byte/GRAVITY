/// Ingresos (laptop; especificación 6.1): por persona con su equivalente
/// semanal, vigencias, próximas fechas (ya ajustadas al día hábil) y los
/// extras de la semana.
library;

import 'package:finanzas_dominio/finanzas_dominio.dart'
    hide Semaforo, formatearCentavos, TipoLibro, puntosBaseEnCien;
import 'package:finanzas_dominio/finanzas_dominio.dart' as dom show TipoLibro;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../diseno/diseno.dart';
import '../../estado/proveedores.dart';
import '../comunes.dart';
import 'dialogos_config.dart';
import 'marco_laptop.dart';

class PantallaIngresos extends StatelessWidget {
  const PantallaIngresos({super.key});

  @override
  Widget build(BuildContext context) => MarcoFinanzasLaptop(
    seccion: SeccionFinanzas.ingresos,
    acciones: (context, c) => [
      if (c.puedeAdministrar) ...[
        // En el libro de papá: pensión (días 1 y 11) y apoyo 60+ (bimestral).
        if (c.libro!.tipo == dom.TipoLibro.representado)
          for (final p in PlantillaIngreso.deRepresentado)
            OutlinedButton(
              key: ValueKey('ingresos-plantilla-${p.nombre}'),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => DialogoIngreso(contexto: c, plantilla: p),
              ),
              child: Text(p.nombre),
            ),
        FilledButton.icon(
          key: const ValueKey('ingresos-nuevo'),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => DialogoIngreso(contexto: c),
          ),
          icon: const Icon(Icons.add),
          label: const Text('Nuevo ingreso'),
        ),
      ],
    ],
    builder: (context, c) => _Ingresos(contexto: c),
  );
}

class _Ingresos extends ConsumerWidget {
  const _Ingresos({required this.contexto});

  final ContextoFinanzas contexto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = contexto;
    final semana = Semana.de(c.hoy);
    final ingresos = c.datos.ingresosDe(c.libroId);
    final plan = armarPlanDelLibro(c.datos, c.libroId, semana).plan;
    final extras = extrasDeLaSemana(c.datos, c.libroId, semana);
    return ContenidoLaptop(
      children: [
        TarjetaModulo(
          key: const ValueKey('ingresos-resumen'),
          titulo: 'Ingreso de la semana (equivalente semanal)',
          icono: Icons.savings_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [const Expanded(child: Text('Cuenta en el plan')), Monto(plan.ingreso)]),
              if (plan.ingresoPotencial > 0)
                Row(
                  children: [
                    const Expanded(child: Text('Potencial (inciertos, no cuentan)')),
                    Monto(plan.ingresoPotencial),
                  ],
                ),
              Row(children: [const Expanded(child: Text('Extras de esta semana')), Monto(extras)]),
              const SizedBox(height: 8),
              const Text(
                'Un mes con tres catorcenas o cinco semanas no es un extra: ya '
                'está en el equivalente semanal. Los extras se registran con su '
                'fecha real.',
                key: ValueKey('ingresos-nota-in9'),
              ),
            ],
          ),
        ),
        if (ingresos.isEmpty)
          const EstadoVacio(
            icono: Icons.savings_outlined,
            mensaje: 'Este libro aún no tiene ingresos.',
            detalle: 'Agrégalos con "Nuevo ingreso" o con el asistente de arranque.',
          ),
        for (final i in ingresos) _FichaIngreso(ingreso: i, contexto: c),
      ],
    );
  }
}

class _FichaIngreso extends StatelessWidget {
  const _FichaIngreso({required this.ingreso, required this.contexto});

  final Ingreso ingreso;
  final ContextoFinanzas contexto;

  @override
  Widget build(BuildContext context) {
    final c = contexto;
    final i = ingreso;
    final actual = i.vigenciaActual;
    final semanal = i.planEn(Semana.de(c.hoy))?.equivalente.semanal ?? 0;
    final proximos = i
        .pagosEntre(c.hoy, c.hoy.sumarDias(70), c.datos.calendario)
        .take(4)
        .toList();
    return TarjetaModulo(
      key: ValueKey('ingreso-${i.id}'),
      titulo: '${i.nombre} · ${c.carga.nombreDe(i.personaId)}',
      icono: Icons.payments_outlined,
      accion: c.puedeAdministrar
          ? TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => DialogoCambiarNeto(ingreso: i, hoy: c.hoy),
              ),
              child: const Text('Cambiar neto'),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (actual != null) ...[
            Text(descripcionCalendario(actual.calendario)),
            DatoConMonto('Neto por pago', actual.montoNeto),
          ],
          DatoConMonto('Equivalente semanal', semanal),
          Text('Certeza: ${nombreCerteza(i.certeza)}${i.activo ? '' : ' · inactivo'}'),
          if (proximos.isNotEmpty)
            Text(
              'Próximas fechas: ${proximos.map((p) => p.$1.seMovio ? '${textoFecha(p.$1.ajustada)} (era ${textoDiaMes(p.$1.programada)})' : textoFecha(p.$1.ajustada)).join(' · ')}',
            ),
          if (i.vigencias.length > 1) ...[
            const SizedBox(height: 4),
            const EtiquetaPanel('Vigencias'),
            for (final v in i.vigencias)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${textoFecha(v.desde)} – ${v.hasta == null ? 'hoy' : textoFecha(v.hasta!)}',
                    ),
                  ),
                  Monto(v.montoNeto),
                ],
              ),
          ],
        ],
      ),
    );
  }
}
