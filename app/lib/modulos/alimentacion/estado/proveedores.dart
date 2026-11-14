library;

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;

import '../../../app/alimentacion/proveedor_alimentacion_supabase.dart';
import '../../../app/alimentacion/sugeridor_recetas_supabase.dart';
import '../../../app/router.dart' show navegadorCascaronKey;
import '../../../app/sesion_efectiva.dart';
import '../../../app/sesion_real.dart';
import '../../../diseno/proveedores.dart' show relojProvider;
import '../../../nucleo/contratos/roles.dart';
import '../casos_uso/lectura_voz.dart';
import '../casos_uso/plan_familiar.dart';
import '../casos_uso/servicio_alimentacion.dart';
import '../casos_uso/sugerir_platillos.dart';
import '../datos/lector_codigo.dart';
import '../datos/lector_codigo_camara.dart';
import '../datos/modelos.dart';
import '../datos/repositorio.dart';

/// `true` con sesión real (Supabase): nunca se muestran datos de ejemplo
/// (revisión F4-A6).
final alimentacionSinServidorProvider = Provider<bool>(
  (ref) => ref.watch(sesionRealSupabaseProvider),
);

/// Demostración y pruebas: memoria con datos de ejemplo. Sesión real:
/// repositorio de Supabase (`app/alimentacion/`, fuera del módulo por la
/// guardia D3); si la sesión no trae hogar, vacío honesto.
final repositorioAlimentacionProvider = Provider<RepositorioAlimentacion>((
  ref,
) {
  if (ref.watch(alimentacionSinServidorProvider)) {
    return ref.watch(repositorioAlimentacionSupabaseProvider) ??
        const RepositorioAlimentacionSinServidor();
  }
  return RepositorioAlimentacionEnMemoria(
    semanaEjemplo: ref.read(relojProvider).ahora(),
  );
});

final puedeEditarAlimentacionProvider = Provider<bool>((ref) {
  final s = ref.watch(sesionEfectivaProvider);
  return s != null && puedeEditarAlimentacion(s.rol, esMaestra: s.esMaestra);
});

/// La función de la IA para "Sugerir con IA" (Fase 8). Vive en `app/`
/// (guardia D3); sin sesión real, avisa que no está disponible.
final sugeridorRecetasProvider = Provider<SugeridorRecetas>(
  (ref) =>
      ref.watch(sugeridorRecetasSupabaseProvider) ??
      const SugeridorNoDisponible(),
);

final servicioAlimentacionProvider = Provider<ServicioAlimentacion>((ref) {
  final s = ref.watch(sesionEfectivaProvider);
  return ServicioAlimentacion(
    ref.watch(repositorioAlimentacionProvider),
    rol: s?.rol ?? Rol.casa,
    esMaestra: s?.esMaestra ?? false,
    ahora: ref.read(relojProvider).ahora,
    sugeridor: ref.watch(sugeridorRecetasProvider),
  );
});

/// Historial completo del libro o lista de [MenuId].
final historialCompletoProvider =
    FutureProvider.family<List<CompraPrecio>, MenuId>((ref, m) {
      ref.watch(versionAlimentacionProvider);
      return ref.watch(servicioAlimentacionProvider).historialCompleto(m);
    });

/// Tiendas del hogar.
final tiendasProvider = FutureProvider<List<Tienda>>((ref) {
  ref.watch(versionAlimentacionProvider);
  return ref.watch(servicioAlimentacionProvider).tiendas();
});

/// Platillos contra la despensa de la cuenta que pide.
final platillosConDespensaProvider =
    FutureProvider<List<PlatilloConDespensa>>((ref) {
      ref.watch(versionAlimentacionProvider);
      return ref.watch(servicioAlimentacionProvider).platillosConLaDespensa();
    });

/// Plataforma en uso; inyectable en pruebas.
final plataformaLectorProvider = Provider<TargetPlatform>(
  (_) => defaultTargetPlatform,
);

