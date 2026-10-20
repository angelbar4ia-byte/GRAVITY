/// Ajustes › Copias de seguridad (D7): copia diaria desde la laptop.
library;

import 'package:flutter/material.dart';

import '../marco_seccion.dart';
import '../secciones_ajustes.dart';

class PantallaCopias extends StatelessWidget {
  const PantallaCopias({super.key});

  @override
  Widget build(BuildContext context) => const MarcoSeccion(
    seccion: SeccionAjustes.copias,
    hijos: [
      NotaAjustes(
        'La laptop hace cada día una copia completa de la base de datos, más '
        'una copia cifrada fuera de la laptop (p. ej. un disco externo).',
        icono: Icons.backup_outlined,
      ),
      NotaAjustes(
        'Cómo programarla y restaurarla: herramientas/respaldo en el '
        'repositorio.',
        icono: Icons.restore,
      ),
    ],
  );
}
