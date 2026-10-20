/// Ajustes › Notificaciones: avisos al teléfono y a la pulsera (D7, D15).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

class PantallaNotificaciones extends ConsumerWidget {
  const PantallaNotificaciones({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MarcoSeccion(
    seccion: SeccionAjustes.notificaciones,
    hijos: [
      NotaAjustes(
        textoEstadoFirebase(ref.watch(estadoFirebaseProvider)),
        icono: Icons.notifications_outlined,
      ),
      const NotaAjustes(
        'Avisos discretos en dinero, hábitos sensibles y cuidados. En la '
        'pulsera, textos cortos sin montos (llegan en las Fases 2 y 3).',
        icono: Icons.watch_outlined,
      ),
    ],
  );
}
