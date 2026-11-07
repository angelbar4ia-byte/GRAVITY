/// Estado de la vista temporal de Finanzas de Papá (D24): el repositorio según
/// la sesión y la lista de solicitudes que la persona puede ver.
library;

import 'package:finanzas_dominio/finanzas_dominio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/sesion_efectiva.dart';
import '../../../diseno/proveedores.dart' show relojProvider;
import '../../../nucleo/sesion/proveedores_sesion.dart';
import '../../../nucleo/sesion/servicio_sesion_supabase.dart';
import '../datos/demostracion.dart';
import '../datos/fuente_tablas.dart';
import '../datos/vista_papa.dart';
import 'proveedores.dart' show repositorioFinanzasProvider;

/// Repositorio de la vista temporal. Con Supabase usa el cliente de la persona
/// activa; en demostración, memoria con el hogar de ejemplo (el reloj de la
/// app marca los 30 minutos). Las pruebas lo sobrescriben.
final repositorioVistaPapaProvider = Provider<RepositorioVistaPapa>((ref) {
  final sesion = ref.watch(sesionEfectivaProvider);
  final servicio = ref.watch(servicioSesionProvider);
  if (servicio is ServicioSesionSupabase && sesion?.hogarId != null) {
    return RepositorioVistaPapaSupabase(
      fuente: FuenteTablasSupabase(() => servicio.clienteActivo),
      cargarLibros: () async =>
          (await ref.read(repositorioFinanzasProvider).cargar()).datos,
    );
  }
  final reloj = ref.read(relojProvider);
  final hoy = Fecha.deDateTime(reloj.ahora());
  return RepositorioVistaPapaEnMemoria(
    personaId: sesion?.persona.id ?? '',
    duenoId: IdsDemostracion.dueno,
    datosPapa: datosDeLibros(datosDeDemostracion(hoy: hoy), {
      IdsDemostracion.libroPapa,
    }, conservarLibros: false),
    reloj: reloj.ahora,
  );
});

/// Solicitudes que la persona puede ver: las suyas (familiar) o todas (dueño).
final solicitudesVistaPapaProvider =
    AsyncNotifierProvider<SolicitudesVistaPapa, List<SolicitudVista>>(
      SolicitudesVistaPapa.new,
    );

class SolicitudesVistaPapa extends AsyncNotifier<List<SolicitudVista>> {
  RepositorioVistaPapa get _repo => ref.read(repositorioVistaPapaProvider);

  @override
  Future<List<SolicitudVista>> build() {
    ref.watch(repositorioVistaPapaProvider);
    return _repo.listar();
  }

  /// Vuelve a pedir la lista (sin pasar por "cargando": la pantalla no parpadea).
  Future<void> refrescar() async {
    try {
      state = AsyncData(await _repo.listar());
    } catch (e, st) {
      // Sin señal se conserva lo último; solo se avisa si no había nada.
      if (!state.hasValue) state = AsyncError(e, st);
    }
  }

  /// Pide la vista. Lanza el error del repositorio (motivo corto, sin señal).
  Future<void> pedir(String motivo) async {
    await _repo.pedir(motivo);
    await refrescar();
  }

  Future<void> responder(String solicitudId, AccionVista accion) async {
    await _repo.responder(solicitudId, accion);
    await refrescar();
  }
}
