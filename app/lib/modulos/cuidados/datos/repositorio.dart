/// Repositorio de Cuidados: interfaz y versión en memoria (pruebas y
/// demostración). La versión con Supabase está en `repositorio_supabase.dart`.
///
/// La versión en memoria **sigue las mismas reglas que el servidor** (RLS y
/// RPC de las migraciones `20261114` a `20261116`): quién lee y escribe cada
/// parte (`cui_puede`), lo que pone el servidor (la persona que registra, el
/// estado del gasto, las horas), solo agregar en comidas, bitácora y
/// entregas, tomas que solo cambian marcándolas (de turno a la hora), cambios
/// urgentes solo del dueño, gastos que solo confirma el dueño y un resumen
/// mensual de totales sin lo de la pareja ni del dueño. Aun así, la interfaz
/// vuelve a revisar (defensa doble).
library;

import '../../../nucleo/contratos/roles.dart';
import '../casos_uso/horario_turnos.dart';
import '../casos_uso/permisos_cuidados.dart';
import 'modelos.dart';

abstract interface class RepositorioCuidados {
  /// `cui_perfil(hogar)` más las autorizaciones propias.
  Future<PerfilCuidados> perfil();

  /// `cui_puede(hogar, objeto, accion)`.
  Future<bool> puede(String objeto, String accion);

  Future<List<Turno>> turnos(DateTime desde, DateTime hasta);
  Future<void> guardarTurno(Turno t);

  Future<List<Medicamento>> medicamentos();
  Future<void> guardarMedicamento(Medicamento m);

  /// Tomas del día (las crea `cui_generar_tomas`; incluye las pendientes).
  Future<List<Toma>> tomas(DateTime dia);

  /// `cui_marcar_toma(toma, estado)`: [t] dice cuál toma (medicamento y hora
  /// programada) y el estado; quién y cuándo lo pone el servidor.
  Future<void> marcarToma(Toma t);

  /// `cui_generar_tomas(hogar, desde, dias)`: solo el dueño. Devuelve cuántas
  /// creó.
  Future<int> generarTomas(DateTime desde, {int dias = 1});

  Future<List<ComidaRegistro>> comidas(DateTime dia);
  Future<void> registrarComida(ComidaRegistro c);

  Future<List<EntradaBitacora>> bitacora();
  Future<void> agregarBitacora(EntradaBitacora e);

  Future<List<Entrega>> entregas();
  Future<void> dejarEntrega(Entrega e);

  Future<List<CambioUrgente>> cambiosUrgentes();

  /// `cui_crear_cambio_urgente(hogar, texto, id)`: solo el dueño; el servidor
  /// avisa a quien está de turno.
  Future<void> crearCambioUrgente(CambioUrgente c);

  /// `cui_atender_cambio_urgente(id)`.
  Future<void> atenderCambioUrgente(
    String id, {
    required String personaId,
    required String nombre,
    required DateTime en,
  });

  Future<List<GastoCuidado>> gastos();
  Future<void> registrarGasto(GastoCuidado g);

  /// `cui_confirmar_gasto(gasto, confirmar)`: solo el dueño.
  Future<void> resolverGasto(String id, EstadoGasto estado);

  /// `cui_cambiar_consentimiento(hogar, persona, concedido)`.
  Future<void> cambiarConsentimiento(String personaId, bool concedido);

  /// `cui_autorizar_resumen(hogar, persona, vigente)`: solo el albacea.
  Future<void> autorizarResumen(String personaId, bool vigente);

  /// `null` si no hay resumen (sin autorización o sin permiso).
  Future<ResumenMensual?> resumenMensual(DateTime mes);

  /// `cui_resumen_papa(hogar, dia)`: conteos, sin nombres.
  Future<ResumenPapa?> resumenPapa(DateTime dia);
}

/// Lo guardado "en el servidor" de la demostración; varios repositorios (uno
/// por persona) lo comparten.
class DatosCuidadosMemoria {
  final List<Turno> turnos = [];
  final List<Medicamento> medicamentos = [];

