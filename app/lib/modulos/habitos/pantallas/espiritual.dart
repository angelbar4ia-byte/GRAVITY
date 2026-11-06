/// Espiritual (reglas 73 a 87): inicio, lector, planes, devocional y oración.
/// Devocional y oración son sensibles (detrás de la puerta reservada).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:habitos_dominio/habitos_dominio.dart';

import '../../../app/pantallas/marco_pantalla.dart';
import '../../../app/sensibles/puerta_reservada.dart';
import '../../../diseno/diseno.dart';
import '../../../nucleo/contratos/roles.dart';
import '../../../nucleo/contratos/rutas.dart';
import '../casos_uso/servicio_diario.dart';
import '../datos/biblia.dart';
import '../datos/repositorio_agenda.dart';
import '../estado/proveedores.dart';

String _ruta(String s) => '${Rutas.habitos}/$s';

class PantallaEspiritual extends ConsumerWidget {
  const PantallaEspiritual({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planes = ref.watch(planesProvider).value ?? const [];
    final hoy = ref.watch(servicioLecturaProvider);
    final biblias = ref.watch(bibliasProvider).value ?? const [];
    final ref0 = analizarReferencia(versiculoDelDia(DateTime.now(), versiculosAnimo));
    String? versiculo;
    if (biblias.isNotEmpty && ref0 != null) {
      final p = pasaje(biblias.first, ref0);
      if (p != null) versiculo = '${p.map((e) => e.$2).join(' ')} (${versiculoDelDia(DateTime.now(), versiculosAnimo)})';
    }
    return TemaModulo(
      modulo: Modulo.habitos,
      submodulo: Submodulo.espiritual,
      child: MarcoPantalla(
        titulo: 'Espiritual',
        rutaAnterior: Rutas.habitos,
        cuerpo: ListView(padding: const EdgeInsets.all(16), children: [
          if (versiculo != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(versiculo)),
          for (final p in planes)
            if (hoy.deHoy(p) case final l?)
              TarjetaPlanLectura(
                titulo: p.nombre,
                avance: p.plan.avancePct() / 100,
                lecturaDeHoy: _texto(l.dia.capitulos),
                diaTexto: 'Día ${l.dia.dia} de ${p.plan.dias.length}',
                diasAtrasado: l.atrasados,
                alLeer: () => context.go(_ruta('lector?libro=${l.dia.capitulos.first.libro}&cap=${l.dia.capitulos.first.cap}')),
                alPonerseAlDia: l.atrasados > 0 ? () => context.go(_ruta('planes')) : null,
              ),
          if (planes.isEmpty)
            const EstadoVacioHabitos(tipo: VacioHabitos.sinObjetivos, textoAccion: null),
          ListTile(leading: const Icon(Icons.menu_book_outlined), title: const Text('Lector'), onTap: () => context.go(_ruta('lector'))),
          ListTile(leading: const Icon(Icons.event_note_outlined), title: const Text('Planes de lectura'), onTap: () => context.go(_ruta('planes'))),
          ListTile(leading: const Icon(Icons.lock_outline), title: const Text('Devocional'), onTap: () => context.go(_ruta('devocional'))),
          ListTile(leading: const Icon(Icons.lock_outline), title: const Text('Oración'), onTap: () => context.go(_ruta('oracion'))),
        ]),
      ),
    );
  }
}

String _texto(List<Capitulo> caps) {
  if (caps.isEmpty) return '';
  final seg = PlanGuardado.segmentos(caps);
  return seg.map((s) {
    final n = canon[(s['libro']! as int) - 1].nombre;
    return s['cap_ini'] == s['cap_fin'] ? '$n ${s['cap_ini']}' : '$n ${s['cap_ini']}-${s['cap_fin']}';
  }).join(', ');
}

class PantallaLector extends ConsumerStatefulWidget {
  const PantallaLector({super.key, this.libro = 43, this.cap = 1});
  final int libro;
  final int cap;
  @override
  ConsumerState<PantallaLector> createState() => _LectorEstado();
}

class _LectorEstado extends ConsumerState<PantallaLector> {
  late int libro = widget.libro;
  late int cap = widget.cap;
  int version = 0;

