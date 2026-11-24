/// Estado de «Mi gimnasio» con Riverpod: el servicio de la persona que está en
/// pantalla, los datos del equipo y el entrenamiento de hoy.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;
import 'package:habitos_dominio/habitos_dominio.dart' show lunesDe;

import '../../../../app/gimnasio/proveedores_gimnasio.dart';
import '../../../../app/sesion_efectiva.dart';
import '../../../../diseno/proveedores.dart' show relojProvider;
import '../../../../nucleo/cola/proveedores_cola.dart'
    show colaSinConexionProvider;
import '../../../../nucleo/seguridad/proveedores_seguridad.dart'
    show almacenSeguroProvider;
import '../../../../nucleo/sensibles/llaves_habitos.dart'
    show LlaveBloqueada, LlaveNoPermitida;
import '../../../../nucleo/sesion/proveedores_sesion.dart';
import '../../../../nucleo/sesion/servicio_sesion_supabase.dart';
import '../../casos_uso/servicio_eliminar.dart';
import '../../estado/proveedores.dart';
import '../casos_uso/aviso_banco.dart';
import '../casos_uso/modo_foco.dart';
import '../casos_uso/servicio_gimnasio.dart';
import '../datos/lector_gimnasio.dart';
import '../datos/modelos_gimnasio.dart';

/// Para volver a pedir los datos del gimnasio tras cada cambio.
final versionGimnasioProvider = StateProvider<int>((_) => 0);

/// El lector del servidor: el cliente activo de Supabase; sin sesión real
/// (demostración, pruebas), no hay nada que bajar.
final lectorGimnasioProvider = Provider<LectorGimnasio>((ref) {
  final sesion = ref.watch(sesionEfectivaProvider);
  final servicio = ref.watch(servicioSesionProvider);
  if (sesion != null && servicio is ServicioSesionSupabase) {
    return LectorGimnasioSupabase(() => servicio.clienteActivo);
  }
  return const LectorGimnasioNulo();
});

/// La copia local de los rangos de foco de quien está en pantalla (no se sube).
final copiaFocoProvider = Provider<CopiaLocalFoco?>((ref) {
  final persona = ref.watch(personaEnPantallaProvider);
  return persona == null
      ? null
      : CopiaLocalFoco(ref.watch(almacenSeguroProvider), persona);
});

/// Lo que este equipo sabe del aviso del banco de quien está en pantalla (solo
/// en este equipo; `null` si nadie ha entrado).
final avisoBancoLocalProvider = Provider<AvisoBancoLocal?>((ref) {
  final persona = ref.watch(personaEnPantallaProvider);
  return persona == null
      ? null
      : AvisoBancoLocal(ref.watch(almacenSeguroProvider), persona);
});

/// ¿La persona ya confirmó que revisó el banco? Sin persona, se da por visto
/// (no hay nada que mostrar).
final avisoBancoRevisadoProvider = FutureProvider<bool>((ref) async {
  final local = ref.watch(avisoBancoLocalProvider);
  return local == null ? true : await local.revisado();
});

/// El modo foco (8.3): sin causa. Con la copia local lo sabe sin abrir lo
/// reservado; sin copia lo intenta una vez y, si no hay llave en este equipo,
/// dice que no se pudo leer y vale `false`.
final modoFocoActivoProvider = FutureProvider<ModoFocoActivo>((ref) async {
  ref.watch(versionHabitosProvider);
  final copia = ref.watch(copiaFocoProvider);
  if (copia == null) return const SinModoFoco();
  final guardada = await copia.leer();
  if (guardada != null) return guardada;
  final eliminar = ref.watch(servicioEliminarProvider);
  if (eliminar == null) return const SinModoFoco(legible: false);
  try {
    final c = await eliminar.config(TipoHabito.cigarrillo);
    if (c == null) {
      await copia.marcarLeido();
    } else {
      await copia.registrar(
        claveAnonimaDeFoco,
        diaD: c.plan.diaD,
        focoDias: c.plan.focoDias,
      );
    }
    return await copia.leer() ?? const SinModoFoco();
  } on LlaveBloqueada {
    return const SinModoFoco(legible: false);
  } on LlaveNoPermitida {
    return const SinModoFoco(legible: false);
  } catch (_) {
    return const SinModoFoco(legible: false);
  }
});

