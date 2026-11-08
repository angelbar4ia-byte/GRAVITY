/// Casos de uso de Cuidados: revisan el permiso (espejo de la matriz de la
/// sección 5; el servidor decide de verdad) y arman lo que muestran las
/// pantallas. Nada de esto va a la IA ni a las bocinas (D3, D6).
library;

import '../datos/modelos.dart';
import '../datos/repositorio.dart';
import 'horario_turnos.dart';
import 'permisos_cuidados.dart';

/// Texto único para recordatorios en voz alta o en pantalla de bloqueo: sin
/// nombre de medicamento ni de persona (D6, spec §8.4).
const textoRecordatorioGenerico = 'Hay un recordatorio en Cuidados';

/// Una toma se identifica por medicamento y hora (en el servidor tiene su
/// propio id; la app no lo conoce hasta leerla).
String _claveToma(String medicamentoId, DateTime hora) =>
    '$medicamentoId|${hora.millisecondsSinceEpoch ~/ 60000}';

/// Paso de un gasto recién confirmado a Finanzas (lo arma el proveedor con el
/// repositorio de Finanzas). Puede lanzar si no hay permiso, libro o cuenta.
typedef PasarGastoAFinanzas = Future<void> Function(GastoCuidado confirmado);

/// Aviso sobrio cuando el gasto quedó confirmado en Cuidados pero Finanzas no
/// lo recibió (la confirmación del servidor no se revierte).
const avisoGastoSinFinanzas =
    'Gasto confirmado, pero no se pudo pasar a Finanzas. Revisa tu permiso '
    'o inténtalo de nuevo más tarde.';

class ServicioCuidados {
  ServicioCuidados(
    this._repo, {
    required this.permisos,
    required this.personaId,
    required this.nombre,
    required this.ahora,
    this.alConfirmarGasto,
  });

  /// Se llama una vez por gasto confirmado, después de que el servidor lo
  /// guarda como confirmado.
  final PasarGastoAFinanzas? alConfirmarGasto;

  final RepositorioCuidados _repo;
  final PermisosCuidados permisos;
  final String personaId;
  final String nombre;
  final DateTime Function() ahora;

  void _exigir(bool ok) {
    if (!ok) throw ErrorCuidados.sinPermiso;
  }

  // ---------------------------------------------------------------- Turnos

  Future<List<Turno>> turnosDeHoy() async {
    if (!permisos.veTurno) return const [];
    final h = soloFecha(ahora());
    return _repo.turnos(h, h.add(const Duration(days: 1)));
  }

  /// Mis turnos de hoy (no las visitas de otras personas).
  Future<List<Turno>> miTurnoHoy() async => [
    for (final t in await turnosDeHoy())
      if (t.personaId == personaId) t,
  ];

  /// Quién está de turno ahora (puede ser nadie).
  Future<Set<String>> deTurno() async =>
      deTurnoAhora(await turnosDeHoy(), ahora());

  Future<List<Turno>> turnosDeLaSemana() async {
    if (!permisos.veTurno) return const [];
    final l = lunesDe(ahora());
    return _repo.turnos(l, l.add(const Duration(days: 7)));
  }

  // --------------------------------------------------------- Entrega y avisos

  Future<Entrega?> ultimaEntrega() async {
    if (!permisos.veTurno) return null;
    final todas = await _repo.entregas();
    return todas.firstOrNull;
  }

  /// Quién sigue después de mí: la siguiente persona con turno que no soy yo
  /// (`cui_entregas.para_persona` es obligatoria y distinta de quien la deja).
  Future<String?> _quienSigue() async {
    final t = ahora();
    final turnos = await _repo.turnos(t, t.add(const Duration(days: 8)));
    for (final x in turnos) {
      if (x.tipo == TipoTurno.turno &&
          x.personaId != personaId &&
          x.fin.isAfter(t)) {
        return x.personaId;
      }
    }
    return null;
  }

