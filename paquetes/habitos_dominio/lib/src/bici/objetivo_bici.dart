/// B1.4 · Objetivo «Bicicleta»: **meta mensual de salidas, sin racha semanal**
/// (4.11, PB-06). Una salida depende del clima y del camino: una racha
/// semanal se rompería cada vez que llueve y empujaría a salir con mal
/// tiempo. Una salida que no sale por clima o seguridad se marca `omitida` con
/// su motivo y **no genera mensaje de ruptura**.
library;

import '../fecha.dart';
import '../objetivos.dart';
import 'mensajes_bici.dart';
import 'reglas_bici.dart';
import 'tipos_bici.dart';

/// Cómo se crea el objetivo (`hab_objetivos`): tipo `meta`, sin racha.
class ObjetivoBici {
  static const titulo = 'Bicicleta';
  static const tipo = TipoObjetivo.meta;

  /// «Salidas del mes»; el valor sale de `ReglasBicicleta.metaMensual`.
  static const unidad = 'salidas del mes';

  /// El objetivo pasa la validación de objetivos de Hábitos.
  static List<String> validar({
    ReglasBicicleta reglas = const ReglasBicicleta(),
  }) => validarObjetivo(
    titulo: titulo,
    tipo: tipo,
    metaValor: reglas.metaMensual,
  );
}

class AvanceMensualBici {
  const AvanceMensualBici({
    required this.anio,
    required this.mes,
    required this.salidas,
    required this.meta,
  });

  final int anio;
  final int mes;

  /// Salidas del mes (hechas o parciales; una omitida no suma, pero tampoco
  /// resta ni rompe nada).
  final int salidas;
  final int meta;

  bool get cumplida => salidas >= meta;
  int get faltan => cumplida ? 0 : meta - salidas;

  /// No existe racha semanal: una semana sin salida no produce ningún mensaje
  /// de ruptura.
  bool get hayRachaSemanal => false;
}

/// Salidas del mes de [mes] (cualquier día del mes).
AvanceMensualBici avanceMensual({
  required List<Salida> salidas,
  required DateTime mes,
  ReglasBicicleta reglas = const ReglasBicicleta(),
}) {
  final m = soloDia(mes);
  final n = salidas
      .where(
        (s) =>
            s.cuenta &&
            soloDia(s.fecha).year == m.year &&
            soloDia(s.fecha).month == m.month,
      )
      .length;
  return AvanceMensualBici(
    anio: m.year,
    mes: m.month,
    salidas: n,
    meta: reglas.metaMensual,
  );
}

/// El mensaje al omitir una salida: siempre el mismo, sin culpa y **nunca** el
/// de ruptura de racha.
String mensajeAlOmitir(MotivoOmision? motivo) => MensajesBici.noSalio;
