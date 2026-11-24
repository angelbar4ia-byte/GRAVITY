/// E3 · Plan de la semana: 3, 4 o 5 días, versión y hora de cada día, ventana,
/// el aviso de las 48 horas y *Poner en mi agenda* (7.1, 5.6 y 8.1).
///
/// El plan **propone y la persona confirma**; un conflicto avisa y no impide
/// guardar. La regla de las 48 horas avisa, nunca bloquea.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habitos_dominio/habitos_dominio.dart' hide EstadoDiaPlan;

import '../../../../app/gimnasio/acceso_gimnasio.dart';
import '../../../../diseno/gimnasio/gimnasio.dart';
import '../../../../diseno/valores_diseno.dart';
import '../../estado/proveedores.dart' show versionHabitosProvider;
import '../casos_uso/servicio_gimnasio.dart';
import '../datos/modelos_gimnasio.dart';
import '../estado/proveedores_gimnasio.dart';
import 'comun.dart';
import 'hoy_gimnasio.dart' show diasDeLaSemana;

/// El plan de esta semana con sus horas y los avisos de 48 horas.
class PlanVista {
  const PlanVista({required this.entrenamientos, required this.avisos});

  /// Por día de la semana (1 a 7), solo los que son sesión.
  final Map<int, EntrenamientoHoy> entrenamientos;
  final List<AvisoSemana> avisos;

  Set<int> get diasConAviso => {
    for (final a in avisos) ...[a.a.inicio.weekday, a.b.inicio.weekday],
  };
}

const _gruposTexto = {
  'pecho': 'pecho',
  'espalda': 'espalda',
  'hombro': 'hombro',
  'triceps': 'tríceps',
  'biceps': 'bíceps',
  'cuadriceps': 'cuádriceps',
  'gluteo': 'glúteo',
  'core': 'core',
};

String _nombreSesion(String tipo) =>
    tipo == TipoDia.bici ? 'la bicicleta' : 'Fuerza $tipo';

/// El aviso de 48 horas ya redactado, sin culpa y con lo que se puede hacer.
String textoAvisoSemana(AvisoSemana a) {
  if (a.tipo == TipoAvisoSemana.mismoDia) {
    return 'Hay dos sesiones de fuerza el mismo día. Mejor en días distintos.';
  }
  final h = a.intervaloMin ~/ 60;
  final m = a.intervaloMin % 60;
  final grupos = [for (final g in a.grupos) _gruposTexto[g] ?? g].join(' y ');
  final propuestas = <String>[];
  for (final p in a.propuestas) {
    propuestas.add(switch (p) {
      AccionSemana.masTarde =>
        'Mejor empezar ${a.faltanMin} min más tarde.',
      AccionSemana.otroDia => 'Mejor en otro día.',
      AccionSemana.moverAlJueves => 'Puedes mover la pierna al jueves.',
      AccionSemana.versionCorta => 'Puedes hacerla en versión corta.',
      AccionSemana.dejarComoEsta => 'O dejarlo como está.',
    });
  }
  return '${_nombreSesion(a.a.tipo)} y ${_nombreSesion(a.b.tipo)} comparten '
      '$grupos, con $h h $m min entre una y otra. ${propuestas.join(' ')}';
}

final planVistaProvider = FutureProvider<PlanVista?>((ref) async {
  ref.watch(versionGimnasioProvider);
  ref.watch(versionHabitosProvider);
  final s = ref.watch(servicioGimnasioProvider);
  if (s == null) return null;
  final d = await s.cargar();
  final hoy = ref.watch(fechaDeHoyGimnasioProvider);
  final lunes = lunesDe(hoy);
  final entrenamientos = <int, EntrenamientoHoy>{};
  final programadas = <SesionProgramada>[];
  for (final dia in d.dias) {
    final fecha = sumarDias(lunes, dia.diaSemana - 1);
    if (dia.esSesion) {
      final h = await s.entrenamientoDe(fecha, datos: d);
      entrenamientos[dia.diaSemana] = h;
      if (dia.esFuerza && h.inicioMin != null) {
        programadas.add(
          SesionProgramada(
            dia.tipo,
            DateTime.utc(
              fecha.year,
              fecha.month,
              fecha.day,
              h.inicioMin! ~/ 60,
              h.inicioMin! % 60,
            ),
          ),
        );
      }
    } else if (dia.tipo == TipoDia.bici) {
      final min = dia.horaMin ?? 8 * 60;
      programadas.add(
        SesionProgramada(
          dia.tipo,
          DateTime.utc(fecha.year, fecha.month, fecha.day, min ~/ 60, min % 60),
        ),
      );
    }
  }
  return PlanVista(
    entrenamientos: entrenamientos,
    avisos: revisarSemana(programadas, s.catalogo, reglas: s.reglas),
  );
});

