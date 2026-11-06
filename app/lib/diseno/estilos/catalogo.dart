/// Catálogo de estilos disponibles. En la Fase 0 solo existe el Futurista; los
/// demás (minimalista, claro, arquitectónico, glass, swagger) llegan en la Fase 4.
library;

import '../estilo.dart';
import 'futurista.dart';

/// Estilo por defecto (decidido el 20/oct/2026).
const Estilo estiloPorDefecto = estiloFuturista;

/// Estilos que se pueden elegir en Ajustes › Apariencia.
const List<Estilo> estilosIncluidos = [estiloFuturista];

/// Busca un estilo por su id; si no existe, regresa el estilo por defecto.
Estilo estiloPorId(String id, {List<Estilo> catalogo = estilosIncluidos}) {
  for (final estilo in catalogo) {
    if (estilo.id == id) return estilo;
  }
  return estiloPorDefecto;
}
