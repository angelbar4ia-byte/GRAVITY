/// Ahorro y fondo de emergencia (Fase 2, sección 5.2 de
/// `docs/specs/fase-2-finanzas.md`): niveles del fondo, gasto esencial,
/// semanas cubiertas, aportación de cada bolsa, los métodos de ahorro y el
/// reparto del remanente con orden y recorte de abajo hacia arriba. Dart puro;
/// la app nunca mueve dinero sola: todo es una **sugerencia** que la persona
/// confirma.
library;

import 'dinero.dart';
import 'indicadores.dart';
import 'presupuesto.dart';

// ----------------------------------------------------------------- el fondo

/// Los 5 niveles del fondo de emergencia (regla 17).
enum NivelFondo {
  colchon(1, 2),
  mes(2, 4),
  tresMeses(3, 13),
  seisMeses(4, 26),
  unAnio(5, 52);

  const NivelFondo(this.numero, this.semanas);

  final int numero;

  /// Semanas de gasto esencial que cubre.
  final int semanas;

  /// El nivel por defecto: 3 meses.
  static const porDefecto = NivelFondo.tresMeses;
}

/// De dónde salió el gasto esencial semanal (regla 18).
enum OrigenEsencial { historial, segunTuPlan, sinDatos }

/// Gasto esencial semanal calculado.
class GastoEsencial {
  /// Centavos por semana; `null` si no hay datos (nunca se inventa).
  final int? semanal;
  final OrigenEsencial origen;

  /// Semanas cerradas usadas (0 si salió del plan).
  final int semanasUsadas;

  const GastoEsencial(this.semanal, this.origen, this.semanasUsadas);

  /// *"según tu plan"* cuando no hay historial.
  String? get rotulo =>
      origen == OrigenEsencial.segunTuPlan ? 'según tu plan' : null;
}

/// Gasto esencial semanal (regla 18): promedio de las **últimas 8 semanas con
/// cierre** de [esencialesPorSemanaCerrada] (gasto real en partidas protegidas
/// y categorías `necesario`, de la más reciente a la más antigua o al revés:
/// se toman las últimas 8 de la lista, que va en orden cronológico), más los
/// [minimosDeDeudaSemanales] si se pide. Con menos de 8 usa las que haya; sin
/// ninguna, el presupuesto semanal de esas partidas ([presupuestoEsencial]);
/// sin plan tampoco, `null`.
GastoEsencial gastoEsencialSemanal({
  required List<int> esencialesPorSemanaCerrada,
  int? presupuestoEsencial,
  int minimosDeDeudaSemanales = 0,
  bool incluirMinimos = false,
}) {
  final extra = incluirMinimos ? minimosDeDeudaSemanales : 0;
  if (esencialesPorSemanaCerrada.isNotEmpty) {
    final ultimas = esencialesPorSemanaCerrada.length > 8
        ? esencialesPorSemanaCerrada.sublist(
            esencialesPorSemanaCerrada.length - 8,
          )
        : esencialesPorSemanaCerrada;
    final suma = ultimas.fold(0, (a, b) => a + b);
    return GastoEsencial(
      dividirRedondeando(suma, ultimas.length) + extra,
      OrigenEsencial.historial,
      ultimas.length,
    );
  }
  if (presupuestoEsencial != null && presupuestoEsencial > 0) {
    return GastoEsencial(
      presupuestoEsencial + extra,
      OrigenEsencial.segunTuPlan,
      0,
    );
  }
  return const GastoEsencial(null, OrigenEsencial.sinDatos, 0);
}

/// Meta en pesos de un nivel: `semanas × esencial semanal`.
int metaDelFondo(NivelFondo nivel, int esencialSemanal) =>
    nivel.semanas * esencialSemanal;

