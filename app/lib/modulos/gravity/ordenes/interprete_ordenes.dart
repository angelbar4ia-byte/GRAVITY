/// Intérprete de la barra de órdenes de la Fase 0: solo navegación, sin IA.
///
/// Entiende órdenes como "abre presupuesto", "ir a hábitos" o "ajustes",
/// tolera acentos, mayúsculas y errores de dedo, sugiere mientras se escribe
/// y nunca ofrece un destino que el rol no ve.
library;

import 'dart:math' as math;

import '../../../nucleo/contratos/roles.dart';
import '../../../nucleo/herramientas/herramientas.dart';
import 'texto_ordenes.dart';

/// Lo que entendió el intérprete.
sealed class ResultadoOrden {
  const ResultadoOrden();
}

/// No se escribió nada.
final class OrdenVacia extends ResultadoOrden {
  const OrdenVacia();
}

/// Se entendió un solo destino: se puede abrir.
final class OrdenEntendida extends ResultadoOrden {
  const OrdenEntendida(this.destino);

  final HerramientaNavegacion destino;
}

/// No hubo coincidencia exacta única: "¿Quisiste decir…?" con [opciones].
final class OrdenParecida extends ResultadoOrden {
  const OrdenParecida(this.texto, this.opciones);

  final String texto;
  final List<HerramientaNavegacion> opciones;
}

/// No se entendió. [disponibles] son los destinos que el rol sí puede abrir.
final class OrdenNoEntendida extends ResultadoOrden {
  const OrdenNoEntendida(this.texto, this.disponibles);

  final String texto;
  final List<HerramientaNavegacion> disponibles;
}

/// Una sugerencia mientras se escribe.
final class SugerenciaOrden {
  const SugerenciaOrden(this.destino, {this.palabra});

  final HerramientaNavegacion destino;

  /// Palabra clave que coincidió, si no es el nombre del destino
  /// (p. ej. "presupuesto" para Finanzas).
  final String? palabra;
}

/// Una palabra clave ya normalizada.
final class _Clave {
  _Clave(this.original, this.palabras);

  final String original;
  final List<String> palabras;
}

final class _Destino {
  _Destino(this.herramienta, this.claves);

  final HerramientaNavegacion herramienta;
  final List<_Clave> claves;
}

/// Intérprete de órdenes de navegación para un rol.
final class InterpreteOrdenes {
  /// [puedeVer] decide qué módulos se ofrecen (por defecto, la matriz de la
  /// sección 5 de la especificación de la Fase 0). Además, cada destino es una
  /// herramienta y solo se ofrece si [rol] está en sus roles y su módulo está
  /// en [modulosActivos] (`null`: todos).
  InterpreteOrdenes({
    required this.rol,
    PuedeVerModulo? puedeVer,
    Set<Modulo>? modulosActivos,
    List<HerramientaNavegacion>? catalogo,
  }) : _destinos = _armar(
         rol: rol,
         puedeVer: puedeVer ?? puedeVerPorDefecto(rol),
         modulosActivos: modulosActivos,
         catalogo: catalogo ?? herramientasNavegacion,
       );

  final Rol rol;
  final List<_Destino> _destinos;

  static List<_Destino> _armar({
    required Rol rol,
    required PuedeVerModulo puedeVer,
    required Set<Modulo>? modulosActivos,
    required List<HerramientaNavegacion> catalogo,
  }) {
    final permitidas = RegistroHerramientas(catalogo)
        .disponibles(rol: rol, modulosActivos: modulosActivos)
        .whereType<HerramientaNavegacion>()
        .where((h) => puedeVer(h.modulo));
    return [
      for (final h in permitidas)
        _Destino(h, [
          for (final original in {h.etiqueta, ...h.palabrasClave})
            if (quitarRelleno(palabrasDe(original)) case final p
                when p.isNotEmpty)
              _Clave(original, p),
        ]),
    ];
  }

  /// Destinos que este rol puede abrir, en orden.
  List<HerramientaNavegacion> get destinos =>
      List.unmodifiable(_destinos.map((d) => d.herramienta));

