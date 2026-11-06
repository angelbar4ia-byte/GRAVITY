/// Semana (laptop; especificación 6.1): selector de semana y de periodo,
/// cascada, partidas con asignado, arrastre, gastado, restante y semáforo,
/// abonos, flujo de las próximas semanas y la revisión semanal (F5).
library;

import 'package:finanzas_dominio/finanzas_dominio.dart'
    hide Semaforo, formatearCentavos, TipoLibro, puntosBaseEnCien;
import 'package:finanzas_dominio/finanzas_dominio.dart' as dom show Semaforo;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../diseno/diseno.dart';
import '../../estado/proveedores.dart';
import '../comunes.dart';
import 'marco_laptop.dart';
import 'revision_semanal.dart';

class PantallaSemana extends StatelessWidget {
  const PantallaSemana({super.key});

  @override
  Widget build(BuildContext context) => MarcoFinanzasLaptop(
    seccion: SeccionFinanzas.semana,
    acciones: (context, c) => [_AccionesSemana(contexto: c)],
    builder: (context, c) => _Semana(contexto: c),
  );
}

Semana semanaVista(WidgetRef ref, ContextoFinanzas c) =>
    ref.watch(semanaElegidaProvider) ?? Semana.de(c.hoy);

class _AccionesSemana extends ConsumerWidget {
  const _AccionesSemana({required this.contexto});

  final ContextoFinanzas contexto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = contexto;
    if (!c.puedeEscribir) return const SizedBox.shrink();
    final semana = semanaVista(ref, c);
    final v = vistaSemana(c.datos, c.libroId, semana, hoy: c.hoy);
    final servicio = ref.read(servicioFinanzasProvider);
    return switch (v.estado) {
      EstadoSemana.borrador => FilledButton.icon(
        key: const ValueKey('semana-activar'),
        onPressed: v.planSemanal.ingreso == 0 && v.planSemanal.partidas.isEmpty
            ? null
            : () async {
                if (await intentar(
                      context,
                      () => servicio.activarSemana(c.libroId, semana),
                    ) &&
                    context.mounted) {
                  avisar(context, 'Semana activada.');
                }
              },
        icon: const Icon(Icons.play_arrow),
        label: const Text('Activar semana'),
      ),
      EstadoSemana.cerrada => OutlinedButton.icon(
        key: const ValueKey('semana-reabrir'),
        onPressed: () async {
          final si = await confirmar(
            context,
            titulo: 'Reabrir la semana',
            mensaje:
                'La foto del cierre se conserva. Al volver a cerrarla se '
                'guarda la versión siguiente. Queda en la bitácora.',
            textoAccion: 'Reabrir',
          );
          if (si && context.mounted) {
            await intentar(context, () => servicio.reabrirSemana(c.libroId, semana));
          }
        },
        icon: const Icon(Icons.lock_open),
        label: const Text('Reabrir'),
      ),
      _ => FilledButton.icon(
        key: const ValueKey('semana-revision'),
        onPressed: () => mostrarRevisionSemanal(context, c, semana),
        icon: const Icon(Icons.fact_check_outlined),
        label: const Text('Revisión semanal'),
      ),
    };
  }
}

class _Semana extends ConsumerStatefulWidget {
  const _Semana({required this.contexto});

  final ContextoFinanzas contexto;

  @override
  ConsumerState<_Semana> createState() => _SemanaState();
}

class _SemanaState extends ConsumerState<_Semana> {
  TipoPeriodo _periodo = TipoPeriodo.semana;

