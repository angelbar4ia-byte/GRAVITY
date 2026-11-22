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
        'La voz todavía no está disponible; mientras tanto puedes escribirle a '
        'GRAVITY. En el teléfono Android también puedes dictar el mensaje con '
        'el micrófono del cuadro de conversación. Cuando GRAVITY pueda '
        'contestar hablando, aquí elegirás la voz.',
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
