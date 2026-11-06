import 'deudas_detalle.dart' show ClaseDeuda;
import 'calendario.dart';
import 'fecha.dart';
import 'frecuencia.dart';
import 'indicadores.dart';
import 'presupuesto.dart';
import 'semana.dart';

/// Configuración de un libro (sección 4.1 y 4.5 de la especificación de la
/// Fase 1): parámetros, ingresos con vigencias, compromisos, sobres y deudas.
/// Es lo que se guarda en `fin_parametros`, `fin_ingresos`,
/// `fin_vigencias_ingreso`, `fin_compromisos`, `fin_sobres` y `fin_deudas`.

/// Parámetros del libro (`fin_parametros`, por libro desde D19; los valores
/// del hogar son la plantilla). Valores por defecto de 5.6 bis y 5.9 bis.
class ParametrosFinanzas {
  final String libroId;
  final int metaRemanentePuntosBase;
  final int ahorroMinimoConDeudaPuntosBase;
  final int topeArrastreSemanas;
  final Umbrales umbrales;

  /// Días después del domingo en que una semana sin cerrar se cierra sola,
  /// con pendientes marcados (5.9 bis, punto 4).
  final int cierreAutomaticoDias;

  /// Cuentas técnicas del libro (se crean solas con el libro).
  final String? cuentaAjustesId;
  final String? cuentaAperturaId;
  final String? cuentaPorClasificarId;

  // Fase 2 (`fin_parametros`): ahorro y avisos.
  /// Orden del reparto del ahorro (regla 22).
  final List<String> ordenAhorro;

  /// Lo declara la persona (nivel 4 del fondo sugerido, regla 20).
  final bool dependientesCuidados;

  /// El gasto esencial suma los mínimos de deuda (regla 18).
  final bool esencialesIncluyenMinimos;

  /// Días antes del vencimiento en que avisa (por omisión 3 y 1).
  final List<int> diasAvisoDeuda;

  const ParametrosFinanzas({
    required this.libroId,
    this.metaRemanentePuntosBase = 2000,
    this.ahorroMinimoConDeudaPuntosBase = 0,
    this.topeArrastreSemanas = 2,
    this.umbrales = Umbrales.porDefecto,
    this.cierreAutomaticoDias = 3,
    this.cuentaAjustesId,
    this.cuentaAperturaId,
    this.cuentaPorClasificarId,
    this.ordenAhorro = const [
      'fondo_n1',
      'reservas',
      'metas_fecha',
      'fondo_meta',
      'metas_libres',
    ],
    this.dependientesCuidados = false,
    this.esencialesIncluyenMinimos = true,
    this.diasAvisoDeuda = const [3, 1],
  });

  ParametrosPlan get plan => ParametrosPlan(
    metaRemanentePuntosBase: metaRemanentePuntosBase,
    ahorroMinimoConDeudaPuntosBase: ahorroMinimoConDeudaPuntosBase,
    topeArrastreSemanas: topeArrastreSemanas,
    umbrales: umbrales,
  );

  ParametrosFinanzas copiar({
    int? metaRemanentePuntosBase,
    int? ahorroMinimoConDeudaPuntosBase,
    int? topeArrastreSemanas,
    Umbrales? umbrales,
    int? cierreAutomaticoDias,
    String? cuentaAjustesId,
    String? cuentaAperturaId,
    String? cuentaPorClasificarId,
    List<String>? ordenAhorro,
    bool? dependientesCuidados,
    bool? esencialesIncluyenMinimos,
    List<int>? diasAvisoDeuda,
  }) => ParametrosFinanzas(
    libroId: libroId,
    ordenAhorro: ordenAhorro ?? this.ordenAhorro,
    dependientesCuidados: dependientesCuidados ?? this.dependientesCuidados,
    esencialesIncluyenMinimos:
        esencialesIncluyenMinimos ?? this.esencialesIncluyenMinimos,
    diasAvisoDeuda: diasAvisoDeuda ?? this.diasAvisoDeuda,
    metaRemanentePuntosBase:
        metaRemanentePuntosBase ?? this.metaRemanentePuntosBase,
    ahorroMinimoConDeudaPuntosBase:
        ahorroMinimoConDeudaPuntosBase ?? this.ahorroMinimoConDeudaPuntosBase,
    topeArrastreSemanas: topeArrastreSemanas ?? this.topeArrastreSemanas,
    umbrales: umbrales ?? this.umbrales,
    cierreAutomaticoDias: cierreAutomaticoDias ?? this.cierreAutomaticoDias,
    cuentaAjustesId: cuentaAjustesId ?? this.cuentaAjustesId,
    cuentaAperturaId: cuentaAperturaId ?? this.cuentaAperturaId,
    cuentaPorClasificarId: cuentaPorClasificarId ?? this.cuentaPorClasificarId,
  );