  /// Tomas generadas, por id (`Toma.idDe`). Las pendientes también.
  final Map<String, Toma> tomas = {};
  final Map<String, ComidaRegistro> comidas = {};
  final List<EntradaBitacora> bitacora = [];
  final List<Entrega> entregas = [];
  final List<CambioUrgente> cambios = [];
  final List<GastoCuidado> gastos = [];

  /// Quienes son dueño o pareja: sus gastos no entran al resumen mensual.
  final Set<String> duenoOPareja = {};

  /// `cui_consentimientos` (persona → concedido).
  final Map<String, bool> consentimientos = {};

  /// `cui_autorizacion_resumen` (persona → vigente).
  final Map<String, bool> autorizaciones = {};

  /// La persona de Papá (la que el albacea representa).
  String personaPapaId = 'persona-papa';
}

/// Crea las tomas pendientes de los medicamentos activos (como
/// `cui_generar_tomas`): idempotente. Devuelve cuántas creó.
int generarTomasMemoria(
  DatosCuidadosMemoria datos,
  DateTime desde, {
  int dias = 1,
}) {
  var n = 0;
  final d0 = soloFecha(desde);
  for (var i = 0; i < dias; i++) {
    final d = DateTime(d0.year, d0.month, d0.day + i);
    for (final m in datos.medicamentos.where((m) => m.activo)) {
      for (final h in m.horas) {
        final p = h.split(':');
        final hora = DateTime(
          d.year,
          d.month,
          d.day,
          int.parse(p[0]),
          int.parse(p[1]),
        );
        final id = Toma.idDe(m.id, hora);
        if (datos.tomas.containsKey(id)) continue;
        datos.tomas[id] = Toma(
          id: id,
          medicamentoId: m.id,
          programada: hora,
          estado: EstadoToma.pendiente,
          registradaPor: '',
          registradaPorNombre: '',
          registradaEn: hora,
        );
        n++;
      }
    }
  }
  return n;
}

class RepositorioCuidadosEnMemoria implements RepositorioCuidados {
  RepositorioCuidadosEnMemoria({
    DatosCuidadosMemoria? datos,
    this.personaId = 'persona-dueno',
    this.rol = Rol.dueno,
    this.perfilActual = const PerfilCuidados(),
    this.esAlbacea = false,
  }) : datos = datos ?? DatosCuidadosMemoria();

  final DatosCuidadosMemoria datos;
  final String personaId;
  final Rol rol;
  final PerfilCuidados perfilActual;

  /// Es el albacea vigente de Papá (D19).
  final bool esAlbacea;

  /// Tope del servidor: registros propios en 24 horas (54000).
  static const topeDiario = 300;

  TipoPerfil? get _perfil => perfilActual.efectivo(rol);
  bool get _dueno => _perfil == TipoPerfil.dueno;
  bool get _cuidadora => _perfil == TipoPerfil.cuidadora;
  bool get _pareja =>
      _perfil == TipoPerfil.pareja || _perfil == TipoPerfil.parejaConsentida;

  bool _puede(String objeto, String accion) =>
      cuiPuede(_perfil, objeto, accion);

  void _exigir(bool ok) {
    if (!ok) throw ErrorCuidados.sinPermiso;
  }

  void _tope(Iterable<DateTime> propios, DateTime ahora) {
    final desde = ahora.subtract(const Duration(hours: 24));
    if (propios.where((t) => t.isAfter(desde)).length >= topeDiario) {
      throw const ErrorCuidados('Se llegó al tope de registros de hoy.');
    }
  }

  @override
  Future<PerfilCuidados> perfil() async {
    final base = perfilActual;
    final cons = datos.consentimientos[personaId];
    final aut = datos.autorizaciones[personaId];
    if (cons == null && aut == null) return base;
    return PerfilCuidados(
      tipo: base.tipo,
      sinAcceso: base.sinAcceso,
      esFamiliar: base.esFamiliar,
      consentimiento: cons ?? base.consentimiento,
      resumenAutorizado: aut ?? base.resumenAutorizado,
    );
  }

