/// Compromisos y deudas (laptop; especificación 6.1): gastos fijos y
/// reservas con su próxima fecha, sobres semanales, deudas con abono, mínimo
/// y tasa, y el **grupo de deudas prioritarias** con su orden (P12; regla 4
/// de 4.5).
library;

import 'package:finanzas_dominio/finanzas_dominio.dart'
    hide Semaforo, formatearCentavos, TipoLibro, puntosBaseEnCien;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../diseno/diseno.dart';
import '../../estado/proveedores.dart';
import '../comunes.dart';
import 'dialogos_config.dart';
import 'marco_laptop.dart';

class PantallaCompromisos extends StatelessWidget {
  const PantallaCompromisos({super.key});

  @override
  Widget build(BuildContext context) => MarcoFinanzasLaptop(
    seccion: SeccionFinanzas.compromisos,
    acciones: (context, c) => [
      if (c.puedeAdministrar) ...[
        FilledButton.icon(
          key: const ValueKey('compromisos-nuevo'),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => DialogoCompromiso(contexto: c),
          ),
          icon: const Icon(Icons.add),
          label: const Text('Nuevo compromiso'),
        ),
        OutlinedButton(
          key: const ValueKey('compromisos-nuevo-sobre'),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => DialogoSobre(contexto: c),
          ),
          child: const Text('Nuevo sobre'),
        ),
        OutlinedButton(
          key: const ValueKey('compromisos-nueva-deuda'),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => DialogoDeuda(contexto: c),
          ),
          child: const Text('Nueva deuda'),
        ),
      ],
    ],
    builder: (context, c) => _Compromisos(contexto: c),
  );
}

class _Compromisos extends ConsumerWidget {
  const _Compromisos({required this.contexto});

  final ContextoFinanzas contexto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = contexto;
    final ocultos = ref.watch(montosOcultosProvider);
    final servicio = ref.read(servicioFinanzasProvider);
    final compromisos = c.datos.compromisosDe(c.libroId);
    final sobres = c.datos.sobresDe(c.libroId);
    final deudas = c.datos.deudasDe(c.libroId);
    final cal = c.datos.calendario;
    String proxima(List<FechaPago> pagos) => pagos.isEmpty
        ? '—'
        : (pagos.first.seMovio
              ? '${textoFecha(pagos.first.ajustada)} (era ${textoDiaMes(pagos.first.programada)})'
              : textoFecha(pagos.first.ajustada));
    final planes = [
      for (final d in deudas)
        if (d.activa) d.plan(saldo: saldoDeDeuda(c.datos, d)),
    ];
    final orden = ordenDeAbonoExtra(planes);
    final grupo = hayGrupoPrioritario(planes);
    final enGrupo = [
      for (final d in deudas)
        if (d.grupoPrioritario) d,
    ]..sort((a, b) => (a.ordenGrupo ?? 99).compareTo(b.ordenGrupo ?? 99));

    Future<void> moverEnGrupo(Deuda d, int delta) async {
      final lista = [...enGrupo];
      final i = lista.indexWhere((x) => x.id == d.id);
      final j = i + delta;
      if (i < 0 || j < 0 || j >= lista.length) return;
      final x = lista.removeAt(i);
      lista.insert(j, x);
      for (var k = 0; k < lista.length; k++) {
        await servicio.guardarDeuda(lista[k].copiar(ordenGrupo: k + 1));
      }
    }