  @override
  Widget build(BuildContext context) {
    final biblias = ref.watch(bibliasProvider);
    return TemaModulo(
      modulo: Modulo.habitos,
      submodulo: Submodulo.espiritual,
      child: MarcoPantalla(
        titulo: 'Lector',
        rutaAnterior: _ruta('espiritual'),
        cuerpo: biblias.when(
          loading: () => const EstadoCargando(),
          error: (_, _) => const EstadoVacioHabitos(tipo: VacioHabitos.sinDatos),
          data: (l) {
            if (l.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Text('El texto bíblico aún no está instalado en este equipo.'),
              );
            }
            final b = l[version.clamp(0, l.length - 1)];
            final v = b.capitulo(libro, cap);
            final lib = canon[libro - 1];
            return ListView(padding: const EdgeInsets.all(16), children: [
              Row(children: [
                Expanded(
                  child: DropdownButton<int>(
                    isExpanded: true,
                    value: libro,
                    items: [for (final x in canon) DropdownMenuItem(value: x.numero, child: Text(x.nombre))],
                    onChanged: (n) => setState(() {
                      libro = n ?? libro;
                      cap = 1;
                    }),
                  ),
                ),
                if (l.length > 1)
                  SegmentedButton<int>(
                    segments: [for (var i = 0; i < l.length; i++) ButtonSegment(value: i, label: Text(l[i].id.toUpperCase()))],
                    selected: {version.clamp(0, l.length - 1)},
                    onSelectionChanged: (s) => setState(() => version = s.first),
                  ),
              ]),
              Row(children: [
                IconButton(tooltip: 'Capítulo anterior', icon: const Icon(Icons.chevron_left), onPressed: cap > 1 ? () => setState(() => cap--) : null),
                Expanded(child: Text('${lib.nombre} $cap', textAlign: TextAlign.center)),
                IconButton(tooltip: 'Capítulo siguiente', icon: const Icon(Icons.chevron_right), onPressed: cap < lib.capitulos ? () => setState(() => cap++) : null),
              ]),
              if (v == null)
                const Text('Este capítulo no existe en esta versión.')
              else
                LectorBiblico(
                  referencia: '${lib.nombre} $cap',
                  version: b.id.toUpperCase(),
                  versiculos: [for (var i = 0; i < v.length; i++) VersiculoLector(i + 1, v[i])],
                ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('${b.nombre} · ${b.licencia}', style: Theme.of(context).textTheme.bodySmall),
              ),
            ]);
          },
        ),
      ),
    );
  }
}

class PantallaPlanes extends ConsumerWidget {
  const PantallaPlanes({super.key});

  Future<void> _crear(BuildContext context, WidgetRef ref, TipoPlan t) async {
    final f = await showDatePicker(
        context: context, initialDate: DateTime.now(), firstDate: DateTime(2026), lastDate: DateTime(2100));
    if (f == null) return;
    await ref.read(servicioLecturaProvider).crear(t, inicio: f, libro: t == TipoPlan.libro ? 19 : null, capitulosPorDia: 5);
    ref.read(versionHabitosProvider.notifier).state++;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.read(servicioLecturaProvider);
    void refrescar() => ref.read(versionHabitosProvider.notifier).state++;
    final planes = ref.watch(planesProvider).value ?? const [];
    return TemaModulo(
      modulo: Modulo.habitos,
      submodulo: Submodulo.espiritual,
      child: MarcoPantalla(
        titulo: 'Planes de lectura',
        rutaAnterior: _ruta('espiritual'),
        cuerpo: ListView(padding: const EdgeInsets.all(16), children: [
          for (final p in planes) ...[
            Text(p.nombre, style: Theme.of(context).textTheme.titleMedium),
            if (s.deHoy(p) case final l?) ...[
              Text('Hoy: ${_texto(l.dia.capitulos)}'),
              Wrap(spacing: 8, children: [
                FilledButton(
                    onPressed: () async {
                      await s.marcarHecho(p, l.dia);
                      refrescar();
                    },
                    child: const Text('Hecho')),
                if (l.atrasados > 0) ...[
                  OutlinedButton(
                      onPressed: () async {
                        await s.ponerAlDiaEn(p, 7);
                        refrescar();
                      },
                      child: const Text('Ponerme al día')),
                  OutlinedButton(
                      onPressed: () async {
                        await s.saltar(p);
                        refrescar();
                      },
                      child: const Text('Saltar')),
                  OutlinedButton(
                      onPressed: () async {
                        await s.reiniciar(p);
                        refrescar();
                      },
                      child: const Text('Reiniciar el tramo')),
                ],
              ]),
            ] else
              const Text('Plan terminado.'),
            const Divider(),
          ],
          Text('Nuevo plan', style: Theme.of(context).textTheme.titleMedium),
          for (final t in [TipoPlan.rutaInicio, TipoPlan.nt90, TipoPlan.salmosProverbios30, TipoPlan.biblia1Ano])
            ListTile(
              title: Text(switch (t) {
                TipoPlan.rutaInicio => 'Ruta de inicio (Juan, 21 días)',
                TipoPlan.nt90 => 'Nuevo Testamento en 90 días',
                TipoPlan.salmosProverbios30 => 'Salmos y Proverbios en 30 días',
                _ => 'La Biblia en un año',
              }),
              subtitle: const Text('Tú eliges cuándo empezar'),
              onTap: () => _crear(context, ref, t),
            ),
        ]),
      ),
    );
  }
}

