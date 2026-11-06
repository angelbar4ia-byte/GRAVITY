library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;

import '../../../app/sesion_efectiva.dart';
import '../../../diseno/proveedores.dart' show relojProvider;
import '../casos_uso/servicio_alimentacion.dart';
import '../datos/modelos.dart';
import '../datos/repositorio.dart';

/// Hoy en memoria con datos de ejemplo; cuando backend entregue las tablas
/// (spec, sección 6) se cambia aquí por el repositorio de Supabase.
final repositorioAlimentacionProvider = Provider<RepositorioAlimentacion>(
  (ref) => RepositorioAlimentacionEnMemoria(
    semanaEjemplo: ref.read(relojProvider).ahora(),
  ),
);

final puedeEditarAlimentacionProvider = Provider<bool>((ref) {
  final s = ref.watch(sesionEfectivaProvider);
  return s != null && puedeEditarAlimentacion(s.rol, esMaestra: s.esMaestra);
});

final servicioAlimentacionProvider = Provider<ServicioAlimentacion>(
  (ref) => ServicioAlimentacion(
    ref.watch(repositorioAlimentacionProvider),
    puedeEditar: ref.watch(puedeEditarAlimentacionProvider),
  ),
);

/// Lunes de la semana que se está viendo.
final semanaAlimentacionProvider = StateProvider<DateTime>(
  (ref) => lunesDe(ref.read(relojProvider).ahora()),
);

/// Contador para volver a pedir datos tras cada cambio.
final versionAlimentacionProvider = StateProvider<int>((_) => 0);

final menuSemanaProvider = FutureProvider<List<EntradaMenu>>((ref) {
  ref.watch(versionAlimentacionProvider);
  return ref
      .watch(servicioAlimentacionProvider)
      .menu(ref.watch(semanaAlimentacionProvider));
});

final platillosProvider = FutureProvider<List<Platillo>>(
  (ref) => ref.watch(servicioAlimentacionProvider).platillos(),
);

final listaComprasProvider = FutureProvider<List<ItemCompra>>((ref) {
  ref.watch(versionAlimentacionProvider);
  return ref
      .watch(servicioAlimentacionProvider)
      .listaCompras(ref.watch(semanaAlimentacionProvider));
});