  /// Revisa que los valores tengan sentido. Lanza [ArgumentError].
  void validar() {
    void rango(int v, String nombre, int min, int max) {
      if (v < min || v > max) {
        throw ArgumentError.value(v, nombre, 'debe estar entre $min y $max');
      }
    }

    rango(metaRemanentePuntosBase, 'Meta de remanente', 0, 10000);
    rango(ahorroMinimoConDeudaPuntosBase, 'Ahorro mínimo con deuda', 0, 10000);
    rango(topeArrastreSemanas, 'Tope de arrastre', 0, 52);
    rango(cierreAutomaticoDias, 'Cierre automático', 1, 6);
    final u = umbrales;
    if (u.partidaAmbarDesde > u.partidaRojoArribaDe ||
        u.remanenteAmbarDesde > u.remanenteVerdeDesde ||
        u.cargaDeudaAmbarDesde > u.cargaDeudaRojoArribaDe ||
        u.cumplimientoAmbarDesde > u.cumplimientoVerdeDesde) {
      throw ArgumentError('El ámbar debe ir entre el verde y el rojo');
    }
  }
}

/// Cómo se guarda un calendario de pago (`forma`, `dia_semana`, `dias_mes`,
/// `fecha_ancla`, `intervalo_meses` y `regla_inhabil`).
///
/// La regla de día inhábil es **por origen** (regla 5 de 4.5; P13): si no se
/// elige ([reglaElegida] nula), un **ingreso** pasa al siguiente día hábil y
/// un **compromiso** o una **deuda** se queda en su fecha (`sin_cambio`,
/// como el `default` de `fin_compromisos` y `fin_deudas`). Solo la caja se
/// configura con `siguiente_dia_habil`.
class CalendarioConfig {
  final FormaPago forma;

  /// Semanal: 1 = lunes … 7 = domingo.
  final int? diaSemana;

  /// Quincenal y mensual: días del mes; **0 = último día**.
  final List<int> diasMes;

  /// Catorcenal y cada N meses: un pago conocido.
  final Fecha? fechaAncla;

  /// Cada N meses: 1, 2, 3, 6 o 12.
  final int? intervaloMeses;

  /// Regla que eligió la persona; nula = la de por omisión de quien usa el
  /// calendario ([reglaPara]).
  final ReglaDiaInhabil? reglaElegida;

  const CalendarioConfig({
    required this.forma,
    this.diaSemana,
    this.diasMes = const [],
    this.fechaAncla,
    this.intervaloMeses,
    ReglaDiaInhabil? regla,
  }) : reglaElegida = regla;

  const CalendarioConfig.semanal(int this.diaSemana, {ReglaDiaInhabil? regla})
    : forma = FormaPago.semanal,
      diasMes = const [],
      fechaAncla = null,
      intervaloMeses = null,
      reglaElegida = regla;

  const CalendarioConfig.catorcenal(
    Fecha this.fechaAncla, {
    ReglaDiaInhabil? regla,
  }) : forma = FormaPago.catorcenal,
       diaSemana = null,
       diasMes = const [],
       intervaloMeses = null,
       reglaElegida = regla;

  /// Quincenal: por defecto el 15 y el último día.
  const CalendarioConfig.quincenal({
    this.diasMes = const [15, 0],
    ReglaDiaInhabil? regla,
  }) : forma = FormaPago.quincenal,
       diaSemana = null,
       fechaAncla = null,
       intervaloMeses = null,
       reglaElegida = regla;

