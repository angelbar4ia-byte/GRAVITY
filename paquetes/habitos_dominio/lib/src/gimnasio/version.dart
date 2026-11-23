/// Elegir la versión según el hueco libre (5.5, CA-G-11).
library;

import '../rachas.dart' show Pausa;
import 'generador.dart';
import 'inventario.dart';
import 'molestias.dart';
import 'registro.dart';
import 'reglas.dart';
import 'tipos.dart';

/// Qué se propone cuando ninguna versión cabe (no hay una cuarta versión).
enum AccionSinHueco { moverBloque, regenerativa }

class EleccionVersion {
  const EleccionVersion({
    required this.version,
    required this.duracionSeg,
    required this.duraciones,
    required this.acciones,
  });

  /// `null` = ninguna cabe.
  final VersionSesion? version;

  /// Duración estimada de la versión elegida (o de la corta si ninguna cabe).
  final int duracionSeg;

  /// Duración estimada de cada versión.
  final Map<VersionSesion, int> duraciones;

  /// Solo si [version] es `null`: «mover el bloque» o «la regenerativa».
  final List<AccionSinHueco> acciones;

  bool get cabe => version != null;
}

/// Con `versionPreferida = auto`, la más larga cuya duración estimada **más
/// el margen** (10 min) cabe en el hueco; con una preferida, esa si cabe.
EleccionVersion elegirVersion({
  required Catalogo catalogo,
  required String plantillaId,
  required Inventario inventario,
  required DateTime hoy,
  required int huecoMin,
  List<Molestia> molestias = const [],
  List<SesionRegistrada> historial = const [],
  bool modoFoco = false,
  PerfilGimnasio perfil = const PerfilGimnasio(),
  ReglasGimnasio reglas = const ReglasGimnasio(),
  List<Pausa> pausas = const [],
  List<DateTime> lunesEnFoco = const [],
  Set<String> ultimaPlaca = const {},
}) {
  final duraciones = <VersionSesion, int>{};
  for (final v in VersionSesion.values) {
    duraciones[v] = generarSesion(
      catalogo: catalogo,
      plantillaId: plantillaId,
      version: v,
      inventario: inventario,
      hoy: hoy,
      molestias: molestias,
      historial: historial,
      modoFoco: modoFoco,
      perfil: perfil,
      reglas: reglas,
      pausas: pausas,
      lunesEnFoco: lunesEnFoco,
      ultimaPlaca: ultimaPlaca,
    ).duracionEstimadaSeg;
  }
  bool cabe(VersionSesion v) =>
      duraciones[v]! + reglas.margenHuecoMin * 60 <= huecoMin * 60;

  final candidatas = perfil.versionPreferida != null
      ? [perfil.versionPreferida!]
      : [VersionSesion.larga, VersionSesion.estandar, VersionSesion.corta];
  for (final v in candidatas) {
    if (cabe(v)) {
      return EleccionVersion(
        version: v,
        duracionSeg: duraciones[v]!,
        duraciones: duraciones,
        acciones: const [],
      );
    }
  }
  return EleccionVersion(
    version: null,
    duracionSeg: duraciones[candidatas.last]!,
    duraciones: duraciones,
    acciones: const [AccionSinHueco.moverBloque, AccionSinHueco.regenerativa],
  );
}
