/// Hábitos a eliminar (cigarrillo y azúcar), reglas 28 a 57. **Todo vive en
/// el documento cifrado de `habitos_sensibles`**; el estado se calcula en el
/// dispositivo con el dominio.
library;

import 'package:habitos_dominio/habitos_dominio.dart';
import 'package:uuid/uuid.dart';

import '../../../nucleo/sensibles/llaves_habitos.dart' show TipoSensible;
import '../datos/documentos_sensibles.dart';

const _t = TipoSensible.habitosSensibles;
const _claveConfig = 'config';

enum TipoHabito { cigarrillo, azucar }

/// Configuración de un hábito a eliminar (se guarda cifrada).
class ConfigHabito {
  const ConfigHabito({
    required this.tipo,
    required this.inicio,
    this.diaD,
    this.lineaBaseDias = 7,
    this.porcentajes = const [25, 50, 75],
    this.focoDias = 14,
    this.limiteOcasional,
    this.periodoSemana = false,
    this.precioCajetillaCentavos,
    this.cigarrillosPorCajetilla = 20,
    this.mostrarAhorro = false,
    this.motivos = const [],
  });

  final TipoHabito tipo;
  final DateTime inicio;
  final DateTime? diaD;
  final int lineaBaseDias;
  final List<int> porcentajes;
  final int focoDias;
  final int? limiteOcasional; // azúcar: nulo = la app lo pregunta
  final bool periodoSemana; // azúcar: semana o mes
  final int? precioCajetillaCentavos;
  final int cigarrillosPorCajetilla;
  final bool mostrarAhorro;
  final List<String> motivos;

  PlanCigarrillo get plan => PlanCigarrillo(
        inicio: inicio,
        diaD: diaD,
        lineaBaseDias: lineaBaseDias,
        porcentajes: porcentajes,
        focoDias: focoDias,
      );

  Map<String, Object?> aDatos() => {
        'tipo': tipo.name,
        'inicio': inicio.toIso8601String(),
        'dia_d': diaD?.toIso8601String(),
        'linea_base_dias': lineaBaseDias,
        'porcentajes': porcentajes,
        'foco_dias': focoDias,
        'limite_ocasional': limiteOcasional,
        'periodo_semana': periodoSemana,
        'precio_cajetilla': precioCajetillaCentavos,
        'cig_por_cajetilla': cigarrillosPorCajetilla,
        'mostrar_ahorro': mostrarAhorro,
        'motivos': motivos,
      };

  static ConfigHabito deDatos(Map<String, Object?> d) => ConfigHabito(
        tipo: TipoHabito.values.byName(d['tipo']! as String),
        inicio: DateTime.parse(d['inicio']! as String),
        diaD: d['dia_d'] == null ? null : DateTime.parse(d['dia_d']! as String),
        lineaBaseDias: d['linea_base_dias']! as int,
        porcentajes: (d['porcentajes']! as List).cast<int>(),
        focoDias: d['foco_dias']! as int,
        limiteOcasional: d['limite_ocasional'] as int?,
        periodoSemana: d['periodo_semana']! as bool,
        precioCajetillaCentavos: d['precio_cajetilla'] as int?,
        cigarrillosPorCajetilla: d['cig_por_cajetilla']! as int,
        mostrarAhorro: d['mostrar_ahorro']! as bool,
        motivos: (d['motivos']! as List).cast<String>(),
      );
}

/// Lo que muestra el panel hoy.
class EstadoHabito {
  const EstadoHabito({
    required this.fase,
    required this.hoy,
    this.limite,
    this.promedioCentesimas,
    this.racha,
    this.recaidaHoy = false,
    this.semaforo,
    this.usadasPeriodo = 0,
    this.ahorroCentavos,
    this.diasParaDiaD,
    this.enFoco = false,
    this.sugerirApoyo = false,
    this.superoLimite = false,
  });
  final FaseHabito fase;
  final int hoy;
  final int? limite;
  final int? promedioCentesimas;
  final RachaLibre? racha;
  final bool recaidaHoy;
  final SemaforoHabito? semaforo;
  final int usadasPeriodo;
  final int? ahorroCentavos;
  final int? diasParaDiaD;
  final bool enFoco;
  final bool sugerirApoyo;
  final bool superoLimite;
}

