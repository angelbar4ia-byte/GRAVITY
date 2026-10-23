/// Tablero de Finanzas (laptop; especificación 6.1 y 5.9 bis, punto 2):
/// cascada planeado contra real, medidor por partida, lo que vence esta
/// semana, alerta de flujo, cuatro indicadores del MVP 1 y la siguiente mejor
/// acción.
library;

import 'package:finanzas_dominio/finanzas_dominio.dart'
    hide Semaforo, formatearCentavos, TipoLibro, puntosBaseEnCien;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../diseno/diseno.dart';
import '../../estado/proveedores.dart';
import '../comunes.dart';
import 'dialogo_movimiento.dart';
import 'marco_laptop.dart';

/// Acción principal de la laptop: Registrar movimiento (Ctrl + N).
List<Widget> accionRegistrar(BuildContext context, ContextoFinanzas c) => [
  if (c.puedeEscribir)
    FilledButton.icon(
      key: const ValueKey('finanzas-registrar-movimiento'),
      onPressed: () => mostrarDialogoMovimiento(context, c),
      icon: const Icon(Icons.add),
      label: const Text('Registrar movimiento'),
    ),
];

class PantallaTablero extends StatelessWidget {
  const PantallaTablero({super.key});

  @override
  Widget build(BuildContext context) => MarcoFinanzasLaptop(
    seccion: SeccionFinanzas.tablero,
    acciones: accionRegistrar,
    builder: (context, c) => _Tablero(contexto: c),
  );
}

class _Tablero extends ConsumerWidget {
  const _Tablero({required this.contexto});

  final ContextoFinanzas contexto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = contexto;
    final semana = Semana.de(c.hoy);
    final v = vistaSemana(c.datos, c.libroId, semana, hoy: c.hoy);
    final ocultos = ref.watch(montosOcultosProvider);
    final ind = v.indicadores;
    final accion = v.siguienteAccion;
    final riesgo = v.flujo.primerDiaEnRiesgo;
    final variables = [
      for (final p in v.real.partidas)
        if (p.partida.tipo == TipoPartida.variable) p,
    ];
    final tendencia = switch (ind.tendenciaPatrimonio) {
      Tendencia.sube => 'Sube contra el último cierre',
      Tendencia.baja => 'Baja contra el último cierre',
      Tendencia.igual => 'Igual que el último cierre',
      null => 'Aún sin cierre para comparar',
    };
    return ContenidoLaptop(
      children: [
        TarjetaModulo(
          key: const ValueKey('tablero-siguiente-accion'),
          titulo: 'Siguiente mejor acción',
          icono: Icons.lightbulb_outline,
          child: Text(textoConMonto(accion, ocultos)),
        ),
        Rejilla(
          anchoMinimo: 220,
          children: [
            TarjetaIndicador(
              key: const ValueKey('indicador-remanente'),
              etiqueta: 'Remanente',
              valor: formatearPuntosBase(ind.remanentePuntosBase),
              estado: estadoDe(ind.remanente),
              detalle: 'Remanente ÷ ingreso de la semana',
            ),
            TarjetaIndicador(
              key: const ValueKey('indicador-carga'),
              etiqueta: 'Carga de deuda',
              valor: formatearPuntosBase(ind.cargaDeudaPuntosBase),
              estado: estadoDe(ind.cargaDeuda),
              detalle: 'Pagos de deuda ÷ ingreso',
            ),
            TarjetaIndicador(
              key: const ValueKey('indicador-cumplimiento'),
              etiqueta: 'Cumplimiento',
              valor: '${ind.partidasDentro} de ${ind.totalPartidas}',
              estado: estadoDe(ind.cumplimiento),
              detalle: 'Partidas dentro de lo asignado',
            ),
            TarjetaIndicador(
              key: const ValueKey('indicador-patrimonio'),
              etiqueta: 'Patrimonio',
              valor: formatearCentavos(ind.patrimonio),
              oculto: ocultos,
              esMonto: true, // cifra de dinero: se oculta sola; los % no
              detalle: tendencia,
            ),
          ],
        ),
        Rejilla(
          anchoMinimo: 420,
          children: [
            TarjetaModulo(
              key: const ValueKey('tablero-cascada'),
              titulo: '${textoSemana(semana)} · ${nombreEstadoSemana(v.estado)}',
              icono: Icons.waterfall_chart,
              accion: TextButton(
                onPressed: () => context.go(SeccionFinanzas.semana.ruta),
                child: const Text('Abrir semana'),
              ),
              child: GadgetCascada(escalones: escalonesDe(v), montosOcultos: ocultos),
            ),
            TarjetaModulo(
              titulo: 'Partidas',
              icono: Icons.donut_large_outlined,
              child: variables.isEmpty
                  ? const Text('Sin sobres semanales en este libro.')
                  : Column(
                      children: [
                        for (final p in variables)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: MedidorPresupuesto(
                              etiqueta: v.infoPartida(p.partida.id).nombre,
                              asignadoCentavos: p.disponible,
                              gastadoCentavos: p.gastado,
                              montosOcultos: ocultos,
                              ambarDesdePuntosBase:
                                  v.planSemanal.parametros.umbrales.partidaAmbarDesde,
                              rojoArribaDePuntosBase:
                                  v.planSemanal.parametros.umbrales.partidaRojoArribaDe,
                            ),
                          ),
                      ],
                    ),
            ),
            TarjetaModulo(
              key: const ValueKey('tablero-vence'),
              titulo: 'Esta semana vence',
              icono: Icons.event_note_outlined,
              child: v.vencimientos.isEmpty
                  ? const Text('Nada vence esta semana.')
                  : Column(
                      children: [
                        for (final x in v.vencimientos)
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              x.esEntrada ? Icons.south_west : Icons.north_east,
                            ),
                            title: Text(x.concepto),
                            subtitle: Text(
                              x.fecha.seMovio
                                  ? '${textoFecha(x.fecha.ajustada)} (era ${textoFecha(x.fecha.programada)})'
                                  : textoFecha(x.fecha.ajustada),
                            ),
                            trailing: Monto(x.esEntrada ? x.monto : -x.monto, signo: true),
                          ),
                      ],
                    ),
            ),
            TarjetaModulo(
              key: const ValueKey('tablero-flujo'),
              titulo: riesgo == null ? 'Flujo' : 'Alerta de flujo',
              icono: riesgo == null ? Icons.timeline : Icons.warning_amber_rounded,
              child: riesgo == null
                  ? const Text(
                      'En las próximas semanas el saldo no baja de cero en el '
                      'peor caso.',
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: Text(
                            'El ${textoFecha(riesgo.fecha)} el saldo puede bajar a '
                            '(peor caso: primero las salidas)',
                          ),
                        ),
                        Monto(riesgo.saldoPeorCaso),
                      ],
                    ),
            ),
          ],
        ),
      ],
    );
  }
}
