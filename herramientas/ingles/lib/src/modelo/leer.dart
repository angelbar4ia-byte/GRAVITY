import 'package:yaml/yaml.dart';

import 'archivo.dart';
import 'estimulo.dart';
import 'formato.dart';
import 'lector.dart';
import 'listas.dart';
import 'niveles.dart';
import 'pregunta.dart';

/// Lee el texto de un archivo YAML. Si no es YAML o no es un archivo del
/// formato, devuelve un [ArchivoIlegible] con su V01.
Archivo leerTexto(String ruta, String contenido) {
  final Object? plano;
  try {
    plano = aPlano(loadYaml(contenido));
  } on YamlException catch (e) {
    return _ilegible(ruta, 'YAML ilegible: ${e.message}');
  }
  if (plano is! Map<String, Object?>) {
    return _ilegible(ruta, 'el archivo debe ser un bloque con campos');
  }
  return leerMapa(ruta, plano);
}

ArchivoIlegible _ilegible(String ruta, String mensaje) {
  final l = Lector(ruta, ruta)..error('', mensaje);
  return ArchivoIlegible(ruta: ruta, id: ruta, estado: null, lectura: l.hallazgos);
}

/// Lee un archivo ya convertido a mapas y listas de Dart.
Archivo leerMapa(String ruta, Map<String, Object?> datos) {
  final crudoId = datos['id'];
  final idLeido = crudoId is String && crudoId.isNotEmpty ? crudoId : ruta;
  final l = Lector(ruta, idLeido);
  final raiz = Vista(l, datos, '', idLeido);

  final esquema = raiz.texto('esquema');
  if (esquema != null && esquema != 'gravity-ingles-v1') {
    l.error('esquema', 'debe ser gravity-ingles-v1, no "$esquema"');
  }
  final tipo = raiz.texto('tipo', en: tiposArchivo);
  raiz.texto('id');
  if (crudoId is String && !patronId.hasMatch(crudoId)) {
    l.error('id', 'el id "$crudoId" debe llevar solo minúsculas, dígitos y guiones');
  }
  final estadoTexto = raiz.texto('estado', en: estados);
  final estado = Estado.de(estadoTexto);

  switch (tipo) {
    case 'unidad':
      return _leerUnidad(raiz, ruta, idLeido, estado);
    case 'forma':
      return _leerForma(raiz, ruta, idLeido, estado);
    case 'sesion':
      return _leerSesion(raiz, ruta, idLeido, estado);
    case 'formato':
      final c = leerFormato(raiz, idLeido);
      return ArchivoFormato(ruta: ruta, id: idLeido, estado: estado, lectura: l.hallazgos, contrato: c);
    case 'niveles':
      final n = leerNiveles(raiz);
      return ArchivoNiveles(ruta: ruta, id: idLeido, estado: estado, lectura: l.hallazgos, niveles: n);
  }
  return ArchivoIlegible(ruta: ruta, id: idLeido, estado: estado, lectura: l.hallazgos);
}

Estimulo? _leerEstimulo(Vista u) {
  final e = u.mapa('estimulo');
  if (e == null) return null;
  final tipo = e.texto('tipo', en: tiposEstimulo);
  if (tipo == null) return null;
  switch (tipo) {
    case 'texto':
      return Estimulo(
        tipo: tipo,
        titulo: e.texto('titulo', requerido: false),
        texto: e.texto('texto'),
      );
    case 'consigna':
      return Estimulo(tipo: tipo, texto: e.texto('texto'));
    case 'imagen':
      return Estimulo(
        tipo: tipo,
        descripcion: e.texto('descripcion'),
        archivo: e.texto('archivo', requerido: false),
      );
    case 'audio':
      final guion = <Turno>[];
      for (final t in e.mapas('guion', noVacia: true)) {
        final voz = t.texto('voz', en: voces);
        final texto = t.texto('texto');
        if (voz != null && texto != null) guion.add(Turno(voz: voz, texto: texto));
      }
      return Estimulo(
        tipo: tipo,
        titulo: e.texto('titulo', requerido: false),
        guion: guion,
        reproducciones: e.entero('reproducciones', requerido: true),
      );
  }
  return Estimulo(tipo: tipo, titulo: e.texto('titulo', requerido: false));
}

List<ElementoConId> _elementosConId(Vista u, String k) {
  final salida = <ElementoConId>[];
  for (final e in u.mapas(k, requerido: false)) {
    final id = e.texto('id');
    if (id == null) continue;
    salida.add(ElementoConId(
      id: id,
      texto: e.texto('texto'),
      porqueNo: e.texto('porque_no', requerido: false),
    ));
  }
  return salida;
}

List<Pregunta> _leerPreguntas(Vista v, String k) {
  final salida = <Pregunta>[];
  for (final p in v.mapas(k)) {
    final q = leerPregunta(p);
    if (q != null) salida.add(q);
  }
  return salida;
}

