/// Pantalla de los módulos que aún no se construyen (Finanzas, Hábitos,
/// Cuidados, Alimentación y Casa llegan en sus fases).
library;

import 'package:flutter/material.dart';

import '../../nucleo/contratos/roles.dart';
import '../../nucleo/permisos/permisos.dart';
import '../navegacion.dart';
import 'marco_pantalla.dart';

/// Fase en la que llega cada módulo (ROADMAP, secciones 4 a 8).
const Map<Modulo, int> faseDeModulo = {
  Modulo.finanzas: 1,
  Modulo.habitos: 3,
  Modulo.cuidados: 5,
  Modulo.casa: 6,
  Modulo.alimentacion: 7,
};

class PantallaProximamente extends StatelessWidget {
  const PantallaProximamente({
    super.key,
    required this.titulo,
    required this.icono,
    this.fase,
    this.detalle,
  });

  /// Pantalla "Próximamente" de un módulo completo.
  PantallaProximamente.modulo(Modulo modulo, {super.key, this.detalle})
    : titulo = nombreModulo(modulo),
      icono = iconoDeModulo(modulo),
      fase = faseDeModulo[modulo];

  final String titulo;
  final IconData icono;
  final int? fase;
  final String? detalle;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return MarcoPantalla(
      titulo: titulo,
      cuerpo: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, size: 64, color: tema.colorScheme.primary),
              const SizedBox(height: 16),
              Text('Próximamente', style: tema.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                fase == null ? titulo : '$titulo llega en la Fase $fase.',
                textAlign: TextAlign.center,
                style: tema.textTheme.bodyLarge,
              ),
              if (detalle != null) ...[
                const SizedBox(height: 8),
                Text(
                  detalle!,
                  textAlign: TextAlign.center,
                  style: tema.textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