  Future<void> dejarEntrega(String notas) async {
    _exigir(permisos.dejaEntrega);
    final t = notas.trim();
    if (t.isEmpty) {
      throw const ErrorCuidados('Escribe una nota para quien sigue.');
    }
    if (t.length > 500) {
      throw const ErrorCuidados('La nota puede tener hasta 500 letras.');
    }
    final para = await _quienSigue();
    if (para == null) {
      throw const ErrorCuidados(
        'No hay a quién dejarle la nota: faltan turnos por asignar.',
      );
    }
    await _repo.dejarEntrega(
      Entrega(
        id: idNuevoCuidados(),
        dePersonaId: personaId,
        deNombre: nombre,
        notas: t,
        creadaEn: ahora(),
        paraPersonaId: para,
      ),
    );
  }

  Future<List<CambioUrgente>> cambiosUrgentes() async =>
      permisos.veCambiosUrgentes ? _repo.cambiosUrgentes() : const [];

  /// El servidor guarda solo el texto (1 a 200 letras): aquí se arma con la
  /// acción, el medicamento y la nota.
  Future<void> crearCambioUrgente({
    required AccionCambio accion,
    required String nota,
    String? medicamentoId,
    String? medicamentoNombre,
  }) async {
    _exigir(permisos.creaCambioUrgente);
    final med = (medicamentoNombre ?? '').trim();
    if (medicamentoId == null && med.isEmpty) {
      throw const ErrorCuidados('Elige o escribe el medicamento.');
    }
    final n = nota.trim();
    final texto =
        '${accion.etiqueta}: ${med.isEmpty ? 'medicamento' : med}'
        '${n.isEmpty ? '' : '. $n'}';
    if (texto.length > 200) {
      throw const ErrorCuidados('El aviso puede tener hasta 200 letras.');
    }
    await _repo.crearCambioUrgente(
      CambioUrgente(
        id: idNuevoCuidados(),
        texto: texto,
        creadoPor: personaId,
        creadoEn: ahora(),
      ),
    );
  }

  /// "Enterada": quien está de turno confirma que vio el cambio.
  Future<void> atenderCambio(String id) async {
    _exigir(permisos.atiendeCambioUrgente);
    await _repo.atenderCambioUrgente(
      id,
      personaId: personaId,
      nombre: nombre,
      en: ahora(),
    );
  }

  // ---------------------------------------------------------- Medicamentos

  Future<List<Medicamento>> medicamentos() async =>
      permisos.veMedicamentos ? _repo.medicamentos() : const [];

  /// Dosis de [dia] (hoy por omisión), en orden de hora.
  Future<List<Dosis>> dosisDelDia([DateTime? dia]) async {
    if (!permisos.veMedicamentos) return const [];
    final d = soloFecha(dia ?? ahora());
    final meds = await _repo.medicamentos();
    final tomas = {
      for (final t in await _repo.tomas(d))
        _claveToma(t.medicamentoId, t.programada): t,
    };
    final salida = <Dosis>[];
    for (final m in meds.where((m) => m.activo)) {
      for (final h in m.horas) {
        final p = h.split(':');
        final hora = DateTime(
          d.year,
          d.month,
          d.day,
          int.parse(p[0]),
          int.parse(p[1]),
        );
        salida.add(
          Dosis(
            medicamento: m,
            hora: hora,
            toma: tomas[_claveToma(m.id, hora)],
          ),
        );
      }
    }
    return salida..sort((a, b) => a.hora.compareTo(b.hora));
  }

  /// La siguiente dosis pendiente (sin importar el nombre: la pantalla de
  /// inicio solo dice la hora).
  Future<Dosis?> siguienteDosis() async {
    final t = ahora();
    final dosis = await dosisDelDia();
    final pendientes = dosis.where((d) => d.estado == EstadoToma.pendiente);
    return pendientes.where((d) => !d.hora.isBefore(t)).firstOrNull ??
        pendientes.firstOrNull;
  }

  Future<void> marcarToma(
    Dosis dosis, {
    required bool dado,
    String? motivo,
  }) async {
    _exigir(permisos.marcaToma);
    await _repo.marcarToma(
      Toma(
        id: Toma.idDe(dosis.medicamento.id, dosis.hora),
        medicamentoId: dosis.medicamento.id,
        programada: dosis.hora,
        estado: dado ? EstadoToma.dado : EstadoToma.noDado,
        registradaPor: personaId,
        registradaPorNombre: nombre,
        registradaEn: ahora(),
        motivo: motivo,
      ),
    );
  }

