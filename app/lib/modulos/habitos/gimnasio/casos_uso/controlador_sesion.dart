/// La sesión en curso (E5): qué ejercicio, qué serie, repeticiones y carga que
/// se ven, el descanso, deshacer y terminar. Es lógica sin widgets: la pantalla
/// solo la dibuja y le pasa los toques.
///
/// - **Una serie, un toque** ([hecha]): guarda las repeticiones y la carga que
///   se ven (las sugeridas, salvo que la persona las haya cambiado con − y +).
/// - **Local primero:** cada serie se guarda en el equipo antes de seguir; con o
///   sin red es igual (CA-G-32 y CA-G-34).
/// - **Deshacer** quita la última serie (la pantalla lo muestra 5 s, 7.2).
/// - **El descanso cuenta hacia un instante final**; cada cambio avisa a
///   [ServicioAvisoDescanso] para programar o cancelar la notificación local.
/// - **Mide** cuánto tarda cada repetición y cada cambio de ejercicio para
///   calibrar el tiempo estimado (5.5, CA-G-12): solo se guarda en este equipo.
library;

import 'package:flutter/foundation.dart';
import 'package:habitos_dominio/habitos_dominio.dart';

import '../../../../diseno/gimnasio/temporizador_descanso.dart'
    show DescansoPlanificado;
import '../../../../nucleo/avisos/aviso_descanso.dart';
import '../../../../nucleo/base_local/base_local.dart';
import '../../../../nucleo/gimnasio/repositorio_gimnasio.dart';
import '../datos/modelos_gimnasio.dart';
import 'servicio_gimnasio.dart';

/// En qué momento va la sesión.
enum FaseSesion { calentamiento, serie, fin }

/// Cuánto tiempo se ofrece *Deshacer* tras guardar una serie (7.2).
const duracionDeshacer = Duration(seconds: 5);

class SerieGuardada {
  const SerieGuardada({
    required this.id,
    required this.ejercicio,
    required this.n,
    required this.reps,
    this.cargaPasos,
    this.bandaId,
  });

  final String id;
  final int ejercicio;
  final int n;
  final int reps;
  final int? cargaPasos;
  final String? bandaId;
}

class ControladorSesion extends ChangeNotifier {
  ControladorSesion({
    required this.servicio,
    required this.hoy,
    required this.fila,
    required this.datos,
    DateTime Function()? ahora,
    this.avisos,
  }) : _ahora = ahora ?? DateTime.now,
       _ejercicios = [...hoy.sesion!.ejercicios],
       _planInicial = [...hoy.sesion!.ejercicios];

  final ServicioGimnasio servicio;
  final EntrenamientoHoy hoy;
  GimSesionFila fila;
  final DatosGimnasio datos;
  final DateTime Function() _ahora;
  final ServicioAvisoDescanso? avisos;

  final List<EjercicioPlanificado> _ejercicios;
  final List<EjercicioPlanificado> _planInicial;
  final List<SerieGuardada> _hechas = [];

  FaseSesion fase = FaseSesion.calentamiento;
  int idx = 0;

  /// Serie en curso del ejercicio actual (1 a `series`).
  int serie = 1;
  int reps = 0;
  int? cargaPasos;
  PasoBanda? banda;
  DescansoPlanificado? descanso;
  bool _versionCorta = false;

  /// La última serie guardada y hasta cuándo se ofrece *Deshacer*.
  SerieGuardada? ultima;
  DateTime? _deshacerHasta;

  /// El ejercicio cuyo esfuerzo se puede anotar ahora (opcional), con la serie
  /// donde se guarda.
  int? esfuerzoPendiente;
  String? _serieDelEsfuerzo;

  // Mediciones (solo locales).
  DateTime? _inicioSerie;
  DateTime? _finUltimaSerie;
  DateTime? _finDescanso;
  final List<int> _segPorRep = [];
  final List<int> _segCambio = [];
  final Map<String, DateTime> _horaDeSerie = {};
  final Map<String, int?> _descansoDe = {};

