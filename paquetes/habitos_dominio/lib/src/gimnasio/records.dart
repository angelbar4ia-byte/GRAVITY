/// Récords personales (6.2): todo **calculado** de las series; corregir o
/// deshacer una serie recalcula; un día más flojo no quita un récord. Se
/// calculan por **variante**: no se mezclan puestos (polea y cojín).
library;

import 'inventario.dart';
import 'registro.dart';
import 'tipos.dart';

class RecordsVariante {
  const RecordsVariante({
    this.mejorCargaPasos,
    this.mejoresReps,
    this.mejorSegundos,
    this.mejorBandaOrden,
  });

  /// La carga más alta con al menos el mínimo del rango de repeticiones.
  final int? mejorCargaPasos;

  /// Más repeticiones en una serie a una carga igual o mayor a la mejor.
  final int? mejoresReps;

  /// Plancha: más segundos en una serie.
  final int? mejorSegundos;

  /// La banda de mayor `orden` con el mínimo del rango.
  final int? mejorBandaOrden;

  bool get vacio =>
      mejorCargaPasos == null &&
      mejoresReps == null &&
      mejorSegundos == null &&
      mejorBandaOrden == null;

  @override
  bool operator ==(Object other) =>
      other is RecordsVariante &&
      other.mejorCargaPasos == mejorCargaPasos &&
      other.mejoresReps == mejoresReps &&
      other.mejorSegundos == mejorSegundos &&
      other.mejorBandaOrden == mejorBandaOrden;

  @override
  int get hashCode =>
      Object.hash(mejorCargaPasos, mejoresReps, mejorSegundos, mejorBandaOrden);
}

/// Mínimo del rango de repeticiones que cuenta para un récord: el que se
/// planeó en la sesión o, si no hay, el del ejercicio en el catálogo.
int _minimoDelRango(SesionRegistrada s, SerieRegistrada x, Catalogo c) {
  for (final p in s.plan) {
    if (p.varianteId == x.varianteId && p.repsMin != null) return p.repsMin!;
  }
  return c.ejercicio(x.ejercicioId)?.repsMin ?? 1;
}

/// Récords por variante. Las sesiones regenerativas no tienen series, así que
/// nunca producen récords. [bandas] da el `orden` de cada banda.
Map<String, RecordsVariante> calcularRecords(
  List<SesionRegistrada> sesiones,
  Catalogo catalogo, {
  List<BandaInventario> bandas = const [],
}) {
  final orden = {for (final b in bandas) b.id: b.orden};
  final cargas = <String, int>{};
  final reps = <String, List<(int? carga, int reps)>>{};
  final segundos = <String, int>{};
  final bandaMax = <String, int>{};

  for (final s in sesiones) {
    if (!s.esDeFuerza) continue;
    for (final x in s.series) {
      final v = x.varianteId;
      final r = x.reps;
      if (x.segundos != null) {
        if (x.segundos! > (segundos[v] ?? -1)) segundos[v] = x.segundos!;
      }
      if (r == null) continue;
      reps.putIfAbsent(v, () => []).add((x.cargaPasos, r));
      final minimo = _minimoDelRango(s, x, catalogo);
      if (r >= minimo) {
        if (x.cargaPasos != null && x.cargaPasos! > (cargas[v] ?? -1)) {
          cargas[v] = x.cargaPasos!;
        }
        final o = x.bandaId == null ? null : orden[x.bandaId];
        if (o != null && o > (bandaMax[v] ?? -1)) bandaMax[v] = o;
      }
    }
  }

  final ids = {
    ...cargas.keys,
    ...reps.keys,
    ...segundos.keys,
    ...bandaMax.keys,
  };
  return {
    for (final v in ids)
      v: RecordsVariante(
        mejorCargaPasos: cargas[v],
        mejoresReps: _mejoresReps(reps[v] ?? const [], cargas[v]),
        mejorSegundos: segundos[v],
        mejorBandaOrden: bandaMax[v],
      ),
  };
}

/// Más repeticiones a una carga igual o mayor a la mejor; sin cargas (peso
/// corporal o banda), las más repeticiones de cualquier serie.
int? _mejoresReps(List<(int?, int)> series, int? mejorCarga) {
  int? m;
  for (final (carga, r) in series) {
    if (mejorCarga != null && (carga == null || carga < mejorCarga)) continue;
    if (m == null || r > m) m = r;
  }
  return m;
}

/// Un récord nuevo, para el mensaje «Nuevo récord personal en …» (sin
/// signos de exclamación, sin comparar con nadie).
class RecordNuevo {
  const RecordNuevo(this.varianteId, this.tipo, this.valor);
  final String varianteId;

  /// `carga`, `repeticiones`, `tiempo` o `banda`.
  final String tipo;
  final int valor;
}

/// Récords que trae [nueva] frente al historial previo.
List<RecordNuevo> recordsNuevos(
  List<SesionRegistrada> antes,
  SesionRegistrada nueva,
  Catalogo catalogo, {
  List<BandaInventario> bandas = const [],
}) {
  final a = calcularRecords(antes, catalogo, bandas: bandas);
  final d = calcularRecords([...antes, nueva], catalogo, bandas: bandas);
  final r = <RecordNuevo>[];
  for (final e in d.entries) {
    final p = a[e.key];
    final n = e.value;
    if (n.mejorCargaPasos != null &&
        n.mejorCargaPasos! > (p?.mejorCargaPasos ?? -1)) {
      r.add(RecordNuevo(e.key, 'carga', n.mejorCargaPasos!));
    } else if (n.mejoresReps != null &&
        n.mejorCargaPasos == null &&
        n.mejoresReps! > (p?.mejoresReps ?? -1)) {
      r.add(RecordNuevo(e.key, 'repeticiones', n.mejoresReps!));
    }
    if (n.mejorSegundos != null &&
        n.mejorSegundos! > (p?.mejorSegundos ?? -1)) {
      r.add(RecordNuevo(e.key, 'tiempo', n.mejorSegundos!));
    }
    if (n.mejorBandaOrden != null &&
        n.mejorBandaOrden! > (p?.mejorBandaOrden ?? -1)) {
      r.add(RecordNuevo(e.key, 'banda', n.mejorBandaOrden!));
    }
  }
  return r;
}
