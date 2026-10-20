/// Servicio de sesión falso para pruebas (de cualquier agente).
///
/// ```dart
/// final sesion = ServicioSesionFalso(
///   cuentas: {'ana@ejemplo.mx': CuentaFalsa('secreta', sesionDeEjemplo(Rol.cuidador))},
/// );
/// ```
library;

import '../contratos/roles.dart';
import 'servicio_sesion_demostracion.dart';
import 'sesion.dart';

class CuentaFalsa {
  const CuentaFalsa(this.contrasena, this.sesion);

  final String contrasena;
  final Sesion sesion;
}

class ServicioSesionFalso extends ServicioSesionEnMemoria {
  ServicioSesionFalso({
    Map<String, CuentaFalsa>? cuentas,
    super.inicial,
    this.sinConexion = false,
  }) : cuentas = cuentas ?? {};

  /// Abre el servicio con una sesión de ejemplo del [rol].
  factory ServicioSesionFalso.con(Rol rol) =>
      ServicioSesionFalso(inicial: sesionDeEjemplo(rol));

  final Map<String, CuentaFalsa> cuentas;

  /// Simula que no hay internet: entrar y verificar fallan.
  bool sinConexion;

  int vecesEntrar = 0;
  int vecesSalir = 0;
  int vecesVerificar = 0;

  @override
  bool get esDemostracion => false;

  /// Cambia la sesión desde la prueba.
  void fijarSesion(Sesion? sesion) => emitir(sesion);

  @override
  Future<Sesion> entrar({
    required String correo,
    required String contrasena,
  }) async {
    vecesEntrar++;
    final sesion = _comprobar(correo, contrasena);
    emitir(sesion);
    return sesion;
  }

  @override
  Future<Sesion> verificarCredenciales({
    required String correo,
    required String contrasena,
  }) async {
    vecesVerificar++;
    return _comprobar(correo, contrasena);
  }

  Sesion _comprobar(String correo, String contrasena) {
    if (sinConexion) throw ErrorSesion.sinConexion;
    final cuenta = cuentas[correo.trim().toLowerCase()];
    if (cuenta == null || cuenta.contrasena != contrasena) {
      throw ErrorSesion.credencialesIncorrectas;
    }
    return cuenta.sesion;
  }

  @override
  Future<void> salir() async {
    vecesSalir++;
    await super.salir();
  }
}
