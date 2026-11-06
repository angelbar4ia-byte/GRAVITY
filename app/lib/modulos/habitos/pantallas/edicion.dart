/// Editar objetivos y bloques de agenda (Fase 4, E4): nombre, horario, días,
/// meta y área, con validación y *Deshacer*. Editar no toca los registros: la
/// racha y el historial siguen donde estaban.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habitos_dominio/habitos_dominio.dart';

import '../../../diseno/diseno.dart';
import '../datos/modelos.dart';
import '../datos/modelos_agenda.dart';
import '../estado/proveedores.dart';

const _nombresDias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
const _nombresDiasLargos = [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];

const nombresArea = {
  'espiritual': 'Espiritual',
  'salud': 'Salud',
  'educacion': 'Educación',
  'personal': 'Personal',
  'laboral': 'Laboral',
  'proyectos': 'Proyectos',
};

String horaDeMin(int min) =>
    '${(min ~/ 60).toString().padLeft(2, '0')}:${(min % 60).toString().padLeft(2, '0')}';

/// Siete casillas (lunes = 1 … domingo = 64). Cada una dice su día completo
/// al lector de pantalla y su estado con texto, no solo con color.
class SelectorDias extends StatelessWidget {
  const SelectorDias({
    super.key,
    required this.mascara,
    required this.alCambiar,
  });
  final int mascara;
  final ValueChanged<int> alCambiar;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 4,
    children: [
      for (var i = 0; i < 7; i++)
        Semantics(
          label: _nombresDiasLargos[i],
          selected: mascara & (1 << i) != 0,
          excludeSemantics: true,
          child: FilterChip(
            label: Text(_nombresDias[i]),
            selected: mascara & (1 << i) != 0,
            onSelected: (v) =>
                alCambiar(v ? mascara | (1 << i) : mascara & ~(1 << i)),
          ),
        ),
    ],
  );
}

void _avisoDeshacer(
  ScaffoldMessengerState m,
  String texto,
  Future<void> Function() alDeshacer,
) {
  m
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(texto),
        action: SnackBarAction(label: 'Deshacer', onPressed: alDeshacer),
      ),
    );
}

Future<void> editarObjetivoEnHoja(BuildContext context, ObjetivoHab o) =>
    mostrarHojaInferior(
      context,
      titulo: 'Editar objetivo',
      child: HojaEditarObjetivo(objetivo: o),
    );

Future<void> editarBloqueEnHoja(BuildContext context, BloqueHab b) =>
    mostrarHojaInferior(
      context,
      titulo: 'Editar bloque',
      child: HojaEditarBloque(bloque: b),
    );

class HojaEditarObjetivo extends ConsumerStatefulWidget {
  const HojaEditarObjetivo({super.key, required this.objetivo});
  final ObjetivoHab objetivo;
  @override
  ConsumerState<HojaEditarObjetivo> createState() =>
      _HojaEditarObjetivoEstado();
}

class _HojaEditarObjetivoEstado extends ConsumerState<HojaEditarObjetivo> {
  late final titulo = TextEditingController(text: widget.objetivo.titulo);
  late final unidad = TextEditingController(text: widget.objetivo.unidad ?? '');
  late final meta = TextEditingController(
    text: widget.objetivo.metaValor?.toString() ?? '',
  );
  late final motivo = TextEditingController(text: widget.objetivo.motivo ?? '');
  late String area = widget.objetivo.area;
  late bool porDias = widget.objetivo.frecuencia == Frecuencia.diasSemana;
  late int mascara = widget.objetivo.diasSemana == 0
      ? 127
      : widget.objetivo.diasSemana;
  String? error;

  bool get _frecuenciaEditable =>
      widget.objetivo.frecuencia == Frecuencia.diaria ||
      widget.objetivo.frecuencia == Frecuencia.diasSemana;

