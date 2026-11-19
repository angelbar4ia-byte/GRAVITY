/// Parámetros del bloque 6 de la Fase 8 (fugas silenciosas y deuda buena o
/// mala). Dart puro, sin red ni IA (D3).
///
/// **Todos los umbrales viven aquí** y ninguna regla escribe un número suelto.
/// Cada valor por omisión es una **[Propuesta]** de
/// `docs/specs/fase-8-fugas-y-deudas.md` (v0.3), salvo los que la propia
/// especificación toma de una fuente; la persona los puede editar por libro
/// (`fin_fuga_parametros`).
///
/// Los umbrales de carga de deuda (20 y 35 %) y de uso del límite (30 y 60 %)
/// no se repiten: la carga viene de [Umbrales] y el uso del límite de
/// `usoDelLimite`, que ya los trae.
library;

import 'dinero.dart';
import 'indicadores.dart';

/// Cadencia de un cobro que se repite (sección 3.0).
enum CadenciaCobro {
  semanal,
  quincenal,
  mensual,
  bimestral,
  anual,

  /// No cumple ninguna cadencia regular.
  irregular,
}

/// Días esperados entre cobros de una [cadencia] y su tolerancia (± días).
class ToleranciaCadencia {
  final CadenciaCobro cadencia;
  final int dias;
  final int tolerancia;

  const ToleranciaCadencia(this.cadencia, this.dias, this.tolerancia);
}

/// Umbrales editables por libro. Valores por omisión: **propuesta**.
class ParametrosFugas {
  // ------------------------------------------------------------- hormiga
  /// H2: tope por gasto, en centavos ($150.00). Propuesta (pregunta 2).
  final int topeHormigaCentavos;

  /// H3: gastos mínimos en la ventana. Propuesta.
  final int hormigaMinGastos;

  /// Semanas completas de la ventana de hormiga ("últimas 4 semanas").
  final int hormigaSemanasVentana;

  /// H4: semanas distintas (de la ventana) con al menos un gasto. Propuesta.
  final int hormigaMinSemanas;

  /// H5: suma mínima como puntos base del ingreso mensual de referencia
  /// (100 = 1 %). Propuesta.
  final int hormigaMinIngresoPb;

  /// Alerta de conjunto de todas las hormigas (500 = 5 %). Propuesta.
  final int hormigaConjuntoPb;

  // ----------------------------------------------------------- recurrente
  /// Cobros mínimos para hablar de patrón recurrente. Propuesta.
  final int recurrenteMinCobros;

  /// Tolerancia del monto contra la mediana (1000 = 10 %). Propuesta.
  final int recurrenteTolerancia;

  /// Días entre cobros por cadencia (semanal 7 ± 1, etc.). Propuesta.
  final List<ToleranciaCadencia> tolerancias;

  /// Un patrón sin comercio agrupa montos parecidos con esta tolerancia (pb).
  final int sinComercioTolerancia;

  // -------------------------------------------------------------- vampiro
  /// VB2: crecimiento del último cobro contra el primero (1000 = 10 %).
  final int vampiroCrecimientoPb;

  /// VB2: aumentos seguidos que bastan. Propuesta.
  final int vampiroAumentosSeguidos;

  /// VB2: días de historia que se miran (los últimos 12 meses).
  final int vampiroDiasHistoria;

  /// VA2: periodos que se miran y cuántos deben traer el cargo (2 de 3).
  final int cargoPeriodosVentana;
  final int cargoPeriodosMin;

  /// VC1: periodos mínimos de historia de un servicio del hogar. Propuesta.
  final int servicioPeriodosMin;

  /// VC2: periodos de la mediana. Propuesta.
  final int servicioPeriodosMediana;

  /// VC3: exceso sobre la mediana (2500 = 25 %). Propuesta.
  final int servicioMedianaPb;

  /// VC3: ventana reciente y cuántos periodos deben superar (2 de 3).
  final int servicioVentana;
  final int servicioMinSuperan;

  // --------------------------------------------------------------- zombie
  /// Z1: "No lo usé" seguidas que bastan. Propuesta.
  final int zombieRespuestas;

  /// Preguntas de una revisión mensual (D25). Propuesta.
  final int revisionMaxPreguntas;

  /// Pregunta de una anual: días antes del cobro esperado. Propuesta.
  final int preguntaAnualDiasAntes;

  // ---------------------------------------------------- persona y bitácora
  /// Cambio material que vuelve a preguntar (1000 = 10 %).
  final int cambioMaterialPb;

