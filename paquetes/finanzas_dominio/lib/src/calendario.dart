import 'fecha.dart';
import 'frecuencia.dart';

/// Qué hacer cuando un pago cae en sábado, domingo o día inhábil
/// (5.1 y 5.6 bis, punto 2; decisión 44). Es configurable por ingreso.
enum ReglaDiaInhabil {
  /// Pasa al siguiente día hábil (el lunes, si cae en fin de semana).
  /// Valor por defecto de los **ingresos** (decisión 44).
  siguienteDiaHabil,

  /// Se adelanta al día hábil anterior.
  diaHabilAnterior,

  /// Se queda en su fecha.
  ///
  /// Interpretación conservadora: es el valor por defecto de los **pagos que
  /// salen** (renta, servicios), porque mover una salida hacia adelante podría
  /// esconder un faltante. Coincide con el ejemplo de flujo de 5.6 bis
  /// (la renta del domingo 1/nov sale esa semana). El ejemplo de 5.1 bis,
  /// punto 9, mueve la renta al lunes: queda como pregunta para el dueño.
  sinCambio,
}

/// Tipo de día inhábil (entidad `DíaInhábil`, sección 7 del diseño).
enum TipoDiaInhabil { festivoOficial, personal }

/// Un día inhábil del calendario editable del hogar (`fin_dias_inhabiles`).
class DiaInhabil {
  /// UUID del registro (nulo en la precarga que aún no se guarda).
  final String? id;
  final Fecha fecha;
  final String nombre;
  final TipoDiaInhabil tipo;

  /// De dónde sale (por ejemplo, "LFT art. 74, fracción I").
  final String fuente;

  /// Solo los activos cuentan en el calendario. La precarga de festivos
  /// llega **inactiva** hasta que el dueño la revisa (decisión 55).
  final bool activo;
  final String? revisadoPor;
  final DateTime? revisadoEn;

  const DiaInhabil({
    this.id,
    required this.fecha,
    required this.nombre,
    this.tipo = TipoDiaInhabil.festivoOficial,
    this.fuente = '',
    this.activo = true,
    this.revisadoPor,
    this.revisadoEn,
  });

  DiaInhabil copiar({
    String? id,
    String? nombre,
    bool? activo,
    String? revisadoPor,
    DateTime? revisadoEn,
  }) => DiaInhabil(
    id: id ?? this.id,
    fecha: fecha,
    nombre: nombre ?? this.nombre,
    tipo: tipo,
    fuente: fuente,
    activo: activo ?? this.activo,
    revisadoPor: revisadoPor ?? this.revisadoPor,
    revisadoEn: revisadoEn ?? this.revisadoEn,
  );

  @override
  String toString() => '$fecha $nombre';
}

/// Calendario de días inhábiles **inyectable** (5.1: "calendario de días
/// inhábiles editable"). El fin de semana no se guarda aquí: siempre es
/// inhábil.
abstract interface class CalendarioDiasInhabiles {
  bool esInhabil(Fecha fecha);
}

/// Calendario con una lista fija de fechas (la que el hogar revisó y activó).
class CalendarioFijo implements CalendarioDiasInhabiles {
  final Set<Fecha> _fechas;

  CalendarioFijo(Iterable<Fecha> fechas) : _fechas = Set.unmodifiable(fechas);

  /// Calendario a partir de los [DiaInhabil] del hogar (solo los activos).
  factory CalendarioFijo.deDias(Iterable<DiaInhabil> dias) =>
      CalendarioFijo(dias.where((d) => d.activo).map((d) => d.fecha));

  /// Sin festivos: solo los fines de semana son inhábiles.
  static final CalendarioFijo vacio = CalendarioFijo(const []);

  @override
  bool esInhabil(Fecha fecha) => _fechas.contains(fecha);
}

/// `true` si [fecha] no es sábado, domingo ni día inhábil de [calendario].
bool esDiaHabil(Fecha fecha, CalendarioDiasInhabiles calendario) =>
    !fecha.esFinDeSemana && !calendario.esInhabil(fecha);

