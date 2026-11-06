enum NivelCarga { ligero, equilibrado, saturado }

/// Minutos libres = (dormir − despertar) − bloques fijos (regla 25).
int minutosLibres({
  required int despertarMin,
  required int dormirMin,
  required int fijosMin,
}) =>
    (dormirMin - despertarMin) - fijosMin;

/// Mide la carga con enteros. Umbrales en puntos base (5000 = 50 %).
NivelCarga medirCarga({
  required int libres,
  required int programados,
  int ligeroPb = 5000,
  int saturadoPb = 8500,
}) {
  if (libres <= 0) return NivelCarga.saturado;
  if (programados * 10000 < libres * ligeroPb) return NivelCarga.ligero;
  if (programados * 10000 <= libres * saturadoPb) return NivelCarga.equilibrado;
  return NivelCarga.saturado;
}

class BloqueCarga {
  const BloqueCarga(this.id, this.minutos, {this.minimo = false});
  final String id;
  final int minutos;
  final bool minimo;
}

/// Propuesta para una carga saturada: primero los no mínimos más largos.
List<String> proponerRecortes(List<BloqueCarga> bloques) {
  final l = bloques.where((b) => !b.minimo).toList()
    ..sort((a, b) => b.minutos != a.minutos
        ? b.minutos.compareTo(a.minutos)
        : a.id.compareTo(b.id));
  return [for (final b in l) b.id];
}
