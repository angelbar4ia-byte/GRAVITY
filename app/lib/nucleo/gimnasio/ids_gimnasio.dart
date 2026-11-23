/// Ids estables de «Mi gimnasio» (spec 4.2 y convención 3): UUID v5 para lo que
/// no debe duplicarse al reintentar, UUID v4 (del dispositivo) para las bandas.
///
/// - **Sesión:** v5 de (persona, fecha, plantilla). El servidor tiene además un
///   único `(persona_id, fecha, plantilla)`: con otro id para el mismo día y
///   plantilla da 23505, que la cola trata como permanente.
/// - **Serie:** v5 de (persona, sesión, ejercicio, número y lado).
///
/// El espacio de nombres es propio del módulo y **nunca cambia**: cambiarlo
/// haría que el mismo hecho produjera otro id y se duplicara.
library;

import 'package:uuid/uuid.dart';

import 'uuid_v5.dart';

/// Espacio de nombres de los ids del gimnasio (v4 fijo, no es secreto).
const espacioIdsGimnasio = '3c9d6f1e-7a2b-4d58-9e41-5b0c8a7d2f63';

abstract final class IdsGimnasio {
  static String _fecha(DateTime f) =>
      '${f.year.toString().padLeft(4, '0')}-'
      '${f.month.toString().padLeft(2, '0')}-'
      '${f.day.toString().padLeft(2, '0')}';

  /// Id de la sesión de [persona] del día [fecha] con la [plantilla] (`A`, `B`,
  /// `C`, `R1` o `R2`). Solo cuenta el día, no la hora.
  static String sesion(String persona, DateTime fecha, String plantilla) =>
      uuidV5(espacioIdsGimnasio, 'sesion|$persona|${_fecha(fecha)}|$plantilla');

  /// Id de una serie: la misma serie (misma sesión, ejercicio, número y lado)
  /// da siempre el mismo id. [lado] es `izquierdo`, `derecho` o `null`.
  static String serie(
    String persona,
    String sesionId,
    String ejercicioId,
    int n, {
    String? lado,
  }) => uuidV5(
    espacioIdsGimnasio,
    'serie|$persona|$sesionId|$ejercicioId|$n|${lado ?? ''}',
  );

  /// Id nuevo de una banda (v4, del dispositivo).
  static String banda() => const Uuid().v4();
}
