/// Capa 3 del sistema de estilos: la personalidad del módulo (DISENO_UX_UI,
/// sección 5). Solo sustituye algunos valores del estilo (acento, densidad,
/// ritmo de animación, escala de lectura) y aplica las excepciones por función:
/// Cuidados y la bici siempre van en alto contraste.
library;

import 'package:flutter/material.dart';

import '../nucleo/contratos/roles.dart';
import 'contraste.dart';
import 'valores_diseno.dart';

/// Submódulos con personalidad propia. Cada uno pertenece a un [Modulo].
enum Submodulo {
  espiritual(Modulo.habitos),
  entrenamiento(Modulo.habitos),
  bici(Modulo.habitos),
  ingles(Modulo.habitos),
  habitosEliminar(Modulo.habitos),
  desarrollador(Modulo.ajustes);

  const Submodulo(this.modulo);

  /// Módulo al que pertenece.
  final Modulo modulo;
}

/// Opción de Ajustes › Apariencia para cada módulo (sección 5).
///
/// "Elegir otro estilo" llega con los demás estilos en la Fase 4.
enum OpcionPersonalidad {
  /// La de la tabla de la sección 5.
  automatica,

  /// Igual al estilo global; conserva las excepciones por función.
  igualAlEstilo,
}

@immutable
class PersonalidadModulo {
  const PersonalidadModulo({
    required this.id,
    required this.nombre,
    this.acentoDia,
    this.acentoNoche,
    this.densidad,
    this.duracionAnimacion,
    this.escalaLectura,
    this.altoContraste = false,
    this.siempreClaro = false,
    this.sinDecoracion = false,
  });

  final String id;
  final String nombre;

  /// Acento en la versión de día; `null` conserva el del estilo.
  final Color? acentoDia;

  /// Acento en la versión de noche; `null` conserva el del estilo.
  final Color? acentoNoche;

  /// Densidad propia; `null` conserva la del dispositivo.
  final Densidad? densidad;

  /// Ritmo de animación; `Duration.zero` es sin animación; `null` conserva el del estilo.
  final Duration? duracionAnimacion;

  /// Escala de la letra de lectura; `null` conserva la del estilo.
  final double? escalaLectura;

  /// Excepción por función: siempre en alto contraste (Cuidados, bici).
  final bool altoContraste;

  /// Excepción por función: siempre en la versión clara (Cuidados).
  final bool siempreClaro;

  /// Excepción por función: sin decoración (Cuidados).
  final bool sinDecoracion;

  /// Si tiene alguna excepción por función que ningún ajuste puede quitar.
  bool get tieneExcepciones => altoContraste || siempreClaro || sinDecoracion;

  // --- Tabla de la sección 5 -------------------------------------------------

  /// GRAVITY (pantalla principal): el estilo elegido completo.
  static const asistente = PersonalidadModulo(id: 'asistente', nombre: 'Asistente');

  /// Sin cambios: igual al estilo global (Ajustes y Hábitos en general).
  static const igualAlEstilo = PersonalidadModulo(
    id: 'estilo',
    nombre: 'Igual al estilo global',
  );

  /// Finanzas: acento índigo, poca animación.
  static const precisa = PersonalidadModulo(
    id: 'precisa',
    nombre: 'Precisa y serena',
    acentoDia: Color(0xFF3949AB),
    acentoNoche: Color(0xFF8C9EFF),
    duracionAnimacion: Duration(milliseconds: 120),
  );

  /// Hábitos · Espiritual: acento violeta, lectura más grande, sin animación.
  static const contemplativa = PersonalidadModulo(
    id: 'contemplativa',
    nombre: 'Contemplativa',
    acentoDia: Color(0xFF6A3FB5),
    acentoNoche: Color(0xFFC3A6FF),
    duracionAnimacion: Duration.zero,
    escalaLectura: 1.15,
  );

