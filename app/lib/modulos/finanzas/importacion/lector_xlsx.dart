/// Lector mínimo de libros de Excel (`.xlsx`) y CSV para importar la hoja
/// **Categorías** de `data/DATOS_SEMILLA_PRESUPUESTO.xlsx` (10, MVP 1).
///
/// Un `.xlsx` es un ZIP con XML: se leen el índice del ZIP, las cadenas
/// compartidas y la hoja pedida. Solo texto y números (sin fórmulas ni
/// formatos), que es lo que necesita la plantilla. Sin dependencias nuevas:
/// descomprime con `ZLibDecoder` de `dart:io` (Android y Windows).
///
/// ## El archivo es NO confiable
///
/// Lo que elige la persona con el selector de archivos puede venir de un
/// correo o de una descarga: se trata como entrada hostil (revisión de calidad
/// de la Fase 1b, hallazgos X1 a X5). Por eso:
///
/// - **Nada se ejecuta ni se sigue.** Las fórmulas no se evalúan (solo se lee
///   el valor guardado), no se abren enlaces ni libros externos
///   (`TargetMode="External"`), no hay DTD ni entidades definidas por el
///   archivo (el XML se recorre con un escáner propio, no con un parser) y
///   ninguna entrada del ZIP toca el disco: los nombres solo son llaves en
///   memoria, así que `../` o una ruta absoluta no hacen nada.
/// - **Topes** (una plantilla de categorías pesa unas decenas de KB y tiene
///   unos cientos de filas; el archivo semilla real usa menos de 2 % de cada
///   tope). Se documentan junto a cada constante: archivo entero
///   ([maximoBytesDeImportacion]), lo que se descomprime por componente
///   ([maximoBytesPorComponente]) y en total ([maximoBytesDescomprimidos]),
///   la razón de compresión ([razonMaximaDeCompresion]), componentes del ZIP
///   ([maximoEntradasZip]), hojas ([maximoHojas]), filas ([maximoFilas]),
///   columnas ([maximoColumnas]) y caracteres por celda
///   ([maximoLargoDeCelda]).
/// - **Descompresión con tope.** Cada componente se descomprime por pedazos y
///   se corta al pasar el tope, sin llegar a reservar la memoria de una
///   "bomba" (un `.xlsx` de unos KB que se expande a cientos de MB).
/// - **Tiempo lineal.** El XML se recorre con `indexOf` de una sola pasada;
///   una etiqueta sin cerrar se rechaza de inmediato en lugar de buscar su
///   cierre una vez por cada apertura (tiempo cuadrático).
/// - **Errores claros.** Todo lo que falla (ZIP dañado, tamaños que mienten,
///   cadenas compartidas fuera de rango, referencias de carácter imposibles…)
///   sale como [ErrorArchivo] con un mensaje corto, sin trazas ni rutas.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:finanzas_dominio/finanzas_dominio.dart';

// --------------------------------------------------------------------- topes

/// Tamaño máximo del archivo elegido (la plantilla pesa unas decenas de KB).
/// Se revisa **antes** de leerlo entero.
const maximoBytesDeImportacion = 10 * 1024 * 1024;

/// Lo máximo que se descomprime de **un** componente del ZIP (4 MiB; la hoja
/// más grande del archivo semilla pesa 125 KB).
const maximoBytesPorComponente = 4 * 1024 * 1024;

/// Lo máximo que se descomprime en total para abrir un libro (6 MiB: el
/// libro, sus relaciones, las cadenas compartidas y la hoja pedida; el archivo
/// semilla usa menos de 200 KB).
const maximoBytesDescomprimidos = 6 * 1024 * 1024;

/// Razón máxima de compresión de un componente: pasado [bytesSinRevisarRazon],
/// descomprimido / comprimido no puede pasar de 100 a 1 (el XML real comprime
/// 3 a 12 veces; una bomba, miles).
const razonMaximaDeCompresion = 100;

/// Los componentes más pequeños que esto no se miden por su razón de
/// compresión (un componente diminuto y muy repetitivo es normal).
const bytesSinRevisarRazon = 256 * 1024;

/// Componentes del ZIP que se aceptan (un libro de Excel tiene unas 25).
const maximoEntradasZip = 1000;

