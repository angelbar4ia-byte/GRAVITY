/// E9 · Molestias: **solo en este equipo** (spec 4.3 y 9, PG-03, CA-G-36).
///
/// - Se guardan cifradas con la llave local de la persona; **nada** las sube,
///   las encola ni las manda a una IA. Aquí no se escribe ningún registro con su
///   contenido (R6).
/// - Sin diagnóstico: la app solo ajusta los ejercicios y recomienda consultar a
///   un profesional. Nunca nombra una lesión ni un tratamiento.
/// - La pantalla va dentro de `ProtegerMolestias` (FLAG_SECURE, modo privado y
///   equipos que no las admiten); **sin PIN** por decisión del dueño
///   (24/nov/2026).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;
import 'package:habitos_dominio/habitos_dominio.dart' hide EstadoDiaPlan;
import 'package:uuid/uuid.dart';

import '../../../../app/gimnasio/acceso_gimnasio.dart';
import '../../../../app/gimnasio/proveedores_gimnasio.dart'
    show molestiasLocalesProvider;
import '../../../../diseno/gimnasio/gimnasio.dart';
import '../../../../diseno/valores_diseno.dart';
import '../../../../nucleo/gimnasio/molestias_locales.dart';
import '../../estado/proveedores.dart' show versionHabitosProvider;
import '../estado/proveedores_gimnasio.dart';
import 'comun.dart';

/// Para volver a leer las molestias tras un cambio.
final versionMolestiasProvider = StateProvider<int>((_) => 0);

final lecturaMolestiasProvider = FutureProvider<LecturaMolestias?>((ref) async {
  ref.watch(versionMolestiasProvider);
  return ref.watch(molestiasLocalesProvider)?.leer();
});

const _zonasTexto = {
  Zonas.hombro: 'Hombro',
  Zonas.codo: 'Codo',
  Zonas.muneca: 'Muñeca',
  Zonas.cuello: 'Cuello',
  Zonas.espaldaAlta: 'Espalda alta',
  Zonas.espaldaBaja: 'Espalda baja',
  Zonas.cadera: 'Cadera',
  Zonas.rodilla: 'Rodilla',
  Zonas.tobillo: 'Tobillo',
  Zonas.otra: 'Otra zona',
};

String textoDeZona(String zona) => _zonasTexto[zona] ?? zona;

NivelMolestia nivelDe(int intensidad) => switch (intensidad) {
  1 => NivelMolestia.leve,
  2 => NivelMolestia.moderada,
  _ => NivelMolestia.fuerte,
};

class PantallaMolestias extends ConsumerWidget {
  const PantallaMolestias({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final almacen = ref.watch(molestiasLocalesProvider);
    return MarcoGimnasio(
      destino: DestinoGimnasio.molestias,
      cuerpo: almacen == null
          ? const SinPersonaGimnasio()
          : vistaAsincrona<LecturaMolestias?>(
              ref.watch(lecturaMolestiasProvider),
              mensajes: const MensajesEstadoGimnasio(
                cargando: 'Leyendo lo guardado en este equipo…',
                error: 'No se pudieron leer las molestias de este equipo.',
              ),
              alReintentar: () => ref.invalidate(lecturaMolestiasProvider),
              listo: (l) => _Cuerpo(lectura: l, almacen: almacen),
            ),
    );
  }
}

class _Cuerpo extends ConsumerWidget {
  const _Cuerpo({required this.lectura, required this.almacen});

  final LecturaMolestias? lectura;
  final MolestiasLocales almacen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ValoresDiseno.de(context);
    final hoy = ref.watch(fechaDeHoyGimnasioProvider);
    final l = lectura;
    void recargar() {
      ref.read(versionMolestiasProvider.notifier).state++;
      ref.read(versionGimnasioProvider.notifier).state++;
      ref.read(versionHabitosProvider.notifier).state++;
    }