class ServicioHabitoEliminar {
  ServicioHabitoEliminar(this._docs, {DateTime Function()? ahora})
      : _ahora = ahora ?? DateTime.now;

  final DocumentosSensibles _docs;
  final DateTime Function() _ahora;
  DateTime get hoy => soloDia(_ahora());

  Future<void> configurar(ConfigHabito c) => _docs.poner(
      _t,
      _claveConfig,
      ElementoDoc(
          id: 'habito:${c.tipo.name}',
          clase: 'habito',
          modificadoEn: _ahora().millisecondsSinceEpoch,
          datos: c.aDatos()));

  Future<ConfigHabito?> config(TipoHabito t) async {
    final e = (await _docs.leer(_t, _claveConfig)).elementos['habito:${t.name}'];
    return e == null || e.eliminado ? null : ConfigHabito.deDatos(e.datos);
  }

  /// Registro en un toque (regla 39). Devuelve el id para Deshacer.
  Future<String> registrarConsumo(TipoHabito t,
      {int? horaMin, DateTime? fecha, String? categoria, String? ocasion}) async {
    final f = soloDia(fecha ?? hoy);
    final n = _ahora();
    final id = const Uuid().v4();
    await _docs.poner(
        _t,
        claveDia(f),
        ElementoDoc(
            id: id,
            clase: 'consumo',
            modificadoEn: n.millisecondsSinceEpoch,
            datos: {
              'habito': t.name,
              'hora_min': horaMin ?? n.hour * 60 + n.minute,
              'categoria': categoria,
              'ocasion': ocasion,
            }));
    return id;
  }

  Future<void> deshacerConsumo(String id, {DateTime? fecha}) =>
      _docs.quitar(_t, claveDia(fecha ?? hoy), id);

  /// *Cero hoy*: cierre explícito del día (regla 30).
  Future<void> cerrarDia(TipoHabito t, {DateTime? fecha}) {
    final f = soloDia(fecha ?? hoy);
    return _docs.poner(
        _t,
        claveDia(f),
        ElementoDoc(
            id: 'cierre:${t.name}',
            clase: 'cierre',
            modificadoEn: _ahora().millisecondsSinceEpoch,
            datos: {'habito': t.name}));
  }

  /// Guarda el antojo del SOS (regla 59).
  Future<void> guardarAntojo(TipoHabito t,
      {required ResultadoAntojo resultado,
      String? tecnica,
      int? intensidad,
      String? disparador}) {
    final n = _ahora();
    return _docs.poner(
        _t,
        claveDia(hoy),
        ElementoDoc(
            id: const Uuid().v4(),
            clase: 'antojo',
            modificadoEn: n.millisecondsSinceEpoch,
            datos: {
              'habito': t.name,
              'hora_min': n.hour * 60 + n.minute,
              'resultado': resultado.name,
              'tecnica': tecnica,
              'intensidad': intensidad,
              'disparador': disparador,
            }));
  }

  Future<int> antojosSuperados(TipoHabito t, {int dias = 30}) async {
    var n = 0;
    for (var i = 0; i < dias; i++) {
      for (final e in await _docs.vivos(_t, claveDia(sumarDias(hoy, -i)), 'antojo')) {
        if (e.datos['habito'] == t.name && e.datos['resultado'] == 'superado') n++;
      }
    }
    return n;
  }

