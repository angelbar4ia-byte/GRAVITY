/// Ajustes › Privacidad: modo privado y datos sensibles (D3, D13).
library;

import 'package:flutter/material.dart';

import '../marco_seccion.dart';
import '../secciones_ajustes.dart';

class PantallaPrivacidad extends StatelessWidget {
  const PantallaPrivacidad({super.key});

  @override
  Widget build(BuildContext context) => const MarcoSeccion(
    seccion: SeccionAjustes.privacidad,
    hijos: [
      NotaAjustes(
        'El dinero y los datos clínicos nunca van a la IA en la nube ni a las '
        'bocinas.',
        icono: Icons.shield_outlined,
      ),
      NotaAjustes(
        'Modo privado: oculta montos y datos de cuidados con un toque (en la '
        'laptop, Ctrl + Shift + O).',
        icono: Icons.visibility_off_outlined,
      ),
      NotaAjustes(
        'Datos sensibles de Hábitos: cifrados en la nube o solo en el '
        'teléfono, a elegir (llega en la Fase 3).',
        icono: Icons.lock_outline,
      ),
    ],
  );
}
