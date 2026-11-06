/// Catálogo de estilos disponibles. Futurista (Fase 0) y Swagger y Glass (Fase 4).
/// Minimalista, claro y arquitectónico quedan para después (P1).
library;

import '../estilo.dart';
import 'futurista.dart';
import 'swagger.dart';

/// Estilo por defecto (decidido el 20/oct/2026).
const Estilo estiloPorDefecto = estiloFuturista;

/// Estilos que se pueden elegir en Ajustes › Apariencia.
const List<Estilo> estilosIncluidos = [estiloFuturista, estiloSwagger];

/// Busca un estilo por su id; si no existe, regresa el estilo por defecto.
Estilo estiloPorId(String id, {List<Estilo> catalogo = estilosIncluidos}) {
  for (final estilo in catalogo) {
    if (estilo.id == id) return estilo;
  }
  return estiloPorDefecto;
}
