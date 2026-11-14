/// Catálogo de estilos disponibles. Minimalista, claro y arquitectónico quedan
/// para después (P1).
library;

import '../estilo.dart';
import 'futurista.dart';
import 'glass.dart';
import 'bento.dart';

/// Estilo por defecto (decidido el 20/oct/2026).
const Estilo estiloPorDefecto = estiloFuturista;

/// Estilos que se pueden elegir en Ajustes › Apariencia: Futurista (Fase 0) y
/// Glass (Fase 4).
const List<Estilo> estilosIncluidos = [estiloFuturista, estiloGlass];

/// Estilos **en pausa** (D27): el código y las pruebas se conservan, pero no se
/// ofrecen. Quien tuviera uno guardado vuelve al Futurista. Swagger se
/// eliminó por completo.
const List<Estilo> estilosEnPausa = [estiloBento];

/// Busca un estilo por su id; si no existe, regresa el estilo por defecto.
Estilo estiloPorId(String id, {List<Estilo> catalogo = estilosIncluidos}) {
  for (final estilo in catalogo) {
    if (estilo.id == id) return estilo;
  }
  return estiloPorDefecto;
}
