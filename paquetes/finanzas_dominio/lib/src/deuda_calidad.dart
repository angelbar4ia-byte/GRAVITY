/// Deuda buena o mala (Fase 8, bloque 6; sección 5 de
/// `docs/specs/fase-8-fugas-y-deudas.md` v0.3). Dart puro.
///
/// **Una deuda mala solo avisa y sugiere: nunca bloquea** (respuesta del
/// dueño, 18/nov/2026). Ninguna función de este archivo impide registrar nada
/// ni pide una confirmación extra ([CalidadDeuda.bloquea] y
/// [VistaPreviaMsi.bloquea] son siempre `false`).
///
/// Todo se calcula con reglas locales: sin IA ni red (D3). El dinero va en
/// centavos y los porcentajes se comparan con la fracción exacta
/// ([compararProporcion]). Los umbrales viven en [ParametrosFugas]; la carga
/// total reutiliza [semaforoCargaDeuda] (20 y 35 %) y el uso del límite
/// [usoDelLimite] (30 y 60 %).
///
/// Falta dato no es "todo bien": una señal sin dato es [NivelSenal.sinDato] y
/// no suma al nivel (sección 2, principio 7).
library;

import 'ahorro_datos.dart';
import 'deudas_detalle.dart';
import 'dinero.dart';
import 'fecha.dart';
import 'indicadores.dart';
import 'parametros_fugas.dart';
import 'plan_guardado.dart';

// ======================================================= declaración (5.2)

/// Para qué fue la deuda (`fin_deuda_propositos.proposito`).
enum PropositoDeuda {
  bienDuradero,
  generaIngreso,
  patrimonio,
  educacionOSalud,
  emergencia,
  consumo,
}

/// Estado del objetivo declarado.
enum EstadoObjetivo {
  vigente,

  /// Ya se tiene y se usa.
  cumplido,

  /// Vendido, devuelto, perdido.
  yaNoExiste,

  /// Ya no se quiere.
  cambio,
}

/// Declaración vigente de una deuda (la más reciente sin reemplazo).
class DeclaracionDeuda {
  final PropositoDeuda proposito;

  /// Hasta 80 caracteres y **sin cifras** ([validarObjetivoTexto]).
  final String? objetivoTexto;
  final String? bienId;
  final String? objetivoId;

  /// Meses que se espera que dure lo comprado.
  final int? vidaUtilMeses;
  final EstadoObjetivo estado;

  /// B5 ámbar: la persona marca "lo uso poco".
  final bool usoPoco;

  const DeclaracionDeuda({
    required this.proposito,
    this.objetivoTexto,
    this.bienId,
    this.objetivoId,
    this.vidaUtilMeses,
    this.estado = EstadoObjetivo.vigente,
    this.usoPoco = false,
  });
}

/// Valida el texto del objetivo: hasta 80 caracteres y sin dígitos ni «\$» (el
/// comercio y las cifras son datos del libro; igual que el servidor, que
/// cuenta caracteres Unicode). Lanza [ArgumentError].
void validarObjetivoTexto(String texto) {
  if (texto.runes.length > 80) {
    throw ArgumentError('El objetivo admite hasta 80 caracteres');
  }
  if (RegExp(r'[0-9$]').hasMatch(texto)) {
    throw ArgumentError('El objetivo no lleva cifras');
  }
}

// ============================================================ entradas

/// Una compra a meses sin intereses para evaluar.
class MsiParaCalidad {
  /// Id de la deuda MSI.
  final String id;

  /// Deuda de la tarjeta donde se hizo la compra.
  final String tarjetaId;
  final Fecha fechaCompra;
  final int totalCentavos;
  final int plazoMeses;

  /// Mensualidades ya pagadas.
  final int pagadas;

  /// Lo que habría costado de contado (opcional; sin él no se evalúa B2).
  final int? precioContadoCentavos;

  const MsiParaCalidad({
    required this.id,
    required this.tarjetaId,
    required this.fechaCompra,
    required this.totalCentavos,
    required this.plazoMeses,
    this.pagadas = 0,
    this.precioContadoCentavos,
  });

  /// Arma la entrada desde el [Msi] guardado.
  factory MsiParaCalidad.deMsi(
    Msi msi, {
    required String tarjetaId,
    int pagadas = 0,
    int? precioContadoCentavos,
  }) => MsiParaCalidad(
    id: msi.deudaId,
    tarjetaId: tarjetaId,
    fechaCompra: msi.fechaCompra,
    totalCentavos: msi.montoTotal,
    plazoMeses: msi.mensualidades,
    pagadas: pagadas,
    precioContadoCentavos: precioContadoCentavos,
  );

