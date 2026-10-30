// Revisión de calidad de la Fase 1b: Finanzas › Importar datos (selector de
// archivos, file_picker 13.1.0) trata lo que lee como NO CONFIABLE?
//
// X1 a X5 fallaban a propósito (etiqueta `hallazgo`) y pasaron al endurecer el
// lector (finanzas, Fase 1b); hoy son pruebas de regresión. Los archivos hostiles se arman a
// mano con `ayuda_zip.dart` (Excel nunca los produciría).
//
//  X1  Sin tope de lo que se descomprime: un .xlsx de ~100 KB se expande a cientos
//      de MB (a 10 MB comprimidos, ~10 GB: la app muere por memoria).
//  X2  Un número de fila enorme (`<row r="50000000">`) reserva millones de filas
//      vacías; con 2,000,000,000 son ~16 GB.
//  X3  Una hoja con `<c>` sin cerrar cuesta tiempo cuadrático (el lector corre en el
//      hilo de la pantalla: la app se congela).
//  X4  El selector lee TODO el archivo en memoria antes de comprobar los 10 MB.
//  X5  Un archivo dañado lanza RangeError en lugar de ErrorArchivo.
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/finanzas/importacion/lector_xlsx.dart';
import 'package:gravity/modulos/finanzas/pantallas/laptop/importar.dart'
    show elegirArchivoDelSistema;

import 'ayuda_zip.dart';

/// Un archivo que dice pesar [tamano] y cuenta cuántas veces se leyó entero.
final class _ArchivoGrande extends PlatformFile {
  _ArchivoGrande(this.tamano, this.nombreArchivo);

  final int tamano;
  final String nombreArchivo;
  int lecturasCompletas = 0;

  @override
  String get name => nombreArchivo;

  @override
  Uri get uri => Uri.file('/tmp/$nombreArchivo');

  @override
  get xFile => throw UnimplementedError();

  @override
  int? lengthSync() => tamano;

  @override
  Future<int?> length() async => tamano;