/// Hojas que se aceptan en el libro.
const maximoHojas = 256;

/// Filas que se aceptan en una hoja o en un CSV (Excel llega a 1,048,576; la
/// plantilla tiene unos cientos).
const maximoFilas = 100000;

/// Columnas que se aceptan (la plantilla usa 10).
const maximoColumnas = 200;

/// Caracteres que se aceptan en una celda (un nombre de categoría tiene
/// decenas; una nota, unos cientos).
const maximoLargoDeCelda = 1000;

/// Hojas que se nombran en el mensaje cuando falta la pedida.
const _hojasEnElMensaje = 10;

final _letrasDeColumna = RegExp(r'^[A-Z]+');

// -------------------------------------------------------------------- errores

/// Error al leer el archivo, con un mensaje para la interfaz.
class ErrorArchivo implements Exception {
  const ErrorArchivo(this.mensaje);

  final String mensaje;

  @override
  String toString() => mensaje;
}

const _noEsXlsx = ErrorArchivo('No es un libro de Excel (.xlsx).');
const _danado = ErrorArchivo('El archivo de Excel está dañado.');

// ------------------------------------------------------------------------ ZIP

class _EntradaZip {
  const _EntradaZip({
    required this.inicio,
    required this.comprimido,
    required this.descomprimido,
    required this.metodo,
  });

  /// Dónde empiezan sus datos dentro de los bytes del archivo.
  final int inicio;
  final int comprimido;

  /// Tamaño descomprimido que **dice** el directorio central (no se confía:
  /// el tope se aplica a lo que realmente sale).
  final int descomprimido;
  final int metodo;
}

/// Recibe los pedazos que va soltando el descompresor y corta al pasar el tope.
class _SumideroConTope implements Sink<List<int>> {
  _SumideroConTope(this.tope);

  final int tope;
  final _salida = BytesBuilder();

  @override
  void add(List<int> datos) {
    if (_salida.length + datos.length > tope) {
      throw const ErrorArchivo(
        'El archivo se expande demasiado al abrirlo: no es la plantilla.',
      );
    }
    _salida.add(datos);
  }

  @override
  void close() {}

  Uint8List get bytes => _salida.takeBytes();
}

/// Un ZIP abierto: solo su índice. Los componentes se descomprimen uno a uno,
/// cuando se piden, y dentro del presupuesto total de bytes.
class _Zip {
  _Zip(this._bytes, this._entradas);

  final Uint8List _bytes;
  final Map<String, _EntradaZip> _entradas;
  var _entregados = 0;

  bool contiene(String nombre) => _entradas.containsKey(nombre);

  Uint8List? leer(String nombre) {
    final e = _entradas[nombre];
    if (e == null) return null;
    final restante = maximoBytesDescomprimidos - _entregados;
    final tope = math.min(maximoBytesPorComponente, restante);
    if (e.descomprimido > tope && e.metodo == 0) {
      throw const ErrorArchivo('Un componente del archivo es demasiado grande.');
    }
    final crudo = Uint8List.sublistView(_bytes, e.inicio, e.inicio + e.comprimido);
    final Uint8List datos;
    if (e.metodo == 0) {
      if (crudo.length > tope) {
        throw const ErrorArchivo('Un componente del archivo es demasiado grande.');
      }
      datos = crudo;
    } else {
      datos = _inflar(crudo, tope);
    }
    if (datos.length > bytesSinRevisarRazon &&
        datos.length > e.comprimido * razonMaximaDeCompresion) {
      throw const ErrorArchivo(
        'El archivo está comprimido de forma sospechosa: no es la plantilla.',
      );
    }
    _entregados += datos.length;
    return datos;
  }

  /// Descomprime "deflate" crudo por pedazos, sin pasar de [tope] bytes.
  static Uint8List _inflar(Uint8List crudo, int tope) {
    final sumidero = _SumideroConTope(tope);
    try {
      final conversor = ZLibDecoder(raw: true).startChunkedConversion(sumidero);
      conversor.add(crudo);
      conversor.close();
    } on ErrorArchivo {
      rethrow;
    } catch (_) {
      throw _danado;
    }
    return sumidero.bytes;
  }
}

