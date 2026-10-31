/// Herramientas de GRAVITY (D1, D3).
///
/// GRAVITY no lee bases de datos: solo actúa con la lista cerrada de
/// herramientas que publica cada módulo. Cada herramienta declara su módulo,
/// los roles que la pueden usar, si escribe (pide confirmación) y si es solo
/// local (su resultado nunca se envía a la IA en la nube).
///
/// Desde la Fase 1 declara además (con valores por omisión):
/// - [Herramienta.accion]: lo que la persona debe poder hacer en el módulo
///   para que se le ofrezca (leer, escribir o administrar).
/// - [Herramienta.pertenencia]: si actúa sobre lo propio o sobre lo ajeno
///   (D19: la cuenta maestra lee lo ajeno y nunca lo escribe).
/// - [Herramienta.ambito]: si es de la bandeja de solicitudes y recordatorios
///   (D18: lo único de GRAVITY que usa la cuidadora).
library;

import '../contratos/roles.dart';

/// Formato del nombre: `<modulo>.<accion>`, en minúsculas, sin acentos ni ñ.
/// Ejemplo: `habitos.resumen_hoy`.
final RegExp formatoNombreHerramienta = RegExp(
  r'^[a-z][a-z0-9_]*\.[a-z][a-z0-9_]*$',
);

/// Módulos con dinero o datos clínicos (D3): **todas** sus herramientas son
/// solo locales, también las de navegación. El registro rechaza una que no lo
/// sea.
const Set<Modulo> modulosSoloLocal = {Modulo.finanzas, Modulo.cuidados};

/// Para qué parte de GRAVITY es una herramienta (D18).
enum AmbitoHerramienta {
  /// Lo de siempre: abrir módulos, consultar, registrar…
  general,

  /// La bandeja de solicitudes y recordatorios que GRAVITY le hace a la
  /// cuidadora y que ella confirma (hecho o no se pudo, con nota). Es lo único
  /// que recibe quien en GRAVITY solo tiene su bandeja (`soloBandejaEnGravity`:
  /// se resuelve por rol, D17; en el servidor su GRAVITY es `restringido`).
  solicitudes,
}

/// De quién son los datos sobre los que actúa una herramienta (D5, D19:
/// cada quien ve lo suyo).
enum Pertenencia {
  /// Lo de la persona: lo suyo y lo de un libro compartido del que es miembro.
  propia,

  /// Lo de otra persona o lo que administra el hogar (p. ej. el libro de otro,
  /// el historial de GRAVITY de otro, Ajustes › Desarrollador). La cuenta
  /// maestra lo lee en Finanzas y GRAVITY, y **nunca** lo escribe.
  ajena,
}

/// Hojas de registro que una herramienta puede abrir. Abrir una hoja no
/// escribe nada: la persona captura y confirma en ella (la hoja es la
/// confirmación). Cómo se muestra (hoja inferior o diálogo) lo decide la app.
enum HojaDeRegistro {
  /// Registro rápido de un gasto (F1).
  gasto,

  /// Registro de un ingreso extra.
  ingresoExtra,
}

/// Una función que GRAVITY puede usar.
///
/// Las subclases declaran sus datos y su lógica; el permiso y la confirmación
/// los aplica [RegistroHerramientas], nunca la herramienta por su cuenta.
abstract class Herramienta {
  const Herramienta();

  /// Nombre único `<modulo>.<accion>`, p. ej. `habitos.resumen_hoy`.
  String get nombre;

  /// Qué hace, en español y en una oración (lo lee la persona y, si aplica, la IA).
  String get descripcion;

  /// Módulo dueño de la herramienta. El prefijo del [nombre] es `modulo.name`.
  Modulo get modulo;

  /// Roles que la pueden usar (D5). Fuera de estos roles la herramienta no existe.
  Set<Rol> get roles;

  /// `true` si escribe datos: siempre pide confirmación antes de ejecutarse.
  bool get escribe;

  /// `true` si su resultado nunca se envía a la IA en la nube (D3: dinero,
  /// datos clínicos). El resultado va directo a la pantalla o a la voz local.
  bool get soloLocal;

  /// Lo que la persona debe poder hacer en [modulo] para que se le ofrezca.
  /// Por omisión: escribir si [escribe], leer si no. Una herramienta que no
  /// escribe puede exigir más (p. ej. abrir la hoja de un gasto exige poder
  /// escribir en Finanzas, aunque la que guarda es la hoja).
  Accion get accion => escribe ? Accion.escribir : Accion.leer;

  /// Sobre qué datos actúa (D19). Por omisión, lo propio.
  Pertenencia get pertenencia => Pertenencia.propia;

  /// Para qué parte de GRAVITY es (D18). Por omisión, [AmbitoHerramienta.general].
  AmbitoHerramienta get ambito => AmbitoHerramienta.general;

  /// `false` si la cuenta maestra de solo lectura total (D19, 23/oct) no la
  /// recibe aunque solo lea: las consultas del libro propio (resumen de la
  /// semana, próximos pagos, avance del ahorro) son de quien lleva su libro,
  /// y esa cuenta no lleva ninguno. Por omisión, `true`.
  bool get ofreceASoloLectura => true;

  /// Texto de la tarjeta de confirmación (solo se usa si [escribe]).
  String resumenConfirmacion(Map<String, Object?> parametros) =>
      '¿Confirmas? $descripcion';

  /// Ejecuta la herramienta. No se llama directamente: se usa
  /// [RegistroHerramientas.ejecutar], que revisa rol, módulo y confirmación.
  Future<ResultadoHerramienta> ejecutar(
    Map<String, Object?> parametros,
    ContextoHerramienta ctx,
  );
}

