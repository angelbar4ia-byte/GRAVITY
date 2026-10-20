/// Capa 2 del sistema de estilos: el estilo global que elige el usuario
/// en Ajustes › Apariencia (sección 4). Cada estilo tiene versión de día y de noche.
library;

import 'package:flutter/material.dart';

import 'valores_diseno.dart';

@immutable
class Estilo {
  const Estilo({
    required this.id,
    required this.nombre,
    required this.dia,
    required this.noche,
    this.descripcion = '',
  });

  /// Identificador estable para guardar la preferencia (p. ej. `futurista`).
  final String id;

  /// Nombre visible en Ajustes.
  final String nombre;

  /// Descripción corta para la vista previa.
  final String descripcion;

  /// Versión de día (claro).
  final ValoresDiseno dia;

  /// Versión de noche (oscuro).
  final ValoresDiseno noche;

  /// Los valores de la versión que corresponde al brillo.
  ValoresDiseno valores(Brightness brillo) =>
      brillo == Brightness.dark ? noche : dia;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Estilo &&
          other.id == id &&
          other.nombre == nombre &&
          other.dia == dia &&
          other.noche == noche;

  @override
  int get hashCode => Object.hash(id, nombre, dia, noche);

  @override
  String toString() => 'Estilo($id)';
}
