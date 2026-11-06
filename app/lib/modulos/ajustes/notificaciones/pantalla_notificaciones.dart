/// Ajustes › Notificaciones: avisos al teléfono y a la pulsera (D7, D15, D20).
///
/// Interruptor de avisos en este equipo (con el permiso de Android explicado
/// antes de pedirlo), horas silenciosas, tope diario, tipos silenciados, vista
/// previa de la pantalla bloqueada y la pulsera, aviso de prueba y la guía de la
/// pulsera. La tablet pública de la casa nunca recibe avisos personales; la
/// tablet personal los trae apagados; la laptop los ve con la app abierta.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/avisos/con_avisos.dart';
import '../../../nucleo/avisos/aviso.dart';
import '../../../nucleo/avisos/catalogo_avisos.dart';
import '../../../nucleo/avisos/proveedores_avisos.dart';
import '../../../nucleo/avisos/repositorio_avisos.dart';
import '../../../nucleo/avisos/servicio_avisos.dart' show ContextoAvisos;
import '../../../nucleo/firebase/firebase.dart';
import '../marco_seccion.dart';
import '../secciones_ajustes.dart';

String textoEstadoFirebase(EstadoFirebase estado) => switch (estado) {
  EstadoFirebase.activo => 'Avisos al instante: listos (Firebase activo).',
  EstadoFirebase.sinConfiguracion =>
    'Avisos al instante apagados: falta la configuración de Firebase.',
  EstadoFirebase.noAplica =>
    'En este dispositivo los avisos al instante no aplican (solo Android).',
};

/// Tipos que se pueden silenciar, con su título (los dos de base y los dos de
/// salida comparten texto: se listan una vez).
final List<MapEntry<String, String>> tiposSilenciables = [
  for (final e in titulosDeAviso.entries)
    if (e.key != 'base_90' && e.key != 'retiro_bolsa_compartida') e,
];

/// Estado del servicio para la pantalla.
class EstadoAvisosEquipo {
  const EstadoAvisosEquipo({
    required this.activado,
    required this.permiso,
    required this.preferencias,
  });

  final bool activado;
  final bool permiso;
  final PreferenciasAvisos preferencias;
}

final estadoAvisosEquipoProvider =
    FutureProvider.autoDispose<EstadoAvisosEquipo>((ref) async {
      final servicio = ref.watch(servicioAvisosProvider);
      final repo = ref.watch(repositorioAvisosProvider);
      PreferenciasAvisos? preferencias;
      try {
        preferencias = await repo?.preferencias();
      } catch (_) {}
      return EstadoAvisosEquipo(
        activado: await servicio.activado(),
        permiso: await ref.watch(notificadorProvider).permisoConcedido(),
        preferencias: preferencias ?? const PreferenciasAvisos(),
      );
    });

class PantallaNotificaciones extends ConsumerWidget {
  const PantallaNotificaciones({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contexto = ref.watch(contextoAvisosProvider);
    final estado = ref.watch(estadoAvisosEquipoProvider);
    return MarcoSeccion(
      seccion: SeccionAjustes.notificaciones,
      hijos: [
        NotaAjustes(
          textoEstadoFirebase(ref.watch(estadoFirebaseProvider)),
          icono: Icons.notifications_outlined,
        ),
        if (contexto.tipo == TipoEquipoAvisos.tabletPublica)
          const NotaAjustes(
            'La tablet de la casa nunca muestra avisos personales ni de '
            'dinero.',
            icono: Icons.tablet_outlined,
          )
        else if (contexto.esMaestra || !contexto.puedeRecibir)
          const NotaAjustes(
            'Esta cuenta no recibe avisos de dinero.',
            icono: Icons.notifications_off_outlined,
          )
        else
          estado.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => const NotaAjustes(
              'No se pudieron leer tus preferencias de avisos.',
              icono: Icons.error_outline,
            ),
            data: (datos) => _Preferencias(datos: datos, contexto: contexto),
          ),
        const NotaAjustes(
          'Los avisos son discretos: solo un título corto, sin montos ni '
          'nombres. El detalle está dentro de GRAVITY.',
          icono: Icons.watch_outlined,
        ),
      ],
    );
  }
}