  /// Cuenta de consumos y días con datos desde [desde] hasta hoy.
  Future<(Map<DateTime, int>, Set<DateTime>)> _consumos(
      TipoHabito t, DateTime desde, {String? categoria}) async {
    final cuenta = <DateTime, int>{};
    final conDatos = <DateTime>{};
    for (var d = soloDia(desde); !d.isAfter(hoy); d = sumarDias(d, 1)) {
      final doc = await _docs.leer(_t, claveDia(d));
      for (final e in doc.elementos.values) {
        if (e.eliminado || e.datos['habito'] != t.name) continue;
        if (e.clase == 'consumo') {
          if (categoria == null || e.datos['categoria'] == categoria) {
            cuenta[d] = (cuenta[d] ?? 0) + 1;
          }
          conDatos.add(d);
        } else if (e.clase == 'cierre') {
          conDatos.add(d);
        }
      }
    }
    return (cuenta, conDatos);
  }

  /// Estado de hoy (reglas 30 a 49).
  Future<EstadoHabito?> estado(TipoHabito t) async {
    final c = await config(t);
    if (c == null) return null;
    return t == TipoHabito.cigarrillo ? _cigarrillo(c) : _azucar(c);
  }

  Future<EstadoHabito> _cigarrillo(ConfigHabito c) async {
    final plan = c.plan;
    final (cuenta, conDatos) = await _consumos(TipoHabito.cigarrillo, c.inicio);
    final hoyN = cuenta[hoy] ?? 0;
    final finBase = sumarDias(c.inicio, c.lineaBaseDias);
    final base = <int>[
      for (final d in conDatos)
        if (!d.isBefore(c.inicio) && d.isBefore(finBase)) cuenta[d] ?? 0
    ];
    final prom = promedioLineaBase(base);
    final fase = plan.fase(hoy);
    final limite = prom == null ? null : plan.limiteDelDia(hoy, prom);
    final desdeD = !hoy.isBefore(plan.diaD);
    final racha = desdeD
        ? calcularRachaLibre(diaD: plan.diaD, hoy: hoy, consumoPorDia: cuenta)
        : null;
    final recaidas = desdeD ? diasDeRecaida(plan.diaD, cuenta) : <DateTime>[];
    int? ahorro;
    if (c.mostrarAhorro && c.precioCajetillaCentavos != null && prom != null) {
      ahorro = ahorroTotal(
        finLineaBase: finBase,
        consumoDiasConDatos: {for (final d in conDatos) d: cuenta[d] ?? 0},
        promedioCentesimas: prom,
        precioCajetillaCentavos: c.precioCajetillaCentavos!,
        cigarrillosPorCajetilla: c.cigarrillosPorCajetilla,
      );
    }
    return EstadoHabito(
      fase: fase,
      hoy: hoyN,
      limite: limite,
      promedioCentesimas: prom,
      racha: racha,
      recaidaHoy: desdeD && hoyN > 0,
      ahorroCentavos: ahorro,
      diasParaDiaD: hoy.isBefore(plan.diaD) ? diasEntre(hoy, plan.diaD) : null,
      enFoco: plan.enFoco(hoy),
      sugerirApoyo: sugerirApoyo(recaidas, hoy),
      superoLimite: limite != null && hoyN > limite,
    );
  }

  Future<EstadoHabito> _azucar(ConfigHabito c) async {
    final desde = c.periodoSemana ? lunesDe(hoy) : DateTime.utc(hoy.year, hoy.month, 1);
    final (cuenta, _) = await _consumos(TipoHabito.azucar, desde, categoria: 'refresco');
    final usadas = cuenta.values.fold<int>(0, (a, b) => a + b);
    final lim = c.limiteOcasional;
    final fase = soloDia(c.inicio).isAfter(hoy)
        ? FaseHabito.noIniciado
        : (diasEntre(c.inicio, hoy) < c.lineaBaseDias
            ? FaseHabito.lineaBase
            : FaseHabito.mantenimiento);
    return EstadoHabito(
      fase: fase,
      hoy: (await _consumos(TipoHabito.azucar, hoy)).$1[hoy] ?? 0,
      semaforo: fase == FaseHabito.lineaBase || lim == null ? null : semaforoAzucar(usadas, lim),
      usadasPeriodo: usadas,
      limite: lim,
    );
  }
}
