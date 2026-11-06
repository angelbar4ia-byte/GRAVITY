/// Nombres y cálculos pequeños que comparten las pantallas de la Fase 2.
library;

import 'package:finanzas_dominio/finanzas_dominio.dart'
    hide
        Semaforo,
        formatearCentavos,
        TipoLibro,
        VisibilidadLibro,
        puntosBaseEnCien,
        BolsaAhorro,
        NivelFondo,
        NivelAlerta;

String nombreClaseDeuda(ClaseDeuda? c) => switch (c) {
  ClaseDeuda.tarjeta => 'Tarjeta',
  ClaseDeuda.prestamo => 'Préstamo',
  ClaseDeuda.credito => 'Crédito',
  ClaseDeuda.msi => 'MSI',
  ClaseDeuda.familiar => 'Familiar',
  null => 'Deuda',
};

/// Próximo pago de una deuda: su fecha ajustada y el monto a pagar (el pago
/// para no generar intereses del último estado de cuenta, o el mínimo, o el
/// abono planeado).
({Fecha fecha, int monto, Vencimiento? vencimiento})? proximoPagoDe(
  DatosFinanzas datos,
  Deuda d,
  Fecha hoy,
) {
  final estado = datos.ultimoEstadoDeCuenta(d.id);
  if (estado != null && !estado.fechaLimitePago.antesDe(hoy)) {
    return (
      fecha: estado.fechaLimitePago,
      monto: estado.pagoSinIntereses,
      vencimiento: null,
    );
  }
  final pagos = d.pagosEntre(hoy, hoy.sumarDias(400), datos.calendario);
  if (pagos.isEmpty) return null;
  final p = pagos.first;
  final monto = d.minimo > 0 ? d.minimo : d.abono;
  return (
    fecha: p.ajustada,
    monto: monto,
    vencimiento: Vencimiento(
      origen: OrigenOcurrencia.deuda,
      origenId: d.id,
      concepto: d.titulo,
      fecha: p,
      monto: monto,
    ),
  );
}

/// Día del corte de una tarjeta en el mes de [ref] (0 = último día).
Fecha? corteEnMes(Deuda d, int anio, int mes) {
  final dia = d.corteDia;
  if (dia == null) return null;
  final ultimo = Fecha.diasDelMes(anio, mes);
  return Fecha(anio, mes, dia == 0 || dia > ultimo ? ultimo : dia);
}