  /// Mensual en uno o dos días fijos (por ejemplo, 1 y 11).
  const CalendarioConfig.mensual(this.diasMes, {ReglaDiaInhabil? regla})
    : forma = FormaPago.mensual,
      diaSemana = null,
      fechaAncla = null,
      intervaloMeses = null,
      reglaElegida = regla;

  /// Cada [intervaloMeses] meses desde [fechaAncla] (bimestral = 2).
  const CalendarioConfig.cadaMeses(
    Fecha this.fechaAncla,
    int this.intervaloMeses, {
    ReglaDiaInhabil? regla,
  }) : forma = FormaPago.cadaMeses,
       diaSemana = null,
       diasMes = const [],
       reglaElegida = regla;

  /// Regla por omisión de un ingreso: el siguiente día hábil (5.1; decisión
  /// 44).
  static const reglaDeIngreso = ReglaDiaInhabil.siguienteDiaHabil;

  /// Regla por omisión de un pago que sale (compromiso o deuda): en su fecha
  /// (regla 5 de 4.5; P13).
  static const reglaDeSalida = ReglaDiaInhabil.sinCambio;

  /// La regla elegida o, si no hay, [porOmision].
  ReglaDiaInhabil reglaPara(ReglaDiaInhabil porOmision) =>
      reglaElegida ?? porOmision;

  /// La regla de un **ingreso** (por omisión, el siguiente día hábil).
  ReglaDiaInhabil get regla => reglaPara(reglaDeIngreso);

  static DiaDelMes _dia(int d) => d == 0 ? DiaDelMes.ultimo : DiaDelMes(d);

  /// El calendario del dominio con la regla de un ingreso (o [porOmision]).
  /// Lanza [ArgumentError] si le falta un dato.
  CalendarioPago get calendario => calendarioCon(reglaDeIngreso);

  /// El calendario del dominio con la regla elegida o [porOmision].
  CalendarioPago calendarioCon(ReglaDiaInhabil porOmision) {
    final regla = reglaPara(porOmision);
    switch (forma) {
      case FormaPago.semanal:
        return CalendarioPago.semanal(
          diaSemana ?? (throw ArgumentError('Falta el día de la semana')),
          regla: regla,
        );
      case FormaPago.catorcenal:
        return CalendarioPago.catorcenal(
          fechaAncla ?? (throw ArgumentError('Falta la fecha de un pago')),
          regla: regla,
        );
      case FormaPago.quincenal:
        final dias = diasMes.isEmpty ? const [15, 0] : diasMes;
        if (dias.length != 2) {
          throw ArgumentError('La quincena lleva dos días del mes');
        }
        return CalendarioPago.quincenal(
          primero: _dia(dias[0]),
          segundo: _dia(dias[1]),
          regla: regla,
        );
      case FormaPago.mensual:
        if (diasMes.isEmpty) throw ArgumentError('Falta el día del mes');
        return CalendarioPago.diasFijos([
          for (final d in diasMes) _dia(d),
        ], regla: regla);
      case FormaPago.cadaMeses:
        return CalendarioPago.cadaMeses(
          fechaAncla ?? (throw ArgumentError('Falta la fecha de un pago')),
          intervaloMeses ?? (throw ArgumentError('Falta cada cuántos meses')),
          regla: regla,
        );
    }
  }

  /// Frecuencia con los mismos pagos al año (para el equivalente semanal).
  Frecuencia get frecuencia => calendario.frecuencia;

  /// Fechas de pago (ya ajustadas al día hábil) entre [desde] y [hasta], con
  /// la regla elegida o [porOmision] (por omisión, la de un ingreso).
  List<FechaPago> pagosEntre(
    Fecha desde,
    Fecha hasta,
    CalendarioDiasInhabiles inhabiles, {
    ReglaDiaInhabil porOmision = reglaDeIngreso,
  }) => calendarioCon(porOmision).fechasDePago(desde, hasta, inhabiles);

  CalendarioConfig conRegla(ReglaDiaInhabil? nueva) => CalendarioConfig(
    forma: forma,
    diaSemana: diaSemana,
    diasMes: diasMes,
    fechaAncla: fechaAncla,
    intervaloMeses: intervaloMeses,
    regla: nueva,
  );
}

