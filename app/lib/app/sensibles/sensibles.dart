/// Datos sensibles de Hábitos en la app (Fase 3, D13, D21): quién puede tener
/// las llaves en este equipo y las piezas que usa el módulo de Hábitos.
///
/// - Teléfono: llaves en el almacén seguro (Keystore).
/// - **Tablet personal** y laptop: igual, pero cifradas con el PIN de la persona
///   y abiertas solo mientras está dentro (D21).
/// - **Tablet pública de la casa: nada**; no guarda llaves ni sobres.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../nucleo/avisos/repositorio_avisos.dart';
import '../../nucleo/cola/proveedores_cola.dart';
import '../../nucleo/seguridad/proveedores_seguridad.dart';
import '../../nucleo/sensibles/llaves_habitos.dart';
import '../../nucleo/sensibles/mis_datos.dart';
import '../../nucleo/sensibles/sobres.dart';
import '../../nucleo/sensibles/subida_diferida.dart';
import '../avisos/con_avisos.dart';

/// ¿Este equipo puede guardar las llaves de Hábitos?
bool equipoPuedeTenerLlaves(TipoEquipoAvisos tipo) =>
    tipo != TipoEquipoAvisos.tabletPublica;

/// ¿Van cifradas con el PIN de la persona?
bool llavesVanConPin(TipoEquipoAvisos tipo) =>
    tipo == TipoEquipoAvisos.tabletPersonal || tipo == TipoEquipoAvisos.laptop;

final llavesHabitosProvider = Provider<LlavesHabitos>((ref) {
  final tipo = ref.watch(tipoEquipoAvisosProvider);
  final llaves = LlavesHabitos(
    ref.watch(almacenSeguroProvider),
    permitido: () => equipoPuedeTenerLlaves(ref.read(tipoEquipoAvisosProvider)),
    protegidaConPin: llavesVanConPin(tipo),
  );
  ref.onDispose(llaves.olvidarEnMemoria);
  return llaves;
});

final almacenDeSobresProvider = Provider<AlmacenDeSobres>(
  (ref) => AlmacenDeSobres(ref.watch(almacenSeguroProvider)),
);

final modosLocalesProvider = Provider<ModosLocales>(
  (ref) => ModosLocales(ref.watch(almacenSeguroProvider)),
);

/// Hábitos lo sustituye con su implementación (descifra en memoria).
final fuenteDeDatosHabitosProvider = Provider<FuenteDeDatosHabitos?>(
  (ref) => null,
);

final nubeDeHabitosProvider = Provider<NubeDeHabitos?>((ref) => null);

final subidaDiferidaProvider = Provider<SubidaDiferidaDeSobres>(
  (ref) => SubidaDiferidaDeSobres(
    sobres: ref.watch(almacenDeSobresProvider),
    modos: ref.watch(modosLocalesProvider),
    cola: ref.watch(colaSinConexionProvider),
    almacen: ref.watch(almacenSeguroProvider),
  ),
);

final borradoDeMisDatosProvider = Provider<BorradoDeMisDatos>(
  (ref) => BorradoDeMisDatos(
    sobres: ref.watch(almacenDeSobresProvider),
    llaves: ref.watch(llavesHabitosProvider),
    modos: ref.watch(modosLocalesProvider),
    almacen: ref.watch(almacenSeguroProvider),
    nube: ref.watch(nubeDeHabitosProvider),
    cola: ref.watch(colaSinConexionProvider),
  ),
);