  /// Interpreta una orden completa (al presionar Enter).
  ResultadoOrden interpretar(String texto) {
    final todas = palabrasDe(texto);
    if (todas.isEmpty) return const OrdenVacia();
    final palabras = quitarRelleno(todas);
    if (palabras.isEmpty) return OrdenNoEntendida(texto, destinos);

    // 1. Coincidencias exactas; gana la palabra clave más larga
    //    ("menú principal" le gana a "menú").
    final largoPorDestino = <_Destino, int>{};
    for (final d in _destinos) {
      for (final c in d.claves) {
        if (_contiene(palabras, c.palabras)) {
          largoPorDestino[d] = math.max(largoPorDestino[d] ?? 0, c.palabras.length);
        }
      }
    }
    if (largoPorDestino.isNotEmpty) {
      final mayor = largoPorDestino.values.reduce(math.max);
      final ganadores = [
        for (final d in _destinos)
          if (largoPorDestino[d] == mayor) d.herramienta,
      ];
      return ganadores.length == 1
          ? OrdenEntendida(ganadores.single)
          : OrdenParecida(texto, ganadores);
    }

    // 2. Parecidas: errores de dedo o palabras a medias.
    final parecidas = <_Destino, int>{};
    for (final d in _destinos) {
      final puntos = _parecido(d, palabras);
      if (puntos != null) parecidas[d] = puntos;
    }
    if (parecidas.isNotEmpty) {
      final orden = parecidas.keys.toList()
        ..sort((a, b) {
          final porPuntos = parecidas[a]!.compareTo(parecidas[b]!);
          return porPuntos != 0
              ? porPuntos
              : _destinos.indexOf(a).compareTo(_destinos.indexOf(b));
        });
      return OrdenParecida(
        texto,
        [for (final d in orden.take(3)) d.herramienta],
      );
    }
    return OrdenNoEntendida(texto, destinos);
  }

  /// Sugerencias mientras se escribe: la última palabra puede estar a medias.
  List<SugerenciaOrden> sugerir(String texto, {int maximo = 5}) {
    final todas = palabrasDe(texto);
    if (todas.isEmpty) return const [];
    final aMedias = texto.endsWith(' ') ? null : todas.last;
    final completas = quitarRelleno(
      aMedias == null ? todas : todas.sublist(0, todas.length - 1),
    );

    final puntos = <_Destino, (int, String?)>{};
    void anotar(_Destino d, int valor, _Clave c) {
      final actual = puntos[d];
      if (actual == null || valor < actual.$1) {
        final esEtiqueta = normalizarTexto(c.original) ==
            normalizarTexto(d.herramienta.etiqueta);
        puntos[d] = (valor, esEtiqueta ? null : c.original);
      }
    }

    for (final d in _destinos) {
      for (final c in d.claves) {
        if (_contiene(completas, c.palabras)) anotar(d, 0, c);
        for (final palabraClave in c.palabras) {
          if (aMedias != null) {
            if (palabraClave.startsWith(aMedias)) {
              anotar(d, 1, c);
            } else if (aMedias.length >= 3 && palabraClave.contains(aMedias)) {
              anotar(d, 2, c);
            } else if (aMedias.length >= 3 &&
                distanciaEdicion(
                      aMedias,
                      palabraClave.substring(
                        0,
                        math.min(aMedias.length, palabraClave.length),
                      ),
                    ) <=
                    1) {
              anotar(d, 3, c);
            }
          }
          for (final p in completas) {
            if (p.length >= 3 &&
                distanciaEdicion(p, palabraClave) <=
                    toleranciaPara(palabraClave.length)) {
              anotar(d, 3, c);
            }
          }
        }
      }
    }

    // Solo relleno ("abre ") o un verbo a medias: se ofrecen todos.
    final soloRelleno = completas.isEmpty &&
        (aMedias == null || palabrasDeRelleno.contains(aMedias));
    if (puntos.isEmpty && soloRelleno) {
      return [
        for (final d in _destinos.take(maximo)) SugerenciaOrden(d.herramienta),
      ];
    }

    final orden = puntos.keys.toList()
      ..sort((a, b) {
        final porPuntos = puntos[a]!.$1.compareTo(puntos[b]!.$1);
        return porPuntos != 0
            ? porPuntos
            : _destinos.indexOf(a).compareTo(_destinos.indexOf(b));
      });
    return [
      for (final d in orden.take(maximo))
        SugerenciaOrden(d.herramienta, palabra: puntos[d]!.$2),
    ];
  }

  /// Menor distancia de edición entre las palabras escritas y las claves del
  /// destino, si está dentro de la tolerancia; si no, `null`.
  static int? _parecido(_Destino d, List<String> palabras) {
    int? mejor;
    for (final c in d.claves) {
      for (final palabraClave in c.palabras) {
        for (final p in palabras) {
          if (p.length < 3) continue;
          int? valor;
          final distancia = distanciaEdicion(p, palabraClave);
          if (distancia <= toleranciaPara(palabraClave.length)) {
            valor = distancia * 2;
          } else if (palabraClave.startsWith(p)) {
            // Palabra a medias ("presu"): vale como un error.
            valor = 2;
          }
          if (valor != null && (mejor == null || valor < mejor)) mejor = valor;
        }
      }
    }
    return mejor;
  }

  /// `true` si [aguja] aparece seguida dentro de [pajar].
  static bool _contiene(List<String> pajar, List<String> aguja) {
    if (aguja.isEmpty || aguja.length > pajar.length) return false;
    for (var i = 0; i + aguja.length <= pajar.length; i++) {
      var igual = true;
      for (var j = 0; j < aguja.length; j++) {
        if (pajar[i + j] != aguja[j]) {
          igual = false;
          break;
        }
      }
      if (igual) return true;
    }
    return false;
  }
}
