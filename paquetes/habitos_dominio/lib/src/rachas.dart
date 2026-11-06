import 'fecha.dart';

/// Estado de un día para la racha (regla 16).
enum EstadoDia { cumplido, gracia, noCumplido, noAplica }

/// Un día de un objetivo: si estaba [programado] (no en pausa) y si se cumplió.
class DiaRacha {
  const DiaRacha(this.fecha, {required this.programado, required this.cumplido});
  final DateTime fecha;
  final bool programado;
  final bool cumplido;
}

class ResultadoRacha {
  const ResultadoRacha(this.actual, this.mejor, this.estados);
  final int actual;
  final int mejor;
  final Map<DateTime, EstadoDia> estados;
}

/// Racha de un hábito diario (reglas 16 a 19). [dias] en orden ascendente.
/// Solo [EstadoDia.noCumplido] rompe; el día de [hoy] sin cumplir sigue abierto.
/// La gracia (hasta [graciaSemanal] por semana) cubre los primeros días fallados.
ResultadoRacha calcularRachaDiaria(
  List<DiaRacha> dias, {
  required DateTime hoy,
  int graciaSemanal = 1,
}) {
  final h = soloDia(hoy);
  final usadas = <DateTime, int>{};
  final estados = <DateTime, EstadoDia>{};
  var corrida = 0;
  var mejor = 0;
  for (final d in dias) {
    final f = soloDia(d.fecha);
    if (f.isAfter(h)) {
      estados[f] = EstadoDia.noAplica;
      continue;
    }
    if (!d.programado) {
      estados[f] = EstadoDia.noAplica;
    } else if (d.cumplido) {
      estados[f] = EstadoDia.cumplido;
      corrida++;
      if (corrida > mejor) mejor = corrida;
    } else if (f == h) {
      estados[f] = EstadoDia.noAplica; // el día en curso no rompe nada
    } else {
      final sem = lunesDe(f);
      final u = usadas[sem] ?? 0;
      if (u < graciaSemanal) {
        usadas[sem] = u + 1;
        estados[f] = EstadoDia.gracia;
      } else {
        estados[f] = EstadoDia.noCumplido;
        corrida = 0;
      }
    }
  }
  return ResultadoRacha(corrida, mejor, estados);
}

/// Racha en semanas (n por semana / semanal, regla 20). [cumplidas] ascendente;
/// si [ultimaEnCurso], la última semana no rompe aunque no esté completa.
ResultadoRacha calcularRachaSemanal(List<bool> cumplidas,
    {bool ultimaEnCurso = true}) {
  var corrida = 0;
  var mejor = 0;
  for (var i = 0; i < cumplidas.length; i++) {
    if (cumplidas[i]) {
      corrida++;
      if (corrida > mejor) mejor = corrida;
    } else if (!(ultimaEnCurso && i == cumplidas.length - 1)) {
      corrida = 0;
    }
  }
  return ResultadoRacha(corrida, mejor, const {});
}

/// Una pausa (regla 17): `objetivoId` nulo = todos.
class Pausa {
  const Pausa(this.desde, this.hasta, {this.objetivoId});
  final DateTime desde;
  final DateTime hasta;
  final String? objetivoId;

  bool cubre(DateTime f, String objetivoId) {
    final d = soloDia(f);
    return !d.isBefore(soloDia(desde)) &&
        !d.isAfter(soloDia(hasta)) &&
        (this.objetivoId == null || this.objetivoId == objetivoId);
  }
}

enum ModoMinimos { porArea, marcados }

/// Un elemento programado en un día, para la racha global.
class ElementoDia {
  const ElementoDia(this.area,
      {required this.minimo, required this.cumplido, this.sensible = false});
  final String area;
  final bool minimo;
  final bool cumplido;
  final bool sensible;
}

/// Evalúa un día de la racha global (regla 22). Lo sensible no cuenta.
/// Devuelve `programado: false` si no hay nada que evaluar.
DiaRacha evaluarDiaGlobal(
    DateTime fecha, List<ElementoDia> elementos, ModoMinimos modo) {
  final e = elementos.where((x) => !x.sensible).toList();
  if (modo == ModoMinimos.marcados) {
    final m = e.where((x) => x.minimo).toList();
    return DiaRacha(fecha,
        programado: m.isNotEmpty, cumplido: m.every((x) => x.cumplido));
  }
  final areas = e.map((x) => x.area).toSet();
  final ok = areas.every((a) => e.any((x) => x.area == a && x.cumplido));
  return DiaRacha(fecha, programado: areas.isNotEmpty, cumplido: ok);
}