  // ---------------------------------------------------------------- lectura

  List<EjercicioPlanificado> get ejercicios => List.unmodifiable(_ejercicios);
  EjercicioPlanificado get actual => _ejercicios[idx];
  EjercicioPlanificado? get siguiente =>
      idx + 1 < _ejercicios.length ? _ejercicios[idx + 1] : null;
  List<SerieGuardada> get hechas => List.unmodifiable(_hechas);
  bool get porTiempo => actual.porTiempo;
  bool get versionCorta => _versionCorta || hoy.version == VersionSesion.corta;
  Inventario get inventario => datos.inventario;

  int get seriesPlaneadas => _ejercicios.fold(0, (a, e) => a + e.series);
  int get seriesHechas => _hechas.length;

  /// Series hechas del ejercicio [i].
  int hechasDe(int i) => _hechas.where((s) => s.ejercicio == i).length;

  bool get deshacerVisible =>
      ultima != null &&
      _deshacerHasta != null &&
      _ahora().isBefore(_deshacerHasta!);

  /// Lo que se ve de la carga: «placa 3», «banda verde», `null` si no lleva.
  bool get llevaCarga {
    final v = hoy.sesion == null ? null : _variante(actual.varianteId);
    return v != null &&
        (v.carga == TipoCarga.pila || v.carga == TipoCarga.banda);
  }

  bool get esDeBanda => _variante(actual.varianteId)?.carga == TipoCarga.banda;

  Variante? _variante(String id) => servicio.catalogo.variante(id);

  /// Con el tope de la pila **confirmado**, no se sube de ahí (CA-G-17).
  bool get enTope {
    if (esDeBanda) {
      final s = secuenciaBandas(inventario.bandas);
      return banda != null && s.isNotEmpty && s.last == banda;
    }
    return cargaPasos != null && inventario.enTopeDePila(cargaPasos!);
  }

  String? get cargaTexto {
    if (esDeBanda) {
      final b = banda == null
          ? null
          : inventario.bandas.where((x) => x.id == banda!.bandaId).firstOrNull;
      return b == null ? null : (banda!.doble ? '${b.nombre} ×2' : b.nombre);
    }
    return cargaPasos == null
        ? null
        : mostrarCargaPasos(cargaPasos!, inventario).texto;
  }

  // -------------------------------------------------------------- arranque

  /// Retoma lo que ya había (las series guardadas) y se coloca en la
  /// siguiente. Se llama una vez, al abrir la pantalla.
  Future<void> inicializar() async {
    final filas = await servicio.repo.series(servicio.persona, fila.id);
    for (var i = 0; i < _ejercicios.length; i++) {
      final e = _ejercicios[i];
      final de = [
        for (final s in filas)
          if (s.varianteId == e.varianteId || s.sustituyeA == e.varianteId) s,
      ]..sort((a, b) => a.n.compareTo(b.n));
      if (de.isEmpty) continue;
      if (de.first.varianteId != e.varianteId) {
        _ejercicios[i] = _conVariante(e, de.first.varianteId);
      }
      for (final s in de) {
        _hechas.add(
          SerieGuardada(
            id: s.id,
            ejercicio: i,
            n: s.n,
            reps: s.reps ?? s.segundos ?? 0,
            cargaPasos: s.cargaPasos,
            bandaId: s.bandaId,
          ),
        );
      }
    }
    _versionCorta = fila.version == 'corta';
    if (_hechas.isNotEmpty) {
      fase = FaseSesion.serie;
      _colocar();
    } else {
      _preparar();
    }
    notifyListeners();
  }

  /// Termina el calentamiento (*Listo*).
  void listo() {
    if (fase != FaseSesion.calentamiento) return;
    fase = FaseSesion.serie;
    _inicioSerie = _ahora();
    notifyListeners();
  }

