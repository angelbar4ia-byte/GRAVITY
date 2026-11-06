/// Datos guardados de la Fase 2: compras a meses (MSI), estados de cuenta,
/// bolsas de ahorro, aportaciones semanales y retiros. Sin dinero inventado:
/// todo lo captura la persona. El saldo de una bolsa o de una deuda sale del
/// libro (cuenta de ahorro o pasivo), nunca se guarda.
library;

import 'ahorro.dart';
import 'fecha.dart';

/// Compra a meses sin intereses de un libro (`fin_msi`).
class Msi {
  final String id;
  final String libroId;
  final String deudaId;
  final String? tarjetaDeudaId;
  final String cuentaPasivoId;
  final String? comercio;
  final String? descripcion;
  final Fecha fechaCompra;
  final int montoTotal;
  final int mensualidades;
  final bool activo;

  const Msi({
    required this.id,
    required this.libroId,
    required this.deudaId,
    this.tarjetaDeudaId,
    required this.cuentaPasivoId,
    this.comercio,
    this.descripcion,
    required this.fechaCompra,
    required this.montoTotal,
    required this.mensualidades,
    this.activo = true,
  });
}

/// Estado de cuenta capturado a mano (`fin_estados_cuenta`, solo agregar: para
/// un mismo corte vale el registro más reciente).
class EstadoDeCuenta {
  final String id;
  final String libroId;
  final String deudaId;
  final Fecha fechaCorte;
  final Fecha fechaLimitePago;
  final int saldoAlCorte;
  final int pagoMinimo;
  final int pagoSinIntereses;
  final int intereses;
  final int cargos;
  final int? tasaDeclaradaPb;
  final int? catPb;
  final DateTime registradoEn;

  const EstadoDeCuenta({
    required this.id,
    required this.libroId,
    required this.deudaId,
    required this.fechaCorte,
    required this.fechaLimitePago,
    required this.saldoAlCorte,
    required this.pagoMinimo,
    required this.pagoSinIntereses,
    this.intereses = 0,
    this.cargos = 0,
    this.tasaDeclaradaPb,
    this.catPb,
    required this.registradoEn,
  });
}

/// Tipo de bolsa (`fin_bolsas_ahorro.tipo`).
enum TipoBolsaAhorro {
  fondoEmergencia('fondo_emergencia'),
  reserva('reserva'),
  metaFecha('meta_fecha'),
  metaLibre('meta_libre');

  const TipoBolsaAhorro(this.clave);
  final String clave;

  static TipoBolsaAhorro deClave(String c) =>
      values.firstWhere((t) => t.clave == c);
}

/// Bolsa de ahorro: una cuenta de tipo ahorro con su configuración.
class BolsaAhorro {
  final String id;
  final String libroId;
  final String nombre;
  final TipoBolsaAhorro tipo;
  final String cuentaId;
  final int? meta;
  final int? montoAnual;
  final Fecha? fechaMeta;
  final int? nivelMeta;
  final int? aporteFijo;
  final int? aportePb;
  final List<MetodoAhorro> metodos;
  final int redondeoMultiplo;
  final int? retoBase;
  final int prioridad;
  final bool activa;

  const BolsaAhorro({
    required this.id,
    required this.libroId,
    required this.nombre,
    required this.tipo,
    required this.cuentaId,
    this.meta,
    this.montoAnual,
    this.fechaMeta,
    this.nivelMeta,
    this.aporteFijo,
    this.aportePb,
    this.metodos = const [],
    this.redondeoMultiplo = 1000,
    this.retoBase,
    this.prioridad = 1,
    this.activa = true,
  });

  BolsaAhorro copiar({bool? activa, int? meta, int? nivelMeta}) => BolsaAhorro(
    id: id,
    libroId: libroId,
    nombre: nombre,
    tipo: tipo,
    cuentaId: cuentaId,
    meta: meta ?? this.meta,
    montoAnual: montoAnual,
    fechaMeta: fechaMeta,
    nivelMeta: nivelMeta ?? this.nivelMeta,
    aporteFijo: aporteFijo,
    aportePb: aportePb,
    metodos: metodos,
    redondeoMultiplo: redondeoMultiplo,
    retoBase: retoBase,
    prioridad: prioridad,
    activa: activa ?? this.activa,
  );
}

/// Estado de una aportación semanal (`fin_aportaciones_ahorro.estado`).
enum EstadoAportacion {
  propuesta,
  confirmada,
  pospuesta,
  omitida;

  static EstadoAportacion deClave(String c) =>
      values.firstWhere((e) => e.name == c);
}

/// Reparto semanal por bolsa. Lo no aportado queda pendiente sin castigo.
class AportacionAhorro {
  final String id;
  final String libroId;
  final String semanaId;
  final String bolsaId;
  final int sugerido;
  final int aportado;
  final EstadoAportacion estado;
  final String? movimientoId;

  const AportacionAhorro({
    required this.id,
    required this.libroId,
    required this.semanaId,
    required this.bolsaId,
    required this.sugerido,
    this.aportado = 0,
    this.estado = EstadoAportacion.propuesta,
    this.movimientoId,
  });

  int get pendiente => sugerido > aportado ? sugerido - aportado : 0;
}

/// Retiro de una bolsa (solo agregar).
class RetiroAhorro {
  final String id;
  final String libroId;
  final String bolsaId;
  final String movimientoId;
  final TipoRetiro tipo;
  final String? motivo;
  final String? bolsaDestinoId;
  final DateTime registradoEn;

  const RetiroAhorro({
    required this.id,
    required this.libroId,
    required this.bolsaId,
    required this.movimientoId,
    required this.tipo,
    this.motivo,
    this.bolsaDestinoId,
    required this.registradoEn,
  });
}
