/// Sección de Finanzas de *Ajustes › Notificaciones* (Fase 4, E13): lo que la
/// persona puede cambiar de los avisos de dinero y que antes no se editaba en
/// pantalla: los **días antes** de cada vencimiento, las **horas silenciosas**,
/// la hora de los avisos de vencimiento, la hora del resumen del lunes y el
/// día y la hora del recordatorio de cierre.
///
/// Plataforma la monta dentro de la pantalla de Notificaciones (la pantalla es
/// suya): `const SeccionAvisosFinanzas()`. Los tipos silenciados, el tope
/// diario y las críticas en silencio ya los edita esa pantalla.
///
/// Reglas: los avisos son discretos (título corto, sin montos); el silencio
/// no puede tener la misma hora de inicio y de fin; los "días antes" son hasta
/// 3, entre 0 y 14. Los días se guardan por libro (`fin_parametros`) en los
/// libros que la persona administra y, junto con las horas, en sus
/// preferencias de avisos; al cambiar se reprograman los recordatorios
/// locales. Sin servidor (demostración) se aplican solo en este equipo.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/avisos/con_avisos.dart' show servicioAvisosProvider;
import '../../../app/sesion_efectiva.dart';
import '../../../nucleo/avisos/aviso.dart';
import '../../../nucleo/avisos/proveedores_avisos.dart';
import '../../../nucleo/contratos/roles.dart';
import '../../../nucleo/permisos/permisos.dart' as permisos;
import '../datos/repositorio.dart' show ErrorFinanzas;
import '../estado/proveedores.dart';

/// Días antes que se ofrecen (se eligen hasta 3).
const diasAntesOfrecidos = [0, 1, 2, 3, 5, 7, 14];

const _nombresDia = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];

/// Mensaje cuando el silencio empieza y termina a la misma hora.
const mensajeSilencioIgual =
    'Las horas silenciosas no pueden empezar y terminar a la misma hora.';

class SeccionAvisosFinanzas extends ConsumerStatefulWidget {
  const SeccionAvisosFinanzas({super.key});

  @override
  ConsumerState<SeccionAvisosFinanzas> createState() =>
      _SeccionAvisosFinanzasState();
}

