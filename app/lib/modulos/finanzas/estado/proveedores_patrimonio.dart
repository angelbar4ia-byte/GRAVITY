/// Estado de objetivos, inversiones, bienes y previsión (Fase 8, bloque 3).
/// Nada de esto va a la IA ni a las bocinas (D3).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/sesion_efectiva.dart';
import '../../../nucleo/sesion/proveedores_sesion.dart';
import '../../../nucleo/sesion/servicio_sesion_supabase.dart';
import '../datos/fuente_tablas.dart';
import '../datos/patrimonio.dart';

/// Repositorio de patrimonio según la sesión: Supabase con la sesión real
/// (migración 20261136); en demostración, memoria.
final repositorioPatrimonioProvider = Provider<RepositorioPatrimonio>((ref) {
  final sesion = ref.watch(sesionEfectivaProvider);
  final servicio = ref.watch(servicioSesionProvider);
  if (servicio is ServicioSesionSupabase && sesion?.hogarId != null) {
    return RepositorioPatrimonioSupabase(
      FuenteTablasSupabase(() => servicio.clienteActivo),
    );
  }
  return RepositorioPatrimonioEnMemoria();
});

/// Lector de estados de inversión en PDF (plataforma lo reemplaza en la
/// laptop). El archivo no se sube.
final lectorEstadoInversionProvider = Provider<LectorEstadoInversion>(
  (ref) => const LectorEstadoInversionNoDisponible(),
);

class DatosPatrimonio {
  const DatosPatrimonio({
    this.objetivos = const [],
    this.inversiones = const [],
    this.bienes = const [],
    this.previsiones = const [],
  });

  final List<Objetivo> objetivos;
  final List<Inversion> inversiones;
  final List<Bien> bienes;
  final List<Prevision> previsiones;
}

/// El patrimonio de un libro.
final patrimonioDeLibroProvider =
    FutureProvider.family<DatosPatrimonio, String>((ref, libroId) async {
      final r = ref.watch(repositorioPatrimonioProvider);
      return DatosPatrimonio(
        objetivos: await r.objetivos(libroId),
        inversiones: await r.inversiones(libroId),
        bienes: await r.bienes(libroId),
        previsiones: await r.previsiones(libroId),
      );
    });
