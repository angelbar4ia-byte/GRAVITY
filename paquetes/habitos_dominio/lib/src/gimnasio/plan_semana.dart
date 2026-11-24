/// Plan semanal, 48 horas, la bicicleta y la sesión perdida (5.6).
library;

import 'reglas.dart';
import 'tipos.dart';

/// Tipos de día del plan (4.2, `hab_ent_plan_dias.tipo`).
class TipoDia {
  static const a = 'A';
  static const b = 'B';
  static const c = 'C';
  static const r1 = 'R1';
  static const r2 = 'R2';
  static const bici = 'bici';
  static const descanso = 'descanso';

  static const fuerza = [a, b, c];
}

/// Qué toca cada día, de lunes (1) a domingo (7).
class PlanSemana {
  const PlanSemana(this.porDia);
  final Map<int, String> porDia;

  String dia(int diaSemana) => porDia[diaSemana] ?? TipoDia.descanso;

  /// Fila de siete casillas, lunes a domingo.
  List<String> get fila => [for (var d = 1; d <= 7; d++) dia(d)];

  int get sesionesDeFuerza =>
      porDia.values.where(TipoDia.fuerza.contains).length;
}

/// Plan de 3, 4 o 5 días (5.6). Por omisión sigue la **semana reordenada que
/// eligió el dueño el 24/nov/2026** (sección 22 de la especificación del
/// gimnasio) para cerrar el choque de 48 h entre la pierna y la ruta en bici
/// del sábado a las 8:00:
///
/// | Días | L | M | X | J | V | S | D |
/// |---|---|---|---|---|---|---|---|
/// | 3 | A | C | B | libre | libre | bici | descanso |
/// | 4 | A | C | B | libre | R1 | bici | descanso |
/// | 5 | A | C | B | R2 | R1 | bici | descanso |
///
/// A lunes y B miércoles comparten hombro y quedan a 48 h exactas; C el martes
/// no comparte grupo con ninguna y llega a la ruta con más de 84 h. Las
/// regenerativas caen en jueves y viernes (nunca en martes).
///
/// Variantes que se conservan (se piden con un parámetro nombrado; no se
/// pueden combinar):
/// - [cEnJueves]: la recomendación anterior (pregunta 4): A-R1-B-C-R2, con C
///   el jueves y, en el plan de 5 días, R2 el viernes. Con la ruta del sábado
///   a las 8:00 quedan 36 h 45 min y el aviso de la bicicleta sigue saliendo.
/// - [cEnViernes]: la tabla literal del diseño (A-R1-B-R2-C), con C el viernes
///   y R2 el jueves. Con la ruta quedan 12 h y el aviso sale.
///
/// El sábado es bicicleta y el domingo descanso en todas.
PlanSemana planSemanal(
  int dias, {
  bool cEnViernes = false,
  bool cEnJueves = false,
}) {
  if (dias != 3 && dias != 4 && dias != 5) {
    throw ArgumentError.value(dias, 'dias', 'el plan es de 3, 4 o 5 días');
  }
  if (cEnViernes && cEnJueves) {
    throw ArgumentError(
      'cEnViernes y cEnJueves son variantes distintas: elige una',
    );
  }
  if (cEnViernes || cEnJueves) {
    // Variantes con A el lunes, R1 el martes, B el miércoles y C al final.
    final c = cEnViernes ? 5 : 4;
    final r2 = cEnViernes ? 4 : 5;
    return PlanSemana({
      1: TipoDia.a,
      if (dias >= 4) 2: TipoDia.r1,
      3: TipoDia.b,
      c: TipoDia.c,
      if (dias == 5) r2: TipoDia.r2,
      6: TipoDia.bici,
      7: TipoDia.descanso,
    });
  }
  return PlanSemana({
    1: TipoDia.a,
    2: TipoDia.c,
    3: TipoDia.b,
    if (dias == 5) 4: TipoDia.r2,
    if (dias >= 4) 5: TipoDia.r1,
    6: TipoDia.bici,
    7: TipoDia.descanso,
  });
}

/// Una sesión puesta en el calendario (hora local del dispositivo, tratada
/// como instante UTC para restar sin cambios de horario).
class SesionProgramada {
  const SesionProgramada(this.tipo, this.inicio);
  final String tipo;
  final DateTime inicio;
}

/// Acciones que se proponen ante un aviso (sin culpa; nunca se impone).
enum AccionSemana {
  masTarde,
  otroDia,
  moverAlJueves,
  versionCorta,
  dejarComoEsta,
}

enum TipoAvisoSemana { grupoCompartido, mismoDia }

class AvisoSemana {
  const AvisoSemana({
    required this.tipo,
    required this.a,
    required this.b,
    required this.grupos,
    required this.intervaloMin,
    required this.faltanMin,
    required this.propuestas,
  });

  final TipoAvisoSemana tipo;

  /// Las dos sesiones, en orden cronológico.
  final SesionProgramada a;
  final SesionProgramada b;
  final List<String> grupos;

