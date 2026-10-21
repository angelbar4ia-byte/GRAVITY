/// Navegación por rol (`DISENO_UX_UI.md`, secciones 9, 11 y 13): pestañas del
/// teléfono, opciones de (+), contenido de "Más" y redirecciones del router.
/// Todo es puro (sin widgets) para probarlo fácil.
library;

import 'package:flutter/material.dart';

import '../modulos/ajustes/secciones_ajustes.dart';
import '../nucleo/contratos/dispositivo.dart';
import '../nucleo/contratos/roles.dart';
import '../nucleo/contratos/rutas.dart';
import '../nucleo/permisos/permisos.dart';

/// Rutas propias de la plataforma (además de las del contrato `Rutas`).
abstract final class RutasApp {
  static const mas = '/mas';
  static const cuidadosMedicamentos = '${Rutas.cuidados}/medicamentos';
  static const cuidadosComidas = '${Rutas.cuidados}/comidas';
  static const cuidadosBitacora = '${Rutas.cuidados}/bitacora';

  /// Registros que el servidor no aceptó y requieren atención (I4).
  static const pendientes = '/pendientes';

  /// Bandeja de solicitudes y recordatorios de GRAVITY (D18: la cuidadora
  /// los confirma; no conversa con GRAVITY).
  static const solicitudes = '/solicitudes';
}

/// Una pestaña de la barra inferior (teléfono) o del riel lateral (tablet).
class Destino {
  const Destino({
    required this.etiqueta,
    required this.icono,
    this.ruta,
    this.modulo,
    this.requiereLeer,
    this.esRegistrar = false,
  });

  final String etiqueta;
  final IconData icono;

  /// Ruta que abre; `null` en el botón (+).
  final String? ruta;

  /// Módulo que exige la pestaña (se filtra con los permisos).
  final Modulo? modulo;

  /// Módulo que la pestaña solo exige **leer** (sin abrir sus pantallas):
  /// p. ej. la bandeja de solicitudes de GRAVITY de la cuidadora.
  final Modulo? requiereLeer;

  /// `true` en el botón (+), que abre la hoja de registro.
  final bool esRegistrar;
}

const _hoy = Destino(
  etiqueta: 'Hoy',
  icono: Icons.today_outlined,
  ruta: Rutas.inicio,
  modulo: Modulo.gravity,
);
const _finanzas = Destino(
  etiqueta: 'Finanzas',
  icono: Icons.account_balance_wallet_outlined,
  ruta: Rutas.finanzas,
  modulo: Modulo.finanzas,
);
const _registrar = Destino(
  etiqueta: 'Registrar',
  icono: Icons.add_circle,
  esRegistrar: true,
);
const _habitos = Destino(
  etiqueta: 'Hábitos',
  icono: Icons.check_circle_outline,
  ruta: Rutas.habitos,
  modulo: Modulo.habitos,
);
const _alimentacion = Destino(
  etiqueta: 'Alimentación',
  icono: Icons.restaurant_menu_outlined,
  ruta: Rutas.alimentacion,
  modulo: Modulo.alimentacion,
);
const _mas = Destino(
  etiqueta: 'Más',
  icono: Icons.more_horiz,
  ruta: RutasApp.mas,
);

/// Pestañas declaradas por rol (sección 9). Se filtran con [destinosDe].
const Map<Rol, List<Destino>> pestanasPorRol = {
  Rol.dueno: [_hoy, _finanzas, _registrar, _habitos, _mas],
  Rol.coadministrador: [_hoy, _finanzas, _registrar, _habitos, _mas],
  Rol.cuidador: [
    Destino(
      etiqueta: 'Mi turno',
      icono: Icons.assignment_ind_outlined,
      ruta: Rutas.cuidados,
      modulo: Modulo.cuidados,
    ),
    Destino(
      etiqueta: 'Solicitudes',
      icono: Icons.inbox_outlined,
      ruta: RutasApp.solicitudes,
      requiereLeer: Modulo.gravity,
    ),
    Destino(
      etiqueta: 'Medicamentos',
      icono: Icons.medication_outlined,
      ruta: RutasApp.cuidadosMedicamentos,
      modulo: Modulo.cuidados,
    ),
    Destino(
      etiqueta: 'Comidas',
      icono: Icons.restaurant_outlined,
      ruta: RutasApp.cuidadosComidas,
      modulo: Modulo.cuidados,
    ),
    Destino(
      etiqueta: 'Bitácora',
      icono: Icons.menu_book_outlined,
      ruta: RutasApp.cuidadosBitacora,
      modulo: Modulo.cuidados,
    ),
  ],
  Rol.familiar: [_hoy, _habitos, _mas],
  Rol.casa: [_hoy, _alimentacion, _mas],
};

