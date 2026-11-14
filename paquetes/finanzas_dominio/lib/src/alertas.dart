/// Alertas y avisos discretos (Fase 2, secciones 5.4 y 5.5 de
/// `docs/specs/fase-2-finanzas.md`). Dart puro: catálogo de tipos con nivel,
/// origen y destinatarios; catálogo cerrado de textos (sin dinero, D3);
/// preferencias; y las reglas de cuándo avisar, silencio y tope diario.
library;

/// Nivel de una alerta (regla 33).
enum NivelAlerta { critica, importante, informativa }

/// Quién genera la alerta (regla 32).
enum OrigenAlerta { servidor, app, local, servidorYLocal }

/// A quién llega (regla 41; nunca la cuenta maestra).
enum DestinoAlerta {
  miembrosDelLibro,
  quienRegistroYTitular,
  titular,
  titularOAlbacea,
  suplente,
  duenio,
  otrosMiembros,
  cadaPersona,
  quienRegistro,
}

/// Catálogo de la Fase 2: un `tipo` por alerta.
enum TipoAlerta {
  pagoProximo(
    'pago_proximo',
    NivelAlerta.critica,
    OrigenAlerta.servidorYLocal,
    DestinoAlerta.miembrosDelLibro,
    'Tienes un pago próximo',
  ),
  limiteTarjeta(
    'limite_tarjeta',
    NivelAlerta.critica,
    OrigenAlerta.servidorYLocal,
    DestinoAlerta.miembrosDelLibro,
    'Vence un pago de tarjeta',
  ),
  pagoVencido(
    'pago_vencido',
    NivelAlerta.critica,
    OrigenAlerta.servidor,
    DestinoAlerta.miembrosDelLibro,
    'Hay un pago sin registrar',
  ),
  protegidoRiesgo(
    'protegido_riesgo',
    NivelAlerta.critica,
    OrigenAlerta.app,
    DestinoAlerta.miembrosDelLibro,
    'Un gasto protegido necesita atención',
  ),
  flujoNegativo(
    'flujo_negativo',
    NivelAlerta.critica,
    OrigenAlerta.app,
    DestinoAlerta.miembrosDelLibro,
    'Revisa el flujo de la semana',
  ),
  abonoBajoMinimo(
    'abono_bajo_minimo',
    NivelAlerta.critica,
    OrigenAlerta.app,
    DestinoAlerta.miembrosDelLibro,
    'Revisa tus pagos de deuda',
  ),
  partida100(
    'partida_100',
    NivelAlerta.importante,
    OrigenAlerta.app,
    DestinoAlerta.quienRegistroYTitular,
    'Revisa una categoría',
  ),
  ingresoRetrasado(
    'ingreso_retrasado',
    NivelAlerta.importante,
    OrigenAlerta.servidor,
    DestinoAlerta.titularOAlbacea,
    'Un ingreso no ha llegado',
  ),
  fondoBajo(
    'fondo_bajo',
    NivelAlerta.importante,
    OrigenAlerta.app,
    DestinoAlerta.titular,
    'Revisa tu ahorro',
  ),
  salidaLibroRepresentado(
    'salida_libro_representado',
    NivelAlerta.importante,
    OrigenAlerta.servidor,
    DestinoAlerta.suplente,
    'Hay un movimiento por revisar',
  ),
  base80(
    'base_80',
    NivelAlerta.importante,
    OrigenAlerta.servidor,
    DestinoAlerta.duenio,
    'Revisa el almacenamiento de GRAVITY',
  ),
  base90(
    'base_90',
    NivelAlerta.critica,
    OrigenAlerta.servidor,
    DestinoAlerta.duenio,
    'Revisa el almacenamiento de GRAVITY',
  ),
  partida80(
    'partida_80',
    NivelAlerta.informativa,
    OrigenAlerta.app,
    DestinoAlerta.quienRegistro,
    'Una categoría se acerca a su límite',
  ),
  usoLimite(
    'uso_limite',
    NivelAlerta.informativa,
    OrigenAlerta.app,
    DestinoAlerta.titular,
    'Revisa el uso de una tarjeta',
  ),
  aportacionPendiente(
    'aportacion_pendiente',
    NivelAlerta.informativa,
    OrigenAlerta.local,
    DestinoAlerta.titular,
    'Hay ahorro por confirmar',
  ),
  conciliacionPendiente(
    'conciliacion_pendiente',
    NivelAlerta.informativa,
    OrigenAlerta.local,
    DestinoAlerta.titular,
    'Falta conciliar el efectivo',
  ),
  retiroBolsaCompartida(
    'retiro_bolsa_compartida',
    NivelAlerta.informativa,
    OrigenAlerta.servidor,
    DestinoAlerta.otrosMiembros,
    'Hay un movimiento por revisar',
  ),
  resumenLunes(
    'resumen_lunes',
    NivelAlerta.informativa,
    OrigenAlerta.local,
    DestinoAlerta.cadaPersona,
    'Tu resumen de la semana está listo',
    fija: true,
  ),
  recordatorioCierre(
    'recordatorio_cierre',
    NivelAlerta.informativa,
    OrigenAlerta.local,
    DestinoAlerta.cadaPersona,
    'Es hora de cerrar la semana',
    fija: true,
  );

