/// Modo demostración: se usa cuando no hay llaves de Supabase
/// (`--dart-define=SUPABASE_URL=...` y `SUPABASE_ANON_KEY`). Personas de
/// ejemplo, sin servidor y sin datos reales.
library;

import '../contratos/roles.dart';
import 'sesion.dart';

/// Personas de ejemplo por rol (nunca datos reales).
const Map<Rol, Persona> personasDeEjemplo = {
  Rol.dueno: Persona(
    id: '00000000-0000-4000-8000-000000000001',
    nombre: 'Dueño de ejemplo',
    correo: 'dueno@ejemplo.mx',
  ),
  Rol.coadministrador: Persona(
    id: '00000000-0000-4000-8000-000000000002',
    nombre: 'Pareja de ejemplo',
    correo: 'pareja@ejemplo.mx',
  ),
  Rol.familiar: Persona(
    id: '00000000-0000-4000-8000-000000000003',
    nombre: 'Familiar de ejemplo',
    correo: 'familiar@ejemplo.mx',
  ),
  Rol.cuidador: Persona(
    id: '00000000-0000-4000-8000-000000000004',
    nombre: 'Cuidadora de ejemplo',
    correo: 'cuidador@ejemplo.mx',
  ),
  Rol.casa: Persona(
    id: '00000000-0000-4000-8000-000000000005',
    nombre: 'Casa',
    correo: 'casa@ejemplo.mx',
  ),
};

/// Hogar de ejemplo.
const hogarDeEjemplo = '00000000-0000-4000-8000-0000000000aa';

/// Sesión de ejemplo para [rol].
Sesion sesionDeEjemplo(Rol rol) =>
    Sesion(persona: personasDeEjemplo[rol]!, rol: rol, hogarId: hogarDeEjemplo);

/// Rol de ejemplo según el correo: `cuidador@...` entra como Cuidador,
/// `familiar@...` como Familiar, etc. Cualquier otro correo entra como Dueño.
Rol rolPorCorreoDeEjemplo(String correo) {
  final usuario = correo.split('@').first.trim().toLowerCase();
  if (usuario == 'pareja') return Rol.coadministrador;
  for (final rol in Rol.values) {
    if (rol.name == usuario) return rol;
  }
  return Rol.dueno;
}

class ServicioSesionDemostracion extends ServicioSesionEnMemoria
    implements EntradaDeDemostracion {
  ServicioSesionDemostracion({super.inicial});

  @override
  bool get esDemostracion => true;

  @override
  List<Rol> get rolesDisponibles => Rol.values;

  @override
  Future<Sesion> entrarComo(Rol rol) async {
    final sesion = sesionDeEjemplo(rol);
    emitir(sesion);
    return sesion;
  }

  @override
  Future<Sesion> entrar({
    required String correo,
    required String contrasena,
  }) async {
    final sesion = await verificarCredenciales(
      correo: correo,
      contrasena: contrasena,
    );
    emitir(sesion);
    return sesion;
  }

  @override
  Future<Sesion> verificarCredenciales({
    required String correo,
    required String contrasena,
  }) async {
    if (correo.trim().isEmpty || contrasena.isEmpty) {
      throw ErrorSesion.credencialesIncorrectas;
    }
    return sesionDeEjemplo(rolPorCorreoDeEjemplo(correo));
  }
}
