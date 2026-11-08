/// Estado de las transferencias y del periodo de la aportación (Fase 8).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/sesion_efectiva.dart';
import '../../../diseno/proveedores.dart' show relojProvider;
import '../../../nucleo/contratos/roles.dart';
import '../../../nucleo/sesion/proveedores_sesion.dart';
import '../../../nucleo/sesion/servicio_sesion_supabase.dart';
import '../datos/demostracion.dart';
import '../datos/fuente_tablas.dart';
import '../datos/transferencias.dart';

/// Repositorio según la sesión (Supabase, o memoria en demostración).
final repositorioTransferenciasProvider = Provider<RepositorioTransferencias>((
  ref,
) {
  final sesion = ref.watch(sesionEfectivaProvider);
  final servicio = ref.watch(servicioSesionProvider);
  if (servicio is ServicioSesionSupabase && sesion?.hogarId != null) {
    return RepositorioTransferenciasSupabase(
      FuenteTablasSupabase(() => servicio.clienteActivo),
    );
  }
  return RepositorioTransferenciasEnMemoria(
    personaId: sesion?.persona.id ?? '',
    duenoId: IdsDemostracion.dueno,
    parejaId: IdsDemostracion.pareja,
    reloj: ref.read(relojProvider).ahora,
  );
});

/// Qué parte es la persona activa frente a las rutas.
final parteTransferenciaProvider = Provider<ParteTransferencia>((ref) {
  final rol = ref.watch(sesionEfectivaProvider)?.rol;
  return switch (rol) {
    Rol.dueno => ParteTransferencia.dueno,
    Rol.coadministrador => ParteTransferencia.pareja,
    _ => ParteTransferencia.otra,
  };
});

final transferenciasProvider =
    AsyncNotifierProvider<TransferenciasNotifier, List<Transferencia>>(
      TransferenciasNotifier.new,
    );

class TransferenciasNotifier extends AsyncNotifier<List<Transferencia>> {
  RepositorioTransferencias get _repo =>
      ref.read(repositorioTransferenciasProvider);

  @override
  Future<List<Transferencia>> build() {
    ref.watch(repositorioTransferenciasProvider);
    return _repo.listar();
  }

  Future<void> refrescar() async {
    try {
      state = AsyncData(await _repo.listar());
    } catch (e, st) {
      if (!state.hasValue) state = AsyncError(e, st);
    }
  }

  Future<void> proponer({
    required RutaTransferencia ruta,
    required int montoCentavos,
    String nota = '',
  }) async {
    await _repo.proponer(ruta: ruta, montoCentavos: montoCentavos, nota: nota);
    await refrescar();
  }

  /// Confirmar, rechazar o cancelar: siempre por un botón de la persona.
  Future<void> responder(String id, AccionTransferencia accion) async {
    await _repo.responder(id, accion);
    await refrescar();
  }
}

final periodoAportacionProvider =
    AsyncNotifierProvider<PeriodoAportacionNotifier, PeriodoAportacion>(
      PeriodoAportacionNotifier.new,
    );

class PeriodoAportacionNotifier extends AsyncNotifier<PeriodoAportacion> {
  @override
  Future<PeriodoAportacion> build() {
    ref.watch(repositorioTransferenciasProvider);
    return ref.read(repositorioTransferenciasProvider).periodo();
  }

  Future<void> fijar(PeriodoAportacion periodo) async {
    await ref.read(repositorioTransferenciasProvider).fijarPeriodo(periodo);
    state = AsyncData(periodo);
  }
}