  @override
  Future<bool> puede(String objeto, String accion) async =>
      _puede(objeto, accion);

  @override
  Future<List<Turno>> turnos(DateTime desde, DateTime hasta) async {
    if (!_puede('turnos', 'leer')) return const [];
    return [
      for (final t in datos.turnos)
        if (t.inicio.isBefore(hasta) && t.fin.isAfter(desde)) t,
    ]..sort((a, b) => a.inicio.compareTo(b.inicio));
  }

  @override
  Future<void> guardarTurno(Turno t) async {
    _exigir(_puede('turnos', 'escribir'));
    datos.turnos
      ..removeWhere((x) => x.id == t.id)
      ..add(t);
  }

  @override
  Future<List<Medicamento>> medicamentos() async =>
      _puede('medicamentos', 'leer') ? [...datos.medicamentos] : const [];

  @override
  Future<void> guardarMedicamento(Medicamento m) async {
    _exigir(_puede('medicamentos', 'escribir'));
    final i = datos.medicamentos.indexWhere((x) => x.id == m.id);
    i < 0 ? datos.medicamentos.add(m) : datos.medicamentos[i] = m;
  }

  @override
  Future<List<Toma>> tomas(DateTime dia) async {
    if (!_puede('tomas', 'leer')) return const [];
    final d = soloFecha(dia);
    return [
      for (final t in datos.tomas.values)
        if (soloFecha(t.programada) == d) t,
    ];
  }

  /// ¿Está esta persona de turno (cuidadora) en [momento]? Como
  /// `cui_quien_en_turno`.
  bool _deTurno(String persona, DateTime momento) => datos.turnos.any(
    (t) =>
        t.personaId == persona && t.tipo == TipoTurno.turno && t.cubre(momento),
  );

  @override
  Future<void> marcarToma(Toma t) async {
    // Dueño siempre; la cuidadora solo si estaba de turno a la hora de la
    // toma; la hermana y la pareja no. Mismo error exista o no la toma.
    final id = Toma.idDe(t.medicamentoId, t.programada);
    final fila = datos.tomas[id];
    _exigir(
      fila != null &&
          (_dueno || (_cuidadora && _deTurno(personaId, t.programada))),
    );
    if (t.estado == EstadoToma.pendiente) {
      throw const ErrorCuidados('Marca la toma como dada o no dada.');
    }
    datos.tomas[id] = Toma(
      id: id,
      medicamentoId: fila!.medicamentoId,
      programada: fila.programada,
      estado: t.estado,
      registradaPor: personaId,
      registradaPorNombre: t.registradaPorNombre,
      registradaEn: t.registradaEn,
      motivo: t.motivo,
    );
  }

  @override
  Future<int> generarTomas(DateTime desde, {int dias = 1}) async {
    _exigir(_dueno);
    if (dias < 1 || dias > 14) {
      throw const ErrorCuidados('Genera de 1 a 14 días a la vez.');
    }
    return generarTomasMemoria(datos, desde, dias: dias);
  }

  @override
  Future<List<ComidaRegistro>> comidas(DateTime dia) async {
    if (!_puede('comidas', 'leer')) return const [];
    final d = soloFecha(dia);
    return [
      for (final c in datos.comidas.values)
        if (soloFecha(c.fecha) == d) c,
    ];
  }

  @override
  Future<void> registrarComida(ComidaRegistro c) async {
    // El dueño siempre; la cuidadora solo un día en que tiene turno.
    _exigir(
      _puede('comidas', 'escribir') &&
          (_dueno ||
              datos.turnos.any(
                (t) =>
                    t.personaId == personaId &&
                    t.tipo == TipoTurno.turno &&
                    t.inicio.weekday == c.fecha.weekday,
              )),
    );
    _tope([
      for (final x in datos.comidas.values)
        if (x.registradaPor == personaId) x.registradaEn,
    ], c.registradaEn);
    // Solo agregar: la corrección es una fila nueva (vale la más reciente).
    // El servidor pone quién y cuándo.
    datos.comidas[c.id] = ComidaRegistro(
      id: c.id,
      fecha: soloFecha(c.fecha),
      tiempo: c.tiempo,
      resultado: c.resultado,
      registradaPor: personaId,
      registradaPorNombre: c.registradaPorNombre,
      registradaEn: c.registradaEn,
    );
  }

