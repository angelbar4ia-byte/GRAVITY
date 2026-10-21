/// Espejo de la matriz de permisos (docs/specs/fase-0-cimientos.md, sección 5).
///
/// La verdad de los permisos está en el **servidor** (RLS, D5 y D7). Este
/// espejo solo sirve para ocultar en la interfaz lo que no le corresponde a
/// cada rol: nada de pantallas vacías ni botones bloqueados.
library;

import '../contratos/dispositivo.dart';
import '../contratos/roles.dart';

/// Qué tanto puede un rol dentro de un módulo.
enum Alcance {
  /// Sin acceso (— en la matriz).
  ninguno,

  /// Leer, escribir y administrar.
  total,

  /// Solo leer.
  lectura,

  /// Leer y escribir solo lo propio.
  propio,

  /// Leer y escribir según el consentimiento de quien representa a la
  /// persona (D2). Sin consentimiento registrado no hay acceso (Fase 5).
  consentimiento,

  /// Leer y escribir lo de su turno.
  turno,

  /// Solo recordatorios genéricos, sin nombres ni medicamentos (D3).
  generico,

  /// Leer una parte acotada (su parte, las comidas de papá, el menú y la lista).
  parcial,

  /// Solo escribir lo que la persona registra (gastos de cuidado), sin leer
  /// el módulo (D5: la cuidadora nunca lee Finanzas).
  registroPropio,

  /// Solo su bandeja de solicitudes y recordatorios de GRAVITY: los lee y los
  /// confirma (hecho o no se pudo, con nota). No conversa con GRAVITY ni ve
  /// nada de la familia (D18, cuidadora).
  solicitudes,
}

/// Una celda de la matriz: alcance, texto para mostrar y si el módulo aparece
/// en la navegación del rol.
class Permiso {
  const Permiso(
    this.alcance,
    this.descripcion, {
    this.accesoDirecto = true,
    this.desdeFase,
    this._acciones,
  });

  const Permiso.ninguno()
    : alcance = Alcance.ninguno,
      descripcion = 'Sin acceso',
      accesoDirecto = false,
      desdeFase = null,
      _acciones = null;

  final Alcance alcance;

  /// Texto en español para Ajustes › Personas y roles.
  final String descripcion;

  /// `true` si el rol abre las pantallas del módulo desde la navegación.
  /// `false` si lo usa solo desde otro módulo (p. ej. la cuidadora registra
  /// gastos de cuidado desde Cuidados, no desde Finanzas).
  final bool accesoDirecto;

  /// Fase en la que se activa, si no es desde el inicio.
  final int? desdeFase;

  /// Acciones dadas a mano cuando no salen solo del alcance (p. ej. "lo
  /// propio" con administrar: cada quien administra su libro de Finanzas).
  final Set<Accion>? _acciones;

  /// Acciones que da la celda (las mismas que `permisos_rol` en el servidor).
  Set<Accion> get acciones => _acciones ?? accionesDe(alcance);

  /// Acciones que da [alcance] por omisión.
  static Set<Accion> accionesDe(Alcance alcance) => switch (alcance) {
    Alcance.ninguno => const {},
    Alcance.total => const {Accion.leer, Accion.escribir, Accion.administrar},
    Alcance.lectura ||
    Alcance.generico ||
    Alcance.parcial => const {Accion.leer},
    Alcance.propio ||
    Alcance.turno ||
    Alcance.solicitudes ||
    Alcance.consentimiento => const {Accion.leer, Accion.escribir},
    Alcance.registroPropio => const {Accion.escribir},
  };
}

/// Matriz rol × módulo. Da las mismas acciones que la matriz del servidor
/// (`permisos_rol` en `supabase/migrations/`); la prueba
/// `test/revision_calidad/i1_matriz_espejo_servidor_test.dart` lo vigila.
///
/// Decisiones del dueño (D18 y D19, 21/oct/2026): cada quien ve lo suyo, también
/// el dueño (historial de GRAVITY y finanzas personales); el dueño y la pareja
/// llevan **su** libro de Finanzas y los compartidos de los que son miembros;
/// la cuidadora no lee Finanzas (solo registrará sus gastos de cuidado en la
/// Fase 5) y de GRAVITY solo usa su bandeja de solicitudes y recordatorios; el
/// coadministrador no entra a Cuidados hasta que exista el consentimiento
/// (Fase 5). La cuenta maestra (D19) se resuelve aparte: [puedeSobre].
const _todas = {Accion.leer, Accion.escribir, Accion.administrar};

