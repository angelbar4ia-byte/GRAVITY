/// Quién está usando la app **ahora**: en el teléfono y la laptop, la persona
/// de la sesión; en la tablet, la persona que entró con PIN o, si nadie, el
/// modo Casa (D14).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../nucleo/contratos/dispositivo.dart';
import '../nucleo/contratos/roles.dart';
import '../nucleo/sesion/proveedores_sesion.dart';
import '../nucleo/sesion/sesion.dart';
import '../nucleo/tablet/controlador_tablet.dart';
import 'dispositivo.dart';

/// Persona que representa al modo Casa en la tablet.
const personaModoCasa = Persona(id: 'modo-casa', nombre: 'Casa');

/// Sesión con la que se arma la interfaz (o `null` si nadie ha entrado).
final sesionEfectivaProvider = Provider<Sesion?>((ref) {
  final sesion = ref.watch(sesionActualProvider);
  if (sesion == null) return null;
  if (ref.watch(tipoDispositivoProvider) != TipoDispositivo.tablet) {
    return sesion;
  }
  final activo = ref.watch(
    controladorTabletProvider.select((estado) => estado.usuarioActivo),
  );
  return activo?.sesion ??
      Sesion(persona: personaModoCasa, rol: Rol.casa, hogarId: sesion.hogarId);
});

/// Rol con el que se arma la interfaz (o `null` si nadie ha entrado).
final rolEfectivoProvider = Provider<Rol?>(
  (ref) => ref.watch(sesionEfectivaProvider)?.rol,
);
