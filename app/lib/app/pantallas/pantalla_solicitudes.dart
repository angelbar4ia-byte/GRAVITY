/// Bandeja "Solicitudes de GRAVITY" (D18): para quien no conversa con
/// GRAVITY (la cuidadora). Cada recordatorio o solicitud se confirma con
/// *Hecho* o *No se pudo* (con nota). Solo lo de su turno: nada de la familia.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../diseno/proveedores.dart' show relojProvider;
import '../../nucleo/contratos/roles.dart';
import '../../nucleo/solicitudes/solicitudes.dart';
import '../sesion_efectiva.dart';
import 'marco_pantalla.dart';

/// Solicitudes de la persona que usa la app ahora. Fase 1: las de ejemplo de
/// la cuidadora, en memoria (cambian con la persona: en la tablet, nadie ve
/// las de otra).
final solicitudesProvider =
    NotifierProvider<ControladorSolicitudes, List<SolicitudGravity>>(
      ControladorSolicitudes.new,
    );

class ControladorSolicitudes extends Notifier<List<SolicitudGravity>> {
  @override
  List<SolicitudGravity> build() {
    final sesion = ref.watch(sesionEfectivaProvider);
    if (sesion?.rol != Rol.cuidador) return const [];
    return solicitudesDeEjemplo(ref.read(relojProvider).ahora());
  }

  void _cambiar(String id, SolicitudGravity Function(SolicitudGravity) cambio) {
    state = [
      for (final solicitud in state)
        solicitud.id == id ? cambio(solicitud) : solicitud,
    ];
  }

  /// *Hecho* o *No se pudo* (este pide [nota]).
  void confirmar(String id, EstadoSolicitud resultado, {String? nota}) =>
      _cambiar(
        id,
        (s) => s.confirmar(
          resultado,
          nota: nota,
          en: ref.read(relojProvider).ahora(),
        ),
      );

  void deshacer(String id) => _cambiar(id, (s) => s.reabrir());
}

String _hora(DateTime momento) =>
    '${momento.hour.toString().padLeft(2, '0')}:'
    '${momento.minute.toString().padLeft(2, '0')}';

class PantallaSolicitudes extends ConsumerWidget {
  const PantallaSolicitudes({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final solicitudes = ref.watch(solicitudesProvider);
    final pendientes = solicitudes.where((s) => s.pendiente).length;
    final tema = Theme.of(context);
    return MarcoPantalla(
      titulo: 'Solicitudes de GRAVITY',
      cuerpo: solicitudes.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Sin solicitudes por ahora.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  pendientes == 0
                      ? 'Todo confirmado. ¡Gracias!'
                      : pendientes == 1
                      ? '1 pendiente'
                      : '$pendientes pendientes',
                  style: tema.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                for (final solicitud in solicitudes)
                  _TarjetaSolicitud(solicitud: solicitud),
              ],
            ),
    );
  }
}

class _TarjetaSolicitud extends ConsumerWidget {
  const _TarjetaSolicitud({required this.solicitud});

  final SolicitudGravity solicitud;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controlador = ref.read(solicitudesProvider.notifier);
    final tema = Theme.of(context);
    final esRecordatorio = solicitud.tipo == TipoSolicitud.recordatorio;
    return Card(
      key: ValueKey('solicitud-${solicitud.id}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  esRecordatorio
                      ? Icons.alarm_outlined
                      : Icons.assignment_outlined,
                  color: tema.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(solicitud.titulo, style: tema.textTheme.titleMedium),
                      Text(
                        '${_hora(solicitud.hora)} · '
                        '${esRecordatorio ? 'Recordatorio' : 'Solicitud'}',
                        style: tema.textTheme.bodySmall,
                      ),
                      if (solicitud.detalle != null) Text(solicitud.detalle!),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (solicitud.pendiente)
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    key: ValueKey('no-se-pudo-${solicitud.id}'),
                    onPressed: () async {
                      final nota = await _pedirNota(context);
                      if (nota != null) {
                        controlador.confirmar(
                          solicitud.id,
                          EstadoSolicitud.noSePudo,
                          nota: nota,
                        );
                      }
                    },
                    icon: const Icon(Icons.block),
                    label: const Text('No se pudo'),
                  ),
                  FilledButton.icon(
                    key: ValueKey('hecho-${solicitud.id}'),
                    onPressed: () => controlador.confirmar(
                      solicitud.id,
                      EstadoSolicitud.hecha,
                    ),
                    icon: const Icon(Icons.check),
                    label: const Text('Hecho'),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Icon(
                    solicitud.estado == EstadoSolicitud.hecha
                        ? Icons.check_circle
                        : Icons.cancel_outlined,
                    color: solicitud.estado == EstadoSolicitud.hecha
                        ? tema.colorScheme.primary
                        : tema.colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      solicitud.estado == EstadoSolicitud.hecha
                          ? 'Hecho a las ${_hora(solicitud.confirmadaEn!)}'
                          : 'No se pudo: ${solicitud.nota}',
                    ),
                  ),
                  TextButton(
                    onPressed: () => controlador.deshacer(solicitud.id),
                    child: const Text('Deshacer'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Pide la nota de *No se pudo* (obligatoria, hasta 200 caracteres).
Future<String?> _pedirNota(BuildContext context) => showDialog<String>(
  context: context,
  builder: (contexto) => const _DialogoNota(),
);

class _DialogoNota extends StatefulWidget {
  const _DialogoNota();

  @override
  State<_DialogoNota> createState() => _DialogoNotaState();
}

class _DialogoNotaState extends State<_DialogoNota> {
  final _nota = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _nota.dispose();
    super.dispose();
  }

  void _guardar() {
    final texto = _nota.text.trim();
    if (texto.isEmpty) {
      setState(() => _error = 'Escribe por qué no se pudo.');
      return;
    }
    Navigator.of(context).pop(texto);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('¿Qué pasó?'),
    content: TextField(
      key: const ValueKey('nota-solicitud'),
      controller: _nota,
      autofocus: true,
      maxLength: largoMaximoNota,
      maxLines: 3,
      inputFormatters: [LengthLimitingTextInputFormatter(largoMaximoNota)],
      decoration: InputDecoration(
        labelText: 'Nota',
        errorText: _error,
        border: const OutlineInputBorder(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: _guardar, child: const Text('Guardar')),
    ],
  );
}