Unidad _leerUnidad(Vista u, String ruta, String id, Estado? estado) {
  final formato = u.texto('formato');
  final parte = u.texto('parte');
  final nivel = u.texto('nivel', en: etapas);
  final variante = u.texto('variante', en: variantes);
  final origen = u.texto('origen');
  if (origen != null && origen != 'nuevo' && !origen.startsWith('migrado:')) {
    u.lector.error('origen', 'debe ser "nuevo" o "migrado:<archivo.md>"');
  }
  final estimulo = _leerEstimulo(u);
  final preguntas = _leerPreguntas(u, 'preguntas');
  return Unidad(
    ruta: ruta,
    id: id,
    estado: estado,
    lectura: u.lector.hallazgos,
    formato: formato,
    parte: parte,
    nivel: nivel,
    variante: variante,
    origen: origen,
    estimulo: estimulo,
    preguntas: preguntas,
    temas: u.textos('temas', requerido: false),
    textos: _elementosConId(u, 'textos'),
    opciones: _elementosConId(u, 'opciones'),
  );
}

Forma _leerForma(Vista v, String ruta, String id, Estado? estado) {
  final formato = v.texto('formato');
  final uso = v.texto('uso', en: usosForma);
  final semilla = v.entero('semilla', requerido: true);
  final secciones = <SeccionForma>[];
  for (final s in v.mapas('secciones', noVacia: true)) {
    secciones.add(SeccionForma(
      parte: s.texto('parte'),
      unidades: s.textos('unidades', noVacia: true),
    ));
  }
  return Forma(
    ruta: ruta,
    id: id,
    estado: estado,
    lectura: v.lector.hallazgos,
    formato: formato,
    uso: uso,
    semilla: semilla,
    secciones: secciones,
  );
}

Bloque? _leerBloque(Vista b, String sesionId) {
  final tipo = b.texto('tipo', en: tiposBloque);
  final minutos = b.numero('minutos', requerido: true);
  switch (tipo) {
    case 'repaso':
      return BloqueRepaso(minutos);
    case 'leccion':
      final ejemplos = [
        for (final e in b.mapas('ejemplos', requerido: false))
          EjemploLeccion(
            en: e.texto('en'),
            es: e.texto('es'),
          ),
      ];
      final ec = b.mapa('error_comun', requerido: false);
      return BloqueLeccion(
        minutos,
        explicacion: b.texto('explicacion'),
        ejemplos: ejemplos,
        errorComun: ec == null
            ? null
            : ErrorComun(
                mal: ec.texto('mal'),
                bien: ec.texto('bien'),
                porque: ec.texto('porque', requerido: false),
              ),
        preguntas: _leerPreguntas(b, 'preguntas'),
      );
    case 'pronunciacion':
      return BloquePronunciacion(
        minutos,
        foco: b.texto('foco'),
        elementos: leerElementos(b, 'elementos'),
      );
    case 'produccion':
      final t = b.mapa('tarea');
      Produccion? tarea;
      if (t != null) {
        final crudo = t.datos['id'];
        final tid = crudo is String && crudo.isNotEmpty ? crudo : sesionId;
        final q = leerPregunta(t);
        if (q is Produccion) {
          tarea = q;
        } else if (q != null) {
          t.lector.error(t.ruta, 'la tarea de producción debe ser una pregunta de tipo produccion', id: tid);
        }
      }
      return BloqueProduccion(minutos, tarea: tarea);
    case 'traslado':
      return BloqueTraslado(
        minutos,
        audios: b.textos('audios', noVacia: true),
        frases: b.textos('frases', noVacia: true),
      );
  }
  return null;
}

Sesion _leerSesion(Vista v, String ruta, String id, Estado? estado) {
  final escalon = v.texto('escalon');
  final semana = v.entero('semana', requerido: true);
  final dia = v.texto('dia', en: diasSemana);
  final enfoque = v.texto('enfoque');
  final variante = v.texto('variante', requerido: false, en: variantes);
  final titulo = v.texto('titulo');
  final puedo = v.texto('puedo');
  final temas = v.textos('temas');
  final bloques = <Bloque>[];
  for (final b in v.mapas('bloques', noVacia: true)) {
    final bloque = _leerBloque(b, id);
    if (bloque != null) bloques.add(bloque);
  }
  final tarjetas = <Tarjeta>[];
  for (final t in v.mapas('tarjetas')) {
    final tid = t.texto('id');
    if (tid == null) continue;
    tarjetas.add(Tarjeta(
      id: tid,
      en: t.texto('en'),
      es: t.texto('es'),
      ejemplo: t.texto('ejemplo'),
    ));
  }
  return Sesion(
    ruta: ruta,
    id: id,
    estado: estado,
    lectura: v.lector.hallazgos,
    escalon: escalon,
    semana: semana,
    dia: dia,
    enfoque: enfoque,
    variante: variante,
    titulo: titulo,
    puedo: puedo,
    temas: temas,
    bloques: bloques,
    tarjetas: tarjetas,
  );
}