  /// Inicio a inicio.
  final int intervaloMin;

  /// Cuánto más tarde debería empezar la segunda para cumplir (0 si cumple).
  final int faltanMin;
  final List<AccionSemana> propuestas;
}

/// Grupos de una sesión del plan: A, B y C salen del catálogo; la bicicleta
/// cuenta como cuádriceps y glúteo; las regenerativas no cuentan (5.6).
Set<String> gruposDeTipo(Catalogo c, String tipo) {
  if (tipo == TipoDia.bici) return {Grupos.cuadriceps, Grupos.gluteo};
  return c.gruposDePlantilla(tipo);
}

/// Revisa las 48 horas y el máximo de una sesión de fuerza por día. **Avisa,
/// no bloquea** (sin culpa): el aviso lleva las propuestas.
List<AvisoSemana> revisarSemana(
  List<SesionProgramada> sesiones,
  Catalogo catalogo, {
  ReglasGimnasio reglas = const ReglasGimnasio(),
}) {
  final o = [...sesiones]..sort((x, y) => x.inicio.compareTo(y.inicio));
  final avisos = <AvisoSemana>[];
  for (var i = 0; i < o.length; i++) {
    for (var j = i + 1; j < o.length; j++) {
      final a = o[i];
      final b = o[j];
      final intervalo = b.inicio.difference(a.inicio).inMinutes;
      final mismoDia =
          TipoDia.fuerza.contains(a.tipo) &&
          TipoDia.fuerza.contains(b.tipo) &&
          a.inicio.year == b.inicio.year &&
          a.inicio.month == b.inicio.month &&
          a.inicio.day == b.inicio.day;
      if (mismoDia) {
        avisos.add(
          AvisoSemana(
            tipo: TipoAvisoSemana.mismoDia,
            a: a,
            b: b,
            grupos: const [],
            intervaloMin: intervalo,
            faltanMin: 0,
            propuestas: const [AccionSemana.otroDia],
          ),
        );
        continue;
      }
      final comunes = gruposDeTipo(
        catalogo,
        a.tipo,
      ).intersection(gruposDeTipo(catalogo, b.tipo)).toList()..sort();
      if (comunes.isEmpty || intervalo >= reglas.minimoEntreSesionesMin) {
        continue;
      }
      final falta = reglas.minimoEntreSesionesMin - intervalo;
      final conBici = a.tipo == TipoDia.bici || b.tipo == TipoDia.bici;
      final sesionC = a.tipo == TipoDia.c
          ? a
          : (b.tipo == TipoDia.c ? b : null);
      final List<AccionSemana> propuestas;
      if (conBici && sesionC != null) {
        // 5.6: mover C al jueves, C corta o dejarlo (en ese orden). Con la
        // semana por omisión (C el martes) este aviso no llega a salir.
        propuestas = [
          if (sesionC.inicio.weekday == DateTime.friday)
            AccionSemana.moverAlJueves,
          AccionSemana.versionCorta,
          AccionSemana.dejarComoEsta,
        ];
      } else {
        propuestas = [
          if (falta <= 180) AccionSemana.masTarde else AccionSemana.otroDia,
          AccionSemana.dejarComoEsta,
        ];
      }
      avisos.add(
        AvisoSemana(
          tipo: TipoAvisoSemana.grupoCompartido,
          a: a,
          b: b,
          grupos: comunes,
          intervaloMin: intervalo,
          faltanMin: falta,
          propuestas: propuestas,
        ),
      );
    }
  }
  return avisos;
}

/// Resultado de mover una sesión perdida (PG-24).
class ResultadoMover {
  const ResultadoMover({required this.permitido, required this.avisos});

  /// `false` solo si el día destino ya tiene una sesión de fuerza.
  final bool permitido;
  final List<AvisoSemana> avisos;
}

/// Mueve la sesión [tipo] a [nuevoInicio] dentro de [plan]. Respeta las 48 h
/// **con aviso** (no bloquea) y no permite dos de fuerza en un día. Saltarse
/// una sesión no cambia nada: la progresión compara con la última vez que se
/// hizo, no con el calendario.
ResultadoMover moverSesion({
  required List<SesionProgramada> plan,
  required String tipo,
  required DateTime nuevoInicio,
  required Catalogo catalogo,
  ReglasGimnasio reglas = const ReglasGimnasio(),
}) {
  final resto = [
    for (final s in plan)
      if (s.tipo != tipo) s,
  ];
  final nueva = SesionProgramada(tipo, nuevoInicio);
  final avisos = revisarSemana([...resto, nueva], catalogo, reglas: reglas);
  final mismoDia = avisos.any(
    (a) => a.tipo == TipoAvisoSemana.mismoDia && (a.a == nueva || a.b == nueva),
  );
  return ResultadoMover(
    permitido: !mismoDia,
    avisos: [
      for (final a in avisos)
        if (a.a == nueva || a.b == nueva) a,
    ],
  );
}
