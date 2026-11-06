/// Hoy de Hábitos (laptop y teléfono): tarjeta *Sigue*, lista con hecho /
/// posponer / omitir y Deshacer, y el botón Pausa siempre visible.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/pantallas/marco_pantalla.dart';
import '../../../diseno/diseno.dart';
import '../../../nucleo/contratos/roles.dart';
import '../../../nucleo/contratos/rutas.dart';
import '../casos_uso/servicio_habitos.dart';
import '../datos/modelos.dart';
import '../estado/proveedores.dart';

EstadoFila _estadoFila(EstadoRegistro e) => switch (e) {
  EstadoRegistro.pendiente => EstadoFila.pendiente,
  EstadoRegistro.hecho => EstadoFila.hecho,
  EstadoRegistro.parcial => EstadoFila.parcial,
  EstadoRegistro.omitido => EstadoFila.omitido,
  EstadoRegistro.pospuesto => EstadoFila.pospuesto,
};

class PantallaHoyHabitos extends ConsumerWidget {
  const PantallaHoyHabitos({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => TemaModulo(
    modulo: Modulo.habitos,
    child: MarcoPantalla(
      titulo: 'Hábitos · Hoy',
      acciones: [
        IconButton(
          tooltip: 'Objetivos',
          icon: const Icon(Icons.flag_outlined),
          onPressed: () => context.go('${Rutas.habitos}/objetivos'),
        ),
      ],
      cuerpo: const _CuerpoHoy(),
    ),
  );
}

class _CuerpoHoy extends ConsumerWidget {
  const _CuerpoHoy();

  Future<void> _accion(
    BuildContext context,
    WidgetRef ref,
    ItemHoy i,
    Future<void> Function(ServicioHabitos s) hacer,
    String texto,
  ) async {
    final s = ref.read(servicioHabitosProvider);
    await hacer(s);
    ref.read(versionHabitosProvider.notifier).state++;
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(texto),
          action: SnackBarAction(
            label: 'Deshacer',
            onPressed: () async {
              await s.deshacer(i.objetivo);
              ref.read(versionHabitosProvider.notifier).state++;
            },
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hoy = ref.watch(hoyHabitosProvider);
    return hoy.when(
      loading: () => const EstadoCargando(),
      error: (e, _) => EstadoError(
        mensaje: 'No pudimos cargar tu día.',
        alReintentar: () => ref.invalidate(hoyHabitosProvider),
      ),
      data: (items) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (items.isEmpty) ...[
            const _AvisoRevision(),
            EstadoVacioHabitos(
              tipo: VacioHabitos.sinObjetivos,
              textoAccion: 'Crear un objetivo',
              alAccionar: () => context.go('${Rutas.habitos}/objetivos'),
            ),
          ] else ...[
            const _AvisoRevision(),
            const _CargaHoy(),
            _Sigue(items: items),
            for (final i in items)
              FilaHabito(
                titulo: i.objetivo.titulo,
                detalle: i.objetivo.metaValor == null
                    ? null
                    : '${i.objetivo.metaValor} ${i.objetivo.unidad ?? ''}'
                          .trim(),
                estado: _estadoFila(i.estado),
                racha: i.racha.actual > 0 ? i.racha.actual : null,
                alHecho: () => _accion(
                  context,
                  ref,
                  i,
                  (s) => s.marcarHecho(i.objetivo),
                  'Hecho',
                ),
                alPosponer: () => _accion(
                  context,
                  ref,
                  i,
                  (s) => s.posponer(i.objetivo, aMin: _ahoraMin() + 60),
                  'Pospuesto una hora',
                ),
                alOmitir: () => _accion(
                  context,
                  ref,
                  i,
                  (s) => s.omitir(i.objetivo),
                  'Omitido',
                ),
              ),
          ],
          ListTile(
            leading: const Icon(Icons.auto_stories_outlined),
            title: const Text('Espiritual'),
            onTap: () => context.go('${Rutas.habitos}/espiritual'),
          ),
          ListTile(
            leading: const Icon(Icons.insights_outlined),
            title: const Text('Progreso'),
            onTap: () => context.go('${Rutas.habitos}/progreso'),
          ),
          ListTile(
            leading: const Icon(Icons.calendar_today_outlined),
            title: const Text('Agenda'),
            onTap: () => context.go('${Rutas.habitos}/agenda'),
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Reservado'),
            onTap: () => context.go('${Rutas.habitos}/reservado'),
          ),
          const SizedBox(height: 16),
          BotonPausa(
            expandido: true,
            alTocar: () => context.go('${Rutas.habitos}/sos'),
          ),
        ],
      ),
    );
  }

  static int _ahoraMin() {
    final n = DateTime.now();
    return n.hour * 60 + n.minute;
  }
}

class _Sigue extends StatelessWidget {
  const _Sigue({required this.items});
  final List<ItemHoy> items;

  @override
  Widget build(BuildContext context) {
    final pend = [
      for (final i in items)
        if (!i.hecho && i.estado != EstadoRegistro.omitido) i,
    ];
    if (pend.isEmpty) return const SizedBox.shrink();
    final i = pend.first;
    return TarjetaSigue(titulo: i.objetivo.titulo, horaTexto: 'Hoy');
  }
}

class _CargaHoy extends ConsumerWidget {
  const _CargaHoy();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(cargaHoyProvider).value;
    if (c == null || c.programados == 0) return const SizedBox.shrink();
    return MedidorCarga(planeadosMin: c.programados, disponiblesMin: c.libres);
  }
}

/// Aviso de la revisión semanal en Hoy (E12): aparece desde la hora del aviso
/// y hasta que se cierre, se omita o pase el miércoles. Un toque la abre; sin
/// culpa ni racha de revisiones.
class _AvisoRevision extends ConsumerWidget {
  const _AvisoRevision();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!(ref.watch(revisionPendienteProvider).value ?? false))
      return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: ListTile(
          leading: const Icon(Icons.rate_review_outlined),
          title: const Text('Es hora de tu revisión semanal'),
          subtitle: const Text('Lleva unos minutos. Hay una versión corta.'),
          trailing: FilledButton(
            onPressed: () => context.go('${Rutas.habitos}/revision'),
            child: const Text('Empezar'),
          ),
        ),
      ),
    );
  }
}
