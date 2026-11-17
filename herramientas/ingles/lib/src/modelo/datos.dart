/// Acceso a los datos tal como se leyeron (mapas y listas de Dart) y búsqueda
/// de los `pendiente: true` a cualquier profundidad.
///
/// Los contratos propios (`gravity-sesion-60`, `gravity-escalon`,
/// `gravity-ubicacion`) y `niveles.yaml` traen mucho más de lo que el modelo
/// tipado conoce; las comprobaciones que los leen (V21, V22, V27, V28) lo hacen
/// por aquí, con rutas de puntos (`viernes.mini_prueba.preguntas`). Un dato que
/// falta devuelve null: quien lo necesita lo dice, la lectura nunca lo inventa.
library;

typedef Mapa = Map<String, Object?>;

/// El valor en una ruta de puntos (`a.b.c`), o null si algún tramo no existe.
/// Un tramo numérico entra en una lista (`a.0.b`).
Object? en(Object? raiz, String ruta) {
  Object? v = raiz;
  for (final tramo in ruta.split('.')) {
    if (v is Map) {
      v = v[tramo];
    } else if (v is List) {
      final i = int.tryParse(tramo);
      if (i == null || i < 0 || i >= v.length) return null;
      v = v[i];
    } else {
      return null;
    }
  }
  return v;
}

Mapa? mapaEn(Object? raiz, String ruta) {
  final v = en(raiz, ruta);
  return v is Map<String, Object?> ? v : null;
}

List<Object?>? listaEn(Object? raiz, String ruta) {
  final v = en(raiz, ruta);
  return v is List<Object?> ? v : null;
}

num? numeroEn(Object? raiz, String ruta) {
  final v = en(raiz, ruta);
  return v is num ? v : null;
}

int? enteroEn(Object? raiz, String ruta) {
  final v = en(raiz, ruta);
  return v is int ? v : (v is num && v == v.roundToDouble() ? v.toInt() : null);
}

String? textoEn(Object? raiz, String ruta) {
  final v = en(raiz, ruta);
  return v is String ? v : null;
}

bool? boolEn(Object? raiz, String ruta) {
  final v = en(raiz, ruta);
  return v is bool ? v : null;
}

/// Una lista de números (`[1, 2, 3]`), o null si no lo es.
List<int>? enterosEn(Object? raiz, String ruta) {
  final l = listaEn(raiz, ruta);
  if (l == null) return null;
  final salida = <int>[];
  for (final e in l) {
    if (e is! num) return null;
    salida.add(e.toInt());
  }
  return salida;
}

/// Una lista de textos, o null si no lo es.
List<String>? textosEn(Object? raiz, String ruta) {
  final l = listaEn(raiz, ruta);
  if (l == null) return null;
  final salida = <String>[];
  for (final e in l) {
    if (e is! String) return null;
    salida.add(e);
  }
  return salida;
}

/// Un dato que el contrato (o `niveles.yaml`) marca `pendiente: true`.
class DatoPendiente {
  const DatoPendiente(this.ruta, this.nota);

  /// Dónde está la marca, con puntos (`secciones.0.partes.1.por_dia.martes`).
  final String ruta;
  final String? nota;

  @override
  String toString() => nota == null ? ruta : '$ruta: $nota';
}

/// Todas las marcas `pendiente: true` de [datos], a cualquier profundidad. La
/// ruta es la del bloque que lleva la marca. Una nota pegada a la marca (campo
/// `nota` del mismo bloque) viaja con ella.
List<DatoPendiente> pendientesEn(Object? datos, [String prefijo = '']) {
  final salida = <DatoPendiente>[];
  void recorre(Object? v, String ruta) {
    if (v is Map) {
      if (v['pendiente'] == true) {
        final nota = v['nota'];
        final id = v['id'];
        salida.add(
          DatoPendiente(
            id is String ? '$ruta ($id)' : ruta,
            nota is String ? nota : null,
          ),
        );
      }
      for (final e in v.entries) {
        recorre(e.value, ruta.isEmpty ? '${e.key}' : '$ruta.${e.key}');
      }
    } else if (v is List) {
      for (var i = 0; i < v.length; i++) {
        recorre(v[i], ruta.isEmpty ? '$i' : '$ruta.$i');
      }
    }
  }

  recorre(datos, prefijo);
  return salida;
}

/// ¿Hay alguna marca `pendiente: true` en [datos] o debajo?
bool tienePendientes(Object? datos) => pendientesEn(datos).isNotEmpty;
