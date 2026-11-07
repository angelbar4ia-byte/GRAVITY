/// Piezas comunes de las pantallas de Cuidados: letra y botones grandes, alto
/// contraste, textos impersonales (*"¿Cómo comió?"*, *"Ya se dio"*).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../diseno/diseno.dart';
import '../datos/modelos.dart';
import '../estado/proveedores.dart';

/// Ejecuta [accion], avisa el resultado y vuelve a pedir los datos. El aviso
/// de éxito nunca lleva nombres de medicamentos ni de personas: puede verse
/// en pantallas de bloqueo (D3).
Future<bool> ejecutarCuidados(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function() accion, {
  String ok = 'Listo, registrado',
}) async {
  final mensajes = ScaffoldMessenger.of(context);
  try {
    await accion();
    refrescarCuidados(ref);
    mensajes.showSnackBar(SnackBar(content: Text(ok)));
    return true;
  } on ErrorCuidados catch (e) {
    mensajes.showSnackBar(SnackBar(content: Text(e.mensaje)));
  } catch (_) {
    mensajes.showSnackBar(
      const SnackBar(content: Text('No se pudo guardar. Intenta de nuevo.')),
    );
  }
  return false;
}

/// Botón grande (64 dp de alto, letra 20).
class BotonGrande extends StatelessWidget {
  const BotonGrande({
    super.key,
    required this.texto,
    required this.onPressed,
    this.icono,
    this.tonal = false,
  });

  final String texto;
  final VoidCallback? onPressed;
  final IconData? icono;
  final bool tonal;

  @override
  Widget build(BuildContext context) {
    final estilo = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size.fromHeight(64)),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      ),
    );
    final hijo = Text(texto, textAlign: TextAlign.center);
    final icon = icono == null ? null : Icon(icono, size: 28);
    if (tonal) {
      return icon == null
          ? FilledButton.tonal(style: estilo, onPressed: onPressed, child: hijo)
          : FilledButton.tonalIcon(
              style: estilo,
              onPressed: onPressed,
              icon: icon,
              label: hijo,
            );
    }
    return icon == null
        ? FilledButton(style: estilo, onPressed: onPressed, child: hijo)
        : FilledButton.icon(
            style: estilo,
            onPressed: onPressed,
            icon: icon,
            label: hijo,
          );
  }
}

/// Tarjeta con título para agrupar una sección.
class TarjetaCuidados extends StatelessWidget {
  const TarjetaCuidados({
    super.key,
    required this.titulo,
    required this.hijos,
    this.icono,
  });

  final String titulo;
  final IconData? icono;
  final List<Widget> hijos;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icono != null) ...[Icon(icono, size: 28), const SizedBox(width: 12)],
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(titulo, style: t.titleLarge),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...hijos,
          ],
        ),
      ),
    );
  }
}

/// Mensaje de "esto no es para ti": la app solo oculta, el servidor decide.
class SinAccesoCuidados extends StatelessWidget {
  const SinAccesoCuidados({super.key, this.detalle});
  final String? detalle;

  @override
  Widget build(BuildContext context) => EstadoVacio(
    mensaje: 'Esta sección no está disponible',
    detalle: detalle ?? 'Pide acceso a quien administra la casa.',
    icono: Icons.lock_outline,
  );
}

/// Pinta un [AsyncValue] con los estados comunes.
Widget cuando<T>(
  AsyncValue<T> v,
  VoidCallback reintentar,
  Widget Function(T datos) construir,
) => v.when(
  loading: () => const EstadoCargando(),
  error: (_, _) => EstadoError(
    mensaje: 'No pudimos cargar esto.',
    alReintentar: reintentar,
  ),
  data: construir,
);

String fechaLarga(DateTime d) {
  const dias = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
  const meses = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio',
    'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];
  return '${dias[d.weekday - 1]} ${d.day} de ${meses[d.month - 1]}';
}

String mesTexto(DateTime d) {
  const meses = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio',
    'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];
  return '${meses[d.month - 1]} de ${d.year}';
}
