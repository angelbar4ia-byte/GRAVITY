/// Ahorro automático al cierre de la semana (Fase 4, E16; decisión (c) de la
/// sección 11 de `docs/specs/fase-2-finanzas.md` y F4-3.5 del aporte de
/// Finanzas). Dart puro.
///
/// El cierre aplica, **en este orden**, los cuatro métodos que alimentan una
/// bolsa sin que la persona los capture (regla 25):
///
/// 1. **extras:** el porcentaje (`aportePb`, 20 % por omisión) de los
///    ingresos extra de la semana;
/// 2. **sobre:** lo no gastado de los sobres que no se arrastra (el excedente
///    sobre el tope de arrastre de 2 semanas de su monto, regla 32);
/// 3. **sobrante:** lo que queda del remanente real de la semana;
/// 4. **redondeo:** lo que falta para llegar al siguiente múltiplo en cada
///    gasto de la semana, **al final y solo si queda disponible**.
///
/// Todos salen del remanente real y se descuentan unos de otros, así que no
/// se aparta dos veces (regla 25) y **el redondeo nunca deja la semana en
/// negativo**. Con una deuda que recibe abono extra (regla 16) rige el mismo
/// límite que el reparto semanal: solo el `ahorroMinimoConDeuda` del remanente
/// y solo al colchón (el fondo de emergencia).
library;

import 'ahorro.dart';
import 'ahorro_datos.dart';
import 'datos_finanzas.dart';
import 'dinero.dart';
import 'libro.dart';
import 'plan_guardado.dart';
import 'semana.dart';
import 'seguimiento.dart';

/// De dónde sale un aporte automático del cierre, en el orden en que se
/// aplican.
enum OrigenAporte {
  extras(MetodoAhorro.porcentajeDeExtras, 'extras', 'Extras'),
  sobre(MetodoAhorro.sobrePorCategoria, 'sobre', 'Sobre'),
  sobrante(MetodoAhorro.sobranteSemanal, 'sobrante', 'Sobrante'),
  redondeo(MetodoAhorro.redondeo, 'redondeo', 'Redondeo');

  const OrigenAporte(this.metodo, this.clave, this.etiqueta);

  /// El método de la bolsa que lo activa.
  final MetodoAhorro metodo;

  /// Parte del id estable del movimiento.
  final String clave;

  /// Cómo se muestra el origen.
  final String etiqueta;
}

/// Un aporte automático: [monto] de [origen] a la bolsa [bolsaId].
class AporteDeCierre {
  final OrigenAporte origen;
  final String bolsaId;
  final int monto;

  const AporteDeCierre(this.origen, this.bolsaId, this.monto);

  @override
  String toString() => 'AporteDeCierre(${origen.clave}, $bolsaId, $monto)';
}

/// Resultado de [planearAhorroDeCierre].
class PlanAhorroDeCierre {
  /// Aportes mayores que cero, en el orden en que se aplican.
  final List<AporteDeCierre> aportes;

  /// Lo que queda del remanente después de los aportes (nunca negativo).
  final int disponibleFinal;

  PlanAhorroDeCierre(List<AporteDeCierre> aportes, this.disponibleFinal)
    : aportes = List.unmodifiable(aportes);

  static final PlanAhorroDeCierre vacio = PlanAhorroDeCierre(const [], 0);

  int get total => aportes.fold(0, (t, a) => t + a.monto);

  int aportadoA(String bolsaId) => aportes
      .where((a) => a.bolsaId == bolsaId)
      .fold(0, (t, a) => t + a.monto);

  int deOrigen(OrigenAporte origen) => aportes
      .where((a) => a.origen == origen)
      .fold(0, (t, a) => t + a.monto);
}

/// Porcentaje de los ingresos extra que se aparta por omisión (D25): 20 %.
/// Cada bolsa lo cambia con su `aportePb`.
const porcentajeDeExtrasPorOmision = 2000;

