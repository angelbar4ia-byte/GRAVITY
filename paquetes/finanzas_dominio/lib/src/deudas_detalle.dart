/// Deudas a detalle (Fase 2, sección 5.1 de `docs/specs/fase-2-finanzas.md`):
/// clases de deuda, orden de pago por costo **con el motivo de cada lugar**,
/// costo estimado de deber, uso del límite de una tarjeta y mensualidades de
/// una compra a MSI. Dart puro; el saldo siempre sale del libro.
library;

import 'dinero.dart';
import 'indicadores.dart';
import 'presupuesto.dart';

/// Clase de una deuda (regla 1). Los tipos `conCosto`, `familiar` y `msi` de
/// la Fase 1 no cambian: la clase solo agrega el detalle.
enum ClaseDeuda {
  tarjeta,
  prestamo,
  credito,
  msi,
  familiar;

  /// El [TipoDeuda] que le corresponde (criterio 2).
  TipoDeuda get tipo => switch (this) {
    ClaseDeuda.msi => TipoDeuda.msi,
    ClaseDeuda.familiar => TipoDeuda.familiar,
    _ => TipoDeuda.conCosto,
  };

  /// `true` si la clase exige tasa (tarjeta, préstamo y crédito).
  bool get exigeTasa => tipo == TipoDeuda.conCosto;

  /// Revisa que la [clase] y el [tipo] concuerden y que la tasa también:
  /// una `msi` o `familiar` lleva tasa cero; una con costo, tasa mayor que cero.
  /// Lanza [ArgumentError].
  static void validar(
    ClaseDeuda clase,
    TipoDeuda tipo,
    int tasaAnualPuntosBase,
  ) {
    if (clase.tipo != tipo) {
      throw ArgumentError(
        'La clase ${clase.name} va con el tipo ${clase.tipo.name}, no con '
        '${tipo.name}',
      );
    }
    if (clase.exigeTasa && tasaAnualPuntosBase <= 0) {
      throw ArgumentError('Una deuda con costo necesita su tasa anual');
    }
    if (!clase.exigeTasa && tasaAnualPuntosBase != 0) {
      throw ArgumentError('Una MSI o un préstamo familiar no llevan tasa');
    }
  }
}

/// Un lugar del orden de pago, con la razón de estar ahí (regla 5).
class LugarDePago {
  final DeudaPlan deuda;

  /// 1 = primero.
  final int lugar;

  /// "manual", "grupo, lugar 2", "tasa 60 %", "familiar: al final".
  final String motivo;

  const LugarDePago(this.deuda, this.lugar, this.motivo);
}

String _porcentaje(int puntosBase) {
  final entero = puntosBase ~/ 100;
  final resto = puntosBase % 100;
  return resto == 0
      ? '$entero'
      : '$entero.${resto.toString().padLeft(2, '0').replaceAll(RegExp(r'0+$'), '')}';
}

/// El orden del abono extra ([ordenDeAbonoExtra]) con el motivo de cada
/// lugar. Los **mínimos van siempre antes** (regla 5, punto 1): el orden solo
/// decide a quién va lo que sobra. Los MSI no aparecen (no reciben extra) salvo
/// con prioridad manual o en el grupo; se listan aparte en [msiSinExtra].
List<LugarDePago> ordenConMotivo(Iterable<DeudaPlan> deudas) {
  final orden = ordenDeAbonoExtra(deudas);
  final conGrupo = hayGrupoPrioritario(deudas);
  return [
    for (var i = 0; i < orden.length; i++)
      LugarDePago(
        orden[i],
        i + 1,
        conGrupo
            ? 'grupo, lugar ${orden[i].ordenGrupo ?? i + 1}'
            : orden[i].prioridadManual != null
            ? 'manual, lugar ${orden[i].prioridadManual}'
            : orden[i].tipo == TipoDeuda.familiar
            ? 'familiar: al final'
            : orden[i].tipo == TipoDeuda.msi
            ? 'MSI'
            : 'tasa ${_porcentaje(orden[i].tasaAnualPuntosBase)} %',
      ),
  ];
}

/// Las MSI que no reciben extra (se muestran con su motivo).
List<DeudaPlan> msiSinExtra(Iterable<DeudaPlan> deudas) {
  final reciben = {for (final d in ordenDeAbonoExtra(deudas)) d.id};
  return [
    for (final d in deudas)
      if (d.tipo == TipoDeuda.msi && !reciben.contains(d.id)) d,
  ];
}