  Future<void> guardarMedicamento(Medicamento m) async {
    _exigir(permisos.administra);
    await _repo.guardarMedicamento(m);
  }

  // ---------------------------------------------------------------- Comidas

  Future<Map<TiempoComidaPapa, ComidaRegistro>> comidasDeHoy() async {
    if (!permisos.veComidas) return const {};
    // Solo agregar: la corrección es una fila nueva; vale la más reciente.
    final salida = <TiempoComidaPapa, ComidaRegistro>{};
    for (final c in await _repo.comidas(ahora())) {
      final previa = salida[c.tiempo];
      if (previa == null || !c.registradaEn.isBefore(previa.registradaEn)) {
        salida[c.tiempo] = c;
      }
    }
    return salida;
  }

  Future<void> registrarComida(TiempoComidaPapa t, ResultadoComida r) async {
    _exigir(permisos.registraComida);
    final hoy = soloFecha(ahora());
    await _repo.registrarComida(
      ComidaRegistro(
        id: idNuevoCuidados(),
        fecha: hoy,
        tiempo: t,
        resultado: r,
        registradaPor: personaId,
        registradaPorNombre: nombre,
        registradaEn: ahora(),
      ),
    );
  }

  // --------------------------------------------------------------- Bitácora

  Future<List<EntradaBitacora>> bitacora() async {
    if (!permisos.veBitacora) return const [];
    final todas = await _repo.bitacora();
    return permisos.soloLoPropioEnBitacora
        ? [
            for (final e in todas)
              if (e.autorId == personaId) e,
          ]
        : todas;
  }

  Future<void> agregarNota(String texto) async {
    _exigir(permisos.escribeBitacora);
    final t = texto.trim();
    if (t.isEmpty) throw const ErrorCuidados('Escribe qué pasó.');
    if (t.length > 500) {
      throw const ErrorCuidados('La nota puede tener hasta 500 letras.');
    }
    await _repo.agregarBitacora(
      EntradaBitacora(
        id: idNuevoCuidados(),
        tipo: TipoBitacora.nota,
        texto: t,
        autorId: personaId,
        autorNombre: nombre,
        creadaEn: ahora(),
      ),
    );
  }

  /// Deja una instrucción para la cuidadora principal (`cui_dejar_instruccion`).
  /// El texto no se copia a ningún registro local (D3): solo viaja al servidor.
  Future<void> dejarInstruccion(String texto) async {
    _exigir(permisos.dejaInstruccion);
    final t = texto.trim();
    if (t.isEmpty) throw const ErrorCuidados('Escribe la instrucción.');
    if (t.length > 500) {
      throw const ErrorCuidados('La instrucción puede tener hasta 500 letras.');
    }
    await _repo.dejarInstruccion(t, autorNombre: nombre, en: ahora());
  }

  /// Solo la cuidadora: las instrucciones que le llegan más sus propias notas,
  /// de la más reciente a la más antigua. Solo lectura.
  Future<List<EntradaBitacora>> instruccionesRecibidas() async {
    if (!permisos.veInstruccionesRecibidas) return const [];
    return [
      for (final e in await _repo.bitacora())
        if (e.tipo == TipoBitacora.instruccion || e.autorId == personaId) e,
    ];
  }

  Future<List<EntradaBitacora>> citas() async {
    _exigir(permisos.administra);
    return [
      for (final e in await _repo.bitacora())
        if (e.tipo == TipoBitacora.cita) e,
    ]..sort(
      (a, b) => (a.programadaEn ?? a.creadaEn).compareTo(
        b.programadaEn ?? b.creadaEn,
      ),
    );
  }

  Future<void> agregarCita(String texto, DateTime cuando) async {
    _exigir(permisos.administra);
    if (texto.trim().isEmpty) {
      throw const ErrorCuidados('Escribe de qué es la cita.');
    }
    await _repo.agregarBitacora(
      EntradaBitacora(
        id: idNuevoCuidados(),
        tipo: TipoBitacora.cita,
        texto: texto.trim(),
        autorId: personaId,
        autorNombre: nombre,
        creadaEn: ahora(),
        programadaEn: cuando,
      ),
    );
  }

  // ----------------------------------------------------------------- Gastos

