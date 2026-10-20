/// Ajustes › Voz: voz de GRAVITY (se puede cambiar) y respuestas habladas.
library;

import 'package:flutter/material.dart';

import '../marco_seccion.dart';
import '../secciones_ajustes.dart';

class PantallaVoz extends StatelessWidget {
  const PantallaVoz({super.key});

  @override
  Widget build(BuildContext context) => const MarcoSeccion(
    seccion: SeccionAjustes.voz,
    hijos: [
      NotaAjustes(
        'La voz de GRAVITY llega en la Fase 6. Podrás elegir la voz y si '
        'responde hablando.',
        icono: Icons.record_voice_over_outlined,
      ),
      NotaAjustes(
        'Por las bocinas de la casa nunca se dicen montos de dinero ni datos '
        'clínicos; los recordatorios de cuidados son genéricos.',
        icono: Icons.speaker_outlined,
      ),
    ],
  );
}
