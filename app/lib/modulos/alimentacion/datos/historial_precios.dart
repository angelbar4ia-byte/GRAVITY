/// Historial de precios reales y alerta de subida (Fase 7, v1.1).
///
/// Solo compras reales que captura una persona: el precio base nunca entra.
/// La alerta es local (pantalla de compras), no un aviso del servidor, y solo
/// habla de porcentaje y precios unitarios, nunca de saldos.
library;

/// Una compra real: [totalCentavos] pagados por [cantidad] de la unidad.
class CompraPrecio {
  const CompraPrecio({
    required this.clave,
    required this.nombre,
    required this.unidad,
    required this.totalCentavos,
    required this.cantidad,
    required this.fecha,
    this.tiendaId,
    this.tienda,
    this.compraId,
    this.revertida = false,
    this.cuentaPago,
  }) : assert(totalCentavos > 0),
       assert(cantidad > 0);

  final String clave;
  final String nombre;
  final String unidad;
  final int totalCentavos;
  final double cantidad;
  final DateTime fecha;

  /// Tienda donde se compró (Fase 8). `null` = compra anterior a la captura de
  /// tienda ("sin tienda"); desde la Fase 8 toda compra nueva la lleva.
  final String? tiendaId;
  final String? tienda;

  /// Id de la compra en el servidor (para regresarla), si se conoce.
  final String? compraId;

  /// La compra se regresó: la original se conserva en el historial como
  /// revertida y no cuenta en los totales.
  final bool revertida;

  /// Nombre de la cuenta de pago (si el albacea rechazó la solicitud de Papá,
  /// la compra no sale del historial: solo cambia de cuenta).
  final String? cuentaPago;

  /// Centavos por una unidad (puede ser fraccionario).
  double get unitarioCentavos => totalCentavos / cantidad;
}

/// Subida de precio por encima del umbral.
class AlertaPrecio {
  const AlertaPrecio({
    required this.porcentaje,
    required this.anteriorUnitario,
    required this.nuevoUnitario,
    required this.unidad,
  });

  /// Porcentaje redondeado (ej. 25).
  final int porcentaje;
  final double anteriorUnitario;
  final double nuevoUnitario;
  final String unidad;

  String get texto =>
      'El precio subió $porcentaje% desde la última compra '
      '(${unitarioTexto(anteriorUnitario)} → ${unitarioTexto(nuevoUnitario)} '
      'por $unidad).';
}

/// Subida mínima (estricta) que dispara la alerta: más de 20%.
const umbralAlertaPrecio = 0.20;

/// `null` si no hay compra real anterior o la subida no pasa de 20%.
AlertaPrecio? calcularAlerta(CompraPrecio? anterior, CompraPrecio nueva) {
  if (anterior == null) return null;
  final a = anterior.unitarioCentavos;
  final n = nueva.unitarioCentavos;
  if (n <= a * (1 + umbralAlertaPrecio)) return null;
  return AlertaPrecio(
    porcentaje: ((n / a - 1) * 100).round(),
    anteriorUnitario: a,
    nuevoUnitario: n,
    unidad: nueva.unidad,
  );
}

/// Compras de [clave], de la más reciente a la más antigua.
List<CompraPrecio> historialDe(Iterable<CompraPrecio> todas, String clave) =>
    todas.where((c) => c.clave == clave && !c.revertida).toList()
      ..sort((a, b) => b.fecha.compareTo(a.fecha));

/// Centavos unitarios como pesos: "$28.00", o con tres decimales bajo $1.
String unitarioTexto(double centavos) {
  final p = centavos / 100;
  return '\$${p >= 1 ? p.toStringAsFixed(2) : p.toStringAsFixed(3)}';
}
