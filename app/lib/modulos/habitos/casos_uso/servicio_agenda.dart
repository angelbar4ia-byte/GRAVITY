/// Agenda, bloques, carga del día y asistente de configuración (reglas 63 a 72).
library;

import 'package:habitos_dominio/habitos_dominio.dart';
import 'package:uuid/uuid.dart';

import '../datos/modelos.dart';
import '../datos/modelos_agenda.dart';
import '../datos/repositorio.dart';
import '../datos/repositorio_agenda.dart';

class OcurrenciaBloque {
  const OcurrenciaBloque(this.bloque, this.registro);
  final BloqueHab bloque;
  final RegistroHab? registro;
  EstadoRegistro get estado => registro?.estado ?? EstadoRegistro.pendiente;
  int get inicioMin => registro?.movidoAMin ?? bloque.inicioMin;
}

class CargaDelDia {
  const CargaDelDia(this.libres, this.programados, this.nivel);
  final int libres;
  final int programados;
  final NivelCarga nivel;
}

class ServicioAgenda {
  ServicioAgenda(this._agenda, this._repo, {DateTime Function()? ahora})
    : _ahora = ahora ?? DateTime.now;

  final RepositorioAgenda _agenda;
  final RepositorioHabitos _repo;
  final DateTime Function() _ahora;
  DateTime get hoy => soloDia(_ahora());

  Future<List<OcurrenciaBloque>> bloquesDe(DateTime fecha) async {
    final f = soloDia(fecha);
    final bs = [
      for (final b in await _agenda.bloques())
        if (b.activo && b.recurrente.ocurreEn(f)) b,
    ];
    final regs = await _repo.registros(f, f);
    final o = [
      for (final b in bs)
        OcurrenciaBloque(b, regs.where((r) => r.bloqueId == b.id).firstOrNull),
    ]..sort((a, b) => a.inicioMin.compareTo(b.inicioMin));
    return o;
  }

  /// Bloques que se cruzan con [nuevo] (regla 67): avisa, no impide.
  Future<List<BloqueHab>> conflictosDe(BloqueHab nuevo) async {
    final r = <BloqueHab>[];
    for (var i = 0; i < 14; i++) {
      final f = sumarDias(soloDia(nuevo.desde), i);
      if (!nuevo.recurrente.ocurreEn(f)) continue;
      for (final o in await bloquesDe(f)) {
        if (o.bloque.id != nuevo.id &&
            conflictos(
              Intervalo(nuevo.inicioMin, nuevo.inicioMin + nuevo.duracionMin),
              [
                Intervalo(
                  o.bloque.inicioMin,
                  o.bloque.inicioMin + o.bloque.duracionMin,
                ),
              ],
            ).isNotEmpty &&
            !r.any((x) => x.id == o.bloque.id)) {
          r.add(o.bloque);
        }
      }
    }
    return r;
  }

  Future<BloqueHab> crearBloque({
    required String titulo,
    required String area,
    required int inicioMin,
    required int duracionMin,
    int dias = 127,
    String tipo = 'actividad',
    bool minimo = false,
    bool esencial = false,
    int? recordarMin,
    DateTime? desde,
  }) async {
    if (titulo.trim().isEmpty || titulo.length > 120) {
      throw ArgumentError('El título va de 1 a 120 caracteres.');
    }
    final b = BloqueHab(
      id: const Uuid().v4(),
      titulo: titulo.trim(),
      area: area,
      tipo: tipo,
      inicioMin: inicioMin,
      duracionMin: duracionMin,
      dias: dias,
      desde: soloDia(desde ?? hoy),
      minimo: minimo,
      esencial: esencial,
      recordarMin: recordarMin,
      modificadoEn: _ahora().toUtc(),
    );
    await _agenda.guardarBloque(b);
    return b;
  }

  /// Edita nombre, área, hora, duración, días y recordatorio (E4). No toca el
  /// id: los registros del bloque (hecho, pospuesto, omitido) se conservan.
  /// Devuelve el bloque editado; para deshacer, [restaurarBloque].
  Future<BloqueHab> editarBloque(
    BloqueHab b, {
    required String titulo,
    required String area,
    required int inicioMin,
    required int duracionMin,
    required int dias,
    bool? minimo,
    bool? esencial,
    int? recordarMin,
  }) async {
    final errores = validarBloque(
      titulo: titulo,
      area: area,
      inicioMin: inicioMin,
      duracionMin: duracionMin,
      dias: dias,
      recordarMin: recordarMin,
    );
    if (errores.isNotEmpty) throw ArgumentError(errores.first);
    final nuevo = b.editado(
      titulo: titulo.trim(),
      area: area,
      inicioMin: inicioMin,
      duracionMin: duracionMin,
      dias: dias,
      minimo: minimo ?? b.minimo,
      esencial: esencial ?? b.esencial,
      recordarMin: recordarMin,
      modificadoEn: _ahora().toUtc(),
    );
    await _agenda.guardarBloque(nuevo);
    return nuevo;
  }

  Future<void> restaurarBloque(BloqueHab original) =>
      _agenda.guardarBloque(original.copiar(modificadoEn: _ahora().toUtc()));

  /// Recordatorio de dar (E11): apagado por omisión; día (1 a 7) y hora.
  /// Hábitos no maneja dinero: no hay montos.
  Future<void> configurarDar({
    required bool activo,
    int? dia,
    int? horaMin,
  }) async {
    if (activo &&
        (dia == null ||
            dia < 1 ||
            dia > 7 ||
            horaMin == null ||
            horaMin < 0 ||
            horaMin > 1439)) {
      throw ArgumentError('Elige el día y la hora del recordatorio.');
    }
    final a = await _agenda.ajustes();
    await _agenda.guardarAjustes(
      a.copiar(darActivo: activo, darDia: dia, darHoraMin: horaMin),
      _ahora(),
    );
  }

