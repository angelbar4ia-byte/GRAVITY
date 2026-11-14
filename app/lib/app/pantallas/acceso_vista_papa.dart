/// Acceso del familiar a "Pedir ver finanzas de Papá" (D24).
///
/// Solo se monta para el rol familiar. Lleva a la pantalla de pedir; los
/// datos los entrega el servidor solo si el dueño autoriza.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../navegacion.dart';

class AccesoPedirVistaPapa extends StatelessWidget {
  const AccesoPedirVistaPapa({super.key});

  @override
  Widget build(BuildContext context) => ListTile(
    key: const ValueKey('acceso-pedir-vista-papa'),
    leading: const Icon(Icons.visibility_outlined),
    title: const Text('Pedir ver finanzas de Papá'),
    minTileHeight: 56,
    onTap: () => context.go(RutasApp.vistaPapa),
  );
}
