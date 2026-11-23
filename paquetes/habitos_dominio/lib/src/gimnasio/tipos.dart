/// Tipos del catálogo del gimnasio (sección 3 de la especificación).
library;

/// Zonas del cuerpo (3.7): lo que un ejercicio carga y lo que afecta una
/// molestia. Catálogo cerrado.
class Zonas {
  static const hombro = 'hombro';
  static const codo = 'codo';
  static const muneca = 'muneca';
  static const cuello = 'cuello';
  static const espaldaAlta = 'espalda_alta';
  static const espaldaBaja = 'espalda_baja';
  static const cadera = 'cadera';
  static const rodilla = 'rodilla';
  static const tobillo = 'tobillo';
  static const otra = 'otra';

  static const todas = [
    hombro,
    codo,
    muneca,
    cuello,
    espaldaAlta,
    espaldaBaja,
    cadera,
    rodilla,
    tobillo,
    otra,
  ];
}

/// Grupos musculares (3.7): para la regla de las 48 horas.
class Grupos {
  static const pecho = 'pecho';
  static const espalda = 'espalda';
  static const hombro = 'hombro';
  static const triceps = 'triceps';
  static const biceps = 'biceps';
  static const cuadriceps = 'cuadriceps';
  static const gluteo = 'gluteo';
  static const core = 'core';

  static const todos = [
    pecho,
    espalda,
    hombro,
    triceps,
    biceps,
    cuadriceps,
    gluteo,
    core,
  ];
}

/// Revisión del contenido (PG-25). Todo nace `borrador`.
enum RevisionContenido { borrador, revisado }

/// Estado de confirmación de un dato del equipo (3.1).
enum EstadoDato { delDiseno, confirmar, confirmado }

enum TipoItem { aparato, puesto, accesorio }

enum TipoCarga { pila, pesoCorporal, banda, ninguna }

/// Dónde se ancla una banda (3.3).
enum Ancla { pisar, puerta, estacion }

enum TipoProgresion { carga, repeticiones, tiempo }

/// Un aparato, puesto o accesorio del catálogo (3.2).
class ItemEquipo {
  const ItemEquipo({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.estado,
    this.padre,
    this.carga = TipoCarga.ninguna,
    this.soloDato = false,
  });

  final String id;
  final String nombre;
  final TipoItem tipo;
  final EstadoDato estado;

  /// Aparato al que pertenece un puesto.
  final String? padre;
  final TipoCarga carga;

  /// Equipo futuro: solo dato, ninguna variante puede exigirlo (D, PG).
  final bool soloDato;
}

/// Dato del aparato que la app no puede inventar (3.2).
class DatoAparato {
  const DatoAparato({
    required this.id,
    required this.nombre,
    required this.estado,
    this.valor,
    this.unidad,
  });

  final String id;
  final String nombre;
  final EstadoDato estado;

  /// Valor del diseño (solo orientación) o `null`.
  final int? valor;
  final String? unidad;
}

/// Una forma de hacer un ejercicio con un equipo requerido (3.3).
class Variante {
  const Variante({
    required this.id,
    required this.nombre,
    this.requiere = const [],
    this.ancla,
    this.nivel = 1,
    this.masDificil,
    this.carga = TipoCarga.ninguna,
    this.zonas,
    this.revision,
  });

  final String id;
  final String nombre;

  /// Ids de puesto, aparato o accesorio: **todos** necesarios.
  final List<String> requiere;

  /// Solo bandas.
  final Ancla? ancla;
  final int nivel;
  final String? masDificil;
  final TipoCarga carga;

  /// Zonas propias de la variante; `null` = las del ejercicio.
  final List<String>? zonas;

  /// `null` es un error de integridad (CA-G-05): el validador lo rechaza.
  final RevisionContenido? revision;

  bool get esDeBanda => requiere.contains('bandas');
}

/// Un movimiento del catálogo, con una o más variantes (3.3).
class Ejercicio {
  const Ejercicio({
    required this.id,
    required this.nombre,
    required this.patron,
    required this.gruposPrimarios,
    required this.zonas,
    required this.explicacion,
    required this.variantes,
    this.errores = const [],
    this.repsMin,
    this.repsMax,
    this.segundosMin,
    this.segundosMax,
    this.progresion = TipoProgresion.carga,
    this.porLado = false,
    this.retirado = false,
    this.revision,
  });

  final String id;
  final String nombre;
  final String patron;
  final List<String> gruposPrimarios;
  final List<String> zonas;

  /// Hasta 280 caracteres.
  final String explicacion;

  /// Hasta 3, de 120 caracteres cada uno.
  final List<String> errores;
  final List<Variante> variantes;
  final int? repsMin;
  final int? repsMax;
  final int? segundosMin;
  final int? segundosMax;
  final TipoProgresion progresion;

  /// Se hace por pierna o por lado (subidas, patadas).
  final bool porLado;
  final bool retirado;
  final RevisionContenido? revision;

  bool get esDeTiempo => segundosMin != null;
}

/// Un espacio de la plantilla con candidatas ordenadas (2 y 3.3).
class Slot {
  const Slot({
    required this.id,
    required this.nombre,
    required this.candidatas,
    this.series = 3,
    this.repsMin,
    this.repsMax,
    this.segundosMin,
    this.segundosMax,
    this.esencial = true,
    this.omitirEnCorta = false,
    this.extra = false,
  });

  final String id;
  final String nombre;

  /// Ids de variante, en orden de preferencia.
  final List<String> candidatas;
  final int series;
  final int? repsMin;
  final int? repsMax;
  final int? segundosMin;
  final int? segundosMax;
  final bool esencial;
  final bool omitirEnCorta;

