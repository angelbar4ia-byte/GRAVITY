/// Espejo de la matriz de permisos (docs/specs/fase-0-cimientos.md, sección 5).
///
/// La verdad de los permisos está en el **servidor** (RLS, D5 y D7). Este
/// espejo solo sirve para ocultar en la interfaz lo que no le corresponde a
/// cada rol: nada de pantallas vacías ni botones bloqueados.
library;

import '../contratos/dispositivo.dart';
import '../contratos/roles.dart';

/// Alcance de una celda de la matriz, **el mismo que en el servidor**
/// (`permisos_rol.alcance`, dominio `alcance_permiso`): `total`, `propio` o
/// `restringido` (D17).
///
/// Lo particular de cada rol no es un alcance: se resuelve **por rol** sobre
/// una celda `restringido` (rol × módulo × restringido). Así, la bandeja de
/// solicitudes y recordatorios de la cuidadora en GRAVITY es
/// cuidador × gravity × restringido ([soloBandejaDeSolicitudes]); su turno en
/// Cuidados, cuidador × cuidados × restringido; el menú y la lista de la
/// cuenta Casa, casa × alimentacion × restringido. El texto de cada celda
/// ([Permiso.descripcion]) dice qué subconjunto es.
enum Alcance {
  /// Sin acceso (sin fila en el servidor).
  ninguno(null),

  /// Todo el módulo en el hogar. Con [Permiso.acciones] puede ser solo leer
  /// (p. ej. Casa para el familiar).
  total('total'),

  /// Solo lo de la persona (en Finanzas, también los libros compartidos de los
  /// que es miembro y el de papá si es su albacea: `fin_puede`).
  propio('propio'),

  /// Un subconjunto que define el módulo para ese rol (su turno, su parte, el
  /// menú y la lista, sus solicitudes…). Siempre con [Permiso.acciones]
  /// explícitas.
  restringido('restringido');

  const Alcance(this.enServidor);

  /// Valor de `permisos_rol.alcance` en el servidor (`null`: sin fila).
  final String? enServidor;
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

  /// Texto en español para Ajustes › Personas y roles. En una celda
  /// `restringido` dice qué subconjunto le toca al rol.
  final String descripcion;

  /// `true` si el rol abre las pantallas del módulo desde la navegación.
  /// `false` si lo usa solo desde otro módulo o desde su bandeja (p. ej. la
  /// cuidadora registra gastos de cuidado desde Cuidados, no desde Finanzas, y
  /// de GRAVITY solo usa su bandeja de solicitudes).
  final bool accesoDirecto;

  /// Fase en la que se activa, si no es desde el inicio.
  final int? desdeFase;

  /// Acciones dadas a mano cuando no salen solo del alcance (p. ej. "lo
  /// propio" con administrar: cada quien administra su libro de Finanzas; o
  /// "total" solo para leer).
  final Set<Accion>? _acciones;

  /// Acciones que da la celda: una fila de `permisos_rol` por acción, con
  /// este mismo alcance.
  Set<Accion> get acciones => _acciones ?? accionesDe(alcance);

  /// Acciones que da [alcance] por omisión. `restringido` no tiene: cada
  /// celda dice las suyas (solo leer, por si faltaran).
  static Set<Accion> accionesDe(Alcance alcance) => switch (alcance) {
    Alcance.ninguno => const {},
    Alcance.total => const {Accion.leer, Accion.escribir, Accion.administrar},
    Alcance.restringido => const {Accion.leer},
    Alcance.propio => const {Accion.leer, Accion.escribir},
  };
}

/// Matriz rol × módulo. Da las mismas filas que la matriz del servidor
/// (`permisos_rol` en `supabase/migrations/`): las mismas acciones y el mismo
/// alcance en cada una. La prueba
/// `test/revision_calidad/i1_matriz_espejo_servidor_test.dart` lo vigila fila
/// por fila.
///
/// Decisiones del dueño (D18 y D19, 21/oct/2026): cada quien ve lo suyo, también
/// el dueño (historial de GRAVITY y finanzas personales); el dueño y la pareja
/// llevan **su** libro de Finanzas y los compartidos de los que son miembros;
/// la cuidadora no lee Finanzas (solo registrará sus gastos de cuidado en la
/// Fase 5) y de GRAVITY solo usa su bandeja de solicitudes y recordatorios; el
/// coadministrador no entra a Cuidados hasta que exista el consentimiento
/// (Fase 5). La cuenta maestra (D19) se resuelve aparte: [puedeSobre].
const _todas = {Accion.leer, Accion.escribir, Accion.administrar};
const _leer = {Accion.leer};
const _leerYEscribir = {Accion.leer, Accion.escribir};

