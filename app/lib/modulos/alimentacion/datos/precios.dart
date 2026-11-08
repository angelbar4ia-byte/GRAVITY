/// Precios de ingredientes (Fase 7, decisión 2 del dueño del 8/nov/2026).
///
/// Dinero en centavos. Un precio **base** es un supuesto sin relevancia que
/// arranca con la app y se muestra siempre como "estimado". El precio **real**
/// sale de una compra que captura una persona; nunca se inventa ni se trae de
/// una fuente sin verificar.
library;

/// Precio de un ingrediente: [centavos] por [porCantidad] de la unidad de su
/// clave (`claveCompra`). Ejemplo: leche, 2800 centavos por 1000 ml.
class PrecioIngrediente {
  const PrecioIngrediente({
    required this.clave,
    required this.centavos,
    this.porCantidad = 1,
    required this.esBase,
  }) : assert(centavos >= 0),
       assert(porCantidad > 0);

  final String clave;
  final int centavos;
  final double porCantidad;

  /// `true` = precio base supuesto: se rotula "estimado", nunca como real.
  final bool esBase;

  /// Costo en centavos de [cantidad] a este precio.
  int costoDe(double cantidad) => (cantidad / porCantidad * centavos).round();

  /// Precio **real** de una compra: se pagaron [totalCentavos] por
  /// [cantidadComprada] de la unidad. Reemplaza al base o a la compra anterior.
  factory PrecioIngrediente.deCompra({
    required String clave,
    required int totalCentavos,
    required double cantidadComprada,
  }) => PrecioIngrediente(
    clave: clave,
    centavos: totalCentavos,
    porCantidad: cantidadComprada,
    esBase: false,
  );
}

/// Centavos como pesos con dos decimales: 12345 -> "$123.45".
String pesosTexto(int centavos) {
  final c = centavos.abs();
  final t = '\$${c ~/ 100}.${(c % 100).toString().padLeft(2, '0')}';
  return centavos < 0 ? '-$t' : t;
}

/// Texto de un costo para mostrar: los precios base siempre dicen "estimado".
String costoTexto(int centavos, {required bool estimado}) =>
    estimado ? '≈ ${pesosTexto(centavos)} (estimado)' : pesosTexto(centavos);
