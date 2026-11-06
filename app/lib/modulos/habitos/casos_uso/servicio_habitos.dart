/// Casos de uso del núcleo de Hábitos (reglas 9 a 19 de la Fase 3).
library;

import 'package:habitos_dominio/habitos_dominio.dart';
import 'package:uuid/uuid.dart';

import '../datos/modelos.dart';
import '../datos/repositorio.dart';

/// Un elemento de Hoy: el objetivo, su registro del día y su racha.
class ItemHoy {
  const ItemHoy(this.objetivo, this.registro, this.racha);
  final ObjetivoHab objetivo;
  final RegistroHab? registro;
  final ResultadoRacha racha;

  EstadoRegistro get estado => registro?.estado ?? EstadoRegistro.pendiente;
  bool get hecho => estado == EstadoRegistro.hecho;
}

class ServicioHabitos {
  ServicioHabitos(this._repo, {DateTime Function()? ahora, this.gracia = 1})
      : _ahora = ahora ?? DateTime.now;

  final RepositorioHabitos _repo;
  final DateTime Function() _ahora;
  final int gracia;

  DateTime get hoy => soloDia(_ahora());

  /// Crea un objetivo (regla 2). Lanza [ArgumentError] con el primer error.
  Future<ObjetivoHab> crearObjetivo({
    required String titulo,
    required String area,
    TipoObjetivo tipo = TipoObjetivo.construir,
    String? unidad,
    int? metaValor,
    Frecuencia frecuencia = Frecuencia.diaria,
    int diasSemana = 127,
    bool minimo = false,
    bool esencial = false,
    String? motivo,
    DateTime? inicio,
  }) async {
    final errores =
        validarObjetivo(titulo: titulo, tipo: tipo, metaValor: metaValor, motivo: motivo);
    if (errores.isNotEmpty) throw ArgumentError(errores.first);
    final o = ObjetivoHab(
      id: const Uuid().v4(),
      titulo: titulo.trim(),
      area: area,
      tipo: tipo,
      fechaInicio: soloDia(inicio ?? hoy),
      unidad: unidad,
      metaValor: metaValor,
      frecuencia: frecuencia,
      diasSemana: diasSemana,
      minimo: minimo,
      esencial: esencial,
      motivo: motivo,
      modificadoEn: _ahora().toUtc(),
    );
    await _repo.guardarObjetivo(o);
    return o;
  }

  Future<void> archivar(ObjetivoHab o) =>
      _repo.guardarObjetivo(o.copiar(estado: 'archivado', modificadoEn: _ahora().toUtc()));

  /// Hoy: objetivos activos programados hoy, con su registro y su racha.
  Future<List<ItemHoy>> hoyDe([DateTime? fecha]) async {
    final f = soloDia(fecha ?? hoy);
    final objetivos = [for (final o in await _repo.objetivos()) if (o.activo && o.programadoEn(f)) o];
    final regs = await _repo.registros(sumarDias(f, -400), f);
    return [
      for (final o in objetivos)
        ItemHoy(
          o,
          regs.where((r) => r.objetivoId == o.id && r.fecha == f).firstOrNull,
          _racha(o, regs.where((r) => r.objetivoId == o.id).toList(), f),
        )
    ];
  }

  ResultadoRacha _racha(ObjetivoHab o, List<RegistroHab> regs, DateTime f) {
    final porDia = {for (final r in regs) r.fecha: r};
    final desde = o.fechaInicio.isAfter(sumarDias(f, -400)) ? soloDia(o.fechaInicio) : sumarDias(f, -400);
    final dias = <DiaRacha>[];
    for (var d = desde; !d.isAfter(f); d = sumarDias(d, 1)) {
      dias.add(DiaRacha(d,
          programado: o.programadoEn(d),
          cumplido: porDia[d]?.estado == EstadoRegistro.hecho));
    }
    return calcularRachaDiaria(dias, hoy: f, graciaSemanal: gracia);
  }

  Future<void> _guardar(ObjetivoHab o, DateTime f, EstadoRegistro e,
      {int? valor, int? movidoAMin, String? motivo}) => _repo.guardarRegistro(RegistroHab(
        id: idRegistro(o.id, f),
        objetivoId: o.id,
        fecha: soloDia(f),
        estado: e,
        valor: valor,
        movidoAMin: movidoAMin,
        motivoOmision: motivo,
        modificadoEn: _ahora().toUtc(),
      ));

  /// *Hecho* en un toque; con meta numérica el valor se precarga con la meta.
  Future<void> marcarHecho(ObjetivoHab o, {DateTime? fecha, int? valor}) =>
      _guardar(o, fecha ?? hoy, EstadoRegistro.hecho, valor: valor ?? o.metaValor);

  Future<void> posponer(ObjetivoHab o, {required int aMin, DateTime? fecha}) =>
      _guardar(o, fecha ?? hoy, EstadoRegistro.pospuesto, movidoAMin: aMin);

  Future<void> omitir(ObjetivoHab o, {String? motivo, DateTime? fecha}) =>
      _guardar(o, fecha ?? hoy, EstadoRegistro.omitido, motivo: motivo);

  /// Deshacer: vuelve a `pendiente` (regla 12).
  Future<void> deshacer(ObjetivoHab o, {DateTime? fecha}) =>
      _guardar(o, fecha ?? hoy, EstadoRegistro.pendiente);

  /// Avance real de cada objetivo (0 a 1): metas de una sola vez, lo
  /// acumulado frente a la meta; los demás, los días programados cumplidos en
  /// la última semana (regla 5). Sin días programados todavía, 0.
  Future<Map<String, double>> avances(List<ObjetivoHab> objetivos) async {
    final r = <String, double>{};
    if (objetivos.isEmpty) return r;
    final desde = objetivos.map((o) => soloDia(o.fechaInicio)).reduce((a, b) => a.isBefore(b) ? a : b);
    final regs = await _repo.registros(desde, hoy);
    for (final o in objetivos) {
      final mios = regs.where((x) => x.objetivoId == o.id && x.estado == EstadoRegistro.hecho).toList();
      if (o.frecuencia == Frecuencia.total && (o.metaValor ?? 0) > 0) {
        final suma = mios.fold<int>(0, (a, x) => a + (x.valor ?? 0));
        r[o.id] = (suma / o.metaValor!).clamp(0.0, 1.0);
        continue;
      }
      var prog = 0, ok = 0;
      for (var i = 0; i < 7; i++) {
        final d = sumarDias(hoy, -i);
        if (!o.programadoEn(d)) continue;
        prog++;
        if (mios.any((x) => soloDia(x.fecha) == d)) ok++;
      }
      final pct = cumplimientoSemanal(ok, prog);
      r[o.id] = pct == null ? 0 : pct / 100;
    }
    return r;
  }

  /// Texto discreto para `habitos.resumen_hoy` (regla 120): solo lo no
  /// sensible, que es todo lo que vive aquí.
  Future<String> resumenHoy() async {
    final l = await hoyDe();
    if (l.isEmpty) return MensajesHabitos.diaLibre;
    final hechos = l.where((i) => i.hecho).length;
    return 'Hoy llevas $hechos de ${l.length}.';
  }
}
