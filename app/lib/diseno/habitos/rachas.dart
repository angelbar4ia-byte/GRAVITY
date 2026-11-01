import 'package:flutter/material.dart';

import '../valores_diseno.dart';

/// Chip de racha: el número de días, el día de gracia y *Retomemos* (sin
/// culpa: nunca "perdiste"). Siempre con texto además del icono.
class ChipRacha extends StatelessWidget {
  const ChipRacha({
    super.key,
    required this.dias,
    this.graciaUsada = false,
    this.retomemos = false,
    this.global = false,
  });

  /// Días consecutivos.
  final int dias;

  /// Hoy se cubrió con el día de gracia de la semana.
  final bool graciaUsada;

  /// La racha se cortó: se invita a retomar, sin reproche.
  final bool retomemos;

  /// Racha global (de todos los objetivos) en vez de la de un hábito.
  final bool global;

  String get texto => retomemos
      ? 'Retomemos'
      : '$dias ${dias == 1 ? 'día' : 'días'}${graciaUsada ? ' · día de gracia' : ''}';

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final color = retomemos ? v.textoTenue : v.acento;
    return Semantics(
      label: '${global ? 'Racha global' : 'Racha'}: $texto',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color.alphaBlend(color.withValues(alpha: 0.10), v.panel),
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(v.radioGrande * 2),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: v.espacio * 1.25,
            vertical: v.espacio * 0.5,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                retomemos ? Icons.replay : Icons.local_fire_department_outlined,
                size: 16,
                color: color,
              ),
              SizedBox(width: v.espacio * 0.5),
              Flexible(
                child: Text(
                  texto,
                  style: v.lectura(
                    tamano: 13,
                    peso: FontWeight.w600,
                    color: v.textoFuerte,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Estado de un día del calendario de constancia (símbolo **y** color).
enum EstadoDiaConstancia {
  cumplido('Cumplido', Icons.check),
  gracia('Día de gracia', Icons.change_history),
  noCumplido('No cumplido', Icons.remove),
  noAplica('No aplica', Icons.horizontal_rule);

  const EstadoDiaConstancia(this.etiqueta, this.icono);

  final String etiqueta;
  final IconData icono;

  Color color(ValoresDiseno v) => switch (this) {
    EstadoDiaConstancia.cumplido => v.exito,
    EstadoDiaConstancia.gracia => v.acento,
    EstadoDiaConstancia.noCumplido => v.textoTenue,
    EstadoDiaConstancia.noAplica => v.borde,
  };
}

@immutable
class DiaConstancia {
  const DiaConstancia(this.etiqueta, this.estado, {this.hoy = false});

  /// "L", "M"… o el número del día.
  final String etiqueta;
  final EstadoDiaConstancia estado;
  final bool hoy;
}

/// Calendario de constancia: una celda de 48 dp por día con símbolo, color y
/// la letra del día; los que no caben pasan a la línea siguiente. Un día no
/// cumplido no es rojo: es un símbolo tenue.
class CalendarioConstancia extends StatelessWidget {
  const CalendarioConstancia({super.key, required this.dias});

  final List<DiaConstancia> dias;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    return Semantics(
      container: true,
      label: 'Calendario de constancia',
      child: Wrap(
        spacing: v.espacio * 0.5,
        runSpacing: v.espacio * 0.5,
        children: [
          for (final d in dias)
            Semantics(
              label:
                  '${d.etiqueta}${d.hoy ? ' (hoy)' : ''}: ${d.estado.etiqueta}',
              excludeSemantics: true,
              child: SizedBox(
                width: 48,
                height: 56,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: d.hoy ? v.acento : v.borde,
                      width: d.hoy ? 1.5 : 1,
                    ),
                    borderRadius: BorderRadius.circular(v.radioMediano),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        d.etiqueta,
                        style: v.numero(tamano: 12, color: v.textoTenue),
                        maxLines: 1,
                      ),
                      const SizedBox(height: 2),
                      Icon(d.estado.icono, size: 18, color: d.estado.color(v)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