  Future<void> desactivar(BloqueHab b) => _agenda.guardarBloque(
    b.copiar(activo: false, modificadoEn: _ahora().toUtc()),
  );

  Future<void> _registro(
    BloqueHab b,
    DateTime f,
    EstadoRegistro e, {
    int? movidoA,
    String? motivo,
  }) => _repo.guardarRegistro(
    RegistroHab(
      id: const Uuid().v5(
        '6b1f8e0a-4c3d-5e2f-9a7b-1d2c3e4f5a6b',
        'bloque|${b.id}|${soloDia(f).toIso8601String().substring(0, 10)}',
      ),
      bloqueId: b.id,
      fecha: soloDia(f),
      estado: e,
      movidoAMin: movidoA,
      motivoOmision: motivo,
      modificadoEn: _ahora().toUtc(),
    ),
  );

  Future<void> marcarHecho(BloqueHab b, {DateTime? fecha}) =>
      _registro(b, fecha ?? hoy, EstadoRegistro.hecho);
  Future<void> posponer(BloqueHab b, int aMin, {DateTime? fecha}) =>
      _registro(b, fecha ?? hoy, EstadoRegistro.pospuesto, movidoA: aMin);
  Future<void> omitir(BloqueHab b, {DateTime? fecha}) =>
      _registro(b, fecha ?? hoy, EstadoRegistro.omitido);
  Future<void> deshacer(BloqueHab b, {DateTime? fecha}) =>
      _registro(b, fecha ?? hoy, EstadoRegistro.pendiente);

  /// Medidor de carga del día (regla 25).
  Future<CargaDelDia> carga([DateTime? fecha]) async {
    final aj = await _agenda.ajustes();
    final bs = await bloquesDe(fecha ?? hoy);
    var fijos = 0, prog = 0;
    for (final o in bs) {
      if (o.bloque.fijo) {
        fijos += o.bloque.duracionMin;
      } else {
        prog += o.bloque.duracionMin;
      }
    }
    final libres = minutosLibres(
      despertarMin: aj.despertarMin,
      dormirMin: aj.dormirMin,
      fijosMin: fijos,
    );
    return CargaDelDia(
      libres,
      prog,
      medirCarga(libres: libres, programados: prog),
    );
  }

  /// Huecos libres del día (regla 67).
  Future<List<Intervalo>> huecos(
    DateTime fecha, {
    int minimoMin = 15,
    int? preferidaMin,
  }) async {
    final aj = await _agenda.ajustes();
    final bs = await bloquesDe(fecha);
    return huecosLibres(
      aj.despertarMin,
      aj.dormirMin,
      [
        for (final o in bs)
          Intervalo(
            o.bloque.inicioMin,
            o.bloque.inicioMin + o.bloque.duracionMin,
          ),
      ],
      minimoMin: minimoMin,
      preferidaMin: preferidaMin,
    );
  }

  /// Aplica el asistente de configuración (regla 68): horario de trabajo,
  /// traslado, día, áreas, revisión. Cada paso omitido queda como estaba.
  Future<void> aplicarAsistente({
    int? despertarMin,
    int? dormirMin,
    List<String>? areas,
    int? trabajoEntradaMin,
    int? trabajoSalidaMin,
    int trabajoDias = 31, // lunes a viernes
    int trasladoIdaMin = 0,
    int trasladoVueltaMin = 0,
    int? revisionDia,
    int? revisionHoraMin,
    int? revisionAvisoMin,
    bool? darActivo,
    int? darDia,
    int? darHoraMin,
    Set<int> pasosHechos = const {},
  }) async {
    final a = await _agenda.ajustes();
    await _agenda.guardarAjustes(
      a.copiar(
        despertarMin: despertarMin,
        dormirMin: dormirMin,
        areasActivas: areas,
        revisionDia: revisionDia,
        revisionHoraMin: revisionHoraMin,
        revisionAvisoMin: revisionAvisoMin,
        darActivo: darActivo,
        darDia: darDia,
        darHoraMin: darHoraMin,
        asistente: {
          'pasos': pasosHechos.toList()..sort(),
          'completo': pasosHechos.length >= 8,
        },
      ),
      _ahora(),
    );
    if (trabajoEntradaMin != null && trabajoSalidaMin != null) {
      await crearBloque(
        titulo: 'Trabajo',
        area: 'laboral',
        tipo: 'trabajo',
        inicioMin: trabajoEntradaMin,
        duracionMin: trabajoSalidaMin - trabajoEntradaMin,
        dias: trabajoDias,
      );
      if (trasladoIdaMin > 0) {
        await crearBloque(
          titulo: 'Traslado de ida',
          area: 'laboral',
          tipo: 'traslado',
          inicioMin: trabajoEntradaMin - trasladoIdaMin,
          duracionMin: trasladoIdaMin,
          dias: trabajoDias,
        );
      }
      if (trasladoVueltaMin > 0) {
        await crearBloque(
          titulo: 'Traslado de regreso',
          area: 'laboral',
          tipo: 'traslado',
          inicioMin: trabajoSalidaMin,
          duracionMin: trasladoVueltaMin,
          dias: trabajoDias,
        );
      }
    }
  }

  /// Semana tipo con la carga de cada día (paso 8). Lunes = índice 0.
  Future<List<CargaDelDia>> semanaTipo([DateTime? fecha]) async => [
    for (var i = 0; i < 7; i++)
      await carga(sumarDias(lunesDe(fecha ?? hoy), i)),
  ];
}