  @override
  Future<List<EntradaBitacora>> bitacora() async {
    // El servidor deja leer toda la bitácora a dueño, cuidadora y hermana;
    // que la cuidadora y la hermana vean solo la suya es decisión pendiente
    // del dueño y la aplica el servicio.
    if (!_puede('bitacora', 'leer')) return const [];
    return [...datos.bitacora]
      ..sort((a, b) => b.creadaEn.compareTo(a.creadaEn));
  }

  @override
  Future<void> agregarBitacora(EntradaBitacora e) async {
    _exigir(_puede('bitacora', 'escribir'));
    _tope([
      for (final x in datos.bitacora)
        if (x.autorId == personaId) x.creadaEn,
    ], e.creadaEn);
    datos.bitacora.add(
      EntradaBitacora(
        id: e.id,
        tipo: e.tipo,
        texto: e.texto,
        autorId: personaId,
        autorNombre: e.autorNombre,
        creadaEn: e.creadaEn,
        programadaEn: e.programadaEn,
      ),
    );
  }

  @override
  Future<List<Entrega>> entregas() async {
    if (!_puede('entregas', 'leer')) return const [];
    return [
      for (final e in datos.entregas)
        if (_dueno ||
            e.dePersonaId == personaId ||
            e.paraPersonaId == personaId)
          e,
    ]..sort((a, b) => b.creadaEn.compareTo(a.creadaEn));
  }

  @override
  Future<void> dejarEntrega(Entrega e) async {
    _exigir(_puede('entregas', 'escribir'));
    final para = e.paraPersonaId;
    // Para alguien del círculo de cuidado (con turnos) y distinto de quien
    // la deja.
    _exigir(
      para != null &&
          para != personaId &&
          datos.turnos.any((t) => t.personaId == para),
    );
    _tope([
      for (final x in datos.entregas)
        if (x.dePersonaId == personaId) x.creadaEn,
    ], e.creadaEn);
    datos.entregas.add(
      Entrega(
        id: e.id,
        dePersonaId: personaId,
        deNombre: e.deNombre,
        notas: e.notas,
        creadaEn: e.creadaEn,
        paraPersonaId: para,
      ),
    );
  }

  @override
  Future<List<CambioUrgente>> cambiosUrgentes() async {
    if (!_puede('cambios', 'leer')) return const [];
    return [
      for (final c in datos.cambios)
        if (_dueno ||
            c.creadoPor == personaId ||
            c.paraPersonaId == personaId ||
            c.paraPersonaId == null)
          c,
    ]..sort((a, b) => b.creadoEn.compareTo(a.creadoEn));
  }

  @override
  Future<void> crearCambioUrgente(CambioUrgente c) async {
    _exigir(_dueno);
    if (c.texto.trim().isEmpty || c.texto.trim().length > 200) {
      throw const ErrorCuidados('El cambio urgente lleva de 1 a 200 letras.');
    }
    if (datos.cambios.any((x) => x.id == c.id)) return; // idempotente por id
    // Avisa a quien está de turno (que no sea el dueño); sin nadie, nulo.
    String? para;
    for (final t in datos.turnos) {
      if (t.tipo == TipoTurno.turno &&
          t.cubre(c.creadoEn) &&
          t.personaId != personaId) {
        para = t.personaId;
        break;
      }
    }
    datos.cambios.add(
      CambioUrgente(
        id: c.id,
        texto: c.texto.trim(),
        creadoPor: personaId,
        creadoEn: c.creadoEn,
        paraPersonaId: para,
      ),
    );
  }