  @override
  Widget build(BuildContext context) {
    final c = widget.contexto;
    final semana = semanaVista(ref, c);
    final v = vistaSemana(c.datos, c.libroId, semana, hoy: c.hoy);
    final ocultos = ref.watch(montosOcultosProvider);
    final elegir = ref.read(semanaElegidaProvider.notifier);
    return ContenidoLaptop(
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            IconButton(
              key: const ValueKey('semana-anterior'),
              tooltip: 'Semana anterior',
              onPressed: () => elegir.elegir(semana.anterior),
              icon: const Icon(Icons.chevron_left),
            ),
            Text(textoSemana(semana), style: Theme.of(context).textTheme.titleMedium),
            IconButton(
              key: const ValueKey('semana-siguiente'),
              tooltip: 'Semana siguiente',
              onPressed: () => elegir.elegir(semana.siguiente),
              icon: const Icon(Icons.chevron_right),
            ),
            if (semana != Semana.de(c.hoy))
              TextButton(onPressed: () => elegir.elegir(null), child: const Text('Hoy')),
            Chip(
              key: const ValueKey('semana-estado'),
              label: Text(nombreEstadoSemana(v.estado)),
            ),
            SegmentedButton<TipoPeriodo>(
              key: const ValueKey('semana-periodo'),
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: TipoPeriodo.semana, label: Text('Semana')),
                ButtonSegment(value: TipoPeriodo.catorcena, label: Text('Catorcena')),
                ButtonSegment(value: TipoPeriodo.quincena, label: Text('Quincena')),
                ButtonSegment(value: TipoPeriodo.mes, label: Text('Mes')),
              ],
              selected: {_periodo},
              onSelectionChanged: (s) => setState(() => _periodo = s.first),
            ),
          ],
        ),
        if (_periodo != TipoPeriodo.semana)
          _VistaPeriodo(contexto: c, vista: v, periodo: _periodo, ocultos: ocultos)
        else ...[
          if (v.estado == EstadoSemana.cerrada && v.ultimoCierre != null)
            Text(
              'Cerrada (versión ${v.ultimoCierre!.version}'
              '${v.ultimoCierre!.conPendientes ? ', con pendientes' : ''}) el '
              '${fechaYHora(v.ultimoCierre!.cerradoEn)}.',
            ),
          TarjetaModulo(
            key: const ValueKey('semana-cascada'),
            titulo: 'Cascada · planeado contra real',
            icono: Icons.waterfall_chart,
            accion: Semaforo(
              estado: estadoDe(v.indicadores.remanente),
              etiqueta:
                  'Remanente ${formatearPuntosBase(v.indicadores.remanentePuntosBase)}',
              tamanoTexto: 12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GadgetCascada(escalones: escalonesDe(v), montosOcultos: ocultos),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  children: [
                    _Dato('Meta de remanente', v.planSemanal.metaRemanente),
                    _Dato('Techo de presupuesto', v.planSemanal.techo),
                    if (v.planConfiguracion.plan.ingresoPotencial > 0)
                      _Dato(
                        'Ingreso potencial (no cuenta)',
                        v.planConfiguracion.plan.ingresoPotencial,
                      ),
                    if (v.real.deficit > 0) _Dato('Déficit', v.real.deficit),
                  ],
                ),
                if (!v.planSemanal.dentroDelTecho)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'El presupuesto pasa del techo: la revisión semanal '
                      'propone recortes en lo discrecional (nunca en lo '
                      'protegido).',
                    ),
                  ),
              ],
            ),
          ),
          _TablaPartidas(vista: v, ocultos: ocultos),
          if (v.real.abonos.isNotEmpty) _TablaAbonos(vista: v, ocultos: ocultos),
          _Flujo(vista: v, ocultos: ocultos),
        ],
      ],
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato(this.etiqueta, this.centavos);

  final String etiqueta;
  final int centavos;

  @override
  Widget build(BuildContext context) => DatoConMonto(etiqueta, centavos);
}

class _TablaPartidas extends StatelessWidget {
  const _TablaPartidas({required this.vista, required this.ocultos});

  final VistaSemana vista;
  final bool ocultos;

  static String _tipo(TipoPartida t) => switch (t) {
    TipoPartida.fija => 'Fija',
    TipoPartida.variable => 'Sobre',
    TipoPartida.reserva => 'Reserva',
  };