  /// Pone el puntero en el primer ejercicio con series pendientes.
  void _colocar() {
    for (var i = 0; i < _ejercicios.length; i++) {
      final n = hechasDe(i);
      if (n < _ejercicios[i].series) {
        idx = i;
        serie = n + 1;
        _preparar(desdeUltima: n > 0);
        return;
      }
    }
    idx = _ejercicios.length - 1;
    serie = _ejercicios.last.series;
    fase = FaseSesion.fin;
  }

  /// Repeticiones y carga con las que se ve la serie en curso: las sugeridas o
  /// las de la serie anterior de este ejercicio.
  void _preparar({bool desdeUltima = false}) {
    final e = actual;
    final previas = _hechas.where((s) => s.ejercicio == idx).toList();
    if (previas.isNotEmpty && desdeUltima) {
      final u = previas.last;
      reps = u.reps;
      cargaPasos = u.cargaPasos;
      banda = u.bandaId == null ? null : PasoBanda(u.bandaId!);
    } else {
      reps = e.objetivo;
      cargaPasos = e.cargaPasos;
      banda = e.bandaId == null
          ? null
          : PasoBanda(e.bandaId!, doble: e.bandaDoble);
    }
  }

  // -------------------------------------------------------------- ajustes

  void masReps() {
    reps = (reps + 1).clamp(0, 100);
    notifyListeners();
  }

  void menosReps() {
    reps = (reps - 1).clamp(0, 100);
    notifyListeners();
  }

  void masCarga() {
    if (esDeBanda) {
      final s = secuenciaBandas(inventario.bandas);
      if (s.isEmpty) return;
      final i = banda == null ? -1 : s.indexOf(banda!);
      if (i + 1 < s.length) banda = s[i + 1];
    } else {
      final tope = inventario.pasosMax ?? 60;
      if ((cargaPasos ?? 0) < tope) cargaPasos = (cargaPasos ?? 0) + 1;
    }
    notifyListeners();
  }

  void menosCarga() {
    if (esDeBanda) {
      final s = secuenciaBandas(inventario.bandas);
      final i = banda == null ? -1 : s.indexOf(banda!);
      if (i > 0) banda = s[i - 1];
    } else if ((cargaPasos ?? 0) > 1) {
      cargaPasos = cargaPasos! - 1;
    }
    notifyListeners();
  }

  // ----------------------------------------------------------------- serie

  /// ✓ **Hecha**: guarda la serie con lo que se ve y empieza el descanso.
  Future<void> hecha() async {
    if (fase != FaseSesion.serie) return;
    final ahora = _ahora();
    final e = actual;
    final i = idx;
    final n = serie;
    final base = _planInicial.length > i ? _planInicial[i] : e;
    // Cuánto descansó antes de esta serie y cuánto tardó en hacerla.
    int? descansoReal;
    if (_finUltimaSerie != null && n > 1) {
      final finDescanso = descanso == null
          ? ahora
          : (descanso!.instanteFinal.isBefore(ahora)
                ? descanso!.instanteFinal
                : ahora);
      descansoReal = finDescanso
          .difference(_finUltimaSerie!)
          .inSeconds
          .clamp(0, 900);
      _finDescanso = finDescanso;
    }
    final trabajo = _inicioSerie == null
        ? null
        : ahora.difference(_finDescanso ?? _inicioSerie!).inSeconds;
    if (n > 1 &&
        trabajo != null &&
        !e.porTiempo &&
        reps > 0 &&
        trabajo ~/ reps >= 1 &&
        trabajo ~/ reps <= 20) {
      _segPorRep.add(trabajo ~/ reps);
    }
    if (n == 1 && i > 0 && _finUltimaSerie != null) {
      // Cambio de ejercicio: lo que pasó entre la última serie del anterior y
      // esta, sin el descanso planeado ni lo que tardó esta serie.
      final total = ahora.difference(_finUltimaSerie!).inSeconds;
      final cambio = total - e.descansoS - (reps * 4);
      if (cambio >= 5 && cambio <= 300) _segCambio.add(cambio);
    }
    final id = await servicio.registrarSerie(
      sesionId: fila.id,
      ejercicio: e,
      varianteId: e.varianteId,
      n: n,
      reps: e.porTiempo ? null : reps,
      segundos: e.porTiempo ? reps : null,
      cargaPasos: esDeBanda ? null : cargaPasos,
      bandaId: esDeBanda ? banda?.bandaId : null,
      descansoRealS: descansoReal,
      sustituyeA: e.varianteId != base.varianteId ? base.varianteId : null,
      motivo: e.varianteId != base.varianteId ? _motivoCambio : null,
    );
    _hechas.add(
      SerieGuardada(
        id: id,
        ejercicio: i,
        n: n,
        reps: reps,
        cargaPasos: esDeBanda ? null : cargaPasos,
        bandaId: esDeBanda ? banda?.bandaId : null,
      ),
    );
    ultima = _hechas.last;
    _deshacerHasta = ahora.add(duracionDeshacer);
    _finUltimaSerie = ahora;
    _horaDeSerie[id] = ahora;
    _descansoDe[id] = descansoReal;
    _avanzar();
    final haySiguiente = fase == FaseSesion.serie;
    if (haySiguiente) {
      descanso = DescansoPlanificado.iniciar(
        ahora,
        Duration(seconds: e.descansoS),
      );
      _finDescanso = null;
      _inicioSerie = descanso!.instanteFinal;
      await avisos?.alCambiarDescanso(descanso!.instanteFinal);
    } else {
      descanso = null;
      await avisos?.alCambiarDescanso(null);
    }
    notifyListeners();
  }