/// Lo que se aplica a cada deuda de un [pago] disponible: primero los
/// **mínimos** de todas y, con lo que sobra, el extra en [ordenDeAbonoExtra]
/// sin pasar del saldo (regla 5; criterio 3). Devuelve el aplicado por id.
Map<String, int> aplicarPagoConMinimosPrimero(
  Iterable<DeudaPlan> deudas,
  int disponible,
) {
  final aplicado = <String, int>{for (final d in deudas) d.id: 0};
  var resto = disponible;
  for (final d in deudas) {
    final minimo = d.minimo < resto ? d.minimo : resto;
    aplicado[d.id] = minimo;
    resto -= minimo;
  }
  for (final d in ordenDeAbonoExtra(deudas)) {
    if (resto <= 0) break;
    final tope = d.saldo == null ? resto : d.saldo! - aplicado[d.id]!;
    final parte = tope < resto ? (tope < 0 ? 0 : tope) : resto;
    aplicado[d.id] = aplicado[d.id]! + parte;
    resto -= parte;
  }
  return aplicado;
}

/// Costo semanal estimado de deber (regla 6): interés simple
/// `saldo × tasa ÷ 52` por deuda con costo, repartido por mayor resto (R2) de
/// modo que los renglones suman exacto. Siempre se rotula *estimado*.
class CostoDeDeber {
  /// Interés semanal estimado por id de deuda.
  final Map<String, int> porDeuda;

  /// Suma exacta de [porDeuda].
  final int semanal;

  /// Interés mensual de referencia por id (saldo × tasa ÷ 12).
  final Map<String, int> mensualDeReferencia;

  const CostoDeDeber(this.porDeuda, this.semanal, this.mensualDeReferencia);
}

/// Calcula el [CostoDeDeber] de las deudas con costo que tienen saldo.
CostoDeDeber costoDeDeber(Iterable<DeudaPlan> deudas) {
  final con = [
    for (final d in deudas)
      if (d.tipo == TipoDeuda.conCosto && (d.saldo ?? 0) > 0) d,
  ];
  // saldo × tasa(pb) ÷ 10,000 ÷ 52: numerador en centavos × pb.
  final partes = repartirConMayorResto([
    for (final d in con) d.saldo! * d.tasaAnualPuntosBase,
  ], puntosBaseEnCien * 52);
  final porDeuda = {for (var i = 0; i < con.length; i++) con[i].id: partes[i]};
  return CostoDeDeber(porDeuda, partes.fold(0, (a, b) => a + b), {
    for (final d in con)
      d.id: dividirRedondeando(
        d.saldo! * d.tasaAnualPuntosBase,
        puntosBaseEnCien * 12,
      ),
  });
}

/// Uso del límite de una tarjeta (regla 7).
class UsoDelLimite {
  /// Saldo de la tarjeta más lo pendiente de sus MSI.
  final int usado;
  final int limite;

  /// Porcentaje redondeado en puntos base (solo para mostrar).
  final int puntosBase;
  final Semaforo semaforo;

  const UsoDelLimite(this.usado, this.limite, this.puntosBase, this.semaforo);
}

/// Uso del límite: `(saldo + MSI pendiente) ÷ límite`; verde menos de 30 %,
/// ámbar de 30 a 60 %, rojo sobre 60 %, con la **fracción exacta**. Sin límite
/// (nulo o cero) no se calcula: `null` y la pantalla pide capturarlo.
/// [msiOcupanLimite] es la bandera de la tarjeta (pregunta P8).
UsoDelLimite? usoDelLimite({
  required int saldo,
  required int? limite,
  int msiPendiente = 0,
  bool msiOcupanLimite = true,
}) {
  if (limite == null || limite <= 0) return null;
  final usado = saldo + (msiOcupanLimite ? msiPendiente : 0);
  final semaforo = compararProporcion(usado, limite, 3000) < 0
      ? Semaforo.verde
      : compararProporcion(usado, limite, 6000) <= 0
      ? Semaforo.ambar
      : Semaforo.rojo;
  return UsoDelLimite(
    usado,
    limite,
    dividirRedondeando(usado * puntosBaseEnCien, limite),
    semaforo,
  );
}

/// Mensualidades de una compra a MSI (regla 10): total ÷ meses (R1) y **la
/// última absorbe la diferencia**, de modo que suman exacto.
List<int> mensualidadesMsi(int totalCentavos, int meses) {
  if (meses <= 0) throw ArgumentError.value(meses, 'meses', 'debe ser > 0');
  if (totalCentavos < 0) throw ArgumentError('El total no puede ser negativo');
  final cuota = dividirRedondeando(totalCentavos, meses);
  return [
    for (var i = 0; i < meses - 1; i++) cuota,
    totalCentavos - cuota * (meses - 1),
  ];
}

/// Una MSI adelantada solo si la persona lo pide: lo pendiente es lo que falta
/// de mensualidades. Sirve para "liberar límite" con confirmación.
int pendienteDeMsi(List<int> mensualidades, int pagadas) => mensualidades
    .skip(pagadas.clamp(0, mensualidades.length))
    .fold(0, (a, b) => a + b);

/// `true` si el crédito puede recibir extra a capital (regla 12): solo con
/// `permite_pago_anticipado` verdadero; con `null` hay que verificarlo.
bool puedeRecibirExtra({required bool? permitePagoAnticipado}) =>
    permitePagoAnticipado == true;