  /// Mensualidad (total ÷ meses, R1).
  int get mensualidad => dividirRedondeando(totalCentavos, plazoMeses);

  int get pendientes => (plazoMeses - pagadas).clamp(0, plazoMeses);
  bool get activa => pendientes > 0;

  int get pendienteCentavos =>
      pendienteDeMsi(mensualidadesMsi(totalCentavos, plazoMeses), pagadas);

  bool get sobreprecio =>
      precioContadoCentavos != null && totalCentavos > precioContadoCentavos!;

  /// Fecha en que termina (la compra más el plazo).
  Fecha get fechaFin => Fecha.enMes(
    fechaCompra.anio,
    fechaCompra.mes + plazoMeses,
    fechaCompra.dia,
  );
}

/// Una deuda para evaluar su calidad.
class DeudaParaCalidad {
  final String id;
  final String nombre;
  final ClaseDeuda clase;

  /// Solo si [clase] es `msi`.
  final MsiParaCalidad? msi;

  /// Préstamo o crédito: plazo total y mensualidades que faltan.
  final int? plazoMeses;
  final int mensualidadesPendientes;

  /// Pago mensual (préstamo, crédito, tarjeta o familiar), para la carga
  /// total. En un MSI activo se toma su mensualidad.
  final int pagoMensualCentavos;

  /// Propósito declarado vigente; `null` = por declarar.
  final DeclaracionDeuda? declaracion;

  /// Estados de las últimas mensualidades de esta deuda, de la más antigua a
  /// la más reciente (ver [estadosDePagos]).
  final List<EstadoOcurrencia> estadosDePagos;

  const DeudaParaCalidad({
    required this.id,
    required this.nombre,
    required this.clase,
    this.msi,
    this.plazoMeses,
    this.mensualidadesPendientes = 0,
    this.pagoMensualCentavos = 0,
    this.declaracion,
    this.estadosDePagos = const [],
  });

  /// Plazo total en meses (MSI o préstamo).
  int? get plazo => msi?.plazoMeses ?? plazoMeses;

  /// Mensualidades que faltan; una tarjeta nunca "termina".
  int get pendientes => clase == ClaseDeuda.tarjeta
      ? 1
      : (msi?.pendientes ?? mensualidadesPendientes);

  bool get activa => pendientes > 0;

  int get pagoMensual =>
      msi != null ? (msi!.activa ? msi!.mensualidad : 0) : pagoMensualCentavos;
}

/// Una tarjeta con su saldo y límite (para B7).
class TarjetaParaCalidad {
  /// Id de la deuda de la tarjeta.
  final String deudaId;
  final int saldoCentavos;
  final int? limiteCentavos;
  final bool msiOcupanLimite;

  const TarjetaParaCalidad({
    required this.deudaId,
    required this.saldoCentavos,
    this.limiteCentavos,
    this.msiOcupanLimite = true,
  });
}

/// Estado de cuenta con los pagos hechos, para B6b y V-D.
class CorteDeTarjeta {
  final EstadoDeCuenta estado;

  /// Pagos registrados entre el corte y su fecha límite (hacia este estado).
  /// Nulo = «sin dato» (nadie los capturó): NO es lo mismo que cero. Solo un
  /// cero capturado significa «no pagó nada».
  final int? pagosAlCorteCentavos;

  /// Pagos hechos al estado anterior; sirve cuando el anterior no se capturó
  /// (V-D con un solo corte).
  final int? pagosCicloAnteriorCentavos;

  const CorteDeTarjeta({
    required this.estado,
    this.pagosAlCorteCentavos,
    this.pagosCicloAnteriorCentavos,
  });

  String get deudaId => estado.deudaId;
}

/// Cortes de [deudaId] sin repetidos (para un mismo corte vale el registro
/// más reciente), del corte más nuevo al más antiguo.
List<CorteDeTarjeta> cortesVigentes(
  Iterable<CorteDeTarjeta> cortes,
  String deudaId,
) {
  final porCorte = <Fecha, CorteDeTarjeta>{};
  for (final c in cortes.where((c) => c.deudaId == deudaId)) {
    final previo = porCorte[c.estado.fechaCorte];
    if (previo == null ||
        c.estado.registradoEn.isAfter(previo.estado.registradoEn)) {
      porCorte[c.estado.fechaCorte] = c;
    }
  }
  return porCorte.values.toList()
    ..sort((a, b) => b.estado.fechaCorte.compareTo(a.estado.fechaCorte));
}

