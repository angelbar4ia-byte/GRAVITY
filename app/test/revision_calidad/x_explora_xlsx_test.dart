import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/finanzas/importacion/lector_xlsx.dart';

import 'ayuda_zip.dart';

void main() {
  test('control: libro sencillo', () {
    final r = leerPlantillaDeBytes(libroConHoja(utf8.encode(hojaSencilla())), nombre: 'a.xlsx');
    print('control filas: ${r.filas.length}');
  });
  test('bomba 100MB', () {
    final sw = Stopwatch()..start();
    final xml = BytesBuilder()
      ..add(utf8.encode('<worksheet><sheetData><row r="1"><c r="A1" t="inlineStr"><is><t>'))
      ..add(Uint8List(100 * 1024 * 1024)..fillRange(0, 100 * 1024 * 1024, 97))
      ..add(utf8.encode('</t></is></c></row></sheetData></worksheet>'));
    final zip = libroConHoja(xml.toBytes());
    print('zip pesa ${zip.length} bytes (${sw.elapsedMilliseconds} ms para armarlo)');
    sw.reset();
    try {
      final r = leerPlantillaDeBytes(zip, nombre: 'b.xlsx');
      print('bomba: leyó ${r.filas.length} filas en ${sw.elapsedMilliseconds} ms');
    } catch (e) {
      print('bomba: ${e.runtimeType} ${'$e'.substring(0, 60.clamp(0, '$e'.length))} en ${sw.elapsedMilliseconds} ms');
    }
  });
  test('tamaño comprimido mentiroso', () {
    final zip = construirZip([
      EntradaZip('xl/workbook.xml', utf8.encode('<workbook/>'), tamanoDeclarado: 5000000),
    ]);
    try {
      leerPlantillaDeBytes(zip, nombre: 'c.xlsx');
      print('mentiroso: sin error');
    } catch (e) {
      print('mentiroso: ${e.runtimeType}');
    }
  });
  test('cadena compartida fuera de rango', () {
    final hoja = '<worksheet><sheetData><row r="1"><c r="A1" t="s"><v>99999</v></c></row></sheetData></worksheet>';
    try {
      leerPlantillaDeBytes(libroConHoja(utf8.encode(hoja), cadenasXml: '<sst><si><t>x</t></si></sst>'), nombre: 'd.xlsx');
      print('fuera de rango: sin error');
    } catch (e) {
      print('fuera de rango: ${e.runtimeType}');
    }
  });
  test('referencia numerica enorme', () {
    final hoja = '<worksheet><sheetData><row r="1"><c r="A1" t="inlineStr"><is><t>&#99999999;</t></is></c></row></sheetData></worksheet>';
    try {
      leerPlantillaDeBytes(libroConHoja(utf8.encode(hoja)), nombre: 'e.xlsx');
      print('ref enorme: sin error');
    } catch (e) {
      print('ref enorme: ${e.runtimeType}');
    }
  });
  test('redos: <c> sin cerrar', () {
    final sw = Stopwatch()..start();
    final n = 40000;
    final hoja = '<worksheet><sheetData><row r="1">${'<c r="A1" t="inlineStr">' * n}</row></sheetData></worksheet>';
    try {
      leerPlantillaDeBytes(libroConHoja(utf8.encode(hoja)), nombre: 'f.xlsx');
      print('redos n=$n: ${sw.elapsedMilliseconds} ms sin error');
    } catch (e) {
      print('redos n=$n: ${e.runtimeType} ${sw.elapsedMilliseconds} ms');
    }
  });
  test('muchas filas', () {
    final sw = Stopwatch()..start();
    final b = StringBuffer('<worksheet><sheetData>');
    b.write('<row r="1"><c r="A1" t="inlineStr"><is><t>Categoría (nivel 1)</t></is></c></row>');
    for (var i = 2; i < 200000; i++) {
      b.write('<row r="$i"><c r="A$i" t="inlineStr"><is><t>Cat $i</t></is></c></row>');
    }
    b.write('</sheetData></worksheet>');
    final r = leerPlantillaDeBytes(libroConHoja(utf8.encode(b.toString())), nombre: 'g.xlsx');
    print('200k filas: ${r.filas.length} filas en ${sw.elapsedMilliseconds} ms');
  });
  test('numero de fila gigante', () {
    final hoja = '<worksheet><sheetData><row r="1"><c r="A1" t="inlineStr"><is><t>Categoría (nivel 1)</t></is></c></row><row r="50000000"><c r="A1" t="inlineStr"><is><t>x</t></is></c></row></sheetData></worksheet>';
    final sw = Stopwatch()..start();
    try {
      final r = leerPlantillaDeBytes(libroConHoja(utf8.encode(hoja)), nombre: 'h.xlsx');
      print('fila 50M: ${r.filas.length} filas, ${sw.elapsedMilliseconds} ms');
    } catch (e) {
      print('fila 50M: ${e.runtimeType} ${sw.elapsedMilliseconds} ms');
    }
  });
}