  Future<List<GastoCuidado>> gastos() async {
    if (!permisos.veGastos) return const [];
    final todos = await _repo.gastos();
    // Salvo el dueño, cada quien ve solo los que registró.
    return permisos.confirmaGasto
        ? todos
        : [
            for (final g in todos)
              if (g.registradoPor == personaId) g,
          ];
  }

  /// Registra un gasto: queda **pendiente de confirmación del dueño**; al
  /// confirmarse, Finanzas lo recibe (lo hace el agente finanzas).
  Future<void> registrarGasto({
    required String concepto,
    required int centavos,
    AmbitoGasto ambito = AmbitoGasto.cuidado,
  }) async {
    _exigir(permisos.registraGasto);
    _exigir(ambito == AmbitoGasto.cuidado || permisos.registraGastoCasa);
    if (concepto.trim().isEmpty) {
      throw const ErrorCuidados('Escribe en qué se gastó.');
    }
    if (concepto.trim().length > 120) {
      throw const ErrorCuidados('El concepto puede tener hasta 120 letras.');
    }
    if (centavos <= 0) {
      throw const ErrorCuidados('El monto debe ser mayor que cero.');
    }
    await _repo.registrarGasto(
      GastoCuidado(
        id: idNuevoCuidados(),
        concepto: concepto.trim(),
        centavos: centavos,
        fecha: soloFecha(ahora()),
        registradoPor: personaId,
        registradoNombre: nombre,
        ambito: ambito,
        registradoEn: ahora(),
      ),
    );
  }

  /// Confirma o rechaza un gasto. Al confirmar, y ya guardado el estado en el
  /// servidor, lo pasa a Finanzas. Devuelve un aviso si Finanzas no lo recibió
  /// (la confirmación no se revierte); `null` si todo salió bien.
  Future<String?> resolverGasto(String id, {required bool confirmar}) async {
    _exigir(permisos.confirmaGasto);
    GastoCuidado? gasto;
    if (confirmar && alConfirmarGasto != null) {
      for (final g in await _repo.gastos()) {
        if (g.id == id) gasto = g;
      }
    }
    await _repo.resolverGasto(
      id,
      confirmar ? EstadoGasto.confirmado : EstadoGasto.rechazado,
    );
    if (gasto == null) return null;
    try {
      await alConfirmarGasto!(gasto.conEstado(EstadoGasto.confirmado));
    } catch (_) {
      return avisoGastoSinFinanzas;
    }
    return null;
  }

  // ---------------------------------------------------------------- Resumen

  /// Resumen del mes: totales de gastos confirmados. El servidor ya deja
  /// fuera lo de la pareja y lo del dueño (`cui_resumen_mensual`).
  Future<ResumenMensual?> resumen(DateTime mes) async {
    if (!permisos.resumenDisponible) return null;
    return _repo.resumenMensual(mes);
  }

  /// Conteos del día de Papá, sin nombres (`cui_resumen_papa`); también para
  /// la pareja sin consentimiento.
  Future<ResumenPapa?> resumenDelDia([DateTime? dia]) async {
    if (!permisos.veResumenPapa) return null;
    return _repo.resumenPapa(dia ?? ahora());
  }

  // ----------------------------------------------- Consentimientos y permisos

  /// La pareja concede o retira su consentimiento (abre medicamentos, tomas y
  /// comidas en solo lectura).
  Future<void> cambiarMiConsentimiento(bool concedido) async {
    _exigir(permisos.daConsentimiento);
    await _repo.cambiarConsentimiento(personaId, concedido);
  }

  /// Solo el albacea (D19): el servidor lo exige.
  Future<void> autorizarResumen(String personaHermanaId, bool vigente) async {
    _exigir(permisos.autorizaResumen);
    await _repo.autorizarResumen(personaHermanaId, vigente);
  }

  /// Estado de consentimiento de la pareja y autorización de la hermana.
  Future<EstadoConsentimientos?> estadoConsentimientos() async {
    if (!permisos.veConsentimientos) return null;
    return _repo.estadoConsentimientos();
  }

  /// Solo el dueño: crea las tomas pendientes de los próximos [dias].
  Future<int> generarTomas({int dias = 1}) async {
    _exigir(permisos.administra);
    return _repo.generarTomas(soloFecha(ahora()), dias: dias);
  }
}
