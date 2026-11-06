/// Contrato compartido entre agentes (dueño: arquitecto).
/// Rutas de primer nivel de la app. Cada módulo agrega sus subrutas debajo de la suya.
library;

abstract final class Rutas {
  static const inicio = '/';
  static const finanzas = '/finanzas';
  static const habitos = '/habitos';
  static const cuidados = '/cuidados';
  static const alimentacion = '/alimentacion';
  static const casa = '/casa';
  static const ajustes = '/ajustes';
  static const desarrollador = '/ajustes/desarrollador';
  static const entrar = '/entrar';
}
