/// Estado de un modelo descargable y avance de su descarga (spec 3.2 punto 7
/// y 4.2.2).
library;

import 'package:flutter/foundation.dart' show immutable;

enum EstadoModelo {
  /// No está en el equipo (puede haber una descarga a medias que se reanuda).
  noDescargado,

  /// Hay una descarga en curso en este momento.
  descargando,

  /// Todos sus archivos verificaron y se pueden cargar.
  instalado,

  /// Faltan archivos o no pesan lo que dice el catálogo, la última carga no
  /// terminó (la marca de carga sigue ahí) o la comprobación de huellas
  /// falló. No se carga hasta que la persona lo reintente o lo borre.
  corrupto,
}

/// Avance de una descarga. Cuenta los bytes de **todo el modelo**, no solo los
/// del archivo que se está bajando (criterio 19).
@immutable
final class ProgresoDescarga {
  const ProgresoDescarga(this.bytes, this.total, this.archivo);

  /// Bytes ya guardados del modelo.
  final int bytes;

  /// Lo que pesa el modelo entero (suma del catálogo).
  final int total;

  /// Nombre (del catálogo) del archivo que se está bajando o verificando.
  final String archivo;

  /// De 0.0 a 1.0.
  double get fraccion => total <= 0 ? 0 : (bytes / total).clamp(0.0, 1.0);

  @override
  bool operator ==(Object other) =>
      other is ProgresoDescarga &&
      other.bytes == bytes &&
      other.total == total &&
      other.archivo == archivo;

  @override
  int get hashCode => Object.hash(bytes, total, archivo);

  @override
  String toString() => 'ProgresoDescarga($bytes/$total, $archivo)';
}

/// "63 MB", "1.2 GB", "950 KB". Megabytes decimales (1 MB = 1 000 000 bytes),
/// como los que mide `Content-Length` y los que muestran los alojamientos.
String formatearBytes(int bytes) {
  if (bytes >= 1000 * 1000 * 1000) {
    return '${(bytes / 1000000000).toStringAsFixed(1)} GB';
  }
  if (bytes >= 1000 * 1000) {
    final mb = bytes / 1000000;
    return '${mb.round()} MB';
  }
  if (bytes >= 1000) return '${(bytes / 1000).round()} KB';
  return '$bytes B';
}