/// Pestañas de [rol], ya filtradas con el espejo de permisos.
List<Destino> destinosDe(Rol rol) => [
  for (final destino in pestanasPorRol[rol] ?? const <Destino>[])
    if (destino.esRegistrar
        ? opcionesRegistrar(rol).isNotEmpty
        : (destino.modulo == null || puedeAbrir(rol, destino.modulo!)) &&
              (destino.requiereLeer == null ||
                  puede(rol, destino.requiereLeer!, Accion.leer)))
      destino,
];

/// Índice de la pestaña que corresponde a [ubicacion] (la ruta más larga que
/// coincide). Lo que no está en una pestaña cae en "Más", si existe.
int? indiceDestino(String ubicacion, List<Destino> destinos) {
  int? mejor;
  var largo = -1;
  for (var i = 0; i < destinos.length; i++) {
    final ruta = destinos[i].ruta;
    if (ruta == null) continue;
    final coincide = ruta == Rutas.inicio
        ? ubicacion == Rutas.inicio
        : ubicacion == ruta || ubicacion.startsWith('$ruta/');
    if (coincide && ruta.length > largo) {
      mejor = i;
      largo = ruta.length;
    }
  }
  if (mejor != null) return mejor;
  final mas = destinos.indexWhere((d) => d.ruta == RutasApp.mas);
  return mas >= 0 ? mas : null;
}

/// Qué registra cada opción del botón (+).
enum TipoRegistro { gasto, ingresoExtra, habito, consumo, sos }

/// Una opción del botón (+) (sección 9).
class OpcionRegistrar {
  const OpcionRegistrar({
    required this.tipo,
    required this.etiqueta,
    required this.icono,
    required this.modulo,
    required this.fase,
  });

  final TipoRegistro tipo;
  final String etiqueta;
  final IconData icono;
  final Modulo modulo;

  /// Fase en la que llega.
  final int fase;
}

const List<OpcionRegistrar> opcionesDeRegistro = [
  OpcionRegistrar(
    tipo: TipoRegistro.gasto,
    etiqueta: 'Gasto',
    icono: Icons.payments_outlined,
    modulo: Modulo.finanzas,
    fase: 1,
  ),
  OpcionRegistrar(
    tipo: TipoRegistro.ingresoExtra,
    etiqueta: 'Ingreso extra',
    icono: Icons.savings_outlined,
    modulo: Modulo.finanzas,
    fase: 1,
  ),
  OpcionRegistrar(
    tipo: TipoRegistro.habito,
    etiqueta: 'Hábito',
    icono: Icons.check_circle_outline,
    modulo: Modulo.habitos,
    fase: 3,
  ),
  OpcionRegistrar(
    tipo: TipoRegistro.consumo,
    etiqueta: 'Consumo (cigarrillo o azúcar)',
    icono: Icons.smoke_free,
    modulo: Modulo.habitos,
    fase: 3,
  ),
  OpcionRegistrar(
    tipo: TipoRegistro.sos,
    etiqueta: 'SOS: tengo un antojo',
    icono: Icons.sos_outlined,
    modulo: Modulo.habitos,
    fase: 3,
  ),
];

/// `true` si [rol] registra en [modulo] desde la navegación (el (+) del
/// teléfono y de la tablet, Ctrl + N en la laptop): lo abre y puede escribir.
bool puedeRegistrarEn(Rol rol, Modulo modulo) =>
    puedeAbrir(rol, modulo) && puede(rol, modulo, Accion.escribir);

/// Opciones de (+) que puede usar [rol] (escribir en el módulo).
List<OpcionRegistrar> opcionesRegistrar(Rol rol) => [
  for (final opcion in opcionesDeRegistro)
    if (puedeRegistrarEn(rol, opcion.modulo)) opcion,
];