/// Semanas cubiertas en **décimas** hacia abajo (`30` = "3.0"): saldo ÷
/// esencial semanal (regla 19). Sin esencial (`<= 0`), `null`.
int? semanasCubiertasDecimas(int saldo, int esencialSemanal) {
  if (esencialSemanal <= 0) return null;
  return (saldo * 10) ~/ esencialSemanal;
}

/// Texto de las semanas cubiertas: `"3.0"`.
String textoSemanasCubiertas(int decimas) => '${decimas ~/ 10}.${decimas % 10}';

/// Semáforo del fondo (regla 19) sobre la fracción exacta: verde si el saldo
/// llega a la meta, ámbar desde el 50 %, rojo por debajo. Sin meta no hay.
Semaforo? semaforoDelFondo(int saldo, int meta) {
  if (meta <= 0) return null;
  if (saldo >= meta) return Semaforo.verde;
  return compararProporcion(saldo, meta, 5000) >= 0
      ? Semaforo.ambar
      : Semaforo.rojo;
}

/// El nivel 4 se **sugiere** (la persona decide) con un solo ingreso activo,
/// con ingresos `probable` o `incierta` como único sustento, o con
/// dependientes (regla 20).
NivelFondo nivelSugeridoDelFondo({
  required int ingresosActivos,
  required bool soloIngresosInseguros,
  required bool dependientesCuidados,
}) => ingresosActivos <= 1 || soloIngresosInseguros || dependientesCuidados
    ? NivelFondo.seisMeses
    : NivelFondo.porDefecto;

// -------------------------------------------------------------- aportaciones

/// Reserva: monto anual ÷ 52 (R2) por semana (regla 21).
int aportacionDeReserva(int montoAnual) => dividirRedondeando(montoAnual, 52);

/// Meta con fecha: `(meta − saldo) ÷ semanas restantes` (mínimo 1 semana).
/// Meta cumplida, cero. Es la aportación de **esta** semana (redondeada R1).
int aportacionDeMetaConFecha({
  required int meta,
  required int saldo,
  required int semanasRestantes,
}) {
  final falta = meta - saldo;
  if (falta <= 0) return 0;
  return dividirRedondeando(falta, semanasRestantes < 1 ? 1 : semanasRestantes);
}

/// Todas las cuotas de una meta con fecha: iguales y **la última absorbe la
/// diferencia** (regla 21 y convención 6).
List<int> cuotasDeMetaConFecha({
  required int meta,
  required int saldo,
  required int semanas,
}) {
  final falta = meta - saldo;
  if (falta <= 0 || semanas < 1) return const [];
  final cuota = dividirRedondeando(falta, semanas);
  return [
    for (var i = 0; i < semanas - 1; i++) cuota,
    falta - cuota * (semanas - 1),
  ];
}

/// Fondo: lo que falta para llegar a [meta], repartido en [semanas]
/// (por defecto, lo que alcance el orden: devuelve todo lo que falta).
int aportacionDeFondo({required int meta, required int saldo, int? semanas}) {
  final falta = meta - saldo;
  if (falta <= 0) return 0;
  return semanas == null || semanas < 1
      ? falta
      : dividirRedondeando(falta, semanas);
}

/// Aceleración (regla 23): cuánto sube la aportación semanal al pedir la meta
/// en menos semanas. Devuelve `(nueva, aumento)`.
({int nueva, int aumento}) acelerarMeta({
  required int meta,
  required int saldo,
  required int semanasActuales,
  required int semanasNuevas,
}) {
  final base = aportacionDeMetaConFecha(
    meta: meta,
    saldo: saldo,
    semanasRestantes: semanasActuales,
  );
  final nueva = aportacionDeMetaConFecha(
    meta: meta,
    saldo: saldo,
    semanasRestantes: semanasNuevas,
  );
  return (nueva: nueva, aumento: nueva - base);
}

// ----------------------------------------------------------------- métodos

