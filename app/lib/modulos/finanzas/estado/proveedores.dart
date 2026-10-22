/// Estado de Finanzas con Riverpod: el repositorio según la sesión, lo
/// cargado, el **libro activo** (D19) con su permiso y los casos de uso.
library;

import 'dart:async';

import 'package:finanzas_dominio/finanzas_dominio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/sesion_efectiva.dart';
import '../../../diseno/proveedores.dart' show horaActualProvider, relojProvider;
import '../../../nucleo/cola/proveedores_cola.dart';
import '../../../nucleo/contratos/roles.dart';
import '../../../nucleo/permisos/permisos.dart' as permisos;
import '../../../nucleo/seguridad/proveedores_seguridad.dart';
import '../../../nucleo/sesion/proveedores_sesion.dart';
import '../../../nucleo/sesion/servicio_sesion_supabase.dart';
import '../casos_uso/servicio_finanzas.dart';
import '../datos/demostracion.dart';
import '../datos/fuente_tablas.dart';
import '../datos/repositorio.dart';
import '../datos/repositorio_memoria.dart';
import '../datos/repositorio_supabase.dart';

/// Hoy (fecha local), según el reloj de la app. Cambia solo al cambiar el día.
final hoyFinanzasProvider = Provider<Fecha>(
  (ref) => ref.watch(
    horaActualProvider.select((t) => Fecha.deDateTime(t)),
  ),
);

/// Repositorio de la persona que usa la app ahora (en la tablet, la que
/// entró con su PIN): Supabase con su cliente; en demostración, el hogar de
/// ejemplo filtrado como lo haría el servidor; sin sesión, vacío.
final repositorioFinanzasProvider = Provider<RepositorioFinanzas>((ref) {
  final sesion = ref.watch(sesionEfectivaProvider);
  final servicio = ref.watch(servicioSesionProvider);
  if (sesion == null) return RepositorioFinanzasEnMemoria();
  final personaId = sesion.persona.id;
  final hogarId = sesion.hogarId;
  if (servicio is ServicioSesionSupabase && hogarId != null) {
    final repo = RepositorioFinanzasSupabase(
      fuente: FuenteTablasSupabase(() => servicio.clienteActivo),
      cola: ref.watch(colaSinConexionProvider),
      hogarId: hogarId,
      personaId: personaId,
      copia: CopiaLocalFinanzas(
        ref.watch(almacenSeguroProvider),
        personaId: personaId,
      ),
    );
    ref.onDispose(repo.cerrar);
    return repo;
  }
  if (servicio.esDemostracion) {
    final hoy = Fecha.deDateTime(ref.read(relojProvider).ahora());
    final maestra = ref.watch(esCuentaMaestraProvider);
    final repo = RepositorioFinanzasEnMemoria(
      datos: filtrarParaPersona(
        datosDeDemostracion(hoy: hoy),
        personaId,
        hoy: hoy,
        esMaestra: maestra,
      ),
      personaId: personaId,
      personas: personasDeDemostracion(),
      esMaestra: maestra,
    );
    ref.onDispose(repo.cerrar);
    return repo;
  }
  final repo = RepositorioFinanzasEnMemoria(personaId: personaId);
  ref.onDispose(repo.cerrar);
  return repo;
});

/// Lo cargado de Finanzas, al día con cada escritura.
final cargaFinanzasProvider =
    AsyncNotifierProvider<CargaFinanzasNotifier, CargaFinanzas>(
      CargaFinanzasNotifier.new,
    );

class CargaFinanzasNotifier extends AsyncNotifier<CargaFinanzas> {
  @override
  Future<CargaFinanzas> build() async {
    final repo = ref.watch(repositorioFinanzasProvider);
    final suscripcion = repo.cambios.listen((c) => state = AsyncData(c));
    ref.onDispose(suscripcion.cancel);
    return repo.cargar();
  }

  /// Vuelve a pedir todo al servidor (Reintentar, deslizar para actualizar).
  Future<void> recargar() async {
    final repo = ref.read(repositorioFinanzasProvider);
    state = await AsyncValue.guard(repo.cargar);
  }
}

/// Libro que eligió la persona en el selector (nulo = el primero: su libro
/// personal). Se olvida al cambiar de persona.
final libroElegidoProvider = NotifierProvider<LibroElegido, String?>(
  LibroElegido.new,
);

class LibroElegido extends Notifier<String?> {
  @override
  String? build() {
    ref.watch(sesionEfectivaProvider.select((s) => s?.persona.id));
    return null;
  }

  void elegir(String libroId) => state = libroId;
}

/// Semana que se está viendo (nula = la de hoy).
final semanaElegidaProvider = NotifierProvider<SemanaElegida, Semana?>(
  SemanaElegida.new,
);

class SemanaElegida extends Notifier<Semana?> {
  @override
  Semana? build() {
    ref.watch(libroElegidoProvider);
    return null;
  }

  void elegir(Semana? semana) => state = semana;
}

