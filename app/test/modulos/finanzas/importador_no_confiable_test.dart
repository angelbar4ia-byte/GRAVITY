// Importar datos trata el archivo elegido como NO CONFIABLE (revisión de
// calidad de la Fase 1b, hallazgos X1 a X5; `lector_xlsx.dart`): topes de lo
// que se descomprime, de filas, columnas y celdas, tiempo lineal, tamaño
// revisado antes de leer y errores claros. Estas pruebas completan las de
// calidad (`f1b_importar_no_confiable_test.dart`) con los demás topes y con el
// archivo semilla real. Datos de ejemplo inventados.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/finanzas/importacion/lector_xlsx.dart';
import 'package:gravity/modulos/finanzas/pantallas/laptop/importar.dart'
    show elegirArchivoDelSistema;

import '../../revision_calidad/ayuda_zip.dart';

/// Un archivo cuyo tamaño no se sabe y cuyos pedazos se cuentan.
final class _ArchivoSinTamano extends PlatformFile {
  _ArchivoSinTamano(this.pedazos, this.tamanoPedazo);

  final int pedazos;
  final int tamanoPedazo;
  int pedidos = 0;

  @override
  String get name => 'sin_tamano.xlsx';

  @override
  Uri get uri => Uri.file('/tmp/sin_tamano.xlsx');

  @override
  get xFile => throw UnimplementedError();

  @override
  int? lengthSync() => null;

  @override
  Future<int?> length() async => null;

  @override
  Future<Uint8List> readAsBytes() async =>
      throw StateError('no debe leerse entero');

  @override
  Stream<Uint8List> readAsByteStream() async* {
    for (var i = 0; i < pedazos; i++) {
      pedidos++;
      yield Uint8List(tamanoPedazo);
    }
  }
}

class _SelectorFalso extends FilePickerPlatform {
  _SelectorFalso(this.archivo);

  final PlatformFile archivo;

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async => archivo;
}

String _hoja(String filas) =>
    '<worksheet><sheetData>$filas</sheetData></worksheet>';

String _fila(int n, List<String> celdas) =>
    '<row r="$n">${[for (var i = 0; i < celdas.length; i++) '<c r="${String.fromCharCode(65 + i)}$n" t="inlineStr"><is><t>${celdas[i]}</t></is></c>'].join()}</row>';

Uint8List _libro(String filas) =>
    libroConHoja(utf8.encode(_hoja(_fila(1, ['Categoría (nivel 1)']) + filas)));

/// Cambia un campo de 16 bits del directorio central de la entrada [indice].
Uint8List _parcharCentral(
  Uint8List zip,
  int indice,
  int desplazamiento,
  int valor,
) {
  final copia = Uint8List.fromList(zip);
  final datos = ByteData.sublistView(copia);
  var encontradas = -1;
  for (var i = 0; i + 46 < copia.length; i++) {
    if (datos.getUint32(i, Endian.little) == 0x02014b50) {
      encontradas++;
      if (encontradas == indice) {
        datos.setUint16(i + desplazamiento, valor, Endian.little);
        return copia;
      }
    }
  }
  throw StateError('no hay entrada $indice');
}

void _noFiltraDetalles(Object error) {
  expect(error, isA<ErrorArchivo>());
  final m = (error as ErrorArchivo).mensaje;
  for (final malo in [
    'Exception',
    'RangeError',
    'FormatException',
    'StateError',
    '#0',
    '/home',
    'dart:',
  ]) {
    expect(m, isNot(contains(malo)), reason: m);
  }
  expect(m.length, lessThan(300));
}

ErrorArchivo _falla(Uint8List bytes, {String nombre = 'a.xlsx'}) {
  try {
    leerPlantillaDeBytes(bytes, nombre: nombre);
  } on ErrorArchivo catch (e) {
    return e;
  }
  fail('debió rechazarse');
}

