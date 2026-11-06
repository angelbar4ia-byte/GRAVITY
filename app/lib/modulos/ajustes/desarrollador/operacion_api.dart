/// Modelo de las operaciones de `api/openapi.yaml` para Ajustes › Desarrollador
/// (D16). Los datos están en `operaciones.g.dart`, generado desde la
/// especificación con `npm run generar` en `api/`.
library;

import '../../../nucleo/contratos/roles.dart';

/// Método HTTP de una operación.
enum MetodoHttp {
  get,
  post,
  put,
  patch,
  delete;

  /// Como se muestra: `GET`, `POST`…
  String get etiqueta => name.toUpperCase();
}

/// Una operación de la especificación.
final class OperacionApi {
  const OperacionApi({
    required this.id,
    required this.metodo,
    required this.ruta,
    required this.resumen,
    required this.descripcion,
    required this.roles,
    required this.escribe,
    required this.soloLocal,
    required this.fase,
  });

  /// `operationId`.
  final String id;
  final MetodoHttp metodo;
  final String ruta;
  final String resumen;
  final String descripcion;

  /// `x-roles`: roles que la pueden usar (D5).
  final Set<Rol> roles;

  /// `x-escribe`: `true` si pide confirmación; `null` si depende de la
  /// herramienta (operación genérica de herramientas).
  final bool? escribe;

  /// `x-solo-local`: `true` si nunca pasa por la IA (D3); `null` si depende de
  /// la herramienta.
  final bool? soloLocal;

  /// `x-fase`: fase del roadmap en que se construye.
  final int fase;
}

/// Las operaciones de una etiqueta de la especificación.
final class GrupoOperaciones {
  const GrupoOperaciones({
    required this.nombre,
    required this.descripcion,
    required this.operaciones,
  });

  final String nombre;
  final String descripcion;
  final List<OperacionApi> operaciones;
}
