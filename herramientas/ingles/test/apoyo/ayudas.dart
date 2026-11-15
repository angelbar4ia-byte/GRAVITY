import 'dart:convert';
import 'dart:io';

import 'package:ingles/ingles.dart';

typedef Doc = Map<String, Object?>;

/// Copia profunda: cada caso malo se construye sobre una copia del bueno.
Doc clonar(Doc d) => jsonDecode(jsonEncode(d)) as Doc;

/// Lista y mapa tal como los lee el YAML, para escribir los casos con soltura.
List<Object?> lista(Object? v) => v! as List<Object?>;
Doc mapa(Object? v) => v! as Doc;

Archivo? _contrato;
Archivo? _niveles;
Archivo? _sesion;

Archivo contratoPrueba() => _contrato ??=
    leerTexto('contrato-prueba.yaml', File('test/datos/contrato-prueba.yaml').readAsStringSync());
Archivo contratoSesionPrueba() => _sesion ??= leerTexto(
    'contrato-sesion-prueba.yaml', File('test/datos/contrato-sesion-prueba.yaml').readAsStringSync());
Archivo nivelesPrueba() => _niveles ??=
    leerTexto('niveles-prueba.yaml', File('test/datos/niveles-prueba.yaml').readAsStringSync());

/// Valida los documentos con el contrato y los niveles de prueba. Con
/// `contrato: false` o `niveles: false` se quitan, para probar "sin contrato"
/// y "sin niveles".
List<Hallazgo> correr(
  List<Doc> docs, {
  bool contrato = true,
  bool niveles = true,
  bool contratoSesion = true,
}) {
  final archivos = <Archivo>[
    if (contrato) contratoPrueba(),
    if (contratoSesion) contratoSesionPrueba(),
    if (niveles) nivelesPrueba(),
    for (var i = 0; i < docs.length; i++) leerMapa('doc$i.yaml', clonar(docs[i])),
  ];
  return validarArchivos(archivos).hallazgos;
}

/// Hallazgos de un código, sin los del contrato y los niveles de prueba.
List<Hallazgo> de(List<Hallazgo> h, String codigo) =>
    h.where((x) => x.codigo == codigo && x.archivo.startsWith('doc')).toList();

List<Hallazgo> errores(List<Hallazgo> h, String codigo) =>
    de(h, codigo).where((x) => x.esError).toList();

List<Hallazgo> avisos(List<Hallazgo> h, String codigo) =>
    de(h, codigo).where((x) => !x.esError).toList();

/// Todo lo que dejó un documento (de los del caso), de cualquier código.
List<Hallazgo> propios(List<Hallazgo> h) =>
    h.where((x) => x.archivo.startsWith('doc')).toList();
