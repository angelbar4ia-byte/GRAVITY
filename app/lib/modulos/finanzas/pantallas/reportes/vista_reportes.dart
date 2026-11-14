/// Reportes de Finanzas (Fase 8, bloque 4) en la laptop y el teléfono. Cada
/// uno muestra solo lo del **libro de quien lo pide** (D19): el activo, y la
/// aportación de la casa solo si la persona ve ese libro. Ninguna cifra sale
/// de la app (D3).
library;

import 'package:finanzas_dominio/finanzas_dominio.dart'
    hide
        Semaforo,
        formatearCentavos,
        TipoLibro,
        VisibilidadLibro,
        puntosBaseEnCien;
import 'package:finanzas_dominio/finanzas_dominio.dart' as dom show TipoLibro;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/pantallas/marco_pantalla.dart';
import '../../../../diseno/diseno.dart';
import '../../../../nucleo/contratos/roles.dart';
import '../../../../nucleo/contratos/rutas.dart';
import '../../casos_uso/reportes.dart';
import '../../datos/demostracion.dart' show IdsDemostracion;
import '../../datos/patrimonio.dart';
import '../../datos/transferencias.dart';
import '../../estado/proveedores.dart';
import '../../estado/proveedores_patrimonio.dart';
import '../../estado/proveedores_transferencias.dart';
import '../comunes.dart';
import '../laptop/marco_laptop.dart';

class PantallaReportes extends StatelessWidget {
  const PantallaReportes({super.key});

  @override
  Widget build(BuildContext context) => MarcoFinanzasLaptop(
    seccion: SeccionFinanzas.reportes,
    builder: (context, c) => VistaReportes(contexto: c),
  );
}

class PantallaReportesTelefono extends StatelessWidget {
  const PantallaReportesTelefono({super.key});

  @override
  Widget build(BuildContext context) => TemaModulo(
    modulo: Modulo.finanzas,
    child: MarcoPantalla(
      titulo: 'Reportes',
      rutaAnterior: Rutas.finanzas,
      acciones: const [BotonMontos()],
      cuerpo: ConDatosFinanzas(
        builder: (context, c) => VistaReportes(contexto: c, telefono: true),
      ),
    ),
  );
}

/// Periodos que se ofrecen; "Otro" abre el selector de fechas.
enum PeriodoReporte {
  esteMes('Este mes'),
  mesAnterior('Mes anterior'),
  tresMeses('Últimos 3 meses'),
  anio('Este año'),
  otro('Otro…');

  const PeriodoReporte(this.titulo);
  final String titulo;

  RangoReporte rango(Fecha hoy, RangoReporte? elegido) => switch (this) {
    PeriodoReporte.esteMes => RangoReporte.delMesDe(hoy),
    PeriodoReporte.mesAnterior => RangoReporte.delMesDe(
      hoy.primerDiaDelMes.sumarDias(-1),
    ),
    PeriodoReporte.tresMeses => RangoReporte(
      Fecha.enMes(
        (hoy.anio * 12 + hoy.mes - 3) ~/ 12,
        (hoy.anio * 12 + hoy.mes - 3) % 12 + 1,
        1,
      ),
      hoy.ultimoDiaDelMes,
    ),
    PeriodoReporte.anio => RangoReporte(
      Fecha(hoy.anio, 1, 1),
      Fecha(hoy.anio, 12, 31),
    ),
    PeriodoReporte.otro => elegido ?? RangoReporte.delMesDe(hoy),
  };
}

final _referenciasCasaProvider = FutureProvider<Map<String, ReparteReferencia>>(
  (ref) async {
    final repo = ref.watch(repositorioTransferenciasProvider);
    final subs = await repo.subcuentas();
    return {for (final s in subs) s.id: await repo.referencia(s.id)};
  },
);

class VistaReportes extends ConsumerStatefulWidget {
  const VistaReportes({
    super.key,
    required this.contexto,
    this.telefono = false,
  });

  final ContextoFinanzas contexto;
  final bool telefono;

  @override
  ConsumerState<VistaReportes> createState() => _VistaReportesState();
}

class _VistaReportesState extends ConsumerState<VistaReportes> {
  PeriodoReporte _periodo = PeriodoReporte.esteMes;
  RangoReporte? _otro;

