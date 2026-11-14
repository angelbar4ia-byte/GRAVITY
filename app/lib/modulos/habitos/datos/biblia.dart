/// Texto bíblico en el formato `gravity-biblia-v1` (ver `herramientas/biblia/`).
/// Proveedor intercambiable (regla 78): agregar RVR1960 o NVI con licencia es
/// agregar otro proveedor. **No hay texto en el repositorio** hasta que el
/// dueño confirme la edición y la fuente (P10).
library;

import 'dart:convert';
import 'dart:io' show gzip;

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:habitos_dominio/habitos_dominio.dart';

class ResultadoBusqueda {
  const ResultadoBusqueda(
    this.libro,
    this.capitulo,
    this.versiculo,
    this.texto,
  );
  final int libro;
  final int capitulo;
  final int versiculo;
  final String texto;
}

abstract interface class ProveedorBiblia {
  String get id;
  String get nombre;
  String get licencia;
  String get origen;

  /// Versículos del capítulo (1 a n) o nulo si no existe en esta versión.
  List<String>? capitulo(int libro, int cap);

  List<ResultadoBusqueda> buscar(String consulta, {int maximo = 50});
}

class BibliaJson implements ProveedorBiblia {
  BibliaJson._(this.id, this.nombre, this.licencia, this.origen, this._libros);

  /// Valida el canon (66 libros y capítulos). Lanza [FormatException].
  factory BibliaJson.deMapa(Map<String, Object?> m) {
    if (m['formato'] != 'gravity-biblia-v1') {
      throw const FormatException('Formato de Biblia desconocido.');
    }
    final libros = [
      for (final l in (m['libros']! as List))
        [for (final c in (l as List)) (c as List).cast<String>()],
    ];
    if (libros.length != 66) throw const FormatException('Faltan libros.');
    for (var i = 0; i < 66; i++) {
      if (libros[i].length != canon[i].capitulos) {
        throw FormatException(
          '${canon[i].nombre}: capítulos distintos del canon.',
        );
      }
    }
    return BibliaJson._(
      m['version']! as String,
      m['nombre']! as String,
      m['licencia']! as String,
      m['origen']! as String,
      libros,
    );
  }

  factory BibliaJson.deBytesGzip(List<int> bytes) => BibliaJson.deMapa(
    (jsonDecode(utf8.decode(gzip.decode(bytes))) as Map)
        .cast<String, Object?>(),
  );

  @override
  final String id;
  @override
  final String nombre;
  @override
  final String licencia;
  @override
  final String origen;
  final List<List<List<String>>> _libros;

  @override
  List<String>? capitulo(int libro, int cap) {
    if (libro < 1 || libro > 66) return null;
    final l = _libros[libro - 1];
    return cap < 1 || cap > l.length ? null : l[cap - 1];
  }

  static String _n(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[áàä]'), 'a')
      .replaceAll(RegExp('[éèë]'), 'e')
      .replaceAll(RegExp('[íìï]'), 'i')
      .replaceAll(RegExp('[óòö]'), 'o')
      .replaceAll(RegExp('[úùü]'), 'u');

  @override
  List<ResultadoBusqueda> buscar(String consulta, {int maximo = 50}) {
    final q = _n(consulta.trim());
    if (q.length < 3) return const [];
    final r = <ResultadoBusqueda>[];
    for (var l = 0; l < 66; l++) {
      for (var c = 0; c < _libros[l].length; c++) {
        for (var v = 0; v < _libros[l][c].length; v++) {
          if (_n(_libros[l][c][v]).contains(q)) {
            r.add(ResultadoBusqueda(l + 1, c + 1, v + 1, _libros[l][c][v]));
            if (r.length >= maximo) return r;
          }
        }
      }
    }
    return r;
  }
}

/// Carga las versiones instaladas como recurso. Las que falten se omiten.
Future<List<ProveedorBiblia>> cargarBiblias({
  List<String> ids = const ['rvr1909', 'kjv'],
  AssetBundle? bundle,
}) async {
  final b = bundle ?? rootBundle;
  final r = <ProveedorBiblia>[];
  for (final id in ids) {
    try {
      final d = await b.load('assets/biblia/$id.json.gz');
      r.add(BibliaJson.deBytesGzip(d.buffer.asUint8List()));
    } catch (_) {
      // sin ese texto todavía
    }
  }
  return r;
}

/// Pasaje (varios versículos) de una [ReferenciaBiblica] de un capítulo.
List<(int, String)>? pasaje(ProveedorBiblia p, ReferenciaBiblica r) {
  final v = p.capitulo(r.libro, r.capIni);
  if (v == null) return null;
  final a = r.verIni ?? 1;
  final z = r.capFin == r.capIni
      ? (r.verFin ?? (r.verIni == null ? v.length : r.verIni!))
      : v.length;
  return [for (var i = a; i <= z && i <= v.length; i++) (i, v[i - 1])];
}
