/// Accesos a "Instrucciones" y "Consentimientos" de Cuidados (Fase 5, 8f).
///
/// Los monta "Más" (teléfono y tablet) y la franja al pie de GRAVITY en la
/// laptop (que no tiene "Más"). Misma visibilidad que el guardia de rutas
/// ([veAccesoInstrucciones], [veAccesoConsentimientos]): el dueño y la pareja.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../navegacion.dart';
import '../sesion_efectiva.dart';

class AccesosInstruccionesCuidados extends ConsumerWidget {
  const AccesosInstruccionesCuidados({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rol = ref.watch(rolEfectivoProvider);
    if (rol == null) return const SizedBox.shrink();
    final esMaestra = ref.watch(esCuentaMaestraProvider);
    final instrucciones = veAccesoInstrucciones(rol, esMaestra: esMaestra);
    final consentimientos = veAccesoConsentimientos(rol, esMaestra: esMaestra);
    if (!instrucciones && !consentimientos) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (instrucciones)
          ListTile(
            key: const ValueKey('acceso-cuidados-instrucciones'),
            leading: const Icon(Icons.speaker_notes_outlined),
            title: const Text('Instrucciones'),
            subtitle: const Text('Para la cuidadora principal'),
            minTileHeight: 56,
            onTap: () => context.go(RutasApp.cuidadosInstrucciones),
          ),
        if (consentimientos)
          ListTile(
            key: const ValueKey('acceso-cuidados-consentimientos'),
            leading: const Icon(Icons.verified_user_outlined),
            title: const Text('Consentimientos'),
            minTileHeight: 56,
            onTap: () => context.go(RutasApp.cuidadosConsentimientos),
          ),
      ],
    );
  }
}