/// Estados de las mensualidades de una deuda hasta [hoy], de la más antigua a
/// la más reciente (lo que pide [DeudaParaCalidad.estadosDePagos]).
List<EstadoOcurrencia> estadosDePagos(
  Iterable<Ocurrencia> ocurrencias, {
  required String deudaId,
  required Fecha hoy,
}) {
  final propias =
      ocurrencias
          .where(
            (o) =>
                o.origen == OrigenOcurrencia.deuda &&
                o.origenId == deudaId &&
                !o.fechaAjustada.despuesDe(hoy),
          )
          .toList()
        ..sort((a, b) => a.fechaAjustada.compareTo(b.fechaAjustada));
  return [for (final o in propias) o.estado];
}

// =========================================================== resultado

/// Nivel de una señal. [sinDato] no suma al nivel de la deuda.
enum NivelSenal {
  sinDato,
  verde,

  /// Falta declarar el propósito (gris con texto).
  porDeclarar,
  ambar,
  rojo,
}

/// Una señal con su código (B1 a B7, T1, M1), nivel y explicación.
class SenalDeuda {
  final String codigo;
  final NivelSenal nivel;

  /// Frase sin cifras ni nombres (voz sin culpa).
  final String explicacion;

  /// Una línea de acción: la deuda sugiere, nunca decide.
  final String? sugerencia;

  const SenalDeuda(
    this.codigo,
    this.nivel,
    this.explicacion, [
    this.sugerencia,
  ]);

  @override
  String toString() => '$codigo:${nivel.name}';
}

/// Una señal de deterioro (M1 a M8, sección 5.4).
class DeterioroDeuda {
  final String codigo;
  final NivelSenal nivel;

  const DeterioroDeuda(this.codigo, this.nivel);

  @override
  String toString() => '$codigo:${nivel.name}';
}

/// Etiqueta de la deuda (sección 5.5). Siempre con texto además del color.
enum EstadoCalidad {
  /// Verde: "Deuda buena".
  buena('Deuda buena'),

  /// Ámbar: "Buena, en vigilancia".
  enVigilancia('Buena, en vigilancia'),

  /// Rojo: "Se volvió mala".
  seVolvioMala('Se volvió mala'),

  /// Gris: "Por declarar".
  porDeclarar('Por declarar'),

  /// Préstamo entre familiares: no entra al semáforo de calidad.
  sinCosto('Sin costo'),

  /// Ya no hay mensualidades pendientes.
  liquidada('Liquidada');

  final String etiqueta;
  const EstadoCalidad(this.etiqueta);

  /// Rango para bajar de nivel con histéresis.
  int get _rango => switch (this) {
    EstadoCalidad.seVolvioMala => 2,
    EstadoCalidad.enVigilancia || EstadoCalidad.porDeclarar => 1,
    _ => 0,
  };
}

/// Resultado de evaluar una deuda.
class CalidadDeuda {
  final String deudaId;
  final EstadoCalidad estado;
  final List<SenalDeuda> senales;
  final List<DeterioroDeuda> deterioros;

  const CalidadDeuda({
    required this.deudaId,
    required this.estado,
    this.senales = const [],
    this.deterioros = const [],
  });

  /// Una deuda mala solo avisa: nunca bloquea registrar nada ni pide una
  /// confirmación extra (respuesta del dueño; DD-19).
  bool get bloquea => false;

  /// Sugerencias de las señales que no están en verde.
  List<String> get sugerencias => [
    for (final s in senales)
      if (s.sugerencia != null &&
          (s.nivel == NivelSenal.ambar ||
              s.nivel == NivelSenal.rojo ||
              s.nivel == NivelSenal.porDeclarar))
        s.sugerencia!,
  ];

  SenalDeuda? senal(String codigo) {
    for (final s in senales) {
      if (s.codigo == codigo) return s;
    }
    return null;
  }

  /// `true` si el nivel del semáforo es rojo (o la etiqueta es "mala").
  bool get esMala => estado == EstadoCalidad.seVolvioMala;

  /// El semáforo equivalente (gris, sin costo y liquidada no tienen color).
  Semaforo? get semaforo => switch (estado) {
    EstadoCalidad.buena => Semaforo.verde,
    EstadoCalidad.enVigilancia => Semaforo.ambar,
    EstadoCalidad.seVolvioMala => Semaforo.rojo,
    _ => null,
  };
}