  @override
  Future<void> atenderCambioUrgente(
    String id, {
    required String personaId,
    required String nombre,
    required DateTime en,
  }) async {
    final i = datos.cambios.indexWhere((c) => c.id == id);
    final c = i < 0 ? null : datos.cambios[i];
    _exigir(
      c != null &&
          _perfil != null &&
          !_pareja &&
          (_dueno ||
              c.paraPersonaId == this.personaId ||
              (c.paraPersonaId == null &&
                  (_perfil == TipoPerfil.cuidadora ||
                      _perfil == TipoPerfil.hermana))),
    );
    if (!c!.atendido) datos.cambios[i] = c.atender(personaId, nombre, en);
  }

  @override
  Future<List<GastoCuidado>> gastos() async {
    if (!_puede('gastos', 'leer')) return const [];
    return [
      for (final g in datos.gastos)
        if (_dueno || g.registradoPor == personaId) g,
    ]..sort((a, b) => b.fecha.compareTo(a.fecha));
  }

  @override
  Future<void> registrarGasto(GastoCuidado g) async {
    _exigir(_puede('gastos', 'escribir'));
    if (g.centavos <= 0) {
      throw const ErrorCuidados('El monto debe ser mayor que cero.');
    }
    _tope([
      for (final x in datos.gastos)
        if (x.registradoPor == personaId) x.registradoEn ?? x.fecha,
    ], g.registradoEn ?? g.fecha);
    // Siempre entra pendiente de confirmación del dueño, a nombre de quien lo
    // registra (el servidor pone persona y estado).
    if (_dueno || _pareja) datos.duenoOPareja.add(personaId);
    datos.gastos.add(
      GastoCuidado(
        id: g.id,
        concepto: g.concepto,
        centavos: g.centavos,
        fecha: g.fecha,
        registradoPor: personaId,
        registradoNombre: g.registradoNombre,
        ambito: g.ambito,
        registradoEn: g.registradoEn,
      ),
    );
  }

  @override
  Future<void> resolverGasto(String id, EstadoGasto estado) async {
    _exigir(_dueno);
    if (estado == EstadoGasto.pendiente) {
      throw const ErrorCuidados('Indica si se confirma o se rechaza.');
    }
    final i = datos.gastos.indexWhere((g) => g.id == id);
    if (i < 0) throw ErrorCuidados.sinPermiso;
    if (datos.gastos[i].estado != EstadoGasto.pendiente) {
      throw const ErrorCuidados('El gasto ya fue resuelto.');
    }
    datos.gastos[i] = datos.gastos[i].conEstado(estado);
  }

  @override
  Future<void> cambiarConsentimiento(String persona, bool concedido) async {
    // Lo cambia su titular; el de Papá, el albacea.
    _exigir(
      _perfil != null &&
          (persona == personaId ||
              (persona == datos.personaPapaId && esAlbacea)),
    );
    datos.consentimientos[persona] = concedido;
  }

  @override
  Future<void> autorizarResumen(String persona, bool vigente) async {
    _exigir(esAlbacea);
    datos.autorizaciones[persona] = vigente;
  }

  @override
  Future<ResumenMensual?> resumenMensual(DateTime mes) async {
    final m = DateTime(mes.year, mes.month);
    final autorizada =
        _perfil == TipoPerfil.hermana &&
        (datos.autorizaciones[personaId] ?? perfilActual.resumenAutorizado);
    if (!_dueno && !autorizada) return null;
    var cuidado = 0, casa = 0, n = 0;
    for (final g in datos.gastos) {
      if (g.estado != EstadoGasto.confirmado ||
          g.fecha.year != m.year ||
          g.fecha.month != m.month ||
          datos.duenoOPareja.contains(g.registradoPor)) {
        continue;
      }
      n++;
      g.ambito == AmbitoGasto.casa ? casa += g.centavos : cuidado += g.centavos;
    }
    return ResumenMensual(
      mes: m,
      gastosCuidadoCentavos: cuidado,
      gastosCasaCentavos: casa,
      nGastos: n,
    );
  }

