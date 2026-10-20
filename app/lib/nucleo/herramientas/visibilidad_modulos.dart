/// Qué módulos se ofrecen a cada rol en GRAVITY.
///
/// Usa el espejo de la matriz de permisos de la plataforma
/// (`nucleo/permisos/permisos.dart`, sección 5 de la especificación de la
/// Fase 0). Solo sirve para no ofrecer lo que el rol no ve: la verdad de los
/// permisos está en el servidor (RLS).
library;

import '../contratos/roles.dart';
import '../permisos/permisos.dart';

/// Decide si un módulo se ofrece en la interfaz.
typedef PuedeVerModulo = bool Function(Modulo modulo);

/// `true` si [rol] abre las pantallas de [modulo] desde la navegación.
bool puedeVerModuloPorDefecto(Rol rol, Modulo modulo) => puedeAbrir(rol, modulo);

/// La función por defecto para un rol.
PuedeVerModulo puedeVerPorDefecto(Rol rol) =>
    (modulo) => puedeVerModuloPorDefecto(rol, modulo);

/// Roles que abren [modulo] según la matriz.
Set<Rol> rolesQueVen(Modulo modulo) => Set.unmodifiable({
  for (final rol in Rol.values)
    if (puedeVerModuloPorDefecto(rol, modulo)) rol,
});

/// Roles que administran [modulo] (en Ajustes, solo el Dueño).
Set<Rol> rolesQueAdministran(Modulo modulo) => Set.unmodifiable({
  for (final rol in Rol.values)
    if (puede(rol, modulo, Accion.administrar)) rol,
});