  /// Hábitos · Entrenamiento y bici: neón, alto contraste, números enormes.
  static const sport = PersonalidadModulo(
    id: 'sport',
    nombre: 'Sport',
    acentoDia: Color(0xFF3D6B00),
    acentoNoche: Color(0xFFC6FF00),
    densidad: Densidad.grande,
    duracionAnimacion: Duration(milliseconds: 150),
    altoContraste: true,
  );

  /// Hábitos · Inglés: acento naranja.
  static const ludica = PersonalidadModulo(
    id: 'ludica',
    nombre: 'Lúdica',
    acentoDia: Color(0xFF9E4F00),
    acentoNoche: Color(0xFFFFAB40),
    duracionAnimacion: Duration(milliseconds: 300),
  );

  /// Hábitos a eliminar: terracota (nunca rojo de alarma).
  static const empatica = PersonalidadModulo(
    id: 'empatica',
    nombre: 'Empática',
    acentoDia: Color(0xFFA4472B),
    acentoNoche: Color(0xFFE08A6D),
    duracionAnimacion: Duration(milliseconds: 250),
  );

  /// Cuidados: rosa oscuro, letra y botones grandes, siempre claro y en alto
  /// contraste, sin decoración.
  static const claraCalida = PersonalidadModulo(
    id: 'clara_calida',
    nombre: 'Clara y cálida',
    acentoDia: Color(0xFFAD1457),
    acentoNoche: Color(0xFFF48FB1),
    densidad: Densidad.grande,
    duracionAnimacion: Duration(milliseconds: 150),
    escalaLectura: 1.2,
    altoContraste: true,
    siempreClaro: true,
    sinDecoracion: true,
  );

  /// Alimentación y Casa: ámbar, letra grande (se usa cocinando).
  static const calidaPractica = PersonalidadModulo(
    id: 'calida_practica',
    nombre: 'Cálida y práctica',
    acentoDia: Color(0xFF8A5A00),
    acentoNoche: Color(0xFFFFC046),
    densidad: Densidad.grande,
    duracionAnimacion: Duration(milliseconds: 200),
    escalaLectura: 1.15,
  );

  /// Ajustes › Desarrollador: colores del estilo activo, compacta.
  static const tecnica = PersonalidadModulo(
    id: 'tecnica',
    nombre: 'Técnica',
    densidad: Densidad.compacta,
    duracionAnimacion: Duration(milliseconds: 120),
  );

  /// Todas las personalidades de la tabla.
  static const todas = [
    asistente,
    igualAlEstilo,
    precisa,
    contemplativa,
    sport,
    ludica,
    empatica,
    claraCalida,
    calidaPractica,
    tecnica,
  ];

  /// La personalidad automática de un módulo o submódulo (tabla de la sección 5).
  static PersonalidadModulo automatica(Modulo modulo, [Submodulo? submodulo]) {
    if (submodulo != null) {
      return switch (submodulo) {
        Submodulo.espiritual => contemplativa,
        Submodulo.entrenamiento || Submodulo.bici => sport,
        Submodulo.ingles => ludica,
        Submodulo.habitosEliminar => empatica,
        Submodulo.desarrollador => tecnica,
      };
    }
    return switch (modulo) {
      Modulo.gravity => asistente,
      Modulo.finanzas => precisa,
      Modulo.habitos => igualAlEstilo,
      Modulo.cuidados => claraCalida,
      Modulo.alimentacion || Modulo.casa => calidaPractica,
      Modulo.ajustes => igualAlEstilo,
    };
  }

  /// La personalidad según la opción elegida en Ajustes.
  static PersonalidadModulo resolver(
    Modulo modulo, {
    Submodulo? submodulo,
    OpcionPersonalidad opcion = OpcionPersonalidad.automatica,
  }) {
    final auto = automatica(modulo, submodulo);
    return switch (opcion) {
      OpcionPersonalidad.automatica => auto,
      OpcionPersonalidad.igualAlEstilo => auto.soloExcepciones(),
    };
  }

