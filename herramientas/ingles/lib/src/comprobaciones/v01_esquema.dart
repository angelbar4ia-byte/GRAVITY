import '../contexto.dart';
import '../hallazgo.dart';
import '../modelo/archivo.dart';

/// V01 · Esquema: campos obligatorios, tipos y valores de las listas
/// controladas. Los comprueba la lectura del archivo; aquí se entregan.
List<Hallazgo> v01(Archivo a, Contexto c) => a.lectura;
