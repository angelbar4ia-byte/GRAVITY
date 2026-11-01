/// Progreso y revisión semanal (reglas 122 a 128). Solo lo no sensible: los
/// hábitos a eliminar y el diario se resumen en su propia pantalla.
library;

import 'package:habitos_dominio/habitos_dominio.dart';
import 'package:uuid/uuid.dart';

import '../datos/modelos.dart';
import '../datos/modelos_agenda.dart';
import '../datos/repositorio.dart';
import '../datos/repositorio_agenda.dart';
import 'servicio_diario.dart';

class DiaConstanciaDato {
  const DiaConstanciaDato(this.fecha, this.estado, this.hoy);
  final DateTime fecha;
  final EstadoDia estado;
  final bool hoy;
}

class ServicioProgreso {
  ServicioProgreso(this._repo, this._agenda, {DateTime Function()? ahora})
      : _ahora = ahora ?? DateTime.now;
  final RepositorioHabitos _repo;
  final RepositorioAgenda _agenda;
  final DateTime Function() _ahora;
  DateTime get hoy => soloDia(_ahora());

  /// Cumplimiento semanal por área (% entero hacia abajo; nulo = sin dato).
  Future<Map<String, int?>> cumplimientoPorArea(DateTime lunes) async {
    final l = soloDia(lunes);
    final fin = sumarDias(l, 6);
    final os = [for (final o in await _repo.objetivos()) if (o.activo) o];
    final regs = await _repo.registros(l, fin);
    final prog = <String, int>{};
    final ok = <String, int>{};
    for (var i = 0; i < 7; i++) {
      final d = sumarDias(l, i);
      if (d.isAfter(hoy)) break;
      for (final o in os.where((o) => o.programadoEn(d))) {
        prog[o.area] = (prog[o.area] ?? 0) + 1;
        if (regs.any((r) => r.objetivoId == o.id && r.fecha == d && r.estado == EstadoRegistro.hecho)) {
          ok[o.area] = (ok[o.area] ?? 0) + 1;
        }
      }
    }
    return {for (final a in prog.keys) a: cumplimientoSemanal(ok[a] ?? 0, prog[a]!)};
  }

  /// Racha global y calendario de constancia de los últimos [dias] días.
  Future<(ResultadoRacha, List<DiaConstanciaDato>)> constancia({int dias = 28}) async {
    final aj = await _agenda.ajustes();
    final os = [for (final o in await _repo.objetivos()) if (o.activo) o];
    final desde = sumarDias(hoy, -(dias + 60));
    final regs = await _repo.registros(desde, hoy);
    final lista = <DiaRacha>[];
    for (var d = desde; !d.isAfter(hoy); d = sumarDias(d, 1)) {
      final el = [
        for (final o in os.where((o) => o.programadoEn(d)))
          ElementoDia(o.area,
              minimo: o.minimo,
              cumplido: regs.any((r) => r.objetivoId == o.id && r.fecha == d && r.estado == EstadoRegistro.hecho))
      ];
      lista.add(evaluarDiaGlobal(d, el, aj.minimosModo));
    }
    final r = calcularRachaDiaria(lista, hoy: hoy, graciaSemanal: aj.graciaSemanal);
    return (
      r,
      [
        for (var i = dias - 1; i >= 0; i--)
          DiaConstanciaDato(sumarDias(hoy, -i), r.estados[sumarDias(hoy, -i)] ?? EstadoDia.noAplica, i == 0)
      ]
    );
  }
}

class ServicioRevision {
  ServicioRevision(this._agenda, this._progreso, this._diario, {DateTime Function()? ahora})
      : _ahora = ahora ?? DateTime.now;
  final RepositorioAgenda _agenda;
  final ServicioProgreso _progreso;
  final ServicioDiario? _diario;
  final DateTime Function() _ahora;

  DateTime get lunes => lunesDe(_ahora());

  String _id(DateTime semana) => const Uuid().v5(
      '6b1f8e0a-4c3d-5e2f-9a7b-1d2c3e4f5a6b', 'revision|${soloDia(semana).toIso8601String().substring(0, 10)}');

  /// Cuándo es la revisión de esta semana y su aviso (reglas 124 y 113).
  Future<(DateTime, DateTime)> programacion([DateTime? semana]) async {
    final a = await _agenda.ajustes();
    final dia = diaDeRevision(semana ?? lunes, diaSemana: a.revisionDia);
    DateTime en(int min) => DateTime(dia.year, dia.month, dia.day, min ~/ 60, min % 60);
    return (en(minutoDeAviso(a.revisionHoraMin, a.revisionAvisoMin)), en(a.revisionHoraMin));
  }

  Future<Map<String, int?>> resumen() => _progreso.cumplimientoPorArea(lunes);

  Future<RevisionHab> _guardar(EstadoRevision e, {Map<String, int?>? resumen, List<Object?> ajustes = const [], bool? dar}) async {
    final r = RevisionHab(
      id: _id(lunes),
      semana: lunes,
      estado: e,
      modificadoEn: _ahora().toUtc(),
      resumen: {for (final x in (resumen ?? {}).entries) x.key: x.value},
      ajustes: ajustes,
      darCumplido: dar,
    );
    await _agenda.guardarRevision(r);
    return r;
  }

  /// Cierra la revisión: lo no sensible a `hab_revisiones`, las respuestas
  /// escritas al diario cifrado (regla 97). No hay racha de revisiones.
  Future<RevisionHab> completar({
    Map<String, String> respuestas = const {},
    List<Object?> ajustes = const [],
    bool? dar,
  }) async {
    if (respuestas.values.any((v) => v.trim().isNotEmpty)) {
      await _diario?.guardarRespuestasRevision(lunes, respuestas);
    }
    return _guardar(EstadoRevision.completada, resumen: await resumen(), ajustes: ajustes, dar: dar);
  }

  Future<RevisionHab> omitir() => _guardar(EstadoRevision.omitida);

  Future<RevisionHab?> estado() => _agenda.revision(lunes);

  bool vigente() => revisionVigente(lunes, _ahora());
}
