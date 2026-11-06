class ElementoHoy {
  const ElementoHoy(
    this.id, {
    this.horaMin,
    this.duracionMin = 0,
    this.prioridad = 0,
    this.hecho = false,
    this.omitido = false,
    this.esencial = false,
  });
  final String id;
  final int? horaMin; // minutos desde medianoche; nulo = sin hora
  final int duracionMin;
  final int prioridad;
  final bool hecho;
  final bool omitido;
  final bool esencial;
}

/// Orden de Hoy (regla 10): por hora, sin hora al final, empates por
/// prioridad (mayor primero) y luego id.
List<ElementoHoy> ordenarHoy(List<ElementoHoy> l) {
  final c = [...l];
  c.sort((a, b) {
    final ha = a.horaMin ?? 1 << 30;
    final hb = b.horaMin ?? 1 << 30;
    if (ha != hb) return ha.compareTo(hb);
    if (a.prioridad != b.prioridad) return b.prioridad.compareTo(a.prioridad);
    return a.id.compareTo(b.id);
  });
  return c;
}

class Siguiente {
  const Siguiente(this.elemento, this.enCurso);
  final ElementoHoy elemento;
  final bool enCurso;
}

/// Tarjeta *Sigue* (regla 11): el de en curso, o el más cercano pendiente.
Siguiente? calcularSigue(List<ElementoHoy> l, int ahoraMin) {
  final p = ordenarHoy(l).where((e) => !e.hecho && !e.omitido).toList();
  for (final e in p) {
    final h = e.horaMin;
    if (h != null && h <= ahoraMin && ahoraMin < h + e.duracionMin) {
      return Siguiente(e, true);
    }
  }
  for (final e in p) {
    final h = e.horaMin;
    if (h == null || h >= ahoraMin) return Siguiente(e, false);
  }
  return p.isEmpty ? null : Siguiente(p.first, false);
}

/// Modo foco (regla 26): solo lo esencial.
List<ElementoHoy> filtrarFoco(List<ElementoHoy> l) =>
    l.where((e) => e.esencial).toList();
