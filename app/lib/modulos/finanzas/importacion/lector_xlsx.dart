/// Lector mínimo de libros de Excel (`.xlsx`) y CSV para importar la hoja
/// **Categorías** de `data/DATOS_SEMILLA_PRESUPUESTO.xlsx` (10, MVP 1).
///
/// Un `.xlsx` es un ZIP con XML: se leen el índice del ZIP, las cadenas
/// compartidas y la hoja pedida. Solo texto y números (sin fórmulas ni
/// formatos), que es lo que necesita la plantilla. Sin dependencias nuevas:
/// descomprime con `ZLibDecoder` de `dart:io` (Android y Windows).
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:finanzas_dominio/finanzas_dominio.dart';

/// Error al leer el archivo, con un mensaje para la interfaz.
class ErrorArchivo implements Exception {
  const ErrorArchivo(this.mensaje);

  final String mensaje;

  @override
  String toString() => mensaje;
}

/// Un libro de Excel ya abierto.
class LibroXlsx {
  LibroXlsx._(this._archivos, this._hojas);

  final Map<String, Uint8List> _archivos;

  /// Nombre de la hoja → ruta de su XML dentro del ZIP.
  final Map<String, String> _hojas;
  List<String>? _compartidas;

  List<String> get hojas => _hojas.keys.toList();

  /// La hoja [nombre] (sin importar acentos ni mayúsculas) como tabla de
  /// texto. Lanza [ErrorArchivo] si no existe.
  List<List<String>> hoja(String nombre) {
    final clave = normalizarNombre(nombre);
    final entrada = _hojas.entries
        .where((e) => normalizarNombre(e.key) == clave)
        .firstOrNull;
    if (entrada == null) {
      throw ErrorArchivo(
        'El archivo no tiene la hoja "$nombre". Hojas: ${hojas.join(', ')}.',
      );
    }
    final xml = _texto(entrada.value);
    return _filas(xml, _cadenas());
  }

  String _texto(String ruta) {
    final datos = _archivos[ruta];
    if (datos == null) throw ErrorArchivo('Falta $ruta dentro del archivo.');
    return utf8.decode(datos, allowMalformed: true);
  }

  List<String> _cadenas() => _compartidas ??= () {
    if (!_archivos.containsKey('xl/sharedStrings.xml')) return <String>[];
    final xml = _texto('xl/sharedStrings.xml');
    return [
      for (final si in RegExp(r'<si\b[^>]*>(.*?)</si>', dotAll: true).allMatches(xml))
        _textoDeRuns(si.group(1)!),
    ];
  }();

  static String _textoDeRuns(String xml) => [
    for (final t in RegExp(r'<t\b[^>]*>(.*?)</t>', dotAll: true).allMatches(xml))
      desescaparXml(t.group(1)!),
  ].join();

  static int _columna(String referencia) {
    var n = 0;
    for (final c in referencia.codeUnits) {
      if (c < 65 || c > 90) break;
      n = n * 26 + (c - 64);
    }
    return n - 1;
  }

  static List<List<String>> _filas(String xml, List<String> cadenas) {
    final filas = <List<String>>[];
    final celdaExp = RegExp(
      r'<c\b([^>]*?)(?:/>|>(.*?)</c>)',
      dotAll: true,
    );
    for (final fila in RegExp(
      r'<row\b([^>]*)>(.*?)</row>',
      dotAll: true,
    ).allMatches(xml)) {
      final numero = int.tryParse(
        RegExp(r'\br="(\d+)"').firstMatch(fila.group(1)!)?.group(1) ?? '',
      );
      final celdas = <int, String>{};
      var siguiente = 0;
      for (final c in celdaExp.allMatches(fila.group(2)!)) {
        final atributos = c.group(1)!;
        final contenido = c.group(2) ?? '';
        final ref = RegExp(r'\br="([A-Z]+)\d*"').firstMatch(atributos)?.group(1);
        final col = ref == null ? siguiente : _columna(ref);
        siguiente = col + 1;
        final tipo = RegExp(r'\bt="(\w+)"').firstMatch(atributos)?.group(1);
        final v = RegExp(r'<v>(.*?)</v>', dotAll: true)
            .firstMatch(contenido)
            ?.group(1);
        final texto = switch (tipo) {
          's' => v == null ? '' : cadenas[int.parse(v)],
          'inlineStr' => _textoDeRuns(contenido),
          _ => v == null ? '' : desescaparXml(v),
        };
        celdas[col] = texto;
      }
      final ancho = celdas.isEmpty
          ? 0
          : celdas.keys.reduce((a, b) => a > b ? a : b) + 1;
      final renglon = [for (var i = 0; i < ancho; i++) celdas[i] ?? ''];
      // Respeta los huecos entre filas (el número de fila del archivo).
      if (numero != null) {
        while (filas.length < numero - 1) {
          filas.add(const []);
        }
      }
      filas.add(renglon);
    }
    return filas;
  }
}

/// `&amp;` → `&`, `&#241;` → `ñ`…
String desescaparXml(String texto) => texto.replaceAllMapped(
  RegExp(r'&(#x[0-9a-fA-F]+|#\d+|amp|lt|gt|quot|apos);'),
  (m) {
    final e = m.group(1)!;
    if (e.startsWith('#x')) {
      return String.fromCharCode(int.parse(e.substring(2), radix: 16));
    }
    if (e.startsWith('#')) return String.fromCharCode(int.parse(e.substring(1)));
    return const {
      'amp': '&',
      'lt': '<',
      'gt': '>',
      'quot': '"',
      'apos': "'",
    }[e]!;
  },
);