/// Historial para la histéresis: nivel mostrado y evaluaciones seguidas
/// con un nivel más bajo.
class HistorialNivel {
  final EstadoCalidad nivel;
  final int bajasSeguidas;

  const HistorialNivel(this.nivel, [this.bajasSeguidas = 0]);
}

/// Subir de nivel es inmediato; bajar exige [ParametrosFugas.bajaNivelEvaluaciones]
/// evaluaciones semanales seguidas con un nivel más bajo (evita parpadeo).
/// Devuelve lo que se muestra y el historial nuevo.
HistorialNivel aplicarHisteresis({
  required HistorialNivel previo,
  required EstadoCalidad calculado,
  ParametrosFugas parametros = ParametrosFugas.porDefecto,
}) {
  if (calculado._rango >= previo.nivel._rango ||
      calculado == EstadoCalidad.sinCosto ||
      calculado == EstadoCalidad.liquidada) {
    return HistorialNivel(calculado);
  }
  final bajas = previo.bajasSeguidas + 1;
  if (bajas >= parametros.bajaNivelEvaluaciones) {
    return HistorialNivel(calculado);
  }
  return HistorialNivel(previo.nivel, bajas);
}

// ============================================================ criterios

NivelSenal _desdeSemaforo(Semaforo s) => switch (s) {
  Semaforo.verde => NivelSenal.verde,
  Semaforo.ambar => NivelSenal.ambar,
  Semaforo.rojo => NivelSenal.rojo,
};

/// B4a: carga total de deuda (pagos de deuda ÷ ingreso). Reutiliza el
/// semáforo existente (verde menos de 20 %, ámbar de 20 a 35 %, rojo más de
/// 35 %). Sin ingreso: sin dato.
NivelSenal senalCargaTotal(
  int pagosDeudaCentavos,
  int ingresoCentavos, {
  ParametrosFugas parametros = ParametrosFugas.porDefecto,
}) {
  if (ingresoCentavos <= 0) return NivelSenal.sinDato;
  return _desdeSemaforo(
    semaforoCargaDeuda(
      pagosDeudaCentavos,
      ingresoCentavos,
      umbrales: parametros.umbrales,
    ),
  );
}

/// B4b: MSI sobre el ingreso mensual. Verde hasta 10 % inclusive, ámbar de
/// 10 % a 20 % inclusive, rojo más de 20 % (propuesta). Fracción exacta.
NivelSenal senalMsiSobreIngreso(
  int mensualidadesMsiCentavos,
  int ingresoMensualCentavos, {
  ParametrosFugas parametros = ParametrosFugas.porDefecto,
}) {
  if (ingresoMensualCentavos <= 0) return NivelSenal.sinDato;
  if (compararProporcion(
        mensualidadesMsiCentavos,
        ingresoMensualCentavos,
        parametros.msiRojoPb,
      ) >
      0) {
    return NivelSenal.rojo;
  }
  if (compararProporcion(
        mensualidadesMsiCentavos,
        ingresoMensualCentavos,
        parametros.msiAmbarPb,
      ) >
      0) {
    return NivelSenal.ambar;
  }
  return NivelSenal.verde;
}

/// B4c: MSI activos a la vez (0 a 2 verde, 3 ámbar, 4 o más rojo).
NivelSenal senalMsiActivos(
  int activos, {
  ParametrosFugas parametros = ParametrosFugas.porDefecto,
}) {
  if (activos >= parametros.msiActivosRojo) return NivelSenal.rojo;
  if (activos >= parametros.msiActivosAmbar) return NivelSenal.ambar;
  return NivelSenal.verde;
}

/// Cómo se pagó un corte de tarjeta.
enum PagoDeTarjeta { totalSinIntereses, menosQueElTotal, soloElMinimo, sinDato }

/// Clasifica el pago de un corte: el total sin intereses (cubre la mensualidad
/// de los MSI), solo el mínimo (menor que el total e igual o menor que el
/// mínimo), algo en medio, o [PagoDeTarjeta.sinDato] si no se capturaron pagos.
PagoDeTarjeta clasificarPago(CorteDeTarjeta c) {
  final pagos = c.pagosAlCorteCentavos;
  if (pagos == null) return PagoDeTarjeta.sinDato;
  if (pagos >= c.estado.pagoSinIntereses) {
    return PagoDeTarjeta.totalSinIntereses;
  }
  if (pagos <= c.estado.pagoMinimo) {
    return PagoDeTarjeta.soloElMinimo;
  }
  return PagoDeTarjeta.menosQueElTotal;
}

