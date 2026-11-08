/// Tarjetas y beneficios de cada persona (Fase 8, bloque 2; D19).
///
/// Lo que la persona captura a mano queda como [OrigenDato.capturado]: la app
/// nunca lo presenta como verificado. Las tablas del servidor son
/// `fin_tarjetas` y `fin_tarjeta_beneficios` (RLS por persona); mientras el
/// adaptador de Supabase no esté, se usa [RepositorioTarjetasEnMemoria]. Nada
/// de esto sale a la IA ni a las bocinas (D3).
library;

import 'package:finanzas_dominio/finanzas_dominio.dart';

abstract interface class RepositorioTarjetas {
  Future<List<Tarjeta>> tarjetas();
  Future<List<BeneficioTarjeta>> beneficios();
  Future<void> guardarTarjeta(Tarjeta tarjeta);
  Future<void> guardarBeneficio(BeneficioTarjeta beneficio);
  Future<void> quitarBeneficio(String beneficioId);
}

class RepositorioTarjetasEnMemoria implements RepositorioTarjetas {
  RepositorioTarjetasEnMemoria({
    List<Tarjeta> tarjetas = const [],
    List<BeneficioTarjeta> beneficios = const [],
  }) : _tarjetas = {for (final t in tarjetas) t.id: t},
       _beneficios = {for (final b in beneficios) b.id: b};

  final Map<String, Tarjeta> _tarjetas;
  final Map<String, BeneficioTarjeta> _beneficios;

  @override
  Future<List<Tarjeta>> tarjetas() async => _tarjetas.values.toList();

  @override
  Future<List<BeneficioTarjeta>> beneficios() async =>
      _beneficios.values.toList();

  @override
  Future<void> guardarTarjeta(Tarjeta tarjeta) async =>
      _tarjetas[tarjeta.id] = tarjeta;

  @override
  Future<void> guardarBeneficio(BeneficioTarjeta beneficio) async {
    if (!_tarjetas.containsKey(beneficio.tarjetaId)) {
      throw ArgumentError('La tarjeta ${beneficio.tarjetaId} no existe');
    }
    _beneficios[beneficio.id] = beneficio;
  }

  @override
  Future<void> quitarBeneficio(String beneficioId) async =>
      _beneficios.remove(beneficioId);
}

/// Alta de una tarjeta **capturada a mano**: siempre `capturado`, nunca
/// `verificado` (solo una fuente comprobada lo cambia). Banco y nombre, de 1 a
/// 60 caracteres (como `fin_tarjetas`).
Tarjeta tarjetaCapturada({
  required String id,
  required String libroId,
  required String banco,
  required String nombre,
}) {
  final n = nombre.trim();
  final b = banco.trim();
  if (b.isEmpty || b.length > 60) {
    throw ArgumentError('El banco va de 1 a 60 caracteres');
  }
  if (n.isEmpty || n.length > 60) {
    throw ArgumentError('El nombre va de 1 a 60 caracteres');
  }
  return Tarjeta(
    id: id,
    libroId: libroId,
    nombre: n,
    banco: b,
    origen: OrigenDato.capturado,
  );
}

/// Alta de un beneficio **capturado a mano** (`capturado`, no verificado).
/// Como el servidor: descripción de 1 a 80 caracteres, sin "\$" ni números de
/// cuatro dígitos (no son para cifras ni números de tarjeta), y la vigencia
/// empieza en [desde].
BeneficioTarjeta beneficioCapturado({
  required String id,
  required String tarjetaId,
  required TipoBeneficio tipo,
  required String descripcion,
  required Fecha desde,
  Fecha? hasta,
}) {
  final d = descripcion.trim();
  if (d.isEmpty || d.length > 80) {
    throw ArgumentError('La descripción va de 1 a 80 caracteres');
  }
  if (d.contains(r'$') || RegExp(r'[0-9]{4}').hasMatch(d)) {
    throw ArgumentError(
      r'La descripción no lleva "$" ni números de cuatro dígitos',
    );
  }
  if (hasta != null && hasta.antesDe(desde)) {
    throw ArgumentError('La vigencia termina antes de empezar');
  }
  return BeneficioTarjeta(
    id: id,
    tarjetaId: tarjetaId,
    tipo: tipo,
    descripcion: d,
    desde: desde,
    hasta: hasta,
    origen: OrigenDato.capturado,
  );
}
