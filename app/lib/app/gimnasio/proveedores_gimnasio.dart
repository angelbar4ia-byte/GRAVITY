/// Proveedores de «Mi gimnasio» para la app (Fase 8, G3). G5 los usa para
/// guardar, leer, programar el aviso del descanso y proteger las molestias.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../nucleo/cola/proveedores_cola.dart';
import '../../nucleo/gimnasio/molestias_locales.dart';
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
