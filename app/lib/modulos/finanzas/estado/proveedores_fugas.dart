/// Estado de las fugas silenciosas y de la deuda buena o mala (Fase 8, bloque
/// 6; `docs/specs/fase-8-fugas-y-deudas.md`): lo que la persona respondió y
/// declaró, el servicio y lo calculado del libro activo.
///
/// El repositorio es el de **Supabase** con la sesión real (migración
/// `20261146`) y el de **memoria** en demostración y en las pruebas. Las
/// pantallas trabajan contra la interfaz [RepositorioFugas]. Todo se calcula
/// en el dispositivo con reglas locales: nada de IA ni red para clasificar
/// (D3, D6).
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/sesion_efectiva.dart';
import '../../../diseno/proveedores.dart' show relojProvider;
import '../../../nucleo/sesion/proveedores_sesion.dart';
import '../../../nucleo/sesion/servicio_sesion_supabase.dart';
import '../casos_uso/servicio_fugas.dart';
import '../datos/fuente_tablas.dart';
import '../datos/repositorio_fugas.dart';
import '../datos/repositorio_fugas_supabase.dart';
import 'proveedores.dart';

/// Dónde se guardan las respuestas: Supabase con la sesión de la persona; en
/// demostración y sin sesión, en memoria. Se reinicia al cambiar de persona
/// (cada quien ve solo lo suyo).
final repositorioFugasProvider = Provider<RepositorioFugas>((ref) {
  final sesion = ref.watch(sesionEfectivaProvider);
  final servicio = ref.watch(servicioSesionProvider);
  if (sesion != null &&
      servicio is ServicioSesionSupabase &&
      sesion.hogarId != null) {
    final repo = RepositorioFugasSupabase(
      fuente: FuenteTablasSupabase(() => servicio.clienteActivo),
    );
    ref.onDispose(repo.cerrar);
    // Un fallo de carga nunca tumba la pantalla; sin señal se vuelve a pedir
    // con la próxima recarga de Finanzas.
    unawaited(repo.cargar().then((_) {}, onError: (Object _) {}));
    // Se pone al día junto con Finanzas (Realtime, volver, «Actualizar»).
    final registro = ref.read(recargasAuxiliaresFinanzasProvider);
    Future<void> recargar() => repo.cargar();
    registro.add(recargar);
    ref.onDispose(() => registro.remove(recargar));
    return repo;
  }
  final repo = RepositorioFugasEnMemoria(reloj: ref.read(relojProvider).ahora);
  ref.onDispose(repo.cerrar);
  return repo;
});

/// Lo guardado, vivo: cambia al responder o declarar.
final fugasGuardadasProvider = NotifierProvider<FugasGuardadas, DatosFugas>(
  FugasGuardadas.new,
);

class FugasGuardadas extends Notifier<DatosFugas> {
  @override
  DatosFugas build() {
    final repo = ref.watch(repositorioFugasProvider);
    final suscripcion = repo.cambios.listen((d) => state = d);
    ref.onDispose(suscripcion.cancel);
    return repo.actuales;
  }
}

/// Claves de aviso ya emitidas en la sesión de esta persona (no se repiten
/// aunque el servicio se vuelva a armar).
final avisosFugasEmitidosProvider = Provider<Set<String>>((ref) {
  ref.watch(sesionEfectivaProvider.select((s) => s?.persona.id));
  return <String>{};
});

/// Casos de uso con la persona, su rol y el reloj de ahora.
final servicioFugasProvider = Provider<ServicioFugas>((ref) {
  final sesion = ref.watch(sesionEfectivaProvider);
  return ServicioFugas(
    finanzas: ref.watch(servicioFinanzasProvider),
    repositorio: ref.watch(repositorioFugasProvider),
    rol: sesion?.rol,
    reloj: ref.watch(relojProvider).ahora,
    avisadas: ref.watch(avisosFugasEmitidosProvider),
  );
});

/// Libros a los que ya se les emitieron los avisos de fugas y deudas en esta
/// sesión (una vez al abrir cada libro; los avisos son idempotentes).
final avisosFugasRevisadosProvider =
    NotifierProvider<AvisosFugasRevisados, Set<String>>(
      AvisosFugasRevisados.new,
    );

class AvisosFugasRevisados extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    ref.watch(sesionEfectivaProvider.select((s) => s?.persona.id));
    return const {};
  }

  /// Emite (sin esperar, sin lanzar) los avisos del bloque 6 del libro:
  /// `fuga_por_reconocer`, `fuga_revision_mensual`, `deuda_en_vigilancia` y
  /// `deuda_se_volvio_mala`. Una vez por libro y sesión; sin cifras (D20).
  void revisar(String libroId) {
    if (state.contains(libroId)) return;
    state = {...state, libroId};
    unawaited(ref.read(servicioFugasProvider).emitirAvisos(libroId));
  }
}

/// `true` si la persona ve las fugas y la calidad de las deudas del libro
/// activo (dueño o coadministrador que lee el libro; la cuenta maestra, solo
/// lectura). Falso para el familiar, el cuidador, Casa y la tablet pública.
final puedeVerFugasProvider = Provider<bool>((ref) {
  final c = ref.watch(contextoFinanzasProvider).value;
  if (c == null || c.libro == null || !c.permiso.leer) return false;
  return ref.watch(servicioFugasProvider).puedeVer(c.libroId);
});

/// Las fugas del libro [libroId], calculadas con lo cargado y lo respondido.
/// Se recalcula al cambiar el libro cargado o las respuestas.
final analisisFugasProvider = Provider.family<AnalisisFugas, String>((
  ref,
  libroId,
) {
  ref.watch(contextoFinanzasProvider); // el libro cargado cambió
  ref.watch(fugasGuardadasProvider); // la persona respondió
  return ref.watch(servicioFugasProvider).analizar(libroId);
});

/// Las deudas del libro [libroId] con su calidad (buena, en vigilancia, mala o
/// por declarar).
final calidadDeudasProvider = Provider.family<List<DeudaConCalidad>, String>((
  ref,
  libroId,
) {
  ref.watch(contextoFinanzasProvider);
  ref.watch(fugasGuardadasProvider);
  return ref.watch(servicioFugasProvider).calidadDeDeudas(libroId);
});

/// «Tus MSI y tu ingreso» del libro [libroId]; nulo si no ve las deudas.
final resumenMsiProvider = Provider.family<ResumenMsi?, String>((ref, libroId) {
  ref.watch(contextoFinanzasProvider);
  ref.watch(fugasGuardadasProvider);
  final s = ref.watch(servicioFugasProvider);
  if (!s.puedeVer(libroId)) return null;
  try {
    return s.resumenMsi(libroId);
  } on Object {
    return null;
  }
});

/// Cuántas preguntas tiene la revisión de cobros del libro activo (0 si no la
/// ve). Para la tarjeta «Revisa un cobro».
final preguntasPendientesProvider = Provider<int>((ref) {
  final c = ref.watch(contextoFinanzasProvider).value;
  if (c == null || c.libro == null || !ref.watch(puedeVerFugasProvider)) {
    return 0;
  }
  return ref.watch(analisisFugasProvider(c.libroId)).preguntas.length;
});