/// B6b y M2: pago de la tarjeta del MSI. [cortes] van del más nuevo al más
/// antiguo ([cortesVigentes]). Sin estados: sin dato.
///
/// Rojo: solo el mínimo, o intereses en 2 cortes seguidos. Ámbar: intereses en
/// el último corte, o pagó menos que el total sin intereses. Verde: pagó el
/// total sin intereses. Sin pagos capturados en el último corte no se acusa
/// nada: «sin dato», salvo intereses en 2 cortes seguidos (no depende del pago).
NivelSenal senalPagoTarjeta(List<CorteDeTarjeta> cortes) {
  if (cortes.isEmpty) return NivelSenal.sinDato;
  final ultimo = cortes.first;
  final dosSeguidos =
      ultimo.estado.intereses > 0 &&
      cortes.length > 1 &&
      cortes[1].estado.intereses > 0;
  final pago = clasificarPago(ultimo);
  if (pago == PagoDeTarjeta.soloElMinimo || dosSeguidos) {
    return NivelSenal.rojo;
  }
  if (pago == PagoDeTarjeta.sinDato) return NivelSenal.sinDato;
  if (ultimo.estado.intereses > 0 ||
      clasificarPago(ultimo) != PagoDeTarjeta.totalSinIntereses) {
    return NivelSenal.ambar;
  }
  return NivelSenal.verde;
}

/// B6a: atrasos entre los últimos pagos (0 verde, 1 ámbar, 2 o más rojo).
NivelSenal senalAtrasos(
  List<EstadoOcurrencia> estados, {
  ParametrosFugas parametros = ParametrosFugas.porDefecto,
}) {
  if (estados.isEmpty) return NivelSenal.sinDato;
  final recientes = estados.length > parametros.atrasosVentana
      ? estados.sublist(estados.length - parametros.atrasosVentana)
      : estados;
  final atrasos = recientes
      .where((e) => e == EstadoOcurrencia.retrasada)
      .length;
  if (atrasos >= parametros.atrasosRojo) return NivelSenal.rojo;
  if (atrasos >= parametros.atrasosAmbar) return NivelSenal.ambar;
  return NivelSenal.verde;
}

int _mesesCompletos(Fecha a, Fecha b) {
  final meses = (b.anio - a.anio) * 12 + (b.mes - a.mes);
  return b.dia < a.dia ? meses - 1 : meses;
}

/// M1: cuántas compras a MSI de [tarjetaId], hechas en los últimos 12 meses,
/// "encadenan" otra: se compró cuando otro MSI de la misma tarjeta tenía
/// [ParametrosFugas.encadenaPendientesMax] mensualidades pendientes o menos,
/// o terminó hace [ParametrosFugas.encadenaDiasTrasFin] días o menos.
int encadenamientosMsi(
  Iterable<MsiParaCalidad> msis, {
  required String tarjetaId,
  required Fecha hoy,
  ParametrosFugas parametros = ParametrosFugas.porDefecto,
}) {
  final de = msis.where((m) => m.tarjetaId == tarjetaId).toList();
  final desde = hoy.sumarDias(-365);
  var cuenta = 0;
  for (final b in de) {
    if (b.fechaCompra.antesDe(desde) || b.fechaCompra.despuesDe(hoy)) continue;
    final encadena = de.any((a) {
      if (a.id == b.id || !a.fechaCompra.antesDe(b.fechaCompra)) return false;
      final diasTrasFin = a.fechaFin.diasHasta(b.fechaCompra);
      if (diasTrasFin > parametros.encadenaDiasTrasFin) return false;
      final transcurridas = _mesesCompletos(a.fechaCompra, b.fechaCompra);
      final pendientes = (a.plazoMeses - transcurridas).clamp(0, a.plazoMeses);
      return pendientes <= parametros.encadenaPendientesMax;
    });
    if (encadena) cuenta++;
  }
  return cuenta;
}

// ============================================================ evaluación

/// Todo lo que hace falta para evaluar las deudas de un libro.
class EntradaCalidadDeuda {
  final Fecha hoy;

  /// Ingreso mensual de referencia ([ingresoMensualDeReferencia]).
  final int ingresoMensualCentavos;
  final List<DeudaParaCalidad> deudas;
  final List<TarjetaParaCalidad> tarjetas;
  final List<CorteDeTarjeta> cortes;
  final ParametrosFugas parametros;

  const EntradaCalidadDeuda({
    required this.hoy,
    required this.ingresoMensualCentavos,
    required this.deudas,
    this.tarjetas = const [],
    this.cortes = const [],
    this.parametros = ParametrosFugas.porDefecto,
  });

