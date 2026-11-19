/// Estado de la dispersión de ingresos (`docs/specs/fase-8-finanzas-
/// dispersion.md`): los repartos guardados, los ingresos por repartir del
/// libro activo y el servicio.
///
/// El repositorio es **en memoria** hasta que el backend construya las tablas
/// (sección 8 de la especificación); las pantallas ya trabajan contra la
/// interfaz [RepositorioDispersiones], así que cambiar el proveedor basta.
library;

import 'package:finanzas_dominio/finanzas_dominio.dart' as dom;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../casos_uso/servicio_dispersion.dart';
import '../datos/repositorio_dispersiones.dart';
import 'proveedores.dart';

/// Dónde se guardan los repartos. **Sin servidor todavía**: en memoria.
final repositorioDispersionesProvider = Provider<RepositorioDispersiones>((
  ref,
) {
  // Se reinicia al cambiar de persona (cada quien ve solo lo suyo).
  ref.watch(repositorioFinanzasProvider);
  final repo = RepositorioDispersionesEnMemoria();
  ref.onDispose(repo.cerrar);
  return repo;
});

/// Los repartos guardados, vivos: cambian al guardar.
final dispersionesProvider =
    NotifierProvider<DispersionesNotifier, List<dom.Dispersion>>(
      DispersionesNotifier.new,
    );

class DispersionesNotifier extends Notifier<List<dom.Dispersion>> {
  @override
  List<dom.Dispersion> build() {
    final repo = ref.watch(repositorioDispersionesProvider);
    final suscripcion = repo.cambios.listen((l) => state = l);
    ref.onDispose(suscripcion.cancel);
    return repo.actuales;
  }
}

/// Casos de uso de la dispersión con la persona y el reloj de ahora.
final servicioDispersionProvider = Provider<ServicioDispersion>(
  (ref) => ServicioDispersion(
    finanzas: ref.watch(servicioFinanzasProvider),
    repositorio: ref.watch(repositorioDispersionesProvider),
  ),
);

/// Ingresos del libro [libroId] con su estado de reparto, calculados con lo
/// cargado y los repartos guardados. No revisa permisos: quien lo usa ya sabe
/// que la persona lleva ese libro.
final ingresosDeLibroProvider =
    Provider.family<List<dom.IngresoPorRepartir>, String>((ref, libroId) {
      final c = ref.watch(contextoFinanzasProvider).value;
      if (c == null) return const [];
      final repo = ref.watch(repositorioDispersionesProvider);
      final repartos = ref.watch(dispersionesProvider);
      final parametros =
          repo.parametrosDe(libroId) ??
          dom.ParametrosDispersion(desde: dom.Semana.de(c.hoy).anterior.inicio);
      return dom.ingresosDelLibro(
        c.datos,
        libroId,
        repartos,
        parametros: parametros,
      );
    });

/// Ingresos del libro activo (todos los estados).
final ingresosDelLibroActivoProvider = Provider<List<dom.IngresoPorRepartir>>((
  ref,
) {
  final c = ref.watch(contextoFinanzasProvider).value;
  if (c == null || c.libro == null || !c.permiso.leer) return const [];
  return ref.watch(ingresosDeLibroProvider(c.libroId));
});

/// Ingresos pendientes del libro activo (por repartir o con propuesta).
final ingresosPendientesProvider = Provider<List<dom.IngresoPorRepartir>>(
  (ref) => [
    for (final i in ref.watch(ingresosDelLibroActivoProvider))
      if (i.estado.pendiente || i.pendiente > 0) i,
  ],
);

/// Lo que se arrastra a la semana [semana] del libro activo (centavos).
int porRepartirDeLaSemana(
  List<dom.IngresoPorRepartir> ingresos,
  dom.Semana semana,
  dom.Fecha hoy,
) => dom.porRepartirArrastrado(ingresos, semana: semana, hoy: hoy);
