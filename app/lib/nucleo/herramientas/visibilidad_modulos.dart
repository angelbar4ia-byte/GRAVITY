/// Qué módulos y qué herramientas se ofrecen a cada rol en GRAVITY.
///
/// Usa el espejo de la matriz de permisos de la plataforma
/// (`nucleo/permisos/permisos.dart`). Solo sirve para no ofrecer lo que el
/// rol no ve: la verdad de los permisos está en el servidor (RLS).
library;

import '../contratos/roles.dart';
import '../permisos/permisos.dart';

/// Decide si un módulo se ofrece en la interfaz.
typedef PuedeVerModulo = bool Function(Modulo modulo);

/// `true` si [rol] abre las pantallas de [modulo] desde la navegación.
bool puedeVerModuloPorDefecto(Rol rol, Modulo modulo) =>
    puedeAbrir(rol, modulo);

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

/// Roles que de GRAVITY solo usan su bandeja de solicitudes y recordatorios
/// (D18: la cuidadora). Se resuelve **por rol**, no con un alcance propio
/// (D17: solo hay `total`, `propio` y `restringido`; en el servidor, GRAVITY
/// del cuidador es `restringido`).
const Set<Rol> rolesSoloBandejaEnGravity = {Rol.cuidador};

/// `true` si de GRAVITY [rol] solo usa su bandeja de solicitudes y
/// recordatorios (D18: la cuidadora). A ese rol GRAVITY solo le ofrece
/// herramientas de la bandeja: nada de dinero, de la familia ni de
/// conversación libre.
///
/// Además de [rolesSoloBandejaEnGravity], por si la matriz cambia: cualquier
/// rol que tiene algo de GRAVITY pero no abre sus pantallas desde la
/// navegación (`accesoDirecto: false`) también queda solo con su bandeja.
bool soloBandejaEnGravity(Rol rol) =>
    rolesSoloBandejaEnGravity.contains(rol) ||
    (puede(rol, Modulo.gravity, Accion.leer) &&
        !permisoDe(rol, Modulo.gravity).accesoDirecto);

/// Roles a los que GRAVITY les ofrece abrir [modulo] (y, con [accion],
/// hacer eso en él): los que abren el módulo según la matriz y pueden hacer
/// [accion], menos quien en GRAVITY solo tiene su bandeja (D18).
Set<Rol> rolesParaNavegar(Modulo modulo, {Accion accion = Accion.leer}) =>
    Set.unmodifiable({
      for (final rol in Rol.values)
        if (puedeAbrir(rol, modulo) &&
            puede(rol, modulo, accion) &&
            !soloBandejaEnGravity(rol))
          rol,
    });

/// Roles que tienen bandeja de solicitudes y recordatorios en GRAVITY (D18):
/// los de solo bandeja que, según la matriz, leen GRAVITY (sus solicitudes)
/// y escriben en él (las confirman).
Set<Rol> rolesConBandeja() => Set.unmodifiable({
  for (final rol in Rol.values)
    if (soloBandejaEnGravity(rol) &&
        puede(rol, Modulo.gravity, Accion.leer) &&
        puede(rol, Modulo.gravity, Accion.escribir))
      rol,
});

/// `true` si [rol] puede ser la cuenta maestra del hogar (D19): solo un rol
/// con Finanzas propio o total (dueño o coadministrador), como exige el
/// servidor (`membresias.es_maestra` y `es_cuenta_maestra`).
bool puedeSerCuentaMaestra(Rol rol) {
  final permiso = permisoDe(rol, Modulo.finanzas);
  return (permiso.alcance == Alcance.propio ||
          permiso.alcance == Alcance.total) &&
      permiso.acciones.contains(Accion.leer);
}
