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

class ServicioCuidados {
  ServicioCuidados(
    this._repo, {
    required this.permisos,
    required this.personaId,
    required this.nombre,
    required this.ahora,
  });

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

  Future<void> dejarEntrega(String notas) async {
    _exigir(permisos.dejaEntrega);
    final t = notas.trim();
    if (t.isEmpty) {
      throw const ErrorCuidados('Escribe una nota para quien sigue.');
    }
    await _repo.dejarEntrega(
      Entrega(
        id: idNuevoCuidados(),
        dePersonaId: personaId,
        deNombre: nombre,
        notas: t,
        creadaEn: ahora(),
      ),
    );
  }

  Future<List<CambioUrgente>> cambiosUrgentes() async =>
      permisos.veCambiosUrgentes ? _repo.cambiosUrgentes() : const [];

  Future<void> crearCambioUrgente({
    required AccionCambio accion,
    required String nota,
    String? medicamentoId,
    String? medicamentoNombre,
  }) async {
    _exigir(permisos.creaCambioUrgente);
    if (medicamentoId == null && (medicamentoNombre ?? '').trim().isEmpty) {
      throw const ErrorCuidados('Elige o escribe el medicamento.');
    }
    await _repo.crearCambioUrgente(
      CambioUrgente(
        id: idNuevoCuidados(),
        accion: accion,
        nota: nota.trim(),
        creadoPor: personaId,
        creadoEn: ahora(),
        medicamentoId: medicamentoId,
        medicamentoNombre: medicamentoNombre?.trim(),
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
    final tomas = {for (final t in await _repo.tomas(d)) t.id: t};
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
          Dosis(medicamento: m, hora: hora, toma: tomas[Toma.idDe(m.id, hora)]),
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
    await _repo.registrarToma(
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
    return {for (final c in await _repo.comidas(ahora())) c.tiempo: c};
  }

  Future<void> registrarComida(TiempoComidaPapa t, ResultadoComida r) async {
    _exigir(permisos.registraComida);
    final hoy = soloFecha(ahora());
    await _repo.registrarComida(
      ComidaRegistro(
        id: ComidaRegistro.idDe(hoy, t),
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
  }) async {
    _exigir(permisos.registraGasto);
    if (concepto.trim().isEmpty) {
      throw const ErrorCuidados('Escribe en qué se gastó.');
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
      ),
    );
  }

  Future<void> resolverGasto(String id, {required bool confirmar}) async {
    _exigir(permisos.confirmaGasto);
    await _repo.resolverGasto(
      id,
      confirmar ? EstadoGasto.confirmado : EstadoGasto.rechazado,
    );
  }

  // ---------------------------------------------------------------- Resumen

  /// Resumen del mes. Para la hermana, sin lo de la pareja ni del dueño.
  Future<ResumenMensual?> resumen(DateTime mes) async {
    if (!permisos.resumenDisponible) return null;
    final r = await _repo.resumenMensual(mes);
    if (r == null) return null;
    return permisos.resumenSinMontosDelDueno ? r.paraFamiliar() : r;
  }
}
