import 'package:ingles/ingles.dart';

import 'ayudas.dart';
import 'casos_b.dart';

/// Los archivos de un caso: el contrato de prueba de la fidelidad (o el que se
/// pase), los niveles de prueba y los documentos, con las rutas `doc0.yaml`,
/// `doc1.yaml`... (las que miran `de`, `errores` y `avisos`).
List<Archivo> archivosB(
  List<Doc> docs, {
  Doc? contrato,
  bool niveles = true,
  bool contratoSesion = false,
}) =>
    [
      leerMapa('contrato.yaml', clonar(contrato ?? contratoFidelidad())),
      if (contratoSesion) contratoSesionPrueba(),
      if (niveles) nivelesPrueba(),
      for (var i = 0; i < docs.length; i++) leerMapa('doc$i.yaml', clonar(docs[i])),
    ];

/// Valida un caso entero y devuelve todos sus hallazgos.
List<Hallazgo> correrB(List<Doc> docs, {Doc? contrato, bool niveles = true}) =>
    validarArchivos(archivosB(docs, contrato: contrato, niveles: niveles)).hallazgos;

/// La fidelidad de la primera forma de un caso.
Fidelidad fidelidadDe(List<Doc> docs, {Doc? contrato}) {
  final archivos = archivosB(docs, contrato: contrato);
  final forma = archivos.whereType<Forma>().first;
  return calcularFidelidad(forma, Contexto(archivos));
}

/// La unidad `doc{i}` de un caso, ya leída.
Unidad unidadDe(Doc d) => leerMapa('u.yaml', clonar(d)) as Unidad;
