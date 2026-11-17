import 'dart:io';

import 'comprobaciones/v01_esquema.dart';
import 'comprobaciones/v02_identificadores.dart';
import 'comprobaciones/v03_opciones.dart';
import 'comprobaciones/v04_una_correcta.dart';
import 'comprobaciones/v05_longitud_correcta.dart';
import 'comprobaciones/v07_formacion_palabra.dart';
import 'comprobaciones/v08_transformacion.dart';
import 'comprobaciones/v09_hueco_abierto.dart';
import 'comprobaciones/v10_oraciones_omitidas.dart';
import 'comprobaciones/v11_correspondencia.dart';
import 'comprobaciones/v12_porque.dart';
import 'comprobaciones/v13_niveles.dart';
import 'comprobaciones/v14_completar_palabras.dart';
import 'comprobaciones/v15_longitud.dart';
import 'comprobaciones/v16_audio.dart';
import 'comprobaciones/v17_idioma.dart';
import 'comprobaciones/v18_grafias.dart';
import 'comprobaciones/v19_duplicados.dart';
import 'comprobaciones/v20_exclusivas.dart';
import 'comprobaciones/v21_sesion.dart';
import 'comprobaciones/v22_minutos.dart';
import 'comprobaciones/v23_tarjetas.dart';
import 'comprobaciones/v24_estados.dart';
import 'comprobaciones/v27_consistencia.dart';
import 'comprobaciones/v28_pruebas_unidad.dart';
import 'contexto.dart';
import 'hallazgo.dart';
import 'modelo/archivo.dart';
import 'modelo/leer.dart';

typedef Comprobacion = List<Hallazgo> Function(Archivo a, Contexto c);

/// Las comprobaciones de P1.2a, P1.2b y P1.2c-1, en orden. V06, V25 y V26
/// pertenecen a `exportar` y `compilar` (P1.2c-2). V24 se aplica aparte, al
/// final, porque mira lo que dejaron las demás.
const List<Comprobacion> comprobaciones = [
  v01,
  v02,
  v03,
  v04,
  v05,
  v07,
  v08,
  v09,
  v10,
  v11,
  v12,
  v13,
  v14,
  v15,
  v16,
  v17,
  v18,
  v19,
  v20,
  v21,
  v22,
  v23,
  v27,
  v28,
];

/// Lo que devuelve `validar`.
class Resultado {
  Resultado(this.archivos, this.hallazgos);
  final List<Archivo> archivos;
  final List<Hallazgo> hallazgos;

  int get errores => hallazgos.where((h) => h.esError).length;
  int get avisos => hallazgos.length - errores;
  bool get limpio => errores == 0;
}

/// Aplica las comprobaciones a archivos ya leídos. Un archivo `retirado` solo
/// pasa V01 y V02.
Resultado validarArchivos(List<Archivo> archivos) {
  final c = Contexto(archivos);
  final todos = <Hallazgo>[];
  for (final a in archivos) {
    final propios = <Hallazgo>[];
    for (final comprobar in comprobaciones) {
      if (estaRetirado(a) && comprobar != v01 && comprobar != v02) continue;
      propios.addAll(comprobar(a, c));
    }
    propios.addAll(v24(a, c, propios));
    todos.addAll(propios);
  }
  return Resultado(archivos, todos);
}

bool estaRetirado(Archivo a) => a.estado == Estado.retirado;

/// Lee todos los `.yaml` de una carpeta (o un solo archivo) y los valida. No
/// toca lo que no sea `.yaml`, las carpetas ocultas ni `revisiones/` (lo que
/// escribe `comparar` tiene otra forma).
Resultado validarRuta(String ruta) {
  final archivos = leerRuta(ruta);
  return validarArchivos(archivos);
}

List<Archivo> leerRuta(String ruta) {
  final tipo = FileSystemEntity.typeSync(ruta);
  final rutas = <String, File>{};
  if (tipo == FileSystemEntityType.file) {
    rutas[_nombre(ruta)] = File(ruta);
  } else if (tipo == FileSystemEntityType.directory) {
    final base = Directory(ruta).absolute.path;
    for (final e in Directory(ruta).listSync(recursive: true, followLinks: false)) {
      if (e is! File || !e.path.endsWith('.yaml')) continue;
      final rel = e.absolute.path.substring(base.length).replaceAll('\\', '/').replaceFirst(RegExp(r'^/'), '');
      final partes = rel.split('/');
      final saltar = partes.take(partes.length - 1).any((d) => d.startsWith('.') || d == 'revisiones');
      if (!saltar) rutas[rel] = e;
    }
  } else {
    throw FileSystemException('No existe la ruta', ruta);
  }
  final claves = rutas.keys.toList()..sort();
  return [
    for (final k in claves) leerTexto(k, rutas[k]!.readAsStringSync()),
  ];
}

String _nombre(String ruta) => ruta.replaceAll('\\', '/').split('/').last;

/// Carpeta `data/ingles` desde la raíz del repositorio: sube desde el
/// directorio actual hasta encontrarla.
String? buscarDataIngles() {
  var d = Directory.current.absolute;
  for (var i = 0; i < 8; i++) {
    final candidata = Directory('${d.path}/data/ingles');
    if (candidata.existsSync()) return candidata.path;
    if (d.parent.path == d.path) break;
    d = d.parent;
  }
  return null;
}
