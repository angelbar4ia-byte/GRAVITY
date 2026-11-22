/// Asignación de voces del motor a las voces de un guion (spec, sección 3.2,
/// punto 6).
///
/// El contenido habla de voces de guion (F1, F2, M1, M2, N). Cada fuente ofrece
/// voces del motor. La asignación las une: la propone el motor y la persona la
/// cambia. Regla de oro: **una misma voz del motor nunca se asigna a dos voces
/// de guion** (criterio 4); si no alcanzan, el guion no se puede decir con esa
/// fuente (`vocesInsuficientes`) en vez de repetir voces sin avisar.
library;

import 'package:flutter/foundation.dart' show immutable;

import 'tipos.dart';

@immutable
final class Asignacion {
  const Asignacion(this.fuente, this.variante, this.idVozMotor);
  final Fuente fuente;
  final Variante variante;

  /// `VozDeGuion` -> `VozMotor.id`.
  final Map<VozDeGuion, String> idVozMotor;

  /// `true` si ninguna voz del motor está asignada a dos voces de guion.
  bool get sinRepetidas =>
      idVozMotor.values.toSet().length == idVozMotor.length;
}

abstract interface class Asignador {
  /// Propuesta automática: mujeres para F1 y F2, hombres para M1 y M2 y, para
  /// N, la primera voz que quede; sin repetir voces. Solo asigna las [roles]
  /// pedidos (por omisión, las cinco). Las voces vienen ya filtradas (locales
  /// y de la variante).
  Asignacion proponer(
    Fuente fuente,
    Variante variante,
    List<VozMotor> voces, {
    Set<VozDeGuion>? roles,
  });
}

/// Propuesta por género, en el orden en que llegan las voces (la fuente las
/// entrega de mejor a peor calidad).
///
/// - Una voz con género conocido solo se propone para ese género.
/// - Una voz sin dato de género puede ocupar cualquier lugar si no hay una
///   voz del género buscado (Android casi nunca dice el género).
/// - Lo que no se puede asignar sin repetir queda sin asignar.
final class AsignadorPorGenero implements Asignador {
  const AsignadorPorGenero();

  @override
  Asignacion proponer(
    Fuente fuente,
    Variante variante,
    List<VozMotor> voces, {
    Set<VozDeGuion>? roles,
  }) {
    final pedidos = roles ?? VozDeGuion.values.toSet();
    final usadas = <String>{};
    final asignadas = <VozDeGuion, String>{};
    VozMotor? primera(bool Function(VozMotor) sirve) {
      for (final v in voces) {
        if (!usadas.contains(v.id) && sirve(v)) return v;
      }
      return null;
    }

    // Primero las voces con género buscado (F1, F2, M1, M2), después N: así
    // una voz sin género no le quita su lugar a quien sí lo necesita.
    final orden = [
      for (final r in VozDeGuion.values)
        if (pedidos.contains(r) && r != VozDeGuion.n) r,
      if (pedidos.contains(VozDeGuion.n)) VozDeGuion.n,
    ];
    // Vuelta 1: voces del género exacto.
    for (final rol in orden) {
      final genero = rol.generoBuscado;
      if (genero == null) continue;
      final v = primera((v) => v.genero == genero);
      if (v != null) {
        asignadas[rol] = v.id;
        usadas.add(v.id);
      }
    }
    // Vuelta 2: lo que falta, con voces sin dato de género.
    for (final rol in orden) {
      if (asignadas.containsKey(rol)) continue;
      final genero = rol.generoBuscado;
      final v = genero == null
          ? primera((_) => true)
          : primera((v) => v.genero == Genero.sinDato);
      if (v != null) {
        asignadas[rol] = v.id;
        usadas.add(v.id);
      }
    }
    return Asignacion(fuente, variante, asignadas);
  }
}

/// Une lo que la persona eligió ([guardadas]) con la propuesta del [asignador]
/// para los [roles] que necesita un guion.
///
/// - Una elección guardada solo vale si esa voz sigue existiendo en [voces] y
///   no está ya tomada por otro rol (nunca se repite una voz).
/// - Lo que falta lo propone el asignador con las voces que quedan.
Asignacion resolverAsignacion({
  required Asignador asignador,
  required Fuente fuente,
  required Variante variante,
  required List<VozMotor> voces,
  required Set<VozDeGuion> roles,
  Map<VozDeGuion, String> guardadas = const {},
}) {
  final ids = {for (final v in voces) v.id};
  final fijas = <VozDeGuion, String>{};
  final tomadas = <String>{};
  for (final rol in VozDeGuion.values) {
    if (!roles.contains(rol)) continue;
    final id = guardadas[rol];
    if (id != null && ids.contains(id) && tomadas.add(id)) fijas[rol] = id;
  }
  final faltan = roles.difference(fijas.keys.toSet());
  if (faltan.isEmpty) return Asignacion(fuente, variante, fijas);
  final libres = [
    for (final v in voces)
      if (!tomadas.contains(v.id)) v,
  ];
  final propuesta = asignador.proponer(
    fuente,
    variante,
    libres,
    roles: faltan,
  );
  return Asignacion(fuente, variante, {
    ...fijas,
    ...propuesta.idVozMotor,
  });
}
