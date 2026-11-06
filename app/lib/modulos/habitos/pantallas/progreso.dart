/// Progreso y revisión semanal (reglas 122 a 128).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:habitos_dominio/habitos_dominio.dart' as dom;

import '../../../app/pantallas/marco_pantalla.dart';
import '../../../diseno/diseno.dart';
import '../../../nucleo/contratos/roles.dart';
import '../../../nucleo/contratos/rutas.dart';
import '../casos_uso/servicio_progreso.dart';
import '../estado/proveedores.dart';

EstadoDiaConstancia _e(dom.EstadoDia e) => switch (e) {
  dom.EstadoDia.cumplido => EstadoDiaConstancia.cumplido,
  dom.EstadoDia.gracia => EstadoDiaConstancia.gracia,
  dom.EstadoDia.noCumplido => EstadoDiaConstancia.noCumplido,
  dom.EstadoDia.noAplica => EstadoDiaConstancia.noAplica,
};

class PantallaProgreso extends ConsumerWidget {
  const PantallaProgreso({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => TemaModulo(
    modulo: Modulo.habitos,
    child: MarcoPantalla(
      titulo: 'Progreso',
      rutaAnterior: Rutas.habitos,
      cuerpo: FutureBuilder(
        future: Future.wait([
          ref.watch(servicioProgresoProvider).constancia(),
          ref
              .watch(servicioProgresoProvider)
              .cumplimientoPorArea(dom.lunesDe(DateTime.now())),
        ]),
        builder: (context, s) {
          if (s.data == null) return const EstadoCargando();
          final (racha, dias) =
              s.data![0] as (dom.ResultadoRacha, List<DiaConstanciaDato>);
          final areas = s.data![1] as Map<String, int?>;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ChipRacha(
                dias: racha.actual,
                global: true,
                retomemos: racha.actual == 0 && racha.mejor > 0,
              ),
              const SizedBox(height: 12),
              CalendarioConstancia(
                dias: [
                  for (final d in dias)
                    DiaConstancia('${d.fecha.day}', _e(d.estado), hoy: d.hoy),
                ],
              ),
              const SizedBox(height: 12),
              for (final a in areas.entries)
                ListTile(
                  title: Text(a.key),
                  trailing: Text(a.value == null ? 'sin dato' : '${a.value} %'),
                ),
              ListTile(
                leading: const Icon(Icons.rate_review_outlined),
                title: const Text('Revisión semanal'),
                onTap: () => context.go('${Rutas.habitos}/revision'),
              ),
            ],
          );
        },
      ),
    ),
  );
}

const preguntasRevision = {
  'aprendi': '¿Qué aprendí?',
  'agradezco': '¿Qué agradezco?',
  'pido': '¿Qué pido?',
  'obedezco': '¿Qué obedezco esta semana?',
};

class PantallaRevision extends ConsumerStatefulWidget {
  const PantallaRevision({super.key});
  @override
  ConsumerState<PantallaRevision> createState() => _RevisionEstado();
}

class _RevisionEstado extends ConsumerState<PantallaRevision> {
  final ctl = {
    for (final k in preguntasRevision.keys) k: TextEditingController(),
  };
  bool? dar;

  /// Versión corta (30 segundos): el resumen y una sola pregunta. Por omisión
  /// en pantallas de teléfono; se puede cambiar (E12).
  bool? corta;
  late final Future<Map<String, int?>> _resumen = ref
      .read(servicioRevisionProvider)
      .resumen();

  @override
  void dispose() {
    for (final c in ctl.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(servicioRevisionProvider);
    final esCorta = corta ?? MediaQuery.sizeOf(context).width < 600;
    return TemaModulo(
      modulo: Modulo.habitos,
      child: MarcoPantalla(
        titulo: 'Revisión semanal',
        rutaAnterior: '${Rutas.habitos}/progreso',
        cuerpo: FutureBuilder<Map<String, int?>>(
          future: _resumen,
          builder: (context, snap) {
            if (snap.data == null) return const EstadoCargando();
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ResumenSemanal(
                  areas: [
                    for (final e in snap.data!.entries)
                      if (e.value != null)
                        CumplimientoArea(e.key, e.value! / 100),
                  ],
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Versión corta (30 segundos)'),
                  value: esCorta,
                  onChanged: (v) => setState(() => corta = v),
                ),
                for (final e in preguntasRevision.entries)
                  if (!esCorta || dom.preguntasRevisionCorta.contains(e.key))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextField(
                        controller: ctl[e.key],
                        maxLines: null,
                        decoration: InputDecoration(labelText: e.value),
                      ),
                    ),
                if (ref.watch(ajustesProvider).value?.darActivo ?? false)
                  SwitchListTile(
                    title: const Text(
                      '¿Se cumplió lo que decidiste dar esta semana?',
                    ),
                    value: dar ?? false,
                    onChanged: (v) => setState(() => dar = v),
                  ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () async {
                        await s.omitir();
                        ref.read(versionHabitosProvider.notifier).state++;
                        if (context.mounted)
                          context.go('${Rutas.habitos}/progreso');
                      },
                      child: const Text('Hoy no puedo'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () async {
                        await s.completar(
                          respuestas: {
                            for (final e in ctl.entries)
                              if (!esCorta ||
                                  dom.preguntasRevisionCorta.contains(e.key))
                                e.key: e.value.text,
                          },
                          dar: dar,
                        );
                        ref.read(versionHabitosProvider.notifier).state++;
                        if (context.mounted)
                          context.go('${Rutas.habitos}/progreso');
                      },
                      child: const Text('Cerrar la revisión'),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
