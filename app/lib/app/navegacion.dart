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

  /// D24: el familiar pide ver las finanzas de Papá. Única ruta de Finanzas
  /// que el router deja abrir al familiar, y solo la pantalla de pedir.
  static const vistaPapa = '${Rutas.finanzas}/vista-papa';
  static const cuidadosMedicamentos = '${Rutas.cuidados}/medicamentos';
  static const cuidadosComidas = '${Rutas.cuidados}/comidas';
  static const cuidadosBitacora = '${Rutas.cuidados}/bitacora';

  /// Fase 5 (8f): instrucciones para la cuidadora principal.
  static const cuidadosInstrucciones = '${Rutas.cuidados}/instrucciones';

  /// Fase 5: consentimiento de la pareja y autorización de la hermana.
  static const cuidadosConsentimientos = '${Rutas.cuidados}/consentimientos';

  /// "Tengo una invitación": registro y aceptación del código del dueño (E3,
  /// Fase 4). Se abre **sin sesión**; con sesión, lleva al inicio.
  static const invitacion = '/invitacion';

  /// Registros que el servidor no aceptó y requieren atención (I4).
  static const pendientes = '/pendientes';

  /// Bandeja de solicitudes y recordatorios de GRAVITY (D18: la cuidadora
  /// los confirma; no conversa con GRAVITY).
  static const solicitudes = '/solicitudes';

  /// Bandeja de avisos de Finanzas (Fase 2, D20): solo para quien ve dinero y
  /// no es la cuenta maestra.
  static const avisos = '/avisos';
}

/// Pantallas de Hábitos que son **sección reservada** (Fase 3, regla 100): el
/// panel de hábitos a eliminar, el SOS, el registro de consumo, el diario de
/// oración, el devocional escrito, las notas y *Mis datos*. Son el primer
/// segmento de la ruta bajo `/habitos/`: Hábitos las monta con esos nombres.
/// Piden PIN o huella, se abren con FLAG_SECURE y la tablet pública no las
/// muestra nunca.
const segmentosReservadosDeHabitos = {
  'reservado',
  'eliminar',
  'sos',
  'consumo',
  'diario',
  'oracion',
  'devocional',
  'notas',
  'mis-datos',
};

/// `true` si [ubicacion] es una pantalla reservada de Hábitos.
bool esRutaReservadaDeHabitos(String ubicacion) {
  final base = '${Rutas.habitos}/';
  if (!ubicacion.startsWith(base)) return false;
  final primero = ubicacion.substring(base.length).split('/').first;
  return segmentosReservadosDeHabitos.contains(primero);
}

/// Quién abre `/cuidados/instrucciones` (8f). El guardia no conoce el perfil de
/// Cuidados (lo dice el servidor, `cui_perfil`): deja pasar a los **roles** que
/// pueden tener un perfil con acceso y la **pantalla** decide qué ve cada
/// perfil (`PermisosCuidados`): dueño y pareja (coadministrador, con o sin
/// consentimiento) y la hermana (cuidador) dejan instrucciones; la cuidadora
/// principal (cuidador) las ve en solo lectura. Casa y la cuenta maestra no
/// entran.
bool puedeAbrirInstrucciones(Rol rol, {bool esMaestra = false}) =>
    !esMaestra &&
    (rol == Rol.dueno || rol == Rol.coadministrador || rol == Rol.cuidador);

/// Quién abre `/cuidados/consentimientos`: la pareja (coadministrador) da o
/// retira el suyo y el dueño ve el estado. La cuenta maestra que no es la
/// dueña (solo lectura total, D19) no entra.
bool puedeAbrirConsentimientos(Rol rol, {bool esMaestra = false}) =>
    !esSoloLectura(rol, esMaestra: esMaestra) &&
    (rol == Rol.dueno || rol == Rol.coadministrador);

/// Accesos "Instrucciones" y "Consentimientos" de Más (teléfono y tablet) y
/// de la franja de la laptop: los ven el dueño y la pareja. La hermana y la
/// cuidadora (cuidador) llegan a Instrucciones desde su turno, no desde aquí.
bool veAccesoInstrucciones(Rol rol, {bool esMaestra = false}) =>
    puedeAbrirInstrucciones(rol, esMaestra: esMaestra) && rol != Rol.cuidador;

