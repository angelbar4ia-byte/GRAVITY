/// Ajustes › Apariencia: estilo, claro/oscuro y personalidad por módulo.
/// El selector lo construye el agente diseno (`seccionApariencia()`).
library;

import 'package:flutter/material.dart';

import '../../../app/pantallas_externas.dart';
import '../marco_seccion.dart';
import '../secciones_ajustes.dart';

class PantallaApariencia extends StatelessWidget {
  const PantallaApariencia({super.key});

  @override
  Widget build(BuildContext context) => MarcoSeccion(
    seccion: SeccionAjustes.apariencia,
    hijos: [
      seccionApariencia() ??
          const NotaAjustes(
            'Estilo: Futurista (por omisión). Claro u oscuro automático según '
            'la hora. El selector con vista previa en vivo llega con el '
            'sistema de estilos.',
            icono: Icons.palette_outlined,
          ),
    ],
  );
}