const Map<Modulo, Map<Rol, Permiso>> matrizPermisos = {
  Modulo.gravity: {
    Rol.dueno: Permiso(
      Alcance.propio,
      'Lo suyo (cada quien su historial) y la configuración de GRAVITY',
      acciones: _todas,
    ),
    Rol.coadministrador: Permiso(Alcance.propio, 'Lo suyo'),
    Rol.familiar: Permiso(Alcance.propio, 'Lo suyo'),
    Rol.cuidador: Permiso(
      Alcance.solicitudes,
      'Solo sus solicitudes y recordatorios, para confirmarlos',
      accesoDirecto: false,
    ),
    Rol.casa: Permiso(
      Alcance.propio,
      'Órdenes de la casa, sin dinero ni datos clínicos',
    ),
  },
  Modulo.finanzas: {
    Rol.dueno: Permiso(
      Alcance.propio,
      'Su libro, los compartidos y el de papá como albacea',
      acciones: _todas,
    ),
    Rol.coadministrador: Permiso(
      Alcance.propio,
      'Su libro y los compartidos de los que es miembro',
      acciones: _todas,
    ),
    Rol.familiar: Permiso.ninguno(),
    Rol.cuidador: Permiso(
      Alcance.registroPropio,
      'Solo registra sus gastos de cuidado, desde Cuidados; no lee Finanzas',
      accesoDirecto: false,
      desdeFase: 5,
    ),
    Rol.casa: Permiso.ninguno(),
  },
  Modulo.habitos: {
    Rol.dueno: Permiso(Alcance.propio, 'Lo propio'),
    Rol.coadministrador: Permiso(Alcance.propio, 'Lo propio'),
    Rol.familiar: Permiso(Alcance.propio, 'Lo propio'),
    Rol.cuidador: Permiso.ninguno(),
    Rol.casa: Permiso.ninguno(),
  },
  Modulo.cuidados: {
    Rol.dueno: Permiso(Alcance.total, 'Total'),
    Rol.coadministrador: Permiso(
      Alcance.consentimiento,
      'Según consentimiento (sin acceso hasta registrarlo)',
      accesoDirecto: false,
      desdeFase: 5,
    ),
    Rol.familiar: Permiso.ninguno(),
    Rol.cuidador: Permiso(Alcance.turno, 'Su turno'),
    Rol.casa: Permiso(Alcance.generico, 'Recordatorios genéricos'),
  },
  Modulo.alimentacion: {
    Rol.dueno: Permiso(Alcance.total, 'Total'),
    Rol.coadministrador: Permiso(Alcance.total, 'Total'),
    Rol.familiar: Permiso(Alcance.parcial, 'Leer su parte'),
    Rol.cuidador: Permiso(
      Alcance.parcial,
      'Leer las comidas de papá, desde Cuidados',
      accesoDirecto: false,
    ),
    Rol.casa: Permiso(Alcance.parcial, 'Leer el menú y la lista'),
  },
  Modulo.casa: {
    Rol.dueno: Permiso(Alcance.total, 'Total'),
    Rol.coadministrador: Permiso(Alcance.total, 'Total'),
    Rol.familiar: Permiso(Alcance.lectura, 'Leer'),
    Rol.cuidador: Permiso(
      Alcance.lectura,
      'Leer, desde Cuidados',
      accesoDirecto: false,
    ),
    Rol.casa: Permiso(Alcance.lectura, 'Leer'),
  },
  Modulo.ajustes: {
    Rol.dueno: Permiso(Alcance.total, 'Total'),
    Rol.coadministrador: Permiso(Alcance.propio, 'Lo propio'),
    Rol.familiar: Permiso(Alcance.propio, 'Lo propio'),
    Rol.cuidador: Permiso(Alcance.propio, 'Lo propio'),
    Rol.casa: Permiso.ninguno(),
  },
};

/// Celda de la matriz para [rol] y [modulo].
Permiso permisoDe(Rol rol, Modulo modulo) =>
    matrizPermisos[modulo]?[rol] ?? const Permiso.ninguno();

/// `true` si [rol] puede hacer [accion] en [modulo] (en algún alcance).
bool puede(Rol rol, Modulo modulo, Accion accion) =>
    permisoDe(rol, modulo).acciones.contains(accion);

/// `true` si [rol] abre las pantallas propias de [modulo] (rutas y menús).
bool puedeAbrir(Rol rol, Modulo modulo) {
  final permiso = permisoDe(rol, modulo);
  return permiso.accesoDirecto && permiso.acciones.contains(Accion.leer);
}

