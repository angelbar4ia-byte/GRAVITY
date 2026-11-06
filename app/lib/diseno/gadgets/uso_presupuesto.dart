/// Cuánto se ha usado de un presupuesto y en qué semáforo está (FINANZAS 5.6 bis
/// punto 10; especificación de la Fase 1, regla 40).
///
/// Es lógica de presentación, pura y sin Flutter, para que el medidor y las
/// tablas de Finanzas digan lo mismo. Los umbrales por defecto son los de
/// `Umbrales.porDefecto` de `finanzas_dominio` (partida verde hasta 80 %, ámbar
/// hasta 100 %, rojo arriba) y se comparan con la **fracción exacta**, nunca con
/// el porcentaje redondeado.
library;

import 'package:flutter/foundation.dart';

import '../componentes/semaforo.dart';

/// Puntos base en 100 % (privado: `finanzas_dominio` exporta el suyo).
const int _puntosBaseEnCien = 10000;

@immutable
class UsoPresupuesto {
  const UsoPresupuesto({
    required this.asignadoCentavos,
    required this.gastadoCentavos,
    this.ambarDesdePuntosBase = 8000,
    this.rojoArribaDePuntosBase = 10000,
  }) : assert(
         ambarDesdePuntosBase <= rojoArribaDePuntosBase,
         'El ámbar empieza antes que el rojo',
       );

  /// Lo asignado a la partida (con su arrastre), en centavos.
  final int asignadoCentavos;

  /// Lo gastado, en centavos. Un reembolso mayor que el gasto lo deja negativo.
  final int gastadoCentavos;

  /// Arriba de esta fracción (en puntos base) la partida pasa a ámbar.
  final int ambarDesdePuntosBase;

  /// Arriba de esta fracción (en puntos base) la partida pasa a rojo.
  final int rojoArribaDePuntosBase;

  /// Si hay presupuesto contra el cual medir.
  bool get conPresupuesto => asignadoCentavos > 0;

  /// Lo que queda (negativo si se excedió).
  int get restanteCentavos => asignadoCentavos - gastadoCentavos;

  /// Si se gastó más de lo asignado.
  bool get excedido => restanteCentavos < 0;

  /// Porcentaje usado, **redondeado hacia arriba** al entero: así nunca se ve
  /// por debajo de un umbral que ya se cruzó (80.2 % se ve "81 %", en ámbar;
  /// 100.1 % se ve "101 %", en rojo). `null` si no hay presupuesto.
  int? get porcentaje {
    if (!conPresupuesto) return null;
    if (gastadoCentavos <= 0) return 0;
    return (gastadoCentavos * 100 + asignadoCentavos - 1) ~/ asignadoCentavos;
  }

  /// Parte llena del medidor, de 0 a 1.
  double get fraccion {
    if (!conPresupuesto) return gastadoCentavos > 0 ? 1 : 0;
    if (gastadoCentavos <= 0) return 0;
    return (gastadoCentavos / asignadoCentavos).clamp(0.0, 1.0);
  }

  /// Semáforo con la fracción exacta (como `semaforoPartida` del dominio).
  EstadoSemaforo get estado {
    if (!conPresupuesto) {
      return gastadoCentavos > 0 ? EstadoSemaforo.rojo : EstadoSemaforo.verde;
    }
    if (_compararCon(rojoArribaDePuntosBase) > 0) return EstadoSemaforo.rojo;
    if (_compararCon(ambarDesdePuntosBase) > 0) return EstadoSemaforo.ambar;
    return EstadoSemaforo.verde;
  }

  /// Texto del semáforo: el estado nunca depende solo del color.
  String get textoEstado => switch (estado) {
    EstadoSemaforo.verde => conPresupuesto ? 'Bien' : 'Sin gasto',
    EstadoSemaforo.ambar =>
      restanteCentavos == 0 ? 'Al límite' : 'Cerca del límite',
    EstadoSemaforo.rojo => 'Excedido',
  };

  /// "62 %", o "Sin presupuesto".
  String get textoPorcentaje {
    final p = porcentaje;
    return p == null ? 'Sin presupuesto' : '$p %';
  }

  /// gastado ÷ asignado comparado con [puntosBase] ÷ 10 000, en enteros.
  int _compararCon(int puntosBase) => (gastadoCentavos * _puntosBaseEnCien)
      .compareTo(puntosBase * asignadoCentavos);

  @override
  bool operator ==(Object other) =>
      other is UsoPresupuesto &&
      other.asignadoCentavos == asignadoCentavos &&
      other.gastadoCentavos == gastadoCentavos &&
      other.ambarDesdePuntosBase == ambarDesdePuntosBase &&
      other.rojoArribaDePuntosBase == rojoArribaDePuntosBase;

  @override
  int get hashCode => Object.hash(
    asignadoCentavos,
    gastadoCentavos,
    ambarDesdePuntosBase,
    rojoArribaDePuntosBase,
  );

  @override
  String toString() =>
      'UsoPresupuesto($gastadoCentavos de $asignadoCentavos: $textoPorcentaje, '
      '${estado.name})';
}