/// Módulos que van en "Más": los navegables que no tienen pestaña propia.
List<Modulo> modulosEnMas(Rol rol) {
  final conPestana = {
    for (final d in destinosDe(rol))
      if (d.modulo != null) d.modulo!,
  };
  return [
    for (final modulo in modulosNavegables(rol))
      if (!conPestana.contains(modulo)) modulo,
  ];
}

/// Ruta de cada módulo.
String rutaDeModulo(Modulo modulo) => switch (modulo) {
  Modulo.gravity => Rutas.inicio,
  Modulo.finanzas => Rutas.finanzas,
  Modulo.habitos => Rutas.habitos,
  Modulo.cuidados => Rutas.cuidados,
  Modulo.alimentacion => Rutas.alimentacion,
  Modulo.casa => Rutas.casa,
  Modulo.ajustes => Rutas.ajustes,
};

/// Icono de cada módulo.
IconData iconoDeModulo(Modulo modulo) => switch (modulo) {
  Modulo.gravity => Icons.blur_circular,
  Modulo.finanzas => Icons.account_balance_wallet_outlined,
  Modulo.habitos => Icons.check_circle_outline,
  Modulo.cuidados => Icons.volunteer_activism_outlined,
  Modulo.alimentacion => Icons.restaurant_menu_outlined,
  Modulo.casa => Icons.home_outlined,
  Modulo.ajustes => Icons.settings_outlined,
};

/// Módulo al que pertenece [ubicacion] (`/` es GRAVITY), o `null`.
Modulo? moduloDeRuta(String ubicacion) {
  if (ubicacion == Rutas.inicio) return Modulo.gravity;
  for (final modulo in Modulo.values) {
    if (modulo == Modulo.gravity) continue;
    final ruta = rutaDeModulo(modulo);
    if (ubicacion == ruta || ubicacion.startsWith('$ruta/')) return modulo;
  }
  return null;
}

/// Pantalla de inicio de [rol]: la cuidadora entra directo a "Mi turno".
String inicioDe(Rol rol) => puedeAbrir(rol, Modulo.gravity)
    ? Rutas.inicio
    : rutaDeModulo(modulosNavegables(rol).firstOrNull ?? Modulo.ajustes);

/// Redirección del router (función pura). `null` = se queda donde está.
///
/// [accion] es la que exige la ruta además de leer su módulo (`metadata`
/// con `exigeAccion`): quien no puede hacerla vuelve al inicio del módulo.
/// [esMaestra]: la cuenta maestra (D19) no abre lo que administra el hogar
/// (personas, copias, dispositivos, desarrollador). [enAccionDeTabletCasa]:
/// en la tablet pública alguien entró solo para una acción y la pantalla
/// sigue en el modo Casa.
String? calcularRedireccion({
  required String ubicacion,
  required Rol? rol,
  required TipoDispositivo dispositivo,
  Accion? accion,
  bool esMaestra = false,
  bool enAccionDeTabletCasa = false,
}) {
  if (rol == null) return ubicacion == Rutas.entrar ? null : Rutas.entrar;
  final inicio = inicioDe(rol);
  if (ubicacion == Rutas.entrar) return inicio;
  if (ubicacion == Rutas.inicio) {
    if (enAccionDeTabletCasa) return null;
    return inicio == Rutas.inicio ? null : inicio;
  }
  if (ubicacion == RutasApp.mas) {
    return dispositivo == TipoDispositivo.laptop ? inicio : null;
  }
  if (ubicacion == RutasApp.solicitudes ||
      ubicacion.startsWith('${RutasApp.solicitudes}/')) {
    return puede(rol, Modulo.gravity, Accion.leer) ? null : inicio;
  }
  final modulo = moduloDeRuta(ubicacion);
  if (modulo != null && !puedeAbrir(rol, modulo)) return inicio;
  if (modulo != null && accion != null && !puede(rol, modulo, accion)) {
    final raiz = rutaDeModulo(modulo);
    if (ubicacion != raiz) return raiz;
    // La raíz del módulo no debe exigir más que leer; si lo hace, se evita
    // el ciclo de redirecciones.
    return inicio == raiz ? null : inicio;
  }
  final seccion = seccionDeRuta(ubicacion);
  if (seccion != null &&
      !seccionDisponible(seccion, rol, dispositivo, esMaestra: esMaestra)) {
    return Rutas.ajustes;
  }
  return null;
}