  List<MsiParaCalidad> get msisActivos => [
    for (final d in deudas)
      if (d.msi != null && d.msi!.activa) d.msi!,
  ];

  /// Suma de los pagos mensuales de todas las deudas (los préstamos entre
  /// familiares sí cuentan en la carga total, hallazgo D-9).
  int get pagosDeudaMensuales =>
      deudas.fold<int>(0, (a, d) => a + d.pagoMensual);
}

/// Evalúa todas las deudas de la entrada.
List<CalidadDeuda> evaluarDeudas(EntradaCalidadDeuda e) => [
  for (final d in e.deudas) evaluarDeuda(e, d),
];

/// Evalúa una deuda: junta sus señales, toma la peor y arma las señales de
/// deterioro. Una deuda mala solo avisa ([CalidadDeuda.bloquea] = `false`).
CalidadDeuda evaluarDeuda(EntradaCalidadDeuda e, DeudaParaCalidad d) {
  final p = e.parametros;
  if (d.clase == ClaseDeuda.familiar) {
    return CalidadDeuda(deudaId: d.id, estado: EstadoCalidad.sinCosto);
  }
  final esTarjeta = d.clase == ClaseDeuda.tarjeta;
  final esMsi = d.clase == ClaseDeuda.msi && d.msi != null;
  if (!esTarjeta && !d.activa) {
    return CalidadDeuda(deudaId: d.id, estado: EstadoCalidad.liquidada);
  }

  final tarjetaId = esTarjeta ? d.id : d.msi?.tarjetaId;
  final cortes = tarjetaId == null
      ? const <CorteDeTarjeta>[]
      : cortesVigentes(e.cortes, tarjetaId);
  final decl = d.declaracion;
  final objetivoMuerto =
      decl != null &&
      (decl.estado == EstadoObjetivo.yaNoExiste ||
          decl.estado == EstadoObjetivo.cambio) &&
      d.activa;
  final senales = <SenalDeuda>[];

  // B1: objetivo declarado.
  if (!esTarjeta) {
    if (decl == null) {
      senales.add(
        const SenalDeuda(
          'B1',
          NivelSenal.porDeclarar,
          'Falta declarar para qué fue esta deuda.',
          'Declara para qué fue.',
        ),
      );
    } else if (decl.proposito == PropositoDeuda.consumo || objetivoMuerto) {
      senales.add(
        SenalDeuda(
          'B1',
          NivelSenal.rojo,
          objetivoMuerto
              ? 'El objetivo que declaraste ya no existe y quedan pagos.'
              : 'Se declaró como gasto de consumo.',
          'Veamos opciones para esta deuda.',
        ),
      );
    } else {
      senales.add(
        const SenalDeuda(
          'B1',
          NivelSenal.verde,
          'Tiene un objetivo declarado.',
        ),
      );
    }
  }

  // B2 / T1: costo financiero total.
  if (esTarjeta) {
    if (cortes.isNotEmpty && cortes.first.estado.intereses > 0) {
      senales.add(
        const SenalDeuda(
          'T1',
          NivelSenal.rojo,
          'La tarjeta cobró intereses en el último estado.',
          'Paga el total en el próximo corte.',
        ),
      );
    }
  } else if (esMsi) {
    final m = d.msi!;
    senales.add(
      m.precioContadoCentavos == null
          ? const SenalDeuda(
              'B2',
              NivelSenal.sinDato,
              'Falta el precio de contado para saber si hay sobreprecio.',
            )
          : m.sobreprecio
          ? const SenalDeuda(
              'B2',
              NivelSenal.ambar,
              'El total a meses supera el precio de contado.',
              'Compara contra el precio de contado.',
            )
          : const SenalDeuda('B2', NivelSenal.verde, 'No hay sobreprecio.'),
    );
  } else {
    final prop = decl?.proposito;
    senales.add(
      prop == PropositoDeuda.patrimonio || prop == PropositoDeuda.generaIngreso
          ? const SenalDeuda(
              'B2',
              NivelSenal.verde,
              'Es un crédito con propósito de patrimonio o ingreso.',
            )
          : const SenalDeuda(
              'B2',
              NivelSenal.sinDato,
              'Sin dato del costo financiero total.',
            ),
    );
  }

  // B3: plazo contra vida útil y contra el límite de los MSI.
  if (!esTarjeta) {
    final plazo = d.plazo;
    final vida = decl?.vidaUtilMeses;
    if (plazo == null) {
      senales.add(
        const SenalDeuda('B3', NivelSenal.sinDato, 'Falta el plazo.'),
      );
    } else if (vida != null && plazo > vida) {
      senales.add(
        const SenalDeuda(
          'B3',
          NivelSenal.rojo,
          'El plazo es mayor que la vida útil de lo comprado.',
          'Evita pagar algo que ya no se usa.',
        ),
      );
    } else if (esMsi && plazo > p.plazoAmbarMeses) {
      senales.add(
        const SenalDeuda(
          'B3',
          NivelSenal.ambar,
          'El plazo es largo para una compra a meses.',
          'Prefiere plazos cortos.',
        ),
      );
    } else {
      senales.add(
        const SenalDeuda('B3', NivelSenal.verde, 'El plazo es razonable.'),
      );
    }
  }

  // B4a: carga total.
  final carga = senalCargaTotal(
    e.pagosDeudaMensuales,
    e.ingresoMensualCentavos,
    parametros: p,
  );
  senales.add(
    SenalDeuda(
      'B4a',
      carga,
      'La carga total de deudas pesa sobre tu ingreso.',
      'Abre el simulador de pago.',
    ),
  );

  // B4b y B4c: solo para los MSI.
  if (esMsi) {
    final activos = e.msisActivos;
    final suma = activos.fold<int>(0, (a, m) => a + m.mensualidad);
    senales.add(
      SenalDeuda(
        'B4b',
        senalMsiSobreIngreso(suma, e.ingresoMensualCentavos, parametros: p),
        'Tus compras a meses pesan sobre tu ingreso mensual.',
        'No abras otro hasta liquidar uno.',
      ),
    );
    senales.add(
      SenalDeuda(
        'B4c',
        senalMsiActivos(activos.length, parametros: p),
        'Tienes varias compras a meses al mismo tiempo.',
        'No abras otro hasta liquidar uno.',
      ),
    );
  }

  // B5: el bien sirve.
  if (!esTarjeta) {
    senales.add(
      decl == null
          ? const SenalDeuda(
              'B5',
              NivelSenal.sinDato,
              'Falta declarar si lo comprado se usa.',
            )
          : objetivoMuerto
          ? const SenalDeuda(
              'B5',
              NivelSenal.rojo,
              'Lo comprado ya no existe o ya no se quiere.',
              'Veamos opciones para esta deuda.',
            )
          : decl.usoPoco
          ? const SenalDeuda(
              'B5',
              NivelSenal.ambar,
              'Marcaste que lo usas poco.',
            )
          : const SenalDeuda('B5', NivelSenal.verde, 'Lo comprado se usa.'),
    );
  }

  // B6a: pagos al corriente.
  senales.add(
    SenalDeuda(
      'B6a',
      senalAtrasos(d.estadosDePagos, parametros: p),
      'Hubo pagos atrasados.',
      'Ponte al corriente con el siguiente pago.',
    ),
  );

  // B6b: pago de la tarjeta.
  if (esTarjeta || esMsi) {
    final n = senalPagoTarjeta(cortes);
    senales.add(
      SenalDeuda(
        'B6b',
        n,
        n == NivelSenal.sinDato
            ? 'Falta el estado de cuenta para saberlo.'
            : 'El pago de la tarjeta trae intereses o fue el mínimo.',
        'Paga el total en el próximo corte.',
      ),
    );
  }

  // B7: uso del límite.
  if (tarjetaId != null) {
    TarjetaParaCalidad? t;
    for (final x in e.tarjetas) {
      if (x.deudaId == tarjetaId) t = x;
    }
    if (t == null || t.limiteCentavos == null) {
      senales.add(
        const SenalDeuda(
          'B7',
          NivelSenal.sinDato,
          'Falta el límite de la tarjeta.',
        ),
      );
    } else {
      final msiPend = e.msisActivos
          .where((m) => m.tarjetaId == tarjetaId)
          .fold<int>(0, (a, m) => a + m.pendienteCentavos);
      final uso = usoDelLimite(
        saldo: t.saldoCentavos,
        limite: t.limiteCentavos,
        msiPendiente: msiPend,
        msiOcupanLimite: t.msiOcupanLimite,
      );
      senales.add(
        SenalDeuda(
          'B7',
          uso == null ? NivelSenal.sinDato : _desdeSemaforo(uso.semaforo),
          'Estás usando buena parte del límite de la tarjeta.',
          'Baja el saldo antes de usar más límite.',
        ),
      );
    }
  }

  // M1: rodar de un MSI a otro (por tarjeta).
  if (tarjetaId != null) {
    final n = encadenamientosMsi(
      [for (final x in e.deudas) ?x.msi],
      tarjetaId: tarjetaId,
      hoy: e.hoy,
      parametros: p,
    );
    senales.add(
      SenalDeuda(
        'M1',
        n >= p.encadenaRojo
            ? NivelSenal.rojo
            : n >= p.encadenaAmbar
            ? NivelSenal.ambar
            : NivelSenal.verde,
        'Se compra a meses antes de terminar la compra anterior.',
        'No abras otro hasta liquidar uno.',
      ),
    );
  }

  final estado = _estadoDe(senales);
  return CalidadDeuda(
    deudaId: d.id,
    estado: estado,
    senales: senales,
    deterioros: _deterioros(senales, objetivoMuerto: objetivoMuerto),
  );
}

