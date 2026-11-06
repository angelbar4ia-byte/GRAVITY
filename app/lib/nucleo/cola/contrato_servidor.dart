/// Lo que la cola sabe del contrato del servidor para Finanzas
/// (`supabase/README.md`, «Finanzas (Fase 1)» › «Contrato para la app»):
///
/// - [columnasQuePoneElServidor]: columnas que la carga **nunca** lleva
///   (`recibido_en`, `libro_origen_id`, `libro_destino_id`, las generadas…):
///   no tienen permiso de columna de INSERT y mandarlas da 42501.
/// - [nivelesDeSubidaFinanzas]: en qué orden suben las tablas porque unas
///   dependen de otras.
///
/// La prueba `test/nucleo/cola/contrato_servidor_test.dart` lee las migraciones
/// y falla si cualquiera de las dos tablas deja de coincidir con el servidor.
library;

/// Columnas de cada tabla que **pone el servidor** (sin permiso de INSERT para
/// la app): las que llenan sus triggers y las generadas. Una tabla que no
/// aparece aquí no tiene ninguna.
///
/// Distinto de las columnas que la app puede mandar y el servidor sobrescribe
/// (`fin_cuentas.creada_por`, `fin_dias_inhabiles.revisado_*`,
/// `fin_semanas.activada_*`): esas sí pueden ir en la carga.
const Map<String, Set<String>> columnasQuePoneElServidor = {
  'fin_libros': {'creado_por', 'creado_en'},
  'fin_cuentas': {'clase', 'liquida', 'creada_en'},
  'fin_movimientos': {'recibido_en', 'libro_origen_id', 'libro_destino_id'},
  'fin_semanas': {'reaperturas'},
  // Fase 2: la pendiente de la aportación es generada; quién y cuándo la
  // confirma y cuándo llegó un estado de cuenta o un retiro los pone el servidor.
  'fin_aportaciones_ahorro': {
    'pendiente_centavos',
    'confirmada_por',
    'confirmada_en',
  },
  'fin_estados_cuenta': {'recibido_en'},
  'fin_retiros_ahorro': {'recibido_en'},
  'fin_cierre_abonos': {'diferido'},
  'fin_conciliaciones': {'diferencia'},
};

/// [carga] sin las columnas que pone el servidor para [tabla]. Devuelve una
/// copia; no cambia [carga].
Map<String, Object?> sinColumnasDelServidor(
  String tabla,
  Map<String, Object?> carga, {
  Map<String, Set<String>> columnas = columnasQuePoneElServidor,
}) {
  final fuera = columnas[tabla];
  return {
    for (final MapEntry(:key, :value) in carga.entries)
      if (fuera == null || !fuera.contains(key)) key: value,
  };
}

/// Clave de [nivelesDeSubidaFinanzas] para un **cambio** (UPDATE) de [tabla],
/// distinto de sus altas: p. ej. marcar la semana cerrada.
String claveDeActualizacion(String tabla) => '$tabla#actualizar';

/// Nivel de subida de cada tabla de Finanzas: cada ronda sube primero los de
/// nivel menor. Sigue las llaves foráneas del servidor (la prueba las lee de
/// las migraciones) y las reglas de escritura, y con ellas el orden del
/// contrato:
///
/// - **cuentas antes que movimientos**;
/// - **el ajuste (un movimiento) antes que su conciliación**;
/// - **el cierre con sus partidas y abonos antes de marcar la semana
///   cerrada**; hacerlo al revés da 55000.
///
/// Un cambio de estado de la semana (cerrarla) es el último nivel. **Reabrir
/// una semana no debe encolarse** junto con un cierre nuevo de la misma
/// semana: necesita señal y confirmación (queda en la bitácora) y el servidor
/// exige que la versión del cierre siga a la reapertura.
const Map<String, int> nivelesDeSubidaFinanzas = {
  // Lo que no depende de nada de Finanzas.
  'fin_libros': 0,
  'fin_categorias': 0,
  // Quién lleva el libro (sin ser miembro no se puede escribir en él).
  'fin_libro_miembros': 1,
  // Cuentas (de libro y de gasto).
  'fin_cuentas': 2,
  // Configuración y plan: dependen de libros y cuentas.
  'fin_parametros': 3,
  'fin_ingresos': 3,
  'fin_compromisos': 3,
  'fin_sobres': 3,
  'fin_deudas': 3,
  'fin_bolsas_ahorro': 3,
  'fin_dias_inhabiles': 3,
  'fin_semanas': 3,
  // Dependen de lo anterior.
  'fin_vigencias_ingreso': 4,
  'fin_partidas_semana': 4,
  'fin_abonos_semana': 4,
  // Fase 2: dependen de deudas y cuentas.
  'fin_msi': 4,
  'fin_estados_cuenta': 4,
  // El libro de movimientos.
  'fin_movimientos': 5,
  // Dependen de movimientos, semanas o partidas.
  'fin_ocurrencias': 6,
  'fin_conciliaciones': 6,
  'fin_cierres': 6,
  'fin_importaciones': 6,
  // Fase 2: dependen de la semana, la bolsa y el movimiento.
  'fin_aportaciones_ahorro': 6,
  'fin_retiros_ahorro': 6,
  // Dependen del cierre.
  'fin_cierre_partidas': 7,
  'fin_cierre_abonos': 7,
  // Marcar la semana cerrada: al final.
  'fin_semanas#actualizar': 8,
};