/// Abre un `.xlsx` desde sus bytes. Lanza [ErrorArchivo] si no lo es.
LibroXlsx leerXlsx(Uint8List bytes) {
  final archivos = _leerZip(bytes);
  final workbook = archivos['xl/workbook.xml'];
  final rels = archivos['xl/_rels/workbook.xml.rels'];
  if (workbook == null || rels == null) {
    throw const ErrorArchivo('No es un libro de Excel (.xlsx).');
  }
  final destinos = <String, String>{
    for (final r in RegExp(r'<Relationship\b([^>]*)/?>').allMatches(
      utf8.decode(rels),
    ))
      if (RegExp(r'\bId="([^"]+)"').firstMatch(r.group(1)!)?.group(1)
          case final id?)
        id: RegExp(r'\bTarget="([^"]+)"').firstMatch(r.group(1)!)!.group(1)!,
  };
  final hojas = <String, String>{};
  for (final h in RegExp(r'<sheet\b([^>]*)/?>').allMatches(utf8.decode(workbook))) {
    final atributos = h.group(1)!;
    final nombre = RegExp(r'\bname="([^"]*)"').firstMatch(atributos)?.group(1);
    final id = RegExp(r'\br:id="([^"]+)"').firstMatch(atributos)?.group(1);
    final destino = destinos[id];
    if (nombre == null || destino == null) continue;
    final ruta = destino.startsWith('/')
        ? destino.substring(1)
        : 'xl/$destino';
    hojas[desescaparXml(nombre)] = ruta;
  }
  return LibroXlsx._(archivos, hojas);
}

/// Lee los archivos de un ZIP (solo "guardado" y "deflate", que es lo que
/// usan Excel y LibreOffice).
Map<String, Uint8List> _leerZip(Uint8List bytes) {
  final datos = ByteData.sublistView(bytes);
  int u16(int i) => datos.getUint16(i, Endian.little);
  int u32(int i) => datos.getUint32(i, Endian.little);
  // Fin del directorio central: firma 0x06054b50, cerca del final.
  var fin = -1;
  for (var i = bytes.length - 22; i >= 0 && i >= bytes.length - 65557; i--) {
    if (u32(i) == 0x06054b50) {
      fin = i;
      break;
    }
  }
  if (fin < 0) throw const ErrorArchivo('No es un libro de Excel (.xlsx).');
  final entradas = u16(fin + 10);
  var p = u32(fin + 16);
  final archivos = <String, Uint8List>{};
  for (var n = 0; n < entradas; n++) {
    if (p + 46 > bytes.length || u32(p) != 0x02014b50) {
      throw const ErrorArchivo('El archivo de Excel está dañado.');
    }
    final metodo = u16(p + 10);
    final comprimido = u32(p + 20);
    final largoNombre = u16(p + 28);
    final largoExtra = u16(p + 30);
    final largoComentario = u16(p + 32);
    final local = u32(p + 42);
    final nombre = utf8.decode(bytes.sublist(p + 46, p + 46 + largoNombre));
    p += 46 + largoNombre + largoExtra + largoComentario;
    if (!nombre.endsWith('.xml') && !nombre.endsWith('.rels')) continue;
    if (u32(local) != 0x04034b50) {
      throw const ErrorArchivo('El archivo de Excel está dañado.');
    }
    final inicio = local + 30 + u16(local + 26) + u16(local + 28);
    final crudo = bytes.sublist(inicio, inicio + comprimido);
    archivos[nombre] = switch (metodo) {
      0 => crudo,
      8 => Uint8List.fromList(ZLibDecoder(raw: true).convert(crudo)),
      _ => throw const ErrorArchivo(
        'El archivo usa una compresión que no se puede leer.',
      ),
    };
  }
  return archivos;
}

/// Lee la tabla de la hoja [hoja] de un `.xlsx`, o el CSV completo, según el
/// nombre del archivo.
List<List<String>> tablaDeArchivo(
  Uint8List bytes, {
  required String nombreArchivo,
  String hoja = 'Categorías',
}) {
  final nombre = nombreArchivo.toLowerCase();
  if (nombre.endsWith('.csv') || nombre.endsWith('.txt')) {
    return leerCsv(utf8.decode(bytes, allowMalformed: true));
  }
  if (nombre.endsWith('.xlsx')) return leerXlsx(bytes).hoja(hoja);
  throw const ErrorArchivo('Elige un archivo .xlsx o .csv.');
}

/// Lee un archivo del disco (laptop) y devuelve la hoja Categorías ya leída.
Future<LecturaPlantilla> leerPlantillaDeRuta(
  String ruta, {
  String hoja = 'Categorías',
}) async {
  final archivo = File(ruta.trim());
  if (!await archivo.exists()) {
    throw ErrorArchivo('No encontré el archivo: ${archivo.path}');
  }
  final bytes = await archivo.readAsBytes();
  try {
    return leerPlantillaCategorias(
      tablaDeArchivo(bytes, nombreArchivo: archivo.path, hoja: hoja),
    );
  } on ErrorPlantilla catch (e) {
    throw ErrorArchivo(e.mensaje);
  } on FormatException catch (e) {
    throw ErrorArchivo('No pude leer el archivo: ${e.message}');
  }
}