EstadoCalidad _estadoDe(List<SenalDeuda> senales) {
  bool hay(NivelSenal n) => senales.any((s) => s.nivel == n);
  if (hay(NivelSenal.rojo)) return EstadoCalidad.seVolvioMala;
  if (hay(NivelSenal.porDeclarar)) return EstadoCalidad.porDeclarar;
  if (hay(NivelSenal.ambar)) return EstadoCalidad.enVigilancia;
  return EstadoCalidad.buena;
}

List<DeterioroDeuda> _deterioros(
  List<SenalDeuda> senales, {
  required bool objetivoMuerto,
}) {
  NivelSenal? peor(Iterable<String> codigos) {
    NivelSenal? r;
    for (final s in senales.where((s) => codigos.contains(s.codigo))) {
      if (s.nivel != NivelSenal.ambar && s.nivel != NivelSenal.rojo) continue;
      if (r == null || s.nivel == NivelSenal.rojo) r = s.nivel;
    }
    return r;
  }

  final salida = <DeterioroDeuda>[];
  void agrega(String codigo, NivelSenal? nivel) {
    if (nivel != null) salida.add(DeterioroDeuda(codigo, nivel));
  }

  agrega('M1', peor(['M1']));
  agrega('M2', peor(['B6b']));
  if (objetivoMuerto) salida.add(const DeterioroDeuda('M3', NivelSenal.rojo));
  agrega('M4', peor(['B4a', 'B4b']));
  agrega('M5', peor(['B4c']));
  agrega('M6', peor(['B6a']));
  agrega('M7', peor(['B3', 'B2']));
  agrega('M8', peor(['B7']));
  return salida;
}