    if (l == null || !l.enEsteEquipo) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(TextosGimnasio.molestiaOtroEquipo),
      );
    }
    if (l.bloqueada) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(TextosHabitosGimnasio.molestiaBloqueada),
      );
    }
    final activas = l.molestias.where((m) => m.activa).toList();
    final cerradas = l.molestias.where((m) => !m.activa).toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        MarcaGimnasio(
          texto: TextosGimnasio.molestiaSoloEnEsteEquipo,
          icono: Icons.phone_android_outlined,
        ),
        const SizedBox(height: 8),
        const Text(
          'Esta guía no sustituye a un profesional. Tus molestias no salen '
          'de este equipo.',
        ),
        SizedBox(height: v.espacio * 2),
        FilledButton.icon(
          key: const ValueKey('molestia-agregar'),
          onPressed: () async {
            final m = await showDialog<Molestia>(
              context: context,
              builder: (_) => _DialogoMolestia(hoy: hoy),
            );
            if (m == null) return;
            await almacen.guardar(m);
            recargar();
          },
          icon: const Icon(Icons.add),
          label: const Text(TextosHabitosGimnasio.molestiaAgregar),
        ),
        SizedBox(height: v.espacio * 2),
        if (l.molestias.isEmpty)
          const Text(TextosHabitosGimnasio.molestiaVacia),
        for (final m in activas) ...[
          AvisoMolestia(
            zonaTexto: textoDeZona(m.zona),
            nivel: nivelDe(m.intensidad),
            alSigue: m.debePreguntarSigue(hoy)
                ? () async {
                    await almacen.guardar(m.sigue(hoy));
                    recargar();
                  }
                : null,
            alYaNo: m.debePreguntarSigue(hoy)
                ? () async {
                    await almacen.guardar(m.yaNo(hoy));
                    recargar();
                  }
                : null,
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Wrap(
              spacing: 8,
              children: [
                TextButton(
                  key: ValueKey('molestia-ya-no-${m.id}'),
                  onPressed: () async {
                    await almacen.guardar(m.yaNo(hoy));
                    recargar();
                  },
                  child: const Text(TextosGimnasio.molestiaYaNo),
                ),
                TextButton(
                  onPressed: () async {
                    await almacen.quitar(m.id);
                    recargar();
                  },
                  child: const Text('Quitar'),
                ),
              ],
            ),
          ),
          SizedBox(height: v.espacio),
        ],
        for (final m in cerradas)
          FilaMolestia(
            zonaTexto: textoDeZona(m.zona),
            nivel: nivelDe(m.intensidad),
            desdeTexto: 'desde el ${m.desde.day}/${m.desde.month}',
            activa: false,
            alTocar: () async {
              await almacen.quitar(m.id);
              recargar();
            },
          ),
      ],
    );
  }
}

class _DialogoMolestia extends StatefulWidget {
  const _DialogoMolestia({required this.hoy});

  final DateTime hoy;

  @override
  State<_DialogoMolestia> createState() => _EstadoDialogoMolestia();
}

class _EstadoDialogoMolestia extends State<_DialogoMolestia> {
  String _zona = Zonas.hombro;
  int _intensidad = 1;
  final _nota = TextEditingController();

  @override
  void dispose() {
    _nota.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text(TextosHabitosGimnasio.molestiaAgregar),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(TextosHabitosGimnasio.molestiaZona),
          Wrap(
            spacing: 8,
            children: [
              for (final z in Zonas.todas)
                ChoiceChip(
                  key: ValueKey('zona-$z'),
                  label: Text(textoDeZona(z)),
                  selected: _zona == z,
                  onSelected: (_) => setState(() => _zona = z),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(TextosHabitosGimnasio.molestiaIntensidad),
          SegmentedButton<int>(
            key: const ValueKey('intensidad'),
            segments: [
              for (final n in NivelMolestia.values)
                ButtonSegment(
                  value: n.index + 1,
                  label: Text(n.texto),
                  icon: Icon(n.icono),
                ),
            ],
            selected: {_intensidad},
            onSelectionChanged: (s) => setState(() => _intensidad = s.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nota,
            maxLength: 200,
            decoration: const InputDecoration(
              labelText: TextosHabitosGimnasio.molestiaNota,
            ),
          ),
          const Text(TextosGimnasio.molestiaSoloEnEsteEquipo),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        key: const ValueKey('molestia-guardar'),
        onPressed: () => Navigator.pop(
          context,
          Molestia(
            id: const Uuid().v4(),
            zona: _zona,
            intensidad: _intensidad,
            desde: widget.hoy,
            nota: _nota.text.trim().isEmpty ? null : _nota.text.trim(),
          ),
        ),
        child: const Text(TextosHabitosGimnasio.guardar),
      ),
    ],
  );
}