    return ContenidoLaptop(
      children: [
        TarjetaModulo(
          key: const ValueKey('compromisos-fijos'),
          titulo: 'Gastos fijos y reservas',
          icono: Icons.event_repeat_outlined,
          child: TablaDensa(
            anchoMinimo: 760,
            vacio: const Text('Sin compromisos. Renta, servicios, reservas…'),
            columnas: const [
              ColumnaTabla('Nombre', flex: 3),
              ColumnaTabla('Tipo'),
              ColumnaTabla('Monto', numerica: true),
              ColumnaTabla('Cada cuándo', flex: 3),
              ColumnaTabla('Próxima fecha', flex: 2),
            ],
            filas: [
              for (final x in compromisos)
                FilaTabla(
                  etiquetaSemantica: x.nombre,
                  celdas: [
                    CeldaTexto(
                      x.nombre,
                      detalle: x.protegida ? 'Protegido' : null,
                    ),
                    CeldaTexto(
                      x.tipo == TipoCompromiso.fija ? 'Fijo' : 'Reserva',
                    ),
                    CeldaMonto(x.monto, oculto: ocultos),
                    CeldaTexto(
                      x.calendario == null
                          ? nombreFrecuencia(x.frecuencia)
                          : descripcionCalendario(x.calendario!, salida: true),
                    ),
                    CeldaTexto(
                      proxima(x.pagosEntre(c.hoy, c.hoy.sumarDias(400), cal)),
                    ),
                  ],
                ),
            ],
          ),
        ),
        TarjetaModulo(
          key: const ValueKey('compromisos-sobres'),
          titulo: 'Sobres semanales (partidas variables)',
          icono: Icons.mail_outline,
          child: TablaDensa(
            anchoMinimo: 640,
            vacio: const Text(
              'Sin sobres: agrégalos hasta el techo del presupuesto.',
            ),
            columnas: const [
              ColumnaTabla('Sobre', flex: 3),
              ColumnaTabla('Por semana', numerica: true),
              ColumnaTabla('Prioridad'),
              ColumnaTabla('Lo que sobra', flex: 2),
            ],
            filas: [
              for (final s in sobres)
                FilaTabla(
                  etiquetaSemantica: s.nombre,
                  alTocar: c.puedeAdministrar
                      ? () => showDialog<void>(
                          context: context,
                          builder: (_) => DialogoSobre(contexto: c, sobre: s),
                        )
                      : null,
                  celdas: [
                    CeldaTexto(s.nombre, detalle: s.activo ? null : 'Inactivo'),
                    CeldaMonto(s.montoSemanal, oculto: ocultos),
                    CeldaTexto(nombrePrioridad(s.prioridad)),
                    CeldaTexto(
                      s.modoArrastre == ModoArrastre.arrastrar
                          ? 'Pasa a la semana siguiente'
                          : 'Va al remanente',
                    ),
                  ],
                ),
            ],
          ),
        ),
        TarjetaModulo(
          key: const ValueKey('compromisos-deudas'),
          titulo: 'Deudas',
          icono: Icons.credit_card_outlined,
          child: TablaDensa(
            anchoMinimo: 760,
            vacio: const Text('Sin deudas en este libro.'),
            columnas: const [
              ColumnaTabla('Deuda', flex: 3),
              ColumnaTabla('Tipo', flex: 2),
              ColumnaTabla('Abono', numerica: true),
              ColumnaTabla('Mínimo', numerica: true),
              ColumnaTabla('Tasa', numerica: true),
              ColumnaTabla('Saldo', numerica: true),
              ColumnaTabla('Grupo', flex: 2),
            ],
            filas: [
              for (final d in deudas)
                FilaTabla(
                  etiquetaSemantica: d.nombre,
                  celdas: [
                    CeldaTexto(d.nombre),
                    CeldaTexto(nombreTipoDeuda(d.tipo)),
                    CeldaMonto(d.abono, oculto: ocultos),
                    CeldaMonto(d.minimo, oculto: ocultos, tenue: true),
                    CeldaTexto(
                      d.tipo == TipoDeuda.conCosto
                          ? formatearPuntosBase(d.tasaAnualPuntosBase)
                          : '—',
                      numerico: true,
                    ),
                    CeldaMonto(saldoDeDeuda(c.datos, d) ?? 0, oculto: ocultos),
                    c.puedeAdministrar
                        ? Row(
                            children: [
                              Checkbox(
                                key: ValueKey('deuda-grupo-${d.id}'),
                                value: d.grupoPrioritario,
                                onChanged: (x) => intentar(
                                  context,
                                  () => servicio.guardarDeuda(
                                    d.copiar(
                                      grupoPrioritario: x ?? false,
                                      ordenGrupo: (x ?? false)
                                          ? enGrupo.length + 1
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                              if (d.grupoPrioritario) ...[
                                Text('${d.ordenGrupo ?? '-'}'),
                                IconButton(
                                  tooltip: 'Subir',
                                  iconSize: 18,
                                  onPressed: () => intentar(
                                    context,
                                    () => moverEnGrupo(d, -1),
                                  ),
                                  icon: const Icon(Icons.arrow_upward),
                                ),
                                IconButton(
                                  tooltip: 'Bajar',
                                  iconSize: 18,
                                  onPressed: () => intentar(
                                    context,
                                    () => moverEnGrupo(d, 1),
                                  ),
                                  icon: const Icon(Icons.arrow_downward),
                                ),
                              ],
                            ],
                          )
                        : CeldaTexto(
                            d.grupoPrioritario ? '${d.ordenGrupo ?? '-'}' : '—',
                          ),
                  ],
                ),
            ],
          ),
        ),
        TarjetaModulo(
          key: const ValueKey('compromisos-orden'),
          titulo: 'Orden del abono extra',
          icono: Icons.format_list_numbered,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                grupo
                    ? 'Grupo prioritario: el remanente (después del ahorro '
                          'mínimo) y el abono que libera una deuda pagada van a '
                          'la siguiente del grupo; cuando el grupo queda pagado, '
                          'a ahorro. Las demás deudas no reciben extra.'
                    : 'Sin grupo: primero la de mayor tasa, después los '
                          'préstamos familiares; las compras a meses sin '
                          'intereses no reciben extra. Marca deudas para formar '
                          'tu grupo prioritario.',
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < orden.length; i++)
                Text('${i + 1}. ${orden[i].nombre}'),
            ],
          ),
        ),
      ],
    );
  }
}
