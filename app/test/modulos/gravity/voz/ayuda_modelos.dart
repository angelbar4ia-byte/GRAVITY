// Ayudas de las pruebas de la fuente B: un catálogo pequeño con archivos de
// verdad (y sus huellas calculadas aquí), un disco en memoria y un servidor de
// descargas simulado ya cargado con esos archivos.
import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:gravity/modulos/gravity/voz/descarga/puerta_de_descarga_falsa.dart';
import 'package:gravity/modulos/gravity/voz/descarga/sistema_de_archivos.dart';
import 'package:gravity/modulos/gravity/voz/modelos/catalogo.dart';
import 'package:gravity/modulos/gravity/voz/modelos/lector_catalogo.dart';

const baseDePrueba =
    'https://voces.ejemplo.test/storage/v1/object/public/voces/rev1';

List<int> bytesDePrueba(int n, int semilla) =>
    List<int>.generate(n, (i) => (i * 31 + semilla * 7 + (i >> 8)) & 0xFF);

String sha256De(List<int> bytes) => crypto.sha256.convert(bytes).toString();

/// Dos modelos Piper de mentira: `ana` (mujer, en-US) y `beto` (hombre,
/// en-US), más `cori` (mujer, en-GB, acento aproximado).
class ContenidoDePrueba {
  ContenidoDePrueba() {
    for (final (id, semilla) in [('ana', 1), ('beto', 2), ('cori', 3)]) {
      archivos[id] = {
        '$id.onnx': bytesDePrueba(30000, semilla),
        'tokens.txt': bytesDePrueba(120, semilla + 10),
        'lexicon-en-us.txt': bytesDePrueba(6000, 9),
      };
    }
  }

  /// modelo -> nombre del archivo -> bytes.
  final archivos = <String, Map<String, List<int>>>{};

  Map<String, Object?> comoMapa() {
    Map<String, Object?> modelo(
      String id,
      String voz,
      String genero,
      String variante, {
      bool aproximada = false,
    }) => {
      'id': id,
      'nombre': 'Voz $voz',
      'familia': 'vits',
      'idioma': 'en',
      'variantes': [variante],
      'voces': [
        {
          'sid': 0,
          'nombre': voz,
          'genero': genero,
          'variante': variante,
          if (aproximada) 'acento_aproximado': true,
        },
      ],
      'asignacion_sugerida': {genero == 'mujer' ? 'F1' : 'M1': 0},
      'archivos': [
        for (final (rol, nombre) in [
          ('modelo', '$id.onnx'),
          ('tokens', 'tokens.txt'),
          ('lexicon', 'lexicon-en-us.txt'),
        ])
          {
            'rol': rol,
            'nombre': nombre,
            'bytes': archivos[id]![nombre]!.length,
            'sha256': sha256De(archivos[id]![nombre]!),
            'url': '$baseDePrueba/$id/$nombre',
          },
      ],
      'licencia': {
        'id': 'public-domain',
        'origen': 'tarjeta de prueba',
        'atribucion': 'Voz de prueba $voz. Atribución de prueba.',
        'texto': 'docs/licencias-voces/textos/APACHE-2.0.txt',
      },
      'fuente': {'url': 'https://ejemplo.test/modelos', 'revision': 'rev1'},
      'consultado': '2026-11-22',
    };
    return {
      'esquema': 'gravity-voces-v1',
      'modelos': [
        modelo('ana', 'Ana', 'mujer', 'en-US'),
        modelo('beto', 'Beto', 'hombre', 'en-US'),
        modelo('cori', 'Cori', 'mujer', 'en-GB', aproximada: true),
      ],
    };
  }

  CatalogoDeVoces catalogo() => leerCatalogo(jsonEncode(comoMapa()));

  /// Un servidor simulado con todos los archivos.
  PuertaDeDescargaFalsa servidor() => PuertaDeDescargaFalsa({
    for (final e in archivos.entries)
      for (final a in e.value.entries)
        '$baseDePrueba/${e.key}/${a.key}': a.value,
  });

  String direccion(String modelo, String archivo) =>
      '$baseDePrueba/$modelo/$archivo';

  int bytesDe(String modelo) =>
      archivos[modelo]!.values.fold(0, (s, a) => s + a.length);
}

/// Un disco en memoria (carpetas implícitas por la ruta).
class SistemaDeArchivosEnMemoria implements SistemaDeArchivos {
  final archivos = <String, List<int>>{};

  String _n(String ruta) => ruta.replaceAll(r'\', '/');

  @override
  Future<bool> existeArchivo(String ruta) async =>
      archivos.containsKey(_n(ruta));

  @override
  Future<bool> existeCarpeta(String ruta) async {
    final p = '${_n(ruta)}/';
    return archivos.keys.any((k) => k.startsWith(p));
  }

  @override
  Future<int?> largo(String ruta) async => archivos[_n(ruta)]?.length;

  @override
  Future<EscritorDeArchivo> abrirEscritura(
    String ruta, {
    bool anexar = false,
  }) async {
    final k = _n(ruta);
    if (!anexar) archivos[k] = [];
    archivos.putIfAbsent(k, () => []);
    return _Escritor(archivos[k]!);
  }

  @override
  Future<String?> leerTexto(String ruta) async {
    final b = archivos[_n(ruta)];
    return b == null ? null : utf8.decode(b);
  }

  @override
  Future<void> escribirTexto(String ruta, String texto) async =>
      archivos[_n(ruta)] = utf8.encode(texto);

  @override
  Future<void> crearCarpeta(String ruta) async {}

  @override
  Future<void> renombrar(String origen, String destino) async {
    final o = _n(origen);
    final d = _n(destino);
    if (archivos.containsKey(o)) {
      archivos[d] = archivos.remove(o)!;
      return;
    }
    archivos.removeWhere((k, _) => k.startsWith('$d/'));
    for (final k in archivos.keys.where((k) => k.startsWith('$o/')).toList()) {
      archivos['$d/${k.substring(o.length + 1)}'] = archivos.remove(k)!;
    }
  }

  @override
  Future<void> borrar(String ruta) async {
    final r = _n(ruta);
    archivos.remove(r);
    archivos.removeWhere((k, _) => k.startsWith('$r/'));
  }

  @override
  Future<int> bytesEn(String ruta) async {
    final r = _n(ruta);
    var suma = 0;
    archivos.forEach((k, v) {
      if (k == r || k.startsWith('$r/')) suma += v.length;
    });
    return suma;
  }

  @override
  Future<List<String>> nombresEn(String ruta) async {
    final p = '${_n(ruta)}/';
    return {
      for (final k in archivos.keys)
        if (k.startsWith(p)) k.substring(p.length).split('/').first,
    }.toList();
  }

  @override
  Future<int?> bytesLibres(String ruta) async => null;
}

class _Escritor implements EscritorDeArchivo {
  _Escritor(this._destino);
  final List<int> _destino;

  @override
  void agregar(List<int> bytes) => _destino.addAll(bytes);

  @override
  Future<void> vaciar() async {}

  @override
  Future<void> cerrar() async {}
}
