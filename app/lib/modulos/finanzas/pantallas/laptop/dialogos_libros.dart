/// Libros compartidos (respuestas del dueño del 23/oct/2026, D19): quien lo
/// crea es su **administrador**; agrega y saca miembros, decide si es
/// **pública o privada** y lo archiva o reactiva. Cualquier miembro puede
/// **salirse**, menos el último; si quedan menos de 2 miembros, el presupuesto
/// pasa a **privado** y sigue activo (2.ª ronda: ya no se archiva; archivar es
/// solo una decisión explícita del administrador).
library;

import 'package:finanzas_dominio/finanzas_dominio.dart'
    as dom
    show Libro, TipoLibro, VisibilidadLibro;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../diseno/diseno.dart'
    show formatearCentavos, montoOculto, montosOcultosProvider;
import '../../estado/proveedores.dart';
import '../comunes.dart';

/// Texto corto de la visibilidad de un compartido.
String nombreVisibilidad(dom.VisibilidadLibro v) => switch (v) {
  dom.VisibilidadLibro.privada => 'Privada',
  dom.VisibilidadLibro.publica => 'Pública',
};

/// Lo que explica cada visibilidad.
String explicacionVisibilidad(dom.VisibilidadLibro v) => switch (v) {
  dom.VisibilidadLibro.privada =>
    'La ven y escriben sus miembros; la lee también la cuenta maestra. El '
        'dueño no entra si no es miembro.',
  dom.VisibilidadLibro.publica =>
    'Además la leen, sin escribir, los adultos con Finanzas del hogar.',
};

/// Selector de visibilidad (privada por omisión).
class SelectorVisibilidad extends StatelessWidget {
  const SelectorVisibilidad({
    super.key,
    required this.valor,
    required this.alCambiar,
    this.habilitado = true,
  });

  final dom.VisibilidadLibro valor;
  final ValueChanged<dom.VisibilidadLibro> alCambiar;
  final bool habilitado;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SegmentedButton<dom.VisibilidadLibro>(
        key: const ValueKey('libro-visibilidad'),
        segments: [
          ButtonSegment(
            value: dom.VisibilidadLibro.privada,
            icon: const Icon(Icons.lock_person_outlined),
            label: Text(nombreVisibilidad(dom.VisibilidadLibro.privada)),
          ),
          ButtonSegment(
            value: dom.VisibilidadLibro.publica,
            icon: const Icon(Icons.public),
            label: Text(nombreVisibilidad(dom.VisibilidadLibro.publica)),
          ),
        ],
        selected: {valor},
        onSelectionChanged: habilitado ? (s) => alCambiar(s.first) : null,
      ),
      const SizedBox(height: 4),
      Text(
        explicacionVisibilidad(valor),
        key: const ValueKey('libro-visibilidad-explicacion'),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );
}

/// Se sale del libro (cualquier miembro, menos el último), con el aviso de lo
/// que pasa: si quedan menos de 2, el presupuesto queda **privado** para quien
/// se queda; si el libro tiene saldo, un aviso informativo (no bloquea).
Future<void> salirDelLibro(
  BuildContext context,
  WidgetRef ref,
  ContextoFinanzas c,
  dom.Libro libro,
) async {
  final quedaPrivado = libro.quedaPrivadoAlSalir(c.hoy);
  final esAdmin = libro.esAdministrador(c.personaId);
  final saldo = c.datos.vista(libro.id).balance().patrimonio;
  final oculto = ref.read(montosOcultosProvider);
  final ok = await confirmar(
    context,
    titulo: 'Salir de ${libro.nombre}',
    mensaje: [
      'Dejarás de ver y registrar en este libro.',
      if (quedaPrivado)
        'Quedarán menos de 2 miembros: el presupuesto queda privado para '
            'quien se queda, que será su administrador.',
      if (esAdmin && !quedaPrivado)
        'Dejas de ser su administrador: el cargo pasa al miembro más antiguo.',
      'Lo que registraste se queda en el historial del libro.',
      if (saldo != 0)
        'El presupuesto tiene ${oculto ? montoOculto : formatearCentavos(saldo)}'
            '; lo que aportaste se queda aquí.',
    ].join(' '),
    textoAccion: 'Salir del libro',
  );
  if (!ok || !context.mounted) return;
  await intentar(context, () async {
    await ref.read(servicioFinanzasProvider).salirDelLibro(libro.id);
    // Si era el libro abierto, el selector pasa al primero que quede.
    ref.read(libroElegidoProvider.notifier).alaPortada();
  });
}

/// Administra un compartido: visibilidad, miembros y archivado.
class DialogoMiembrosLibro extends ConsumerStatefulWidget {
  const DialogoMiembrosLibro({super.key, required this.libroId});

  final String libroId;

  @override
  ConsumerState<DialogoMiembrosLibro> createState() =>
      _DialogoMiembrosLibroState();
}

