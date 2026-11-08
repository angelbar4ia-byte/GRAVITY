/// Lector de código de barras (Fase 7, v1.1). Sin catálogo externo: el código
/// se busca en el catálogo local y, si no existe, se captura a mano.
library;

import 'modelos.dart';

/// Lee un código con la cámara. La implementación real (paquete de cámara)
/// queda detrás de esta interfaz; el permiso de cámara se pide solo dentro de
/// [leer], es decir, cuando la persona toca "Escanear".
abstract interface class LectorCodigo {
  /// El código leído, o `null` si la persona cancela o no hay cámara/permiso.
  Future<String?> leer();
}

/// Lector para pruebas: devuelve [codigo] sin tocar la cámara.
class LectorCodigoFalso implements LectorCodigo {
  LectorCodigoFalso(this.codigo);
  final String? codigo;
  int lecturas = 0;

  @override
  Future<String?> leer() async {
    lecturas++;
    return codigo;
  }
}

/// Por omisión, hasta que se agregue el paquete de cámara: no lee nada y no
/// pide ningún permiso.
class LectorCodigoSinCamara implements LectorCodigo {
  const LectorCodigoSinCamara();

  @override
  Future<String?> leer() async => null;
}

/// Busca [codigo] en [catalogo]; `null` si no existe (hay que capturarlo).
Ingrediente? buscarPorCodigo(Iterable<Ingrediente> catalogo, String codigo) {
  final c = codigo.trim();
  if (c.isEmpty) return null;
  for (final i in catalogo) {
    if (i.codigoBarras == c) return i;
  }
  return null;
}