class PantallaDevocional extends ConsumerStatefulWidget {
  const PantallaDevocional({super.key});
  @override
  ConsumerState<PantallaDevocional> createState() => _DevocionalEstado();
}

class _DevocionalEstado extends ConsumerState<PantallaDevocional> {
  final pasaje = TextEditingController();
  final reflexion = TextEditingController();
  final aplicacion = TextEditingController();
  final oracion = TextEditingController();
  bool breve = false;
  bool cargado = false;

  @override
  void dispose() {
    for (final c in [pasaje, reflexion, aplicacion, oracion]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cargar() async {
    cargado = true;
    final e = await ref.read(servicioDiarioProvider)?.devocionalDe(DateTime.now());
    if (e != null && mounted) {
      setState(() {
        pasaje.text = e.pasaje ?? '';
        reflexion.text = e.reflexion ?? '';
        aplicacion.text = e.aplicacion ?? '';
        oracion.text = e.oracion ?? '';
        breve = e.breve;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!cargado) _cargar();
    Widget campo(String t, TextEditingController c) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TextField(controller: c, maxLines: null, decoration: InputDecoration(labelText: t)),
        );
    return TemaModulo(
      modulo: Modulo.habitos,
      submodulo: Submodulo.espiritual,
      child: PuertaReservada(
        child: Scaffold(
          appBar: AppBar(title: const Text('Devocional'), leading: BackButton(onPressed: () => context.go(_ruta('espiritual')))),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            SwitchListTile(title: const Text('Versión breve (5 minutos)'), value: breve, onChanged: (v) => setState(() => breve = v)),
            campo('Lectura (pasaje)', pasaje),
            campo('Reflexión', reflexion),
            if (!breve) campo('Aplicación', aplicacion),
            campo('Oración', oracion),
            FilledButton(
              onPressed: () async {
                await ref.read(servicioDiarioProvider)?.guardarDevocional(
                    pasaje: pasaje.text, reflexion: reflexion.text, aplicacion: aplicacion.text, oracion: oracion.text, breve: breve);
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Guardado')));
              },
              child: const Text('Guardar'),
            ),
          ]),
        ),
      ),
    );
  }
}

class PantallaOracion extends ConsumerStatefulWidget {
  const PantallaOracion({super.key});
  @override
  ConsumerState<PantallaOracion> createState() => _OracionEstado();
}

class _OracionEstado extends ConsumerState<PantallaOracion> {
  final nueva = TextEditingController();
  int version = 0;

  @override
  void dispose() {
    nueva.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(servicioDiarioProvider);
    return TemaModulo(
      modulo: Modulo.habitos,
      submodulo: Submodulo.espiritual,
      child: PuertaReservada(
        child: Scaffold(
          appBar: AppBar(title: const Text('Oración'), leading: BackButton(onPressed: () => context.go(_ruta('espiritual')))),
          body: FutureBuilder<List<Peticion>>(
            key: ValueKey(version),
            future: d?.peticiones() ?? Future.value(const []),
            builder: (context, snap) {
              final l = snap.data ?? const <Peticion>[];
              return ListView(padding: const EdgeInsets.all(16), children: [
                Row(children: [
                  Expanded(child: TextField(controller: nueva, decoration: const InputDecoration(labelText: 'Nueva petición'))),
                  IconButton(
                    tooltip: 'Agregar',
                    icon: const Icon(Icons.add),
                    onPressed: () async {
                      if (nueva.text.trim().isEmpty) return;
                      await d?.agregarPeticion(nueva.text);
                      nueva.clear();
                      setState(() => version++);
                    },
                  ),
                ]),
                OutlinedButton(
                  onPressed: () async {
                    await d?.registrarOracion(10);
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('10 minutos de oración anotados')));
                  },
                  child: const Text('Anotar 10 minutos de oración'),
                ),
                for (final p in l)
                  FilaOracion(
                    texto: p.texto,
                    respondida: p.estado == EstadoPeticion.respondida,
                    fechaTexto: '${p.creada.day}/${p.creada.month}/${p.creada.year}',
                    alTocar: () async {
                      final sig = switch (p.estado) {
                        EstadoPeticion.pendiente => EstadoPeticion.enEspera,
                        EstadoPeticion.enEspera => EstadoPeticion.respondida,
                        EstadoPeticion.respondida => EstadoPeticion.pendiente,
                      };
                      await d?.cambiarEstado(p, sig);
                      setState(() => version++);
                    },
                  ),
              ]);
            },
          ),
        ),
      ),
    );
  }
}