/// Módulos en los que la **cuenta maestra** (D19) lee también lo ajeno: los
/// libros de Finanzas y el historial de GRAVITY de todos.
const Set<Modulo> modulosQueLeeLaMaestra = {Modulo.finanzas, Modulo.gravity};

/// Lo que puede hacer una sesión sobre **un dato concreto** de [modulo] (un
/// libro de Finanzas, una conversación del historial de GRAVITY…).
///
/// [esDeLaPersona] es `true` si el dato es suyo o de un libro compartido del
/// que es miembro (lo dice el módulo, que conoce al dueño del dato).
/// - Lo suyo: según la matriz ([puede]).
/// - Lo ajeno: solo con alcance total en el módulo (p. ej. Cuidados del dueño).
/// - La **cuenta maestra** [esMaestra] además **lee** lo ajeno de
///   [modulosQueLeeLaMaestra], y **nunca** escribe ni administra lo ajeno: no
///   se le muestran esos botones.
///
/// Solo es para la interfaz; el servidor decide (RLS, `fin_puede`).
bool puedeSobre(
  Rol rol,
  Modulo modulo,
  Accion accion, {
  required bool esDeLaPersona,
  bool esMaestra = false,
}) {
  if (esDeLaPersona) return puede(rol, modulo, accion);
  final conTotal =
      permisoDe(rol, modulo).alcance == Alcance.total && puede(rol, modulo, accion);
  if (!esMaestra) return conTotal;
  if (accion != Accion.leer) return false;
  return conTotal || modulosQueLeeLaMaestra.contains(modulo);
}

/// Clave de `GoRoute.metadata` con la acción que exige una ruta de un módulo
/// además de leerlo. Úsala con [exigeAccion].
const claveAccionDeRuta = 'gravity.accion';

/// `metadata` de una ruta que solo abre quien puede hacer [accion] en su
/// módulo; a los demás el router los regresa al inicio del módulo (p. ej. el
/// asistente de arranque de Finanzas: el coadministrador solo lee).
///
/// ```dart
/// GoRoute(path: 'asistente', metadata: exigeAccion(Accion.administrar), …)
/// ```
///
/// Las rutas hijas la heredan. Es solo para la interfaz: la verdad está en el
/// servidor (RLS).
Map<String, Object> exigeAccion(Accion accion) => {claveAccionDeRuta: accion};

/// Acción que exige una ruta según su `metadata` ya combinada (`null` si
/// basta con leer el módulo).
Accion? accionExigida(Map<String, dynamic> metadata) =>
    switch (metadata[claveAccionDeRuta]) {
      final Accion accion => accion,
      _ => null,
    };

/// Módulos de trabajo, en el orden de la barra de módulos de la laptop
/// (`DISENO_UX_UI.md`, sección 7) y de los atajos Ctrl + 1 a 5.
const List<Modulo> modulosDeTrabajo = [
  Modulo.finanzas,
  Modulo.habitos,
  Modulo.cuidados,
  Modulo.alimentacion,
  Modulo.casa,
];

/// Módulos de trabajo que [rol] ve en su navegación.
List<Modulo> modulosNavegables(Rol rol) => [
  for (final modulo in modulosDeTrabajo)
    if (puedeAbrir(rol, modulo)) modulo,
];

/// Ajustes › Desarrollador (D16): solo el Dueño y solo en la laptop.
bool puedeVerDesarrollador(Rol rol, TipoDispositivo dispositivo) =>
    dispositivo == TipoDispositivo.laptop &&
    puede(rol, Modulo.ajustes, Accion.administrar);

/// Nombre del rol para la interfaz.
String nombreRol(Rol rol) => switch (rol) {
  Rol.dueno => 'Dueño',
  Rol.coadministrador => 'Coadministrador',
  Rol.familiar => 'Familiar',
  Rol.cuidador => 'Cuidador',
  Rol.casa => 'Casa',
};

/// Nombre del módulo para la interfaz.
String nombreModulo(Modulo modulo) => switch (modulo) {
  Modulo.gravity => 'GRAVITY',
  Modulo.finanzas => 'Finanzas',
  Modulo.habitos => 'Hábitos',
  Modulo.cuidados => 'Cuidados',
  Modulo.alimentacion => 'Alimentación',
  Modulo.casa => 'Casa',
  Modulo.ajustes => 'Ajustes',
};
