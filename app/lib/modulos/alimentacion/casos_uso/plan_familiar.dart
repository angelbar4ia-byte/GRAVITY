/// Plan familiar por votación (D28; Fase 7, decisión 5 del dueño).
///
/// Alguien propone un menú; otra persona propone el suyo; se vota **un día**.
/// Cada quien puede **cambiar su voto** mientras la votación esté abierta. Un
/// empate al cierre lo resuelve el servidor por volado; aquí solo se muestra.
/// Lógica pura: la pantalla y el repositorio solo la usan.
library;

import '../../../nucleo/contratos/roles.dart';
import '../datos/repositorio.dart';
import '../datos/votacion.dart';

export '../datos/votacion.dart';

/// Dueño, pareja y familiar proponen y votan (la cuenta maestra solo ve).
bool puedeParticiparPlan(Rol rol, {bool esMaestra = false}) =>
    !esMaestra &&
    (rol == Rol.dueno || rol == Rol.coadministrador || rol == Rol.familiar);

/// Ven el plan: los que participan, la maestra y Casa. La cuidadora no.
bool puedeVerPlan(Rol rol, {bool esMaestra = false}) =>
    esMaestra || rol != Rol.cuidador;

DateTime _soloDia(DateTime d) => DateTime(d.year, d.month, d.day);

class ServicioPlanFamiliar {
  ServicioPlanFamiliar(
    this._repo, {
    required this.rol,
    required this.personaId,
    required this.personaNombre,
    required this.ahora,
    this.esMaestra = false,
  });
  final RepositorioAlimentacion _repo;
  final Rol rol;
  final String personaId;
  final String personaNombre;
  final bool esMaestra;
  final DateTime Function() ahora;

  bool get puedeVer => puedeVerPlan(rol, esMaestra: esMaestra);
  bool get puedeParticipar => puedeParticiparPlan(rol, esMaestra: esMaestra);

  void _exigirVer() {
    if (!puedeVer) throw const ErrorVotacion('Tu rol no ve el plan familiar.');
  }

  void _exigirParticipar() {
    if (!puedeParticipar) {
      throw const ErrorVotacion('Tu rol no propone ni vota en el plan familiar.');
    }
  }

  /// Nombres de platillo que esta persona puede ver en [vot]. Dueño, pareja y
  /// familiar ven los de todas las propuestas; la cuenta Casa **solo** los de
  /// la comida familiar ganadora (plan aprobado). Nunca el catálogo completo.
  Future<Map<String, String>> nombresDePlatillos(VotacionPlan? vot) async {
    _exigirVer();
    if (vot == null) return const {};
    final ids = rol == Rol.casa && !esMaestra
        ? <String>{...?vot.ganador(ahora())?.platilloIds}
        : <String>{for (final p in vot.propuestas) ...p.platilloIds};
    if (ids.isEmpty) return const {};
    try {
      return {
        for (final p in await _repo.platillos())
          if (ids.contains(p.id)) p.id: p.nombre,
      };
    } catch (_) {
      return const {};
    }
  }

  /// ¿Esta propuesta muestra sus platillos a esta persona?
  bool muestraPlatillosDe(VotacionPlan vot, PropuestaMenu p) {
    if (rol != Rol.casa || esMaestra) return true;
    return vot.ganador(ahora())?.id == p.id;
  }

  Future<VotacionPlan?> votacion(DateTime dia) async {
    _exigirVer();
    final d = _soloDia(dia);
    // Como en el servidor: al abrir el plan se cierran las votaciones
    // vencidas; el servidor decide los empates (la app no).
    await _repo.cerrarVotacionesVencidas(ahora());
    return _repo.votacion(d);
  }

  /// Propone un menú para [dia]; abre la votación con la primera propuesta.
  Future<VotacionPlan> proponer(
    DateTime dia, {
    required String titulo,
    List<String> platilloIds = const [],
  }) async {
    _exigirParticipar();
    final t = titulo.trim();
    if (t.isEmpty || t.length > 80) {
      throw const ErrorVotacion('Escribe un nombre de hasta 80 caracteres.');
    }
    final d = _soloDia(dia);
    final ahoraYa = ahora();
    final previa =
        await _repo.votacion(d) ??
        VotacionPlan(id: 'v-${d.toIso8601String().substring(0, 10)}', dia: d, abiertaEn: ahoraYa);
    final n = previa.propuestas.length + 1;
    final nueva = previa.conPropuesta(
      PropuestaMenu(
        id: '${previa.id}-p$n',
        autorId: personaId,
        autorNombre: personaNombre,
        titulo: t,
        platilloIds: platilloIds,
      ),
      ahoraYa,
    );
    await _repo.guardarVotacion(nueva);
    return nueva;
  }

  Future<VotacionPlan> votar(DateTime dia, String propuestaId) async {
    _exigirParticipar();
    final d = _soloDia(dia);
    final previa = await _repo.votacion(d);
    if (previa == null) throw const ErrorVotacion('No hay propuestas para ese día.');
    final nueva = previa.conVoto(personaId, propuestaId, ahora());
    await _repo.guardarVotacion(nueva);
    return nueva;
  }
}