  const TipoAlerta(
    this.clave,
    this.nivel,
    this.origen,
    this.destino,
    this.titulo, {
    this.fija = false,
  });

  /// Valor guardado (`tipo` en la tabla de avisos).
  final String clave;
  final NivelAlerta nivel;
  final OrigenAlerta origen;
  final DestinoAlerta destino;

  /// Título discreto del catálogo cerrado (regla 42).
  final String titulo;

  /// Fijas: no se pueden desactivar por tipo ni usan "días antes".
  final bool fija;

  bool get esCritica => nivel == NivelAlerta.critica;

  static TipoAlerta? deClave(String clave) {
    for (final t in values) {
      if (t.clave == clave) return t;
    }
    return null;
  }
}

/// Catálogo cerrado de textos (regla 42 y D3): máximo 40 caracteres, sin
/// dígitos, sin "$" y sin nombres propios. El cuerpo va siempre vacío.
class TextoAviso {
  TextoAviso._();

  /// Texto cuando no hay sesión o señal.
  static const generico = 'Tienes un aviso de GRAVITY';

  /// Versión pública para la pantalla bloqueada.
  static const publicoDeBloqueo = 'GRAVITY · tienes un aviso';

  static const int maximo = 40;

  /// Cuerpo de todo aviso: vacío por construcción.
  static const cuerpo = '';

  /// Título para una clave; clave desconocida, genérico.
  static String paraClave(String clave) =>
      TipoAlerta.deClave(clave)?.titulo ?? generico;

  /// Todos los textos del catálogo.
  static Iterable<String> todos() sync* {
    for (final t in TipoAlerta.values) {
      yield t.titulo;
    }
    yield generico;
    yield publicoDeBloqueo;
  }

  /// `true` si el texto cumple las reglas de discreción.
  static bool esDiscreto(String texto) =>
      texto.length <= maximo &&
      !texto.contains(r'$') &&
      !RegExp(r'[0-9]').hasMatch(texto);
}

// --------------------------------------------------------------- preferencias

/// Preferencias de avisos de una persona (reglas 34 a 37 y 48).
class PreferenciasAviso {
  /// Días antes del vencimiento (0 a 3 valores entre 0 y 14).
  final List<int> diasAntes;

  /// Hora de inicio y fin del silencio (0 a 23). Por defecto 22 a 7.
  final int silencioDesde;
  final int silencioHasta;
  final bool criticasEnSilencio;

  /// Tope de avisos no críticos al día (0 a 10).
  final int topeDiario;

  /// Hora de los avisos de vencimiento.
  final int horaVencimientos;
  final Set<String> tiposSilenciados;

  const PreferenciasAviso({
    this.diasAntes = const [3, 1],
    this.silencioDesde = 22,
    this.silencioHasta = 7,
    this.criticasEnSilencio = false,
    this.topeDiario = 3,
    this.horaVencimientos = 9,
    this.tiposSilenciados = const {},
  });

  /// Mensaje de error si hay rangos inválidos; `null` si todo está bien.
  String? validar() {
    if (topeDiario < 0 || topeDiario > 10) return 'El tope va de 0 a 10.';
    if (diasAntes.length > 3) return 'Máximo 3 avisos antes.';
    if (diasAntes.any((d) => d < 0 || d > 14)) return 'Los días van de 0 a 14.';
    if (silencioDesde < 0 ||
        silencioDesde > 23 ||
        silencioHasta < 0 ||
        silencioHasta > 23) {
      return 'Las horas van de 0 a 23.';
    }
    if (silencioDesde == silencioHasta)
      return 'Las horas silenciosas no pueden ser iguales.';
    if (horaVencimientos < 0 || horaVencimientos > 23) return 'Hora inválida.';
    return null;
  }

  /// `true` si [hora] (0 a 23) cae en el silencio; cruza la medianoche.
  bool esSilencio(int hora) => silencioDesde > silencioHasta
      ? hora >= silencioDesde || hora < silencioHasta
      : hora >= silencioDesde && hora < silencioHasta;
}

// ------------------------------------------------------------------- reglas

/// Momentos de aviso de un vencimiento: cada "día antes" a la hora de los
/// vencimientos. Los que ya pasaron respecto a [ahora] se omiten (regla 34).
List<DateTime> momentosDeVencimiento(
  DateTime vencimiento,
  PreferenciasAviso prefs, {
  DateTime? ahora,
}) {
  final dia = DateTime(vencimiento.year, vencimiento.month, vencimiento.day);
  final lista = <DateTime>[];
  for (final d in {...prefs.diasAntes}) {
    final m = DateTime(
      dia.year,
      dia.month,
      dia.day - d,
      prefs.horaVencimientos,
    );
    if (ahora == null || !m.isBefore(ahora)) lista.add(m);
  }
  lista.sort();
  return lista;
}

