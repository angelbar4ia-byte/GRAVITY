/// E1 · «Entrenamiento de hoy»: la entrada de «Mi gimnasio» y la tarjeta que
/// Hoy de Hábitos reutiliza (7.1).
///
/// - **Empezar** es un toque (va a la sesión en curso) y *Hecho* es un toque,
///   sin registrar series (F-E1, CA-G-33).
/// - Sin culpa: un día sin entrenar no deja ningún aviso rojo.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:habitos_dominio/habitos_dominio.dart' hide EstadoDiaPlan;

import '../../../../app/avisos/con_avisos.dart' show tipoEquipoAvisosProvider;
import '../../../../app/gimnasio/acceso_gimnasio.dart';
import '../../../../diseno/componentes/tarjeta_modulo.dart';
import '../../../../diseno/gimnasio/gimnasio.dart';
import '../../../../diseno/valores_diseno.dart';
import '../../estado/proveedores.dart' show versionHabitosProvider;
import '../datos/conversion_gimnasio.dart';
import '../datos/modelos_gimnasio.dart';
import '../estado/proveedores_gimnasio.dart';
import 'comun.dart';

void _recargar(WidgetRef ref) {
  ref.read(versionGimnasioProvider.notifier).state++;
  ref.read(versionHabitosProvider.notifier).state++;
}

EstadoDiaPlan _estadoDia(EstadoEntrenamientoDia e) => switch (e) {
  EstadoEntrenamientoDia.hecho => EstadoDiaPlan.hecho,
  EstadoEntrenamientoDia.parcial => EstadoDiaPlan.parcial,
  _ => EstadoDiaPlan.pendiente,
};

/// La tarjeta «Entrenamiento de hoy» conectada a los datos. Si hoy no toca
/// fuerza ni regenerativa, dice qué toca (bicicleta o descanso); sin plan, no
/// ocupa lugar.
class TarjetaEntrenamientoHoyConectada extends ConsumerWidget {
  const TarjetaEntrenamientoHoyConectada({super.key, this.enHoy = false});

  /// En Hoy de Hábitos: solo si la persona ya vio la guía y hoy toca entrenar
  /// (un día de bicicleta o de descanso no ocupa lugar en Hoy).
  final bool enHoy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hoy = ref.watch(entrenamientoHoyProvider);
    final servicio = ref.watch(servicioGimnasioProvider);
    return hoy.when(
      loading: () => const TarjetaEntrenamientoHoy(
        plantillaTexto: '',
        estado: EstadoVistaGimnasio.cargando,
      ),
      error: (_, _) => TarjetaEntrenamientoHoy(
        plantillaTexto: '',
        estado: EstadoVistaGimnasio.error,
        alReintentar: () => ref.invalidate(entrenamientoHoyProvider),
      ),
      data: (h) {
        if (h == null || servicio == null) return const SizedBox.shrink();
        if (enHoy &&
            (!h.esSesion ||
                !(ref.watch(datosGimnasioProvider).value?.avisoVisto ??
                    false))) {
          return const SizedBox.shrink();
        }
        if (!h.esSesion) {
          return TarjetaModulo(
            titulo: 'Entrenamiento de hoy',
            icono: Icons.fitness_center,
            alTocar: () => context.go(RutasGimnasio.hoy),
            child: Text(
              h.tipo == TipoDia.bici
                  ? TextosHabitosGimnasio.hoyBicicleta
                  : TextosHabitosGimnasio.hoyDescanso,
            ),
          );
        }
        final nombre = nombreDePlantilla(servicio.catalogo, h.tipo);
        return TarjetaEntrenamientoHoy(
          plantillaTexto: nombre,
          versionTexto: h.version == null || h.esRegenerativa
              ? null
              : textoVersion(h.version!),
          horaTexto: h.inicioMin == null ? null : horaTexto(h.inicioMin!),
          duracionTexto: h.duracionSeg == null
              ? null
              : textoDuracion(h.duracionSeg!),
          estadoDia: _estadoDia(h.estado),
          tipoSemana: semanaVista(h.semanaTipo),
          avisoTexto: avisosDe(h).firstOrNull,
          contenidoEnRevision: h.contenidoEnRevision,
          alEmpezar: () => context.go(RutasGimnasio.sesionEnCurso),
          alAbrir: () => context.go(DestinoGimnasio.sesion.ruta),
          alHecho: () async {
            final ResultadoSesion res;
            try {
              res = await servicio.marcarHecho(h);
            } on Exception {
              // Nunca una excepción cruda: lo registrado sigue en este equipo.
              if (!context.mounted) return;
              ScaffoldMessenger.of(context)
                ..clearSnackBars()
                ..showSnackBar(
                  const SnackBar(
                    content: Text(TextosHabitosGimnasio.noSePudoTerminar),
                  ),
                );
              return;
            }
            _recargar(ref);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context)
              ..clearSnackBars()
              ..showSnackBar(
                SnackBar(
                  content: Text(
                    res.enviarDespues
                        ? '${TextosHabitosGimnasio.guardadoDeshacer}. '
                              '${TextosHabitosGimnasio.sinNubeSeEnviara}'
                        : TextosHabitosGimnasio.guardadoDeshacer,
                  ),
                  action: SnackBarAction(
                    label: TextosGimnasio.deshacer,
                    onPressed: () async {
                      await servicio.deshacerHecho(h);
                      _recargar(ref);
                    },
                  ),
                ),
              );
          },
          alDeshacer: () async {
            await servicio.deshacerHecho(h);
            _recargar(ref);
          },
        );
      },
    );
  }
}