/// Aplica la [regla] de fin de semana y festivos a [fecha] (5.1).
///
/// Ejemplo (prueba IN2): la quincena del sábado 31/oct/2026 se paga el
/// lunes 2/nov/2026.
Fecha ajustarADiaHabil(
  Fecha fecha,
  ReglaDiaInhabil regla,
  CalendarioDiasInhabiles calendario,
) {
  if (regla == ReglaDiaInhabil.sinCambio) return fecha;
  final paso = regla == ReglaDiaInhabil.siguienteDiaHabil ? 1 : -1;
  var actual = fecha;
  // Un calendario razonable nunca tiene 31 días inhábiles seguidos.
  for (var i = 0; i < 31; i++) {
    if (esDiaHabil(actual, calendario)) return actual;
    actual = actual.sumarDias(paso);
  }
  throw StateError('No hay un día hábil cerca de $fecha: revisa el calendario');
}

/// Precarga de los **días de descanso obligatorio** de la Ley Federal del
/// Trabajo, artículo 74, para [anio] (decisión 55: solo festivos oficiales).
///
/// Incluye: 1 de enero; primer lunes de febrero; tercer lunes de marzo;
/// 1 de mayo; 16 de septiembre; tercer lunes de noviembre; 1 de octubre cada
/// seis años, cuando hay transmisión del Poder Ejecutivo Federal (2024, 2030…);
/// y 25 de diciembre.
///
/// **No incluye** las jornadas electorales (fracción IX): cambian y las agrega
/// el hogar a mano. Tampoco incluye días inhábiles bancarios que no son
/// festivos oficiales (Jueves y Viernes Santo, 12 de diciembre…).
///
/// Es solo la **precarga**: el diseño pide que el hogar la revise cada año y
/// la verifique contra la fuente oficial (DOF) antes de activarla (5.1).
List<DiaInhabil> festivosOficialesMexico(int anio) {
  DiaInhabil dia(Fecha fecha, String nombre, String fraccion) => DiaInhabil(
    fecha: fecha,
    nombre: nombre,
    fuente: 'LFT art. 74, fracción $fraccion',
  );
  final dias = <DiaInhabil>[
    dia(Fecha(anio, 1, 1), 'Año Nuevo', 'I'),
    dia(nEsimoLunes(anio, 2, 1), 'Día de la Constitución', 'II'),
    dia(nEsimoLunes(anio, 3, 3), 'Natalicio de Benito Juárez', 'III'),
    dia(Fecha(anio, 5, 1), 'Día del Trabajo', 'IV'),
    dia(Fecha(anio, 9, 16), 'Día de la Independencia', 'V'),
    if (anio >= 2024 && (anio - 2024) % 6 == 0)
      dia(Fecha(anio, 10, 1), 'Transmisión del Poder Ejecutivo Federal', 'VII'),
    dia(nEsimoLunes(anio, 11, 3), 'Día de la Revolución', 'VI'),
    dia(Fecha(anio, 12, 25), 'Navidad', 'VIII'),
  ];
  return dias;
}

/// El [n]-ésimo lunes de [mes] de [anio] (n = 1 es el primer lunes).
Fecha nEsimoLunes(int anio, int mes, int n) {
  final primero = Fecha(anio, mes, 1);
  final hastaLunes = (DateTime.monday - primero.diaSemana + 7) % 7;
  return primero.sumarDias(hastaLunes + 7 * (n - 1));
}

/// Formas de ingreso o de pago recurrente (5.1, "Forma de ingreso y día de
/// pago"). Los extras no tienen calendario: se registran con su fecha real.
///
/// [cadaMeses] cubre los compromisos bimestrales, trimestrales, semestrales y
/// anuales (luz, predial, seguro) para la vista de flujo.
enum FormaPago { semanal, catorcenal, quincenal, mensual, cadaMeses }

/// Día del mes de un pago: un número (1 a 31) o el último día del mes.
///
/// Interpretación conservadora: si el mes no tiene ese día (por ejemplo, el
/// 31 en abril), el pago se toma el **último día** de ese mes.
class DiaDelMes {
  /// Día del mes, o nulo para "último día".
  final int? numero;

  const DiaDelMes(int this.numero)
    : assert(numero >= 1 && numero <= 31, 'El día debe estar entre 1 y 31');

  const DiaDelMes._ultimo() : numero = null;

  static const DiaDelMes ultimo = DiaDelMes._ultimo();

  Fecha en(int anio, int mes) => Fecha.enMes(anio, mes, numero ?? 31);

  @override
  bool operator ==(Object other) =>
      other is DiaDelMes && other.numero == numero;

  @override
  int get hashCode => numero.hashCode;

