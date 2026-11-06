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
import '../../../diseno/proveedores.dart' show montosOcultosProvider;
import '../datos/ids.dart';
import '../pantallas/fase2/ayuda_fase2.dart' show proximoPagoDe;
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

/// Texto de las consultas locales de Finanzas para la barra de órdenes
/// (`finanzas.resumen_semana`, `finanzas.proximos_pagos`,
/// `finanzas.ahorro_avance`; D3). Se arma con los datos locales y **nunca**
/// sale del equipo: ni a la IA en la nube ni a las bocinas. Con los montos
/// ocultos, el texto no lleva cifras. `null` si no hay libro propio que
/// leer (la barra solo abre la vista).
final consultaLocalFinanzasProvider =
    Provider<Future<String?> Function(String herramienta)>((ref) {
      return (String herramienta) async {
        try {
          // Si Finanzas aún no se carga en este equipo, se carga ahora.
          await ref.read(cargaFinanzasProvider.future);
        } catch (_) {
          return null;
        }
        final c = ref.read(contextoFinanzasProvider).value;
        if (c == null || c.libro == null || !c.esLibroPropio) return null;
        final ocultos = ref.read(montosOcultosProvider);
        String monto(int centavos) => dom.formatearCentavos(centavos);
        final semana = dom.Semana.de(c.hoy);
        switch (herramienta) {
          case 'finanzas.resumen_semana':
            final v = dom.vistaSemana(c.datos, c.libroId, semana, hoy: c.hoy);
            final ind = v.indicadores;
            final estado = switch (ind.remanente) {
              dom.Semaforo.verde => 'en verde',
              dom.Semaforo.ambar => 'en ámbar',
              dom.Semaforo.rojo => 'en rojo',
            };
            final cifra = ocultos
                ? ''
                : ' (${monto(v.planSemanal.remanente)} planeados)';
            return 'Esta semana el remanente va $estado$cifra. '
                '${ind.partidasDentro} de ${ind.totalPartidas} partidas '
                'dentro de su presupuesto.';
          case 'finanzas.proximos_pagos':
            final svc = ref.read(servicioFase2Provider);
            final pagos = <({String nombre, dom.Fecha fecha, int monto})>[];
            for (final r in svc.deudas(c.libroId)) {
              final p = proximoPagoDe(c.datos, r.deuda, c.hoy);
              if (p != null) {
                pagos.add((nombre: r.deuda.titulo, fecha: p.fecha, monto: p.monto));
              }
            }
            if (pagos.isEmpty) return 'No tienes pagos próximos registrados.';
            pagos.sort((a, b) => a.fecha.compareTo(b.fecha));
            final lineas = [
              for (final p in pagos.take(3))
                '${p.nombre} el ${p.fecha.dia}/${p.fecha.mes}'
                    '${ocultos ? '' : ' por ${monto(p.monto)}'}',
            ];
            return 'Próximos pagos: ${lineas.join('; ')}.';
          case 'finanzas.ahorro_avance':
            final f = ref.read(servicioFase2Provider).fondo(c.libroId, semana);
            if (f == null) return 'Aún no tienes un fondo de emergencia.';
            if (f.semanasDecimas == null) {
              return 'Tu fondo de emergencia aún no tiene un gasto esencial '
                  'calculado.';
            }
            return 'Tu fondo de emergencia cubre '
                '${dom.textoSemanasCubiertas(f.semanasDecimas!)} semanas'
                '${ocultos ? '' : ' (${monto(f.saldo)})'}.';
        }
        return null;
      };
    });
