/// Objetivos: lista y asistente SMART resumido (5 pasos en una hoja).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habitos_dominio/habitos_dominio.dart';

import '../../../app/pantallas/marco_pantalla.dart';
import '../../../diseno/diseno.dart';
import '../../../nucleo/contratos/roles.dart';
import '../../../nucleo/contratos/rutas.dart';
import '../estado/proveedores.dart';
import 'edicion.dart';

final _objetivosProvider = FutureProvider((ref) async {
  ref.watch(versionHabitosProvider);
  final os = await ref.watch(repositorioHabitosProvider).objetivos();
  final av = await ref.watch(servicioHabitosProvider).avances([
    for (final o in os)
      if (o.activo) o,
  ]);
  return (os, av);
});

class PantallaObjetivos extends ConsumerWidget {
  const PantallaObjetivos({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => TemaModulo(
    modulo: Modulo.habitos,
    child: MarcoPantalla(
      titulo: 'Objetivos',
      rutaAnterior: Rutas.habitos,
      cuerpo: ref
          .watch(_objetivosProvider)
          .when(
            loading: () => const EstadoCargando(),
            error: (_, _) => EstadoError(
              mensaje: 'No pudimos cargar tus objetivos.',
              alReintentar: () => ref.invalidate(_objetivosProvider),
            ),
            data: (datos) {
              final (l, avances) = datos;
              final activos = l.where((o) => o.activo).toList();
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Nuevo objetivo'),
                    onPressed: () => mostrarHojaInferior(
                      context,
                      titulo: 'Nuevo objetivo',
                      child: const _AsistenteSmart(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (activos.isEmpty)
                    const EstadoVacioHabitos(tipo: VacioHabitos.sinObjetivos),
                  for (final o in activos)
                    TarjetaObjetivo(
                      titulo: o.titulo,
                      area: o.area,
                      avance: avances[o.id] ?? 0,
                      avanceTexto:
                          '${((avances[o.id] ?? 0) * 100).round()} % esta semana',
                      alTocar: () => editarObjetivoEnHoja(context, o),
                      ritmoTexto: o.metaValor == null
                          ? null
                          : '${o.metaValor} ${o.unidad ?? ''}'.trim(),
                    ),
                ],
              );
            },
          ),
    ),
  );
}

class _AsistenteSmart extends ConsumerStatefulWidget {
  const _AsistenteSmart();
  @override
  ConsumerState<_AsistenteSmart> createState() => _AsistenteSmartEstado();
}

class _AsistenteSmartEstado extends ConsumerState<_AsistenteSmart> {
  int paso = 0;
  final titulo = TextEditingController();
  final unidad = TextEditingController();
  final meta = TextEditingController();
  final motivo = TextEditingController();
  String area = 'personal';
  String? error;

  @override
  void dispose() {
    titulo.dispose();
    unidad.dispose();
    meta.dispose();
    motivo.dispose();
    super.dispose();
  }

  Future<void> _crear() async {
    try {
      await ref
          .read(servicioHabitosProvider)
          .crearObjetivo(
            titulo: titulo.text,
            area: area,
            unidad: unidad.text.isEmpty ? null : unidad.text,
            metaValor: int.tryParse(meta.text),
            motivo: motivo.text.isEmpty ? null : motivo.text,
          );
      ref.read(versionHabitosProvider.notifier).state++;
      if (mounted) Navigator.of(context).pop();
    } on ArgumentError catch (e) {
      setState(() => error = e.message.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = pasosSmart[paso];
    final campo = switch (paso) {
      0 => Column(
        children: [
          TextField(
            controller: titulo,
            decoration: const InputDecoration(
              labelText: '¿Qué quieres lograr?',
            ),
          ),
          DropdownButtonFormField<String>(
            initialValue: area,
            items: [
              for (final a in [
                'espiritual',
                'salud',
                'educacion',
                'personal',
                'laboral',
                'proyectos',
              ])
                DropdownMenuItem(value: a, child: Text(a)),
            ],
            onChanged: (v) => setState(() => area = v ?? area),
          ),
        ],
      ),
      1 => Column(
        children: [
          TextField(
            controller: unidad,
            decoration: const InputDecoration(
              labelText: 'Unidad (minutos, páginas…)',
            ),
          ),
          TextField(
            controller: meta,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Meta por vez (opcional)',
            ),
          ),
        ],
      ),
      2 => const Text('Empieza con algo pequeño: todos los días, un poco.'),
      3 => TextField(
        controller: motivo,
        maxLength: 200,
        decoration: const InputDecoration(
          labelText: '¿Por qué es importante? (opcional)',
        ),
      ),
      _ => const Text('Empieza hoy. Puedes cambiar la fecha después.'),
    };
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Paso ${paso + 1} de ${pasosSmart.length}: ${p.titulo}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          campo,
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(error!),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (paso > 0)
                TextButton(
                  onPressed: () => setState(() => paso--),
                  child: const Text('Atrás'),
                ),
              const Spacer(),
              FilledButton(
                onPressed: paso < pasosSmart.length - 1
                    ? () => setState(() => paso++)
                    : _crear,
                child: Text(
                  paso < pasosSmart.length - 1 ? 'Siguiente' : 'Crear',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
