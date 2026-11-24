/// Proveedores de «Mi gimnasio» para la app (Fase 8, G3). G5 los usa para
/// guardar, leer, programar el aviso del descanso y proteger las molestias.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../nucleo/cola/proveedores_cola.dart';
import '../../nucleo/gimnasio/molestias_locales.dart';
import '../../nucleo/gimnasio/pantalla_encendida.dart';
import '../../nucleo/tablet/retencion_sesion_gimnasio.dart';
import '../../nucleo/gimnasio/repositorio_gimnasio.dart';
import '../avisos/con_avisos.dart';
import '../sensibles/sensibles.dart';
import '../sesion_efectiva.dart';

export '../avisos/con_avisos.dart' show servicioAvisoDescansoProvider;
export '../../nucleo/avisos/aviso_descanso.dart' show ServicioAvisoDescanso;
export '../../nucleo/gimnasio/pantalla_encendida.dart'
    show PantallaEncendida, pantallaEncendidaProvider;
export '../../nucleo/tablet/retencion_sesion_gimnasio.dart'
    show
        retencionSesionGimnasio,
        sesionGimnasioEnCursoProvider,
        tiempoSinUsoDeLaTablet;

/// Tablas locales y cola de «Mi gimnasio»: **local primero**; cada cambio se
/// encola con los tipos `habitos.gim_*`.
final repositorioGimnasioProvider = Provider<RepositorioGimnasio>(
  (ref) => RepositorioGimnasio(
    ref.watch(baseLocalProvider),
    cola: ref.watch(colaSinConexionProvider),
  ),
);

/// Las molestias de quien está en pantalla, **solo en este equipo**; `null` si
/// nadie ha entrado. En la laptop y en la tablet pública no las guarda ni las
/// muestra (`equipoAdmiteMolestias`).
final molestiasLocalesProvider = Provider<MolestiasLocales?>((ref) {
  final persona = ref.watch(sesionEfectivaProvider)?.persona.id;
  if (persona == null) return null;
  final equipo = ref.watch(tipoEquipoAvisosProvider);
  return MolestiasLocales(
    llaves: ref.watch(llavesHabitosProvider),
    sobres: ref.watch(almacenDeSobresProvider),
    modos: ref.watch(modosLocalesProvider),
    persona: persona,
    equipoLasAdmite: () => equipoAdmiteMolestias(equipo),
  );
});

/// Id de la persona cuya interfaz está en pantalla (`null`: nadie). Solo avisa
/// cuando cambia la persona, no cuando se renueva su sesión.
final personaEnPantallaProvider = Provider<String?>(
  (ref) => ref.watch(sesionEfectivaProvider)?.persona.id,
);

/// `true` si hay una sesión de gimnasio en curso **de la persona que está en
/// pantalla**. Si la persona cambió (otra entró con su PIN), la sesión de la
/// anterior ya no cuenta.
final sesionDeGimnasioALaVistaProvider = Provider<bool>((ref) {
  final enCurso = ref.watch(sesionGimnasioEnCursoProvider);
  final persona = ref.watch(personaEnPantallaProvider);
  return enCurso != null && enCurso == persona;
});

/// Mantiene la pantalla encendida mientras haya una sesión de gimnasio en curso
/// de quien está en pantalla (H-14, spec 22). Devuelve `true` mientras la tiene
/// pedida.
///
/// **Sin cableado en la pantalla:** `AppGravity` lo mantiene vivo; la pantalla
/// de la sesión (G5) solo tiene que llamar a
/// `ref.read(sesionGimnasioEnCursoProvider.notifier).iniciar(persona)` al
/// empezar **o retomar** la sesión y a `.terminar()` al terminar, salir o
/// descartar (lo mismo que ya pide la retención de la tablet, PG-17). Se suelta
/// sola al terminar, al cambiar de persona, al volver la tablet al reposo y al
/// ir la app a segundo plano (lo hace [PantallaEncendidaAndroid]). La sesión
/// guarda igual si la pantalla no se pudo mantener encendida.
final pantallaEncendidaDeLaSesionProvider = Provider<bool>((ref) {
  if (!ref.watch(sesionDeGimnasioALaVistaProvider)) return false;
  final soltar = ref.read(pantallaEncendidaProvider).pedir();
  ref.onDispose(soltar);
  return true;
});