  @override
  Future<Uint8List> readAsBytes() async {
    lecturasCompletas++;
    return Uint8List(16);
  }

  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(Uint8List(16));
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

String _hojaConRelleno(int bytesDeRelleno) {
  // Una hoja válida (un encabezado y una categoría) seguida de un comentario XML
  // enorme y muy repetitivo: comprime ~1000 a 1.
  return '${hojaSencilla()}<!--${'a' * bytesDeRelleno}-->';
}

void main() {
  final valido = libroConHoja(utf8.encode(hojaSencilla('Transporte')));

  group('lo que sí hace bien (guardias)', () {
    test('lee un libro sencillo', () {
      final r = leerPlantillaDeBytes(valido, nombre: 'plantilla.xlsx');
      expect(r.filas.map((f) => f.nivel1), ['Transporte']);
    });

    test('más de 10 MB se rechaza antes de abrirlo', () {
      expect(
        () => leerPlantillaDeBytes(Uint8List(maximoBytesDeImportacion + 1), nombre: 'a.xlsx'),
        throwsA(isA<ErrorArchivo>()),
      );
    });

    test('otras extensiones y archivos que no son ZIP se rechazan con un mensaje', () {
      for (final nombre in ['virus.exe', 'plantilla.xlsm', 'datos', 'a.xls']) {
        expect(() => leerPlantillaDeBytes(valido, nombre: nombre), throwsA(isA<ErrorArchivo>()),
            reason: nombre);
      }
      expect(
        () => leerPlantillaDeBytes(Uint8List.fromList(utf8.encode('esto no es un zip')), nombre: 'a.xlsx'),
        throwsA(isA<ErrorArchivo>()),
      );
    });

    test('las fórmulas no se evalúan: se lee el valor guardado, o el texto tal cual', () {
      final hoja =
          '<worksheet><sheetData>'
          '<row r="1"><c r="A1" t="inlineStr"><is><t>Categoría (nivel 1)</t></is></c></row>'
          '<row r="2"><c r="A2" t="str"><f>HYPERLINK("http://malo","x")</f><v>Valor guardado</v></c></row>'
          '<row r="3"><c r="A3" t="inlineStr"><is><t>=cmd|\' /C calc\'!A0</t></is></c></row>'
          '</sheetData></worksheet>';
      final r = leerPlantillaDeBytes(libroConHoja(utf8.encode(hoja)), nombre: 'f.xlsx');
      final nombres = [for (final f in r.filas) f.nivel1].join('|');
      expect(nombres, contains('Valor guardado'));
      expect(nombres, isNot(contains('HYPERLINK')), reason: 'la fórmula no se lee ni se ejecuta');
      expect(nombres, contains('cmd|'), reason: 'el texto con "=" es solo un nombre, no una orden');
    });

    test('los nombres de entradas del ZIP (../, rutas absolutas) no tocan el disco', () {
      final zip = libroConHoja(
        utf8.encode(hojaSencilla()),
        extras: [
          EntradaZip('../../../../tmp/evil.xml', utf8.encode('<x/>')),
          EntradaZip('/etc/passwd.xml', utf8.encode('<x/>')),
          EntradaZip('xl/media/imagen.png', Uint8List(10)),
        ],
      );
      // Solo se leen en memoria las entradas .xml y .rels; nada se escribe.
      expect(leerPlantillaDeBytes(zip, nombre: 'z.xlsx').filas, isNotEmpty);
    });

    test('un CSV de decenas de miles de filas se lee en un tiempo razonable', () {
      final b = StringBuffer('Categoría (nivel 1)\n');
      for (var i = 0; i < 50000; i++) {
        b.writeln('Categoría $i');
      }
      final reloj = Stopwatch()..start();
      final r = leerPlantillaDeBytes(Uint8List.fromList(utf8.encode(b.toString())), nombre: 'c.csv');
      expect(r.filasLeidas, 50000);
      expect(reloj.elapsed, lessThan(const Duration(seconds: 15)));
    });
  });

  group('X1: sin tope de lo que se descomprime', () {
    test('un .xlsx de ~64 KB que se expande a 64 MB se rechaza', () {
      final zip = libroConHoja(utf8.encode(_hojaConRelleno(64 * 1024 * 1024)));
      expect(zip.length, lessThan(256 * 1024), reason: 'pesa unos KB, pasa el tope de 10 MB');
      expect(
        () => leerPlantillaDeBytes(zip, nombre: 'bomba.xlsx'),
        throwsA(isA<ErrorArchivo>()),
        reason:
            'el lector descomprime cada entrada sin límite (ZLibDecoder.convert en '
            'lector_xlsx.dart:_leerZip) y lee el libro entero: la plantilla pesa '
            'unas decenas de KB, así que un tope de pocos MB descomprimidos basta',
      );
    });
  });

  group('X2: un número de fila enorme reserva memoria', () {
    test('r="50000000" no debe reservar 50 millones de filas', () {
      final hoja =
          '<worksheet><sheetData>'
          '<row r="1"><c r="A1" t="inlineStr"><is><t>Categoría (nivel 1)</t></is></c></row>'
          '<row r="50000000"><c r="A1" t="inlineStr"><is><t>x</t></is></c></row>'
          '</sheetData></worksheet>';
      expect(
        () => leerPlantillaDeBytes(libroConHoja(utf8.encode(hoja)), nombre: 'filas.xlsx'),
        throwsA(isA<ErrorArchivo>()),
        reason:
            'Excel tiene a lo más 1,048,576 filas; el lector rellena con filas vacías '
            'hasta el número de fila declarado (while (filas.length < numero - 1)) y '
            'con r="2000000000" serían ~16 GB',
      );
    });
  });

  group('X3: tiempo cuadrático con celdas sin cerrar', () {
    test('cuadruplicar el tamaño no debe multiplicar el tiempo por 16', () {
      Duration medir(int n) {
        final hoja =
            '<worksheet><sheetData><row r="1">${'<c r="A1" t="inlineStr">' * n}</row></sheetData></worksheet>';
        final zip = libroConHoja(utf8.encode(hoja));
        final reloj = Stopwatch()..start();
        try {
          leerPlantillaDeBytes(zip, nombre: 'redos.xlsx');
        } on ErrorArchivo {
          // El resultado no importa: importa cuánto tarda.
        }
        return reloj.elapsed;
      }

      final chico = medir(10000);
      final grande = medir(40000);
      final razon = grande.inMicroseconds / (chico.inMicroseconds == 0 ? 1 : chico.inMicroseconds);
      expect(
        grande < const Duration(milliseconds: 500) || razon < 9,
        isTrue,
        reason:
            '10,000 celdas sin cerrar: ${chico.inMilliseconds} ms; 40,000: '
            '${grande.inMilliseconds} ms (×${razon.toStringAsFixed(1)}; lineal sería ×4, '
            'cuadrático ×16). La expresión r"<c\\b([^>]*?)(?:/>|>(.*?)</c>)" recorre hasta '
            'el final por cada <c> sin cerrar, y se ejecuta en el hilo de la pantalla',
      );
    });
  });

  group('X4: el selector lee el archivo entero antes de mirar su tamaño', () {
    test('un archivo de 3 GB no se carga en memoria', () async {
      final original = FilePickerPlatform.instance;
      final enorme = _ArchivoGrande(3 * 1024 * 1024 * 1024, 'enorme.xlsx');
      FilePickerPlatform.instance = _SelectorFalso(enorme);
      addTearDown(() => FilePickerPlatform.instance = original);

      Object? error;
      try {
        await elegirArchivoDelSistema();
      } catch (e) {
        error = e;
      }
      expect(
        enorme.lecturasCompletas,
        0,
        reason:
            'elegirArchivoDelSistema llama a readAsBytes() sin mirar lengthSync(): '
            'el tope de 10 MB (maximoBytesDeImportacion) se revisa DESPUÉS de tener '
            'los bytes en memoria. Debe rechazarlo por su tamaño antes de leerlo',
      );
      expect(error, isA<ErrorArchivo>());
    });

    test('control: pide solo .xlsx y .csv', () async {
      final original = FilePickerPlatform.instance;
      final chico = _ArchivoGrande(1024, 'plantilla.xlsx');
      FilePickerPlatform.instance = _SelectorFalso(chico);
      addTearDown(() => FilePickerPlatform.instance = original);
      final elegido = await elegirArchivoDelSistema();
      expect(elegido?.nombre, 'plantilla.xlsx');
    });
  });

  group('X5: un archivo dañado se explica, no lanza RangeError', () {
    final danados = <String, Uint8List>{
      'tamaño comprimido que miente': construirZip([
        EntradaZip('xl/workbook.xml', utf8.encode('<workbook/>'), tamanoDeclarado: 5000000),
      ]),
      'cadena compartida fuera de rango': libroConHoja(
        utf8.encode(
          '<worksheet><sheetData><row r="1"><c r="A1" t="s"><v>99999</v></c></row></sheetData></worksheet>',
        ),
        cadenasXml: '<sst><si><t>x</t></si></sst>',
      ),
      'referencia de carácter imposible': libroConHoja(
        utf8.encode(
          '<worksheet><sheetData><row r="1"><c r="A1" t="inlineStr"><is><t>&#99999999;</t></is></c></row></sheetData></worksheet>',
        ),
      ),
    };
    for (final entrada in danados.entries) {
      test(entrada.key, () {
        expect(
          () => leerPlantillaDeBytes(entrada.value, nombre: 'dañado.xlsx'),
          throwsA(isA<ErrorArchivo>()),
          reason:
              'hoy lanza RangeError; la pantalla lo atrapa y muestra "No pude leer el '
              'archivo: RangeError…", pero el lector promete ErrorArchivo',
        );
      });
    }
  });
}