  Future<void> _elegirOtro() async {
    final c = widget.contexto;
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: aDateTime(c.hoy.sumarDias(366)),
      initialDateRange: DateTimeRange(
        start: aDateTime(_periodo.rango(c.hoy, _otro).desde),
        end: aDateTime(_periodo.rango(c.hoy, _otro).hasta),
      ),
    );
    if (r == null) return;
    setState(() {
      _otro = RangoReporte(Fecha.deDateTime(r.start), Fecha.deDateTime(r.end));
      _periodo = PeriodoReporte.otro;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.contexto;
    final rango = _periodo.rango(c.hoy, _otro);
    final espacio = SizedBox(height: ValoresDiseno.de(context).espacio * 2);
    final contenido = <Widget>[
      Wrap(
        key: const ValueKey('reportes-periodos'),
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final p in PeriodoReporte.values)
            ChoiceChip(
              key: ValueKey('reportes-periodo-${p.name}'),
              label: Text(p.titulo),
              selected: _periodo == p,
              onSelected: (_) => p == PeriodoReporte.otro
                  ? _elegirOtro()
                  : setState(() => _periodo = p),
            ),
        ],
      ),
      Text(
        'Del ${textoFecha(rango.desde)} al ${textoFecha(rango.hasta)} · '
        'libro: ${c.libro?.nombre ?? ''}',
        key: const ValueKey('reportes-rango'),
      ),
      _TarjetaGastoCategoria(contexto: c, rango: rango),
      _TarjetaAportacion(contexto: c, rango: rango),
      _TarjetaDeudas(contexto: c),
      _TarjetaObjetivos(contexto: c),
    ];
    final lista = [
      for (var i = 0; i < contenido.length; i++) ...[
        if (i > 0) espacio,
        contenido[i],
      ],
    ];
    return widget.telefono
        ? ListView(
            key: const ValueKey('reportes-lista'),
            padding: const EdgeInsets.all(16),
            children: lista,
          )
        : ContenidoLaptop(children: contenido);
  }
}

class _TarjetaGastoCategoria extends StatelessWidget {
  const _TarjetaGastoCategoria({required this.contexto, required this.rango});

  final ContextoFinanzas contexto;
  final RangoReporte rango;

  @override
  Widget build(BuildContext context) {
    final c = contexto;
    final r = gastoPorCategoria(c.datos, c.libroId, rango);
    final meses = gastoPorMes(c.datos, c.libroId, c.hoy, meses: 6);
    String pct(int pb) => '${(pb / 100).toStringAsFixed(1)}%';
    return TarjetaModulo(
      key: const ValueKey('reporte-gasto-categoria'),
      titulo: 'Gasto por categoría',
      icono: Icons.pie_chart_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DatoConMonto('Gasto del periodo', r.totalCentavos),
          if (r.lineas.isEmpty)
            const Text(
              'Sin gastos en este periodo.',
              key: ValueKey('reporte-gasto-vacio'),
            )
          else
            for (final l in r.lineas)
              ListTile(
                key: ValueKey('reporte-cat-${l.categoriaId ?? 'sin'}'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(l.nombre),
                subtitle: Text(pct(l.partePb)),
                trailing: Monto(l.centavos),
              ),
          const Divider(),
          const EtiquetaPanel('Por mes (últimos 6)'),
          for (final m in meses)
            ListTile(
              key: ValueKey('reporte-mes-${m.anio}-${m.mes}'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(textoMes(m.anio, m.mes)),
              trailing: Monto(m.centavos),
            ),
        ],
      ),
    );
  }
}

const _nombresMes = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

String textoMes(int anio, int mes) => '${_nombresMes[mes - 1]} $anio';

class _TarjetaAportacion extends ConsumerWidget {
  const _TarjetaAportacion({required this.contexto, required this.rango});

  final ContextoFinanzas contexto;
  final RangoReporte rango;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = contexto;
    // Solo si la persona ve el libro de la casa (D19).
    final casa = c.libros
        .where((l) => l.tipo == dom.TipoLibro.compartido)
        .firstOrNull;
    if (casa == null) return const SizedBox.shrink();
    final transferencias = ref.watch(transferenciasProvider).value ?? const [];
    final subcuentas = ref.watch(subcuentasCasaProvider).value ?? const [];
    final referencias = ref.watch(_referenciasCasaProvider).value ?? const {};
    final r = reporteDeAportacion(
      datos: c.datos,
      libroCasaId: casa.id,
      rango: rango,
      transferencias: transferencias,
      subcuentas: subcuentas,
      referencias: referencias,
      duenoId: c.rol == Rol.dueno ? c.personaId : IdsDemostracion.dueno,
      parejaId: c.rol == Rol.coadministrador
          ? c.personaId
          : IdsDemostracion.pareja,
      nombreDe: c.carga.nombreDe,
    );
    String pct(int pb) => '${pb / 100}%';
    return TarjetaModulo(
      key: const ValueKey('reporte-aportacion'),
      titulo: 'Aportación a la casa',
      icono: Icons.home_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DatoConMonto('Gastos de la casa en el periodo', r.totalGastoCasa),
          const Divider(),
          for (final f in r.personas)
            ListTile(
              key: ValueKey('reporte-aporte-${f.clave}'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(f.nombre),
              subtitle: Wrap(
                spacing: 12,
                children: [
                  const Text('Referencia'),
                  Monto(f.referencia),
                  const Text('· Aportado'),
                  Monto(f.aportado),
                ],
              ),
            ),
          for (final s in r.subcuentas)
            ListTile(
              key: ValueKey('reporte-sub-${s.subcuentaId}'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(s.nombre),
              subtitle: Text(
                'Referencia: Papá ${pct(s.reparto.papaPb)} · Dueño '
                '${pct(s.reparto.duenoPb)} · Pareja ${pct(s.reparto.parejaPb)}',
              ),
              trailing: Monto(s.aportadoTotal),
            ),
          const Text(
            'Es una guía: cada quien aporta lo que quiera.',
            key: ValueKey('reporte-aporte-aviso'),
          ),
        ],
      ),
    );
  }
}

