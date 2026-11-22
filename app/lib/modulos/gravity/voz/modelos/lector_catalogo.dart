/// Lector y validador del catálogo de voces (spec 4.2.1, criterios 14 y 27).
///
/// El catálogo es la única fuente de lo que la app descarga y carga, así que
/// se valida entero y **de una vez**: si algo no cumple, no entra ningún
/// modelo (la pantalla dice que no hay voces descargables) y la lista de
/// problemas dice dónde. Los mensajes no repiten los valores: solo la ruta del
/// campo (`modelos[0].archivos[1].sha256`).
///
/// Lo que se exige:
/// 1. **Sin secretos (R7).** Ninguna clave se llama `token`, `clave`, `key`,
///    `secret` ni `password`; ningún valor parece una credencial; toda
///    dirección es `https://`, sin usuario, sin parámetros de consulta y sin
///    fragmento.
/// 2. **Sin nulos ni pendientes.** Ningún valor es `null`, `<n>` o
///    "pendiente".
/// 3. **Revisión fija.** `fuente.revision` no es `main`, `latest` ni parecida,
///    y la dirección de cada archivo la lleva en la ruta.
/// 4. **Nombres de archivo** sin `/`, `\` ni `..`.
/// 5. **Huella completa:** `sha256` de 64 hexadecimales en minúscula y `bytes`
///    mayor que cero.
/// 6. **Licencia con atribución** (R11), fuente y fecha de consulta.
///
/// Desviación de 4.2.1 (regla 1, aprobada el 22/nov/2026): `uso` y `rtf`
/// son **opcionales** hasta P3.3, porque salen de medir en el aparato; si
/// están, se validan. Lo mismo `licencia.permite_distribuir_audio`: ausente
/// significa que nadie lo decidió y entonces el modelo no se usa para pregrabar
/// (regla 4).
library;

import 'dart:convert';

import '../tipos.dart';
import 'catalogo.dart';

/// Lo que el validador rechaza. [problemas] nunca trae valores del archivo.
final class CatalogoInvalido implements Exception {
  const CatalogoInvalido(this.problemas);
  final List<String> problemas;

  @override
  String toString() => 'CatalogoInvalido(${problemas.length} problemas)';
}

const esquemaDelCatalogo = 'gravity-voces-v1';

const _familias = {'vits', 'kokoro', 'kitten', 'matcha'};

/// Revisiones que cambian con el tiempo: no son fijas.
const _revisionesMoviles = {
  'main',
  'master',
  'latest',
  'head',
  'trunk',
  'dev',
  'develop',
  'ultima',
  'última',
  'actual',
};

final _soloHex = RegExp(r'^[0-9a-f]{64}$');
final _nombreSeguro = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$');
final _fecha = RegExp(r'^\d{4}-\d{2}-\d{2}$');
final _pendiente = RegExp(
  r'^\s*(<[^>]*>|pendiente|por definir|tbd|todo|n/a|\?+)\s*$',
  caseSensitive: false,
);

/// Palabras que no pueden ser el nombre de un campo (criterio 14).
bool _claveProhibida(String clave) {
  final k = clave.toLowerCase();
  if (k == 'key') return true;
  for (final p in const [
    'token',
    'clave',
    'secret',
    'password',
    'passwd',
    'apikey',
    'api_key',
    'authorization',
    'cookie',
  ]) {
    if (k.contains(p)) return true;
  }
  return false;
}

/// Formas típicas de una credencial pegada por error en un valor.
final _pareceCredencial = RegExp(
  r'eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}|' // JWT
  r'\b(sbp|sb_secret|sb_publishable|ghp|gho|ghs|github_pat|sk|rk|pk)_[A-Za-z0-9_]{12,}|'
  r'\bAKIA[0-9A-Z]{12,}|'
  r'bearer\s+[A-Za-z0-9._-]{12,}|'
  r'(apikey|api_key|access_token|secret)\s*[=:]',
  caseSensitive: false,
);

/// Todos los problemas del catálogo (lista vacía si es válido).
List<String> validarCatalogo(Object? json) {
  final p = <String>[];
  if (json is! Map) {
    return ['raíz: no es un objeto'];
  }
  _recorrer(json, 'raíz', p);
  if (json['esquema'] != esquemaDelCatalogo) {
    p.add('esquema: debe ser $esquemaDelCatalogo');
  }
  final modelos = json['modelos'];
  if (modelos is! List) {
    p.add('modelos: no es una lista');
  } else {
    final ids = <String>{};
    for (var i = 0; i < modelos.length; i++) {
      _validarModelo(modelos[i], 'modelos[$i]', ids, p);
    }
  }
  final paquetes = json['paquetes_audio'];
  if (paquetes != null && paquetes is! List) {
    p.add('paquetes_audio: no es una lista');
  }
  return p;
}