/// Tipo de ingreso (`fin_ingresos.tipo`).
enum TipoIngreso { salario, independiente, prestaciones, pension, otro }

/// Monto y calendario de un ingreso durante un periodo
/// (`fin_vigencias_ingreso`). Un cambio de neto crea una vigencia nueva y de
/// la anterior solo se cierra [hasta] (5.1 bis, punto 2).
///
/// Aquí [desde] y [hasta] son **fechas inclusivas** (el servidor compara con
/// `daterange(desde, hasta, '[]')`): el último día de una vigencia es su
/// `hasta`. No confundir con `hasta` de [MiembroLibro], que es exclusivo.
class VigenciaIngreso {
  final String id;
  final String ingresoId;

  /// Neto por pago, en centavos.
  final int montoNeto;
  final CalendarioConfig calendario;
  final Fecha desde;
  final Fecha? hasta;

  const VigenciaIngreso({
    required this.id,
    required this.ingresoId,
    required this.montoNeto,
    required this.calendario,
    required this.desde,
    this.hasta,
  });

  /// `true` si la vigencia cubre algún día del periodo.
  bool cubre(Fecha inicio, Fecha fin) =>
      !desde.despuesDe(fin) && (hasta == null || !hasta!.antesDe(inicio));

  bool vigenteEn(Fecha dia) => cubre(dia, dia);

  VigenciaIngreso cerrarEl(Fecha dia) => VigenciaIngreso(
    id: id,
    ingresoId: ingresoId,
    montoNeto: montoNeto,
    calendario: calendario,
    desde: desde,
    hasta: dia,
  );
}

/// Un ingreso recurrente de un libro (`fin_ingresos`). Los extras no tienen
/// configuración: son movimientos `ingreso` desde la cuenta "Extras".
class Ingreso {
  final String id;
  final String libroId;

  /// Quién lo recibe (en el libro de papá, papá).
  final String? personaId;
  final String nombre;
  final TipoIngreso tipo;

  /// Cuenta de origen de ingreso (clase ingreso) y cuenta donde cae (activo).
  final String cuentaOrigenId;
  final String cuentaDestinoId;
  final Certeza certeza;
  final bool activo;
  final List<VigenciaIngreso> vigencias;

  Ingreso({
    required this.id,
    required this.libroId,
    this.personaId,
    required this.nombre,
    this.tipo = TipoIngreso.salario,
    required this.cuentaOrigenId,
    required this.cuentaDestinoId,
    this.certeza = Certeza.segura,
    this.activo = true,
    List<VigenciaIngreso> vigencias = const [],
  }) : vigencias = List<VigenciaIngreso>.unmodifiable(
         <VigenciaIngreso>[...vigencias]
           ..sort((a, b) => a.desde.compareTo(b.desde)),
       );

  /// La vigencia que aplica en [semana]: la más reciente que la cubre.
  VigenciaIngreso? vigenciaEn(Semana semana) {
    VigenciaIngreso? elegida;
    for (final v in vigencias) {
      if (v.cubre(semana.inicio, semana.fin)) elegida = v;
    }
    return elegida;
  }

  /// La vigencia abierta (sin fecha de fin), si hay.
  VigenciaIngreso? get vigenciaActual =>
      vigencias.where((v) => v.hasta == null).lastOrNull;

  /// El ingreso para el plan de [semana] (nulo si no está activo o no hay
  /// vigencia).
  IngresoPlan? planEn(Semana semana) {
    if (!activo) return null;
    final v = vigenciaEn(semana);
    if (v == null) return null;
    return IngresoPlan(
      id: id,
      nombre: nombre,
      monto: v.montoNeto,
      frecuencia: v.calendario.frecuencia,
      certeza: certeza,
    );
  }

  /// Fechas de pago entre [desde] y [hasta] con el monto de la vigencia de
  /// cada fecha (por la fecha programada).
  List<(FechaPago, int)> pagosEntre(
    Fecha desde,
    Fecha hasta,
    CalendarioDiasInhabiles inhabiles,
  ) {
    if (!activo) return const [];
    final pagos = <(FechaPago, int)>[];
    for (final v in vigencias) {
      for (final p in v.calendario.pagosEntre(desde, hasta, inhabiles)) {
        if (v.vigenteEn(p.programada)) pagos.add((p, v.montoNeto));
      }
    }
    pagos.sort((a, b) => a.$1.ajustada.compareTo(b.$1.ajustada));
    return pagos;
  }