/// La semana con el estado de cada día, para E1 y E3.
List<DiaSemanaVista> diasDeLaSemana({
  required DatosGimnasio datos,
  required DateTime hoy,
  required Catalogo catalogo,
  Set<int> conAviso = const {},
}) {
  final lunes = lunesDe(hoy);
  final inicioPlan = datos.perfil.inicioCiclo;
  return [
    for (var d = 1; d <= 7; d++)
      () {
        final dia = datos.dia(d);
        final fecha = sumarDias(lunes, d - 1);
        final iso = fechaIso(fecha);
        final fila = datos.sesionesFilas
            .where((s) => s.fecha == iso && s.plantilla == dia.tipo)
            .firstOrNull;
        final estado = switch (fila?.estado) {
          'completa' => EstadoDiaPlan.hecho,
          'parcial' => EstadoDiaPlan.parcial,
          // «Saltado» solo para días de un plan que ya empezó: antes no hay nada
          // que se haya dejado pasar (sin culpa).
          _ =>
            dia.esSesion &&
                    fila == null &&
                    fecha.isBefore(soloDia(hoy)) &&
                    inicioPlan != null &&
                    !fecha.isBefore(inicioPlan)
                ? EstadoDiaPlan.saltado
                : EstadoDiaPlan.pendiente,
        };
        final detalle = [
          if (dia.esFuerza && dia.version != 'auto')
            textoVersionId(dia.version).toLowerCase(),
          if (dia.horaMin != null) horaTexto(dia.horaMin!),
        ].join(' · ');
        return DiaSemanaVista(
          nombre: nombreDeDia(d),
          letra: letraDeDia(d),
          tipo: tipoDiaPlan(dia.tipo),
          estado: estado,
          esHoy: fecha == soloDia(hoy),
          detalleTexto: detalle.isEmpty ? null : detalle,
          conAviso: conAviso.contains(d),
        );
      }(),
  ];
}

class PantallaEntrenamientoHoy extends ConsumerWidget {
  const PantallaEntrenamientoHoy({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final equipo = ref.watch(tipoEquipoAvisosProvider);
    final datos = ref.watch(datosGimnasioProvider);
    // Baja del servidor una vez; sin conexión no pasa nada.
    ref.watch(bajadaGimnasioProvider);
    return MarcoGimnasio(
      destino: DestinoGimnasio.hoy,
      cuerpo: ref.watch(servicioGimnasioProvider) == null
          ? const SinPersonaGimnasio()
          : vistaAsincrona<DatosGimnasio?>(
              datos,
              alReintentar: () => ref.invalidate(datosGimnasioProvider),
              listo: (d) {
                if (d == null) return const SinPersonaGimnasio();
                final servicio = ref.read(servicioGimnasioProvider)!;
                final v = ValoresDiseno.de(context);
                final hoy = ref.watch(fechaDeHoyGimnasioProvider);
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (!d.avisoVisto) ...[
                      _AvisoGuia(
                        alEntendido: () async {
                          await servicio.aceptarAviso();
                          _recargar(ref);
                        },
                      ),
                      SizedBox(height: v.espacio * 2),
                    ],
                    const TarjetaEntrenamientoHoyConectada(),
                    SizedBox(height: v.espacio * 2),
                    LineaSemana(
                      titulo: 'Tu semana',
                      dias: diasDeLaSemana(
                        datos: d,
                        hoy: hoy,
                        catalogo: servicio.catalogo,
                      ),
                    ),
                    SizedBox(height: v.espacio * 2),
                    for (final destino in const [
                      DestinoGimnasio.plan,
                      DestinoGimnasio.historial,
                      DestinoGimnasio.records,
                      DestinoGimnasio.registro,
                      DestinoGimnasio.inventario,
                      DestinoGimnasio.molestias,
                      DestinoGimnasio.ajustes,
                    ])
                      if (gimnasioDisponibleEn(destino, equipo))
                        ListTile(
                          leading: Icon(_icono(destino)),
                          title: Text(destino.titulo),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.go(destino.ruta),
                        ),
                  ],
                );
              },
            ),
    );
  }

  IconData _icono(DestinoGimnasio d) => switch (d) {
    DestinoGimnasio.plan => Icons.calendar_view_week_outlined,
    DestinoGimnasio.historial => Icons.history,
    DestinoGimnasio.records => Icons.emoji_events_outlined,
    DestinoGimnasio.registro => Icons.edit_note,
    DestinoGimnasio.inventario => Icons.inventory_2_outlined,
    DestinoGimnasio.molestias => Icons.healing_outlined,
    _ => Icons.tune,
  };
}

/// «Guía general que no sustituye a un profesional» (1.2): se pide *Entendido*
/// una vez y se guarda la fecha. No pregunta ni guarda condiciones médicas.
class _AvisoGuia extends StatelessWidget {
  const _AvisoGuia({required this.alEntendido});

  final VoidCallback alEntendido;

  @override
  Widget build(BuildContext context) => TarjetaModulo(
    titulo: TextosHabitosGimnasio.guiaTitulo,
    icono: Icons.info_outline,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(MensajesGimnasio.guiaGeneral),
        const SizedBox(height: 8),
        const Text(MensajesGimnasio.consultaAntesDeEmpezar),
        const SizedBox(height: 12),
        FilledButton(
          key: const ValueKey('gimnasio-entendido'),
          onPressed: alEntendido,
          child: const Text(TextosHabitosGimnasio.entendido),
        ),
      ],
    ),
  );
}