void main() {
  group('El archivo semilla real sigue importando', () {
    test('por bytes y por ruta da la misma lectura', () async {
      final archivo = File('../data/DATOS_SEMILLA_PRESUPUESTO.xlsx');
      final porBytes = leerPlantillaDeBytes(
        await archivo.readAsBytes(),
        nombre: 'DATOS_SEMILLA_PRESUPUESTO.xlsx',
      );
      final porRuta = await leerPlantillaDeRuta(archivo.path);
      expect(porBytes.filasLeidas, greaterThan(100));
      expect(
        porBytes.filas.map((f) => f.toString()).toList(),
        porRuta.filas.map((f) => f.toString()).toList(),
      );
      // Lee una fracción de los topes.
      expect(await archivo.length(), lessThan(maximoBytesDeImportacion ~/ 100));
    });
  });

  group('Topes de filas, columnas y celdas', () {
    test(
      'una celda de $maximoLargoDeCelda caracteres pasa; una de más, no',
      () {
        Uint8List conCelda(int n) => _libro(_fila(2, ['a' * n]));
        expect(
          () => leerPlantillaDeBytes(
            conCelda(maximoLargoDeCelda),
            nombre: 'a.xlsx',
          ),
          returnsNormally,
        );
        _noFiltraDetalles(_falla(conCelda(maximoLargoDeCelda + 1)));
      },
    );

    test('una cadena compartida demasiado larga también se rechaza', () {
      final zip = libroConHoja(
        utf8.encode(_hoja('<row r="1"><c r="A1" t="s"><v>0</v></c></row>')),
        cadenasXml:
            '<sst><si><t>${'a' * (maximoLargoDeCelda + 1)}</t></si></sst>',
      );
      _noFiltraDetalles(_falla(zip));
    });

    test('hasta $maximoFilas filas; una más, no', () {
      expect(
        () => leerPlantillaDeBytes(
          libroConHoja(utf8.encode(_hoja(_fila(maximoFilas, ['x'])))),
          nombre: 'a.xlsx',
        ),
        throwsA(
          isA<ErrorArchivo>().having(
            (e) => e.mensaje,
            'mensaje',
            isNot(contains('demasiadas')),
          ),
        ),
        reason: 'la fila 100000 cabe (el error es de la plantilla sin encabezado, no del tope)',
      );
      _noFiltraDetalles(
        _falla(libroConHoja(utf8.encode(_hoja(_fila(maximoFilas + 1, ['x']))))),
      );
    });

    test('una columna lejana (ZZ) se rechaza; una normal, no', () {
      final lejana = libroConHoja(
        utf8.encode(
          _hoja(
            '<row r="1"><c r="A1" t="inlineStr"><is><t>Categoría (nivel 1)</t></is></c>'
            '<c r="ZZ1" t="inlineStr"><is><t>x</t></is></c></row>',
          ),
        ),
      );
      _noFiltraDetalles(_falla(lejana));
      expect(
        () => leerPlantillaDeBytes(_libro(''), nombre: 'a.xlsx'),
        returnsNormally,
      );
    });

    test('un CSV con millones de renglones vacíos se rechaza sin armarlos', () {
      final csv = Uint8List.fromList(List.filled(maximoFilas * 2 + 100, 0x0A));
      _noFiltraDetalles(_falla(csv, nombre: 'a.csv'));
    });

    test('un CSV con una celda enorme se rechaza', () {
      final csv = Uint8List.fromList(
        utf8.encode('Categoría (nivel 1)\n${'a' * (maximoLargoDeCelda + 1)}\n'),
      );
      _noFiltraDetalles(_falla(csv, nombre: 'a.csv'));
    });
  });

  group('Topes de lo que se descomprime', () {
    test('un componente guardado sin comprimir de más de 4 MiB se rechaza', () {
      final grande = libroConHoja(
        utf8.encode(hojaSencilla()),
        extras: [
          EntradaZip(
            'xl/otro.xml',
            Uint8List(maximoBytesPorComponente + 1),
            comprimir: false,
          ),
        ],
      );
      // El componente de más no se pide, así que el libro se lee igual.
      expect(
        () => leerPlantillaDeBytes(grande, nombre: 'a.xlsx'),
        returnsNormally,
      );
      final sheetGrande = construirZip([
        EntradaZip(
          'xl/workbook.xml',
          utf8.encode(
            '<workbook xmlns:r="x"><sheets><sheet name="Categorías" sheetId="1" r:id="rId1"/></sheets></workbook>',
          ),
        ),
        EntradaZip(
          'xl/_rels/workbook.xml.rels',
          utf8.encode(
            '<Relationships><Relationship Id="rId1" Target="worksheets/sheet1.xml"/></Relationships>',
          ),
        ),
        EntradaZip(
          'xl/worksheets/sheet1.xml',
          Uint8List(maximoBytesPorComponente + 1),
          comprimir: false,
        ),
      ]);
      _noFiltraDetalles(_falla(sheetGrande));
    });

    test('el total descomprimido tiene tope: dos componentes grandes juntos pasan de 6 MiB', () {
      final relleno = '<!--${'a' * (3 * 1024 * 1024 + 512 * 1024)}-->';
      final zip = construirZip([
        EntradaZip(
          'xl/workbook.xml',
          utf8.encode(
            '<workbook xmlns:r="x"><sheets><sheet name="Categorías" sheetId="1" r:id="rId1"/></sheets></workbook>',
          ),
        ),
        EntradaZip(
          'xl/_rels/workbook.xml.rels',
          utf8.encode(
            '<Relationships><Relationship Id="rId1" Target="worksheets/sheet1.xml"/></Relationships>',
          ),
        ),
        EntradaZip(
          'xl/sharedStrings.xml',
          utf8.encode('<sst><si><t>x</t></si>$relleno</sst>'),
          comprimir: false,
        ),
        EntradaZip(
          'xl/worksheets/sheet1.xml',
          utf8.encode(
            '${_hoja('<row r="1"><c r="A1" t="s"><v>0</v></c></row>')}$relleno',
          ),
          comprimir: false,
        ),
      ]);
      _noFiltraDetalles(_falla(zip));
    });

    test(
      'un componente que comprime más de 100 a 1 (y pasa de 256 KB) se rechaza',
      () {
        final zip = libroConHoja(
          utf8.encode('${hojaSencilla()}<!--${'a' * (300 * 1024)}-->'),
        );
        expect(zip.length, lessThan(5 * 1024));
        final e = _falla(zip);
        expect(e.mensaje, contains('comprimido'));
        _noFiltraDetalles(e);
      },
    );

    test('un ZIP con demasiados componentes se rechaza', () {
      final muchos = libroConHoja(
        utf8.encode(hojaSencilla()),
        extras: [
          for (var i = 0; i < maximoEntradasZip; i++)
            EntradaZip('xl/x$i.xml', const [60, 120, 47, 62]),
        ],
      );
      final e = _falla(muchos);
      expect(e.mensaje, contains('demasiados componentes'));
    });
  });

  group('Archivos dañados, protegidos o que no son lo que dicen', () {
    test('un componente protegido con contraseña se explica', () {
      final zip = _parcharCentral(_libro(''), 0, 8, 1);
      final e = _falla(zip);
      expect(e.mensaje, contains('contraseña'));
    });

    test(
      'datos que dicen estar comprimidos y no lo están dan un error claro',
      () {
        final base = construirZip([
          EntradaZip(
            'xl/workbook.xml',
            Uint8List.fromList(List.generate(200, (i) => (i * 37 + 11) & 0xff)),
            comprimir: false,
          ),
          EntradaZip(
            'xl/_rels/workbook.xml.rels',
            utf8.encode('<Relationships/>'),
          ),
        ]);
        final zip = _parcharCentral(base, 0, 10, 8); // dice "deflate"
        _noFiltraDetalles(_falla(zip));
      },
    );

    test('truncado, vacío, aleatorio o un ZIP cualquiera: siempre ErrorArchivo '
        'sin detalles', () {
      final valido = _libro('');
      final casos = <String, Uint8List>{
        'vacío': Uint8List(0),
        'corto': Uint8List(21),
        'truncado': valido.sublist(0, valido.length - 30),
        'a la mitad': valido.sublist(0, valido.length ~/ 2),
        'aleatorio': Uint8List.fromList(
          List.generate(5000, (i) => (i * 7919 + 13) & 0xff),
        ),
        'ceros': Uint8List(70000),
      };
      for (final c in casos.entries) {
        final e = _falla(c.value);
        _noFiltraDetalles(e);
        expect(e.mensaje, isNotEmpty, reason: c.key);
      }
    });

    test('el directorio central no puede apuntar fuera del archivo', () {
      final valido = _libro('');
      final datos = ByteData.sublistView(valido);
      // Mueve el inicio del directorio central muy lejos.
      var fin = -1;
      for (var i = valido.length - 22; i >= 0; i--) {
        if (datos.getUint32(i, Endian.little) == 0x06054b50) {
          fin = i;
          break;
        }
      }
      final roto = Uint8List.fromList(valido);
      ByteData.sublistView(roto)
          .setUint32(fin + 16, valido.length + 1000, Endian.little);
      _noFiltraDetalles(_falla(roto));
    });
  });

  group('Nada se sigue ni se ejecuta', () {
    test('una relación externa nunca se sigue: la hoja no existe', () {
      final zip = construirZip([
        EntradaZip(
          'xl/workbook.xml',
          utf8.encode(
            '<workbook xmlns:r="x"><sheets><sheet name="Categorías" sheetId="1" r:id="rId1"/></sheets></workbook>',
          ),
        ),
        EntradaZip(
          'xl/_rels/workbook.xml.rels',
          utf8.encode(
            '<Relationships><Relationship Id="rId1" Target="http://malo.example/x.xml" TargetMode="External"/></Relationships>',
          ),
        ),
      ]);
      final e = _falla(zip);
      expect(e.mensaje, contains('no tiene la hoja'));
      expect(e.mensaje, isNot(contains('malo.example')));
    });

    test('el nombre de una hoja enorme no infla el mensaje de error', () {
      final nombre = 'H' * 5000;
      final zip = construirZip([
        EntradaZip(
          'xl/workbook.xml',
          utf8.encode(
            '<workbook xmlns:r="x"><sheets><sheet name="$nombre" sheetId="1" r:id="rId1"/></sheets></workbook>',
          ),
        ),
        EntradaZip(
          'xl/_rels/workbook.xml.rels',
          utf8.encode(
            '<Relationships><Relationship Id="rId1" Target="worksheets/sheet1.xml"/></Relationships>',
          ),
        ),
        EntradaZip('xl/worksheets/sheet1.xml', utf8.encode(hojaSencilla())),
      ]);
      expect(_falla(zip).mensaje.length, lessThan(200));
    });

    test('las entidades del archivo no se expanden (no hay DTD)', () {
      final hoja =
          '<!DOCTYPE x [<!ENTITY a "bomba">]>'
          '${_hoja(_fila(1, ['Categoría (nivel 1)']) + _fila(2, ['&a;']))}';
      final r = leerPlantillaDeBytes(
        libroConHoja(utf8.encode(hoja)),
        nombre: 'a.xlsx',
      );
      final todo = r.filas.map((f) => f.toString()).join('|');
      expect(todo, isNot(contains('bomba')));
      expect(todo, contains('&a;'), reason: 'queda como texto');
    });

    test('etiquetas vecinas no se confunden: <cols>, <col>, <rowBreaks>', () {
      final hoja =
          '<worksheet><cols><col min="1" max="1" width="9"/></cols><sheetData>'
          '${_fila(1, ['Categoría (nivel 1)'])}${_fila(2, ['Transporte'])}'
          '</sheetData><rowBreaks count="0"/></worksheet>';
      final r = leerPlantillaDeBytes(
        libroConHoja(utf8.encode(hoja)),
        nombre: 'a.xlsx',
      );
      expect(r.filas.single.nivel1, 'Transporte');
    });
  });

  group('desescaparXml', () {
    test('caracteres normales, de control e imposibles', () {
      expect(
        desescaparXml('a &amp; b &lt;c&gt; &#233; &#xE9;'),
        'a & b <c> é é',
      );
      expect(
        desescaparXml('x&#1;y'),
        'xy',
        reason: 'los de control se descartan',
      );
      expect(desescaparXml('a&#10;b'), 'a\nb');
      for (final malo in [
        '&#xD800;',
        '&#1114112;',
        '&#99999999;',
        '&#xFFFFFFFFFFFFFFFFFFFF;',
      ]) {
        expect(
          () => desescaparXml(malo),
          throwsA(isA<ErrorArchivo>()),
          reason: malo,
        );
      }
    });
  });

  group('El selector de archivos', () {
    Future<(Object?, int)> elegir(_ArchivoSinTamano archivo) async {
      final original = FilePickerPlatform.instance;
      FilePickerPlatform.instance = _SelectorFalso(archivo);
      try {
        await elegirArchivoDelSistema();
        return (null, archivo.pedidos);
      } catch (e) {
        return (e, archivo.pedidos);
      } finally {
        FilePickerPlatform.instance = original;
      }
    }

    test('si el tamaño no se sabe, deja de leer al pasar el tope', () async {
      final archivo = _ArchivoSinTamano(100, 1024 * 1024);
      final (error, pedidos) = await elegir(archivo);
      expect(error, isA<ErrorArchivo>());
      expect(pedidos, lessThan(15), reason: 'no leyó los 100 MB');
    });

    test('un archivo dentro del tope se entrega completo', () async {
      final archivo = _ArchivoSinTamano(3, 1000);
      final original = FilePickerPlatform.instance;
      FilePickerPlatform.instance = _SelectorFalso(archivo);
      addTearDown(() => FilePickerPlatform.instance = original);
      final elegido = await elegirArchivoDelSistema();
      expect(elegido!.bytes, hasLength(3000));
      expect(elegido.nombre, 'sin_tamano.xlsx');
    });
  });

  group('Tiempo lineal', () {
    test('cientos de miles de aperturas sin cerrar se rechazan al instante', () {
      final hoja =
          '<worksheet><sheetData><row r="1">${'<c r="A1" t="inlineStr">' * 100000}</row></sheetData></worksheet>';
      final reloj = Stopwatch()..start();
      _noFiltraDetalles(_falla(libroConHoja(utf8.encode(hoja))));
      expect(reloj.elapsed, lessThan(const Duration(seconds: 2)));
    });

    test('filas y cadenas compartidas sin cerrar tampoco son cuadráticas', () {
      final filas =
          '<worksheet><sheetData>${'<row r="1">' * 100000}</sheetData></worksheet>';
      final cadenas = '<sst>${'<si><t>x' * 100000}</sst>';
      final reloj = Stopwatch()..start();
      _noFiltraDetalles(_falla(libroConHoja(utf8.encode(filas))));
      _noFiltraDetalles(
        _falla(
          libroConHoja(
            utf8.encode(_hoja('<row r="1"><c r="A1" t="s"><v>0</v></c></row>')),
            cadenasXml: cadenas,
          ),
        ),
      );
      expect(reloj.elapsed, lessThan(const Duration(seconds: 3)));
    });
  });
}