/// Momentos de un pago vencido sin registrar: al día siguiente y a los 3 días.
List<DateTime> momentosDePagoVencido(
  DateTime vencimiento,
  PreferenciasAviso prefs,
) {
  final dia = DateTime(vencimiento.year, vencimiento.month, vencimiento.day);
  return [
    for (final d in const [1, 3])
      DateTime(dia.year, dia.month, dia.day + d, prefs.horaVencimientos),
  ];
}

/// Cuándo sale un aviso programado para [enviarEn] (regla 35): fuera del
/// silencio sale a su hora; en silencio, los no críticos y las críticas sin
/// permiso esperan a la hora final del silencio. Con `criticasEnSilencio` las
/// críticas salen a su hora.
DateTime salidaDeAviso(
  DateTime enviarEn,
  NivelAlerta nivel,
  PreferenciasAviso prefs,
) {
  if (!prefs.esSilencio(enviarEn.hour)) return enviarEn;
  if (nivel == NivelAlerta.critica && prefs.criticasEnSilencio) return enviarEn;
  final base =
      enviarEn.hour >= prefs.silencioDesde &&
          prefs.silencioDesde > prefs.silencioHasta
      ? DateTime(enviarEn.year, enviarEn.month, enviarEn.day + 1)
      : DateTime(enviarEn.year, enviarEn.month, enviarEn.day);
  return DateTime(base.year, base.month, base.day, prefs.silencioHasta);
}

/// Un aviso por entregar.
class AvisoPlan {
  final String clave;
  final TipoAlerta tipo;
  final DateTime cuando;

  const AvisoPlan(this.clave, this.tipo, this.cuando);
}

/// Resultado de aplicar preferencias y tope a los avisos de un día.
class PlanDelDia {
  /// Salen tal cual (críticas y no críticas dentro del tope).
  final List<AvisoPlan> individuales;

  /// Los que pasan del tope: se entregan como un solo aviso agrupado.
  final List<AvisoPlan> agrupados;

  /// Silenciados por tipo: solo viven en la bandeja y en Hoy.
  final List<AvisoPlan> soloBandeja;

  const PlanDelDia(this.individuales, this.agrupados, this.soloBandeja);
}

/// Aplica tipos silenciados y el tope diario a los avisos de un día
/// (reglas 36 y 37). Las críticas no tienen tope; una crítica silenciada igual
/// va a la bandeja (y a Hoy), no suena. El tope cuenta no críticos por orden
/// de hora.
PlanDelDia planearDia(List<AvisoPlan> avisos, PreferenciasAviso prefs) {
  final ordenados = [...avisos]..sort((a, b) => a.cuando.compareTo(b.cuando));
  final ind = <AvisoPlan>[];
  final agr = <AvisoPlan>[];
  final bandeja = <AvisoPlan>[];
  var noCriticos = 0;
  for (final a in ordenados) {
    if (prefs.tiposSilenciados.contains(a.tipo.clave) && !a.tipo.fija) {
      bandeja.add(a);
      continue;
    }
    if (a.tipo.esCritica) {
      ind.add(a);
    } else if (noCriticos < prefs.topeDiario) {
      noCriticos++;
      ind.add(a);
    } else {
      agr.add(a);
    }
  }
  return PlanDelDia(ind, agr, bandeja);
}

/// Pospone un aviso: 1 hora, o hasta mañana a la hora de los vencimientos.
DateTime posponer(
  DateTime ahora, {
  required bool hastaManana,
  int horaManana = 9,
}) => hastaManana
    ? DateTime(ahora.year, ahora.month, ahora.day + 1, horaManana)
    : ahora.add(const Duration(hours: 1));

/// Rol de quien recibe, para el cálculo de destinatarios (regla 41).
enum RolDestino { titular, miembro, albacea, suplente, cuentaMaestra, otro }

/// Tipo de libro para destinatarios.
enum LibroDestino { personal, compartido, representado }

/// `true` si [rol] debe recibir un aviso de un libro [libro]. [hayAlbaceaVigente]
/// solo importa en el libro de papá. La cuenta maestra y los demás roles
/// nunca reciben avisos de dinero.
bool recibeAvisoDeLibro({
  required LibroDestino libro,
  required RolDestino rol,
  bool hayAlbaceaVigente = true,
}) {
  switch (libro) {
    case LibroDestino.personal:
      return rol == RolDestino.titular;
    case LibroDestino.compartido:
      return rol == RolDestino.titular || rol == RolDestino.miembro;
    case LibroDestino.representado:
      return hayAlbaceaVigente
          ? rol == RolDestino.albacea
          : rol == RolDestino.suplente;
  }
}