/// El servicio de la persona que está en pantalla (`null` si nadie entró).
final servicioGimnasioProvider = Provider<ServicioGimnasio?>((ref) {
  final persona = ref.watch(personaEnPantallaProvider);
  if (persona == null) return null;
  final agenda = ref.watch(repositorioAgendaProvider);
  return ServicioGimnasio(
    repo: ref.watch(repositorioGimnasioProvider),
    persona: persona,
    agenda: agenda,
    registros: ref.watch(repositorioHabitosProvider),
    molestias: ref.watch(molestiasLocalesProvider),
    // Sin señal, lo que no se pueda escribir en Hábitos queda en la cola.
    cola: ref.watch(colaSinConexionProvider),
    lector: ref.watch(lectorGimnasioProvider),
    foco: () => ref.read(modoFocoActivoProvider.future),
    ahora: ref.watch(relojProvider).ahora,
  );
});

/// Baja una vez del servidor lo de la persona (último cambio gana). `false`
/// sin conexión: la app sigue con lo local.
final bajadaGimnasioProvider = FutureProvider<bool>((ref) async {
  final s = ref.watch(servicioGimnasioProvider);
  if (s == null) return false;
  final ok = await s.bajarDelServidor();
  if (ok) ref.read(versionGimnasioProvider.notifier).state++;
  return ok;
});

final datosGimnasioProvider = FutureProvider<DatosGimnasio?>((ref) {
  ref.watch(versionGimnasioProvider);
  return ref.watch(servicioGimnasioProvider)?.cargar();
});

/// Lo que toca hoy (o el día [fecha]) con el equipo y las molestias de este
/// equipo.
final entrenamientoDeProvider =
    FutureProvider.family<EntrenamientoHoy?, DateTime>((ref, fecha) async {
      ref.watch(versionGimnasioProvider);
      ref.watch(versionHabitosProvider);
      final s = ref.watch(servicioGimnasioProvider);
      if (s == null) return null;
      return s.entrenamientoDe(fecha);
    });

/// El día de hoy según el reloj de la app.
final fechaDeHoyGimnasioProvider = Provider<DateTime>((ref) {
  final ahora = ref.watch(relojProvider).ahora();
  return DateTime.utc(ahora.year, ahora.month, ahora.day);
});

/// Lo de hoy, para Hoy y E1.
final entrenamientoHoyProvider = FutureProvider<EntrenamientoHoy?>((ref) {
  final f = ref.watch(fechaDeHoyGimnasioProvider);
  return ref.watch(entrenamientoDeProvider(f).future);
});

/// Cuántos elementos de entrenamiento hay hoy y cuántos están hechos (para
/// `habitos.resumen_hoy`: solo el conteo, sin cargas ni molestias).
final conteoGimnasioHoyProvider = FutureProvider<({int total, int hechos})>((
  ref,
) async {
  ref.watch(versionGimnasioProvider);
  ref.watch(versionHabitosProvider);
  final s = ref.watch(servicioGimnasioProvider);
  if (s == null) return (total: 0, hechos: 0);
  try {
    return await s.conteoDeHoy();
  } catch (_) {
    return (total: 0, hechos: 0);
  }
});

/// El id del objetivo «Entrenamiento» de quien está en pantalla: Hoy lo muestra
/// con la tarjeta de entrenamiento, no como un hábito más.
final idObjetivoEntrenamientoProvider = Provider<String?>((ref) {
  final p = ref.watch(personaEnPantallaProvider);
  return p == null ? null : idObjetivoEntrenamiento(p);
});

/// El lunes de esta semana (para el plan).
final lunesDeEstaSemanaProvider = Provider<DateTime>(
  (ref) => lunesDe(ref.watch(fechaDeHoyGimnasioProvider)),
);
