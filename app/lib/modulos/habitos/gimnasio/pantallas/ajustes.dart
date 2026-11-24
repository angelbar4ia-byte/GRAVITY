/// E10 · Ajustes de «Mi gimnasio»: ciclo, ventana, objetivo y nivel, descanso,
/// margen antes de dormir, voz en el descanso y «Sobre esta guía» (7.1 y 5).
///
/// Los valores de partida de la persona (decisión del dueño, 23/nov/2026):
/// objetivo «salud general», nivel «principiante» y la voz en el descanso
/// apagada.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:habitos_dominio/habitos_dominio.dart' hide EstadoDiaPlan;

import '../../../../app/gimnasio/acceso_gimnasio.dart';
import '../../../../diseno/componentes/tarjeta_modulo.dart';
import '../../../../diseno/gimnasio/gimnasio.dart';
import '../../../../diseno/valores_diseno.dart';
import '../../../../nucleo/contratos/rutas.dart';
import '../../estado/proveedores.dart' show versionHabitosProvider;
import '../casos_uso/servicio_gimnasio.dart';
import '../datos/conversion_gimnasio.dart';
import '../datos/modelos_gimnasio.dart';
import '../estado/proveedores_gimnasio.dart';
import 'comun.dart';
import 'plan.dart' show SelectorVentana;

class PantallaAjustesGimnasio extends ConsumerWidget {
  const PantallaAjustesGimnasio({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicio = ref.watch(servicioGimnasioProvider);
    return MarcoGimnasio(
      destino: DestinoGimnasio.ajustes,
      cuerpo: servicio == null
          ? const SinPersonaGimnasio()
          : vistaAsincrona<DatosGimnasio?>(
              ref.watch(datosGimnasioProvider),
              alReintentar: () => ref.invalidate(datosGimnasioProvider),
              listo: (d) => d == null
                  ? const SinPersonaGimnasio()
                  : _Cuerpo(datos: d, servicio: servicio),
            ),
    );
  }
}

class _Cuerpo extends ConsumerWidget {
  const _Cuerpo({required this.datos, required this.servicio});

  final DatosGimnasio datos;
  final ServicioGimnasio servicio;

