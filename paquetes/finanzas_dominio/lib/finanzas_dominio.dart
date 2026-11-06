/// Lógica pura del módulo Finanzas de GRAVITY (Dart sin Flutter).
///
/// Base: diseño de FINANZAS v23 (`docs/modulos/finanzas/`) y la
/// especificación de la Fase 1 (`docs/specs/fase-1-finanzas.md`).
///
/// - Dinero en **centavos** (`int`) con redondeo explícito ([dividirRedondeando]).
/// - Semana de **lunes a domingo** ([Semana]).
/// - Equivalentes semanales por frecuencia ([Equivalente]).
/// - Calendario de días hábiles y fechas de pago ([ajustarADiaHabil]).
/// - Vista de flujo con peor caso ([proyectarFlujo]).
/// - Libro de movimientos **solo-agregar** con anulación por contraasiento
///   ([LibroMovimientos]).
/// - Motor del presupuesto semanal y la cascada ([armarPlanSemanal],
///   [cerrarSemana]) con el grupo de deudas prioritarias.
/// - Libros personales, compartidos y representado (D19) con su permiso
///   ([permisoEnLibro]) y su vista ([vistaDelLibro]).
/// - Configuración por libro ([Ingreso], [Compromiso], [Sobre], [Deuda]),
///   categorías e importador de la plantilla ([planearImportacionCategorias])
///   y seguimiento de la semana ([vistaSemana]).
library;

export 'src/ahorro.dart';
export 'src/ahorro_datos.dart';
export 'src/alertas.dart';
export 'src/calendario.dart';
export 'src/categorias.dart';
export 'src/cierre_ahorro.dart';
export 'src/configuracion.dart';
export 'src/datos_finanzas.dart';
export 'src/deudas_detalle.dart';
export 'src/dinero.dart';
export 'src/fecha.dart';
export 'src/flujo.dart';
export 'src/frecuencia.dart';
export 'src/indicadores.dart';
export 'src/libro.dart';
export 'src/libros.dart';
export 'src/motivo.dart';
export 'src/plan_guardado.dart';
export 'src/presupuesto.dart';
export 'src/proyeccion_deuda.dart';
export 'src/semana.dart';
export 'src/seguimiento.dart';