/// Lee el directorio central de un ZIP (solo "guardado" y "deflate", que es lo
/// que usan Excel y LibreOffice) y revisa que cada componente `.xml` o
/// `.rels` quepa de verdad dentro del archivo.
_Zip _abrirZip(Uint8List bytes) {
  if (bytes.length < 22) throw _noEsXlsx;
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
  if (fin < 0) throw _noEsXlsx;
  final totalEntradas = u16(fin + 10);
  var p = u32(fin + 16);
  if (totalEntradas == 0xFFFF || p == 0xFFFFFFFF) {
    throw const ErrorArchivo('Este tipo de archivo ZIP no se puede leer.');
  }
  if (totalEntradas > maximoEntradasZip) {
    throw const ErrorArchivo(
      'El archivo tiene demasiados componentes para ser la plantilla.',
    );
  }
  final entradas = <String, _EntradaZip>{};
  for (var n = 0; n < totalEntradas; n++) {
    if (p < 0 || p + 46 > bytes.length || u32(p) != 0x02014b50) throw _danado;
    final banderas = u16(p + 8);
    final metodo = u16(p + 10);
    final comprimido = u32(p + 20);
    final descomprimido = u32(p + 24);
    final largoNombre = u16(p + 28);
    final largoExtra = u16(p + 30);
    final largoComentario = u16(p + 32);
    final local = u32(p + 42);
    if (p + 46 + largoNombre > bytes.length) throw _danado;
    final nombre = utf8.decode(
      Uint8List.sublistView(bytes, p + 46, p + 46 + largoNombre),
      allowMalformed: true,
    );
    p += 46 + largoNombre + largoExtra + largoComentario;
    if (!nombre.endsWith('.xml') && !nombre.endsWith('.rels')) continue;
    if (banderas & 1 != 0) {
      throw const ErrorArchivo('El archivo está protegido con contraseña.');
    }
    if (metodo != 0 && metodo != 8) {
      throw const ErrorArchivo(
        'El archivo usa una compresión que no se puede leer.',
      );
    }
    if (local + 30 > bytes.length || u32(local) != 0x04034b50) throw _danado;
    final inicio = local + 30 + u16(local + 26) + u16(local + 28);
    // El tamaño comprimido que declara el directorio no puede salirse del
    // archivo (un archivo dañado o que miente).
    if (inicio > bytes.length || inicio + comprimido > bytes.length) {
      throw _danado;
    }
    entradas.putIfAbsent(
      nombre,
      () => _EntradaZip(
        inicio: inicio,
        comprimido: comprimido,
        descomprimido: descomprimido,
        metodo: metodo,
      ),
    );
  }
  return _Zip(bytes, entradas);
}

// ---------------------------------------------------------- escáner de XML

/// Una etiqueta de apertura encontrada por el escáner.
class _Apertura {
  const _Apertura(this.inicio, this.fin, this.atributos, this.autocerrada);

  /// Posición del `<`.
  final int inicio;

  /// Posición del `>`.
  final int fin;
  final String atributos;
  final bool autocerrada;
}

bool _esEspacioOCierre(int c) =>
    c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D || c == 0x3E || c == 0x2F;

/// La primera apertura `<nombre …>` desde [desde] (no confunde `<c` con
/// `<col` ni `<t` con `<tableParts`). `null` si no hay más. Una etiqueta sin
/// su `>` es un archivo dañado.
_Apertura? _abrir(String xml, String nombre, int desde) {
  final marca = '<$nombre';
  var i = desde;
  while (true) {
    i = xml.indexOf(marca, i);
    if (i < 0) return null;
    final j = i + marca.length;
    if (j >= xml.length) throw _danado;
    if (_esEspacioOCierre(xml.codeUnitAt(j))) break;
    i = j;
  }
  final fin = xml.indexOf('>', i);
  if (fin < 0) throw _danado;
  final autocerrada = xml.codeUnitAt(fin - 1) == 0x2F;
  final atributos = xml.substring(
    i + marca.length,
    autocerrada ? fin - 1 : fin,
  );
  return _Apertura(i, fin, atributos, autocerrada);
}

