/// El disco, detrás de una interfaz pequeña para poder inyectar fallos en las
/// pruebas (disco lleno, cortes entre archivos: criterios 23 y 24).
///
/// Solo lo que el gestor de descargas necesita. La implementación real usa
/// `dart:io`; no abre ninguna conexión.
library;

import 'dart:io';

/// Escribe un archivo (siempre al final).
abstract interface class EscritorDeArchivo {
  void agregar(List<int> bytes);

  /// Espera a que lo agregado llegue al disco (para no acumular en memoria).
  /// Si el disco se llenó, lanza [FileSystemException].
  Future<void> vaciar();

  /// Vacía lo pendiente y cierra. Si el disco se llenó, lanza
  /// [FileSystemException].
  Future<void> cerrar();
}

abstract interface class SistemaDeArchivos {
  Future<bool> existeArchivo(String ruta);
  Future<bool> existeCarpeta(String ruta);

  /// Tamaño del archivo, o `null` si no existe.
  Future<int?> largo(String ruta);

  /// Abre [ruta] para escribir; con [anexar] conserva lo que ya tenía, y si
  /// no, la deja vacía. Crea las carpetas que falten.
  Future<EscritorDeArchivo> abrirEscritura(String ruta, {bool anexar = false});

  Future<String?> leerTexto(String ruta);

  /// Escribe el texto completo de una vez (por un archivo temporal que se
  /// renombra, para que nunca quede a medias).
  Future<void> escribirTexto(String ruta, String texto);
  Future<void> crearCarpeta(String ruta);

  /// Renombra un archivo o una carpeta. Si [destino] existe, se reemplaza.
  Future<void> renombrar(String origen, String destino);

  /// Borra un archivo o una carpeta con todo lo que tenga. No falla si no
  /// existe.
  Future<void> borrar(String ruta);

  /// Suma de lo que pesan los archivos bajo [ruta] (0 si no existe).
  Future<int> bytesEn(String ruta);

  /// Nombres de lo que hay directamente en [ruta] (vacío si no existe).
  Future<List<String>> nombresEn(String ruta);

  /// Espacio libre en el volumen de [ruta], o `null` si no se puede medir.
  ///
  /// Con los paquetes aprobados no hay forma portátil de medirlo (Android y
  /// Windows no lo dicen a `dart:io`): la implementación real devuelve `null`
  /// y el gestor se apoya en el error de disco lleno del sistema (spec 4.2.2,
  /// punto 7). Si se aprueba un paquete para esto, solo cambia esta clase.
  Future<int?> bytesLibres(String ruta);
}

/// `true` si [e] es "no queda espacio en el disco": ENOSPC (28) o EDQUOT (122)
/// en Android y Linux; ERROR_HANDLE_DISK_FULL (39) y ERROR_DISK_FULL (112) en
/// Windows.
bool esDiscoLleno(FileSystemException e) {
  final codigo = e.osError?.errorCode;
  return codigo == 28 || codigo == 122 || codigo == 39 || codigo == 112;
}

class SistemaDeArchivosReal implements SistemaDeArchivos {
  const SistemaDeArchivosReal();

  @override
  Future<bool> existeArchivo(String ruta) => File(ruta).exists();

  @override
  Future<bool> existeCarpeta(String ruta) => Directory(ruta).exists();

  @override
  Future<int?> largo(String ruta) async {
    final f = File(ruta);
    if (!await f.exists()) return null;
    return f.length();
  }

  @override
  Future<EscritorDeArchivo> abrirEscritura(
    String ruta, {
    bool anexar = false,
  }) async {
    final f = File(ruta);
    await f.parent.create(recursive: true);
    final sink = f.openWrite(mode: anexar ? FileMode.append : FileMode.write);
    return _EscritorReal(sink);
  }

  @override
  Future<String?> leerTexto(String ruta) async {
    final f = File(ruta);
    if (!await f.exists()) return null;
    return f.readAsString();
  }

  @override
  Future<void> escribirTexto(String ruta, String texto) async {
    final f = File(ruta);
    await f.parent.create(recursive: true);
    final tmp = File('$ruta.tmp');
    await tmp.writeAsString(texto, flush: true);
    await tmp.rename(ruta);
  }

  @override
  Future<void> crearCarpeta(String ruta) async {
    await Directory(ruta).create(recursive: true);
  }

  @override
  Future<void> renombrar(String origen, String destino) async {
    final tipo = await FileSystemEntity.type(origen);
    if (tipo == FileSystemEntityType.directory) {
      if (await Directory(destino).exists()) {
        await Directory(destino).delete(recursive: true);
      }
      await Directory(destino).parent.create(recursive: true);
      await Directory(origen).rename(destino);
    } else {
      await File(destino).parent.create(recursive: true);
      await File(origen).rename(destino);
    }
  }

  @override
  Future<void> borrar(String ruta) async {
    final tipo = await FileSystemEntity.type(ruta);
    switch (tipo) {
      case FileSystemEntityType.directory:
        await Directory(ruta).delete(recursive: true);
      case FileSystemEntityType.notFound:
        break;
      default:
        await File(ruta).delete();
    }
  }

  @override
  Future<int> bytesEn(String ruta) async {
    final tipo = await FileSystemEntity.type(ruta);
    if (tipo == FileSystemEntityType.notFound) return 0;
    if (tipo != FileSystemEntityType.directory) return File(ruta).length();
    var suma = 0;
    await for (final e in Directory(ruta).list(recursive: true)) {
      if (e is File) {
        try {
          suma += await e.length();
        } on FileSystemException {
          // Se borró mientras se contaba.
        }
      }
    }
    return suma;
  }

  @override
  Future<List<String>> nombresEn(String ruta) async {
    final d = Directory(ruta);
    if (!await d.exists()) return const [];
    return [
      await for (final e in d.list())
        e.uri.pathSegments.where((s) => s.isNotEmpty).last,
    ];
  }

  @override
  Future<int?> bytesLibres(String ruta) async => null;
}

class _EscritorReal implements EscritorDeArchivo {
  _EscritorReal(this._sink) {
    // Un error de escritura (disco lleno) llega por `done`: se guarda y se
    // lanza en la siguiente operación, para que nunca sea un error suelto.
    _sink.done.then<void>((_) {}, onError: (Object e) => _error ??= e);
  }
  final IOSink _sink;
  Object? _error;

  void _revisar() {
    final e = _error;
    if (e != null) throw e;
  }

  @override
  void agregar(List<int> bytes) {
    _revisar();
    _sink.add(bytes);
  }

  @override
  Future<void> vaciar() async {
    _revisar();
    try {
      await _sink.flush();
    } catch (e) {
      _error ??= e;
    }
    _revisar();
  }

  @override
  Future<void> cerrar() async {
    try {
      await _sink.flush();
      await _sink.close();
    } catch (e) {
      _error ??= e;
    }
    _revisar();
  }
}
