/// Enlaces externos (7, PB-15, CA-B-14): solo `https`, `tel`, `sms` y `geo`.
/// Nada se abre sin un toque de la persona (eso lo cumple la capa de
/// pantallas; aquí solo se decide **qué enlace es aceptable**).
///
/// Se rechazan `javascript:`, `intent:`, `file:`, `content:`, `http:` sin
/// cifrar y cualquier otro esquema. Un enlace con coordenadas es una ruta y
/// **vive en el tipo local**, nunca en la nube.
library;

enum EsquemaEnlace {
  https('https'),
  tel('tel'),
  sms('sms'),
  geo('geo');

  const EsquemaEnlace(this.id);
  final String id;

  static EsquemaEnlace? deId(String id) {
    for (final e in values) {
      if (e.id == id) return e;
    }
    return null;
  }
}

class ResultadoEnlace {
  const ResultadoEnlace.ok(this.esquema, this.enlace) : motivo = null;
  const ResultadoEnlace.malo(this.motivo) : esquema = null, enlace = null;

  final EsquemaEnlace? esquema;

  /// El enlace limpio (sin espacios en los extremos).
  final String? enlace;

  /// Por qué se rechazó: `vacio`, `largo`, `caracteres`, `sin_cifrar`,
  /// `esquema`, `forma`, `credenciales`, `no_permitido`.
  final String? motivo;

  bool get valido => esquema != null;
}

final _control = RegExp(r'[\x00-\x20\x7F]');

/// Valida un enlace. [permitidos] limita los esquemas (música y clima: solo
/// `https`).
ResultadoEnlace validarEnlace(
  String texto, {
  Set<EsquemaEnlace> permitidos = const {
    EsquemaEnlace.https,
    EsquemaEnlace.tel,
    EsquemaEnlace.sms,
    EsquemaEnlace.geo,
  },
  int maxLargo = 500,
}) {
  final t = texto.trim();
  if (t.isEmpty) return const ResultadoEnlace.malo('vacio');
  if (t.length > maxLargo) return const ResultadoEnlace.malo('largo');
  if (_control.hasMatch(t)) return const ResultadoEnlace.malo('caracteres');
  final u = Uri.tryParse(t);
  if (u == null || u.scheme.isEmpty) return const ResultadoEnlace.malo('forma');
  if (u.scheme == 'http') return const ResultadoEnlace.malo('sin_cifrar');
  final e = EsquemaEnlace.deId(u.scheme);
  if (e == null) return const ResultadoEnlace.malo('esquema');
  if (!permitidos.contains(e)) {
    return const ResultadoEnlace.malo('no_permitido');
  }
  switch (e) {
    case EsquemaEnlace.https:
      if (!u.hasAuthority || u.host.isEmpty) {
        return const ResultadoEnlace.malo('forma');
      }
      if (u.userInfo.isNotEmpty) {
        return const ResultadoEnlace.malo('credenciales');
      }
    case EsquemaEnlace.tel:
    case EsquemaEnlace.sms:
    case EsquemaEnlace.geo:
      // Esquemas sin autoridad: debe haber algo después de los dos puntos.
      if (t.length <= e.id.length + 1 || u.hasAuthority) {
        return const ResultadoEnlace.malo('forma');
      }
  }
  return ResultadoEnlace.ok(e, t);
}

final _coordenadas = RegExp(
  r'-?\d{1,3}\.\d{3,}\s*(,|%2c)\s*-?\d{1,3}\.\d{3,}',
  caseSensitive: false,
);

/// ¿El enlace lleva una ubicación (esquema `geo` o un par de coordenadas)?
/// Si es así es una ruta: **va al tipo local**, no a la nube.
bool enlaceLlevaUbicacion(String texto) {
  final t = texto.trim();
  return t.toLowerCase().startsWith('geo:') || _coordenadas.hasMatch(t);
}

// ---------------------------------------------------------------------------
// Listas de música (`hab_musica_listas`, PB-14, 3.12)
// ---------------------------------------------------------------------------

enum ActividadMusica {
  bicicleta('bicicleta'),
  fuerza('fuerza'),
  regenerativo('regenerativo'),
  traslado('traslado'),
  devocional('devocional');

  const ActividadMusica(this.id);
  final String id;
}

enum AppMusica {
  spotify('spotify'),
  amazonMusic('amazon_music'),
  otra('otra');

  const AppMusica(this.id);
  final String id;
}

/// Un enlace `https` guardado con su nombre y su actividad. GRAVITY no se
/// conecta a ninguna cuenta de música.
class ListaMusica {
  const ListaMusica({
    required this.id,
    required this.nombre,
    required this.actividad,
    required this.app,
    required this.enlace,
    this.orden = 1,
  });

  final String id;
  final String nombre;
  final ActividadMusica actividad;
  final AppMusica app;
  final String enlace;
  final int orden;

  /// Nombre de 1 a 60; enlace `https://` de 10 a 300; orden de 1 a 20.
  List<String> validar() {
    final e = <String>[];
    if (nombre.trim().isEmpty || nombre.length > 60) {
      e.add('nombre de 1 a 60 caracteres');
    }
    if (enlace.length < 10 || enlace.length > 300) {
      e.add('enlace de 10 a 300 caracteres');
    }
    if (!enlace.startsWith('https://')) e.add('el enlace debe ser https');
    final r = validarEnlace(
      enlace,
      permitidos: const {EsquemaEnlace.https},
      maxLargo: 300,
    );
    if (!r.valido) e.add('enlace no válido (${r.motivo})');
    if (enlaceLlevaUbicacion(enlace)) {
      e.add('un enlace con coordenadas es una ruta: va solo al equipo');
    }
    if (orden < 1 || orden > 20) e.add('orden de 1 a 20');
    return e;
  }

  Map<String, Object?> aJson() => {
    'id': id,
    'nombre': nombre,
    'actividad': actividad.id,
    'app': app.id,
    'enlace': enlace,
    'orden': orden,
  };
}
