/// Ventana de entrenamiento: periodo de prueba y aviso de cercanía a la hora
/// de dormir (5.13, PG-15 y PG-16). **Sugiere; la persona decide**: nada de
/// esto cambia la ventana sola.
library;

import 'reglas.dart';

/// Ventana de una sesión según su hora real de inicio (en minutos desde la
/// medianoche).
VentanaEntrenamiento ventanaDeInicio(
  int inicioMin, {
  ReglasGimnasio reglas = const ReglasGimnasio(),
}) => inicioMin < reglas.ventanaMananaHastaMin
    ? VentanaEntrenamiento.manana
    : VentanaEntrenamiento.noche;

/// Lo que se midió en una ventana durante el periodo de prueba.
class ResumenVentana {
  const ResumenVentana({
    required this.planeadas,
    required this.cumplidas,
    this.energias = const [],
  });

  final int planeadas;
  final int cumplidas;

  /// Energía percibida (1 a 5) de cada sesión que la registró.
  final List<int> energias;

  /// Energía media en centésimas enteras (3.6 → 360); `null` sin datos.
  int? get energiaCentesimas => energias.isEmpty
      ? null
      : (energias.fold(0, (a, b) => a + b) * 100 * 2 + energias.length) ~/
            (energias.length * 2);
}

enum ResultadoVentana {
  faltanDatos,
  sugiereManana,
  sugiereNoche,
  sinDiferenciaClara,
}

/// Por qué se sugirió una ventana.
enum CriterioVentana { cumplimiento, energia, ninguno }

class SugerenciaVentana {
  const SugerenciaVentana(
    this.resultado,
    this.criterio, {
    this.diferenciaPuntos,
    this.diferenciaEnergiaCentesimas,
  });
  final ResultadoVentana resultado;
  final CriterioVentana criterio;

  /// Diferencia de cumplimiento en puntos porcentuales (redondeada).
  final int? diferenciaPuntos;
  final int? diferenciaEnergiaCentesimas;
}

/// Regla de la sugerencia (PG-16):
/// 1. Hacen falta al menos 4 sesiones planeadas en **cada** ventana.
/// 2. Diferencia de cumplimiento de 15 puntos o más: la de mayor cumplimiento.
/// 3. Si no, diferencia de energía media de 0.5 o más: la de mayor energía.
/// 4. Si no, no hay diferencia clara.
/// Todo se compara con enteros.
SugerenciaVentana compararVentanas(
  ResumenVentana manana,
  ResumenVentana noche, {
  ReglasGimnasio reglas = const ReglasGimnasio(),
}) {
  if (manana.planeadas < reglas.ventanaMinimoPlaneadas ||
      noche.planeadas < reglas.ventanaMinimoPlaneadas) {
    return const SugerenciaVentana(
      ResultadoVentana.faltanDatos,
      CriterioVentana.ninguno,
    );
  }
  // cumplimiento = cumplidas / planeadas; diferencia × 100 en enteros.
  final difNum =
      noche.cumplidas * manana.planeadas -
      manana.cumplidas * noche.planeadas; // (n/pn − m/pm) × pn × pm
  final den = manana.planeadas * noche.planeadas;
  final puntos = (difNum.abs() * 100 * 2 + den) ~/ (den * 2);
  if (difNum.abs() * 100 >= reglas.ventanaDifCumplimientoPct * den) {
    return SugerenciaVentana(
      difNum > 0
          ? ResultadoVentana.sugiereNoche
          : ResultadoVentana.sugiereManana,
      CriterioVentana.cumplimiento,
      diferenciaPuntos: puntos,
    );
  }
  final em = manana.energiaCentesimas;
  final en = noche.energiaCentesimas;
  if (em != null && en != null) {
    final d = en - em;
    if (d.abs() >= reglas.ventanaDifEnergiaCentesimas) {
      return SugerenciaVentana(
        d > 0 ? ResultadoVentana.sugiereNoche : ResultadoVentana.sugiereManana,
        CriterioVentana.energia,
        diferenciaPuntos: puntos,
        diferenciaEnergiaCentesimas: d.abs(),
      );
    }
  }
  return SugerenciaVentana(
    ResultadoVentana.sinDiferenciaClara,
    CriterioVentana.ninguno,
    diferenciaPuntos: puntos,
  );
}

/// Opciones ante una sesión que termina cerca de dormir, en orden (5.13).
enum OpcionDormir {
  versionMasCorta,
  regenerativa,
  empezarAntes,
  moverALaManana,
}

class AvisoDormir {
  const AvisoDormir({
    required this.minutosAntesDeDormir,
    required this.opciones,
  });

  /// Minutos que quedan entre el fin de la sesión y la hora de dormir.
  final int minutosAntesDeDormir;
  final List<OpcionDormir> opciones;
}

/// Aviso de cercanía a la hora de dormir (PG-15): con ventana de noche, si el
/// fin estimado queda a menos de [margenMin] minutos de dormir (90 por
/// omisión). `null` si no hay aviso. [esCorta] quita la opción de «versión más
/// corta».
AvisoDormir? avisoDormir({
  required int finMin,
  required int dormirMin,
  int margenMin = 90,
  VentanaEntrenamiento ventana = VentanaEntrenamiento.noche,
  bool esCorta = false,
}) {
  if (ventana == VentanaEntrenamiento.manana) return null;
  final quedan = dormirMin - finMin;
  if (quedan >= margenMin) return null;
  return AvisoDormir(
    minutosAntesDeDormir: quedan,
    opciones: [
      if (!esCorta) OpcionDormir.versionMasCorta,
      OpcionDormir.regenerativa,
      OpcionDormir.empezarAntes,
      OpcionDormir.moverALaManana,
    ],
  );
}

/// Fin estimado (min desde la medianoche) de una sesión que empieza en
/// [inicioMin] y dura [duracionSeg]; redondeado hacia arriba al minuto.
int finEstimadoMin(int inicioMin, int duracionSeg) =>
    inicioMin + (duracionSeg + 59) ~/ 60;