// ============================================================ vista previa

/// Vista previa de un MSI nuevo (sección 5.5): cómo quedaría el semáforo de
/// los MSI antes de guardar. Solo informa: **nunca bloquea** (DD-19).
class VistaPreviaMsi {
  /// Mensualidades de MSI ÷ ingreso mensual, en puntos base redondeados
  /// (solo para mostrar).
  final int puntosBase;
  final int activos;
  final NivelSenal sobreIngreso;
  final NivelSenal activosANivel;

  const VistaPreviaMsi({
    required this.puntosBase,
    required this.activos,
    required this.sobreIngreso,
    required this.activosANivel,
  });

  /// El peor de los dos niveles.
  NivelSenal get nivel =>
      sobreIngreso == NivelSenal.rojo || activosANivel == NivelSenal.rojo
      ? NivelSenal.rojo
      : sobreIngreso == NivelSenal.ambar || activosANivel == NivelSenal.ambar
      ? NivelSenal.ambar
      : NivelSenal.verde;

  /// Guardar nunca exige una confirmación extra.
  bool get bloquea => false;
}

/// "Con esta compra, tus MSI serían X % de tu ingreso y tendrías N a la vez."
VistaPreviaMsi vistaPreviaMsiNuevo({
  required Iterable<MsiParaCalidad> activosActuales,
  required int mensualidadNuevaCentavos,
  required int ingresoMensualCentavos,
  ParametrosFugas parametros = ParametrosFugas.porDefecto,
}) {
  final suma =
      activosActuales
          .where((m) => m.activa)
          .fold<int>(0, (a, m) => a + m.mensualidad) +
      mensualidadNuevaCentavos;
  final n = activosActuales.where((m) => m.activa).length + 1;
  return VistaPreviaMsi(
    puntosBase: proporcionEnPuntosBase(suma, ingresoMensualCentavos),
    activos: n,
    sobreIngreso: senalMsiSobreIngreso(
      suma,
      ingresoMensualCentavos,
      parametros: parametros,
    ),
    activosANivel: senalMsiActivos(n, parametros: parametros),
  );
}
