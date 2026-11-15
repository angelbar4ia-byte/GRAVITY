import 'lector.dart';
import 'listas.dart';

/// Un rango con extremos opcionales (`{min, max}`).
class Rango {
  const Rango({this.min, this.max, this.origen});
  final num? min;
  final num? max;

  /// `declarado` (la cifra la da el manual) o `medido` (se contó en su prueba).
  final String? origen;
}

/// Regla `ocultar` de `completar_palabras` (formato, sección 4.2).
class ReglaOcultar {
  const ReglaOcultar({required this.regla, required this.pendiente});
  final String? regla;
  final bool pendiente;
}

/// Una parte de una sección del contrato (formato, sección 6.1).
class Parte {
  const Parte({
    required this.id,
    this.tarea,
    this.tipoPregunta,
    this.tipoEstimulo,
    this.modalidad,
    this.unidades,
    this.preguntasPorUnidad,
    this.preguntasTotal,
    this.opciones,
    this.reproducciones,
    this.puntosPorPregunta,
    this.palabrasEstimulo,
    this.palabrasRespuesta,
    this.paginaManual,
    this.pendiente = false,
    this.ocultar,
    this.nota,
  });

  final String id;
  final String? tarea;
  final String? tipoPregunta;
  final String? tipoEstimulo;
  final String? modalidad;
  final int? unidades;

  /// Un número fijo o un rango (Parte 7 de TOEIC).
  final Rango? preguntasPorUnidad;
  final Rango? preguntasTotal;
  final int? opciones;
  final int? reproducciones;
  
  /// Un número o un rango (TOEIC Speaking y Writing: de 0 a 3).
  final Rango? puntosPorPregunta;
  final Rango? palabrasEstimulo;
  final Rango? palabrasRespuesta;
  final int? paginaManual;

  /// `pendiente: true`: el manual no da el dato. Un dato pendiente no decide nada.
  final bool pendiente;
  final ReglaOcultar? ocultar;
  final String? nota;
}

class Seccion {
  const Seccion({required this.id, required this.partes});
  final String id;
  final List<Parte> partes;
}

/// El contrato de un examen o de una plantilla propia.
class Formato {
  const Formato({
    required this.id,
    required this.nombre,
    required this.variante,
    required this.secciones,
    required this.datos,
  });
  final String id;
  final String? nombre;
  final String? variante;
  final List<Seccion> secciones;

  /// Todo el contenido tal como se leyó, para lo que P1.2b y P1.2c necesiten
  /// (mínimos de sesión, `totales`, minutos).
  final Map<String, Object?> datos;

  Parte? parte(String? id) {
    if (id == null) return null;
    for (final s in secciones) {
      for (final p in s.partes) {
        if (p.id == id) return p;
      }
    }
    return null;
  }
}

/// Número fijo o `{min, max}`.
Rango? _rangoOEntero(Vista v, String k) {
  final crudo = v.datos[k];
  if (crudo == null) return null;
  if (crudo is num) return Rango(min: crudo, max: crudo);
  final m = v.mapa(k, requerido: false);
  if (m == null) return null;
  return Rango(min: m.numero('min'), max: m.numero('max'), origen: m.texto('origen', requerido: false));
}

Parte? _leerParte(Vista p, Set<String> vistas) {
  final id = p.texto('id');
  if (id == null) return null;
  if (!vistas.add(id)) p.lector.error('${p.ruta}.id', 'la parte "$id" está repetida en el contrato');
  final tipoPregunta = p.texto('tipo_pregunta', requerido: false, en: tiposPregunta);
  final tipoEstimulo = p.texto('tipo_estimulo', requerido: false, en: tiposEstimulo);
  final ocultar = p.mapa('ocultar', requerido: false);
  return Parte(
    id: id,
    tarea: p.texto('tarea', requerido: false),
    tipoPregunta: tipoPregunta,
    tipoEstimulo: tipoEstimulo,
    modalidad: p.texto('modalidad', requerido: false, en: modalidades),
    unidades: p.entero('unidades'),
    preguntasPorUnidad: _rangoOEntero(p, 'preguntas_por_unidad'),
    preguntasTotal: _rangoOEntero(p, 'preguntas_total'),
    opciones: p.entero('opciones'),
    reproducciones: p.entero('reproducciones'),
    puntosPorPregunta: _rangoOEntero(p, 'puntos_por_pregunta'),
    palabrasEstimulo: _rangoOEntero(p, 'palabras_estimulo'),
    palabrasRespuesta: _rangoOEntero(p, 'palabras_respuesta'),
    paginaManual: p.entero('pagina_manual'),
    pendiente: p.booleano('pendiente') ?? false,
    ocultar: ocultar == null
        ? null
        : ReglaOcultar(
            regla: ocultar.texto('regla', requerido: false),
            pendiente: ocultar.booleano('pendiente') ?? false,
          ),
    nota: p.texto('nota', requerido: false),
  );
}

/// Lee el cuerpo de un archivo `tipo: formato`.
Formato leerFormato(Vista v, String id) {
  v.texto('nombre');
  final f = v.mapa('fuente');
  f?.texto('titulo');
  f?.texto('url');
  final variante = v.texto('variante', en: variantes);
  v.texto('idioma_instrucciones', requerido: false);
  final secciones = <Seccion>[];
  final vistas = <String>{};
  final vistasSeccion = <String>{};
  for (final s in v.mapas('secciones', noVacia: true)) {
    final sid = s.texto('id');
    if (sid == null) continue;
    if (!vistasSeccion.add(sid)) s.lector.error('${s.ruta}.id', 'la sección "$sid" está repetida');
    final partes = <Parte>[];
    for (final p in s.mapas('partes', noVacia: true)) {
      final parte = _leerParte(p, vistas);
      if (parte != null) partes.add(parte);
    }
    secciones.add(Seccion(id: sid, partes: partes));
  }
  return Formato(
    id: id,
    nombre: v.datos['nombre'] is String ? v.datos['nombre']! as String : null,
    variante: variante,
    secciones: secciones,
    datos: v.datos,
  );
}