  MotivoCambioLocal _motivoCambio = MotivoCambioLocal.preferencia;

  /// Pasa a la siguiente serie o ejercicio. Si era la última de todas, `fin`.
  void _avanzar() {
    final e = actual;
    if (serie < e.series) {
      serie++;
      _preparar(desdeUltima: true);
      return;
    }
    // Terminó el ejercicio: su esfuerzo se puede anotar (opcional).
    esfuerzoPendiente = idx;
    _serieDelEsfuerzo = _hechas.last.id;
    if (idx + 1 < _ejercicios.length) {
      idx++;
      serie = 1;
      _preparar();
    } else {
      fase = FaseSesion.fin;
    }
  }

  /// Quita la última serie guardada y vuelve a esa serie.
  Future<void> deshacer() async {
    final u = ultima;
    if (u == null) return;
    await servicio.deshacerSerie(u.id);
    _hechas.removeWhere((s) => s.id == u.id);
    ultima = null;
    _deshacerHasta = null;
    _horaDeSerie.remove(u.id);
    _descansoDe.remove(u.id);
    esfuerzoPendiente = null;
    _serieDelEsfuerzo = null;
    idx = u.ejercicio;
    serie = u.n;
    fase = FaseSesion.serie;
    reps = u.reps;
    cargaPasos = u.cargaPasos;
    banda = u.bandaId == null ? null : PasoBanda(u.bandaId!);
    descanso = null;
    _finUltimaSerie = null;
    _finDescanso = null;
    _inicioSerie = _ahora();
    await avisos?.alCambiarDescanso(null);
    notifyListeners();
  }

  /// El esfuerzo (1 a 5) del ejercicio que acaba de terminar, o `null` para
  /// omitirlo.
  Future<void> esfuerzoDelEjercicio(int? valor) async {
    final id = _serieDelEsfuerzo;
    esfuerzoPendiente = null;
    _serieDelEsfuerzo = null;
    if (valor != null && id != null) {
      await servicio.esfuerzoDeSerie(id, valor);
    }
    notifyListeners();
  }

  // --------------------------------------------------------------- descanso

  Future<void> _cambiarDescanso(DescansoPlanificado d) async {
    descanso = d;
    notifyListeners();
    await avisos?.alCambiarDescanso(
      d.haTerminado(_ahora()) ? null : d.instanteFinal,
    );
  }

  Future<void> masQuince() async {
    if (descanso != null) {
      await _cambiarDescanso(
        descanso!.ajustar(const Duration(seconds: 15), _ahora()),
      );
    }
  }

