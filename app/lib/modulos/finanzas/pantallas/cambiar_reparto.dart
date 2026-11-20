/// Entradas a «Cambiar reparto» desde los movimientos (teléfono: menú de la
/// fila; laptop: botón del detalle). La hoja es la misma de «Repartir ingreso»
/// (`registro/hoja_repartir_ingreso.dart`): en un ingreso ya repartido se abre
/// con el reparto vigente editable y el botón «Guardar cambios»
/// (`docs/specs/fase-8-finanzas-dispersion.md`, P5).
library;

import 'package:finanzas_dominio/finanzas_dominio.dart'
    hide Semaforo, formatearCentavos, TipoLibro, puntosBaseEnCien;
import 'package:flutter/widgets.dart';

import '../estado/proveedores.dart';
import 'registro/hoja_repartir_ingreso.dart';

/// `true` si [m] es un ingreso confirmado, sin anular y con un reparto
/// aplicado (confirmado o automático) que la persona puede cambiar con su
/// permiso de escribir. El servidor vuelve a verificar todo.
bool sePuedeCambiarReparto(
  Movimiento m,
  LibroMovimientos vista,
  ContextoFinanzas c,
  List<Dispersion> repartos,
) =>
    c.puedeEscribir &&
    m.tipo == TipoMovimiento.ingreso &&
    vista.contraasientoDe(m.id) == null &&
    vista.estadoDe(m.id) == EstadoMovimiento.confirmado &&
    repartos.any((x) => x.movimientoId == m.id && x.estado.aplicada);

/// Abre la hoja del ingreso [m] para cambiar su reparto.
Future<void> abrirCambiarReparto(
  BuildContext context,
  ContextoFinanzas c,
  Movimiento m,
) => mostrarHojaRepartir(context, libroId: c.libroId, movimientoId: m.id);