  @override
  String toString() => numero == null ? 'último' : '$numero';
}

/// Calendario de un ingreso o pago recurrente (`ConfigIngreso`, 5.6 bis
/// punto 11).
class CalendarioPago {
  final FormaPago forma;

  /// Semanal: día de la semana (1 = lunes … 7 = domingo).
  final int? diaSemana;

  /// Catorcenal: fecha ancla; se paga cada 14 días desde ella.
  /// Cada N meses: fecha de un pago conocido.
  final Fecha? ancla;

  /// Cada N meses: el intervalo (2 bimestral, 3 trimestral, 6 semestral,
  /// 12 anual).
  final int? intervaloMeses;

  /// Quincenal: los dos días del mes (por defecto 15 y último).
  /// Mensual: un solo día.
  final List<DiaDelMes> diasDelMes;

  final ReglaDiaInhabil regla;

  CalendarioPago._(
    this.forma, {
    this.diaSemana,
    this.ancla,
    this.intervaloMeses,
    this.diasDelMes = const [],
    required this.regla,
  });

  factory CalendarioPago.semanal(
    int diaSemana, {
    ReglaDiaInhabil regla = ReglaDiaInhabil.siguienteDiaHabil,
  }) {
    if (diaSemana < 1 || diaSemana > 7) {
      throw ArgumentError.value(diaSemana, 'diaSemana', 'debe ser de 1 a 7');
    }
    return CalendarioPago._(
      FormaPago.semanal,
      diaSemana: diaSemana,
      regla: regla,
    );
  }

  factory CalendarioPago.catorcenal(
    Fecha ancla, {
    ReglaDiaInhabil regla = ReglaDiaInhabil.siguienteDiaHabil,
  }) => CalendarioPago._(FormaPago.catorcenal, ancla: ancla, regla: regla);

  /// Quincenal; por defecto el 15 y el último día del mes (5.1).
  factory CalendarioPago.quincenal({
    DiaDelMes primero = const DiaDelMes(15),
    DiaDelMes segundo = DiaDelMes.ultimo,
    ReglaDiaInhabil regla = ReglaDiaInhabil.siguienteDiaHabil,
  }) => CalendarioPago._(
    FormaPago.quincenal,
    diasDelMes: List.unmodifiable([primero, segundo]),
    regla: regla,
  );

  factory CalendarioPago.mensual(
    DiaDelMes dia, {
    ReglaDiaInhabil regla = ReglaDiaInhabil.siguienteDiaHabil,
  }) => CalendarioPago._(
    FormaPago.mensual,
    diasDelMes: List.unmodifiable([dia]),
    regla: regla,
  );

  /// Varios **días fijos** de cada mes (por ejemplo, la pensión de los días
  /// 1 y 11; P15 y regla 6 de 4.5). Con un solo día es igual a [mensual].
  /// Se admiten 1 o 2 días: con 2 días al mes el equivalente semanal es el
  /// de 24 pagos al año (× 24 ÷ 52), igual que el quincenal.
  factory CalendarioPago.diasFijos(
    List<DiaDelMes> dias, {
    ReglaDiaInhabil regla = ReglaDiaInhabil.siguienteDiaHabil,
  }) {
    final distintos = dias.toSet().toList();
    if (distintos.isEmpty || distintos.length > 2) {
      throw ArgumentError('Se admiten 1 o 2 días fijos por mes');
    }
    return CalendarioPago._(
      FormaPago.mensual,
      diasDelMes: List.unmodifiable(distintos),
      regla: regla,
    );
  }

  /// Cada [meses] meses a partir de la fecha [ancla] (un pago conocido), en
  /// el mismo día del mes (o el último, si el mes es más corto).
  factory CalendarioPago.cadaMeses(
    Fecha ancla,
    int meses, {
    ReglaDiaInhabil regla = ReglaDiaInhabil.siguienteDiaHabil,
  }) {
    if (!const {1, 2, 3, 6, 12}.contains(meses)) {
      throw ArgumentError.value(
        meses,
        'meses',
        'debe ser 1, 2, 3, 6 o 12 (mensual, bimestral, trimestral, semestral '
            'o anual)',
      );
    }
    return CalendarioPago._(
      FormaPago.cadaMeses,
      ancla: ancla,
      intervaloMeses: meses,
      regla: regla,
    );
  }

