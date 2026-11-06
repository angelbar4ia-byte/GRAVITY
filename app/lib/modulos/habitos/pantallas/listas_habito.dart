/// Motivos, disparadores y reemplazos de un hábito a eliminar (Fase 4, E9).
/// Son texto de la persona: se guardan cifrados con el resto del hábito y
/// nunca salen del equipo. Los motivos aparecen en el SOS.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habitos_dominio/habitos_dominio.dart';

import '../../../diseno/diseno.dart';
import '../casos_uso/servicio_eliminar.dart';
import '../estado/proveedores.dart';

Future<void> abrirListasHabito(BuildContext context, TipoHabito tipo) =>
    mostrarHojaInferior(
      context,
      titulo: 'Mis motivos y disparadores',
      child: HojaListasHabito(tipo: tipo),
    );

class HojaListasHabito extends ConsumerStatefulWidget {
  const HojaListasHabito({super.key, required this.tipo});
  final TipoHabito tipo;
  @override
  ConsumerState<HojaListasHabito> createState() => _HojaListasEstado();
}

class _HojaListasEstado extends ConsumerState<HojaListasHabito> {
  List<String> motivos = [], disparadores = [], reemplazos = [];
  bool cargado = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final c = await ref.read(servicioEliminarProvider)?.config(widget.tipo);
      if (c != null && mounted) {
        setState(() {
          motivos = [...c.motivos];
          disparadores = [...c.disparadores];
          reemplazos = [...c.reemplazos];
        });
      }
    } catch (_) {
      // sin llave: se queda vacío
    }
    if (mounted) setState(() => cargado = true);
  }

  Future<void> _guardar() async {
    try {
      await ref
          .read(servicioEliminarProvider)!
          .guardarListas(
            widget.tipo,
            motivos: motivos,
            disparadores: disparadores,
            reemplazos: reemplazos,
          );
    } on ArgumentError catch (e) {
      setState(() => error = e.message.toString());
      return;
    } on StateError {
      setState(
        () => error = 'No pudimos guardar: falta la llave en este equipo.',
      );
      return;
    }
    ref.read(versionHabitosProvider.notifier).state++;
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (!cargado)
      return const Padding(
        padding: EdgeInsets.all(24),
        child: EstadoCargando(),
      );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EditorLista(
          titulo: 'Mis motivos',
          ayuda: 'Por qué quiero dejarlo. Los verás en la Pausa.',
          etiquetaNuevo: 'Nuevo motivo',
          elementos: motivos,
          alCambiar: (l) => setState(() => motivos = l),
        ),
        _EditorLista(
          titulo: 'Qué me dispara las ganas',
          ayuda: 'Momentos, lugares o emociones.',
          etiquetaNuevo: 'Nuevo disparador',
          elementos: disparadores,
          alCambiar: (l) => setState(() => disparadores = l),
        ),
        _EditorLista(
          titulo: 'Con qué lo reemplazo',
          ayuda: 'Algo pequeño que sí me ayuda.',
          etiquetaNuevo: 'Nuevo reemplazo',
          elementos: reemplazos,
          alCambiar: (l) => setState(() => reemplazos = l),
        ),
        if (error != null)
          Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!)),
        const SizedBox(height: 12),
        FilledButton(onPressed: _guardar, child: const Text('Guardar')),
      ],
    );
  }
}

class _EditorLista extends StatefulWidget {
  const _EditorLista({
    required this.titulo,
    required this.ayuda,
    required this.etiquetaNuevo,
    required this.elementos,
    required this.alCambiar,
  });
  final String titulo, ayuda, etiquetaNuevo;
  final List<String> elementos;
  final ValueChanged<List<String>> alCambiar;
  @override
  State<_EditorLista> createState() => _EditorListaEstado();
}

class _EditorListaEstado extends State<_EditorLista> {
  final nuevo = TextEditingController();

  @override
  void dispose() {
    nuevo.dispose();
    super.dispose();
  }

  void _agregar() {
    final t = nuevo.text.trim();
    if (t.isEmpty ||
        widget.elementos.contains(t) ||
        widget.elementos.length >= maxElementosLista)
      return;
    widget.alCambiar([
      ...widget.elementos,
      t.length > maxLargoElemento ? t.substring(0, maxLargoElemento) : t,
    ]);
    nuevo.clear();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.titulo, style: Theme.of(context).textTheme.titleSmall),
        Text(widget.ayuda, style: Theme.of(context).textTheme.bodySmall),
        for (final e in widget.elementos)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(e),
            trailing: IconButton(
              tooltip: 'Quitar: $e',
              icon: const Icon(Icons.close),
              onPressed: () =>
                  widget.alCambiar([...widget.elementos]..remove(e)),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: nuevo,
                maxLength: maxLargoElemento,
                decoration: InputDecoration(
                  labelText: widget.etiquetaNuevo,
                  counterText: '',
                ),
                onSubmitted: (_) => _agregar(),
              ),
            ),
            IconButton(
              tooltip: 'Agregar',
              icon: const Icon(Icons.add),
              onPressed: _agregar,
            ),
          ],
        ),
      ],
    ),
  );
}
