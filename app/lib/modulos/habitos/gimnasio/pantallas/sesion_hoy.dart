/// E4 · Sesión de hoy (vista previa): calentamiento, ejercicios con series y
/// carga sugerida, avisos, versión y *Empezar* (7.1).
///
/// - La duración que se ve es la **estimada real** (5.5): 30, 45 y 60 son
///   metas con tolerancia.
/// - «Contenido en revisión» mientras el catálogo sea borrador (PG-25).
/// - Las molestias y el modo foco solo se aplican con lo que este equipo sabe;
///   si no se pueden leer aquí, la pantalla lo dice.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:habitos_dominio/habitos_dominio.dart' hide EstadoDiaPlan;

import '../../../../app/gimnasio/acceso_gimnasio.dart';
import '../../../../diseno/gimnasio/gimnasio.dart';
import '../../../../diseno/valores_diseno.dart';
import '../../estado/proveedores.dart' show versionHabitosProvider;
import '../datos/modelos_gimnasio.dart';
import '../estado/proveedores_gimnasio.dart';
import 'comun.dart';

/// La sesión de [fecha] con la plantilla y versión que se piden (`null` = las
/// del plan y la automática).
final entrenamientoVariadoProvider =
    FutureProvider.family<EntrenamientoHoy?, ({String? tipo, VersionSesion? version})>(
      (ref, p) async {
        ref.watch(versionGimnasioProvider);
        ref.watch(versionHabitosProvider);
        final s = ref.watch(servicioGimnasioProvider);
        if (s == null) return null;
        return s.entrenamientoDe(
          ref.watch(fechaDeHoyGimnasioProvider),
          tipo: p.tipo,
          version: p.version,
        );
      },
    );

class PantallaSesionDeHoy extends ConsumerStatefulWidget {
  const PantallaSesionDeHoy({super.key});

  @override
  ConsumerState<PantallaSesionDeHoy> createState() => _EstadoSesionDeHoy();
}

class _EstadoSesionDeHoy extends ConsumerState<PantallaSesionDeHoy> {
  String? _tipo;
  VersionSesion? _version;
  EstadoAnimo? _animo;

  @override
  Widget build(BuildContext context) {
    final servicio = ref.watch(servicioGimnasioProvider);
    final base = ref.watch(
      entrenamientoVariadoProvider((tipo: _tipo, version: null)),
    );
    final actual = _version == null
        ? base
        : ref.watch(
            entrenamientoVariadoProvider((tipo: _tipo, version: _version)),
          );
    return MarcoGimnasio(
      destino: DestinoGimnasio.sesion,
      cuerpo: servicio == null
          ? const SinPersonaGimnasio()
          : vistaAsincrona<EntrenamientoHoy?>(
              actual,
              alReintentar: () => ref.invalidate(entrenamientoVariadoProvider),
              listo: (h) {
                if (h == null) return const SinPersonaGimnasio();
                return _Contenido(
                  h: h,
                  base: base.value ?? h,
                  version: _version,
                  animo: _animo,
                  alElegirVersion: (v) => setState(() => _version = v),
                  alElegirAnimo: (a) => setState(() => _animo = a),
                  alVerRegenerativa: () => setState(() {
                    _tipo = proponerRegenerativa(EstadoAnimo.cansado);
                    _version = null;
                  }),
                  alVolverALaPlantilla: () => setState(() {
                    _tipo = null;
                    _version = null;
                  }),
                  cambiado: _tipo != null,
                );
              },
            ),
    );
  }
}

class _Contenido extends ConsumerWidget {
  const _Contenido({
    required this.h,
    required this.base,
    required this.version,
    required this.animo,
    required this.alElegirVersion,
    required this.alElegirAnimo,
    required this.alVerRegenerativa,
    required this.alVolverALaPlantilla,
    required this.cambiado,
  });

