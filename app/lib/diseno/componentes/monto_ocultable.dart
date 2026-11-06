import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../formato.dart';
import '../proveedores.dart';
import '../tema.dart';
import '../valores_diseno.dart';

export '../formato.dart' show formatearCentavos, montoOculto;

/// Monto en pesos con modo oculto (secciones 19 y 21).
///
/// Recibe **centavos** (`int`). Se dibuja oculto (`••••` y, para el lector de
/// pantalla, "Monto oculto", sin la cifra) si lo pide [oculto] **o** si la app
/// tiene los montos ocultos ([montosOcultosProvider]: modo privado, o montos
/// sin mostrar tras abrir la app o tras unos minutos sin uso). Así ningún monto
/// se escapa por olvido de quien lo dibuja.
///
/// [deEjemplo] es solo para vistas previas con cifras inventadas (por ejemplo,
/// la muestra de estilos en Ajustes): no se oculta con el provider.
class MontoOcultable extends ConsumerWidget {
  const MontoOcultable({
    super.key,
    required this.centavos,
    this.oculto = false,
    this.estilo,
    this.mostrarSigno = false,
    this.alTocar,
    this.deEjemplo = false,
  });

  final int centavos;

  /// Pide ocultar el monto aunque la app los tenga visibles.
  final bool oculto;

  /// Estilo del texto; por defecto, números de ancho fijo con texto fuerte.
  final TextStyle? estilo;

  /// Si los positivos llevan `+`.
  final bool mostrarSigno;

  /// Acción al tocar (por ejemplo, pedir ver los montos).
  final VoidCallback? alTocar;

  /// Cifra de ejemplo de una vista previa: nunca se oculta con el provider.
  final bool deEjemplo;

  /// El texto que se muestra con el monto [oculto] o a la vista.
  String textoPara({required bool oculto}) => oculto
      ? montoOculto
      : formatearCentavos(centavos, mostrarSigno: mostrarSigno);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final oculto =
        this.oculto || (!deEjemplo && ref.watch(montosOcultosProvider));
    final texto = textoPara(oculto: oculto);
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
