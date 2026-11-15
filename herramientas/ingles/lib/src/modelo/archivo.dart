import '../hallazgo.dart';
import 'estimulo.dart';
import 'formato.dart';
import 'niveles.dart';
import 'pregunta.dart';

enum Estado {
  borrador,
  validado,
  revisado,
  aprobado,
  retirado;

  static Estado? de(String? t) {
    for (final e in values) {
      if (e.name == t) return e;
    }
    return null;
  }

  /// `validado` o más: lo que ya no admite errores.
  bool get exigeLimpio =>
      this == validado || this == revisado || this == aprobado;
}

/// Un archivo de `data/ingles/` ya leído. Siempre se puede preguntar por su
/// `ruta`, `id`, `estado` y `lectura` (los V01 que dejó al leerlo), aunque
/// esté roto: así una falla de formato no esconde al resto.
sealed class Archivo {
  const Archivo({
    required this.ruta,
    required this.id,
    required this.estado,
    required this.lectura,
  });

  /// Ruta relativa a la carpeta validada, para mostrarla.
  final String ruta;
  final String id;
  final Estado? estado;

  /// Hallazgos V01 de la lectura.
  final List<Hallazgo> lectura;

  String get tipo;
}

/// Un archivo que no se pudo leer o cuyo `tipo` no existe: solo cuenta su V01.
class ArchivoIlegible extends Archivo {
  const ArchivoIlegible({
    required super.ruta,
    required super.id,
    required super.estado,
    required super.lectura,
  });
  @override
  String get tipo => 'ilegible';
}

/// Un estímulo con sus preguntas.
class Unidad extends Archivo {
  const Unidad({
    required super.ruta,
    required super.id,
    required super.estado,
    required super.lectura,
    required this.formato,
    required this.parte,
    required this.nivel,
    required this.variante,
    required this.origen,
    required this.estimulo,
    required this.preguntas,
    required this.temas,
    required this.textos,
    required this.opciones,
  });

  final String? formato;
  final String? parte;
  final String? nivel;
  final String? variante;
  final String? origen;
  final Estimulo? estimulo;
  final List<Pregunta> preguntas;
  final List<String> temas;

  /// Textos con id (preguntas de `correspondencia`).
  final List<ElementoConId> textos;

  /// Opciones con id (preguntas de `emparejar`).
  final List<ElementoConId> opciones;

  @override
  String get tipo => 'unidad';
}

/// Un texto u opción con id propio dentro de una unidad.
class ElementoConId {
  const ElementoConId({required this.id, this.texto, this.porqueNo});
  final String id;
  final String? texto;
  final String? porqueNo;
}

class SeccionForma {
  const SeccionForma({required this.parte, required this.unidades});
  final String? parte;
  final List<String> unidades;
}

/// Una prueba: lista ordenada de unidades.
class Forma extends Archivo {
  const Forma({
    required super.ruta,
    required super.id,
    required super.estado,
    required super.lectura,
    required this.formato,
    required this.uso,
    required this.semilla,
    required this.secciones,
  });
  final String? formato;
  final String? uso;
  final int? semilla;
  final List<SeccionForma> secciones;
  @override
  String get tipo => 'forma';
}

class Tarjeta {
  const Tarjeta({required this.id, this.en, this.es, this.ejemplo});
  final String id;
  final String? en;
  final String? es;
  final String? ejemplo;
}

class EjemploLeccion {
  const EjemploLeccion({this.en, this.es});
  final String? en;
  final String? es;
}

class ErrorComun {
  const ErrorComun({this.mal, this.bien, this.porque});
  final String? mal;
  final String? bien;
  final String? porque;
}

sealed class Bloque {
  const Bloque(this.minutos);
  final num? minutos;
  String get tipo;
}

class BloqueRepaso extends Bloque {
  const BloqueRepaso(super.minutos);
  @override
  String get tipo => 'repaso';
}

class BloqueLeccion extends Bloque {
  const BloqueLeccion(
    super.minutos, {
    required this.explicacion,
    required this.ejemplos,
    required this.errorComun,
    required this.preguntas,
  });
  final String? explicacion;
  final List<EjemploLeccion> ejemplos;
  final ErrorComun? errorComun;
  final List<Pregunta> preguntas;
  @override
  String get tipo => 'leccion';
}

class BloquePronunciacion extends Bloque {
  const BloquePronunciacion(super.minutos, {required this.foco, required this.elementos});
  final String? foco;
  final List<ElementoPronunciacion> elementos;
  @override
  String get tipo => 'pronunciacion';
}

class BloqueProduccion extends Bloque {
  const BloqueProduccion(super.minutos, {required this.tarea});
  final Produccion? tarea;
  @override
  String get tipo => 'produccion';
}

class BloqueTraslado extends Bloque {
  const BloqueTraslado(super.minutos, {required this.audios, required this.frases});
  final List<String> audios;
  final List<String> frases;
  @override
  String get tipo => 'traslado';
}

/// Una sesión diaria del curso (60 minutos).
class Sesion extends Archivo {
  const Sesion({
    required super.ruta,
    required super.id,
    required super.estado,
    required super.lectura,
    required this.escalon,
    required this.semana,
    required this.dia,
    required this.enfoque,
    required this.variante,
    required this.titulo,
    required this.puedo,
    required this.temas,
    required this.bloques,
    required this.tarjetas,
  });
  final String? escalon;
  final int? semana;
  final String? dia;
  final String? enfoque;
  final String? variante;
  final String? titulo;
  final String? puedo;
  final List<String> temas;
  final List<Bloque> bloques;
  final List<Tarjeta> tarjetas;

  /// Preguntas de la lección y tarea de producción, en orden.
  List<Pregunta> get preguntas => [
        for (final b in bloques)
          ...[
            if (b is BloqueLeccion) ...b.preguntas,
            if (b is BloqueProduccion && b.tarea != null) b.tarea!,
          ],
      ];

  @override
  String get tipo => 'sesion';
}

/// Contrato de formato (un examen o una plantilla propia).
class ArchivoFormato extends Archivo {
  const ArchivoFormato({
    required super.ruta,
    required super.id,
    required super.estado,
    required super.lectura,
    required this.contrato,
  });
  final Formato contrato;
  @override
  String get tipo => 'formato';
}

/// `data/ingles/niveles.yaml`.
class ArchivoNiveles extends Archivo {
  const ArchivoNiveles({
    required super.ruta,
    required super.id,
    required super.estado,
    required super.lectura,
    required this.niveles,
  });
  final Niveles niveles;
  @override
  String get tipo => 'niveles';
}
