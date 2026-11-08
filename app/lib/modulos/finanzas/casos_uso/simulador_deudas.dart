/// Arma las deudas del libro para el simulador (Fase 8, bloque 2). Lee solo
/// lo que ya está en el libro; lo que no está queda en `null` (el simulador
/// dice "falta dato" y no estima). Nada de esto sale a la IA (D3).
library;

import 'package:finanzas_dominio/finanzas_dominio.dart';

import '../pantallas/fase2/ayuda_fase2.dart' show proximoPagoDe;

/// Las deudas activas con saldo del [libroId], listas para simular.
List<DeudaSimulable> deudasSimulables(
  DatosFinanzas datos,
  String libroId,
  Fecha hoy,
) {
  final lista = <DeudaSimulable>[];
  for (final d in datos.deudasDe(libroId)) {
    if (!d.activa) continue;
    final saldo = saldoDeDeuda(datos, d);
    if (saldo != null && saldo <= 0) continue;
    final estado = datos.ultimoEstadoDeCuenta(d.id);
    final proximo = proximoPagoDe(datos, d, hoy);
    // Una deuda con costo sin tasa capturada no se estima.
    final tasa = d.tipo == TipoDeuda.conCosto
        ? (d.tasaAnualPuntosBase > 0 ? d.tasaAnualPuntosBase : null)
        : 0;
    lista.add(
      DeudaSimulable(
        id: d.id,
        nombre: d.titulo,
        saldo: saldo,
        tasaAnualPuntosBase: tasa,
        minimoMensual: _minimoMensual(d, estado),
        diasParaVencer: proximo == null ? null : hoy.diasHasta(proximo.fecha),
      ),
    );
  }
  return lista;
}

int? _minimoMensual(Deuda d, EstadoDeCuenta? estado) {
  // Tarjeta: el mínimo del último estado de cuenta ya es mensual.
  if (estado != null && estado.pagoMinimo > 0) return estado.pagoMinimo;
  final monto = d.minimo > 0 ? d.minimo : d.abono;
  if (monto <= 0) return null;
  try {
    return dividirRedondeando(
      Equivalente.de(monto, d.frecuencia).anualCentavos,
      12,
    );
  } on ArgumentError {
    return null; // frecuencia diaria sin días activos: no se adivina
  }
}
