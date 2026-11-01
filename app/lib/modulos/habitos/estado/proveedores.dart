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
import '../datos/documentos_sensibles.dart';
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