  /// Cuántos pagos hay en un año (base de su equivalente semanal, sección 4).
  int get vecesAlAnio => switch (forma) {
    FormaPago.semanal => 52,
    FormaPago.catorcenal => 26,
    FormaPago.quincenal => 24,
    FormaPago.mensual => 12 * diasDelMes.length,
    FormaPago.cadaMeses => 12 ~/ intervaloMeses!,
  };

  /// Frecuencia con el mismo número de pagos al año, para el equivalente
  /// semanal (sección 4). Dos días fijos al mes equivalen a 24 pagos al año,
  /// como el quincenal; cada 2, 3, 6 o 12 meses es bimestral, trimestral,
  /// semestral o anual.
  Frecuencia get frecuencia => switch (vecesAlAnio) {
    52 => Frecuencia.semanal,
    26 => Frecuencia.catorcenal,
    24 => Frecuencia.quincenal,
    12 => Frecuencia.mensual,
    6 => Frecuencia.bimestral,
    4 => Frecuencia.trimestral,
    2 => Frecuencia.semestral,
    1 => Frecuencia.anual,
    final n => throw StateError('$n pagos al año no tienen equivalente'),
  };

  /// Fechas nominales (sin ajustar) entre [desde] y [hasta], inclusive.
  List<Fecha> fechasNominales(Fecha desde, Fecha hasta) {
    final fechas = <Fecha>[];
    switch (forma) {
      case FormaPago.semanal:
        var f = desde.sumarDias((diaSemana! - desde.diaSemana + 7) % 7);
        while (!f.despuesDe(hasta)) {
          fechas.add(f);
          f = f.sumarDias(7);
        }
      case FormaPago.catorcenal:
        final dias = ancla!.diasHasta(desde);
        var f = ancla!.sumarDias((dias / 14).ceil() * 14);
        while (!f.despuesDe(hasta)) {
          fechas.add(f);
          f = f.sumarDias(14);
        }
      case FormaPago.cadaMeses:
        final n = intervaloMeses!;
        final base = ancla!;
        final mesesHastaDesde =
            (desde.anio - base.anio) * 12 + desde.mes - base.mes;
        var k = (mesesHastaDesde / n).floor() - 1;
        while (true) {
          final f = Fecha.enMes(base.anio, base.mes + k * n, base.dia);
          if (f.despuesDe(hasta)) break;
          if (!f.antesDe(desde)) fechas.add(f);
          k += 1;
        }
      case FormaPago.quincenal:
      case FormaPago.mensual:
        var anio = desde.anio;
        var mes = desde.mes;
        while (!Fecha(anio, mes, 1).despuesDe(hasta)) {
          final delMes = {for (final d in diasDelMes) d.en(anio, mes)}.toList()
            ..sort();
          for (final f in delMes) {
            if (!f.antesDe(desde) && !f.despuesDe(hasta)) fechas.add(f);
          }
          mes += 1;
          if (mes > 12) {
            mes = 1;
            anio += 1;
          }
        }
    }
    return fechas;
  }

  /// Fechas de pago cuya **fecha ajustada** cae entre [desde] y [hasta]
  /// (5.6 bis, punto 4, paso 1: "ocurrencias" con la regla de fin de semana).
  ///
  /// Revisa también unos días antes y después del rango, porque un pago
  /// nominal del sábado puede caer, ya ajustado, en el lunes del rango.
  List<FechaPago> fechasDePago(
    Fecha desde,
    Fecha hasta,
    CalendarioDiasInhabiles calendario,
  ) {
    const margen = 31;
    return [
          for (final nominal in fechasNominales(
            desde.sumarDias(-margen),
            hasta.sumarDias(margen),
          ))
            FechaPago(nominal, ajustarADiaHabil(nominal, regla, calendario)),
        ]
        .where(
          (p) => !p.ajustada.antesDe(desde) && !p.ajustada.despuesDe(hasta),
        )
        .toList();
  }
}

/// Una fecha de pago: la programada y la ajustada al día hábil.
class FechaPago {
  final Fecha programada;
  final Fecha ajustada;

  const FechaPago(this.programada, this.ajustada);

  bool get seMovio => programada != ajustada;

  @override
  bool operator ==(Object other) =>
      other is FechaPago &&
      other.programada == programada &&
      other.ajustada == ajustada;

  @override
  int get hashCode => Object.hash(programada, ajustada);

  @override
  String toString() => seMovio ? '$programada → $ajustada' : '$programada';
}
