/// Calendario de vencimientos (Fase 2): las próximas 8 semanas con los pagos
/// de deudas, los cortes y fechas límite de tarjetas, y lo que sumarán los MSI
/// en los próximos meses.
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
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../diseno/diseno.dart';
import '../../estado/proveedores.dart';
import '../comunes.dart';
import 'ayuda_fase2.dart';

/// Las semanas del calendario (pura, para probarla).
List<SemanaVencimientos> semanasDeVencimientos(
  ContextoFinanzas c, {
  int semanas = 8,
}) {
  final datos = c.datos;
  final primera = Semana.de(c.hoy);
  final ultima = primera.mas(semanas - 1);
  final porSemana = <Semana, List<EventoVencimiento>>{};

  void agregar(Fecha f, EventoVencimiento e) {
    final s = Semana.de(f);
    if (s.inicio.antesDe(primera.inicio) || s.inicio.despuesDe(ultima.inicio)) {
      return;
    }
    porSemana.putIfAbsent(s, () => []).add(e);
  }

  for (final d in datos.deudasDe(c.libroId)) {
    if (!d.activa) continue;
    final saldo = saldoDeDeuda(datos, d);
    if (saldo != null && saldo <= 0) continue;
    final monto = d.minimo > 0 ? d.minimo : d.abono;
    for (final p in d.pagosEntre(c.hoy, ultima.fin, datos.calendario)) {
      final hecha = datos.ocurrencias.any(
        (o) =>
            o.origenId == d.id &&
            o.fechaProgramada == p.programada &&
            o.estado == EstadoOcurrencia.cumplida,
      );
      if (hecha) continue;
      agregar(
        p.ajustada,
        EventoVencimiento(
          tipo: d.clase == ClaseDeuda.msi
              ? TipoVencimiento.msi
              : TipoVencimiento.pago,
          titulo: d.titulo,
          diaTexto: textoDiaMes(p.ajustada),
          montoCentavos: monto,
        ),
      );
    }
    final e = datos.ultimoEstadoDeCuenta(d.id);
    if (e != null && !e.fechaLimitePago.antesDe(c.hoy)) {
      agregar(
        e.fechaLimitePago,
        EventoVencimiento(
          tipo: TipoVencimiento.limite,
          titulo: d.titulo,
          diaTexto: textoDiaMes(e.fechaLimitePago),
          montoCentavos: e.pagoSinIntereses,
        ),
      );
    }
    for (var i = 0; i < 3; i++) {
      final m0 = c.hoy.mes - 1 + i;
      final corte = corteEnMes(d, c.hoy.anio + m0 ~/ 12, m0 % 12 + 1);
      if (corte != null && !corte.antesDe(c.hoy)) {
        agregar(
          corte,
          EventoVencimiento(
            tipo: TipoVencimiento.corte,
            titulo: d.titulo,
            diaTexto: textoDiaMes(corte),
          ),
        );
      }
    }
  }
  return [
    for (var i = 0; i < semanas; i++)
      SemanaVencimientos(
        etiqueta: textoSemana(primera.mas(i)),
        actual: i == 0,
        eventos: porSemana[primera.mas(i)] ?? const [],
      ),
  ];
}

/// Lo que sumarán las mensualidades de MSI en los próximos 3 meses.
List<TotalMsiDelMes> totalesMsi(ContextoFinanzas c) {
  const meses = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];
  final datos = c.datos;
  final lista = <TotalMsiDelMes>[];
  for (var i = 0; i < 3; i++) {
    final m0 = c.hoy.mes - 1 + i;
    final mes = m0 % 12;
    var total = 0;
    for (final m in datos.msiDe(c.libroId)) {
      final d = datos.deudas.where((x) => x.id == m.deudaId).firstOrNull;
      if (d == null || !d.activa) continue;
      final saldo = saldoDeDeuda(datos, d) ?? 0;
      if (saldo <= 0 || d.abono <= 0) continue;
      final restantes = (saldo / d.abono).ceil();
      if (restantes > i) {
        total += d.abono < saldo - i * d.abono ? d.abono : saldo - i * d.abono;
      }
    }
    if (total > 0) lista.add(TotalMsiDelMes(meses[mes], total));
  }
  return lista;
}

class VistaVencimientos extends ConsumerWidget {
  const VistaVencimientos({super.key, required this.contexto});

  final ContextoFinanzas contexto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semanas = semanasDeVencimientos(contexto);
    final hay = semanas.any((s) => s.eventos.isNotEmpty);
    return ListView(
      key: const ValueKey('vencimientos-lista'),
      padding: const EdgeInsets.all(16),
      children: [
        if (!hay)
          const EstadoVacio(
            mensaje: 'Sin vencimientos en las próximas 8 semanas.',
            icono: Icons.event_available_outlined,
          )
        else
          LineaVencimientos(semanas: semanas, totalesMsi: totalesMsi(contexto)),
      ],
    );
  }
}
