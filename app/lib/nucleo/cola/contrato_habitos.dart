/// Lo que la cola sabe de dos escrituras de **Hábitos** que «Mi gimnasio» hace
/// al terminar una sesión (spec `docs/specs/fase-8-habitos-gimnasio.md`, 9.1,
/// H-12, CA-G-32; cierre G6-A1):
///
/// - el **registro del día** (`hab_registros`: el bloque de la agenda y el
///   objetivo «Entrenamiento» quedan «hecho» o «parcial»), y
/// - el **objetivo «Entrenamiento»** (`hab_objetivos`), que el registro necesita.
///
/// Sin señal, la sesión no debe quedarse sin cerrar: el servicio intenta
/// escribir directo (como siempre) y, si falla, deja esto en la cola con los
/// tipos de abajo. Lo registrado nunca se pierde.
///
/// - Ambos tipos llevan el prefijo `habitos.`: son **personales**
///   ([esTipoPersonal]) y nunca salen con el origen «tablet de la casa».
/// - **Registro: upsert** (`INSERT … ON CONFLICT (id) DO UPDATE`), último gana
///   por `modificado_en`, como `hab_registros` ya lo hace con la escritura
///   directa. El `id` es estable (UUID v5 del bloque u objetivo y la fecha), así
///   que un reintento no duplica ni choca con el índice de un elemento por día.
/// - **Objetivo: insertar y no pisar** (`ON CONFLICT (id) DO NOTHING`, por
///   `tablas` del enviador): sin señal el servicio no sabe si la persona ya
///   cambió el título o la meta, y reponer el objetivo no debe deshacerlo.
/// - **Orden de subida:** el objetivo antes que el registro (llave foránea); si
///   aun así falta algo (23503, por ejemplo el bloque de la agenda), se
///   reintenta.
library;

import 'contrato_gimnasio.dart' show DestinoUpsert;

/// Tipos de la cola de Hábitos que usa «Mi gimnasio».
abstract final class TipoColaHabitos {
  static const registro = 'habitos.registro';
  static const objetivo = 'habitos.objetivo';
}

/// Tipo → destino de las escrituras por upsert.
const Map<String, DestinoUpsert> destinosUpsertHabitos = {
  TipoColaHabitos.registro: DestinoUpsert('hab_registros', 'id', llevaId: true),
};

/// Tipo → tabla de las altas que **no pisan** lo que ya hay (`DO NOTHING`).
const Map<String, String> tablasInsertarHabitos = {
  TipoColaHabitos.objetivo: 'hab_objetivos',
};

/// Nivel de subida por tabla (cada ronda sube primero los de nivel menor).
const Map<String, int> nivelesDeSubidaHabitos = {
  'hab_objetivos': 0,
  'hab_registros': 1,
};
