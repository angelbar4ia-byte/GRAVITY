/// Arma archivos ZIP a mano (solo para las pruebas de calidad del lector de
/// `.xlsx`): permite fabricar archivos hostiles que Excel nunca produciría.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class EntradaZip {
  EntradaZip(
    this.nombre,
    this.contenido, {
    this.comprimir = true,
    this.tamanoDeclarado,
  });

  final String nombre;
  final List<int> contenido;
  final bool comprimir;

  /// Tamaño comprimido que se escribe en el directorio central (para mentir).
  final int? tamanoDeclarado;
}

/// Un ZIP mínimo con las [entradas] dadas.
Uint8List construirZip(List<EntradaZip> entradas) {
  final salida = BytesBuilder();
  final central = BytesBuilder();
  void u16(BytesBuilder b, int v) => b.add([v & 0xff, (v >> 8) & 0xff]);
  void u32(BytesBuilder b, int v) =>
      b.add([v & 0xff, (v >> 8) & 0xff, (v >> 16) & 0xff, (v >> 24) & 0xff]);

  for (final e in entradas) {
    final nombre = utf8.encode(e.nombre);
    final datos = e.comprimir
        ? ZLibEncoder(raw: true, level: 9).convert(e.contenido)
        : e.contenido;
    final metodo = e.comprimir ? 8 : 0;
    final posicion = salida.length;
    // Encabezado local.
    u32(salida, 0x04034b50);
    u16(salida, 20);
    u16(salida, 0);
    u16(salida, metodo);
    u16(salida, 0);
    u16(salida, 0);
    u32(salida, 0); // crc (el lector no lo revisa)
    u32(salida, datos.length);
    u32(salida, e.contenido.length);
    u16(salida, nombre.length);
    u16(salida, 0);
    salida.add(nombre);
    salida.add(datos);
    // Directorio central.
    u32(central, 0x02014b50);
    u16(central, 20);
    u16(central, 20);
    u16(central, 0);
    u16(central, metodo);
    u16(central, 0);
    u16(central, 0);
    u32(central, 0);
    u32(central, e.tamanoDeclarado ?? datos.length);
    u32(central, e.contenido.length);
    u16(central, nombre.length);
    u16(central, 0);
    u16(central, 0);
    u16(central, 0);
    u16(central, 0);
    u32(central, 0);
    u32(central, posicion);
    central.add(nombre);
  }
  final inicioCentral = salida.length;
  salida.add(central.toBytes());
  u32(salida, 0x06054b50);
  u16(salida, 0);
  u16(salida, 0);
  u16(salida, entradas.length);
  u16(salida, entradas.length);
  u32(salida, central.length);
  u32(salida, inicioCentral);
  u16(salida, 0);
  return salida.toBytes();
}

const _workbook =
    '<workbook xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
    '<sheets><sheet name="Categorías" sheetId="1" r:id="rId1"/></sheets></workbook>';
const _rels =
    '<Relationships><Relationship Id="rId1" Target="worksheets/sheet1.xml"/></Relationships>';

/// Un libro con la hoja "Categorías" cuyo XML es [hojaXml] y, si se da,
/// sharedStrings.
Uint8List libroConHoja(
  List<int> hojaXml, {
  String? cadenasXml,
  List<EntradaZip> extras = const [],
}) => construirZip([
  EntradaZip('xl/workbook.xml', utf8.encode(_workbook)),
  EntradaZip('xl/_rels/workbook.xml.rels', utf8.encode(_rels)),
  if (cadenasXml != null)
    EntradaZip('xl/sharedStrings.xml', utf8.encode(cadenasXml)),
  EntradaZip('xl/worksheets/sheet1.xml', hojaXml),
  ...extras,
]);

/// Una hoja válida con encabezado y una categoría, con celdas en línea.
String hojaSencilla([String categoria = 'Alimentación']) =>
    '<worksheet><sheetData>'
    '<row r="1"><c r="A1" t="inlineStr"><is><t>Categoría (nivel 1)</t></is></c></row>'
    '<row r="2"><c r="A2" t="inlineStr"><is><t>$categoria</t></is></c></row>'
    '</sheetData></worksheet>';