/// Lector de código de barras: cámara en Android; en Windows no se usa cámara
/// (sin lectura, se captura a mano). El permiso se pide solo al escanear.
final lectorCodigoProvider = Provider<LectorCodigo>(
  (ref) => ref.watch(plataformaLectorProvider) == TargetPlatform.android
      ? LectorCodigoCamara(() => navegadorCascaronKey.currentContext)
      : const LectorCodigoSinCamara(),
);

final servicioPlanFamiliarProvider = Provider<ServicioPlanFamiliar>((ref) {
  final s = ref.watch(sesionEfectivaProvider);
  return ServicioPlanFamiliar(
    ref.watch(repositorioAlimentacionProvider),
    rol: s?.rol ?? Rol.casa,
    esMaestra: s?.esMaestra ?? false,
    personaId: s?.persona.id ?? '',
    personaNombre: s?.persona.nombre ?? '',
    ahora: ref.read(relojProvider).ahora,
  );
});

/// Día del plan familiar que se está viendo.
final diaPlanProvider = StateProvider<DateTime>((ref) {
  final h = ref.read(relojProvider).ahora();
  return DateTime(h.year, h.month, h.day);
});

final votacionPlanProvider = FutureProvider<VotacionPlan?>((ref) {
  ref.watch(versionAlimentacionProvider);
  return ref
      .watch(servicioPlanFamiliarProvider)
      .votacion(ref.watch(diaPlanProvider));
});

/// Nombres de platillo del plan del día que esta persona puede ver (Casa:
/// solo los de la comida familiar ganadora).
final nombresPlatillosPlanProvider = FutureProvider<Map<String, String>>((
  ref,
) async {
  final vot = await ref.watch(votacionPlanProvider.future);
  return ref.watch(servicioPlanFamiliarProvider).nombresDePlatillos(vot);
});

/// Porciones recomendadas por persona (menú compartido de dueño y pareja).
final porcionesRecomendadasProvider =
    FutureProvider<Map<String, List<PorcionPersona>>>((ref) {
      ref.watch(versionAlimentacionProvider);
      return ref
          .watch(servicioAlimentacionProvider)
          .porcionesPorPlatillo(ref.watch(semanaAlimentacionProvider));
    });

/// Menú del día de Papá para la cuenta Casa (D28): solo nombres de platillos.
final menuDelDiaPapaProvider = FutureProvider<List<ComidaDelDia>>((ref) {
  ref.watch(versionAlimentacionProvider);
  return ref
      .watch(servicioAlimentacionProvider)
      .menuDelDiaPapa(ref.read(relojProvider).ahora());
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

/// Respuesta de "¿Hay presupuesto para comprar?": sí o no, sin cifras.
/// Con [montoCentavos] (el total de la lista) pregunta por ese monto.
final hayPresupuestoProvider = FutureProvider.family<bool?, int?>((
  ref,
  montoCentavos,
) {
  ref.watch(versionAlimentacionProvider);
  return ref
      .watch(servicioAlimentacionProvider)
      .hayPresupuesto(montoCentavos: montoCentavos);
});

/// `true` solo para el albacea vigente de Papá (no la suplente).
final esAlbaceaAlimentacionProvider = FutureProvider<bool>((ref) async {
  ref.watch(versionAlimentacionProvider);
  try {
    return await ref
        .watch(servicioAlimentacionProvider)
        .puedeResolverSolicitudes();
  } catch (_) {
    return false;
  }
});

/// Compras de Papá pendientes de pago (solo el albacea; los demás, lanza
/// [PermisoDenegado]).
final solicitudesPapaProvider = FutureProvider<List<SolicitudPago>>((ref) {
  ref.watch(versionAlimentacionProvider);
  return ref.watch(servicioAlimentacionProvider).solicitudesPendientes();
});

/// Mis compras de Papá rechazadas que todavía puedo reenviar (v1.4).
final solicitudesRechazadasMiasProvider = FutureProvider<List<SolicitudPago>>((ref) {
  ref.watch(versionAlimentacionProvider);
  return ref.watch(servicioAlimentacionProvider).solicitudesRechazadasMias();
});
