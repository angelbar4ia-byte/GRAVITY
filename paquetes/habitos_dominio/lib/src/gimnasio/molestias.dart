/// Molestias físicas (4.3 y 5.10): **solo en el dispositivo**.
///
/// Este archivo no serializa nada a un formato de nube: [Molestia] solo se
/// convierte a un mapa **local** para el almacén cifrado del equipo
/// (`salud_local`, PG-03). Los tipos que sí viajan al servidor
/// (`registro.dart`) no tienen campo de molestia. No diagnostica: solo ajusta
/// el ejercicio y recomienda consultar a un profesional.
library;

import 'fecha_gim.dart';
import 'tipos.dart';

/// Intensidad de una molestia (4.3): 1 leve, 2 moderada, 3 fuerte.
class IntensidadMolestia {
  static const leve = 1;
  static const moderada = 2;
  static const fuerte = 3;
}

class Molestia {
  const Molestia({
    required this.id,
    required this.zona,
    required this.intensidad,
    required this.desde,
    this.hasta,
    this.revisadaEn,
    this.nota,
  });

  final String id;

  /// De [Zonas].
  final String zona;
  final int intensidad;
  final DateTime desde;

  /// `null` = activa.
  final DateTime? hasta;

  /// Última vez que la persona respondió «Sigue» a «¿Sigue esta molestia?».
  final DateTime? revisadaEn;

  /// Hasta 200 caracteres, solo local.
  final String? nota;

  bool get activa => hasta == null;

  bool get valida =>
      Zonas.todas.contains(zona) && intensidad >= 1 && intensidad <= 3;

  /// ¿Toca preguntar «¿Sigue esta molestia?»? Cada 14 días sin cambios.
  bool debePreguntarSigue(DateTime hoy, {int cadaDias = 14}) {
    if (!activa) return false;
    final base = revisadaEn ?? desde;
    return diasEntreGim(base, hoy) >= cadaDias;
  }

  /// Respuesta «Sigue»: se anota la revisión de hoy.
  Molestia sigue(DateTime hoy) => Molestia(
        id: id,
        zona: zona,
        intensidad: intensidad,
        desde: desde,
        revisadaEn: hoy,
        nota: nota,
      );

  /// Respuesta «Ya no»: queda cerrada.
  Molestia yaNo(DateTime hoy) => Molestia(
        id: id,
        zona: zona,
        intensidad: intensidad,
        desde: desde,
        hasta: hoy,
        revisadaEn: revisadaEn,
        nota: nota,
      );

  /// Mapa **solo para el almacén local cifrado del equipo** (`salud_local`).
  /// Nunca se envía a la nube ni a una cola.
  Map<String, Object?> aMapaLocal() => {
        'zona': zona,
        'intensidad': intensidad,
        'desde': desde.millisecondsSinceEpoch,
        'hasta': hasta?.millisecondsSinceEpoch,
        'revisada_en': revisadaEn?.millisecondsSinceEpoch,
        'nota': nota,
      };

  static Molestia deMapaLocal(String id, Map<String, Object?> m) {
    DateTime? f(Object? v) =>
        v == null ? null : DateTime.fromMillisecondsSinceEpoch(v as int, isUtc: true);
    return Molestia(
      id: id,
      zona: m['zona']! as String,
      intensidad: m['intensidad']! as int,
      desde: f(m['desde'])!,
      hasta: f(m['hasta']),
      revisadaEn: f(m['revisada_en']),
      nota: m['nota'] as String?,
    );
  }
}

/// Intensidad más alta, entre las molestias **activas**, que afecta alguna de
/// las [zonas]; 0 si ninguna.
int intensidadQueAfecta(List<Molestia> molestias, List<String> zonas) {
  var m = 0;
  for (final x in molestias) {
    if (x.activa && x.valida && zonas.contains(x.zona) && x.intensidad > m) {
      m = x.intensidad;
    }
  }
  return m;
}

/// Qué hacer con una variante frente a las molestias (5.10).
enum PrecaucionVariante {
  /// Sin molestia en sus zonas.
  ninguna,

  /// Leve: se marca «con precaución» y se ofrece una alternativa.
  conPrecaucion,

  /// Moderada o fuerte: no se ocupa automáticamente.
  noSeOcupa,
}

PrecaucionVariante precaucionDe(int intensidad) => switch (intensidad) {
      0 => PrecaucionVariante.ninguna,
      1 => PrecaucionVariante.conPrecaucion,
      _ => PrecaucionVariante.noSeOcupa,
    };
