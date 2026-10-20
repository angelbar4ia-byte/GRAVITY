/// Herramientas de GRAVITY (D1, D3).
///
/// GRAVITY no lee bases de datos: solo actúa con la lista cerrada de
/// herramientas que publica cada módulo. Cada herramienta declara su módulo,
/// los roles que la pueden usar, si escribe (pide confirmación) y si es solo
/// local (su resultado nunca se envía a la IA en la nube).
library;

import '../contratos/roles.dart';

/// Formato del nombre: `<modulo>.<accion>`, en minúsculas, sin acentos ni ñ.
/// Ejemplo: `habitos.resumen_hoy`.
final RegExp formatoNombreHerramienta = RegExp(
  r'^[a-z][a-z0-9_]*\.[a-z][a-z0-9_]*$',
);

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
    this.modulosActivos,
    this.navegar,
  });

  /// Rol de la sesión (D5).
  final Rol rol;

  /// `true` solo después de que la persona aceptó la tarjeta de confirmación.
  final bool confirmado;

  /// Módulos activos en esta instalación; `null` significa todos.
  final Set<Modulo>? modulosActivos;

  /// Abre una ruta de la app (las de `Rutas`). `null` si no hay pantalla.
  final void Function(String ruta)? navegar;

  /// El mismo contexto, ya confirmado por la persona.
  ContextoHerramienta confirmar() => ContextoHerramienta(
    rol: rol,
    confirmado: true,
    modulosActivos: modulosActivos,
    navegar: navegar,
  );
}

/// Por qué una herramienta no está disponible.
enum MotivoNoDisponible { noExiste, rolSinPermiso, moduloInactivo }

/// La herramienta no existe para esta sesión. Hacia fuera el mensaje es el
/// mismo en los tres casos: lo que no está en la lista no existe (D1).
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
