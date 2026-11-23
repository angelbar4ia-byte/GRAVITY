/// Sesiones regenerativas R1 y R2 (3.5): recuperar, no rendir. **Sin series,
/// cargas ni récords:** solo minutos y bloques.
library;

import 'inventario.dart';
import 'tipos.dart';

/// «¿Cómo amaneciste?» (un toque).
enum EstadoAnimo { descansado, normal, cansado }

class BloquePlanificadoRegen {
  const BloquePlanificadoRegen(this.bloqueId, this.minutos);
  final String bloqueId;
  final int minutos;
}

class SesionRegenerativa {
  const SesionRegenerativa({
    required this.plantillaId,
    required this.bloques,
    required this.contenidoEnRevision,
  });

  final String plantillaId;
  final List<BloquePlanificadoRegen> bloques;
  final bool contenidoEnRevision;

  int get minutos => bloques.fold(0, (s, b) => s + b.minutos);
}

/// Qué regenerativa proponer: con **Cansado**, R1 (la más corta); si no, la
/// del día del plan (R1 por omisión).
String proponerRegenerativa(EstadoAnimo animo, {String? plantillaDelDia}) =>
    animo == EstadoAnimo.cansado ? 'R1' : (plantillaDelDia ?? 'R1');

/// Arma la regenerativa: sin caminadora, la caminata se cambia por marcha
/// suave de la misma duración.
SesionRegenerativa generarRegenerativa({
  required Catalogo catalogo,
  required String plantillaId,
  required Inventario inventario,
}) {
  final p = catalogo.regenerativa(plantillaId);
  if (p == null) {
    throw ArgumentError.value(
      plantillaId,
      'plantillaId',
      'regenerativa inexistente',
    );
  }
  final caminadora = inventario.disponible('caminadora', catalogo);
  var borrador = p.revision != RevisionContenido.revisado;
  final bloques = <BloquePlanificadoRegen>[];
  for (final b in p.bloques) {
    final g = catalogo.bloque(b.bloqueId);
    if (g == null || g.revision != RevisionContenido.revisado) borrador = true;
    final id = g != null && g.requiereCaminadora && !caminadora
        ? (g.sustitutoSinCaminadora ?? b.bloqueId)
        : b.bloqueId;
    bloques.add(BloquePlanificadoRegen(id, b.minutos));
  }
  return SesionRegenerativa(
    plantillaId: plantillaId,
    bloques: bloques,
    contenidoEnRevision: borrador,
  );
}