/// Los 8 métodos de ahorro (regla 25).
enum MetodoAhorro {
  pagatePrimero('pagate_primero'),
  montoFijo('monto_fijo'),
  metaConFecha('meta_fecha'),
  reto52Semanas('reto_52_semanas'),
  redondeo('redondeo'),
  sobranteSemanal('sobrante_semanal'),
  sobrePorCategoria('sobre_categoria'),
  porcentajeDeExtras('porcentaje_extras');

  const MetodoAhorro(this.clave);

  /// Valor guardado en `fin_bolsas_ahorro.metodos`.
  final String clave;

  static MetodoAhorro? deClave(String c) {
    for (final m in values) {
      if (m.clave == c) return m;
    }
    return null;
  }
}

/// Reto de 52 semanas: la semana *k* aporta `k × base`. Con base $10 suma
/// $13,780 en las 52.
int retoDeSemana(int semana, int base) {
  if (semana < 1 || semana > 52) {
    throw RangeError.range(semana, 1, 52, 'semana');
  }
  return semana * base;
}

/// Suma del reto de 52 semanas.
int totalDelReto(int base) => base * (52 * 53 ~/ 2);

/// Lo que falta para llegar al siguiente múltiplo de [multiplo] (hacia arriba)
/// por un gasto (por omisión $10 = 1000 centavos).
int redondeoDeGasto(int gasto, {int multiplo = 1000}) {
  if (multiplo <= 0) throw ArgumentError.value(multiplo, 'multiplo');
  final resto = gasto % multiplo;
  return resto == 0 ? 0 : multiplo - resto;
}

/// Suma del redondeo de todos los gastos de la semana (se calcula al armar el
/// reparto, no al capturar el gasto).
int redondeoDeGastos(Iterable<int> gastos, {int multiplo = 1000}) =>
    gastos.fold(0, (a, g) => a + redondeoDeGasto(g, multiplo: multiplo));

/// Págate primero: `porcentaje` (puntos base) del ingreso que llegó. Apagado
/// (cero) mientras haya deuda que reciba extra ([hayDeuda]).
int pagatePrimero({
  required int ingresoQueLlego,
  required int puntosBase,
  required bool hayDeuda,
}) => hayDeuda ? 0 : aplicarPorcentaje(ingresoQueLlego, puntosBase);

/// Porcentaje de los ingresos extra de la semana.
int porcentajeDeExtras(int extras, int puntosBase) =>
    extras <= 0 ? 0 : aplicarPorcentaje(extras, puntosBase);

/// Sobrante semanal: el remanente positivo del cierre anterior.
int sobranteSemanal(int remanenteDelCierre) =>
    remanenteDelCierre > 0 ? remanenteDelCierre : 0;

/// Sobre por categoría: lo no gastado de la categoría elegida.
int sobreDeCategoria({required int asignado, required int gastado}) =>
    asignado > gastado ? asignado - gastado : 0;

/// Los métodos redondeo, sobrante, sobre y extras **alimentan la misma bolsa y
/// se descuentan de la aportación sugerida** para no apartar dos veces
/// (regla 25).
int sugeridoSinLoYaApartado(int sugerido, int yaApartado) =>
    sugerido > yaApartado ? sugerido - yaApartado : 0;

// ------------------------------------------------------------- el reparto

/// Etapa del orden por defecto del reparto (regla 22).
enum EtapaAhorro {
  /// 1. Fondo hasta el nivel 1 (el colchón).
  colchon,

  /// 2. Reservas.
  reservas,

  /// 3. Metas con fecha (solo lo necesario para llegar).
  metasConFecha,

  /// 4. Fondo hasta la meta elegida.
  fondoHastaLaMeta,

  /// 5. Metas sin fecha.
  metasSinFecha,
}

/// Un renglón del reparto: lo sugerido para una bolsa en una etapa.
class PasoDeAhorro {
  final String bolsaId;
  final EtapaAhorro etapa;
  final int sugerido;

  const PasoDeAhorro(this.bolsaId, this.etapa, this.sugerido);
}