  /// Quita el acento y el ritmo propios, pero conserva las excepciones por
  /// función (alto contraste, siempre claro, letra y botones grandes).
  PersonalidadModulo soloExcepciones() {
    if (!tieneExcepciones) return igualAlEstilo;
    return PersonalidadModulo(
      id: '$id+estilo',
      nombre: nombre,
      densidad: densidad,
      escalaLectura: escalaLectura,
      altoContraste: altoContraste,
      siempreClaro: siempreClaro,
      sinDecoracion: sinDecoracion,
    );
  }

  /// Brillo que se usa en este módulo, dado el brillo global (capa 4).
  Brightness brilloEfectivo(Brightness global) =>
      siempreClaro ? Brightness.light : global;

  /// Aplica la personalidad sobre los valores del estilo.
  ValoresDiseno aplicar(ValoresDiseno base) {
    var v = altoContraste ? valoresAltoContraste(base) : base;
    final acento = v.brillo == Brightness.dark ? acentoNoche : acentoDia;
    if (acento != null) {
      v = v.copyWith(
        acento: acento,
        sobreAcento: masLegibleSobre(acento, [v.fondo, v.textoFuerte]),
      );
    }
    return v.copyWith(
      densidad: densidad,
      duracionAnimacion: duracionAnimacion,
      escalaLectura: escalaLectura,
      decoracion: sinDecoracion ? false : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PersonalidadModulo &&
          other.id == id &&
          other.acentoDia == acentoDia &&
          other.acentoNoche == acentoNoche &&
          other.densidad == densidad &&
          other.duracionAnimacion == duracionAnimacion &&
          other.escalaLectura == escalaLectura &&
          other.altoContraste == altoContraste &&
          other.siempreClaro == siempreClaro &&
          other.sinDecoracion == sinDecoracion;

  @override
  int get hashCode => Object.hash(
    id,
    acentoDia,
    acentoNoche,
    densidad,
    duracionAnimacion,
    escalaLectura,
    altoContraste,
    siempreClaro,
    sinDecoracion,
  );

  @override
  String toString() => 'PersonalidadModulo($id)';
}

/// Variante de alto contraste de cualquier estilo (sección 4, excepciones por
/// función, y sección 20: ningún estilo baja el contraste mínimo).
///
/// Conserva el brillo, las tipografías y las formas del estilo; lleva los
/// colores al máximo contraste. Si el acento del estilo no llega a 7:1, se
/// cambia por el texto fuerte.
ValoresDiseno valoresAltoContraste(ValoresDiseno base) {
  final claro = base.brillo == Brightness.light;
  final v = claro
      ? base.copyWith(
          fondo: const Color(0xFFFFFFFF),
          panel: const Color(0xFFFFFFFF),
          borde: const Color(0xFF3B4A52),
          texto: const Color(0xFF000000),
          textoFuerte: const Color(0xFF000000),
          textoTenue: const Color(0xFF2E3A40),
          etiqueta: const Color(0xFF1F2A30),
          exito: const Color(0xFF0B5D36),
          alerta: const Color(0xFF6B4700),
          peligro: const Color(0xFF9B1C14),
          altoContraste: true,
        )
      : base.copyWith(
          fondo: const Color(0xFF000000),
          panel: const Color(0xFF0A0A0A),
          borde: const Color(0xFFBDBDBD),
          texto: const Color(0xFFFFFFFF),
          textoFuerte: const Color(0xFFFFFFFF),
          textoTenue: const Color(0xFFE0E0E0),
          etiqueta: const Color(0xFFEDEDED),
          exito: const Color(0xFF5CF2A8),
          alerta: const Color(0xFFFFD54F),
          peligro: const Color(0xFFFF8A80),
          altoContraste: true,
        );
  final acento = razonContraste(base.acento, v.fondo) >= 7
      ? base.acento
      : v.textoFuerte;
  return v.copyWith(
    acento: acento,
    sobreAcento: masLegibleSobre(acento, [v.fondo, v.textoFuerte]),
  );
}
