/// Estado de objetivos, inversiones, bienes y previsión (Fase 8, bloque 3).
/// Nada de esto va a la IA ni a las bocinas (D3).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datos/patrimonio.dart';

/// Repositorio de patrimonio. Pendiente: conectar
/// [RepositorioPatrimonioSupabase] cuando backend entregue la migración
/// 20261136 y se confirmen las columnas.
final repositorioPatrimonioProvider = Provider<RepositorioPatrimonio>(
  (ref) => RepositorioPatrimonioEnMemoria(),
);

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