  Ingreso copiar({
    String? nombre,
    TipoIngreso? tipo,
    String? personaId,
    String? cuentaOrigenId,
    String? cuentaDestinoId,
    Certeza? certeza,
    bool? activo,
    List<VigenciaIngreso>? vigencias,
  }) => Ingreso(
    id: id,
    libroId: libroId,
    personaId: personaId ?? this.personaId,
    nombre: nombre ?? this.nombre,
    tipo: tipo ?? this.tipo,
    cuentaOrigenId: cuentaOrigenId ?? this.cuentaOrigenId,
    cuentaDestinoId: cuentaDestinoId ?? this.cuentaDestinoId,
    certeza: certeza ?? this.certeza,
    activo: activo ?? this.activo,
    vigencias: vigencias ?? this.vigencias,
  );

  /// Cambia el neto o el calendario **desde** [desde]: cierra la vigencia
  /// abierta el día anterior y agrega una nueva (el historial no se toca).
  /// Lanza [ArgumentError] si la vigencia abierta no empieza antes.
  Ingreso conNuevaVigencia({
    required String id,
    required int montoNeto,
    required CalendarioConfig calendario,
    required Fecha desde,
  }) {
    if (montoNeto <= 0) {
      throw ArgumentError('El neto debe ser mayor que cero');
    }
    final cambiadas = <VigenciaIngreso>[];
    for (final v in vigencias) {
      if (v.hasta == null) {
        if (!v.desde.antesDe(desde)) {
          throw ArgumentError(
            'El cambio debe empezar después del ${v.desde} (vigencia actual)',
          );
        }
        cambiadas.add(v.cerrarEl(desde.sumarDias(-1)));
      } else {
        cambiadas.add(v);
      }
    }
    return copiar(
      vigencias: [
        ...cambiadas,
        VigenciaIngreso(
          id: id,
          ingresoId: this.id,
          montoNeto: montoNeto,
          calendario: calendario,
          desde: desde,
        ),
      ],
    );
  }
}

/// Tipo de compromiso (`fin_compromisos.tipo`).
enum TipoCompromiso { fija, reserva }

/// Gasto fijo o reserva de un libro (`fin_compromisos`): renta, servicios,
/// placas, predial.
class Compromiso {
  final String id;
  final String libroId;
  final String nombre;
  final TipoCompromiso tipo;

  /// Cuenta de gasto del hogar (la de su categoría principal) y la
  /// subcategoría o detalle con que se registra el pago.
  final String cuentaGastoId;
  final String? categoriaId;
  final int monto;
  final Frecuencia frecuencia;
  final int? diasActivos;

  /// Fechas del pago, para el flujo y "lo que vence". Por defecto los pagos
  /// que salen se quedan en su fecha (`sin_cambio`, regla 5 de 4.5).
  final CalendarioConfig? calendario;
  final bool protegida;
  final Prioridad prioridad;
  final Fecha? desde;
  final Fecha? hasta;
  final bool activo;

  const Compromiso({
    required this.id,
    required this.libroId,
    required this.nombre,
    this.tipo = TipoCompromiso.fija,
    required this.cuentaGastoId,
    this.categoriaId,
    required this.monto,
    required this.frecuencia,
    this.diasActivos,
    this.calendario,
    this.protegida = false,
    this.prioridad = Prioridad.necesario,
    this.desde,
    this.hasta,
    this.activo = true,
  });

  bool vigenteEn(Semana s) =>
      activo &&
      (desde == null || !desde!.despuesDe(s.fin)) &&
      (hasta == null || !hasta!.antesDe(s.inicio));

  PartidaPlan get partida => PartidaPlan(
    id: id,
    nombre: nombre,
    tipo: tipo == TipoCompromiso.fija ? TipoPartida.fija : TipoPartida.reserva,
    cuentaGastoId: cuentaGastoId,
    monto: monto,
    frecuencia: frecuencia,
    diasActivosPorSemana: diasActivos,
    protegida: protegida,
    prioridad: prioridad,
  );