class PantallaPlan extends ConsumerWidget {
  const PantallaPlan({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicio = ref.watch(servicioGimnasioProvider);
    return MarcoGimnasio(
      destino: DestinoGimnasio.plan,
      cuerpo: servicio == null
          ? const SinPersonaGimnasio()
          : vistaAsincrona<DatosGimnasio?>(
              ref.watch(datosGimnasioProvider),
              alReintentar: () => ref.invalidate(datosGimnasioProvider),
              listo: (d) => d == null
                  ? const SinPersonaGimnasio()
                  : _CuerpoPlan(datos: d, servicio: servicio),
            ),
    );
  }
}

class _CuerpoPlan extends ConsumerWidget {
  const _CuerpoPlan({required this.datos, required this.servicio});

  final DatosGimnasio datos;
  final ServicioGimnasio servicio;

  void _recargar(WidgetRef ref) {
    ref.read(versionGimnasioProvider.notifier).state++;
    ref.read(versionHabitosProvider.notifier).state++;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ValoresDiseno.de(context);
    final gap = SizedBox(height: v.espacio * 2);
    final hoy = ref.watch(fechaDeHoyGimnasioProvider);
    final plan = ref.watch(planVistaProvider);
    final vista = plan.value;
    final ciclo = semanaDelCiclo(
      hoy: hoy,
      inicioCiclo: datos.perfil.inicioCiclo,
      cicloSemanas: datos.perfil.cicloSemanas,
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Días de fuerza y descanso activo', style: v.titulo(tamano: 16)),
        const SizedBox(height: 8),
        SegmentedButton<int>(
          key: const ValueKey('plan-dias'),
          segments: const [
            ButtonSegment(value: 3, label: Text('3 días')),
            ButtonSegment(value: 4, label: Text('4 días')),
            ButtonSegment(value: 5, label: Text('5 días')),
          ],
          selected: {datos.perfil.diasPlan},
          onSelectionChanged: (s) async {
            await servicio.elegirDiasDelPlan(datos, s.first);
            _recargar(ref);
          },
        ),
        gap,
        LineaSemana(
          titulo: 'Plan de ${datos.perfil.diasPlan} días',
          dias: diasDeLaSemana(
            datos: datos,
            hoy: hoy,
            catalogo: servicio.catalogo,
            conAviso: vista?.diasConAviso ?? const {},
          ),
          avisos: [for (final a in vista?.avisos ?? const []) textoAvisoSemana(a)],
          alTocarDia: (i) => _editarDia(context, ref, datos.dia(i + 1)),
        ),
        if (ciclo != null) ...[
          const SizedBox(height: 8),
          Text(
            datos.perfil.cicloSemanas == 0
                ? 'Semana ${ciclo.numero} del plan · sin descarga programada'
                : 'Semana ${ciclo.numero} de ${datos.perfil.cicloSemanas} · '
                      '${ciclo.descarga ? 'descarga' : 'carga'}',
            style: v.lectura(tamano: 14),
          ),
        ],
        gap,
        Text('¿Cuándo prefieres entrenar?', style: v.titulo(tamano: 16)),
        const SizedBox(height: 8),
        SelectorVentana(
          datos: datos,
          alElegir: (venta) async {
            await servicio.guardarPerfil({'ventana': venta.id});
            _recargar(ref);
          },
        ),
        gap,
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (!datos.planIniciado)
              FilledButton.icon(
                key: const ValueKey('plan-empezar'),
                onPressed: () async {
                  await servicio.iniciarPlan();
                  _recargar(ref);
                },
                icon: const Icon(Icons.flag_outlined),
                label: const Text(TextosHabitosGimnasio.empezarPlan),
              ),
            OutlinedButton.icon(
              key: const ValueKey('plan-agenda'),
              onPressed: () async {
                final r = await servicio.ponerEnMiAgenda(datos);
                _recargar(ref);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context)
                  ..clearSnackBars()
                  ..showSnackBar(
                    SnackBar(
                      content: Text(
                        r.conflictos.isEmpty
                            ? TextosHabitosGimnasio.agendaListo
                            : TextosHabitosGimnasio.agendaConflicto,
                      ),
                    ),
                  );
              },
              icon: const Icon(Icons.event_available_outlined),
              label: const Text(TextosHabitosGimnasio.ponerEnAgenda),
            ),
          ],
        ),
        gap,
        const Text(MensajesGimnasio.guiaGeneral),
        gap,
        const TarjetaContenidoEnRevision(compacta: true),
      ],
    );
  }

  Future<void> _editarDia(
    BuildContext context,
    WidgetRef ref,
    DiaDelPlan dia,
  ) async {
    if (!dia.esSesion && dia.tipo != TipoDia.bici) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _HojaDia(
        dia: dia,
        alGuardar: (version, hora, quitarHora) async {
          await servicio.guardarDiaDelPlan(
            dia,
            version: version,
            horaMin: hora,
            quitarHora: quitarHora,
          );
          _recargar(ref);
        },
      ),
    );
  }
}

