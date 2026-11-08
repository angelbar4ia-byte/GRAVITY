/// Estado del simulador de deudas, los intereses y las tarjetas (Fase 8,
/// bloque 2). Nada de esto va a la IA ni a las bocinas (D3).
library;

import 'package:finanzas_dominio/finanzas_dominio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datos/tarjetas.dart';

/// Repositorio de tarjetas. Pendiente: el adaptador de Supabase
/// (`fin_tarjetas`, `fin_tarjeta_beneficios`) cuando backend fije las columnas.
final repositorioTarjetasProvider = Provider<RepositorioTarjetas>(
  (ref) => RepositorioTarjetasEnMemoria(),
);

class DatosTarjetas {
  const DatosTarjetas(this.tarjetas, this.beneficios);
  final List<Tarjeta> tarjetas;
  final List<BeneficioTarjeta> beneficios;

  List<Tarjeta> deLibro(String libroId) => [
    for (final t in tarjetas)
      if (t.libroId == libroId) t,
  ];

  List<BeneficioTarjeta> deTarjeta(String tarjetaId) => [
    for (final b in beneficios)
      if (b.tarjetaId == tarjetaId) b,
  ];
}

final tarjetasProvider = AsyncNotifierProvider<TarjetasNotifier, DatosTarjetas>(
  TarjetasNotifier.new,
);

class TarjetasNotifier extends AsyncNotifier<DatosTarjetas> {
  RepositorioTarjetas get _repo => ref.read(repositorioTarjetasProvider);

  @override
  Future<DatosTarjetas> build() async {
    ref.watch(repositorioTarjetasProvider);
    return DatosTarjetas(await _repo.tarjetas(), await _repo.beneficios());
  }

  Future<void> _recargar() async => state = AsyncData(
    DatosTarjetas(await _repo.tarjetas(), await _repo.beneficios()),
  );

  Future<void> guardarTarjeta(Tarjeta t) async {
    await _repo.guardarTarjeta(t);
    await _recargar();
  }

  Future<void> guardarBeneficio(BeneficioTarjeta b) async {
    await _repo.guardarBeneficio(b);
    await _recargar();
  }

  Future<void> quitarBeneficio(String id) async {
    await _repo.quitarBeneficio(id);
    await _recargar();
  }
}
