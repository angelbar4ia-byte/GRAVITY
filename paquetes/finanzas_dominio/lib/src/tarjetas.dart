/// Tarjetas y sus beneficios (Fase 8, bloque 2). Dart puro.
///
/// Reglas: ninguna cifra se inventa; lo que la persona escribe a mano queda
/// marcado como [OrigenDato.capturado] (no verificado) y solo pasa a
/// [OrigenDato.verificado] cuando viene de una fuente comprobada (estado de
/// cuenta leído en la laptop). Nada de esto va a la IA ni a las bocinas (D3).
library;

import 'fecha.dart';

/// De dónde salió un dato.
enum OrigenDato {
  /// Lo escribió la persona; no se ha comprobado.
  capturado('capturado', 'Capturado, no verificado'),

  /// Viene de una fuente comprobada (estado de cuenta).
  verificado('verificado', 'Verificado');

  const OrigenDato(this.clave, this.etiqueta);
  final String clave;
  final String etiqueta;

  static OrigenDato deClave(String? clave) =>
      clave == 'verificado' ? verificado : capturado;
}

enum TipoBeneficio {
  puntos('puntos', 'Puntos'),
  cashback('cashback', 'Cashback'),
  mesesSinIntereses('meses_sin_intereses', 'Meses sin intereses');

  const TipoBeneficio(this.clave, this.etiqueta);
  final String clave;
  final String etiqueta;

  static TipoBeneficio? deClave(String? clave) {
    for (final t in values) {
      if (t.clave == clave) return t;
    }
    return null;
  }
}

class BeneficioTarjeta {
  const BeneficioTarjeta({
    required this.id,
    required this.tarjetaId,
    required this.tipo,
    required this.descripcion,
    required this.desde,
    this.hasta,
    this.origen = OrigenDato.capturado,
  });

  final String id;
  final String tarjetaId;
  final TipoBeneficio tipo;
  final String descripcion;

  /// Vigencia: el inicio es obligatorio (como en el servidor).
  final Fecha desde;
  final Fecha? hasta;
  final OrigenDato origen;

  bool get esVerificado => origen == OrigenDato.verificado;

  /// Vigente en [hoy].
  bool vigenteEn(Fecha hoy) {
    if (hoy.antesDe(desde)) return false;
    if (hasta != null && hoy.despuesDe(hasta!)) return false;
    return true;
  }
}

class Tarjeta {
  const Tarjeta({
    required this.id,
    required this.libroId,
    required this.nombre,
    this.banco,
    this.origen = OrigenDato.capturado,
  });

  final String id;

  /// Libro de la persona dueña (D19): de ahí sale quién la ve.
  final String libroId;
  final String nombre;
  final String? banco;
  final OrigenDato origen;

  bool get esVerificada => origen == OrigenDato.verificado;
}