/// Recorre, en una sola pasada, los bloques `<nombre …>contenido</nombre>` de
/// [xml]. Una apertura sin su cierre es un archivo dañado y se rechaza de
/// inmediato (no se vuelve a buscar el cierre por cada apertura).
Iterable<({String atributos, String contenido})> _bloques(
  String xml,
  String nombre,
) sync* {
  final cierre = '</$nombre>';
  var pos = 0;
  while (true) {
    final a = _abrir(xml, nombre, pos);
    if (a == null) return;
    if (a.autocerrada) {
      yield (atributos: a.atributos, contenido: '');
      pos = a.fin + 1;
      continue;
    }
    final fin = xml.indexOf(cierre, a.fin + 1);
    if (fin < 0) throw _danado;
    yield (atributos: a.atributos, contenido: xml.substring(a.fin + 1, fin));
    pos = fin + cierre.length;
  }
}

final _expresionesDeAtributos = <String, RegExp>{};

String? _atributo(String atributos, String nombre) {
  final expresion = _expresionesDeAtributos.putIfAbsent(
    nombre,
    () => RegExp('(?<![\\w:.-])${RegExp.escape(nombre)}\\s*=\\s*"([^"]*)"'),
  );
  return expresion.firstMatch(atributos)?.group(1);
}

/// Texto de las corridas `<t>` de un bloque (`<si>` o `<is>`).
String _textoDeRuns(String xml) {
  final b = StringBuffer();
  for (final t in _bloques(xml, 't')) {
    b.write(desescaparXml(t.contenido));
    if (b.length > maximoLargoDeCelda * 4) break;
  }
  return b.toString();
}

/// Revisa el largo de una celda ya leída.
String _celdaValida(String texto) {
  if (texto.length > maximoLargoDeCelda) {
    throw const ErrorArchivo(
      'Una celda tiene demasiado texto: no es la plantilla.',
    );
  }
  return texto;
}

// ------------------------------------------------------------------ el libro

/// Un libro de Excel ya abierto.
class LibroXlsx {
  LibroXlsx._(this._zip, this._hojas);

  final _Zip _zip;

  /// Nombre de la hoja → ruta de su XML dentro del ZIP.
  final Map<String, String> _hojas;
  List<String>? _compartidas;

  List<String> get hojas => _hojas.keys.toList();

  /// La hoja [nombre] (sin importar acentos ni mayúsculas) como tabla de
  /// texto. Lanza [ErrorArchivo] si no existe o el archivo no es válido.
  List<List<String>> hoja(String nombre) {
    final clave = normalizarNombre(nombre);
    final entrada = _hojas.entries
        .where((e) => normalizarNombre(e.key) == clave)
        .firstOrNull;
    if (entrada == null) {
      final nombres = [
        for (final h in hojas.take(_hojasEnElMensaje))
          h.length > 40 ? '${h.substring(0, 40)}…' : h,
      ];
      throw ErrorArchivo(
        'El archivo no tiene la hoja "${nombre.length > 40 ? nombre.substring(0, 40) : nombre}". '
        'Hojas: ${nombres.join(', ')}${hojas.length > _hojasEnElMensaje ? '…' : ''}.',
      );
    }
    return _filas(_texto(entrada.value), _cadenas());
  }

  String _texto(String ruta) {
    final datos = _zip.leer(ruta);
    if (datos == null) {
      throw const ErrorArchivo('El archivo está incompleto: falta una hoja.');
    }
    return utf8.decode(datos, allowMalformed: true);
  }

  List<String> _cadenas() => _compartidas ??= () {
    if (!_zip.contiene('xl/sharedStrings.xml')) return <String>[];
    final xml = _texto('xl/sharedStrings.xml');
    return [
      for (final si in _bloques(xml, 'si')) _celdaValida(_textoDeRuns(si.contenido)),
    ];
  }();

  static int _columna(String referencia) {
    var n = 0;
    for (final c in referencia.codeUnits) {
      if (c < 65 || c > 90) break;
      n = n * 26 + (c - 64);
      if (n > maximoColumnas * 30) break; // no crece sin fin con "ZZZZZZ…"
    }
    return n - 1;
  }