/// Planea el ahorro automático del cierre.
///
/// - [orden]: los ids de las bolsas en el orden de **prioridad** que eligió la
///   persona al cerrar (D25: se arrastran las bolsas para darles prioridad).
///   Las que no estén en la lista van después, por su `prioridad` y su id. El
///   **sobrante va a la primera** bolsa de la lista que tenga ese método.
///
/// - [remanente]: el remanente real de la semana (si es cero o negativo, no
///   hay nada que apartar: el plan queda vacío).
/// - [bolsas]: las bolsas del libro; solo cuentan las activas con el método
///   del origen en `metodos`, en el orden de su `prioridad` (y de su id).
/// - [extras]: ingresos extra de la semana; [sobre]: lo no gastado de los
///   sobres que pasa al remanente; [gastos]: cada gasto de la semana, para el
///   redondeo.
/// - [hayDeudaConExtra] y [ahorroMinimoConDeudaPuntosBase]: ver arriba.
PlanAhorroDeCierre planearAhorroDeCierre({
  required int remanente,
  required Iterable<BolsaAhorro> bolsas,
  int extras = 0,
  int sobre = 0,
  Iterable<int> gastos = const [],
  List<String> orden = const [],
  bool hayDeudaConExtra = false,
  int ahorroMinimoConDeudaPuntosBase = 0,
}) {
  if (remanente <= 0) return PlanAhorroDeCierre.vacio;
  var disponible = hayDeudaConExtra
      ? aplicarPorcentaje(remanente, ahorroMinimoConDeudaPuntosBase)
      : remanente;
  final ordenadas = [
    for (final b in bolsas)
      if (b.activa &&
          (!hayDeudaConExtra || b.tipo == TipoBolsaAhorro.fondoEmergencia))
        b,
  ]..sort((a, b) {
    final ia = orden.indexOf(a.id);
    final ib = orden.indexOf(b.id);
    if (ia >= 0 || ib >= 0) {
      if (ia < 0) return 1;
      if (ib < 0) return -1;
      return ia.compareTo(ib);
    }
    final c = a.prioridad.compareTo(b.prioridad);
    return c != 0 ? c : a.id.compareTo(b.id);
  });
  final aportes = <AporteDeCierre>[];
  var sobreRestante = sobre < 0 ? 0 : sobre;
  final listaGastos = gastos.toList();
  for (final origen in OrigenAporte.values) {
    for (final b in ordenadas) {
      if (disponible <= 0) break;
      if (!b.metodos.contains(origen.metodo)) continue;
      final deseado = switch (origen) {
        OrigenAporte.extras => porcentajeDeExtras(
          extras,
          b.aportePb ?? porcentajeDeExtrasPorOmision,
        ),
        OrigenAporte.sobre => sobreRestante,
        OrigenAporte.sobrante => sobranteSemanal(disponible),
        OrigenAporte.redondeo => redondeoDeGastos(
          listaGastos,
          multiplo: b.redondeoMultiplo,
        ),
      };
      final aporta = deseado < disponible ? deseado : disponible;
      if (aporta <= 0) continue;
      if (origen == OrigenAporte.sobre) sobreRestante -= aporta;
      disponible -= aporta;
      aportes.add(AporteDeCierre(origen, b.id, aporta));
      // El sobrante va a la primera de la lista (D25).
      if (origen == OrigenAporte.sobrante) break;
    }
  }
  return PlanAhorroDeCierre(aportes, disponible);
}

/// Cada gasto confirmado de la semana de [libroId] (para el redondeo): los
/// movimientos de tipo gasto, netos de su anulación y sin los reembolsos.
List<int> gastosDeLaSemana(DatosFinanzas d, String libroId, Semana semana) {
  final vista = d.vista(libroId);
  return [
    for (final m in vista.movimientos)
      if (m.tipo == TipoMovimiento.gasto &&
          semana.contiene(m.fecha) &&
          vista.estadoDe(m.id) == EstadoMovimiento.confirmado)
        m.monto,
  ];
}

/// Lo no gastado de los sobres que pasa al remanente en el cierre de [v] (el
/// excedente sobre el tope de arrastre de cada sobre).
int sobreDeLaSemana(VistaSemana v) {
  var total = 0;
  for (final p in v.real.partidas) {
    if (v.infoPartida(p.partida.id).origen == OrigenPartida.sobre) {
      total += p.alRemanente;
    }
  }
  return total;
}

/// Gasto real en partidas **protegidas** de cada semana cerrada de [libroId],
/// en orden cronológico (regla 18): con la marca de esencial que quedó en la
/// foto de cada semana (`PartidaSemana.protegida`) y el gasto de su último
/// cierre. Es lo que vuelve "real" el gasto esencial del fondo de emergencia.
List<int> esencialesPorSemanaCerrada(DatosFinanzas d, String libroId) {
  final cerradas = [
    for (final s in d.semanas)
      if (s.libroId == libroId && s.estado == EstadoSemana.cerrada) s,
  ]..sort((a, b) => a.semana.compareTo(b.semana));
  final lista = <int>[];
  for (final s in cerradas) {
    final cierre = d.ultimoCierre(s.id);
    if (cierre == null) continue;
    final protegidas = {
      for (final p in s.partidas)
        if (p.protegida) p.id,
    };
    var total = 0;
    for (final r in cierre.partidas) {
      if (protegidas.contains(r.partidaId)) total += r.gastado;
    }
    lista.add(total);
  }
  return lista;
}
