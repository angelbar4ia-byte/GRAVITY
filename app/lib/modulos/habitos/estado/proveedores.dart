/// Estado de Hábitos con Riverpod: repositorio según la sesión y el servicio.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;

import '../../../app/sesion_efectiva.dart';
import '../../../diseno/proveedores.dart' show relojProvider;
import '../../../nucleo/sesion/proveedores_sesion.dart';
import '../../../nucleo/sesion/servicio_sesion_supabase.dart';
import '../../../app/sensibles/sensibles.dart';
import '../casos_uso/servicio_eliminar.dart';
import '../casos_uso/servicio_habitos.dart';
import '../casos_uso/servicio_agenda.dart';
import '../casos_uso/servicio_diario.dart';
import '../casos_uso/servicio_lectura.dart';
import '../casos_uso/servicio_progreso.dart';
import '../datos/modelos_agenda.dart';
import '../datos/biblia.dart';
import '../datos/documentos_sensibles.dart';
import '../datos/repositorio_agenda.dart';
import '../datos/repositorio.dart';

/// Repositorio de la persona que usa la app (en la tablet, la que entró con
/// su PIN). Sin sesión o en demostración: memoria.
final repositorioHabitosProvider = Provider<RepositorioHabitos>((ref) {
  final sesion = ref.watch(sesionEfectivaProvider);
  final servicio = ref.watch(servicioSesionProvider);
  if (sesion != null && servicio is ServicioSesionSupabase) {
    return RepositorioHabitosSupabase(() => servicio.clienteActivo);
  }
  return RepositorioHabitosEnMemoria();
});

final servicioHabitosProvider = Provider<ServicioHabitos>((ref) {
  final reloj = ref.watch(relojProvider);
  return ServicioHabitos(ref.watch(repositorioHabitosProvider), ahora: reloj.ahora);
});

/// Contador para volver a pedir Hoy tras cada cambio.
final versionHabitosProvider = StateProvider<int>((_) => 0);

final hoyHabitosProvider = FutureProvider<List<ItemHoy>>((ref) {
  ref.watch(versionHabitosProvider);
  return ref.watch(servicioHabitosProvider).hoyDe();
});

/// Documentos sensibles de la persona activa (llaves y sobres de plataforma).
final documentosSensiblesProvider = Provider<DocumentosSensibles?>((ref) {
  final sesion = ref.watch(sesionEfectivaProvider);
  if (sesion == null) return null;
  return DocumentosSensibles(
    llaves: ref.watch(llavesHabitosProvider),
    sobres: ref.watch(almacenDeSobresProvider),
    modos: ref.watch(modosLocalesProvider),
    persona: sesion.persona.id,
    ahora: ref.watch(relojProvider).ahora,
  );
});

final servicioEliminarProvider = Provider<ServicioHabitoEliminar?>((ref) {
  final d = ref.watch(documentosSensiblesProvider);
  return d == null ? null : ServicioHabitoEliminar(d, ahora: ref.watch(relojProvider).ahora);
});

final estadoEliminarProvider =
    FutureProvider.family<EstadoHabito?, TipoHabito>((ref, tipo) async {
  ref.watch(versionHabitosProvider);
  return ref.watch(servicioEliminarProvider)?.estado(tipo);
});

/// Agenda, ajustes, revisiones y planes de la persona activa.
final repositorioAgendaProvider = Provider<RepositorioAgenda>((ref) {
  final sesion = ref.watch(sesionEfectivaProvider);
  final servicio = ref.watch(servicioSesionProvider);
  if (sesion != null && servicio is ServicioSesionSupabase) {
    return RepositorioAgendaSupabase(() => servicio.clienteActivo);
  }
  return RepositorioAgendaEnMemoria();
});

final servicioAgendaProvider = Provider<ServicioAgenda>((ref) => ServicioAgenda(
      ref.watch(repositorioAgendaProvider),
      ref.watch(repositorioHabitosProvider),
      ahora: ref.watch(relojProvider).ahora,
    ));

final cargaHoyProvider = FutureProvider<CargaDelDia>((ref) {
  ref.watch(versionHabitosProvider);
  return ref.watch(servicioAgendaProvider).carga();
});

final bloquesDelDiaProvider = FutureProvider.family<List<OcurrenciaBloque>, DateTime>((ref, f) {
  ref.watch(versionHabitosProvider);
  return ref.watch(servicioAgendaProvider).bloquesDe(f);
});

/// Versiones de la Biblia instaladas (vacío mientras no haya texto, P10).
final bibliasProvider = FutureProvider<List<ProveedorBiblia>>((ref) => cargarBiblias());

final servicioLecturaProvider = Provider<ServicioLectura>((ref) =>
    ServicioLectura(ref.watch(repositorioAgendaProvider), ahora: ref.watch(relojProvider).ahora));

final planesProvider = FutureProvider<List<PlanGuardado>>((ref) {
  ref.watch(versionHabitosProvider);
  return ref.watch(servicioLecturaProvider).activos();
});

final servicioDiarioProvider = Provider<ServicioDiario?>((ref) {
  final d = ref.watch(documentosSensiblesProvider);
  return d == null ? null : ServicioDiario(d, ahora: ref.watch(relojProvider).ahora);
});

final ajustesProvider = FutureProvider<AjustesHab>((ref) {
  ref.watch(versionHabitosProvider);
  return ref.watch(repositorioAgendaProvider).ajustes();
});

final servicioProgresoProvider = Provider<ServicioProgreso>((ref) => ServicioProgreso(
    ref.watch(repositorioHabitosProvider), ref.watch(repositorioAgendaProvider),
    ahora: ref.watch(relojProvider).ahora));

final servicioRevisionProvider = Provider<ServicioRevision>((ref) => ServicioRevision(
    ref.watch(repositorioAgendaProvider), ref.watch(servicioProgresoProvider), ref.watch(servicioDiarioProvider),
    ahora: ref.watch(relojProvider).ahora));
