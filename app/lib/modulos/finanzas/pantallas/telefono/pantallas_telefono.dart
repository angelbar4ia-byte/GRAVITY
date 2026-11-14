/// Finanzas en el teléfono (`DISENO_UX_UI.md` sección 9; especificación 6.2):
/// la semana resumida (cascada con semáforo, partidas con medidor y alerta de
/// flujo) y los movimientos recientes. Cada persona ve sus libros (D19).
library;

import 'package:finanzas_dominio/finanzas_dominio.dart'
    hide Semaforo, formatearCentavos, TipoLibro, puntosBaseEnCien;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/pantallas/marco_pantalla.dart';
import '../../../../diseno/diseno.dart';
import '../../../../nucleo/contratos/roles.dart';
import '../../../../nucleo/contratos/rutas.dart';
import '../../estado/proveedores.dart';
import '../comunes.dart';
import '../fila_movimiento.dart';

/// Semana resumida (raíz de Finanzas en el teléfono y la tablet).
class PantallaSemanaTelefono extends ConsumerWidget {
  const PantallaSemanaTelefono({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => TemaModulo(
    modulo: Modulo.finanzas,
    child: MarcoPantalla(
      titulo: 'Finanzas',
      acciones: const [BotonMontos()],
      cuerpo: ConDatosFinanzas(
        builder: (context, c) => RefreshIndicator(
          onRefresh: () => ref.read(cargaFinanzasProvider.notifier).recargar(),
          child: _SemanaResumida(contexto: c),
        ),
      ),
    ),
  );
}

class _SemanaResumida extends ConsumerWidget {
  const _SemanaResumida({required this.contexto});

  final ContextoFinanzas contexto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = contexto;
    final semana = Semana.de(c.hoy);
    final v = vistaSemana(c.datos, c.libroId, semana, hoy: c.hoy);
    final ocultos = ref.watch(montosOcultosProvider);
    final hueco = SizedBox(height: ValoresDiseno.de(context).espacio * 2);
    final variables = [
      for (final p in v.real.partidas)
        if (p.partida.tipo == TipoPartida.variable) p,
    ];
    final recientes = movimientosDelLibro(c).take(5).toList();
    final riesgo = v.flujo.primerDiaEnRiesgo;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SelectorLibroFinanzas(contexto: c),
        if (c.libros.length > 1) const SizedBox(height: 8),
        marcaDe(c),
        const Align(
          alignment: AlignmentDirectional.centerStart,
          child: MarcaMontosOcultos(),
        ),
        hueco,
        TarjetaModulo(
          key: const ValueKey('finanzas-semana-resumen'),
          titulo: textoSemana(semana),
          icono: Icons.waterfall_chart,
          accion: Semaforo(
            estado: estadoDe(v.indicadores.remanente),
            etiqueta:
                'Remanente ${formatearPuntosBase(v.indicadores.remanentePuntosBase, decimales: 1)}',
            tamanoTexto: 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GadgetCascada(escalones: escalonesDe(v), montosOcultos: ocultos),
              if (v.estado == EstadoSemana.borrador) ...[
                const SizedBox(height: 8),
                Text(
                  'La semana aún no está activada: el plan sale de tu '
                  'configuración.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (c.puedeEscribir && v.planSemanal.ingreso > 0)
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                      key: const ValueKey('finanzas-activar-semana'),
                      onPressed: () => intentar(
                        context,
                        () => ref
                            .read(servicioFinanzasProvider)
                            .activarSemana(c.libroId, semana),
                      ),
                      child: const Text('Activar semana'),
                    ),
                  ),
              ],
            ],
          ),
        ),
        if (riesgo != null) ...[
          hueco,
          TarjetaModulo(
            key: const ValueKey('finanzas-alerta-flujo'),
            titulo: 'Alerta de flujo',
            icono: Icons.warning_amber_rounded,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'El ${textoFecha(riesgo.fecha)} el saldo puede bajar a',
                  ),
                ),
                Monto(riesgo.saldoPeorCaso),
              ],
            ),
          ),
        ],
        if (variables.isNotEmpty) ...[
          hueco,
          TarjetaModulo(
            titulo: 'Partidas',
            icono: Icons.donut_large_outlined,
            child: Column(
              children: [
                for (final p in variables)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: MedidorPresupuesto(
                      key: ValueKey('medidor-${p.partida.id}'),
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
        ],
        hueco,
        TarjetaModulo(
          titulo: 'Movimientos recientes',
          icono: Icons.receipt_long_outlined,
          accion: TextButton(
            key: const ValueKey('finanzas-ver-movimientos'),
            onPressed: () => context.go('${Rutas.finanzas}/movimientos'),
            child: const Text('Ver todos'),
          ),
          child: recientes.isEmpty
              ? const Text('Aún no hay movimientos en este libro.')
              : Column(
                  children: [
                    for (final m in recientes)
                      FilaMovimiento(movimiento: m, contexto: c),
                  ],
                ),
        ),
        hueco,
        OutlinedButton.icon(
          key: const ValueKey('finanzas-ver-reportes'),
          onPressed: () => context.go('${Rutas.finanzas}/reportes'),
          icon: const Icon(Icons.assessment_outlined),
          label: const Text('Reportes'),
        ),
      ],
    );
  }
}

/// Movimientos del libro activo (teléfono): lista corta con anular.
class PantallaMovimientosTelefono extends ConsumerWidget {
  const PantallaMovimientosTelefono({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => TemaModulo(
    modulo: Modulo.finanzas,
    child: MarcoPantalla(
      titulo: 'Movimientos',
      rutaAnterior: Rutas.finanzas,
      acciones: const [BotonMontos()],
      cuerpo: ConDatosFinanzas(
        builder: (context, c) {
          final lista = movimientosDelLibro(c).take(100).toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: SelectorLibroFinanzas(contexto: c),
              ),
              const Align(
                alignment: AlignmentDirectional.centerStart,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: MarcaMontosOcultos(),
                ),
              ),
              Expanded(
                child: lista.isEmpty
                    ? const EstadoVacio(
                        icono: Icons.receipt_long_outlined,
                        mensaje: 'Aún no hay movimientos en este libro.',
                      )
                    : ListView.builder(
                        itemCount: lista.length,
                        itemBuilder: (context, i) =>
                            FilaMovimiento(movimiento: lista[i], contexto: c),
                      ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
