import 'package:flutter/material.dart';

import '../formato.dart';
import '../tema.dart';
import '../valores_diseno.dart';

export '../formato.dart' show formatearCentavos, montoOculto;

/// Monto en pesos con modo oculto (secciones 19 y 21).
///
/// Recibe **centavos** (`int`). Con [oculto] muestra `$ • • • • •` y el lector
/// de pantalla dice "Monto oculto", sin la cifra.
class MontoOcultable extends StatelessWidget {
  const MontoOcultable({
    super.key,
    required this.centavos,
    this.oculto = false,
    this.estilo,
    this.mostrarSigno = false,
    this.alTocar,
  });

  final int centavos;
  final bool oculto;

  /// Estilo del texto; por defecto, números de ancho fijo con texto fuerte.
  final TextStyle? estilo;

  /// Si los positivos llevan `+`.
  final bool mostrarSigno;

  /// Acción al tocar (por ejemplo, alternar el modo privado).
  final VoidCallback? alTocar;

  /// El texto que se muestra.
  String get texto => oculto
      ? montoOculto
      : formatearCentavos(centavos, mostrarSigno: mostrarSigno);

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final style =
        estilo ??
        v.numero(tamano: 16, peso: FontWeight.w600, color: v.textoFuerte);
    Widget resultado = Text(
      texto,
      style: oculto ? style.copyWith(letterSpacing: 1.5) : style,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.fade,
    );
    if (alTocar != null) {
      resultado = InkWell(
        onTap: alTocar,
        borderRadius: BorderRadius.circular(v.radioChico),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: zonaTactilMinima),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: 1,
            child: resultado,
          ),
        ),
      );
    }
    return Semantics(
      label: oculto ? 'Monto oculto' : texto,
      hint: alTocar == null
          ? null
          : (oculto ? 'Toca para mostrar' : 'Toca para ocultar'),
      button: alTocar != null,
      excludeSemantics: true,
      child: resultado,
    );
  }
}
