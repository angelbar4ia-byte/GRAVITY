/// Lo que la cola sabe del servidor de «Mi gimnasio» (migración
/// `20261152000000_habitos_gimnasio.sql`, `supabase/README.md` › «Entrenamiento:
/// tablas `hab_ent_*`»; spec `docs/specs/fase-8-habitos-gimnasio.md`, 9.1,
/// H-12 y CA-G-32):
///
/// - **Tipos de la cola** `habitos.gim_*`, uno por tabla. Todos llevan el
///   prefijo `habitos.`: son **personales** ([esTipoPersonal]) y nunca salen con
///   el origen «tablet de la casa».
/// - **Subida por upsert** (`INSERT … ON CONFLICT (llave) DO UPDATE`): las seis
///   tablas son **editables con último-gana** por `modificado_en` (a diferencia
///   de Finanzas, que inserta con `DO NOTHING`): una sesión se sube `en_curso` y
///   después `completa` con el mismo id. Un reintento con el mismo contenido no
///   duplica; con otro contenido gana el `modificado_en` más reciente.
/// - **Orden de subida** por llaves foráneas: perfil, inventario, bandas y plan
///   (sin dependencias); luego sesiones (apuntan a un bloque de Hábitos, que si
///   aún no existe da 23503 y se reintenta); luego series (apuntan a la sesión y
///   a la banda). Los borrados, al final: borrar una banda antes de subir las
///   series que la usan daría 23503.
/// - **Columnas que pone el servidor** (`persona_id`, `hogar_id`,
///   `actualizado_en`): sin permiso de INSERT; mandarlas da 42501.
/// - **Errores:** 23514 (regla de la tabla), 23505 (el mismo día y plantilla, o
///   la misma serie, con **otro id**: duplicado real), 42501 (sin permiso) y
///   54000 (cuota de filas) son **permanentes**: requieren atención y no se
///   reintentan; 23503 (falta la sesión, la banda o el bloque) **se reintenta**.
///
/// La prueba `test/nucleo/gimnasio/contrato_gimnasio_test.dart` lee la
/// migración y falla si cualquiera de estas tablas deja de coincidir con ella.
library;

import 'contrato_servidor.dart';

/// Tipos de la cola de «Mi gimnasio».
abstract final class TipoColaGimnasio {
  static const perfil = 'habitos.gim_perfil';
  static const planDia = 'habitos.gim_plan_dia';
  static const inventario = 'habitos.gim_inventario';
  static const banda = 'habitos.gim_banda';
  static const sesion = 'habitos.gim_sesion';
  static const serie = 'habitos.gim_serie';

  /// Borrados (deshacer la última serie, quitar una banda o una sesión).
  static const bandaBorrar = 'habitos.gim_banda_borrar';
  static const sesionBorrar = 'habitos.gim_sesion_borrar';
  static const serieBorrar = 'habitos.gim_serie_borrar';

  static const altas = {perfil, planDia, inventario, banda, sesion, serie};
  static const borrados = {bandaBorrar, sesionBorrar, serieBorrar};
  static const todos = {...altas, ...borrados};

  /// Prefijo de todos (para borrar lo pendiente de una persona).
  static const prefijo = 'habitos.gim_';
}

/// A qué tabla sube un tipo y por qué llave resuelve el conflicto.
class DestinoUpsert {
  const DestinoUpsert(this.tabla, this.onConflict, {this.llevaId = false});

  final String tabla;

  /// Columnas del `ON CONFLICT` (lo que PostgREST llama `on_conflict`).
  final String onConflict;

  /// `true` si la fila lleva su propio `id` (v4 de la banda; v5 de la sesión y
  /// de la serie): el de la carga, no el de la petición de la cola.
  final bool llevaId;
}

/// Tipo → destino de las altas y los cambios (upsert).
const Map<String, DestinoUpsert> destinosUpsertGimnasio = {
  TipoColaGimnasio.perfil: DestinoUpsert('hab_ent_perfil', 'persona_id'),
  TipoColaGimnasio.planDia: DestinoUpsert(
    'hab_ent_plan_dias',
    'persona_id,dia_semana',
  ),
  TipoColaGimnasio.inventario: DestinoUpsert(
    'hab_ent_inventario',
    'persona_id,item_id',
  ),
  TipoColaGimnasio.banda: DestinoUpsert('hab_ent_bandas', 'id', llevaId: true),
  TipoColaGimnasio.sesion: DestinoUpsert(
    'hab_ent_sesiones',
    'id',
    llevaId: true,
  ),
  TipoColaGimnasio.serie: DestinoUpsert('hab_ent_series', 'id', llevaId: true),
};

/// Tipo → tabla de los borrados por `id` (idempotentes: 0 filas no es error).
const Map<String, String> borradosGimnasio = {
  TipoColaGimnasio.bandaBorrar: 'hab_ent_bandas',
  TipoColaGimnasio.sesionBorrar: 'hab_ent_sesiones',
  TipoColaGimnasio.serieBorrar: 'hab_ent_series',
};

