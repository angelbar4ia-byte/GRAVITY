/// Lector bíblico con subrayados (6 colores), marcadores y notas (Fase 4, E8).
///
/// - Subrayados y marcadores: sin texto libre, en claro; van por referencia
///   `libro:capítulo:versículo`, así que cambiar de versión (RVR1909, KJV) los
///   conserva.
/// - Notas: sensibles; se escriben y se leen **solo detrás de la puerta
///   reservada** y se guardan cifradas (`diario_oracion`).
/// - Sin texto instalado el lector dice qué falta (E18). El texto real lo
///   entrega el dueño (P10); mientras tanto sirve el texto ficticio de prueba.
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
import '../datos/modelos_agenda.dart';
import '../estado/proveedores.dart';

String _ruta(String s) => '${Rutas.habitos}/$s';

String rutaLector(int libro, int cap) => _ruta('lector?libro=$libro&cap=$cap');

/// Mensaje del lector sin texto bíblico instalado (E18).
const mensajeSinTexto =
    'Falta el texto de la Biblia en este equipo. Avísale a quien administra '
    'la casa para que lo instale; mientras tanto puedes seguir con tus planes '
    'y tu devocional.';

final marcasCapituloProvider =
    FutureProvider.family<List<MarcaBiblia>, (int, int)>((ref, k) {
      ref.watch(versionHabitosProvider);
      return ref.watch(servicioMarcasProvider).delCapitulo(k.$1, k.$2);
    });

const _tonos = {
  'amarillo': 50.0,
  'verde': 130.0,
  'azul': 210.0,
  'rosa': 330.0,
  'naranja': 25.0,
  'morado': 275.0,
};

/// Color de una muestra de subrayado, derivado del tema (sin colores fijos).
/// Siempre va acompañado del nombre del color: nunca es la única señal.
Color colorDeSubrayado(ValoresDiseno v, String nombre) {
  final oscuro = HSLColor.fromColor(v.fondo).lightness < 0.5;
  return HSLColor.fromAHSL(
    1,
    _tonos[nombre] ?? 50,
    0.6,
    oscuro ? 0.45 : 0.7,
  ).toColor();
}

