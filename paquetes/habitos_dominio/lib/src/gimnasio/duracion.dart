/// Modelo de tiempo (5.5, PG-06): duración = calentamiento + Σ por ejercicio
/// (`cambio` + series × (`trabajo` + `descanso`)) + cierre, en segundos
/// enteros.
library;

import 'registro.dart';
import 'reglas.dart';
import 'sesion_planificada.dart';

class ModeloTiempo {
  const ModeloTiempo({
    this.segundosPorRepeticion = 4,
    this.segundosCambio = 45,
    this.calibrado = false,
  });

  factory ModeloTiempo.deReglas(ReglasGimnasio r) => ModeloTiempo(
    segundosPorRepeticion: r.segundosPorRepeticion,
    segundosCambio: r.segundosCambio,
  );

  final int segundosPorRepeticion;
  final int segundosCambio;

  /// ¿Salió de las sesiones de la persona?
  final bool calibrado;
}

/// Mediana de enteros; con cantidad par, el promedio redondeado hacia arriba.
int mediana(List<int> v) {
  final s = [...v]..sort();
  final n = s.length;
  if (n.isOdd) return s[n ~/ 2];
  return (s[n ~/ 2 - 1] + s[n ~/ 2] + 1) ~/ 2;
}

/// Calibración (CA-G-12): con al menos [ReglasGimnasio.calibracionSesiones]
/// sesiones que tengan `descanso_real_s` y tiempos medidos, se sustituyen los
/// 4 s por repetición y los 45 s de cambio por la **mediana** de la persona.
/// Con menos, se usan los valores de 5.5.
ModeloTiempo calibrarModelo(
  List<SesionRegistrada> sesiones, {
  ReglasGimnasio reglas = const ReglasGimnasio(),
}) {
  final validas = [
    for (final s in sesiones)
      if (s.terminada &&
          s.tiempos != null &&
          s.series.any((x) => x.descansoRealS != null))
        s.tiempos!,
  ];
  if (validas.length < reglas.calibracionSesiones) {
    return ModeloTiempo.deReglas(reglas);
  }
  return ModeloTiempo(
    segundosPorRepeticion: mediana([
      for (final t in validas) t.segundosPorRepeticion,
    ]),
    segundosCambio: mediana([for (final t in validas) t.segundosCambio]),
    calibrado: true,
  );
}

/// Segundos de trabajo de una serie: repeticiones medias × segundos por
/// repetición (por pierna: ×2) o los segundos medios del rango.
int trabajoSerieSegundos(EjercicioPlanificado e, ModeloTiempo m) {
  final suma = e.rangoMin + e.rangoMax;
  final t = e.porTiempo ? suma ~/ 2 : suma * m.segundosPorRepeticion ~/ 2;
  return e.porLado ? t * 2 : t;
}

int duracionEjercicioSegundos(EjercicioPlanificado e, ModeloTiempo m) =>
    m.segundosCambio + e.series * (trabajoSerieSegundos(e, m) + e.descansoS);

int duracionSegundos(
  List<EjercicioPlanificado> ejercicios, {
  required int calentamientoMin,
  required int cierreMin,
  required ModeloTiempo modelo,
}) {
  var t = calentamientoMin * 60 + cierreMin * 60;
  for (final e in ejercicios) {
    t += duracionEjercicioSegundos(e, modelo);
  }
  return t;
}

/// Décimas de minuto, **truncadas** (la especificación muestra 63.15 como
/// 63.1 y 31.25 como 31.2): 2118 s → 353 (35.3 min).
int decimasDeMinuto(int segundos) => segundos * 10 ~/ 60;

/// «35.3» para 2118 s.
String minutosConDecimal(int segundos) {
  final d = decimasDeMinuto(segundos);
  return '${d ~/ 10}.${d % 10}';
}
