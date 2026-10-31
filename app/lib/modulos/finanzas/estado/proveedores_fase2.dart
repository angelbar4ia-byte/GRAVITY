/// Estado de la Fase 2 de Finanzas: los casos de uso de deudas y ahorro, la
/// fuente de vencimientos de los recordatorios locales y el detalle de los
/// avisos de la bandeja (D20).
library;

import 'package:finanzas_dominio/finanzas_dominio.dart' as dom;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import '../../../app/avisos/con_avisos.dart' show servicioAvisosProvider;
import '../../../nucleo/avisos/aviso.dart';
import '../../../nucleo/avisos/proveedores_avisos.dart';
import '../../../nucleo/avisos/recordatorios.dart' as av;
import '../casos_uso/servicio_fase2.dart';
import '../datos/ids.dart';
import '../pantallas/detalle_aviso.dart';
import 'proveedores.dart';

/// Casos de uso de deudas y ahorro. Al registrar un pago retira los avisos de
/// esa ocurrencia (regla 38).
final servicioFase2Provider = Provider<ServicioDeudasAhorro>((ref) {
  return ServicioDeudasAhorro(
    ref.watch(servicioFinanzasProvider),
    alRegistrarPago: (objetoId, fecha) {
      try {
        final avisos = ref.read(servicioAvisosProvider);
        for (final clave in clavesDeAvisosDePago(objetoId, fecha)) {
          avisos.retirarPorClave(clave);
        }
      } catch (_) {
        // Retirar una notificación nunca debe impedir registrar el pago.
      }
    },
  );
});

/// Pagos de deudas de los próximos días con la copia local (no necesita
/// señal). El `objetoId` es el id de la ocurrencia; el límite de pago de una
/// tarjeta sale de su último estado de cuenta.
class FuenteVencimientosFinanzas implements av.FuenteDeVencimientos {
  const FuenteVencimientosFinanzas(this._datos);

  final dom.DatosFinanzas? Function() _datos;

  @override
  Future<List<av.Vencimiento>> proximos({
    required DateTime desde,
    required int dias,
  }) async {
    final d = _datos();
    if (d == null) return const [];
    final inicio = dom.Fecha.deDateTime(desde);
    final fin = inicio.sumarDias(dias);
    final lista = <av.Vencimiento>[];
    for (final libro in d.libros) {
      for (final v in dom.vencimientosEntre(d, libro.id, inicio, fin)) {
        if (v.origen != dom.OrigenOcurrencia.deuda) continue;
        final ocurrenciaId = idEstable(
          ClavesId.ocurrencia(
            libro.id,
            v.origen.name,
            v.origenId,
            '${v.fecha.programada}',
          ),
        );
        final hecha = d.ocurrencias.any(
          (o) =>
              o.id == ocurrenciaId && o.estado == dom.EstadoOcurrencia.cumplida,
        );
        if (hecha) continue;
        lista.add(
          av.Vencimiento(
            objetoId: ocurrenciaId,
            fecha: DateTime(
              v.fecha.ajustada.anio,
              v.fecha.ajustada.mes,
              v.fecha.ajustada.dia,
            ),
          ),
        );
      }
      for (final deuda in d.deudasDe(libro.id)) {
        final e = d.ultimoEstadoDeCuenta(deuda.id);
        if (e == null || !deuda.activa) continue;
        final l = e.fechaLimitePago;
        if (l.antesDe(inicio) || l.despuesDe(fin)) continue;
        lista.add(
          av.Vencimiento(
            objetoId: e.id,
            fecha: DateTime(l.anio, l.mes, l.dia),
            esLimiteDeTarjeta: true,
          ),
        );
      }
    }
    lista.sort((a, b) => a.fecha.compareTo(b.fecha));
    return lista;
  }
}

/// Lo que Finanzas pone en la plataforma: la fuente de vencimientos y el
/// detalle de la bandeja. El arranque los suma a los `overrides` de Riverpod.
final List<Override> sobrescriturasAvisosFinanzas = [
  fuenteDeVencimientosProvider.overrideWith(
    (ref) => FuenteVencimientosFinanzas(
      () => ref.read(repositorioFinanzasProvider).actual?.datos,
    ),
  ),
  detalleDeAvisoProvider.overrideWithValue(
    (BuildContext context, Object aviso) =>
        DetalleAvisoFinanzas(aviso: aviso as Aviso),
  ),
];