/// Claves prohibidas, valores nulos, pendientes y credenciales, en todo el
/// árbol.
void _recorrer(Object? nodo, String ruta, List<String> p) {
  if (nodo is Map) {
    nodo.forEach((k, v) {
      final nombre = '$k';
      if (_claveProhibida(nombre)) {
        p.add('$ruta.$nombre: un campo no puede llamarse así (sin secretos)');
      }
      _recorrer(v, '$ruta.$nombre', p);
    });
  } else if (nodo is List) {
    for (var i = 0; i < nodo.length; i++) {
      _recorrer(nodo[i], '$ruta[$i]', p);
    }
  } else if (nodo == null) {
    p.add('$ruta: no puede ser nulo');
  } else if (nodo is String) {
    if (_pendiente.hasMatch(nodo)) p.add('$ruta: valor pendiente');
    if (_pareceCredencial.hasMatch(nodo)) {
      p.add('$ruta: parece una credencial');
    }
    if (nodo.toLowerCase().startsWith('http')) _validarDireccion(nodo, ruta, p);
  }
}

/// `https`, con equipo, sin usuario, sin parámetros y sin fragmento.
void _validarDireccion(String texto, String ruta, List<String> p) {
  final uri = Uri.tryParse(texto);
  if (uri == null) {
    p.add('$ruta: dirección no válida');
    return;
  }
  if (uri.scheme != 'https') p.add('$ruta: la dirección debe ser https');
  if (uri.host.isEmpty) p.add('$ruta: la dirección no tiene equipo');
  if (uri.userInfo.isNotEmpty) p.add('$ruta: la dirección lleva usuario');
  if (uri.hasQuery || texto.contains('?')) {
    p.add('$ruta: la dirección lleva parámetros de consulta');
  }
  if (uri.hasFragment || texto.contains('#')) {
    p.add('$ruta: la dirección lleva fragmento');
  }
}

/// `AAAA-MM-DD` que existe en el calendario (Dart acepta el mes 13).
bool _esFechaReal(String texto) {
  if (!_fecha.hasMatch(texto)) return false;
  final a = int.parse(texto.substring(0, 4));
  final m = int.parse(texto.substring(5, 7));
  final d = int.parse(texto.substring(8, 10));
  final fecha = DateTime(a, m, d);
  return fecha.year == a && fecha.month == m && fecha.day == d;
}

String? _texto(Object? v) => v is String && v.trim().isNotEmpty ? v : null;

void _validarModelo(Object? crudo, String r, Set<String> ids, List<String> p) {
  if (crudo is! Map) {
    p.add('$r: no es un objeto');
    return;
  }
  final id = _texto(crudo['id']);
  if (id == null || !_nombreSeguro.hasMatch(id) || id.contains('..')) {
    p.add('$r.id: falta o tiene caracteres no permitidos');
  } else if (!ids.add(id)) {
    p.add('$r.id: repetido');
  }
  if (_texto(crudo['nombre']) == null) p.add('$r.nombre: falta');
  if (!_familias.contains(crudo['familia'])) {
    p.add('$r.familia: no es una de ${_familias.join(', ')}');
  }
  if (_texto(crudo['idioma']) == null) p.add('$r.idioma: falta');

  final variantes = crudo['variantes'];
  final etiquetas = <String>{};
  if (variantes is! List || variantes.isEmpty) {
    p.add('$r.variantes: debe ser una lista con al menos una');
  } else {
    for (var i = 0; i < variantes.length; i++) {
      final v = Variante.deEtiqueta(
        variantes[i] is String ? variantes[i] as String : null,
      );
      if (v == null) {
        p.add('$r.variantes[$i]: variante desconocida');
      } else {
        etiquetas.add(v.etiqueta);
      }
    }
  }

  final sids = <int>{};
  final voces = crudo['voces'];
  if (voces is! List || voces.isEmpty) {
    p.add('$r.voces: debe ser una lista con al menos una voz');
  } else {
    for (var i = 0; i < voces.length; i++) {
      final v = voces[i];
      final rv = '$r.voces[$i]';
      if (v is! Map) {
        p.add('$rv: no es un objeto');
        continue;
      }
      final sid = v['sid'];
      if (sid is! int || sid < 0) {
        p.add('$rv.sid: debe ser un entero desde 0');
      } else if (!sids.add(sid)) {
        p.add('$rv.sid: repetido');
      }
      if (_texto(v['nombre']) == null) p.add('$rv.nombre: falta');
      if (v['genero'] != 'mujer' && v['genero'] != 'hombre') {
        p.add('$rv.genero: debe ser mujer u hombre');
      }
      final variante = v['variante'];
      if (variante is! String || !etiquetas.contains(variante)) {
        p.add('$rv.variante: no está en las variantes del modelo');
      }
      final aprox = v['acento_aproximado'];
      if (aprox != null && aprox is! bool) {
        p.add('$rv.acento_aproximado: debe ser verdadero o falso');
      }
    }
  }

  final sugerida = crudo['asignacion_sugerida'];
  if (sugerida != null) {
    if (sugerida is! Map) {
      p.add('$r.asignacion_sugerida: no es un objeto');
    } else {
      sugerida.forEach((k, v) {
        if (VozDeGuion.deEtiqueta('$k') == null) {
          p.add('$r.asignacion_sugerida.$k: voz de guion desconocida');
        }
        if (v is! int || !sids.contains(v)) {
          p.add('$r.asignacion_sugerida.$k: no es un sid del modelo');
        }
      });
    }
  }

  final revision = _validarFuente(crudo['fuente'], '$r.fuente', p);
  _validarArchivos(
    crudo['archivos'],
    '$r.archivos',
    revision,
    esVits: crudo['familia'] == 'vits',
    p,
  );
  _validarLicencia(crudo['licencia'], '$r.licencia', p);

  final consultado = crudo['consultado'];
  if (consultado is! String || !_esFechaReal(consultado)) {
    p.add('$r.consultado: debe ser una fecha AAAA-MM-DD');
  }
  _validarOpcionales(crudo, r, p);
}

