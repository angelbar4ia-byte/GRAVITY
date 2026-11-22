/// Catálogo de modelos de voz descargables (spec `fase-8-motor-de-voz.md`,
/// 4.2.1): datos, no código.
///
/// Es un archivo dentro de la app (`app/assets/voces/catalogo.json`): **no se
/// descarga**, así que las huellas viajan firmadas con la app. Un modelo es una
/// **lista de archivos con huella**; el cargador nunca recorre carpetas ni
/// acepta archivos que el catálogo no liste.
///
/// Reglas que estos tipos ayudan a cumplir: R7 (sin secretos: solo direcciones
/// públicas y huellas), R10 (solo se carga lo verificado), R11 (cada modelo
/// lleva su licencia y la atribución que la pantalla muestra).
library;

import 'package:flutter/foundation.dart' show immutable;

import '../tipos.dart';

/// Qué es cada archivo de un modelo para el cargador.
enum RolDeArchivo {
  modelo('modelo'),
  tokens('tokens'),
  lexicon('lexicon');

  const RolDeArchivo(this.codigo);

  /// Cómo se escribe en el catálogo.
  final String codigo;

  static RolDeArchivo? deCodigo(Object? codigo) {
    for (final r in values) {
      if (r.codigo == codigo) return r;
    }
    return null;
  }
}

/// Un archivo del modelo, con su huella.
@immutable
final class ArchivoDeModelo {
  const ArchivoDeModelo({
    required this.rol,
    required this.nombre,
    required this.bytes,
    required this.sha256,
    required this.url,
  });

  final RolDeArchivo rol;

  /// Sin `/`, `\` ni `..` (lo comprueba el validador).
  final String nombre;
  final int bytes;

  /// 64 hexadecimales en minúscula.
  final String sha256;

  /// `https`, sin parámetros, con la revisión fija en la ruta.
  final Uri url;

  @override
  String toString() => 'ArchivoDeModelo($nombre)';
}

/// Una voz que trae un modelo (`sid` es el número de voz dentro del modelo).
@immutable
final class VozDeModelo {
  const VozDeModelo({
    required this.sid,
    required this.nombre,
    required this.genero,
    required this.variante,
    this.acentoAproximado = false,
  });

  final int sid;
  final String nombre;
  final Genero genero;
  final Variante variante;

  /// La voz suena con otro acento del que dice (por ejemplo, Cori: británica,
  /// pero con el lexicón americano, spec 9.2 V8). Se dice en pantalla.
  final bool acentoAproximado;
}

@immutable
final class LicenciaDeModelo {
  const LicenciaDeModelo({
    required this.id,
    required this.origen,
    required this.atribucion,
    required this.texto,
    this.permiteDistribuirAudio,
  });

  final String id;
  final String origen;

  /// Lo que la pantalla debe mostrar (R11).
  final String atribucion;

  /// Ruta del texto de la licencia en el repositorio (`docs/licencias-voces/`).
  final String texto;

  /// `null`: nadie lo decidió todavía, y entonces el modelo **no** se usa para
  /// pregrabar audio (regla 4 de 4.2.1). Lo decide una persona.
  final bool? permiteDistribuirAudio;
}

@immutable
final class FuenteDelModelo {
  const FuenteDelModelo({required this.url, required this.revision});
  final Uri url;

  /// Revisión fija del alojamiento (nunca `main` ni "la última").
  final String revision;
}

@immutable
final class ModeloDelCatalogo {
  const ModeloDelCatalogo({
    required this.id,
    required this.nombre,
    required this.familia,
    required this.idioma,
    required this.variantes,
    required this.voces,
    required this.asignacionSugerida,
    required this.archivos,
    required this.licencia,
    required this.fuente,
    required this.consultado,
  });

  /// Nombre de la carpeta del modelo y de su carpeta en el alojamiento.
  final String id;
  final String nombre;

  /// `vits` (Piper), `kokoro`, `kitten` o `matcha`. Hoy solo `vits` se carga.
  final String familia;
  final String idioma;
  final List<Variante> variantes;
  final List<VozDeModelo> voces;

  /// Qué `sid` suena mejor para cada voz de guion (la usará el generador de
  /// la fuente C; la fuente B asigna por género).
  final Map<VozDeGuion, int> asignacionSugerida;
  final List<ArchivoDeModelo> archivos;
  final LicenciaDeModelo licencia;
  final FuenteDelModelo fuente;

  /// Fecha en que se leyó el origen (`2026-11-22`).
  final String consultado;

  /// Lo que pesa descargarlo todo.
  int get bytes => archivos.fold(0, (suma, a) => suma + a.bytes);

  ArchivoDeModelo archivoDe(RolDeArchivo rol) =>
      archivos.firstWhere((a) => a.rol == rol);

  ArchivoDeModelo? archivoOpcional(RolDeArchivo rol) {
    for (final a in archivos) {
      if (a.rol == rol) return a;
    }
    return null;
  }

  /// `true` si alguna de sus voces es de [variante].
  bool ofrece(Variante variante) => voces.any((v) => v.variante == variante);

  /// Esta versión de la app solo sabe cargar voces VITS (Piper) con lexicón.
  bool get cargable => familia == 'vits';
}

@immutable
final class CatalogoDeVoces {
  const CatalogoDeVoces(this.modelos);

  /// Catálogo vacío: la app sin voces descargables (por ejemplo, si el archivo
  /// del catálogo no pasó la validación).
  static const vacio = CatalogoDeVoces([]);

  final List<ModeloDelCatalogo> modelos;

  ModeloDelCatalogo? porId(String id) {
    for (final m in modelos) {
      if (m.id == id) return m;
    }
    return null;
  }
}
