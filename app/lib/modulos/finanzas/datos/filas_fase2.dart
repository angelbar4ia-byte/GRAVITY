/// Filas de las tablas de la Fase 2 (`fin_msi`, `fin_estados_cuenta`,
/// `fin_bolsas_ahorro`, `fin_aportaciones_ahorro`, `fin_retiros_ahorro`).
/// Las columnas que pone el servidor (`recibido_en`, `registrado_por`,
/// `pendiente_centavos`, `confirmada_por`, `confirmada_en`) no se envían.
library;

import 'package:finanzas_dominio/finanzas_dominio.dart';

import 'filas.dart';

Map<String, Object?> filaMsi(Msi m, {required String hogarId}) => {
  'id': m.id,
  'hogar_id': hogarId,
  'libro_id': m.libroId,
  'deuda_id': m.deudaId,
  'tarjeta_deuda_id': m.tarjetaDeudaId,
  'cuenta_pasivo_id': m.cuentaPasivoId,
  'comercio': m.comercio,
  'descripcion': m.descripcion,
  'fecha_compra': fechaIso(m.fechaCompra),
  'monto_total_centavos': m.montoTotal,
  'mensualidades': m.mensualidades,
  'activo': m.activo,
};

Msi msiDeFila(Map<String, dynamic> f) => Msi(
  id: '${f['id']}',
  libroId: '${f['libro_id']}',
  deudaId: '${f['deuda_id']}',
  tarjetaDeudaId: texto(f['tarjeta_deuda_id']),
  cuentaPasivoId: '${f['cuenta_pasivo_id']}',
  comercio: texto(f['comercio']),
  descripcion: texto(f['descripcion']),
  fechaCompra: fechaReq(f['fecha_compra']),
  montoTotal: entero(f['monto_total_centavos']),
  mensualidades: entero(f['mensualidades']),
  activo: booleano(f['activo'], true),
);

Map<String, Object?> filaEstadoDeCuenta(
  EstadoDeCuenta e, {
  required String hogarId,
}) => {
  'id': e.id,
  'hogar_id': hogarId,
  'libro_id': e.libroId,
  'deuda_id': e.deudaId,
  'fecha_corte': fechaIso(e.fechaCorte),
  'fecha_limite_pago': fechaIso(e.fechaLimitePago),
  'saldo_al_corte_centavos': e.saldoAlCorte,
  'pago_minimo_centavos': e.pagoMinimo,
  'pago_sin_intereses_centavos': e.pagoSinIntereses,
  'intereses_centavos': e.intereses,
  'cargos_centavos': e.cargos,
  'tasa_declarada_pb': e.tasaDeclaradaPb,
  'cat_pb': e.catPb,
  'via': 'manual',
  'registrado_en': horaIso(e.registradoEn),
};

EstadoDeCuenta estadoDeCuentaDeFila(Map<String, dynamic> f) => EstadoDeCuenta(
  id: '${f['id']}',
  libroId: '${f['libro_id']}',
  deudaId: '${f['deuda_id']}',
  fechaCorte: fechaReq(f['fecha_corte']),
  fechaLimitePago: fechaReq(f['fecha_limite_pago']),
  saldoAlCorte: entero(f['saldo_al_corte_centavos']),
  pagoMinimo: entero(f['pago_minimo_centavos']),
  pagoSinIntereses: entero(f['pago_sin_intereses_centavos']),
  intereses: entero(f['intereses_centavos']),
  cargos: entero(f['cargos_centavos']),
  tasaDeclaradaPb: enteroONulo(f['tasa_declarada_pb']),
  catPb: enteroONulo(f['cat_pb']),
  registradoEn:
      horaDe(f['registrado_en']) ?? DateTime.fromMillisecondsSinceEpoch(0),
);