  @override
  void dispose() {
    for (final c in [titulo, unidad, meta, motivo]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    final original = widget.objetivo;
    final s = ref.read(servicioHabitosProvider);
    final messenger = ScaffoldMessenger.of(context);
    final version = ref.read(versionHabitosProvider.notifier);
    try {
      await s.editarObjetivo(
        original,
        titulo: titulo.text,
        area: area,
        unidad: unidad.text,
        metaValor: meta.text.trim().isEmpty
            ? null
            : int.tryParse(meta.text.trim()) ?? -1,
        frecuencia: _frecuenciaEditable
            ? (porDias ? Frecuencia.diasSemana : Frecuencia.diaria)
            : null,
        diasSemana: porDias ? mascara : null,
        motivo: motivo.text,
      );
    } on ArgumentError catch (e) {
      setState(() => error = e.message.toString());
      return;
    }
    version.state++;
    if (mounted) Navigator.of(context).pop();
    _avisoDeshacer(messenger, 'Cambios guardados', () async {
      await s.restaurarObjetivo(original);
      version.state++;
    });
  }

  Future<void> _archivar() async {
    final original = widget.objetivo;
    final s = ref.read(servicioHabitosProvider);
    final messenger = ScaffoldMessenger.of(context);
    final version = ref.read(versionHabitosProvider.notifier);
    await s.archivar(original);
    version.state++;
    if (mounted) Navigator.of(context).pop();
    _avisoDeshacer(
      messenger,
      'Objetivo archivado. Tu historial se queda.',
      () async {
        await s.restaurarObjetivo(original);
        version.state++;
      },
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        controller: titulo,
        maxLength: 120,
        decoration: const InputDecoration(labelText: 'Nombre'),
      ),
      DropdownButtonFormField<String>(
        initialValue: area,
        decoration: const InputDecoration(labelText: 'Área'),
        items: [
          for (final a in areasHabitos)
            DropdownMenuItem(value: a, child: Text(nombresArea[a]!)),
        ],
        onChanged: (v) => setState(() => area = v ?? area),
      ),
      TextField(
        controller: unidad,
        maxLength: 20,
        decoration: const InputDecoration(
          labelText: 'Unidad (minutos, páginas…)',
        ),
      ),
      TextField(
        controller: meta,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Meta por vez (opcional)'),
      ),
      if (_frecuenciaEditable) ...[
        const SizedBox(height: 8),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Todos los días')),
            ButtonSegment(value: true, label: Text('Días elegidos')),
          ],
          selected: {porDias},
          onSelectionChanged: (s) => setState(() => porDias = s.first),
        ),
        if (porDias) ...[
          const SizedBox(height: 8),
          SelectorDias(
            mascara: mascara,
            alCambiar: (m) => setState(() => mascara = m),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Tu historial no cambia. La racha se calcula con los días que elijas.',
            ),
          ),
        ],
      ],
      TextField(
        controller: motivo,
        maxLength: 200,
        decoration: const InputDecoration(
          labelText: '¿Por qué es importante? (opcional)',
        ),
      ),
      if (error != null)
        Padding(padding: const EdgeInsets.only(top: 4), child: Text(error!)),
      const SizedBox(height: 8),
      FilledButton(onPressed: _guardar, child: const Text('Guardar cambios')),
      TextButton(
        onPressed: _archivar,
        child: const Text('Archivar este objetivo'),
      ),
    ],
  );
}

class HojaEditarBloque extends ConsumerStatefulWidget {
  const HojaEditarBloque({super.key, required this.bloque});
  final BloqueHab bloque;
  @override
  ConsumerState<HojaEditarBloque> createState() => _HojaEditarBloqueEstado();
}

class _HojaEditarBloqueEstado extends ConsumerState<HojaEditarBloque> {
  late final titulo = TextEditingController(text: widget.bloque.titulo);
  late final duracion = TextEditingController(
    text: widget.bloque.duracionMin.toString(),
  );
  late String area = widget.bloque.area;
  late int inicio = widget.bloque.inicioMin;
  late int dias = widget.bloque.dias == 0 ? 127 : widget.bloque.dias;
  late int? recordar = widget.bloque.recordarMin;
  String? error;

  @override
  void dispose() {
    titulo.dispose();
    duracion.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final original = widget.bloque;
    final s = ref.read(servicioAgendaProvider);
    final messenger = ScaffoldMessenger.of(context);
    final version = ref.read(versionHabitosProvider.notifier);
    final BloqueHab nuevo;
    try {
      nuevo = await s.editarBloque(
        original,
        titulo: titulo.text,
        area: area,
        inicioMin: inicio,
        duracionMin: int.tryParse(duracion.text.trim()) ?? 0,
        dias: dias,
        recordarMin: recordar,
      );
    } on ArgumentError catch (e) {
      setState(() => error = e.message.toString());
      return;
    }
    final cruces = await s.conflictosDe(nuevo);
    version.state++;
    if (mounted) Navigator.of(context).pop();
    // El cruce avisa, no impide (regla 67).
    final texto = cruces.isEmpty
        ? 'Cambios guardados'
        : 'Cambios guardados. Se cruza con: ${cruces.map((x) => x.titulo).join(', ')}';
    _avisoDeshacer(messenger, texto, () async {
      await s.restaurarBloque(original);
      version.state++;
    });
  }

  Future<void> _quitar() async {
    final original = widget.bloque;
    final s = ref.read(servicioAgendaProvider);
    final messenger = ScaffoldMessenger.of(context);
    final version = ref.read(versionHabitosProvider.notifier);
    await s.desactivar(original);
    version.state++;
    if (mounted) Navigator.of(context).pop();
    _avisoDeshacer(messenger, 'Bloque quitado de tu agenda', () async {
      await s.restaurarBloque(original);
      version.state++;
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        controller: titulo,
        maxLength: 120,
        decoration: const InputDecoration(labelText: 'Nombre'),
      ),
      DropdownButtonFormField<String>(
        initialValue: area,
        decoration: const InputDecoration(labelText: 'Área'),
        items: [
          for (final a in areasHabitos)
            DropdownMenuItem(value: a, child: Text(nombresArea[a]!)),
        ],
        onChanged: (v) => setState(() => area = v ?? area),
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Hora'),
        subtitle: Text(horaDeMin(inicio)),
        onTap: () async {
          final h = await showTimePicker(
            context: context,
            initialTime: TimeOfDay(hour: inicio ~/ 60, minute: inicio % 60),
          );
          if (h != null) setState(() => inicio = h.hour * 60 + h.minute);
        },
      ),
      TextField(
        controller: duracion,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Minutos'),
      ),
      const SizedBox(height: 8),
      SelectorDias(mascara: dias, alCambiar: (m) => setState(() => dias = m)),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Avisarme 10 minutos antes'),
        value: recordar != null,
        onChanged: (v) => setState(() => recordar = v ? 10 : null),
      ),
      if (error != null) Text(error!),
      const SizedBox(height: 8),
      FilledButton(onPressed: _guardar, child: const Text('Guardar cambios')),
      TextButton(onPressed: _quitar, child: const Text('Quitar este bloque')),
    ],
  );
}
