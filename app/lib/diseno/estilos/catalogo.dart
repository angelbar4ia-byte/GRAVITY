/// Catálogo de estilos disponibles. Futurista (Fase 0) y Bento (Fase 4); Glass sigue pendiente de aprobación.
/// Minimalista, claro y arquitectónico quedan para después (P1).
library;

import '../estilo.dart';
import 'futurista.dart';
import 'bento.dart';
import 'swagger.dart';

/// Estilo por defecto (decidido el 20/oct/2026).
const Estilo estiloPorDefecto = estiloFuturista;

/// Estilos que se pueden elegir en Ajustes › Apariencia.
const List<Estilo> estilosIncluidos = [estiloFuturista, estiloBento];

/// Estilos que existen en el código pero **no se ofrecen** (el dueño no aprobó
/// Swagger, D26). Se conservan por si se retoman; ninguna pantalla los usa.
const List<Estilo> estilosSinUsar = [estiloSwagger];

/// Busca un estilo por su id; si no existe, regresa el estilo por defecto.
Estilo estiloPorId(String id, {List<Estilo> catalogo = estilosIncluidos}) {
  for (final estilo in catalogo) {
    if (estilo.id == id) return estilo;
  }
  return estiloPorDefecto;
}