/// Ver [veAccesoInstrucciones].
bool veAccesoConsentimientos(Rol rol, {bool esMaestra = false}) =>
    puedeAbrirConsentimientos(rol, esMaestra: esMaestra);

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

/// Pestañas de [rol], ya filtradas con el espejo de permisos. La cuenta
/// maestra que no es la dueña ([esMaestra]) no tiene el botón (+).
List<Destino> destinosDe(Rol rol, {bool esMaestra = false}) => [
  for (final destino in pestanasPorRol[rol] ?? const <Destino>[])
    if (destino.esRegistrar
        ? opcionesRegistrar(rol, esMaestra: esMaestra).isNotEmpty
        : (destino.modulo == null || puedeAbrir(rol, destino.modulo!)) &&
              // La cuenta maestra no tiene Hábitos (hab_activa).
              (destino.modulo != Modulo.habitos ||
                  puedeUsarHabitos(rol, esMaestra: esMaestra)) &&
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
///
/// La cuenta maestra que no es la dueña ([esMaestra], D19) es de solo lectura
/// total: no registra nada.
bool puedeRegistrarEn(Rol rol, Modulo modulo, {bool esMaestra = false}) =>
    puedeAbrir(rol, modulo) &&
    puedeConSesion(rol, modulo, Accion.escribir, esMaestra: esMaestra);

/// Opciones de (+) que puede usar [rol] (escribir en el módulo).
List<OpcionRegistrar> opcionesRegistrar(Rol rol, {bool esMaestra = false}) => [
  for (final opcion in opcionesDeRegistro)
    if (puedeRegistrarEn(rol, opcion.modulo, esMaestra: esMaestra)) opcion,
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
  if (rol == null) {
    return ubicacion == Rutas.entrar || ubicacion == RutasApp.invitacion
        ? null
        : Rutas.entrar;
  }
  final inicio = inicioDe(rol);
  if (ubicacion == Rutas.entrar || ubicacion == RutasApp.invitacion) {
    return inicio;
  }
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
  if (ubicacion == RutasApp.avisos ||
      ubicacion.startsWith('${RutasApp.avisos}/')) {
    // La maestra nunca recibe avisos de dinero (regla 41); familiar, cuidador
    // y Casa tampoco ven nada de Finanzas.
    return puedeAbrir(rol, Modulo.finanzas) && !esMaestra ? null : inicio;
  }
  // D24 (excepción estrecha): solo el familiar, solo esta ruta exacta. La
  // matriz de permisos no cambia: los datos los entrega el servidor (RLS)
  // solo durante una vista autorizada.
  if (rol == Rol.familiar && ubicacion == RutasApp.vistaPapa) return null;
  // Fase 5 (excepción estrecha, solo estas dos rutas exactas): la pareja
  // (coadministrador) no abre Cuidados sin consentimiento
  // (dependeDelConsentimiento), pero siempre puede dejar instrucciones y dar o
  // retirar su consentimiento. No se abre nada más de Cuidados: la bitácora,
  // las entregas y lo clínico siguen bloqueados. Casa y la cuenta maestra se
  // devuelven al inicio aunque Casa abra Cuidados (recordatorios genéricos).
  // Los datos los protege el servidor (RLS).
  if (ubicacion == RutasApp.cuidadosInstrucciones) {
    return puedeAbrirInstrucciones(rol, esMaestra: esMaestra) ? null : inicio;
  }
  if (ubicacion == RutasApp.cuidadosConsentimientos) {
    return puedeAbrirConsentimientos(rol, esMaestra: esMaestra) ? null : inicio;
  }
  final modulo = moduloDeRuta(ubicacion);
  if (modulo != null && !puedeAbrir(rol, modulo)) return inicio;
  if (modulo == Modulo.habitos) {
    // La cuenta maestra no entra a Hábitos (hab_activa); la tablet pública no
    // muestra nunca lo reservado, ni siquiera durante una acción con PIN.
    if (!puedeUsarHabitos(rol, esMaestra: esMaestra)) return inicio;
    if (enAccionDeTabletCasa && esRutaReservadaDeHabitos(ubicacion)) {
      return Rutas.habitos;
    }
  }
  if (modulo != null &&
      accion != null &&
      !puedeConSesion(rol, modulo, accion, esMaestra: esMaestra)) {
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