/// Resultado del reparto de una semana.
class RepartoDeAhorro {
  /// Aportación de cada paso (misma posición que los pasos ordenados).
  final List<({PasoDeAhorro paso, int aportado, int pendiente})> renglones;

  /// Remanente que no se asignó a ningún paso.
  final int sobrante;

  const RepartoDeAhorro(this.renglones, this.sobrante);

  /// Total aportado a una bolsa (suma de sus renglones).
  int aportadoA(String bolsaId) => renglones
      .where((r) => r.paso.bolsaId == bolsaId)
      .fold(0, (a, r) => a + r.aportado);

  /// Total pendiente de una bolsa: lo no aportado queda **sin intereses ni
  /// castigo** (regla 24).
  int pendienteDe(String bolsaId) => renglones
      .where((r) => r.paso.bolsaId == bolsaId)
      .fold(0, (a, r) => a + r.pendiente);

  int get totalAportado => renglones.fold(0, (a, r) => a + r.aportado);
}

/// `true` si alguna deuda **recibe abono extra** (regla 16): una deuda con
/// costo o un préstamo familiar del orden de [ordenDeAbonoExtra] con saldo
/// pendiente. Los MSI no cuentan; con el grupo prioritario pagado, tampoco las
/// que quedan fuera de él.
bool hayDeudaQueRecibeExtra(Iterable<DeudaPlan> deudas) => ordenDeAbonoExtra(
  deudas,
).any((d) => d.tipo != TipoDeuda.msi && (d.saldo == null || d.saldo! > 0));

/// Reparte el [remanente] de la semana entre los [pasos] **en el orden de las
/// etapas** (regla 22). Si lo sugerido suma más que el remanente, **se recorta
/// de abajo hacia arriba**: lo último en la lista pierde primero y el colchón
/// al final. Lo que no cabe queda como pendiente.
///
/// Con [hayDeudaConExtra] (regla 16) todo el remanente va a deuda: solo se
/// aparta el [ahorroMinimoConDeuda] (puntos base del remanente) y solo al
/// colchón; el resto del reparto vale cero (y no queda pendiente: no se
/// propone).
RepartoDeAhorro repartirAhorro({
  required int remanente,
  required List<PasoDeAhorro> pasos,
  bool hayDeudaConExtra = false,
  int ahorroMinimoConDeuda = 0,
}) {
  final ordenados = [...pasos]
    ..sort((a, b) => a.etapa.index.compareTo(b.etapa.index));
  final disponible = remanente < 0 ? 0 : remanente;
  final tope = hayDeudaConExtra
      ? aplicarPorcentaje(disponible, ahorroMinimoConDeuda)
      : disponible;
  final renglones = <({PasoDeAhorro paso, int aportado, int pendiente})>[];
  var restante = tope;
  for (final p in ordenados) {
    final permitido = hayDeudaConExtra && p.etapa != EtapaAhorro.colchon
        ? 0
        : p.sugerido;
    final aporta = permitido < restante ? permitido : restante;
    restante -= aporta;
    renglones.add((
      paso: p,
      aportado: aporta,
      pendiente: hayDeudaConExtra && p.etapa != EtapaAhorro.colchon
          ? 0
          : p.sugerido - aporta,
    ));
  }
  return RepartoDeAhorro(renglones, disponible - (tope - restante));
}

// ------------------------------------------------------------------ retiros

/// Tipos de retiro de una bolsa (regla 27).
enum TipoRetiro { usoPrevisto, emergencia, cambioDeDestino }

/// Reposición del fondo tras un retiro de **emergencia**: el fondo pasa a ser
/// lo primero hasta recuperar el saldo que tenía antes (devuelve lo que falta).
int reposicionTrasRetiro({required int saldoAntes, required int saldoAhora}) =>
    saldoAntes > saldoAhora ? saldoAntes - saldoAhora : 0;