/// Devuelve la revisión fija, o `null` si no es válida.
String? _validarFuente(Object? crudo, String r, List<String> p) {
  if (crudo is! Map) {
    p.add('$r: falta');
    return null;
  }
  if (crudo['url'] is! String || Uri.tryParse(crudo['url'] as String) == null) {
    p.add('$r.url: falta');
  }
  final revision = _texto(crudo['revision']);
  if (revision == null) {
    p.add('$r.revision: falta');
    return null;
  }
  if (_revisionesMoviles.contains(revision.toLowerCase()) ||
      !_nombreSeguro.hasMatch(revision)) {
    p.add('$r.revision: no es una revisión fija');
    return null;
  }
  return revision;
}

void _validarArchivos(
  Object? crudo,
  String r,
  String? revision,
  List<String> p, {
  required bool esVits,
}) {
  if (crudo is! List || crudo.isEmpty) {
    p.add('$r: debe ser una lista con al menos un archivo');
    return;
  }
  final nombres = <String>{};
  final roles = <RolDeArchivo, int>{};
  for (var i = 0; i < crudo.length; i++) {
    final a = crudo[i];
    final ra = '$r[$i]';
    if (a is! Map) {
      p.add('$ra: no es un objeto');
      continue;
    }
    final rol = RolDeArchivo.deCodigo(a['rol']);
    if (rol == null) {
      p.add('$ra.rol: debe ser modelo, tokens o lexicon');
    } else {
      roles[rol] = (roles[rol] ?? 0) + 1;
    }
    final nombre = a['nombre'];
    if (nombre is! String ||
        nombre.isEmpty ||
        nombre.contains('/') ||
        nombre.contains(r'\') ||
        nombre.contains('..') ||
        !_nombreSeguro.hasMatch(nombre)) {
      p.add('$ra.nombre: vacío o con caracteres no permitidos (/, \\, ..)');
    } else if (!nombres.add(nombre)) {
      p.add('$ra.nombre: repetido');
    }
    final bytes = a['bytes'];
    if (bytes is! int || bytes <= 0) {
      p.add('$ra.bytes: debe ser un entero mayor que cero');
    }
    final sha = a['sha256'];
    if (sha is! String || !_soloHex.hasMatch(sha)) {
      p.add('$ra.sha256: debe tener 64 hexadecimales en minúscula');
    }
    final url = a['url'];
    if (url is! String || !url.startsWith('https://')) {
      p.add('$ra.url: debe ser una dirección https');
    } else {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        if (nombre is String && !uri.path.endsWith('/$nombre')) {
          p.add('$ra.url: no termina en el nombre del archivo');
        }
        if (revision != null && !uri.pathSegments.contains(revision)) {
          p.add('$ra.url: no lleva la revisión fija en la ruta');
        }
      }
    }
  }
  if ((roles[RolDeArchivo.modelo] ?? 0) != 1) {
    p.add('$r: debe haber exactamente un archivo con rol modelo');
  }
  if ((roles[RolDeArchivo.tokens] ?? 0) != 1) {
    p.add('$r: debe haber exactamente un archivo con rol tokens');
  }
  if ((roles[RolDeArchivo.lexicon] ?? 0) > 1) {
    p.add('$r: no puede haber más de un lexicón');
  }
  if (esVits && (roles[RolDeArchivo.lexicon] ?? 0) != 1) {
    // Con sherpa_onnx 2.0.x los modelos Piper no funcionan sin lexicón
    // (spec 4.2.5).
    p.add('$r: un modelo vits necesita su lexicón');
  }
}