class _TarjetaDeudas extends StatelessWidget {
  const _TarjetaDeudas({required this.contexto});

  final ContextoFinanzas contexto;

  @override
  Widget build(BuildContext context) {
    final c = contexto;
    final r = resumenDeDeudas(c.datos, c.libroId, c.hoy);
    final mejor = r.recomendada;
    return TarjetaModulo(
      key: const ValueKey('reporte-deudas'),
      titulo: 'Resumen de deudas',
      icono: Icons.credit_card_outlined,
      child: r.deudas.isEmpty
          ? const Text(
              'Sin deudas con saldo.',
              key: ValueKey('reporte-deudas-vacio'),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DatoConMonto('Saldo total', r.saldoTotal),
                if (!r.saldosConocidos)
                  const Text('Hay deudas sin saldo capturado: no se estiman.'),
                for (final d in r.deudas)
                  ListTile(
                    key: ValueKey('reporte-deuda-${d.id}'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(d.nombre),
                    subtitle: Text(
                      d.tasaAnualPuntosBase == null
                          ? 'Falta la tasa'
                          : 'Tasa anual ${d.tasaAnualPuntosBase! / 100}%',
                    ),
                    trailing: d.saldo == null
                        ? const Text('Falta el saldo')
                        : Monto(d.saldo!),
                  ),
                const Divider(),
                Text(
                  mejor == null
                      ? 'Falta un dato para recomendar una estrategia.'
                      : 'Estrategia recomendada: ${mejor.estrategia.nombre} '
                            '(${mejor.meses} meses)',
                  key: const ValueKey('reporte-deudas-recomendada'),
                ),
                const Text('Es una sugerencia: el pago lo confirmas tú.'),
              ],
            ),
    );
  }
}

class _TarjetaObjetivos extends ConsumerWidget {
  const _TarjetaObjetivos({required this.contexto});

  final ContextoFinanzas contexto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = contexto;
    final permiso = permisoPatrimonio(
      c.permiso,
      c.rol,
      soloLectura: c.soloLecturaTotal,
    );
    if (!permiso.ver) return const SizedBox.shrink();
    final datos = ref.watch(patrimonioDeLibroProvider(c.libroId));
    final avances = datos.hasValue
        ? reporteDeObjetivos(
            datos: c.datos,
            libroId: c.libroId,
            hoy: c.hoy,
            objetivos: datos.value!.objetivos,
          )
        : const <AvanceDeUnObjetivo>[];
    return TarjetaModulo(
      key: const ValueKey('reporte-objetivos'),
      titulo: 'Avance de objetivos',
      icono: Icons.flag_outlined,
      child: avances.isEmpty
          ? const Text(
              'Aún no tienes objetivos.',
              key: ValueKey('reporte-objetivos-vacio'),
            )
          : Column(
              children: [
                for (final a in avances)
                  ListTile(
                    key: ValueKey('reporte-objetivo-${a.objetivo.id}'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(a.objetivo.nombre),
                    subtitle: Text(_textoSemanas(a.avance)),
                    trailing: a.avance.alcanzado
                        ? const Text('Alcanzado')
                        : Wrap(
                            spacing: 4,
                            children: [
                              const Text('Falta'),
                              Monto(a.avance.falta),
                            ],
                          ),
                  ),
              ],
            ),
    );
  }
}

String _textoSemanas(AvanceObjetivo a) {
  if (a.alcanzado) return 'Meta alcanzada';
  final s = a.semanasParaAlcanzar;
  if (s == null) return 'Sin apartado: no se puede estimar';
  final base = s == 1 ? '1 semana' : '$s semanas';
  return switch (a.llegaATiempo) {
    true => '$base · llega a tiempo',
    false => '$base · no llega a la fecha meta',
    null => base,
  };
}