  /// Meses sin revisar que vuelven a preguntar una decisión (12).
  final int cambioMaterialMeses;

  /// Meses tras los que "Vigilar" vuelve a preguntar (3).
  final int vigilarMeses;

  /// Motivo de una decisión: longitud mínima y máxima (como un ajuste).
  final int motivoMin;
  final int motivoMax;

  /// Folio de cancelación: máximo de caracteres (`[A-Za-z0-9-]`).
  final int folioMax;

  // ------------------------------------------------------- deuda buena/mala
  /// B4b: MSI ÷ ingreso mensual. Ámbar arriba de 1000 pb (10 %), rojo arriba
  /// de 2000 pb (20 %). Propuesta sin fuente.
  final int msiAmbarPb;
  final int msiRojoPb;

  /// B4c: MSI activos a la vez. Ámbar desde 3, rojo desde 4. Propuesta.
  final int msiActivosAmbar;
  final int msiActivosRojo;

  /// B3: plazo máximo en meses de un MSI sin alerta (18). Propuesta.
  final int plazoAmbarMeses;

  /// B6a: pagos que se miran y atrasos que encienden ámbar y rojo.
  final int atrasosVentana;
  final int atrasosAmbar;
  final int atrasosRojo;

  /// M1: un MSI nuevo "encadena" si otro tiene a lo más estas mensualidades
  /// pendientes, o terminó hace a lo más estos días.
  final int encadenaPendientesMax;
  final int encadenaDiasTrasFin;

  /// M1: encadenamientos en 12 meses que encienden ámbar y rojo.
  final int encadenaAmbar;
  final int encadenaRojo;

  /// Evaluaciones semanales seguidas sin la señal para bajar de nivel (2).
  final int bajaNivelEvaluaciones;

  /// Carga de deuda (20 y 35 %); uso del límite usa `usoDelLimite`.
  final Umbrales umbrales;

  const ParametrosFugas({
    this.topeHormigaCentavos = 15000,
    this.hormigaMinGastos = 8,
    this.hormigaSemanasVentana = 4,
    this.hormigaMinSemanas = 3,
    this.hormigaMinIngresoPb = 100,
    this.hormigaConjuntoPb = 500,
    this.recurrenteMinCobros = 3,
    this.recurrenteTolerancia = 1000,
    this.tolerancias = const [
      ToleranciaCadencia(CadenciaCobro.semanal, 7, 1),
      ToleranciaCadencia(CadenciaCobro.quincenal, 15, 2),
      ToleranciaCadencia(CadenciaCobro.mensual, 30, 3),
      ToleranciaCadencia(CadenciaCobro.bimestral, 61, 4),
      ToleranciaCadencia(CadenciaCobro.anual, 365, 7),
    ],
    this.sinComercioTolerancia = 1000,
    this.vampiroCrecimientoPb = 1000,
    this.vampiroAumentosSeguidos = 3,
    this.vampiroDiasHistoria = 365,
    this.cargoPeriodosVentana = 3,
    this.cargoPeriodosMin = 2,
    this.servicioPeriodosMin = 6,
    this.servicioPeriodosMediana = 12,
    this.servicioMedianaPb = 2500,
    this.servicioVentana = 3,
    this.servicioMinSuperan = 2,
    this.zombieRespuestas = 2,
    this.revisionMaxPreguntas = 7,
    this.preguntaAnualDiasAntes = 30,
    this.cambioMaterialPb = 1000,
    this.cambioMaterialMeses = 12,
    this.vigilarMeses = 3,
    this.motivoMin = 3,
    this.motivoMax = 200,
    this.folioMax = 40,
    this.msiAmbarPb = 1000,
    this.msiRojoPb = 2000,
    this.msiActivosAmbar = 3,
    this.msiActivosRojo = 4,
    this.plazoAmbarMeses = 18,
    this.atrasosVentana = 6,
    this.atrasosAmbar = 1,
    this.atrasosRojo = 2,
    this.encadenaPendientesMax = 2,
    this.encadenaDiasTrasFin = 30,
    this.encadenaAmbar = 2,
    this.encadenaRojo = 3,
    this.bajaNivelEvaluaciones = 2,
    this.umbrales = Umbrales.porDefecto,
  });

  /// Valores por omisión (todos son propuesta).
  static const ParametrosFugas porDefecto = ParametrosFugas();
}

/// Ingreso mensual de referencia: `ingreso semanal × 52 ÷ 12` (R1).
int ingresoMensualDeReferencia(int ingresoSemanalCentavos) =>
    dividirRedondeando(ingresoSemanalCentavos * 52, 12);