  /// Revisa que la frecuencia y el calendario coincidan. Lanza
  /// [ArgumentError].
  void validar() {
    if (monto <= 0) throw ArgumentError('El monto debe ser mayor que cero');
    final c = calendario;
    if (c != null && frecuencia != Frecuencia.diaria) {
      if (c.frecuencia != frecuencia) {
        throw ArgumentError(
          'La frecuencia (${frecuencia.name}) no coincide con el calendario '
          '(${c.frecuencia.name})',
        );
      }
    }
  }

  /// Regla de día inhábil del compromiso (`fin_compromisos.regla_inhabil`):
  /// la elegida o, por omisión, **en su fecha** (regla 5 de 4.5).
  ReglaDiaInhabil get reglaInhabil =>
      calendario?.reglaPara(CalendarioConfig.reglaDeSalida) ??
      CalendarioConfig.reglaDeSalida;

  /// Pagos entre [desde] y [hasta] (vacío sin calendario).
  List<FechaPago> pagosEntre(
    Fecha inicio,
    Fecha fin,
    CalendarioDiasInhabiles inhabiles,
  ) {
    final c = calendario;
    if (c == null || !activo) return const [];
    return c
        .pagosEntre(
          inicio,
          fin,
          inhabiles,
          porOmision: CalendarioConfig.reglaDeSalida,
        )
        .where(
          (p) =>
              (desde == null || !p.programada.antesDe(desde!)) &&
              (hasta == null || !p.programada.despuesDe(hasta!)),
        )
        .toList();
  }
}

/// Sobre semanal de una cuenta de gasto (`fin_sobres`): las partidas
/// variables del presupuesto.
class Sobre {
  final String id;
  final String libroId;
  final String cuentaGastoId;
  final String nombre;
  final int montoSemanal;
  final bool protegida;
  final Prioridad prioridad;
  final int pisoMinimo;
  final ModoArrastre modoArrastre;
  final bool activo;

  const Sobre({
    required this.id,
    required this.libroId,
    required this.cuentaGastoId,
    required this.nombre,
    required this.montoSemanal,
    this.protegida = false,
    this.prioridad = Prioridad.deseable,
    this.pisoMinimo = 0,
    this.modoArrastre = ModoArrastre.arrastrar,
    this.activo = true,
  });

  PartidaPlan get partida => PartidaPlan.variable(
    id: id,
    nombre: nombre,
    montoSemanal: montoSemanal,
    cuentaGastoId: cuentaGastoId,
    protegida: protegida,
    prioridad: prioridad,
    pisoMinimo: pisoMinimo,
    arrastre: modoArrastre,
  );

  Sobre conMonto(int nuevo) => Sobre(
    id: id,
    libroId: libroId,
    cuentaGastoId: cuentaGastoId,
    nombre: nombre,
    montoSemanal: nuevo,
    protegida: protegida,
    prioridad: prioridad,
    pisoMinimo: pisoMinimo,
    modoArrastre: modoArrastre,
    activo: activo,
  );
}

/// Deuda de un libro (`fin_deudas`), con lo mínimo para la cascada. El saldo
/// sale del libro (su cuenta pasivo).
class Deuda {
  final String id;
  final String libroId;
  final String nombre;
  final TipoDeuda tipo;

  /// Tarjeta o préstamo (clase pasivo) donde vive el saldo.
  final String? cuentaPasivoId;
  final int abono;
  final Frecuencia frecuencia;

  /// Fechas del pago; por defecto en su fecha (`sin_cambio`, regla 5 de 4.5).
  final CalendarioConfig? calendario;
  final int minimo;
  final int tasaAnualPuntosBase;
  final int? prioridadManual;

  /// Grupo de deudas prioritarias (P12; regla 4 de 4.5).
  final bool grupoPrioritario;
  final int? ordenGrupo;
  final bool activa;

  // Fase 2 (deudas a detalle). Todos opcionales: una deuda de la Fase 1 sigue
  // siendo válida y el servidor deduce la clase.
  final ClaseDeuda? clase;
  final String? acreedor;
  final int? montoOriginal;
  final int? catPuntosBase;

  /// Día del mes del corte de una tarjeta (0 = último día).
  final int? corteDia;