const Map<Modulo, Map<Rol, Permiso>> matrizPermisos = {
  Modulo.gravity: {
    Rol.dueno: Permiso(
      Alcance.propio,
      'Lo suyo (cada quien su historial) y la configuración de GRAVITY',
      acciones: _todas,
    ),
    Rol.coadministrador: Permiso(Alcance.propio, 'Lo suyo'),
    Rol.familiar: Permiso(Alcance.propio, 'Lo suyo'),
    // D18: restringido = su bandeja de solicitudes y recordatorios (los lee y
    // los confirma). No abre las pantallas de GRAVITY ni conversa con él.
    Rol.cuidador: Permiso(
      Alcance.restringido,
      'Solo sus solicitudes y recordatorios, para confirmarlos',
      acciones: _leerYEscribir,
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
    // D5: restringido = solo escribe sus gastos de cuidado; nunca lee.
    Rol.cuidador: Permiso(
      Alcance.restringido,
      'Solo registra sus gastos de cuidado, desde Cuidados; no lee Finanzas',
      acciones: {Accion.escribir},
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
    // D2 y D18: restringido = según el consentimiento de quien representa a
    // la persona; sin él no hay acceso (Fase 5).
    Rol.coadministrador: Permiso(
      Alcance.restringido,
      'Según consentimiento (sin acceso hasta registrarlo)',
      acciones: _leerYEscribir,
      accesoDirecto: false,
      desdeFase: 5,
    ),
    Rol.familiar: Permiso.ninguno(),
    // Restringido = su turno.
    Rol.cuidador: Permiso(
      Alcance.restringido,
      'Su turno',
      acciones: _leerYEscribir,
    ),
    // D3: restringido = solo recordatorios genéricos, sin nombres ni
    // medicamentos.
    Rol.casa: Permiso(
      Alcance.restringido,
      'Recordatorios genéricos',
      acciones: _leer,
    ),
  },
  Modulo.alimentacion: {
    Rol.dueno: Permiso(Alcance.total, 'Total'),
    Rol.coadministrador: Permiso(Alcance.total, 'Total'),
    Rol.familiar: Permiso(
      Alcance.restringido,
      'Leer su parte',
      acciones: _leer,
    ),
    Rol.cuidador: Permiso(
      Alcance.restringido,
      'Leer las comidas de papá, desde Cuidados',
      acciones: _leer,
      accesoDirecto: false,
    ),
    Rol.casa: Permiso(
      Alcance.restringido,
      'Leer el menú y la lista',
      acciones: _leer,
    ),
  },
  Modulo.casa: {
    Rol.dueno: Permiso(Alcance.total, 'Total'),
    Rol.coadministrador: Permiso(Alcance.total, 'Total'),
    Rol.familiar: Permiso(Alcance.total, 'Leer', acciones: _leer),
    Rol.cuidador: Permiso(
      Alcance.total,
      'Leer, desde Cuidados',
      acciones: _leer,
      accesoDirecto: false,
    ),
    Rol.casa: Permiso(Alcance.total, 'Leer', acciones: _leer),
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

// ---------------------------------------------------------------------------
// Lo particular de cada rol sobre una celda `restringido` (D17): se resuelve
// por rol, no con alcances nuevos.
// ---------------------------------------------------------------------------

bool _restringido(Rol rol, Modulo modulo) =>
    permisoDe(rol, modulo).alcance.enServidor == 'restringido';

/// D18: de GRAVITY, [rol] solo usa su **bandeja de solicitudes y
/// recordatorios** (los lee y los confirma: *Hecho* o *No se pudo*, con nota),
/// sin abrir las pantallas de GRAVITY ni conversar con él, y sin ver nada de
/// la familia. Es lo que significa gravity × restringido: hoy, la cuidadora.
bool soloBandejaDeSolicitudes(Rol rol) =>
    _restringido(rol, Modulo.gravity) &&
    puede(rol, Modulo.gravity, Accion.leer) &&
    !puedeAbrir(rol, Modulo.gravity);

/// D3: de Cuidados, [rol] solo ve recordatorios genéricos, sin nombres ni
/// medicamentos: la cuenta Casa (casa × cuidados × restringido).
bool soloRecordatoriosGenericos(Rol rol, Modulo modulo) =>
    modulo == Modulo.cuidados && rol == Rol.casa && _restringido(rol, modulo);

/// D2 y D18: [rol] entra a [modulo] solo con el consentimiento de quien
/// representa a la persona (sin él, nada; Fase 5): el coadministrador en
/// Cuidados (coadministrador × cuidados × restringido).
bool dependeDelConsentimiento(Rol rol, Modulo modulo) =>
    modulo == Modulo.cuidados &&
    rol == Rol.coadministrador &&
    _restringido(rol, modulo);

/// `true` si la sesión es de **solo lectura total** (D19, 23/oct/2026): una
/// cuenta maestra que **no es la dueña**. La maestra con su propio login es
/// otra persona: lee todo y no registra ni administra nada, ni en lo suyo
/// (lo suyo lo registra el dueño con su cuenta normal), y no tiene (+) ni
/// órdenes que abran una hoja de registro. Si la dueña es además la maestra,
/// escribe en lo suyo y en lo ajeno solo lee ([puedeSobre]).
bool esSoloLectura(Rol rol, {required bool esMaestra}) =>
    esMaestra && rol != Rol.dueno;

/// [puede] para una sesión: igual, salvo que una cuenta de solo lectura
/// ([esSoloLectura]) nunca escribe ni administra.
bool puedeConSesion(
  Rol rol,
  Modulo modulo,
  Accion accion, {
  bool esMaestra = false,
}) =>
    puede(rol, modulo, accion) &&
    (accion == Accion.leer || !esSoloLectura(rol, esMaestra: esMaestra));

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
///   se le muestran esos botones. Si no es la dueña ([esSoloLectura]), tampoco
///   escribe ni administra **lo suyo** (D19, 23/oct/2026).
///
/// Solo es para la interfaz; el servidor decide (RLS, `fin_puede`).
bool puedeSobre(
  Rol rol,
  Modulo modulo,
  Accion accion, {
  required bool esDeLaPersona,
  bool esMaestra = false,
}) {
  if (accion != Accion.leer && esSoloLectura(rol, esMaestra: esMaestra)) {
    return false;
  }
  if (esDeLaPersona) return puede(rol, modulo, accion);
  final conTotal =
      permisoDe(rol, modulo).alcance == Alcance.total &&
      puede(rol, modulo, accion);
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