  @override
  Widget build(BuildContext context) {
    final v = vista;
    final partidas = [...v.real.partidas]
      ..sort((a, b) => a.partida.tipo.index.compareTo(b.partida.tipo.index));
    return TarjetaModulo(
      key: const ValueKey('semana-partidas'),
      titulo: 'Partidas',
      icono: Icons.table_rows_outlined,
      child: TablaDensa(
        anchoMinimo: 720,
        etiquetaSemantica: 'Partidas de la semana',
        vacio: const Text('Sin partidas: configura compromisos y sobres.'),
        columnas: const [
          ColumnaTabla('Partida', flex: 3),
          ColumnaTabla('Tipo'),
          ColumnaTabla('Asignado', numerica: true),
          ColumnaTabla('Arrastre', numerica: true),
          ColumnaTabla('Gastado', numerica: true),
          ColumnaTabla('Restante', numerica: true),
          ColumnaTabla('Semáforo', flex: 2),
        ],
        filas: [
          for (final p in partidas)
            FilaTabla(
              etiquetaSemantica: v.infoPartida(p.partida.id).nombre,
              celdas: [
                CeldaTexto(
                  v.infoPartida(p.partida.id).nombre,
                  detalle: p.partida.protegida ? 'Protegida' : null,
                ),
                CeldaTexto(_tipo(p.partida.tipo)),
                CeldaMonto(p.asignado, oculto: ocultos),
                CeldaMonto(p.arrastreRecibido, oculto: ocultos, tenue: true),
                CeldaMonto(p.gastado, oculto: ocultos),
                CeldaMonto(p.restante, oculto: ocultos),
                p.partida.tipo == TipoPartida.variable
                    ? CeldaSemaforo(
                        estadoDe(p.semaforo),
                        etiqueta: UsoPresupuesto(
                          asignadoCentavos: p.disponible,
                          gastadoCentavos: p.gastado,
                        ).textoEstado,
                      )
                    : CeldaTexto(
                        (v.gasto.pagadoPorPartida[p.partida.id] ?? 0) > 0
                            ? 'Pagado'
                            : 'Devengado',
                        tenue: true,
                      ),
              ],
            ),
        ],
        pie: FilaTabla(
          celdas: [
            const CeldaTexto('Total'),
            const CeldaTexto(''),
            CeldaMonto(v.planSemanal.presupuesto, oculto: ocultos),
            CeldaMonto(
              v.real.partidas.fold(0, (t, p) => t + p.arrastreRecibido),
              oculto: ocultos,
            ),
            CeldaMonto(v.real.gastoReal, oculto: ocultos),
            CeldaMonto(
              v.planSemanal.presupuesto - v.real.gastoReal,
              oculto: ocultos,
            ),
            const CeldaTexto(''),
          ],
        ),
      ),
    );
  }
}

class _TablaAbonos extends StatelessWidget {
  const _TablaAbonos({required this.vista, required this.ocultos});

  final VistaSemana vista;
  final bool ocultos;

  @override
  Widget build(BuildContext context) {
    final v = vista;
    return TarjetaModulo(
      key: const ValueKey('semana-abonos'),
      titulo: 'Abonos a deudas',
      icono: Icons.credit_card_outlined,
      child: TablaDensa(
        anchoMinimo: 640,
        columnas: const [
          ColumnaTabla('Deuda', flex: 3),
          ColumnaTabla('Planeado', numerica: true),
          ColumnaTabla('Real', numerica: true),
          ColumnaTabla('Mínimo', numerica: true),
          ColumnaTabla('Diferido', numerica: true),
          ColumnaTabla('Extra', numerica: true),
          ColumnaTabla('Estado', flex: 2),
        ],
        filas: [
          for (final a in v.real.abonos)
            FilaTabla(
              celdas: [
                CeldaTexto(
                  a.deuda.nombre,
                  detalle: a.deuda.grupoPrioritario
                      ? 'Grupo prioritario (${a.deuda.ordenGrupo ?? '-'})'
                      : null,
                ),
                CeldaMonto(a.planeado, oculto: ocultos),
                CeldaMonto(a.real, oculto: ocultos),
                CeldaMonto(a.minimo, oculto: ocultos, tenue: true),
                CeldaMonto(a.diferido, oculto: ocultos),
                CeldaMonto(v.real.destino.extraPara(a.deuda.id), oculto: ocultos),
                a.bajoMinimo
                    ? const CeldaSemaforo(
                        EstadoSemaforo.rojo,
                        etiqueta: 'Bajo el mínimo',
                      )
                    : CeldaSemaforo(
                        a.diferido > 0 ? EstadoSemaforo.ambar : EstadoSemaforo.verde,
                        etiqueta: a.diferido > 0 ? 'Diferido' : 'Completo',
                      ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Flujo extends StatelessWidget {
  const _Flujo({required this.vista, required this.ocultos});

  final VistaSemana vista;
  final bool ocultos;

  @override
  Widget build(BuildContext context) {
    final f = vista.flujo;
    final riesgo = f.primerDiaEnRiesgo;
    return TarjetaModulo(
      key: const ValueKey('semana-flujo'),
      titulo: 'Flujo de las próximas semanas (fechas reales)',
      icono: riesgo == null ? Icons.timeline : Icons.warning_amber_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (riesgo != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Semaforo(estado: EstadoSemaforo.rojo, etiqueta: 'Alerta de flujo'),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'El ${textoFecha(riesgo.fecha)} el saldo puede bajar a',
                      key: const ValueKey('semana-alerta-flujo'),
                    ),
                  ),
                  Monto(riesgo.saldoPeorCaso),
                ],
              ),
            ),
          TablaDensa(
            anchoMinimo: 560,
            columnas: const [
              ColumnaTabla('Semana', flex: 2),
              ColumnaTabla('Entradas', numerica: true),
              ColumnaTabla('Salidas', numerica: true),
              ColumnaTabla('Neto', numerica: true),
            ],
            filas: [
              for (final s in f.semanas)
                FilaTabla(
                  etiquetaSemantica: textoSemana(s.semana),
                  celdas: [
                    CeldaTexto(textoSemana(s.semana)),
                    CeldaMonto(s.entradas, oculto: ocultos),
                    CeldaMonto(s.salidas, oculto: ocultos),
                    CeldaMonto(s.neto, oculto: ocultos, mostrarSigno: true),
                  ],
                ),
            ],
          ),
          if (f.noSeguros.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Aparte (no cuentan en el peor caso): '
                '${f.noSeguros.map((x) => '${x.concepto} ${textoFecha(x.fecha.ajustada)}').join(', ')}.',
              ),
            ),
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Si en un día hay entradas y salidas, se suponen primero las '
              'salidas. Nunca se propone tapar un hueco con una tarjeta.',
            ),
          ),
        ],
      ),
    );
  }
}