  /// `null` = "verificar con la caja": no se propone extra a capital (regla 12).
  final bool? permitePagoAnticipado;

  /// `plazo` o `cuota`: qué reduce un abono extra.
  final String? extraReduce;

  const Deuda({
    required this.id,
    required this.libroId,
    required this.nombre,
    required this.tipo,
    this.cuentaPasivoId,
    required this.abono,
    required this.frecuencia,
    this.calendario,
    this.minimo = 0,
    this.tasaAnualPuntosBase = 0,
    this.prioridadManual,
    this.grupoPrioritario = false,
    this.ordenGrupo,
    this.activa = true,
    this.clase,
    this.acreedor,
    this.montoOriginal,
    this.catPuntosBase,
    this.corteDia,
    this.permitePagoAnticipado,
    this.extraReduce,
  });

  /// Nombre para mostrar: el acreedor si lo hay, si no el nombre.
  String get titulo => acreedor ?? nombre;

  /// La deuda para el motor, con su [saldo] actual (si se conoce).
  /// Lanza [ArgumentError] si falta la tasa de una deuda con costo.
  DeudaPlan plan({int? saldo}) => DeudaPlan(
    id: id,
    nombre: nombre,
    tipo: tipo,
    abono: abono,
    frecuencia: frecuencia,
    minimo: minimo,
    tasaAnualPuntosBase: tasaAnualPuntosBase,
    saldo: saldo,
    prioridadManual: prioridadManual,
    grupoPrioritario: grupoPrioritario,
    ordenGrupo: ordenGrupo,
  );

  void validar() {
    plan();
    final c = calendario;
    if (c != null && c.frecuencia != frecuencia) {
      throw ArgumentError(
        'La frecuencia (${frecuencia.name}) no coincide con el calendario',
      );
    }
  }

  /// Regla de día inhábil de la deuda (`fin_deudas.regla_inhabil`): la
  /// elegida o, por omisión, **en su fecha** (regla 5 de 4.5; solo la caja
  /// pasa al siguiente día hábil).
  ReglaDiaInhabil get reglaInhabil =>
      calendario?.reglaPara(CalendarioConfig.reglaDeSalida) ??
      CalendarioConfig.reglaDeSalida;

  List<FechaPago> pagosEntre(
    Fecha inicio,
    Fecha fin,
    CalendarioDiasInhabiles inhabiles,
  ) {
    final c = calendario;
    if (c == null || !activa) return const [];
    return c.pagosEntre(
      inicio,
      fin,
      inhabiles,
      porOmision: CalendarioConfig.reglaDeSalida,
    );
  }

  Deuda copiar({
    String? nombre,
    int? abono,
    int? minimo,
    int? tasaAnualPuntosBase,
    bool? grupoPrioritario,
    int? ordenGrupo,
    bool? activa,
    ClaseDeuda? clase,
    String? acreedor,
    int? montoOriginal,
    int? catPuntosBase,
    int? corteDia,
    bool? permitePagoAnticipado,
    String? extraReduce,
  }) => Deuda(
    id: id,
    libroId: libroId,
    clase: clase ?? this.clase,
    acreedor: acreedor ?? this.acreedor,
    montoOriginal: montoOriginal ?? this.montoOriginal,
    catPuntosBase: catPuntosBase ?? this.catPuntosBase,
    corteDia: corteDia ?? this.corteDia,
    permitePagoAnticipado: permitePagoAnticipado ?? this.permitePagoAnticipado,
    extraReduce: extraReduce ?? this.extraReduce,
    nombre: nombre ?? this.nombre,
    tipo: tipo,
    cuentaPasivoId: cuentaPasivoId,
    abono: abono ?? this.abono,
    frecuencia: frecuencia,
    calendario: calendario,
    minimo: minimo ?? this.minimo,
    tasaAnualPuntosBase: tasaAnualPuntosBase ?? this.tasaAnualPuntosBase,
    prioridadManual: prioridadManual,
    grupoPrioritario: grupoPrioritario ?? this.grupoPrioritario,
    ordenGrupo: grupoPrioritario == false
        ? null
        : (ordenGrupo ?? this.ordenGrupo),
    activa: activa ?? this.activa,
  );
}
