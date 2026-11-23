/// Gancho para **mantener la pantalla encendida** durante la sesión de
/// gimnasio (spec 7.2, 12 y 20; H-14). **No está implementado.**
///
/// Hacerlo pide un paquete (p. ej. `wakelock_plus`) o un canal nativo en
/// `MainActivity` que ponga `FLAG_KEEP_SCREEN_ON`, y el dueño **no ha aprobado**
/// ninguno de los dos (la especificación, sección 20, lo deja sin hacer hasta
/// que `plataforma` lo evalúe y el dueño apruebe). Por eso este archivo solo
/// deja la **interfaz** y una implementación que no hace nada: la pantalla de la
/// sesión (G5) ya puede llamar a [PantallaEncendida.mantener] al empezar y al
/// terminar; hoy no cambia nada y la sesión **no depende de ello** para guardar.
///
/// Cuando se apruebe, se sobrescribe [pantallaEncendidaProvider] con la
/// implementación real, sin tocar a quien la llama.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract interface class PantallaEncendida {
  /// `true` si este equipo puede mantener la pantalla encendida (hoy, nunca).
  bool get disponible;

  /// Pide mantener la pantalla encendida ([encendida] `true`) o devolver el
  /// control al sistema (`false`). Devuelve `true` si el sistema quedó como se
  /// pidió. Debe poder llamarse de más sin efecto (al salir de la sesión se
  /// llama con `false` aunque nunca se hubiera pedido).
  Future<bool> mantener(bool encendida);
}

/// La que hay hoy: no hace nada y lo dice.
class PantallaEncendidaNula implements PantallaEncendida {
  const PantallaEncendidaNula();

  @override
  bool get disponible => false;

  @override
  Future<bool> mantener(bool encendida) async => false;
}

final pantallaEncendidaProvider = Provider<PantallaEncendida>(
  (ref) => const PantallaEncendidaNula(),
);
