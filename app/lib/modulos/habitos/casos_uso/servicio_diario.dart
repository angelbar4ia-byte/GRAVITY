/// Diario espiritual (`diario_oracion`, sensible): peticiones, devocionales,
/// sesiones de oración y notas del lector (reglas 84 a 86). Todo cifrado.
library;

import 'package:habitos_dominio/habitos_dominio.dart';
import 'package:uuid/uuid.dart';

import '../../../nucleo/sensibles/llaves_habitos.dart' show TipoSensible;
import '../datos/documentos_sensibles.dart';

const _t = TipoSensible.diarioOracion;

enum EstadoPeticion { pendiente, enEspera, respondida }

class Peticion {
  const Peticion(this.id, this.texto, this.estado, this.creada, {this.categoria, this.respondida, this.nota});
  final String id;
  final String texto;
  final EstadoPeticion estado;
  final DateTime creada;
  final String? categoria;
  final DateTime? respondida;
  final String? nota;
}

class EntradaDevocional {
  const EntradaDevocional(this.id, this.fecha, this.pasaje, this.reflexion, this.aplicacion, this.oracion, this.breve);
  final String id;
  final DateTime fecha;
  final String? pasaje;
  final String? reflexion;
  final String? aplicacion;
  final String? oracion;
  final bool breve;
}

class ServicioDiario {
  ServicioDiario(this._docs, {DateTime Function()? ahora}) : _ahora = ahora ?? DateTime.now;
  final DocumentosSensibles _docs;
  final DateTime Function() _ahora;
  DateTime get hoy => soloDia(_ahora());
  int get _ms => _ahora().millisecondsSinceEpoch;

  String _clavePeticiones(int anio) => 'peticiones:$anio';

  Future<String> agregarPeticion(String texto, {String? categoria}) async {
    if (texto.trim().isEmpty) throw ArgumentError('Escribe la petición.');
    final id = const Uuid().v4();
    await _docs.poner(_t, _clavePeticiones(hoy.year),
        ElementoDoc(id: id, clase: 'peticion', modificadoEn: _ms, datos: {
          'texto': texto.trim(),
          'estado': EstadoPeticion.pendiente.name,
          'creada': hoy.toIso8601String(),
          'categoria': categoria,
        }));
    return id;
  }

  Future<void> cambiarEstado(Peticion p, EstadoPeticion e, {String? nota}) => _docs.poner(
      _t,
      _clavePeticiones(p.creada.year),
      ElementoDoc(id: p.id, clase: 'peticion', modificadoEn: _ms, datos: {
        'texto': p.texto,
        'estado': e.name,
        'creada': p.creada.toIso8601String(),
        'categoria': p.categoria,
        'respondida': e == EstadoPeticion.respondida ? hoy.toIso8601String() : null,
        'nota': nota ?? p.nota,
      }));

  Future<List<Peticion>> peticiones({int anios = 3}) async {
    final r = <Peticion>[];
    for (var a = hoy.year; a > hoy.year - anios; a--) {
      for (final e in await _docs.vivos(_t, _clavePeticiones(a), 'peticion')) {
        final d = e.datos;
        r.add(Peticion(
          e.id,
          d['texto']! as String,
          EstadoPeticion.values.byName(d['estado']! as String),
          DateTime.parse(d['creada']! as String),
          categoria: d['categoria'] as String?,
          respondida: d['respondida'] == null ? null : DateTime.parse(d['respondida']! as String),
          nota: d['nota'] as String?,
        ));
      }
    }
    return r..sort((a, b) => b.creada.compareTo(a.creada));
  }

  Future<void> guardarDevocional({String? pasaje, String? reflexion, String? aplicacion, String? oracion, bool breve = false, DateTime? fecha}) {
    final f = soloDia(fecha ?? hoy);
    return _docs.poner(_t, claveDia(f),
        ElementoDoc(id: 'devocional', clase: 'devocional', modificadoEn: _ms, datos: {
          'pasaje': pasaje,
          'reflexion': reflexion,
          'aplicacion': aplicacion,
          'oracion': oracion,
          'breve': breve,
        }));
  }

  Future<EntradaDevocional?> devocionalDe(DateTime fecha) async {
    final e = (await _docs.leer(_t, claveDia(fecha))).elementos['devocional'];
    if (e == null || e.eliminado) return null;
    final d = e.datos;
    return EntradaDevocional('devocional', soloDia(fecha), d['pasaje'] as String?, d['reflexion'] as String?,
        d['aplicacion'] as String?, d['oracion'] as String?, (d['breve'] as bool?) ?? false);
  }

  Future<void> registrarOracion(int minutos) => _docs.poner(
      _t,
      claveDia(hoy),
      ElementoDoc(id: const Uuid().v4(), clase: 'sesion_oracion', modificadoEn: _ms, datos: {'minutos': minutos}));

  Future<int> minutosDeOracion(DateTime fecha) async => [
        for (final e in await _docs.vivos(_t, claveDia(fecha), 'sesion_oracion')) e.datos['minutos']! as int
      ].fold<int>(0, (a, b) => a + b);

  /// Nota del lector por referencia (no por versión).
  Future<void> guardarNota(String codigoReferencia, String texto, {String? version}) => _docs.poner(
      _t,
      claveDia(hoy),
      ElementoDoc(id: 'nota:$codigoReferencia', clase: 'nota', modificadoEn: _ms, datos: {
        'referencia': codigoReferencia,
        'texto': texto,
        'version': version,
      }));

  Future<List<Map<String, Object?>>> notasDe(DateTime fecha) async =>
      [for (final e in await _docs.vivos(_t, claveDia(fecha), 'nota')) e.datos];

  /// Respuestas escritas de la revisión semanal (regla 125, paso 3).
  Future<void> guardarRespuestasRevision(DateTime semana, Map<String, String> respuestas) =>
      _docs.poner(
          _t,
          claveDia(hoy),
          ElementoDoc(
              id: 'revision:${soloDia(semana).toIso8601String().substring(0, 10)}',
              clase: 'respuesta_revision',
              modificadoEn: _ms,
              datos: {'semana': soloDia(semana).toIso8601String(), 'respuestas': respuestas}));
}