/// Lo que devuelve una herramienta.
///
/// Por construcción, si la herramienta es [Herramienta.soloLocal], [paraIa]
/// es siempre `null`: no hay constructor que permita lo contrario.
final class ResultadoHerramienta {
  /// Resultado de [herramienta]. Si es solo local, [paraIa] se descarta.
  ResultadoHerramienta(
    Herramienta herramienta, {
    required this.contenido,
    String? paraIa,
  }) : nombreHerramienta = herramienta.nombre,
       soloLocal = herramienta.soloLocal,
       requiereConfirmacion = false,
       paraIa = herramienta.soloLocal ? null : paraIa;

  /// La herramienta escribe y aún no se confirma: no se ejecutó nada.
  /// [contenido] es el texto de la tarjeta de confirmación.
  ResultadoHerramienta.pendienteDeConfirmacion(
    Herramienta herramienta, {
    required this.contenido,
  }) : nombreHerramienta = herramienta.nombre,
       soloLocal = herramienta.soloLocal,
       requiereConfirmacion = true,
       paraIa = null;

  /// Nombre de la herramienta que lo produjo.
  final String nombreHerramienta;

  /// Texto para la pantalla o la voz local.
  final String contenido;

  /// `true` si falta la confirmación de la persona; no se escribió nada.
  final bool requiereConfirmacion;

  /// Texto mínimo que sí puede ver la IA en la nube. Siempre `null` si [soloLocal].
  final String? paraIa;

  /// Copia de [Herramienta.soloLocal] de quien lo produjo.
  final bool soloLocal;

  @override
  String toString() =>
      'ResultadoHerramienta($nombreHerramienta, requiereConfirmacion: '
      '$requiereConfirmacion, soloLocal: $soloLocal)';
}

/// Con qué se ejecuta una herramienta: quién la pide y qué puede hacer la app.
final class ContextoHerramienta {
  const ContextoHerramienta({
    required this.rol,
    this.confirmado = false,
    this.esMaestra = false,
    this.modulosActivos,
    this.navegar,
    this.abrirHoja,
    this.consultaLocal,
  });

  /// Rol de la sesión (D5).
  final Rol rol;

  /// `true` si la sesión es la cuenta maestra del hogar (D19): lee lo ajeno
  /// de Finanzas y GRAVITY y nunca recibe herramientas que lo escriban. Si
  /// además no es la dueña (login propio), es de **solo lectura total**:
  /// ninguna herramienta que escriba ni abra una hoja de registro, tampoco
  /// para lo propio (23/oct). Si es la dueña, conserva las suyas para lo
  /// propio.
  final bool esMaestra;

  /// `true` solo después de que la persona aceptó la tarjeta de confirmación.
  final bool confirmado;

  /// Módulos activos en esta instalación; `null` significa todos.
  final Set<Modulo>? modulosActivos;

  /// Abre una ruta de la app (las de `Rutas`). `null` si no hay pantalla.
  final void Function(String ruta)? navegar;

  /// Abre una hoja de registro (la persona captura y confirma en ella).
  /// `null` si no hay pantalla: la herramienta abre la ruta de su módulo.
  final void Function(HojaDeRegistro hoja)? abrirHoja;

  /// Contenido de las herramientas de consulta (p. ej. `finanzas.resumen_semana`),
  /// que entrega el módulo desde sus datos locales. Devuelve el texto para la
  /// pantalla o la voz local, o `null` si no hay datos. Nunca va a la IA en la
  /// nube ni a las bocinas (D3, D6). `null`: la herramienta solo abre la vista.
  final Future<String?> Function(String herramienta)? consultaLocal;

  /// El mismo contexto, ya confirmado por la persona.
  ContextoHerramienta confirmar() => ContextoHerramienta(
    rol: rol,
    confirmado: true,
    esMaestra: esMaestra,
    modulosActivos: modulosActivos,
    navegar: navegar,
    abrirHoja: abrirHoja,
    consultaLocal: consultaLocal,
  );
}

/// Por qué una herramienta no está disponible.
enum MotivoNoDisponible {
  noExiste,
  rolSinPermiso,
  moduloInactivo,

  /// La cuenta maestra no escribe ni administra lo ajeno (D19), y si no es la
  /// dueña no escribe nada, ni abre una hoja de registro (solo lectura total).
  cuentaMaestra,
}

/// La herramienta no existe para esta sesión. Hacia fuera el mensaje es el
/// mismo en todos los casos: lo que no está en la lista no existe (D1).
final class HerramientaNoDisponible implements Exception {
  const HerramientaNoDisponible(this.nombre, this.motivo);

  final String nombre;
  final MotivoNoDisponible motivo;

  String get mensaje => 'La herramienta «$nombre» no está disponible.';

  @override
  String toString() => 'HerramientaNoDisponible($nombre, ${motivo.name})';
}

/// Falló una herramienta solo local (D3).
///
/// El registro envuelve así cualquier error de una herramienta [Herramienta.soloLocal]:
/// el mensaje del error original podría llevar cifras o datos clínicos, y
/// quien lo atrape (p. ej. la conversación con IA de la Fase 6) podría
/// mandarlo a la nube. Hacia fuera solo dice qué herramienta falló.
final class FalloHerramienta implements Exception {
  const FalloHerramienta(this.nombre, {this.causaLocal});

  final String nombre;

  /// El error original. Solo para la pantalla o el registro del dispositivo;
  /// nunca se envía a la IA en la nube ni a las bocinas.
  final Object? causaLocal;

  /// Texto seguro para la persona y para la IA.
  String get mensaje => 'La herramienta «$nombre» no pudo completarse.';

  @override
  String toString() => 'FalloHerramienta($nombre)';
}