/// Todo lo que necesita una pantalla de Finanzas.
class ContextoFinanzas {
  const ContextoFinanzas({
    required this.carga,
    required this.personaId,
    required this.rol,
    required this.hoy,
    required this.esMaestra,
    required this.libros,
    required this.libro,
    required this.permiso,
  });

  final CargaFinanzas carga;
  final String personaId;
  final Rol rol;
  final Fecha hoy;
  final bool esMaestra;

  /// Libros que la persona ve, en el orden del selector.
  final List<Libro> libros;

  /// Libro activo (nulo si no ve ninguno).
  final Libro? libro;
  final PermisoLibro permiso;

  DatosFinanzas get datos => carga.datos;
  String get libroId => libro!.id;
  bool get puedeEscribir => permiso.escribir;
  bool get puedeAdministrar => permiso.administrar;

  /// Permiso para lo que es del **hogar** (categorías y cuentas de gasto,
  /// días inhábiles e importaciones): el rol tiene Finanzas (D19).
  bool get administraHogar =>
      permisos.puede(rol, Modulo.finanzas, Accion.administrar);

  PermisoLibro permisoEn(Libro l) =>
      permisoEnLibro(l, personaId, hoy: hoy, esMaestra: esMaestra);

  static ContextoFinanzas armar({
    required CargaFinanzas carga,
    required String personaId,
    required Rol rol,
    required Fecha hoy,
    required bool esMaestra,
    String? elegido,
  }) {
    final visibles = librosVisibles(
      carga.datos.libros,
      personaId,
      hoy: hoy,
      esMaestra: esMaestra,
    );
    final libro =
        visibles.where((l) => l.id == elegido).firstOrNull ??
        visibles.firstOrNull;
    return ContextoFinanzas(
      carga: carga,
      personaId: personaId,
      rol: rol,
      hoy: hoy,
      esMaestra: esMaestra,
      libros: visibles,
      libro: libro,
      permiso: libro == null
          ? PermisoLibro.ninguno
          : permisoEnLibro(libro, personaId, hoy: hoy, esMaestra: esMaestra),
    );
  }
}

/// `true` si la persona es la cuenta maestra (por la sesión o por el
/// servidor).
final esMaestraFinanzasProvider = Provider<bool>(
  (ref) =>
      ref.watch(esCuentaMaestraProvider) ||
      ref.watch(
        cargaFinanzasProvider.select((a) => a.value?.esMaestra ?? false),
      ),
);

final contextoFinanzasProvider = Provider<AsyncValue<ContextoFinanzas>>((ref) {
  final sesion = ref.watch(sesionEfectivaProvider);
  final carga = ref.watch(cargaFinanzasProvider);
  final hoy = ref.watch(hoyFinanzasProvider);
  final elegido = ref.watch(libroElegidoProvider);
  final maestra = ref.watch(esMaestraFinanzasProvider);
  if (sesion == null) {
    return AsyncError(const ErrorFinanzas('Nadie ha entrado.'), StackTrace.empty);
  }
  return carga.whenData(
    (c) => ContextoFinanzas.armar(
      carga: c,
      personaId: sesion.persona.id,
      rol: sesion.rol,
      hoy: hoy,
      esMaestra: maestra,
      elegido: elegido,
    ),
  );
});

/// Casos de uso con la persona y el reloj de ahora.
final servicioFinanzasProvider = Provider<ServicioFinanzas>((ref) {
  final sesion = ref.watch(sesionEfectivaProvider);
  final reloj = ref.watch(relojProvider);
  return ServicioFinanzas(
    repositorio: ref.watch(repositorioFinanzasProvider),
    personaId: sesion?.persona.id ?? '',
    esMaestra: ref.watch(esMaestraFinanzasProvider),
    reloj: reloj.ahora,
  );
});

/// La consulta de la cuenta maestra a un libro ajeno queda en la bitácora
/// **antes** de mostrarlo (D19). Si no se puede registrar, no se muestra.
final consultaMaestraProvider = FutureProvider.family<bool, String>((
  ref,
  libroId,
) async {
  await ref.read(repositorioFinanzasProvider).registrarConsultaMaestra(libroId);
  return true;
});

/// Libros a los que ya se les revisó el cierre automático en esta sesión.
final cierresRevisadosProvider = NotifierProvider<CierresRevisados, Set<String>>(
  CierresRevisados.new,
);

class CierresRevisados extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    ref.watch(sesionEfectivaProvider.select((s) => s?.persona.id));
    return const {};
  }

  /// Revisa una sola vez por libro y sesión las semanas que pasaron 3 días
  /// sin cerrar (5.9 bis, punto 4): se cierran con pendientes marcados.
  void revisar(String libroId) {
    if (state.contains(libroId)) return;
    state = {...state, libroId};
    unawaited(
      ref
          .read(servicioFinanzasProvider)
          .cerrarSemanasVencidas(libroId)
          .catchError((_) => 0),
    );
  }
}
