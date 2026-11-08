/// Gestión de Cuidados (laptop, dueño): medicamentos, citas, turnos y
/// cuidadoras. Todo con permiso de administrar; el servidor lo vuelve a
/// exigir.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/pantallas/marco_pantalla.dart';
import '../../../diseno/diseno.dart';
import '../../../nucleo/contratos/roles.dart';
import '../datos/modelos.dart';
import '../estado/proveedores.dart';
import 'comunes.dart';

class PantallaGestionCuidados extends ConsumerWidget {
  const PantallaGestionCuidados({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(permisosCuidadosProvider);
    return TemaModulo(
      modulo: Modulo.cuidados,
      child: !p.administra
          ? const MarcoPantalla(titulo: 'Cuidados', cuerpo: SinAccesoCuidados())
          : const DefaultTabController(
              length: 4,
              child: MarcoPantalla(
                titulo: 'Cuidados · gestión',
                cuerpo: Column(
                  children: [
                    TabBar(
                      tabs: [
                        Tab(text: 'Medicamentos'),
                        Tab(text: 'Citas'),
                        Tab(text: 'Turnos'),
                        Tab(text: 'Cuidadoras'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _Medicamentos(),
                          _Citas(),
                          _Turnos(),
                          _Cuidadoras(),
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

class _Medicamentos extends ConsumerWidget {
  const _Medicamentos();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    backgroundColor: Colors.transparent,
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _agregar(context, ref),
      icon: const Icon(Icons.add),
      label: const Text('Agregar medicamento'),
    ),
    body: cuando(
      ref.watch(medicamentosProvider),
      () => ref.invalidate(medicamentosProvider),
      (meds) => meds.isEmpty
          ? const EstadoVacio(
              mensaje: 'Sin medicamentos',
              icono: Icons.medication_outlined,
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                for (final m in meds)
                  ListTile(
                    title: Text('${m.nombre} · ${m.dosis}'),
                    subtitle: Text(
                      '${m.horas.join(', ')}${m.activo ? '' : ' · suspendido'}',
                    ),
                    trailing: Switch(
                      value: m.activo,
                      onChanged: (v) => ejecutarCuidados(
                        context,
                        ref,
                        () => ref
                            .read(servicioCuidadosProvider)
                            .guardarMedicamento(m.copiarCon(activo: v)),
                        ok: 'Guardado',
                      ),
                    ),
                  ),
              ],
            ),
    ),
  );

  Future<void> _agregar(BuildContext context, WidgetRef ref) async {
    final nombre = TextEditingController();
    final dosis = TextEditingController();
    final horas = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Agregar medicamento'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombre,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            TextField(
              controller: dosis,
              decoration: const InputDecoration(labelText: 'Dosis'),
            ),
            TextField(
              controller: horas,
              decoration: const InputDecoration(
                labelText: 'Horas (08:00, 20:00)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final lista = [
      for (final h in horas.text.split(','))
        if (RegExp(r'^\d{1,2}:\d{2}$').hasMatch(h.trim()))
          h.trim().padLeft(5, '0'),
    ];
    if (nombre.text.trim().isEmpty || lista.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Escribe el nombre y al menos una hora, como 08:00.'),
        ),
      );
      return;
    }
    await ejecutarCuidados(
      context,
      ref,
      () => ref
          .read(servicioCuidadosProvider)
          .guardarMedicamento(
            Medicamento(
              id: idNuevoCuidados(),
              nombre: nombre.text.trim(),
              dosis: dosis.text.trim(),
              horas: lista..sort(),
            ),
          ),
      ok: 'Guardado',
    );
  }
}

class _Citas extends ConsumerWidget {
  const _Citas();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    backgroundColor: Colors.transparent,
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _agregar(context, ref),
      icon: const Icon(Icons.add),
      label: const Text('Agregar cita'),
    ),
    body: cuando(
      ref.watch(citasProvider),
      () => ref.invalidate(citasProvider),
      (citas) => citas.isEmpty
          ? const EstadoVacio(mensaje: 'Sin citas', icono: Icons.event_outlined)
          : ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                for (final c in citas)
                  ListTile(
                    leading: const Icon(Icons.event_outlined),
                    title: Text(c.nota ?? c.lugar ?? 'Cita'),
                    subtitle: Text(
                      '${diaLargo(c.programadaEn)} · ${horaTexto(c.programadaEn)}'
                      '${c.lugar != null && c.nota != null ? ' · ${c.lugar}' : ''}',
                    ),
                  ),
              ],
            ),
    ),
  );

  Future<void> _agregar(BuildContext context, WidgetRef ref) async {
    final texto = TextEditingController();
    final lugar = TextEditingController();
    final ahora = ref.read(relojDeCuidados);
    var cuando = DateTime(ahora.year, ahora.month, ahora.day + 1, 10);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Agregar cita'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: texto,
                decoration: const InputDecoration(labelText: 'Cita'),
              ),
              TextField(
                controller: lugar,
                decoration: const InputDecoration(
                  labelText: 'Lugar (opcional)',
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today),
                label: Text('${diaLargo(cuando)} · ${horaTexto(cuando)}'),
                onPressed: () async {
                  final f = await showDatePicker(
                    context: ctx,
                    initialDate: cuando,
                    firstDate: soloFecha(ahora),
                    lastDate: soloFecha(ahora).add(const Duration(days: 730)),
                  );
                  if (f != null) {
                    setS(
                      () => cuando = DateTime(
                        f.year,
                        f.month,
                        f.day,
                        cuando.hour,
                        cuando.minute,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    await ejecutarCuidados(
      context,
      ref,
      () => ref
          .read(servicioCuidadosProvider)
          .agregarCita(texto.text, cuando, lugar: lugar.text),
      ok: 'Guardado',
    );
  }
}

class _Turnos extends ConsumerWidget {
  const _Turnos();

  @override
  Widget build(BuildContext context, WidgetRef ref) => cuando(
    ref.watch(turnosSemanaProvider),
    () => ref.invalidate(turnosSemanaProvider),
    (turnos) => turnos.isEmpty
        ? const EstadoVacio(
            mensaje: 'Sin turnos esta semana',
            icono: Icons.calendar_month_outlined,
          )
        : ListView(
            children: [
              for (final t in turnos)
                ListTile(
                  leading: Icon(
                    t.tipo == TipoTurno.visita
                        ? Icons.person_outline
                        : Icons.assignment_ind_outlined,
                  ),
                  title: Text('${diaLargo(t.inicio)} · ${t.horario}'),
                  subtitle: Text(
                    '${t.nombre}${t.tipo == TipoTurno.visita ? ' (visita)' : ''}',
                  ),
                ),
            ],
          ),
  );
}

class _Cuidadoras extends ConsumerWidget {
  const _Cuidadoras();

  @override
  Widget build(BuildContext context, WidgetRef ref) => cuando(
    ref.watch(turnosSemanaProvider),
    () => ref.invalidate(turnosSemanaProvider),
    (turnos) {
      final personas = <String, String>{
        for (final t in turnos) t.personaId: t.nombre,
      };
      return ListView(
        children: [
          for (final e in personas.entries)
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(e.value),
            ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Altas y bajas'),
            subtitle: Text(
              'Se hacen en Ajustes › Personas y roles. Una baja corta el acceso de inmediato.',
            ),
          ),
        ],
      );
    },
  );
}