  Future<void> menosQuince() async {
    if (descanso != null) {
      await _cambiarDescanso(
        descanso!.ajustar(const Duration(seconds: -15), _ahora()),
      );
    }
  }

  Future<void> saltarDescanso() async {
    if (descanso != null) {
      await _cambiarDescanso(descanso!.saltar(_ahora()));
    }
  }

  // ------------------------------------------------------ cambiar ejercicio

  /// Cambia el ejercicio en curso por una alternativa del slot (F-E7). Solo
  /// vale para esta sesión: el plan no cambia (5.10).
  Future<void> cambiarEjercicio(
    AlternativaSlot alt, {
    MotivoCambioLocal? motivo,
  }) async {
    _motivoCambio =
        motivo ??
        switch (alt.motivo) {
          MotivoAlternativa.sinAparato => MotivoCambioLocal.noDisponible,
          MotivoAlternativa.conPrecaucion => MotivoCambioLocal.molestia,
          _ => MotivoCambioLocal.preferencia,
        };
    _ejercicios[idx] = _conVariante(actual, alt.varianteId);
    _preparar(desdeUltima: false);
    notifyListeners();
  }

  EjercicioPlanificado _conVariante(EjercicioPlanificado e, String varianteId) {
    final ej = servicio.catalogo.ejercicioDeVariante(varianteId)!;
    final v = servicio.catalogo.variante(varianteId)!;
    // La última carga que la persona hizo con esa variante, si la hay.
    int? carga;
    String? bandaId;
    for (final s in datos.historial.reversed) {
      for (final x in s.series.reversed) {
        if (x.varianteId == varianteId) {
          carga ??= x.cargaPasos;
          bandaId ??= x.bandaId;
        }
      }
      if (carga != null || bandaId != null) break;
    }
    return EjercicioPlanificado(
      slotId: e.slotId,
      ejercicioId: ej.id,
      varianteId: varianteId,
      series: e.series,
      rangoMin: e.rangoMin,
      rangoMax: e.rangoMax,
      objetivo: e.objetivo,
      porTiempo: ej.esDeTiempo,
      porLado: ej.porLado,
      descansoS: e.descansoS,
      tempoBajadaS: e.tempoBajadaS,
      motivo: MotivoProgresion.primeraVez,
      cargaPasos: v.carga == TipoCarga.pila ? carga : null,
      bandaId: v.carga == TipoCarga.banda ? bandaId : null,
      conPrecaucion: false,
      esExtra: e.esExtra,
      alternativas: [
        for (final a in e.alternativas)
          if (a.varianteId != varianteId) a,
        if (e.varianteId != varianteId)
          AlternativaSlot(e.varianteId, MotivoAlternativa.sinAparato),
      ],
    );
  }

  // ---------------------------------------------------------- versión corta

  /// *Versión corta* en plena sesión: lo que aún no se hizo pierde los extras y
  /// los ejercicios que la versión corta omite, y se queda en 3 series.
  Future<void> acortar() async {
    if (versionCorta) return;
    final plantilla = servicio.catalogo.plantilla(hoy.tipo);
    bool omitible(EjercicioPlanificado e) {
      if (e.esExtra) return true;
      final slot = plantilla?.slots.where((s) => s.id == e.slotId).firstOrNull;
      return slot != null && slot.omitirEnCorta && !slot.esencial;
    }

    for (var i = _ejercicios.length - 1; i > idx; i--) {
      if (hechasDe(i) == 0 && omitible(_ejercicios[i])) {
        _ejercicios.removeAt(i);
      }
    }
    for (var i = idx; i < _ejercicios.length; i++) {
      final e = _ejercicios[i];
      final tope = e.series > 3 ? 3 : e.series;
      final nueva = tope < hechasDe(i) ? hechasDe(i) : tope;
      if (nueva != e.series) {
        _ejercicios[i] = _conSeries(e, nueva);
      }
    }
    if (serie > actual.series) serie = actual.series;
    _versionCorta = true;
    fila = await servicio.repo.guardarSesion(servicio.persona, {
      ...fila.aMapaServidor(),
      'version': 'corta',
      'plan': [for (final p in _resumen()) p.aJson()],
    });
    notifyListeners();
  }

