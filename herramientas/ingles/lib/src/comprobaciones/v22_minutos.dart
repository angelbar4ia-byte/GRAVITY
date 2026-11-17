import '../contexto.dart';
import '../estimacion.dart';
import '../hallazgo.dart';
import '../modelo/archivo.dart';
import 'comun.dart';

/// V22 · Minutos estimados por bloque entre el 70 % y el 150 % del declarado, y
/// total entre 54 y 66 (formato, secciones 7 y 7.1). Es error. Los porcentajes y
/// los límites del total salen del contrato (`tolerancias_de_minutos`), y las
/// fórmulas, de su `estimacion_de_minutos` (ver `estimacion.dart`).
///
/// Cuando el contrato marca pendiente algo de lo que la estimación necesita (el
/// lugar del audio y del texto de la lección de martes y jueves, los elementos
/// del miércoles, el tiempo de un tipo de pregunta que no trae), la estimación
/// es incompleta y lo que se sale de la banda es un **aviso**: un dato
/// pendiente no decide nada.
List<Hallazgo> v22(Archivo a, Contexto c) {
  if (a is! Sesion) return const [];
  final k = c.contratoSesion;
  final minPct = k?.porcentajeMinimoPorBloque;
  final maxPct = k?.porcentajeMaximoPorBloque;
  final totMin = k?.totalMinimo;
  final totMax = k?.totalMaximo;
  if (k == null ||
      !k.declaraLaSesion ||
      minPct == null ||
      maxPct == null ||
      totMin == null ||
      totMax == null) {
    return const [];
  }
  final est = estimarSesion(a, c);
  if (est == null) return const [];
  final h = <Hallazgo>[];

  for (final b in est.bloques) {
    final declarados = b.declarados;
    if (declarados <= 0) continue;
    final pct = b.minutos / declarados * 100;
    if (pct >= minPct - 1e-9 && pct <= maxPct + 1e-9) continue;
    final mensaje =
        'el bloque ${b.bloque.tipo} declara ${_n(declarados)} minutos y estima ${_n1(b.minutos)} (${pct.round()} %); el contrato pide entre $minPct % y $maxPct %';
    h.add(
      b.esCompleta
          ? error(a, 'V22', mensaje)
          : aviso(
              a,
              'V22',
              '$mensaje. Estimación incompleta: ${b.incompleta.join('; ')}',
            ),
    );
  }

  final total = est.total;
  if (total < totMin - 1e-9 || total > totMax + 1e-9) {
    final mensaje =
        'la sesión estima ${_n1(total)} minutos en total y el contrato pide entre $totMin y $totMax';
    final falta = est.incompleta;
    h.add(
      falta.isEmpty
          ? error(a, 'V22', mensaje)
          : aviso(
              a,
              'V22',
              '$mensaje. Estimación incompleta: ${falta.toSet().join('; ')}',
            ),
    );
  }
  return h;
}

String _n(num n) => n == n.roundToDouble() ? '${n.round()}' : _n1(n);

/// Un decimal: `12.3`, `6.7`.
String _n1(num n) => n.toStringAsFixed(1);
