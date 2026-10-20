/// Quién está usando la app **ahora**: en el teléfono y la laptop, la persona
/// de la sesión; en la tablet, la persona que entró con su PIN o, si nadie,
/// la cuenta Casa (modo Casa, D14).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../nucleo/contratos/dispositivo.dart';
import '../nucleo/contratos/roles.dart';
import '../nucleo/sesion/proveedores_sesion.dart';
import '../nucleo/sesion/sesion.dart';
import '../nucleo/tablet/controlador_tablet.dart';
import 'dispositivo.dart';

/// `true` si la tablet de la casa tiene abierta una cuenta que no es la de
/// rol Casa (D14; revisión de la Fase 0, I6). Entonces no se arma ninguna
/// interfaz: la pantalla de entrar pide la cuenta de la casa.
final tabletSinCuentaCasaProvider = Provider<bool>((ref) {
  if (ref.watch(tipoDispositivoProvider) != TipoDispositivo.tablet) {
    return false;
  }
  final sesion = ref.watch(sesionActualProvider);
  return sesion != null && sesion.rol != Rol.casa;
});

/// Sesión con la que se arma la interfaz (o `null` si nadie ha entrado).
final sesionEfectivaProvider = Provider<Sesion?>((ref) {
  final sesion = ref.watch(sesionActualProvider);
  if (sesion == null) return null;
  if (ref.watch(tipoDispositivoProvider) != TipoDispositivo.tablet) {
    return sesion;
  }
  // D14: el modo Casa usa la cuenta de rol Casa. Con otra cuenta, nada.
  if (ref.watch(tabletSinCuentaCasaProvider)) return null;
  final activo = ref.watch(
    controladorTabletProvider.select((estado) => estado.usuarioActivo),
  );
  return activo?.sesion ?? sesion;
});

/// Rol con el que se arma la interfaz (o `null` si nadie ha entrado).
final rolEfectivoProvider = Provider<Rol?>(
  (ref) => ref.watch(sesionEfectivaProvider)?.rol,
);