  /// Solo entra en la versión larga.
  final bool extra;

  bool get esDeTiempo => segundosMin != null;
}

/// Plantilla de fuerza (A, B o C).
class PlantillaSesion {
  const PlantillaSesion({
    required this.id,
    required this.nombre,
    required this.slots,
    this.calentamiento = const [],
    this.cierre = const [],
    this.revision,
  });

  final String id;
  final String nombre;
  final List<Slot> slots;

  /// Ids de bloques guiados.
  final List<String> calentamiento;
  final List<String> cierre;
  final RevisionContenido? revision;
}

/// Bloque guiado: calentamiento, movilidad, cierre o parte de una
/// regenerativa (3.5 y 3.6).
class BloqueGuiado {
  const BloqueGuiado({
    required this.id,
    required this.nombre,
    required this.instruccion,
    this.requiereCaminadora = false,
    this.sustitutoSinCaminadora,
    this.revision,
  });

  final String id;
  final String nombre;
  final String instruccion;
  final bool requiereCaminadora;

  /// Id del bloque que lo reemplaza si no hay caminadora.
  final String? sustitutoSinCaminadora;
  final RevisionContenido? revision;
}

class BloqueRegenerativo {
  const BloqueRegenerativo(this.bloqueId, this.minutos);
  final String bloqueId;
  final int minutos;
}

/// Sesión regenerativa (R1 o R2): sin series, cargas ni récords (3.5).
class PlantillaRegenerativa {
  const PlantillaRegenerativa({
    required this.id,
    required this.nombre,
    required this.bloques,
    this.revision,
  });

  final String id;
  final String nombre;
  final List<BloqueRegenerativo> bloques;
  final RevisionContenido? revision;

  int get minutos => bloques.fold(0, (s, b) => s + b.minutos);
}

/// Catálogo completo, versionado (3 y PG-01).
class Catalogo {
  Catalogo({
    required this.version,
    required this.items,
    required this.datosAparato,
    required this.ejercicios,
    required this.plantillas,
    required this.regenerativas,
    required this.bloques,
  });

  final int version;
  final List<ItemEquipo> items;
  final List<DatoAparato> datosAparato;
  final List<Ejercicio> ejercicios;
  final List<PlantillaSesion> plantillas;
  final List<PlantillaRegenerativa> regenerativas;
  final List<BloqueGuiado> bloques;

  late final Map<String, ItemEquipo> _items = {for (final i in items) i.id: i};
  late final Map<String, Ejercicio> _ejercicios = {
    for (final e in ejercicios) e.id: e,
  };
  late final Map<String, Variante> _variantes = {
    for (final e in ejercicios)
      for (final v in e.variantes) v.id: v,
  };
  late final Map<String, Ejercicio> _ejercicioDeVariante = {
    for (final e in ejercicios)
      for (final v in e.variantes) v.id: e,
  };

  ItemEquipo? item(String id) => _items[id];
  Ejercicio? ejercicio(String id) => _ejercicios[id];
  Variante? variante(String id) => _variantes[id];
  Ejercicio? ejercicioDeVariante(String id) => _ejercicioDeVariante[id];

  PlantillaSesion? plantilla(String id) {
    for (final p in plantillas) {
      if (p.id == id) return p;
    }
    return null;
  }

  PlantillaRegenerativa? regenerativa(String id) {
    for (final r in regenerativas) {
      if (r.id == id) return r;
    }
    return null;
  }

  BloqueGuiado? bloque(String id) {
    for (final b in bloques) {
      if (b.id == id) return b;
    }
    return null;
  }

  DatoAparato? datoAparato(String id) {
    for (final d in datosAparato) {
      if (d.id == id) return d;
    }
    return null;
  }

  /// Zonas que carga una variante (las propias o las del ejercicio).
  List<String> zonasDe(String varianteId) {
    final v = variante(varianteId);
    final e = ejercicioDeVariante(varianteId);
    return v?.zonas ?? e?.zonas ?? const [];
  }

  /// Grupos de una plantilla: unión de los grupos primarios de los
  /// ejercicios de sus slots que no son extras (5.6).
  Set<String> gruposDePlantilla(String plantillaId) {
    final p = plantilla(plantillaId);
    if (p == null) return {};
    final r = <String>{};
    for (final s in p.slots) {
      if (s.extra) continue;
      final e = ejercicioDeVariante(s.candidatas.first);
      if (e != null) r.addAll(e.gruposPrimarios);
    }
    return r;
  }

  /// ¿Hay contenido `borrador` (o sin revisión)? La sesión dice «Contenido
  /// en revisión» (PG-25, CA-G-05).
  bool get hayBorrador => hayBorradorEn(plantillas.map((p) => p.id));

  /// Revisión de lo que usan las plantillas indicadas.
  bool hayBorradorEn(Iterable<String> plantillaIds) {
    bool malo(RevisionContenido? r) => r != RevisionContenido.revisado;
    for (final id in plantillaIds) {
      final p = plantilla(id);
      if (p != null) {
        if (malo(p.revision)) return true;
        for (final s in p.slots) {
          for (final c in s.candidatas) {
            final v = variante(c);
            final e = ejercicioDeVariante(c);
            if (v == null ||
                e == null ||
                malo(v.revision) ||
                malo(e.revision)) {
              return true;
            }
          }
        }
      }
      final r = regenerativa(id);
      if (r != null) {
        if (malo(r.revision)) return true;
        for (final b in r.bloques) {
          if (malo(bloque(b.bloqueId)?.revision)) return true;
        }
      }
    }
    return false;
  }
}