class _Preferencias extends ConsumerWidget {
  const _Preferencias({required this.datos, required this.contexto});

  final EstadoAvisosEquipo datos;
  final ContextoAvisos contexto;

  Future<void> _guardar(WidgetRef ref, PreferenciasAvisos nuevas) async {
    final error = nuevas.error;
    if (error != null) return;
    await ref.read(repositorioAvisosProvider)?.guardarPreferencias(nuevas);
    ref.read(servicioAvisosProvider).preferenciasCambiaron(nuevas);
    ref.invalidate(estadoAvisosEquipoProvider);
  }

  Future<void> _activar(
    BuildContext context,
    WidgetRef ref,
    bool activar,
  ) async {
    final servicio = ref.read(servicioAvisosProvider);
    if (activar && !datos.permiso) {
      // Se explica antes de pedir el permiso del sistema (regla 46).
      final seguir = await showDialog<bool>(
        context: context,
        builder: (contexto) => AlertDialog(
          title: const Text('Permitir avisos'),
          content: const Text(
            'Android te pedirá permiso para mostrar notificaciones. GRAVITY '
            'solo mostrará un título corto, sin montos ni nombres; el detalle '
            'está dentro de la app.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(contexto).pop(false),
              child: const Text('Ahora no'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(contexto).pop(true),
              child: const Text('Continuar'),
            ),
          ],
        ),
      );
      if (seguir != true) return;
    }
    await servicio.fijarActivado(activar);
    ref.invalidate(estadoAvisosEquipoProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = datos.preferencias;
    final esLaptop = contexto.tipo == TipoEquipoAvisos.laptop;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Column(
            children: [
              if (!esLaptop)
                SwitchListTile(
                  key: const ValueKey('avisos-activar'),
                  title: const Text('Recibir avisos en este equipo'),
                  subtitle: Text(
                    contexto.tipo == TipoEquipoAvisos.tabletPersonal
                        ? 'En la tablet personal vienen apagados.'
                        : 'Pagos próximos, alertas y resúmenes.',
                  ),
                  value: datos.activado,
                  onChanged: (valor) => _activar(context, ref, valor),
                )
              else
                const ListTile(
                  title: Text('Aviso de Windows'),
                  subtitle: Text(
                    'Con GRAVITY abierto, la bandeja se actualiza en vivo y '
                    'Windows muestra el mismo título corto.',
                  ),
                ),
              if (!esLaptop && datos.activado && !datos.permiso)
                const ListTile(
                  key: ValueKey('avisos-sin-permiso'),
                  leading: Icon(Icons.warning_amber_outlined),
                  title: Text('Falta el permiso de notificaciones'),
                  subtitle: Text(
                    'Actívalo en la configuración del sistema. Mientras tanto '
                    'los avisos siguen en la bandeja.',
                  ),
                ),
            ],
          ),
        ),
        const _RecordatoriosDeHabitos(),
        Card(
          child: Column(
            children: [
              ListTile(
                title: const Text('Horas silenciosas'),
                subtitle: Text('De ${p.silencioDesde} a ${p.silencioHasta}'),
              ),
              SwitchListTile(
                key: const ValueKey('avisos-criticas-silencio'),
                title: const Text('Las críticas también suenan en silencio'),
                value: p.criticasEnSilencio,
                onChanged: (v) =>
                    _guardar(ref, p.copiarCon(criticasEnSilencio: v)),
              ),
              ListTile(
                title: const Text('Tope diario de avisos no críticos'),
                trailing: DropdownButton<int>(
                  key: const ValueKey('avisos-tope'),
                  value: p.topeNoCriticas.clamp(0, 10),
                  items: [
                    for (var n = 0; n <= 10; n++)
                      DropdownMenuItem(value: n, child: Text('$n')),
                  ],
                  onChanged: (n) {
                    if (n != null)
                      _guardar(ref, p.copiarCon(topeNoCriticas: n));
                  },
                ),
              ),
            ],
          ),
        ),
        Card(
          child: ExpansionTile(
            title: const Text('Tipos de aviso'),
            children: [
              for (final tipo in tiposSilenciables)
                SwitchListTile(
                  key: ValueKey('avisos-tipo-${tipo.key}'),
                  title: Text(tipo.value),
                  subtitle: Text(textoSeveridadAviso(severidadDe(tipo.key))),
                  value: !p.tiposSilenciados.contains(tipo.key),
                  onChanged: (activo) => _guardar(
                    ref,
                    p.copiarCon(
                      tiposSilenciados: activo
                          ? ({...p.tiposSilenciados}..remove(tipo.key))
                          : {...p.tiposSilenciados, tipo.key},
                    ),
                  ),
                ),
            ],
          ),
        ),
        Card(
          key: const ValueKey('avisos-vista-previa'),
          child: ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Vista previa'),
            subtitle: Text(
              'Pantalla bloqueada y pulsera: "${tituloDeAviso('pago_proximo')}" '
              'y nada más (sin cuerpo). Sin sesión: "$textoAvisoGenerico".',
            ),
          ),
        ),
        if (!esLaptop)
          Card(
            child: Column(
              children: [
                ListTile(
                  key: const ValueKey('avisos-prueba'),
                  leading: const Icon(Icons.send_outlined),
                  title: const Text('Enviarme un aviso de prueba'),
                  subtitle: const Text(
                    'Muestra "$textoAvisoGenerico", igual que la pulsera.',
                  ),
                  onTap: () async {
                    final mostrado = await ref
                        .read(servicioAvisosProvider)
                        .avisoDePrueba();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          mostrado
                              ? 'Aviso de prueba enviado.'
                              : 'Falta el permiso de notificaciones.',
                        ),
                      ),
                    );
                  },
                ),
                const ListTile(
                  key: ValueKey('avisos-guia-pulsera'),
                  leading: Icon(Icons.watch_outlined),
                  title: Text('Pulsera'),
                  subtitle: Text(
                    'La pulsera repite las notificaciones del teléfono. En la '
                    'app de tu pulsera, permite las notificaciones de GRAVITY '
                    'y manda la de prueba. El patrón de vibración lo decide '
                    'la app de la pulsera.',
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

String textoSeveridadAviso(SeveridadAviso s) => switch (s) {
  SeveridadAviso.critica => 'Crítica',
  SeveridadAviso.importante => 'Importante',
  SeveridadAviso.informativa => 'Informativa',
};

/// Recordatorios locales de Hábitos (Fase 3): solo donde Hábitos es de la
/// persona y el equipo los programa (teléfono y tablet personal).
class _RecordatoriosDeHabitos extends ConsumerStatefulWidget {
  const _RecordatoriosDeHabitos();

  @override
  ConsumerState<_RecordatoriosDeHabitos> createState() =>
      _RecordatoriosDeHabitosState();
}

class _RecordatoriosDeHabitosState
    extends ConsumerState<_RecordatoriosDeHabitos> {
  bool? _activado;

  @override
  void initState() {
    super.initState();
    ref.read(recordatoriosHabitosProvider).activado().then((v) {
      if (mounted) setState(() => _activado = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final servicio = ref.watch(recordatoriosHabitosProvider);
    if (!servicio.recibe()) return const SizedBox.shrink();
    return Card(
      child: SwitchListTile(
        key: const ValueKey('recordatorios-habitos'),
        title: const Text('Recordatorios de Hábitos'),
        subtitle: const Text(
          'Se programan en este equipo, sin internet. Los reservados salen '
          'solo como "Recordatorio".',
        ),
        value: _activado ?? true,
        onChanged: _activado == null
            ? null
            : (valor) async {
                setState(() => _activado = valor);
                await servicio.fijarActivado(valor);
              },
      ),
    );
  }
}
