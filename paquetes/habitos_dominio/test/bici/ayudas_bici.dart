import 'package:habitos_dominio/habitos_dominio.dart';

/// Lunes 30/nov/2026; el sábado de la ruta es el 5/dic/2026 (ejemplos
/// inventados de la especificación).
final lunes30nov = dia(2026, 11, 30);
final sabado5dic = dia(2026, 12, 5);

DateTime t(int d, int h, int m, {int mes = 12}) =>
    DateTime.utc(2026, mes, d, h, m);

const revision1430 = 14 * 60 + 30;

/// Una salida de ejemplo.
Salida salida(
  String id,
  DateTime fecha, {
  int n = 1,
  String? bici = 'a',
  int? duracion,
  int? distanciaM,
  int? esfuerzo,
  EstadoSalida estado = EstadoSalida.hecha,
  MotivoOmision? motivo,
  SuperficieSalida? superficie,
}) => Salida(
  id: id,
  fecha: fecha,
  n: n,
  bicicletaId: bici,
  duracionMin: duracion,
  distanciaM: distanciaM,
  esfuerzo: esfuerzo,
  superficie: superficie,
  estado: estado,
  motivo: motivo,
);

const biciA = Bicicleta(id: 'a', nombre: 'Mi bici', odometroInicialM: 350000);
const biciB = Bicicleta(id: 'b', nombre: 'La otra', odometroInicialM: 1000000);

RegistroMantenimiento hecho(
  String id,
  TareaMantenimiento tarea,
  DateTime fecha, {
  String bici = 'a',
  int? odometroM,
}) => RegistroMantenimiento(
  id: id,
  bicicletaId: bici,
  tarea: tarea,
  fecha: fecha,
  odometroM: odometroM,
);

/// Pone un plan en el calendario de la semana del 30/nov/2026: fuerza y
/// regenerativas a las 19:15 y la bicicleta a las 8:00 del sábado.
List<SesionProgramada> calendario(PlanSemana plan) => [
  for (final e in plan.porDia.entries)
    if (e.value != 'descanso')
      SesionProgramada(
        e.value,
        DateTime.utc(
          2026,
          11,
          30 + e.key - 1,
          e.value == 'bici' ? 8 : 19,
          e.value == 'bici' ? 0 : 15,
        ),
      ),
];
