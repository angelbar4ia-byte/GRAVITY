/// Plan familiar por votación (D28; Fase 7, decisión 5): una persona propone
/// un menú, otra da el suyo y se vota un día. Se puede cambiar el voto mientras
/// la votación esté abierta; un empate al cierre lo resuelve el servidor por
/// volado. Pantalla sencilla, igual en la laptop y el teléfono.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/pantallas/marco_pantalla.dart';
import '../../../app/sesion_efectiva.dart';
import '../../../diseno/diseno.dart';
import '../../../nucleo/contratos/roles.dart';
import '../../../nucleo/contratos/rutas.dart';
import '../casos_uso/plan_familiar.dart';
import '../datos/modelos.dart';
import '../estado/proveedores.dart';
import 'hay_presupuesto.dart';

String _fecha(DateTime d) => '${diasSemana[d.weekday - 1]} ${d.day}/${d.month}';

class PantallaPlanFamiliar extends ConsumerWidget {
  const PantallaPlanFamiliar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final srv = ref.watch(servicioPlanFamiliarProvider);
    final dia = ref.watch(diaPlanProvider);
    return TemaModulo(
      modulo: Modulo.alimentacion,
      child: MarcoPantalla(
        titulo: 'Plan familiar',
        rutaAnterior: Rutas.alimentacion,
        cuerpo: !srv.puedeVer
            ? const EstadoVacio(
                mensaje: 'No tienes acceso al plan familiar',
                icono: Icons.lock_outline,
              )
            : ref.watch(alimentacionSinServidorProvider)
            ? const EstadoVacio(
                mensaje: 'Sin plan todavía',
                detalle:
                    'El plan familiar aparecerá cuando Alimentación esté activa en tu hogar.',
                icono: Icons.how_to_vote_outlined,
              )
            : Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        tooltip: 'Día anterior',
                        onPressed: () => ref.read(diaPlanProvider.notifier).state =
                            dia.subtract(const Duration(days: 1)),
                      ),
                      Expanded(
                        child: Text(
                          _fecha(dia),
                          textAlign: TextAlign.center,
                          style: ValoresDiseno.de(context).titulo(
                            tamano: 18,
                            color: ValoresDiseno.de(context).textoFuerte,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        tooltip: 'Día siguiente',
                        onPressed: () => ref.read(diaPlanProvider.notifier).state =
                            dia.add(const Duration(days: 1)),
                      ),
                    ],
                  ),
                  Expanded(
                    child: ref
                        .watch(votacionPlanProvider)
                        .when(
                          loading: () => const EstadoCargando(),
                          error: (_, _) => EstadoError(
                            mensaje: 'No pudimos cargar la votación.',
                            alReintentar: () =>
                                ref.invalidate(votacionPlanProvider),
                          ),
                          data: (vot) => _Votacion(votacion: vot, dia: dia),
                        ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _Votacion extends ConsumerWidget {
  const _Votacion({required this.votacion, required this.dia});
  final VotacionPlan? votacion;
  final DateTime dia;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ValoresDiseno.de(context);
    final srv = ref.watch(servicioPlanFamiliarProvider);
    final ahora = ref.watch(relojProvider).ahora();
    final yo = ref.watch(sesionEfectivaProvider)?.persona.id;
    final vot = votacion;
    final estado = vot?.estado(ahora);
    final nombresPlatillos = ref
        .watch(platillosProvider)
        .maybeWhen(
          data: (l) => {for (final p in l) p.id: p.nombre},
          orElse: () => <String, String>{},
        );

    String aviso() {
      if (vot == null) return 'Nadie ha propuesto un menú para este día.';
      return switch (estado!) {
        EstadoVotacion.faltaPropuesta =>
          'Falta la segunda propuesta, de otra persona.',
        EstadoVotacion.enCurso =>
          vot.hayEmpate
              ? 'Votación abierta, van empatadas. Puedes cambiar tu voto hasta el cierre; si sigue el empate, el servidor decide por volado.'
              : 'Votación abierta. Puedes cambiar tu voto hasta el cierre.',
        EstadoVotacion.empatePendiente =>
          'Empate: el servidor lo resuelve por volado.',
        EstadoVotacion.ganador =>
          vot.resueltaPorVolado(ahora)
              ? 'Empate resuelto por volado del servidor. Ganó: ${vot.ganador(ahora)!.titulo}.'
              : 'Ganó: ${vot.ganador(ahora)!.titulo}.',
      };
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const TarjetaHayPresupuesto(),
        Text(
          aviso(),
          style: v.lectura(
            tamano: 16,
            peso: FontWeight.w600,
            color: v.textoFuerte,
          ),
        ),
        if (!srv.puedeParticipar)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Solo lectura',
              style: v.lectura(tamano: 14, color: v.textoTenue),
            ),
          ),
        const SizedBox(height: 12),
        for (final p in vot?.propuestas ?? const <PropuestaMenu>[])
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.titulo,
                    style: v.titulo(tamano: 18, color: v.textoFuerte),
                  ),
                  Text(
                    'Propone ${p.autorNombre}',
                    style: v.lectura(tamano: 14, color: v.textoTenue),
                  ),
                  for (final id in p.platilloIds)
                    if (nombresPlatillos[id] != null)
                      Text(
                        '• ${nombresPlatillos[id]}',
                        style: v.lectura(tamano: 15, color: v.texto),
                      ),
                  const SizedBox(height: 8),
                  Text(
                    '${vot!.conteo(p.id)} ${vot.conteo(p.id) == 1 ? 'voto' : 'votos'}',
                    style: v.lectura(tamano: 16, color: v.texto),
                  ),
                  if (vot.votos[yo] == p.id)
                    Text(
                      'Tu voto',
                      style: v.lectura(
                        tamano: 15,
                        peso: FontWeight.w600,
                        color: v.etiqueta,
                      ),
                    )
                  else if (srv.puedeParticipar && vot.puedeVotar(ahora))
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: FilledButton(
                        onPressed: () => _hacer(
                          context,
                          ref,
                          () => srv.votar(dia, p.id),
                        ),
                        child: Text(
                          vot.votos.containsKey(yo)
                              ? 'Cambiar mi voto a esta'
                              : 'Votar por esta',
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        if (srv.puedeParticipar && (vot == null || vot.propuestas.length < 2))
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              icon: const Icon(Icons.add),
              onPressed: () => _proponer(context, ref),
              label: Text(
                vot == null ? 'Proponer un menú' : 'Dar mi propuesta',
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _hacer(
    BuildContext context,
    WidgetRef ref,
    Future<Object?> Function() accion,
  ) async {
    try {
      await accion();
      ref.read(versionAlimentacionProvider.notifier).state++;
    } on ErrorVotacion catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.mensaje)));
      }
    }
  }

  Future<void> _proponer(BuildContext context, WidgetRef ref) async {
    final titulo = TextEditingController();
    final elegidos = <String>{};
    List<Platillo> catalogo = const [];
    try {
      catalogo = await ref.read(platillosProvider.future);
    } catch (_) {}
    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Proponer un menú'),
          content: SizedBox(
            width: 400,
            child: ListView(
              shrinkWrap: true,
              children: [
                TextField(
                  controller: titulo,
                  maxLength: 80,
                  decoration: const InputDecoration(labelText: 'Nombre del menú'),
                ),
                for (final p in catalogo)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: elegidos.contains(p.id),
                    title: Text(p.nombre),
                    onChanged: (m) => setS(
                      () => m == true ? elegidos.add(p.id) : elegidos.remove(p.id),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Proponer'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    await _hacer(
      context,
      ref,
      () => ref
          .read(servicioPlanFamiliarProvider)
          .proponer(dia, titulo: titulo.text, platilloIds: elegidos.toList()),
    );
  }
}
