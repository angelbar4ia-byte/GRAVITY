/// Agenda del día con bloques, huecos y carga (reglas 63 a 67).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;
import 'package:go_router/go_router.dart';
import 'package:habitos_dominio/habitos_dominio.dart';

import '../../../app/pantallas/marco_pantalla.dart';
import '../../../diseno/diseno.dart';
import '../../../nucleo/contratos/roles.dart';
import '../../../nucleo/contratos/rutas.dart';
import '../casos_uso/servicio_agenda.dart';
import '../estado/proveedores.dart';
import 'edicion.dart';

String horaTexto(int min) =>
    '${(min ~/ 60).toString().padLeft(2, '0')}:${(min % 60).toString().padLeft(2, '0')}';

final _diaAgendaProvider = StateProvider<DateTime>(
  (ref) => soloDia(DateTime.now()),
);

class PantallaAgenda extends ConsumerWidget {
  const PantallaAgenda({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(_diaAgendaProvider);
    final bloques = ref.watch(bloquesDelDiaProvider(f));
    return TemaModulo(
      modulo: Modulo.habitos,
      child: MarcoPantalla(
        titulo: 'Agenda',
        rutaAnterior: Rutas.habitos,
        acciones: [
          IconButton(
            tooltip: 'Asistente de configuración',
            icon: const Icon(Icons.tune),
            onPressed: () => context.go('${Rutas.habitos}/asistente'),
          ),
        ],
        cuerpo: Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            icon: const Icon(Icons.add),
            label: const Text('Nuevo bloque'),
            onPressed: () => mostrarHojaInferior(
              context,
              titulo: 'Nuevo bloque',
              child: const _NuevoBloque(),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Día anterior',
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () =>
                        ref.read(_diaAgendaProvider.notifier).state = sumarDias(
                          f,
                          -1,
                        ),
                  ),
                  Expanded(
                    child: Text(
                      '${f.day}/${f.month}/${f.year}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Día siguiente',
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () =>
                        ref.read(_diaAgendaProvider.notifier).state = sumarDias(
                          f,
                          1,
                        ),
                  ),
                ],
              ),
              _Carga(fecha: f),
              bloques.when(
                loading: () => const EstadoCargando(),
                error: (_, _) => EstadoError(
                  mensaje: 'No pudimos cargar la agenda.',
                  alReintentar: () => ref.invalidate(bloquesDelDiaProvider(f)),
                ),
                data: (l) => l.isEmpty
                    ? const EstadoVacioHabitos(tipo: VacioHabitos.hoyLibre)
                    : Column(
                        children: [
                          for (final o in l) _FilaBloque(o: o, fecha: f),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Carga extends ConsumerWidget {
  const _Carga({required this.fecha});
  final DateTime fecha;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      FutureBuilder<CargaDelDia>(
        future: ref.watch(servicioAgendaProvider).carga(fecha),
        builder: (_, s) => s.data == null
            ? const SizedBox.shrink()
            : MedidorCarga(
                planeadosMin: s.data!.programados,
                disponiblesMin: s.data!.libres,
              ),
      );
}

class _FilaBloque extends ConsumerWidget {
  const _FilaBloque({required this.o, required this.fecha});
  final OcurrenciaBloque o;
  final DateTime fecha;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = o.bloque;
    final s = ref.read(servicioAgendaProvider);
    void refrescar() => ref.read(versionHabitosProvider.notifier).state++;
    if (b.fijo) {
      return ListTile(
        leading: const Icon(Icons.work_outline),
        title: Text(b.titulo),
        subtitle: Text(
          '${horaTexto(b.inicioMin)} · ${b.duracionMin} min · fijo',
        ),
        trailing: IconButton(
          tooltip: 'Editar ${b.titulo}',
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => editarBloqueEnHoja(context, b),
        ),
      );
    }
    final fila = FilaHabito(
      titulo: b.titulo,
      horaTexto: horaTexto(o.inicioMin),
      detalle: '${b.duracionMin} min · ${b.area}',
      estado: EstadoFila.values.byName(o.estado.name),
      alHecho: () async {
        await s.marcarHecho(b, fecha: fecha);
        refrescar();
      },
      alPosponer: () async {
        await s.posponer(b, o.inicioMin + 60, fecha: fecha);
        refrescar();
      },
      alOmitir: () async {
        await s.omitir(b, fecha: fecha);
        refrescar();
      },
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        fila,
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: Text('Editar ${b.titulo}'),
            onPressed: () => editarBloqueEnHoja(context, b),
          ),
        ),
      ],
    );
  }
}

class _NuevoBloque extends ConsumerStatefulWidget {
  const _NuevoBloque();
  @override
  ConsumerState<_NuevoBloque> createState() => _NuevoBloqueEstado();
}

class _NuevoBloqueEstado extends ConsumerState<_NuevoBloque> {
  final titulo = TextEditingController();
  final duracion = TextEditingController(text: '30');
  TimeOfDay hora = const TimeOfDay(hour: 20, minute: 0);
  String? aviso;

  @override
  void dispose() {
    titulo.dispose();
    duracion.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final s = ref.read(servicioAgendaProvider);
    try {
      final b = await s.crearBloque(
        titulo: titulo.text,
        area: 'personal',
        inicioMin: hora.hour * 60 + hora.minute,
        duracionMin: int.tryParse(duracion.text) ?? 30,
        desde: ref.read(_diaAgendaProvider),
      );
      final c = await s.conflictosDe(b);
      ref.read(versionHabitosProvider.notifier).state++;
      if (c.isNotEmpty && mounted) {
        // El aviso no impide guardar (regla 67).
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Se cruza con: ${c.map((x) => x.titulo).join(', ')}'),
          ),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } on ArgumentError catch (e) {
      setState(() => aviso = e.message.toString());
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: titulo,
          decoration: const InputDecoration(labelText: 'Nombre'),
        ),
        ListTile(
          title: const Text('Hora'),
          subtitle: Text(hora.format(context)),
          onTap: () async {
            final h = await showTimePicker(context: context, initialTime: hora);
            if (h != null) setState(() => hora = h);
          },
        ),
        TextField(
          controller: duracion,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Minutos'),
        ),
        if (aviso != null) Text(aviso!),
        const SizedBox(height: 12),
        FilledButton(onPressed: _guardar, child: const Text('Guardar')),
      ],
    ),
  );
}