/// Nivel de subida por tabla (cada ronda sube primero los de nivel menor) y,
/// con `#borrar`, el de sus borrados.
const Map<String, int> nivelesDeSubidaGimnasio = {
  'hab_ent_perfil': 0,
  'hab_ent_inventario': 0,
  'hab_ent_bandas': 0,
  'hab_ent_plan_dias': 0,
  'hab_ent_sesiones': 1,
  'hab_ent_series': 2,
  'hab_ent_series#borrar': 3,
  'hab_ent_sesiones#borrar': 3,
  'hab_ent_bandas#borrar': 3,
};

/// Clave de [nivelesDeSubidaGimnasio] para los borrados de [tabla].
String claveDeBorrado(String tabla) => '$tabla#borrar';

const _lasTres = {'persona_id', 'hogar_id', 'actualizado_en'};

/// Columnas que **pone el servidor** en cada tabla: la carga nunca las lleva.
const Map<String, Set<String>> columnasQuePoneElServidorGimnasio = {
  'hab_ent_perfil': _lasTres,
  'hab_ent_plan_dias': _lasTres,
  'hab_ent_inventario': _lasTres,
  'hab_ent_bandas': _lasTres,
  'hab_ent_sesiones': _lasTres,
  'hab_ent_series': _lasTres,
};

/// Columnas que la app **puede mandar** a cada tabla (las del `grant insert`).
/// La carga de cada tipo lleva solo estas, y la prueba las compara con la
/// migración.
const Map<String, Set<String>> columnasQueSeMandanGimnasio = {
  'hab_ent_perfil': {
    'dias_plan',
    'version_pref',
    'ventana',
    'noche_desde',
    'objetivo',
    'nivel',
    'inicio_ciclo',
    'ciclo_semanas',
    'descanso_s',
    'margen_dormir_min',
    'prueba_desde',
    'prueba_ventana',
    'voz_descanso',
    'aviso_visto_en',
    'modificado_en',
  },
  'hab_ent_plan_dias': {
    'dia_semana',
    'tipo',
    'version',
    'hora',
    'modificado_en',
  },
  'hab_ent_inventario': {
    'item_id',
    'estado',
    'confirmado',
    'notas',
    'modificado_en',
  },
  'hab_ent_bandas': {
    'id',
    'nombre',
    'orden',
    'resistencia_kg_x10',
    'cantidad',
    'activa',
    'modificado_en',
  },
  'hab_ent_sesiones': {
    'id',
    'fecha',
    'plantilla',
    'version',
    'semana_tipo',
    'ventana',
    'bloque_id',
    'inicio',
    'fin',
    'estado',
    'esfuerzo',
    'energia',
    'plan',
    'catalogo_version',
    'modificado_en',
  },
  'hab_ent_series': {
    'id',
    'sesion_id',
    'ejercicio_id',
    'variante_id',
    'n',
    'lado',
    'reps',
    'segundos',
    'carga_pasos',
    'banda_id',
    'esfuerzo',
    'descanso_real_s',
    'sustituye_a',
    'motivo_cambio',
    'modificado_en',
  },
};

/// Palabras que **nunca** deben estar en una carga hacia el servidor: ninguna
/// columna habla de molestias (PG-03, PG-19, CA-G-28).
const List<String> raicesProhibidasEnCarga = [
  'molest',
  'dolor',
  'zona',
  'lesion',
  'diagn',
];

/// Niveles de subida de **toda** la app (Finanzas y «Mi gimnasio»): lo que usa
/// el enviador por omisión.
const Map<String, int> nivelesDeSubidaDeLaApp = {
  ...nivelesDeSubidaFinanzas,
  ...nivelesDeSubidaGimnasio,
};

/// Columnas que pone el servidor en **todas** las tablas que sube la cola.
const Map<String, Set<String>> columnasQuePoneElServidorDeLaApp = {
  ...columnasQuePoneElServidor,
  ...columnasQuePoneElServidorGimnasio,
};

/// Tipos de sobre que **nunca** salen del equipo (PG-03): las molestias. El
/// servidor tampoco los admite; esto es la segunda cerradura, del lado de la
/// app.
const Set<String> tiposDeSobreSoloLocales = {'salud_local'};

/// `true` si la carga de una llamada a una función (`p_sobres`) lleva un sobre
/// que solo debe vivir en el equipo. No mira el contenido (va cifrado): solo
/// el tipo.
bool cargaLlevaSobreSoloLocal(Map<String, Object?> carga) {
  final sobres = carga['p_sobres'];
  if (sobres is! List) return false;
  for (final s in sobres) {
    if (s is Map && tiposDeSobreSoloLocales.contains(s['tipo'])) return true;
  }
  return false;
}