/// Vista por catorcena, quincena o mes (5.6 bis, punto 2): el presupuesto se
/// prorratea desde el monto anual exacto; el gasto real sale de las fechas.
class _VistaPeriodo extends StatelessWidget {
  const _VistaPeriodo({
    required this.contexto,
    required this.vista,
    required this.periodo,
    required this.ocultos,
  });

  final ContextoFinanzas contexto;
  final VistaSemana vista;
  final TipoPeriodo periodo;
  final bool ocultos;

  @override
  Widget build(BuildContext context) {
    final c = contexto;
    final fecha = vista.semana.inicio;
    final ancla = c.datos
        .ingresosDe(c.libroId)
        .expand((i) => i.vigencias)
        .map((v) => v.calendario)
        .where((x) => x.forma == FormaPago.catorcenal && x.fechaAncla != null)
        .map((x) => x.fechaAncla!)
        .firstOrNull;
    final rango = Periodo.de(periodo, fecha, ancla: ancla ?? fecha);
    final plan = vista.planConfiguracion.plan.enPeriodo(periodo);
    final real = c.datos.vista(c.libroId).estadoResultados(rango);
    final nombre = switch (periodo) {
      TipoPeriodo.semana => 'Semana',
      TipoPeriodo.catorcena => 'Catorcena',
      TipoPeriodo.quincena => 'Quincena',
      TipoPeriodo.mes => 'Mes',
    };
    final mes = periodo == TipoPeriodo.mes
        ? gastoDelMesPorSemanas(c.datos, c.libroId, fecha.anio, fecha.mes)
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TarjetaModulo(
          key: const ValueKey('semana-vista-periodo'),
          titulo:
              '$nombre · ${textoFecha(rango.inicio)} a ${textoFecha(rango.fin)}',
          icono: Icons.date_range_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GadgetCascada(
                montosOcultos: ocultos,
                escalones: [
                  EscalonCascada(etiqueta: 'Ingreso', planeadoCentavos: plan.ingreso),
                  EscalonCascada(
                    etiqueta: '− Presupuesto',
                    planeadoCentavos: plan.presupuesto,
                    realCentavos: real.gastos + real.gastoFinanciero,
                  ),
                  EscalonCascada(etiqueta: '− Deuda', planeadoCentavos: plan.deuda),
                  EscalonCascada(
                    etiqueta: '= Remanente',
                    planeadoCentavos: plan.remanente,
                    tono: plan.remanente < 0 ? TonoEscalon.peligro : TonoEscalon.neutro,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'El plan se prorratea desde el monto anual exacto; lo real '
                'sale de las fechas de los movimientos.',
              ),
            ],
          ),
        ),
        if (mes != null) ...[
          const SizedBox(height: 16),
          TarjetaModulo(
            key: const ValueKey('semana-mes-por-semanas'),
            titulo: 'El mes por semanas (${mes.semanas.length} lunes)',
            icono: Icons.view_week_outlined,
            child: TablaDensa(
              anchoMinimo: 420,
              columnas: const [
                ColumnaTabla('Semana', flex: 2),
                ColumnaTabla('Gasto', numerica: true),
              ],
              filas: [
                for (final (s, gasto) in mes.semanas)
                  FilaTabla(
                    celdas: [CeldaTexto(textoSemana(s)), CeldaMonto(gasto, oculto: ocultos)],
                  ),
              ],
              pie: FilaTabla(
                celdas: [
                  const CeldaTexto('Promedio semanal'),
                  CeldaMonto(mes.promedioSemanal, oculto: ocultos),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Semáforo del dominio → texto corto.
String textoSemaforo(dom.Semaforo s) => estadoDe(s).etiqueta;
