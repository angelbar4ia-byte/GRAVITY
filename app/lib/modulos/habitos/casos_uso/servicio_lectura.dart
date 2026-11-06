/// Planes de lectura (reglas 81 a 83) con *ponerse al día*, *saltar* y
/// *reiniciar*, sin culpa.
library;

import 'package:habitos_dominio/habitos_dominio.dart';
import 'package:uuid/uuid.dart';

import '../datos/repositorio_agenda.dart';

class LecturaDeHoy {
  const LecturaDeHoy(this.plan, this.dia, this.atrasados);
  final PlanGuardado plan;
  final DiaPlan dia;
  final int atrasados; // días pasados pendientes (sin reproche)
}

class ServicioLectura {
  ServicioLectura(this._repo, {DateTime Function()? ahora}) : _ahora = ahora ?? DateTime.now;
  final RepositorioAgenda _repo;
  final DateTime Function() _ahora;
  DateTime get hoy => soloDia(_ahora());

  static const _nombres = {
    TipoPlan.rutaInicio: 'Ruta de inicio (Juan)',
    TipoPlan.nt90: 'Nuevo Testamento en 90 días',
    TipoPlan.salmosProverbios30: 'Salmos y Proverbios en 30 días',
    TipoPlan.biblia1Ano: 'La Biblia en un año',
    TipoPlan.libro: 'Un libro',
  };

  /// Crea un plan; la fecha de inicio la fija cada persona (por omisión, hoy).
  Future<PlanGuardado> crear(TipoPlan tipo,
      {DateTime? inicio, int mascara = 127, int? libro, int capitulosPorDia = 1, String version = 'rvr1909'}) async {
    final i = soloDia(inicio ?? hoy);
    final plan = generarPlan(tipo, i, mascaraDias: mascara, libro: libro, capitulosPorDia: capitulosPorDia);
    final nombre = tipo == TipoPlan.libro ? 'Leer ${canon[libro! - 1].nombre}' : _nombres[tipo]!;
    final g = PlanGuardado(
        id: const Uuid().v4(), nombre: nombre, plan: plan, inicio: i, mascara: mascara, version: version, libro: libro);
    await _repo.crearPlan(g, _ahora());
    return g;
  }

  Future<List<PlanGuardado>> activos() async =>
      [for (final p in await _repo.planes()) if (p.estado == 'activo') p];

  /// El día que toca leer: el de hoy o, si no hay, el primer pendiente.
  LecturaDeHoy? deHoy(PlanGuardado p) {
    final pend = p.plan.dias.where((d) => d.estado == EstadoDiaPlan.pendiente).toList();
    if (pend.isEmpty) return null;
    final atrasados = pend.where((d) => d.fecha.isBefore(hoy)).length;
    final dia = pend.firstWhere((d) => !d.fecha.isBefore(hoy), orElse: () => pend.first);
    return LecturaDeHoy(p, dia, atrasados);
  }

  Future<void> marcarHecho(PlanGuardado p, DiaPlan d) async {
    d.estado = EstadoDiaPlan.hecho;
    await _repo.guardarDiaPlan(p, d);
  }

  Future<void> _guardarTodos(PlanGuardado p) async {
    for (final d in p.plan.dias) {
      await _repo.guardarDiaPlan(p, d);
    }
  }

  Future<void> ponerAlDiaEn(PlanGuardado p, int dias) async {
    ponerAlDia(p.plan, hoy, dias);
    await _guardarTodos(p);
  }

  Future<void> saltar(PlanGuardado p) async {
    saltarAtrasados(p.plan, hoy);
    await _guardarTodos(p);
  }

  Future<void> reiniciar(PlanGuardado p) async {
    reiniciarTramo(p.plan, hoy, p.mascara);
    await _guardarTodos(p);
  }
}