String nombreColor(String c) =>
    c.isEmpty ? c : c[0].toUpperCase() + c.substring(1);

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

  Future<void> _tocar(VersiculoLector v, List<MarcaBiblia> marcas) async {
    final accion = await mostrarHojaInferior<String>(
      context,
      titulo: '${canon[libro - 1].nombre} $cap:${v.numero}',
      child: HojaVersiculo(
        libro: libro,
        cap: cap,
        ver: v.numero,
        marcas: marcas,
      ),
    );
    if (accion == 'nota' && mounted) {
      context.go(_ruta('lector/nota?libro=$libro&cap=$cap&ver=${v.numero}'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final biblias = ref.watch(bibliasProvider);
    final marcas =
        ref.watch(marcasCapituloProvider((libro, cap))).value ??
        const <MarcaBiblia>[];
    return TemaModulo(
      modulo: Modulo.habitos,
      submodulo: Submodulo.espiritual,
      child: MarcoPantalla(
        titulo: 'Lector',
        rutaAnterior: _ruta('espiritual'),
        cuerpo: biblias.when(
          loading: () => const EstadoCargando(),
          error: (_, _) =>
              const EstadoVacioHabitos(tipo: VacioHabitos.sinDatos),
          data: (l) {
            if (l.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Semantics(
                  container: true,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.menu_book_outlined, size: 40),
                      const SizedBox(height: 12),
                      Text(
                        'Aún no hay texto bíblico',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text(mensajeSinTexto, textAlign: TextAlign.center),
                    ],
                  ),
                ),
              );
            }
            final b = l[version.clamp(0, l.length - 1)];
            final v = b.capitulo(libro, cap);
            final lib = canon[libro - 1];
            final subrayados = {
              for (final m in marcas)
                if (m.esSubrayado &&
                    analizarReferenciaMarca(m.referencia) != null)
                  analizarReferenciaMarca(m.referencia)!.ver: m.color,
            };
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButton<int>(
                        isExpanded: true,
                        value: libro,
                        items: [
                          for (final x in canon)
                            DropdownMenuItem(
                              value: x.numero,
                              child: Text(x.nombre),
                            ),
                        ],
                        onChanged: (n) => setState(() {
                          libro = n ?? libro;
                          cap = 1;
                        }),
                      ),
                    ),
                    if (l.length > 1)
                      SegmentedButton<int>(
                        segments: [
                          for (var i = 0; i < l.length; i++)
                            ButtonSegment(
                              value: i,
                              label: Text(l[i].id.toUpperCase()),
                            ),
                        ],
                        selected: {version.clamp(0, l.length - 1)},
                        onSelectionChanged: (s) =>
                            setState(() => version = s.first),
                      ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Capítulo anterior',
                      icon: const Icon(Icons.chevron_left),
                      onPressed: cap > 1 ? () => setState(() => cap--) : null,
                    ),
                    Expanded(
                      child: Text(
                        '${lib.nombre} $cap',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Capítulo siguiente',
                      icon: const Icon(Icons.chevron_right),
                      onPressed: cap < lib.capitulos
                          ? () => setState(() => cap++)
                          : null,
                    ),
                  ],
                ),
                if (v == null)
                  const Text('Este capítulo no existe en esta versión.')
                else ...[
                  LectorBiblico(
                    referencia: '${lib.nombre} $cap',
                    version: b.id.toUpperCase(),
                    versiculos: [
                      for (var i = 0; i < v.length; i++)
                        VersiculoLector(
                          i + 1,
                          v[i],
                          subrayado: subrayados.containsKey(i + 1),
                        ),
                    ],
                    alTocarVersiculo: (x) => _tocar(x, marcas),
                  ),
                  _ResumenMarcas(marcas: marcas),
                ],
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${b.nombre} · ${b.licencia}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Lista en palabras de lo marcado en el capítulo: el color se dice con su
/// nombre, no solo se muestra.
class _ResumenMarcas extends StatelessWidget {
  const _ResumenMarcas({required this.marcas});
  final List<MarcaBiblia> marcas;

  @override
  Widget build(BuildContext context) {
    if (marcas.isEmpty) return const SizedBox.shrink();
    final v = ValoresDiseno.de(context);
    final orden = [...marcas]
      ..sort(
        (a, b) => (analizarReferenciaMarca(a.referencia)?.ver ?? 0).compareTo(
          analizarReferenciaMarca(b.referencia)?.ver ?? 0,
        ),
      );
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Semantics(
        container: true,
        label: 'Tus marcas en este capítulo',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tus marcas', style: Theme.of(context).textTheme.titleSmall),
            for (final m in orden)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    if (m.esSubrayado)
                      ExcludeSemantics(
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: colorDeSubrayado(v, m.color ?? ''),
                            shape: BoxShape.circle,
                            border: Border.all(color: v.borde),
                          ),
                        ),
                      )
                    else
                      const ExcludeSemantics(
                        child: Icon(Icons.bookmark_outline, size: 16),
                      ),
                    const SizedBox(width: 8),
                    Text(
                      m.esSubrayado
                          ? 'Versículo ${analizarReferenciaMarca(m.referencia)?.ver} · subrayado ${m.color}'
                          : 'Versículo ${analizarReferenciaMarca(m.referencia)?.ver} · marcador',
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Qué hacer con un versículo: subrayar con uno de seis colores, quitar el
/// subrayado, poner o quitar el marcador, o escribir una nota (reservada).
class HojaVersiculo extends ConsumerWidget {
  const HojaVersiculo({
    super.key,
    required this.libro,
    required this.cap,
    required this.ver,
    required this.marcas,
  });
  final int libro, cap, ver;
  final List<MarcaBiblia> marcas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ValoresDiseno.de(context);
    final ref0 = referenciaMarca(libro, cap, ver);
    final propias = marcas.where((m) => m.referencia == ref0);
    final subrayado = propias.where((m) => m.esSubrayado).firstOrNull;
    final tieneMarcador = propias.any((m) => !m.esSubrayado);
    final s = ref.read(servicioMarcasProvider);
    void refrescar() => ref.read(versionHabitosProvider.notifier).state++;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Subrayar', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in coloresSubrayado)
              ChoiceChip(
                avatar: CircleAvatar(
                  radius: 8,
                  backgroundColor: colorDeSubrayado(v, c),
                ),
                label: Text(nombreColor(c)),
                selected: subrayado?.color == c,
                onSelected: (_) async {
                  await s.subrayar(libro, cap, ver, c);
                  refrescar();
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
          ],
        ),
        if (subrayado != null)
          TextButton(
            onPressed: () async {
              await s.quitarSubrayado(libro, cap, ver);
              refrescar();
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Quitar subrayado'),
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Marcador'),
          value: tieneMarcador,
          onChanged: (_) async {
            await s.alternarMarcador(libro, cap, ver);
            refrescar();
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.lock_outline),
          title: const Text('Escribir una nota'),
          subtitle: const Text('Reservada: se pide tu PIN'),
          onTap: () => Navigator.of(context).pop('nota'),
        ),
      ],
    );
  }
}

/// Nota de un versículo: cifrada y detrás de la puerta reservada.
class PantallaNotaLector extends ConsumerStatefulWidget {
  const PantallaNotaLector({
    super.key,
    required this.libro,
    required this.cap,
    required this.ver,
  });
  final int libro, cap, ver;
  @override
  ConsumerState<PantallaNotaLector> createState() => _NotaEstado();
}

class _NotaEstado extends ConsumerState<PantallaNotaLector> {
  final texto = TextEditingController();
  bool cargado = false;
  String? aviso;

  String get _ref => referenciaMarca(widget.libro, widget.cap, widget.ver);

  @override
  void dispose() {
    texto.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    cargado = true;
    try {
      final n = await ref
          .read(servicioDiarioProvider)
          ?.notasDeCapitulo(widget.libro, widget.cap);
      if (n != null && mounted) {
        setState(() => texto.text = n[widget.ver] ?? '');
      }
    } catch (_) {
      // Sin llave en este equipo: la nota no se puede leer.
    }
  }

  void _volver() => context.go(rutaLector(widget.libro, widget.cap));

  @override
  Widget build(BuildContext context) {
    if (!cargado) _cargar();
    final nombre =
        '${canon[widget.libro - 1].nombre} ${widget.cap}:${widget.ver}';
    return TemaModulo(
      modulo: Modulo.habitos,
      submodulo: Submodulo.espiritual,
      child: PuertaReservada(
        child: Scaffold(
          appBar: AppBar(
            title: Text('Nota · $nombre'),
            leading: BackButton(onPressed: _volver),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Solo tú ves esta nota. Se guarda cifrada y sigue al versículo en cualquier versión.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: texto,
                maxLines: null,
                minLines: 5,
                maxLength: 4000,
                decoration: const InputDecoration(labelText: 'Tu nota'),
              ),
              if (aviso != null) Text(aviso!),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () async {
                  try {
                    await ref
                        .read(servicioDiarioProvider)
                        ?.guardarNota(_ref, texto.text);
                    if (mounted) _volver();
                  } on StateError {
                    setState(
                      () => aviso = 'No pudimos guardarla: falta la llave en este equipo.',
                    );
                  } on ArgumentError catch (e) {
                    setState(() => aviso = e.message.toString());
                  }
                },
                child: Text(
                  texto.text.trim().isEmpty ? 'Listo' : 'Guardar nota',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