  @override
  Future<ResumenPapa?> resumenPapa(DateTime dia) async {
    if (_perfil == null) return null;
    final d = soloFecha(dia);
    final tomas = [
      for (final t in datos.tomas.values)
        if (soloFecha(t.programada) == d) t,
    ];
    // Una comida por tiempo: vale la más reciente.
    final porTiempo = <TiempoComidaPapa, ComidaRegistro>{};
    for (final c in datos.comidas.values) {
      if (soloFecha(c.fecha) != d) continue;
      final previa = porTiempo[c.tiempo];
      if (previa == null || !c.registradaEn.isBefore(previa.registradaEn)) {
        porTiempo[c.tiempo] = c;
      }
    }
    int cuenta(EstadoToma e) => tomas.where((t) => t.estado == e).length;
    return ResumenPapa(
      dia: d,
      tomasTotal: tomas.length,
      tomasDadas: cuenta(EstadoToma.dado),
      tomasNoDadas: cuenta(EstadoToma.noDado),
      tomasPendientes: cuenta(EstadoToma.pendiente),
      comidasRegistradas: porTiempo.length,
      comidasConRechazo: porTiempo.values
          .where((c) => c.resultado == ResultadoComida.rechazo)
          .length,
    );
  }
}

/// Datos inventados para la demostración. Nada real (el repositorio es
/// público): nombres y cifras de ejemplo.
DatosCuidadosMemoria datosDeEjemploCuidados(
  DateTime ahora, {
  PersonasTurno personas = personasDemo,
}) {
  final d = DatosCuidadosMemoria();
  d.turnos.addAll(turnosDeLaSemana(lunesDe(ahora), personas));
  d.medicamentos.addAll(const [
    Medicamento(
      id: 'med-1',
      nombre: 'Medicamento A',
      dosis: '1 tableta',
      horas: ['08:00', '20:00'],
    ),
    Medicamento(
      id: 'med-2',
      nombre: 'Medicamento B',
      dosis: '1/2 tableta',
      horas: ['14:00'],
    ),
  ]);
  // El servidor genera las tomas pendientes de la semana (cron, D4).
  generarTomasMemoria(d, lunesDe(ahora), dias: 7);

  // Gastos confirmados del mes de ejemplo, de otras personas (no de quien
  // prueba la app). Los del dueño y la pareja no entran al resumen mensual.
  final dia = DateTime(ahora.year, ahora.month, 1);
  d.duenoOPareja
    ..add(personas.duenoId)
    ..add('persona-pareja');
  void gasto(
    String id,
    String concepto,
    int centavos,
    String quien,
    AmbitoGasto ambito,
  ) => d.gastos.add(
    GastoCuidado(
      id: id,
      concepto: concepto,
      centavos: centavos,
      fecha: dia,
      registradoPor: quien,
      registradoNombre: '',
      estado: EstadoGasto.confirmado,
      ambito: ambito,
    ),
  );
  gasto(
    'g-1',
    'Pago de la cuidadora',
    1200000,
    'persona-demo-1',
    AmbitoGasto.cuidado,
  );
  gasto('g-2', 'Pañales y aseo', 180000, 'persona-demo-1', AmbitoGasto.cuidado);
  gasto(
    'g-3',
    'Servicios de la casa',
    350000,
    'persona-demo-2',
    AmbitoGasto.casa,
  );
  gasto(
    'g-4',
    'Gasto de la pareja',
    90000,
    'persona-pareja',
    AmbitoGasto.cuidado,
  );
  gasto('g-5', 'Gasto del dueño', 75000, personas.duenoId, AmbitoGasto.cuidado);
  return d;
}

const personasDemo = PersonasTurno(
  cuidadoraId: 'persona-cuidadora',
  cuidadoraNombre: 'Cuidadora',
  hermanaId: 'persona-hermana',
  hermanaNombre: 'Hermana',
  duenoId: 'persona-dueno',
  duenoNombre: 'Dueño',
);