  static List<List<String>> _filas(String xml, List<String> cadenas) {
    final filas = <List<String>>[];
    for (final fila in _bloques(xml, 'row')) {
      final numero = int.tryParse(_atributo(fila.atributos, 'r') ?? '');
      if (numero != null && numero > maximoFilas) {
        throw const ErrorArchivo(
          'La hoja tiene demasiadas filas: no es la plantilla.',
        );
      }
      final celdas = <int, String>{};
      var siguiente = 0;
      for (final c in _bloques(fila.contenido, 'c')) {
        final ref = _letrasDeColumna
            .firstMatch(_atributo(c.atributos, 'r') ?? '')
            ?.group(0);
        final col = ref == null ? siguiente : _columna(ref);
        if (col < 0 || col >= maximoColumnas) {
          throw const ErrorArchivo(
            'La hoja tiene demasiadas columnas: no es la plantilla.',
          );
        }
        siguiente = col + 1;
        final tipo = _atributo(c.atributos, 't');
        final v = _bloques(c.contenido, 'v').firstOrNull?.contenido;
        final texto = switch (tipo) {
          's' => _cadenaCompartida(v, cadenas),
          'inlineStr' => _textoDeRuns(c.contenido),
          _ => v == null ? '' : desescaparXml(v),
        };
        celdas[col] = _celdaValida(texto);
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
      if (filas.length > maximoFilas) {
        throw const ErrorArchivo(
          'La hoja tiene demasiadas filas: no es la plantilla.',
        );
      }
    }
    return filas;
  }

  static String _cadenaCompartida(String? v, List<String> cadenas) {
    if (v == null) return '';
    final i = int.tryParse(v.trim());
    if (i == null || i < 0 || i >= cadenas.length) {
      throw const ErrorArchivo(
        'El archivo está dañado: una celda apunta a un texto que no existe.',
      );
    }
    return cadenas[i];
  }
}

/// `&amp;` → `&`, `&#241;` → `ñ`… Una referencia de carácter imposible
/// (fuera de Unicode o un sustituto) es un archivo dañado; los caracteres de
/// control, que Excel nunca escribe, se descartan.
String desescaparXml(String texto) => texto.replaceAllMapped(
  RegExp(r'&(#x[0-9a-fA-F]+|#\d+|amp|lt|gt|quot|apos);'),
  (m) {
    final e = m.group(1)!;
    if (e.startsWith('#')) {
      final codigo = e.startsWith('#x')
          ? int.tryParse(e.substring(2), radix: 16)
          : int.tryParse(e.substring(1));
      if (codigo == null ||
          codigo > 0x10FFFF ||
          (codigo >= 0xD800 && codigo <= 0xDFFF)) {
        throw const ErrorArchivo(
          'El archivo trae un carácter que no es válido.',
        );
      }
      if (codigo < 0x20 && codigo != 0x09 && codigo != 0x0A && codigo != 0x0D) {
        return '';
      }
      return String.fromCharCode(codigo);
    }
    return const {
      'amp': '&',
      'lt': '<',
      'gt': '>',
      'quot': '"',
      'apos': "'",
    }[e]!;
  },
);

/// Abre un `.xlsx` desde sus bytes. Lanza [ErrorArchivo] si no lo es o si
/// pasa alguno de los topes de este archivo.
LibroXlsx leerXlsx(Uint8List bytes) {
  final zip = _abrirZip(bytes);
  final workbook = zip.leer('xl/workbook.xml');
  final rels = zip.leer('xl/_rels/workbook.xml.rels');
  if (workbook == null || rels == null) throw _noEsXlsx;
  final destinos = <String, String>{};
  for (final r in _bloques(utf8.decode(rels, allowMalformed: true), 'Relationship')) {
    // Un destino externo (otro libro, una URL) nunca se sigue.
    if ((_atributo(r.atributos, 'TargetMode') ?? '').toLowerCase() == 'external') {
      continue;
    }
    final id = _atributo(r.atributos, 'Id');
    final destino = _atributo(r.atributos, 'Target');
    if (id != null && destino != null) destinos[id] = destino;
  }
  final hojas = <String, String>{};
  for (final h in _bloques(utf8.decode(workbook, allowMalformed: true), 'sheet')) {
    final nombre = _atributo(h.atributos, 'name');
    final id = _atributo(h.atributos, 'r:id');
    final destino = id == null ? null : destinos[id];
    if (nombre == null || destino == null) continue;
    final ruta = destino.startsWith('/') ? destino.substring(1) : 'xl/$destino';
    hojas[desescaparXml(nombre)] = ruta;
    if (hojas.length > maximoHojas) {
      throw const ErrorArchivo('El libro tiene demasiadas hojas.');
    }
  }
  return LibroXlsx._(zip, hojas);
}

// --------------------------------------------------------------- tabla y CSV

/// Lee la tabla de la hoja [hoja] de un `.xlsx`, o el CSV completo, según el
/// nombre del archivo. Solo `.xlsx` y `.csv`.
List<List<String>> tablaDeArchivo(
  Uint8List bytes, {
  required String nombreArchivo,
  String hoja = 'Categorías',
}) {
  final nombre = nombreArchivo.toLowerCase();
  if (nombre.endsWith('.csv')) {
    // Antes de armar nada: un "CSV" de millones de renglones vacíos.
    var saltos = 0;
    for (final b in bytes) {
      if (b == 0x0A || b == 0x0D) saltos++;
      if (saltos > maximoFilas * 2 + 2) {
        throw const ErrorArchivo(
          'El archivo tiene demasiadas filas: no es la plantilla.',
        );
      }
    }
    final tabla = leerCsv(utf8.decode(bytes, allowMalformed: true));
    if (tabla.length > maximoFilas) {
      throw const ErrorArchivo(
        'El archivo tiene demasiadas filas: no es la plantilla.',
      );
    }
    for (final fila in tabla) {
      if (fila.length > maximoColumnas) {
        throw const ErrorArchivo(
          'El archivo tiene demasiadas columnas: no es la plantilla.',
        );
      }
      for (final celda in fila) {
        _celdaValida(celda);
      }
    }
    return tabla;
  }
  if (nombre.endsWith('.xlsx')) return leerXlsx(bytes).hoja(hoja);
  throw const ErrorArchivo('Elige un archivo .xlsx o .csv.');
}

/// Lee los bytes de un `.xlsx` o `.csv` ([nombre] decide el formato) y
/// devuelve la hoja Categorías ya leída. Es lo que usa el selector de archivos:
/// el sistema entrega el nombre y los bytes, no una ruta que se pueda abrir
/// (en Android es un `content://`). Todo fallo sale como [ErrorArchivo].
LecturaPlantilla leerPlantillaDeBytes(
  Uint8List bytes, {
  required String nombre,
  String hoja = 'Categorías',
}) {
  if (bytes.length > maximoBytesDeImportacion) {
    throw const ErrorArchivo('El archivo pesa más de 10 MB: no es la plantilla.');
  }
  try {
    return leerPlantillaCategorias(
      tablaDeArchivo(bytes, nombreArchivo: nombre, hoja: hoja),
    );
  } on ErrorArchivo {
    rethrow;
  } on ErrorPlantilla catch (e) {
    throw ErrorArchivo(e.mensaje);
  } catch (_) {
    // Sin trazas ni detalles del archivo: un formato que no se entiende.
    throw const ErrorArchivo(
      'No pude leer el archivo: está dañado o no es la plantilla.',
    );
  }
}

/// Lee un archivo del disco por su ruta y devuelve la hoja Categorías ya
/// leída (para pruebas y herramientas; la app usa el selector de archivos).
Future<LecturaPlantilla> leerPlantillaDeRuta(
  String ruta, {
  String hoja = 'Categorías',
}) async {
  final archivo = File(ruta.trim());
  if (!await archivo.exists()) {
    throw ErrorArchivo('No encontré el archivo: ${archivo.path}');
  }
  if (await archivo.length() > maximoBytesDeImportacion) {
    throw const ErrorArchivo('El archivo pesa más de 10 MB: no es la plantilla.');
  }
  return leerPlantillaDeBytes(
    await archivo.readAsBytes(),
    nombre: archivo.path,
    hoja: hoja,
  );
}
