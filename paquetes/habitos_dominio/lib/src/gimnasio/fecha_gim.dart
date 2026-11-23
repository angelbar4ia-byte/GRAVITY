/// Auxiliares de fecha del gimnasio sobre `fecha.dart` (sin reloj propio).
library;

import '../fecha.dart';

/// Días entre dos fechas (b − a).
int diasEntreGim(DateTime a, DateTime b) => diasEntre(a, b);

/// Minutos entre dos instantes (b − a), redondeados hacia abajo.
int minutosEntre(DateTime a, DateTime b) => b.difference(a).inMinutes;

/// Número de semanas completas entre dos lunes.
int semanasEntre(DateTime lunesA, DateTime lunesB) =>
    diasEntre(lunesDe(lunesA), lunesDe(lunesB)) ~/ 7;
