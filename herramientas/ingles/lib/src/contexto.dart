import 'duplicados.dart';
import 'modelo/archivo.dart';
import 'modelo/contrato_sesion.dart';
import 'modelo/formato.dart';
import 'modelo/niveles.dart';
import 'modelo/pregunta.dart';
import 'usos.dart';

/// Todo lo que una comprobación puede necesitar de los demás archivos de la
/// carpeta validada: los contratos, los niveles y los ids de todo el conjunto,
/// y lo que solo se ve en conjunto (repeticiones y usos de las unidades).
class Contexto {
  Contexto(this.archivos) {
    for (final a in archivos) {
      if (a is ArchivoFormato) _contratos.putIfAbsent(a.id, () => a.contrato);
      if (a is ArchivoNiveles) niveles ??= a.niveles;
      _porId.putIfAbsent(a.id, () => a);
      for (final id in idsDe(a)) {
        (_duenos[id] ??= []).add(a);
      }
    }
  }

  final List<Archivo> archivos;

  /// `data/ingles/niveles.yaml`, si existe (el primero que se encuentre).
  Niveles? niveles;

  /// Qué comparte cada unidad o sesión con otras (V19, reglas a y b). Se
  /// calcula la primera vez que se pide y sirve a todos los archivos.
  late final IndiceDuplicados duplicados = IndiceDuplicados(archivos);

  /// En qué formas y sesiones se usa cada unidad (V19, regla c, y V20). Se
  /// calcula la primera vez que se pide.
  late final UsoDeUnidades usos = UsoDeUnidades(archivos);

  /// El contrato `gravity-sesion-60` ya leído, o null si no existe.
  late final ContratoSesion? contratoSesion = () {
    final f = _contratos[idContratoSesion];
    return f == null ? null : ContratoSesion(f);
  }();

  final Map<String, Formato> _contratos = {};
  final Map<String, Archivo> _porId = {};
  final Map<String, List<Archivo>> _duenos = {};

  /// Contrato con ese id, o null si no existe ("sin contrato").
  Formato? contrato(String? id) => id == null ? null : _contratos[id];

  /// Archivo cuyo id (de archivo, no de pregunta) es este.
  Archivo? archivo(String id) => _porId[id];

  /// Los archivos que declaran este id (de archivo, de pregunta o de
  /// tarjeta); más de uno es un duplicado.
  List<Archivo> duenosDe(String id) => _duenos[id] ?? const [];

  /// Parte del contrato a la que pertenece la unidad, o null.
  Parte? parteDe(Unidad u) => contrato(u.formato)?.parte(u.parte);

  /// Unidades del mismo formato y parte, ordenadas por id.
  List<Unidad> unidadesDeParte(String? formato, String? parte) => [
        for (final a in archivos)
          if (a is Unidad && a.formato == formato && a.parte == parte) a,
      ]..sort((x, y) => x.id.compareTo(y.id));
}

/// Los ids que declara un archivo: el suyo, los de sus preguntas y los de sus
/// tarjetas. Todos deben ser únicos en todo `data/ingles` (V02).
List<String> idsDe(Archivo a) => [
      a.id,
      for (final q in preguntasDe(a)) q.id,
      if (a is Sesion) for (final t in a.tarjetas) t.id,
    ];

/// Las preguntas de un archivo (de una unidad o de una sesión).
List<Pregunta> preguntasDe(Archivo a) => switch (a) {
      Unidad() => a.preguntas,
      Sesion() => a.preguntas,
      _ => const [],
    };