  final EntrenamientoHoy h;
  final EntrenamientoHoy base;
  final VersionSesion? version;
  final EstadoAnimo? animo;
  final ValueChanged<VersionSesion> alElegirVersion;
  final ValueChanged<EstadoAnimo> alElegirAnimo;
  final VoidCallback alVerRegenerativa;
  final VoidCallback alVolverALaPlantilla;
  final bool cambiado;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicio = ref.watch(servicioGimnasioProvider)!;
    final datos = ref.watch(datosGimnasioProvider).value;
    final inv = datos?.inventario ?? Inventario.inicial();
    final v = ValoresDiseno.de(context);
    final gap = SizedBox(height: v.espacio * 2);
    final c = servicio.catalogo;
    if (!h.esSesion) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            h.tipo == TipoDia.bici
                ? TextosHabitosGimnasio.hoyBicicleta
                : TextosHabitosGimnasio.hoyDescanso,
            style: v.lectura(tamano: 16),
          ),
        ],
      );
    }
    final nombre = nombreDePlantilla(c, h.tipo);
    final avisos = avisosDe(h);
    final rutaEmpezar = rutaConParametros(DestinoGimnasio.sesionEnCurso, {
      if (cambiado) 'tipo': h.tipo,
      if (version != null) 'version': version!.id,
    });
    final hecho =
        h.estado == EstadoEntrenamientoDia.hecho ||
        h.estado == EstadoEntrenamientoDia.parcial;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Semantics(
          header: true,
          child: Text(nombre, style: v.titulo(tamano: 24)),
        ),
        Text(
          [
            if (h.version != null && h.esFuerza) textoVersion(h.version!),
            if (h.inicioMin != null) horaTexto(h.inicioMin!),
            if (h.duracionSeg != null) textoDuracion(h.duracionSeg!),
          ].join(' · '),
          style: v.numero(tamano: 15, color: v.textoTenue),
        ),
        if (h.esFuerza && h.sesion!.semanaTipo != TipoSemana.carga) ...[
          const SizedBox(height: 8),
          MarcaGimnasio(
            texto: semanaVista(h.sesion!.semanaTipo).texto,
            icono: semanaVista(h.sesion!.semanaTipo).icono,
          ),
        ],
        gap,
        if (h.contenidoEnRevision) ...[
          const TarjetaContenidoEnRevision(compacta: true),
          gap,
        ],
        for (final a in avisos)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 20, color: v.alerta),
                const SizedBox(width: 8),
                Expanded(child: Text(a)),
              ],
            ),
          ),
        if (!h.modoFocoLegible)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              TextosHabitosGimnasio.modoFocoNoLegible,
              key: ValueKey('foco-no-legible'),
            ),
          ),
        if (h.esFuerza && !h.molestiasLegibles)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(TextosGimnasio.molestiaOtroEquipo),
          ),
        if (h.avisoDormir != null) ...[
          _OpcionesDormir(
            aviso: h.avisoDormir!,
            alCorta: () => alElegirVersion(VersionSesion.corta),
            alRegenerativa: alVerRegenerativa,
          ),
          gap,
        ],
        if (h.noCabe && h.esFuerza) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => context.go(DestinoGimnasio.plan.ruta),
                child: const Text('Mover el bloque'),
              ),
              OutlinedButton(
                onPressed: alVerRegenerativa,
                child: const Text(TextosHabitosGimnasio.verRegenerativa),
              ),
            ],
          ),
          gap,
        ],
        if (h.esFuerza && !hecho) ...[
          Text(TextosHabitosGimnasio.comoAmaneciste, style: v.titulo(tamano: 15)),
          const SizedBox(height: 8),
          SegmentedButton<EstadoAnimo>(
            key: const ValueKey('animo'),
            emptySelectionAllowed: true,
            segments: const [
              ButtonSegment(
                value: EstadoAnimo.descansado,
                label: Text(TextosHabitosGimnasio.descansado),
              ),
              ButtonSegment(
                value: EstadoAnimo.normal,
                label: Text(TextosHabitosGimnasio.normal),
              ),
              ButtonSegment(
                value: EstadoAnimo.cansado,
                label: Text(TextosHabitosGimnasio.cansado),
              ),
            ],
            selected: {?animo},
            onSelectionChanged: (s) {
              if (s.isNotEmpty) alElegirAnimo(s.first);
            },
          ),
          if (animo == EstadoAnimo.cansado) ...[
            const SizedBox(height: 8),
            const Text(TextosHabitosGimnasio.proponemosRegenerativa),
            TextButton(
              key: const ValueKey('ver-regenerativa'),
              onPressed: alVerRegenerativa,
              child: const Text(TextosHabitosGimnasio.verRegenerativa),
            ),
          ],
          gap,
        ],
        if (cambiado)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: alVolverALaPlantilla,
              child: const Text('Volver a la sesión del plan'),
            ),
          ),
        if (h.esFuerza) ...[
          Text('Versión', style: v.titulo(tamano: 15)),
          const SizedBox(height: 8),
          SegmentedButton<VersionSesion>(
            key: const ValueKey('version'),
            segments: [
              for (final ver in VersionSesion.values)
                ButtonSegment(
                  value: ver,
                  label: Text(
                    '${textoVersion(ver)}'
                    '${base.eleccion == null ? '' : ' ${textoDuracion(base.eleccion!.duraciones[ver]!)}'}',
                  ),
                ),
            ],
            selected: {h.version!},
            onSelectionChanged: (s) => alElegirVersion(s.first),
          ),
          gap,
          if (h.sesion!.calentamiento.isNotEmpty)
            _LineaBloques(
              titulo: '${TextosHabitosGimnasio.calentamiento} · '
                  '${h.sesion!.calentamientoMin} min',
              ids: h.sesion!.calentamiento,
              catalogo: c,
            ),
          for (var i = 0; i < h.sesion!.ejercicios.length; i++) ...[
            const SizedBox(height: 8),
            FilaEjercicioPlan(
              numero: i + 1,
              total: h.sesion!.ejercicios.length,
              datos: vistaDeEjercicio(h.sesion!.ejercicios[i], c, inv),
            ),
          ],
          if (h.sesion!.ejercicios.any((e) => e.cargaPasos == null && e.bandaId == null))
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(MensajesGimnasio.primeraCarga),
            ),
          if (h.sesion!.cierre.isNotEmpty) ...[
            const SizedBox(height: 8),
            _LineaBloques(
              titulo: 'Cierre · ${h.sesion!.cierreMin} min',
              ids: h.sesion!.cierre,
              catalogo: c,
            ),
          ],
        ] else ...[
          for (final b in h.regenerativa!.bloques)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.self_improvement),
              title: Text(c.bloque(b.bloqueId)?.nombre ?? b.bloqueId),
              subtitle: Text(c.bloque(b.bloqueId)?.instruccion ?? ''),
              trailing: Text('${b.minutos} min'),
            ),
        ],
        gap,
        if (hecho)
          Text(
            h.estado == EstadoEntrenamientoDia.hecho
                ? EstadoDiaPlan.hecho.texto
                : EstadoDiaPlan.parcial.texto,
            style: v.lectura(tamano: 16),
          )
        else
          FilledButton.icon(
            key: const ValueKey('sesion-empezar'),
            onPressed: () => context.go(rutaEmpezar),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            icon: const Icon(Icons.play_arrow),
            label: Text(
              h.estado == EstadoEntrenamientoDia.enCurso ? 'Continuar' : 'Empezar',
            ),
          ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => context.go(DestinoGimnasio.registro.ruta),
          child: const Text(TextosHabitosGimnasio.registrarLoQueHice),
        ),
      ],
    );
  }
}

class _OpcionesDormir extends StatelessWidget {
  const _OpcionesDormir({
    required this.aviso,
    required this.alCorta,
    required this.alRegenerativa,
  });

  final AvisoDormir aviso;
  final VoidCallback alCorta;
  final VoidCallback alRegenerativa;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final o in aviso.opciones)
        switch (o) {
          OpcionDormir.versionMasCorta => OutlinedButton(
            onPressed: alCorta,
            child: Text(textoDeOpcionDormir(o)),
          ),
          OpcionDormir.regenerativa => OutlinedButton(
            onPressed: alRegenerativa,
            child: Text(textoDeOpcionDormir(o)),
          ),
          _ => Chip(label: Text(textoDeOpcionDormir(o))),
        },
    ],
  );
}

class _LineaBloques extends StatelessWidget {
  const _LineaBloques({
    required this.titulo,
    required this.ids,
    required this.catalogo,
  });

  final String titulo;
  final List<String> ids;
  final Catalogo catalogo;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: v.titulo(tamano: 15)),
        Text(
          [for (final id in ids) catalogo.bloque(id)?.nombre ?? id].join(' · '),
          style: v.lectura(tamano: 14, color: v.textoTenue),
        ),
      ],
    );
  }
}