  Future<void> _guardar(WidgetRef ref, Map<String, Object?> cambios) async {
    await servicio.guardarPerfil(cambios);
    ref.read(versionGimnasioProvider.notifier).state++;
    ref.read(versionHabitosProvider.notifier).state++;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = datos.perfil;
    final r = servicio.reglas;
    final v = ValoresDiseno.de(context);
    final gap = SizedBox(height: v.espacio * 2);
    final descanso = p.descansoS;
    final ciclo = p.cicloSemanas;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TarjetaModulo(
          titulo: 'Valores del plan',
          icono: Icons.tune,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SelectorPasos(
                etiqueta: 'DESCANSO ENTRE SERIES',
                valorTexto: descanso == null ? 'El de la versión' : '$descanso s',
                descripcionAccesible: descanso == null
                    ? 'Descanso entre series: el de cada versión'
                    : 'Descanso entre series: $descanso segundos',
                etiquetaMenos: 'Quitar 15 segundos de descanso',
                etiquetaMas: 'Agregar 15 segundos de descanso',
                alMenos: (descanso ?? 60) - r.pasoDescansoS >= r.descansoPisoS
                    ? () => _guardar(ref, {
                        'descanso_s': (descanso ?? 60) - r.pasoDescansoS,
                      })
                    : null,
                alMas: (descanso ?? 60) + r.pasoDescansoS <= r.descansoTopeS
                    ? () => _guardar(ref, {
                        'descanso_s': (descanso ?? 60) + r.pasoDescansoS,
                      })
                    : null,
              ),
              if (descanso != null)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    onPressed: () => _guardar(ref, {'descanso_s': null}),
                    child: const Text('Volver al descanso de cada versión'),
                  ),
                ),
              if (descanso != null &&
                  (descanso < r.descansoMinimoS ||
                      descanso > r.descansoMaximoS))
                const Text(
                  'Fuera de 45 a 75 s: queda como lo elegiste, solo es un '
                  'aviso.',
                ),
              gap,
              SelectorPasos(
                etiqueta: 'CICLO (CARGA Y DESCARGA)',
                valorTexto: ciclo == 0 ? 'Sin descarga' : '$ciclo semanas',
                descripcionAccesible: ciclo == 0
                    ? TextosHabitosGimnasio.ajustesSinDescarga
                    : 'Ciclo de $ciclo semanas, la última de descarga',
                etiquetaMenos: 'Un ciclo más corto',
                etiquetaMas: 'Un ciclo más largo',
                alMenos: ciclo == 0
                    ? null
                    : () => _guardar(ref, {
                        'ciclo_semanas': ciclo <= r.cicloMinimo ? 0 : ciclo - 1,
                      }),
                alMas: ciclo >= r.cicloMaximo
                    ? null
                    : () => _guardar(ref, {
                        'ciclo_semanas': ciclo == 0 ? r.cicloMinimo : ciclo + 1,
                      }),
              ),
              gap,
              SelectorPasos(
                etiqueta: 'AVISO ANTES DE DORMIR',
                valorTexto: '${p.margenDormirMin} min',
                descripcionAccesible:
                    'Avisar si termino a menos de ${p.margenDormirMin} minutos de dormir',
                etiquetaMenos: 'Quitar 15 minutos',
                etiquetaMas: 'Agregar 15 minutos',
                alMenos: p.margenDormirMin >= 15
                    ? () => _guardar(ref, {
                        'margen_dormir_min': p.margenDormirMin - 15,
                      })
                    : null,
                alMas: p.margenDormirMin <= 225
                    ? () => _guardar(ref, {
                        'margen_dormir_min': p.margenDormirMin + 15,
                      })
                    : null,
              ),
            ],
          ),
        ),
        gap,
        TarjetaModulo(
          titulo: 'Cuándo entrenas',
          icono: Icons.schedule,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectorVentana(
                datos: datos,
                alElegir: (x) => _guardar(ref, {'ventana': x.id}),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const ValueKey('noche-desde'),
                onPressed: () async {
                  final t = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(
                      hour: p.nocheDesdeMin ~/ 60,
                      minute: p.nocheDesdeMin % 60,
                    ),
                  );
                  if (t == null) return;
                  await _guardar(ref, {
                    'noche_desde': horaDeMinutos(t.hour * 60 + t.minute),
                  });
                },
                icon: const Icon(Icons.nightlight_outlined),
                label: Text('Por la noche, desde ${horaTexto(p.nocheDesdeMin)}'),
              ),
            ],
          ),
        ),
        gap,
        TarjetaModulo(
          titulo: 'Tu punto de partida',
          icono: Icons.flag_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Objetivo'),
              Wrap(
                spacing: 8,
                children: [
                  for (final o in ObjetivoGimnasio.values)
                    ChoiceChip(
                      key: ValueKey('objetivo-${o.id}'),
                      label: Text(_objetivo(o)),
                      selected: p.objetivo == o,
                      onSelected: (_) => _guardar(ref, {'objetivo': o.id}),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Nivel'),
              Wrap(
                spacing: 8,
                children: [
                  for (final n in NivelGimnasio.values)
                    ChoiceChip(
                      key: ValueKey('nivel-${n.id}'),
                      label: Text(
                        n == NivelGimnasio.principiante
                            ? 'Principiante'
                            : 'Intermedio',
                      ),
                      selected: p.nivel == n,
                      onSelected: (_) => _guardar(ref, {'nivel': n.id}),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Solo cambia los valores de partida (repeticiones y descanso '
                'por omisión); no calcula calorías ni masa.',
              ),
            ],
          ),
        ),
        gap,
        TarjetaModulo(
          titulo: TextosHabitosGimnasio.ajustesVoz,
          icono: Icons.record_voice_over_outlined,
          child: SwitchListTile(
            key: const ValueKey('voz-descanso'),
            contentPadding: EdgeInsets.zero,
            title: const Text(TextosHabitosGimnasio.ajustesVoz),
            subtitle: const Text(TextosHabitosGimnasio.ajustesVozAyuda),
            value: datos.perfilFila?.vozDescanso ?? false,
            onChanged: (x) => _guardar(ref, {'voz_descanso': x}),
          ),
        ),
        gap,
        TarjetaModulo(
          titulo: TextosGimnasio.sobreEstaGuia,
          icono: Icons.info_outline,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: const [
              Text(MensajesGimnasio.guiaGeneral),
              SizedBox(height: 8),
              Text(MensajesGimnasio.consultaAntesDeEmpezar),
              SizedBox(height: 8),
              TarjetaContenidoEnRevision(compacta: true),
            ],
          ),
        ),
        gap,
        TarjetaModulo(
          titulo: 'Mis datos',
          icono: Icons.lock_outline,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Mis datos de Hábitos'),
            subtitle: const Text(
              'Exportar o borrar lo del gimnasio, en Ajustes.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go(Rutas.ajustes),
          ),
        ),
      ],
    );
  }

  String _objetivo(ObjetivoGimnasio o) => switch (o) {
    ObjetivoGimnasio.fuerza => 'Fuerza',
    ObjetivoGimnasio.masa => 'Masa',
    ObjetivoGimnasio.perdidaGrasa => 'Pérdida de grasa',
    ObjetivoGimnasio.saludGeneral => 'Salud general',
  };
}