class _DialogoMiembrosLibroState extends ConsumerState<DialogoMiembrosLibro> {
  String? _agregar;
  bool _ocupado = false;

  Future<void> _hacer(Future<void> Function() accion) async {
    setState(() => _ocupado = true);
    await intentar(context, accion);
    if (mounted) setState(() => _ocupado = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(contextoFinanzasProvider).value;
    final libro = c?.datos.libro(widget.libroId);
    if (c == null || libro == null || libro.tipo != dom.TipoLibro.compartido) {
      return const AlertDialog(
        content: Text('Ese libro ya no está disponible.'),
      );
    }
    final servicio = ref.read(servicioFinanzasProvider);
    final puedeMiembros = c.administraMiembrosDe(libro);
    final esAdmin = libro.esAdministrador(c.personaId) && !c.soloLecturaTotal;
    final vigentes = libro.vigentes(c.hoy);
    final candidatos = [
      for (final p in c.carga.adultosConFinanzas)
        if (libro.papelDe(p, c.hoy) == null) p,
    ];
    // Sacar a alguien con solo 2 miembros deja el libro con uno: pasa a privado.
    final avisoPrivado = vigentes.length <= 2;
    return AlertDialog(
      title: Text(libro.nombre),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (libro.archivado)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Archivado: solo lectura para todos.',
                    key: const ValueKey('libro-archivado-aviso'),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              const Text('Visibilidad'),
              const SizedBox(height: 4),
              SelectorVisibilidad(
                valor: libro.visibilidad,
                habilitado: esAdmin && !_ocupado,
                alCambiar: (v) =>
                    _hacer(() => servicio.cambiarVisibilidadLibro(libro.id, v)),
              ),
              const SizedBox(height: 12),
              Text('Miembros', style: Theme.of(context).textTheme.titleSmall),
              for (final m in vigentes)
                ListTile(
                  key: ValueKey('miembro-${m.personaId}'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(c.carga.nombreDe(m.personaId)),
                  subtitle: libro.esAdministrador(m.personaId)
                      ? const Text('Administrador')
                      : null,
                  trailing: puedeMiembros && m.personaId != c.personaId
                      ? IconButton(
                          key: ValueKey('miembro-quitar-${m.personaId}'),
                          tooltip: 'Sacar del libro',
                          icon: const Icon(Icons.person_remove_outlined),
                          onPressed: _ocupado
                              ? null
                              : () async {
                                  if (avisoPrivado) {
                                    final ok = await confirmar(
                                      context,
                                      titulo: 'Sacar a ${c.carga.nombreDe(m.personaId)}',
                                      mensaje:
                                          'Quedará menos de 2 miembros: el '
                                          'presupuesto pasa a privado y sigue '
                                          'activo para ti.',
                                      textoAccion: 'Sacar',
                                    );
                                    if (!ok) return;
                                  }
                                  await _hacer(
                                    () => servicio.quitarMiembroLibro(
                                      libro.id,
                                      m.personaId,
                                    ),
                                  );
                                },
                        )
                      : null,
                ),
              if (puedeMiembros && candidatos.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: const ValueKey('miembro-agregar'),
                        initialValue: _agregar,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Agregar a un adulto del hogar',
                        ),
                        items: [
                          for (final p in candidatos)
                            DropdownMenuItem(
                              value: p,
                              child: Text(c.carga.nombreDe(p)),
                            ),
                        ],
                        onChanged: (p) => setState(() => _agregar = p),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      key: const ValueKey('miembro-agregar-boton'),
                      onPressed: _agregar == null || _ocupado
                          ? null
                          : () => _hacer(() async {
                              await servicio.agregarMiembroLibro(
                                libro.id,
                                _agregar!,
                              );
                              _agregar = null;
                            }),
                      child: const Text('Agregar'),
                    ),
                  ],
                ),
              ],
              if (esAdmin) ...[
                const SizedBox(height: 12),
                if (libro.archivado)
                  OutlinedButton.icon(
                    key: const ValueKey('libro-reactivar'),
                    onPressed: _ocupado
                        ? null
                        : () => _hacer(() => servicio.reactivarLibro(libro.id)),
                    icon: const Icon(Icons.unarchive_outlined),
                    label: const Text('Reactivar libro'),
                  )
                else
                  OutlinedButton.icon(
                    key: const ValueKey('libro-archivar'),
                    onPressed: _ocupado
                        ? null
                        : () async {
                            final ok = await confirmar(
                              context,
                              titulo: 'Archivar ${libro.nombre}',
                              mensaje:
                                  'El libro pasa a solo lectura para todos; '
                                  'puedes reactivarlo después. Lo registrado '
                                  'se conserva.',
                              textoAccion: 'Archivar',
                            );
                            if (ok) {
                              await _hacer(
                                () => servicio.archivarLibro(libro.id),
                              );
                            }
                          },
                    icon: const Icon(Icons.archive_outlined),
                    label: const Text('Archivar libro'),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('libro-miembros-cerrar'),
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}
