library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;

import '../../../app/sesion_efectiva.dart';
import '../../../app/sesion_real.dart';
import '../../../diseno/proveedores.dart' show relojProvider;
import '../../../nucleo/contratos/roles.dart';
import '../casos_uso/lectura_voz.dart';
import '../casos_uso/servicio_alimentacion.dart';
import '../datos/modelos.dart';
import '../datos/repositorio.dart';

/// `true` con sesión real (Supabase): todavía no hay tablas de Alimentación,
/// así que no se muestra ningún dato de ejemplo (revisión F4-A6).
final alimentacionSinServidorProvider = Provider<bool>(
  (ref) => ref.watch(sesionRealSupabaseProvider),
);

/// Demostración y pruebas: memoria con datos de ejemplo. Sesión real: vacío
/// honesto hasta que backend entregue las tablas (spec, sección 6); entonces
/// se cambia aquí por el repositorio de Supabase.
final repositorioAlimentacionProvider = Provider<RepositorioAlimentacion>((
  ref,
) {
  if (ref.watch(alimentacionSinServidorProvider)) {
    return const RepositorioAlimentacionSinServidor();
  }
  return RepositorioAlimentacionEnMemoria(
    semanaEjemplo: ref.read(relojProvider).ahora(),
  );
});

final puedeEditarAlimentacionProvider = Provider<bool>((ref) {
  final s = ref.watch(sesionEfectivaProvider);
  return s != null && puedeEditarAlimentacion(s.rol, esMaestra: s.esMaestra);
});

final servicioAlimentacionProvider = Provider<ServicioAlimentacion>((ref) {
  final s = ref.watch(sesionEfectivaProvider);
  return ServicioAlimentacion(
    ref.watch(repositorioAlimentacionProvider),
    rol: s?.rol ?? Rol.casa,
    esMaestra: s?.esMaestra ?? false,
  );
});

/// Lunes de la semana que se está viendo.
final semanaAlimentacionProvider = StateProvider<DateTime>(
  (ref) => lunesDe(ref.read(relojProvider).ahora()),
);

/// Menú elegido en el selector (se corrige a uno permitido con [menuEfectivo]).
final menuElegidoProvider = StateProvider<MenuId>((_) => MenuId.papa);

/// El menú elegido si está en [permitidos]; si no, el primero.
MenuId? menuEfectivo(MenuId elegido, List<MenuId> permitidos) =>
    permitidos.isEmpty
    ? null
    : (permitidos.contains(elegido) ? elegido : permitidos.first);

/// Contador para volver a pedir datos tras cada cambio.
final versionAlimentacionProvider = StateProvider<int>((_) => 0);

final platillosProvider = FutureProvider<List<Platillo>>(
  (ref) => ref.watch(servicioAlimentacionProvider).platillos(),
);

final menuSemanaProvider = FutureProvider.family<List<EntradaMenu>, MenuId>((
  ref,
  m,
) {
  ref.watch(versionAlimentacionProvider);
  return ref
      .watch(servicioAlimentacionProvider)
      .menu(m, ref.watch(semanaAlimentacionProvider));
});

final suplementosProvider = FutureProvider.family<List<Suplemento>, MenuId>((
  ref,
  m,
) {
  ref.watch(versionAlimentacionProvider);
  return ref.watch(servicioAlimentacionProvider).suplementos(m);
});

final listaComprasProvider = FutureProvider.family<List<ItemCompra>, MenuId>((
  ref,
  m,
) {
  ref.watch(versionAlimentacionProvider);
  return ref
      .watch(servicioAlimentacionProvider)
      .listaCompras(m, ref.watch(semanaAlimentacionProvider));
});

/// Dónde va la receta que se cocina (memoria de la sesión, nada se guarda).
final cocinaPasoAPasoProvider = Provider<CocinaPasoAPaso>(
  (ref) => CocinaPasoAPaso(),
);

/// Contenido de las cinco herramientas de voz de Alimentación para
/// `ContextoHerramienta.consultaLocal` (puente de Casa, D6). `null` si no es
/// una de ellas o si falla la lectura.
final consultaLocalAlimentacionProvider =
    Provider<Future<String?> Function(String herramienta)>((ref) {
      final lectura = LecturaVozAlimentacion(
        ref.watch(repositorioAlimentacionProvider),
        ref.watch(cocinaPasoAPasoProvider),
        ahora: ref.read(relojProvider).ahora,
      );
      return (String herramienta) async {
        try {
          return await lectura.responder(herramienta);
        } catch (_) {
          return null;
        }
      };
    });