void _validarLicencia(Object? crudo, String r, List<String> p) {
  if (crudo is! Map) {
    p.add('$r: falta');
    return;
  }
  for (final campo in const ['id', 'origen', 'atribucion', 'texto']) {
    if (_texto(crudo[campo]) == null) p.add('$r.$campo: falta');
  }
  final dist = crudo['permite_distribuir_audio'];
  if (dist != null && dist is! bool) {
    p.add('$r.permite_distribuir_audio: debe ser verdadero o falso');
  }
  final texto = crudo['texto'];
  if (texto is String &&
      (texto.contains('..') || texto.startsWith('/') || texto.contains(r'\'))) {
    p.add('$r.texto: ruta no permitida');
  }
}

/// `uso` y `rtf` salen de medir en el aparato (P3.3): si están, tienen forma.
void _validarOpcionales(Map crudo, String r, List<String> p) {
  final uso = crudo['uso'];
  if (uso != null) {
    if (uso is! Map) {
      p.add('$r.uso: no es un objeto');
    } else {
      uso.forEach((k, v) {
        if (v is! bool) p.add('$r.uso.$k: debe ser verdadero o falso');
      });
    }
  }
  final rtf = crudo['rtf'];
  if (rtf != null) {
    if (rtf is! List) {
      p.add('$r.rtf: no es una lista');
    } else {
      for (var i = 0; i < rtf.length; i++) {
        final m = rtf[i];
        if (m is! Map ||
            _texto(m['equipo']) == null ||
            m['hilos'] is! int ||
            m['rtf'] is! num ||
            _texto(m['fecha']) == null) {
          p.add('$r.rtf[$i]: debe traer equipo, hilos, rtf y fecha');
        }
      }
    }
  }
}

/// Lee y valida un catálogo. Lanza [CatalogoInvalido] si algo no cumple.
CatalogoDeVoces leerCatalogo(String texto) {
  final Object? json;
  try {
    json = jsonDecode(texto);
  } on FormatException {
    throw const CatalogoInvalido(['raíz: no es JSON válido']);
  }
  final problemas = validarCatalogo(json);
  if (problemas.isNotEmpty) throw CatalogoInvalido(problemas);
  final modelos = (json! as Map)['modelos'] as List;
  return CatalogoDeVoces([
    for (final m in modelos) _construir(m as Map<Object?, Object?>),
  ]);
}

ModeloDelCatalogo _construir(Map<Object?, Object?> m) {
  final fuente = m['fuente']! as Map;
  final licencia = m['licencia']! as Map;
  final sugerida = (m['asignacion_sugerida'] as Map?) ?? const {};
  return ModeloDelCatalogo(
    id: m['id']! as String,
    nombre: m['nombre']! as String,
    familia: m['familia']! as String,
    idioma: m['idioma']! as String,
    variantes: [
      for (final v in m['variantes']! as List)
        Variante.deEtiqueta(v as String)!,
    ],
    voces: [
      for (final v in m['voces']! as List)
        VozDeModelo(
          sid: (v as Map)['sid']! as int,
          nombre: v['nombre']! as String,
          genero: v['genero'] == 'mujer' ? Genero.mujer : Genero.hombre,
          variante: Variante.deEtiqueta(v['variante']! as String)!,
          acentoAproximado: v['acento_aproximado'] == true,
        ),
    ],
    asignacionSugerida: {
      for (final e in sugerida.entries)
        VozDeGuion.deEtiqueta('${e.key}')!: e.value! as int,
    },
    archivos: [
      for (final a in m['archivos']! as List)
        ArchivoDeModelo(
          rol: RolDeArchivo.deCodigo((a as Map)['rol'])!,
          nombre: a['nombre']! as String,
          bytes: a['bytes']! as int,
          sha256: a['sha256']! as String,
          url: Uri.parse(a['url']! as String),
        ),
    ],
    licencia: LicenciaDeModelo(
      id: licencia['id']! as String,
      origen: licencia['origen']! as String,
      atribucion: licencia['atribucion']! as String,
      texto: licencia['texto']! as String,
      permiteDistribuirAudio: licencia['permite_distribuir_audio'] as bool?,
    ),
    fuente: FuenteDelModelo(
      url: Uri.parse(fuente['url']! as String),
      revision: fuente['revision']! as String,
    ),
    consultado: m['consultado']! as String,
  );
}
