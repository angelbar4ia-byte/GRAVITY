// Datos del ejemplo con números de 5.6 bis, punto 5 (hogar de Ana y Alex).
// Montos ilustrativos del diseño, no datos reales.
import 'package:finanzas_dominio/finanzas_dominio.dart';

final semanaEjemplo = Semana.de(Fecha(2026, 10, 26));

const ingresosEjemplo = [
  IngresoPlan(
    id: 'ana',
    nombre: 'Sueldo de Ana (neto)',
    monto: 900000,
    frecuencia: Frecuencia.quincenal,
  ),
  IngresoPlan(
    id: 'alex',
    nombre: 'Sueldo de Alex (neto)',
    monto: 1400000,
    frecuencia: Frecuencia.mensual,
  ),
];

const partidasEjemplo = [
  PartidaPlan.fija(
    id: 'renta',
    nombre: 'Renta',
    monto: 800000,
    frecuencia: Frecuencia.mensual,
    protegida: true,
  ),
  PartidaPlan.fija(
    id: 'luz',
    nombre: 'Luz',
    monto: 90000,
    frecuencia: Frecuencia.bimestral,
    protegida: true,
  ),
  PartidaPlan.fija(
    id: 'agua',
    nombre: 'Agua',
    monto: 30000,
    frecuencia: Frecuencia.mensual,
    protegida: true,
  ),
  PartidaPlan.fija(
    id: 'internet',
    nombre: 'Internet',
    monto: 40000,
    frecuencia: Frecuencia.mensual,
    protegida: true,
  ),
  PartidaPlan.fija(
    id: 'celular',
    nombre: 'Celular',
    monto: 35000,
    frecuencia: Frecuencia.mensual,
  ),
  PartidaPlan.reserva(
    id: 'placas-predial',
    nombre: 'Reserva: placas y predial',
    monto: 156000,
    frecuencia: Frecuencia.anual,
  ),
  PartidaPlan.variable(
    id: 'alimentacion',
    nombre: 'Alimentación',
    montoSemanal: 150000,
    prioridad: Prioridad.necesario,
  ),
  PartidaPlan.variable(
    id: 'transporte',
    nombre: 'Transporte',
    montoSemanal: 70000,
    prioridad: Prioridad.necesario,
  ),
  PartidaPlan.variable(id: 'salud', nombre: 'Salud', montoSemanal: 30000),
  PartidaPlan.variable(id: 'limpieza', nombre: 'Limpieza', montoSemanal: 15000),
  PartidaPlan.variable(
    id: 'cuidado-personal',
    nombre: 'Cuidado personal',
    montoSemanal: 15000,
  ),
  PartidaPlan.variable(
    id: 'entretenimiento',
    nombre: 'Entretenimiento',
    montoSemanal: 25000,
    prioridad: Prioridad.discrecional,
  ),
  PartidaPlan.variable(
    id: 'vestimenta',
    nombre: 'Vestimenta',
    montoSemanal: 20000,
    prioridad: Prioridad.discrecional,
  ),
];

final tarjetaEjemplo = DeudaPlan(
  id: 'tarjeta',
  nombre: 'Tarjeta de crédito',
  tipo: TipoDeuda.conCosto,
  abono: 120000,
  frecuencia: Frecuencia.mensual,
  tasaAnualPuntosBase: 4800,
  saldo: 600000,
);

final prestamoFamiliarEjemplo = DeudaPlan(
  id: 'familiar',
  nombre: 'Préstamo familiar',
  tipo: TipoDeuda.familiar,
  abono: 50000,
  frecuencia: Frecuencia.mensual,
  saldo: 300000,
);

PlanSemanal planEjemplo({
  List<IngresoPlan> ingresos = ingresosEjemplo,
  List<PartidaPlan> partidas = partidasEjemplo,
  List<DeudaPlan>? deudas,
  ParametrosPlan parametros = const ParametrosPlan(),
}) => armarPlanSemanal(
  semana: semanaEjemplo,
  ingresos: ingresos,
  partidas: partidas,
  deudas: deudas ?? [tarjetaEjemplo, prestamoFamiliarEjemplo],
  parametros: parametros,
);

/// Gasto exacto de lo asignado en cada partida, con ajustes por partida.
Map<String, int> gastoSegunPlan(
  PlanSemanal plan, [
  Map<String, int> diferencias = const {},
]) => {
  for (final r in plan.partidas)
    r.origen.id: r.semanal + (diferencias[r.origen.id] ?? 0),
};