/// «¿Cuándo prefieres entrenar?»: noche, mañana o flexible (5.13).
class SelectorVentana extends StatelessWidget {
  const SelectorVentana({
    super.key,
    required this.datos,
    required this.alElegir,
  });

  final DatosGimnasio datos;
  final ValueChanged<VentanaEntrenamiento> alElegir;

  @override
  Widget build(BuildContext context) => SegmentedButton<VentanaEntrenamiento>(
    key: const ValueKey('plan-ventana'),
    segments: const [
      ButtonSegment(value: VentanaEntrenamiento.noche, label: Text('Noche')),
      ButtonSegment(value: VentanaEntrenamiento.manana, label: Text('Mañana')),
      ButtonSegment(
        value: VentanaEntrenamiento.flexible,
        label: Text('Flexible'),
      ),
    ],
    selected: {datos.perfil.ventana},
    onSelectionChanged: (s) => alElegir(s.first),
  );
}

class _HojaDia extends StatefulWidget {
  const _HojaDia({required this.dia, required this.alGuardar});

  final DiaDelPlan dia;
  final Future<void> Function(String? version, int? hora, bool quitarHora)
  alGuardar;

  @override
  State<_HojaDia> createState() => _EstadoHojaDia();
}

class _EstadoHojaDia extends State<_HojaDia> {
  late String _version = widget.dia.version;

  Future<void> _elegirHora() async {
    final h = widget.dia.horaMin;
    final t = await showTimePicker(
      context: context,
      initialTime: h == null
          ? const TimeOfDay(hour: 19, minute: 15)
          : TimeOfDay(hour: h ~/ 60, minute: h % 60),
    );
    if (t == null) return;
    await widget.alGuardar(null, t.hour * 60 + t.minute, false);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${nombreDeDia(widget.dia.diaSemana)} · '
          '${tipoDiaPlan(widget.dia.tipo).texto}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (widget.dia.esFuerza) ...[
          const SizedBox(height: 12),
          const Text('Versión'),
          Wrap(
            spacing: 8,
            children: [
              for (final id in const ['auto', 'corta', 'estandar', 'larga'])
                ChoiceChip(
                  key: ValueKey('version-$id'),
                  label: Text(textoVersionId(id)),
                  selected: _version == id,
                  onSelected: (_) async {
                    setState(() => _version = id);
                    await widget.alGuardar(id, null, false);
                  },
                ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              key: const ValueKey('dia-hora'),
              onPressed: _elegirHora,
              icon: const Icon(Icons.schedule),
              label: Text(
                widget.dia.horaMin == null
                    ? 'Elegir la hora'
                    : 'Hora: ${horaTexto(widget.dia.horaMin!)}',
              ),
            ),
            if (widget.dia.horaMin != null)
              TextButton(
                onPressed: () async {
                  await widget.alGuardar(null, null, true);
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Que la app proponga la hora'),
              ),
          ],
        ),
      ],
    ),
  );
}
