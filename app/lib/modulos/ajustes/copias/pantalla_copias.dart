/// Ajustes › Copias de seguridad (D7): copia diaria desde la laptop y, para el
/// dueño, el porcentaje usado de la base (Fase 2: `avisos_porcentaje_base`; el
/// aviso a las 80 % y 90 % llega a la bandeja).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../nucleo/avisos/proveedores_avisos.dart';
import '../../../nucleo/contratos/roles.dart';
import '../../../app/sesion_efectiva.dart';
import '../marco_seccion.dart';
import '../secciones_ajustes.dart';

/// Porcentaje de la base usado; `null` si no se puede saber (no es el dueño,
/// sin servidor o sin límite configurado).
final porcentajeBaseProvider = FutureProvider.autoDispose<double?>((ref) async {
  if (ref.watch(rolEfectivoProvider) != Rol.dueno) return null;
  try {
    return await ref.watch(repositorioAvisosProvider)?.porcentajeBase();
  } catch (_) {
    return null;
  }
});

class PantallaCopias extends ConsumerWidget {
  const PantallaCopias({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final porcentaje = ref.watch(porcentajeBaseProvider).value;
    return MarcoSeccion(
      seccion: SeccionAjustes.copias,
      hijos: [
        if (porcentaje != null)
          NotaAjustes(
            'Base de datos usada: ${porcentaje.toStringAsFixed(1)} %. Al llegar '
            'a 80 % y a 90 % GRAVITY te lo avisa.',
            icono: Icons.storage_outlined,
          ),
        const NotaAjustes(
          'La laptop hace cada día una copia completa de la base de datos, más '
          'una copia cifrada fuera de la laptop (p. ej. un disco externo).',
          icono: Icons.backup_outlined,
        ),
        const NotaAjustes(
          'Cómo programarla y restaurarla: herramientas/respaldo en el '
          'repositorio.',
          icono: Icons.restore,
        ),
      ],
    );
  }
}