class _SeccionAvisosFinanzasState
    extends ConsumerState<SeccionAvisosFinanzas> {
  PreferenciasAvisos? _p;
  String? _error;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    PreferenciasAvisos? leidas;
    try {
      leidas = await ref.read(repositorioAvisosProvider)?.preferencias();
    } catch (_) {
      // Sin señal: se editan las de siempre y se guardan al volver.
    }
    if (!mounted) return;
    final c = ref.read(contextoFinanzasProvider).value;
    final libro = c?.libro;
    final dias = libro == null ? null : c!.datos.parametrosDe(libro.id).diasAvisoDeuda;
    setState(() {
      final base = leidas ?? const PreferenciasAvisos();
      _p = dias == null ? base : base.copiarCon(diasAvisoDeuda: dias);
    });
  }

  Future<void> _guardar(PreferenciasAvisos nuevas, {bool conDias = false}) async {
    final actual = _p;
    if (actual == null || _guardando) return;
    String? error = nuevas.error;
    if (nuevas.silencioDesde == nuevas.silencioHasta) {
      error = mensajeSilencioIgual;
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await ref.read(repositorioAvisosProvider)?.guardarPreferencias(nuevas);
      if (conDias) await _guardarDiasPorLibro(nuevas.diasAvisoDeuda);
      ref.read(servicioAvisosProvider).preferenciasCambiaron(nuevas);
      if (mounted) setState(() => _p = nuevas);
    } on ErrorFinanzas catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No se pudo guardar. Revisa tu señal e inténtalo de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  /// Los días antes son del libro (`fin_parametros`): se actualizan en los
  /// libros que la persona administra.
  Future<void> _guardarDiasPorLibro(List<int> dias) async {
    final c = ref.read(contextoFinanzasProvider).value;
    if (c == null) return;
    final servicio = ref.read(servicioFinanzasProvider);
    for (final libro in c.libros) {
      if (libro.archivado || !c.permisoEn(libro).administrar) continue;
      final parametros = c.datos.parametrosDe(libro.id);
      await servicio.guardarParametros(parametros.copiar(diasAvisoDeuda: dias));
    }
  }

  static String _hora(int h) => '${h.toString().padLeft(2, '0')}:00';

  Widget _horas({
    required String etiqueta,
    required Key llave,
    required int valor,
    required ValueChanged<int> alCambiar,
  }) => DropdownButtonFormField<int>(
    key: llave,
    initialValue: valor,
    isExpanded: true,
    decoration: InputDecoration(labelText: etiqueta),
    items: [
      for (var h = 0; h < 24; h++)
        DropdownMenuItem(value: h, child: Text(_hora(h))),
    ],
    onChanged: _guardando
        ? null
        : (h) {
            if (h != null) alCambiar(h);
          },
  );

  @override
  Widget build(BuildContext context) {
    final rol = ref.watch(rolEfectivoProvider);
    if (rol == null || !permisos.puedeAbrir(rol, Modulo.finanzas)) {
      return const SizedBox.shrink();
    }
    final p = _p;
    final tema = Theme.of(context);
    if (p == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final dias = [...p.diasAvisoDeuda]..sort((a, b) => b.compareTo(a));
    return Card(
      key: const ValueKey('avisos-finanzas'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Avisos de Finanzas', style: tema.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Los avisos son discretos: un título corto, sin montos. El '
              'detalle está dentro de GRAVITY.',
              style: tema.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Text('Cuántos días antes de un vencimiento', style: tema.textTheme.titleSmall),
            Text(
              'Hasta 3 avisos. 0 es el mismo día.',
              style: tema.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final d in diasAntesOfrecidos)
                  FilterChip(
                    key: ValueKey('avisos-fin-dias-$d'),
                    label: Text(d == 0 ? 'Mismo día' : '$d'),
                    selected: dias.contains(d),
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    onSelected: _guardando
                        ? null
                        : (sel) {
                            final nuevos = {...dias};
                            sel ? nuevos.add(d) : nuevos.remove(d);
                            _guardar(
                              p.copiarCon(
                                diasAvisoDeuda: (nuevos.toList()
                                  ..sort((a, b) => b.compareTo(a))),
                              ),
                              conDias: true,
                            );
                          },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _horas(
              etiqueta: 'Hora de los avisos de vencimiento',
              llave: const ValueKey('avisos-fin-hora-vencimientos'),
              valor: p.horaVencimientos.hora,
              alCambiar: (h) => _guardar(p.copiarCon(horaVencimientos: HoraDelDia(h))),
            ),
            const SizedBox(height: 12),
            _horas(
              etiqueta: 'Silencio desde',
              llave: const ValueKey('avisos-fin-silencio-desde'),
              valor: p.silencioDesde.hora,
              alCambiar: (h) => _guardar(p.copiarCon(silencioDesde: HoraDelDia(h))),
            ),
            const SizedBox(height: 12),
            _horas(
              etiqueta: 'Silencio hasta',
              llave: const ValueKey('avisos-fin-silencio-hasta'),
              valor: p.silencioHasta.hora,
              alCambiar: (h) => _guardar(p.copiarCon(silencioHasta: HoraDelDia(h))),
            ),
            const SizedBox(height: 12),
            _horas(
              etiqueta: 'Resumen del lunes',
              llave: const ValueKey('avisos-fin-resumen-lunes'),
              valor: p.resumenLunes.hora,
              alCambiar: (h) => _guardar(p.copiarCon(resumenLunes: HoraDelDia(h))),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              key: const ValueKey('avisos-fin-cierre-dia'),
              initialValue: p.recordatorioCierreDia.clamp(1, 7),
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Recordatorio de cierre de semana: día',
              ),
              items: [
                for (var d = 1; d <= 7; d++)
                  DropdownMenuItem(value: d, child: Text(_nombresDia[d - 1])),
              ],
              onChanged: _guardando
                  ? null
                  : (d) {
                      if (d != null) _guardar(p.copiarCon(recordatorioCierreDia: d));
                    },
            ),
            const SizedBox(height: 12),
            _horas(
              etiqueta: 'Recordatorio de cierre de semana: hora',
              llave: const ValueKey('avisos-fin-cierre-hora'),
              valor: p.recordatorioCierreHora.hora,
              alCambiar: (h) =>
                  _guardar(p.copiarCon(recordatorioCierreHora: HoraDelDia(h))),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Row(
                key: const ValueKey('avisos-fin-error'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline, size: 20, color: tema.colorScheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: tema.textTheme.bodyMedium?.copyWith(
                        color: tema.colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