  EjercicioPlanificado _conSeries(EjercicioPlanificado e, int series) =>
      EjercicioPlanificado(
        slotId: e.slotId,
        ejercicioId: e.ejercicioId,
        varianteId: e.varianteId,
        series: series,
        rangoMin: e.rangoMin,
        rangoMax: e.rangoMax,
        objetivo: e.objetivo,
        porTiempo: e.porTiempo,
        porLado: e.porLado,
        descansoS: e.descansoS,
        tempoBajadaS: e.tempoBajadaS,
        motivo: e.motivo,
        cargaPasos: e.cargaPasos,
        bandaId: e.bandaId,
        bandaDoble: e.bandaDoble,
        conPrecaucion: e.conPrecaucion,
        esExtra: e.esExtra,
        topeDePila: e.topeDePila,
        alternativas: e.alternativas,
        aproximacion: e.aproximacion,
      );

  List<PlanEjercicioGuardado> _resumen() => [
    for (final e in _ejercicios)
      PlanEjercicioGuardado(
        ejercicioId: e.ejercicioId,
        varianteId: e.varianteId,
        series: e.series,
        repsMin: e.porTiempo ? null : e.rangoMin,
        repsMax: e.porTiempo ? null : e.rangoMax,
      ),
  ];

  // -------------------------------------------------------------- terminar

  /// Lo medido en esta sesión para calibrar el tiempo estimado, si hay.
  TiemposMedidos? get tiemposMedidos {
    if (_segPorRep.isEmpty && _segCambio.isEmpty) return null;
    const r = ReglasGimnasio();
    return TiemposMedidos(
      segundosPorRepeticion: _segPorRep.isEmpty
          ? r.segundosPorRepeticion
          : mediana(_segPorRep),
      segundosCambio: _segCambio.isEmpty
          ? r.segundosCambio
          : mediana(_segCambio),
    );
  }

  /// «Terminé la sesión» ([completa]) o «Terminé una parte» (PG-13).
  Future<ResultadoSesion> terminar({
    required bool completa,
    int? esfuerzo,
    int? energia,
  }) async {
    await avisos?.cancelar();
    descanso = null;
    return servicio.terminarSesion(
      fila: fila,
      h: hoy,
      completa: completa,
      esfuerzo: esfuerzo,
      energia: energia,
      tiempos: tiemposMedidos,
      plan: _resumen(),
    );
  }

  @override
  void dispose() {
    avisos?.cancelar();
    super.dispose();
  }
}

/// La sesión regenerativa (R1 o R2): sin series, cargas ni récords; solo qué
/// bloques se hicieron (3.5).
class ControladorRegenerativa extends ChangeNotifier {
  ControladorRegenerativa({
    required this.servicio,
    required this.hoy,
    required this.fila,
  });

  final ServicioGimnasio servicio;
  final EntrenamientoHoy hoy;
  final GimSesionFila fila;
  final Set<int> hechos = {};

  List<BloquePlanificadoRegen> get bloques => hoy.regenerativa!.bloques;

  void alternar(int i) {
    if (!hechos.add(i)) hechos.remove(i);
    notifyListeners();
  }

  int get minutosHechos => hechos.fold(0, (a, i) => a + bloques[i].minutos);

  Future<ResultadoSesion> terminar({
    required bool completa,
    int? energia,
  }) {
    // Cada bloque hecho: una línea con sus minutos (sin series ni cargas).
    return servicio.terminarSesion(
      fila: fila,
      h: hoy,
      completa: completa,
      energia: energia,
      plan: [
        for (final i in hechos.toList()..sort())
          PlanEjercicioGuardado(
            ejercicioId: bloques[i].bloqueId,
            varianteId: bloques[i].bloqueId,
            series: 1,
            repsMin: bloques[i].minutos,
            repsMax: bloques[i].minutos,
          ),
      ],
    );
  }
}