Map<String, Object?> filaBolsa(BolsaAhorro b, {required String hogarId}) => {
  'id': b.id,
  'hogar_id': hogarId,
  'libro_id': b.libroId,
  'nombre': b.nombre,
  'tipo': b.tipo.clave,
  'cuenta_id': b.cuentaId,
  'meta_centavos': b.meta,
  'monto_anual_centavos': b.montoAnual,
  'fecha_meta': b.fechaMeta == null ? null : fechaIso(b.fechaMeta!),
  'nivel_meta': b.nivelMeta,
  'aporte_fijo_centavos': b.aporteFijo,
  'aporte_pb': b.aportePb,
  'metodos': [for (final m in b.metodos) m.clave],
  'redondeo_multiplo_centavos': b.redondeoMultiplo,
  'reto_base_centavos': b.retoBase,
  'prioridad': b.prioridad,
  'activa': b.activa,
};

BolsaAhorro bolsaDeFila(Map<String, dynamic> f) => BolsaAhorro(
  id: '${f['id']}',
  libroId: '${f['libro_id']}',
  nombre: '${f['nombre']}',
  tipo: TipoBolsaAhorro.deClave('${f['tipo']}'),
  cuentaId: '${f['cuenta_id']}',
  meta: enteroONulo(f['meta_centavos']),
  montoAnual: enteroONulo(f['monto_anual_centavos']),
  fechaMeta: fechaDe(f['fecha_meta']),
  nivelMeta: enteroONulo(f['nivel_meta']),
  aporteFijo: enteroONulo(f['aporte_fijo_centavos']),
  aportePb: enteroONulo(f['aporte_pb']),
  metodos: [
    for (final m in (f['metodos'] as List? ?? const []))
      ?MetodoAhorro.deClave('$m'),
  ],
  redondeoMultiplo: entero(f['redondeo_multiplo_centavos'], 1000),
  retoBase: enteroONulo(f['reto_base_centavos']),
  prioridad: entero(f['prioridad'], 1),
  activa: booleano(f['activa'], true),
);

Map<String, Object?> filaAportacion(
  AportacionAhorro a, {
  required String hogarId,
}) => {
  'id': a.id,
  'hogar_id': hogarId,
  'libro_id': a.libroId,
  'semana_id': a.semanaId,
  'bolsa_id': a.bolsaId,
  'sugerido_centavos': a.sugerido,
  'aportado_centavos': a.aportado,
  'estado': a.estado.name,
  'movimiento_id': a.movimientoId,
};

AportacionAhorro aportacionDeFila(Map<String, dynamic> f) => AportacionAhorro(
  id: '${f['id']}',
  libroId: '${f['libro_id']}',
  semanaId: '${f['semana_id']}',
  bolsaId: '${f['bolsa_id']}',
  sugerido: entero(f['sugerido_centavos']),
  aportado: entero(f['aportado_centavos']),
  estado: EstadoAportacion.deClave('${f['estado']}'),
  movimientoId: texto(f['movimiento_id']),
);

Map<String, Object?> filaRetiro(RetiroAhorro r, {required String hogarId}) => {
  'id': r.id,
  'hogar_id': hogarId,
  'libro_id': r.libroId,
  'bolsa_id': r.bolsaId,
  'movimiento_id': r.movimientoId,
  'tipo': nombreEnum(r.tipo),
  'motivo': r.motivo,
  'bolsa_destino_id': r.bolsaDestinoId,
  'registrado_en': horaIso(r.registradoEn),
};

RetiroAhorro retiroDeFila(Map<String, dynamic> f) => RetiroAhorro(
  id: '${f['id']}',
  libroId: '${f['libro_id']}',
  bolsaId: '${f['bolsa_id']}',
  movimientoId: '${f['movimiento_id']}',
  tipo: enumDe(TipoRetiro.values, f['tipo']),
  motivo: texto(f['motivo']),
  bolsaDestinoId: texto(f['bolsa_destino_id']),
  registradoEn:
      horaDe(f['registrado_en']) ?? DateTime.fromMillisecondsSinceEpoch(0),
);
