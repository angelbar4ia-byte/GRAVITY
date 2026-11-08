/// Imagen en el teléfono (Fase 8, bloque 4): fotografiar un recibo, leer su
/// texto SIN salir del teléfono y guardarlo como comprobante del gasto.
///
/// Reglas (D3, D19, especificación fase-8, sección 2):
/// - La foto se toma solo cuando la persona toca "Fotografiar recibo". El
///   permiso de cámara se pide en ese momento, nunca al abrir una pantalla.
/// - El texto se lee en el dispositivo (ML Kit on-device). Nada de este
///   archivo usa red: la imagen no se envía al servidor ni a la IA.
/// - El comprobante vive solo en el almacenamiento privado de la app, ligado
///   al id del gasto. No se sube a la nube ni entra en copias de seguridad
///   (`allowBackup=false`).
/// - Las páginas de estado de cuenta se procesan y se borran; no se guardan.
/// - Sin cámara en Windows: allí no hay captura (se carga el gasto a mano).
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

// ---------------------------------------------------------------------------
// Captura
// ---------------------------------------------------------------------------

/// Toma la foto de un recibo.
abstract class CapturaRecibo {
  /// Si este dispositivo puede fotografiar (sin pedir permisos).
  bool get disponible;

  /// Abre la cámara y devuelve la foto, o `null` si la persona canceló o no
  /// dio permiso. Se llama SOLO al tocar "Fotografiar recibo".
  Future<Uint8List?> fotografiar();
}

/// Cámara del teléfono (Android) con el selector estándar; el permiso de
/// cámara lo pide el sistema al abrirla, dentro de [fotografiar].
class CapturaReciboCamara implements CapturaRecibo {
  CapturaReciboCamara({ImagePicker? selector})
    : _selector = selector ?? ImagePicker();
  final ImagePicker _selector;

  @override
  bool get disponible => true;

  @override
  Future<Uint8List?> fotografiar() async {
    try {
      final foto = await _selector.pickImage(
        source: ImageSource.camera,
        maxWidth: 2000,
        imageQuality: 85,
      );
      return foto == null ? null : await foto.readAsBytes();
    } catch (_) {
      return null; // Sin permiso o sin cámara: se captura a mano.
    }
  }
}

/// Windows y otros: no hay cámara (no se inventa soporte).
class CapturaReciboSinCamara implements CapturaRecibo {
  const CapturaReciboSinCamara();

  @override
  bool get disponible => false;

  @override
  Future<Uint8List?> fotografiar() async => null;
}

/// Falsa para pruebas: no toca cámara ni permisos.
class CapturaReciboFalsa implements CapturaRecibo {
  CapturaReciboFalsa([this.foto]);
  Uint8List? foto;
  int tomas = 0;

  @override
  bool get disponible => true;

  @override
  Future<Uint8List?> fotografiar() async {
    tomas++;
    return foto;
  }
}

// ---------------------------------------------------------------------------
// Lectura de texto en el teléfono
// ---------------------------------------------------------------------------

/// Reconoce el texto de una imagen dentro del dispositivo.
abstract class LectorTextoLocal {
  /// Devuelve el texto de la imagen (vacío si no se reconoce nada).
  Future<String> leer(Uint8List imagen);
}

/// ML Kit de Google en el dispositivo (modelo latino incluido en la app: no
/// descarga nada ni usa red). ML Kit lee desde un archivo, así que la imagen
/// pasa por un archivo temporal privado que se borra al terminar.
class LectorTextoMlKit implements LectorTextoLocal {
  LectorTextoMlKit({Future<Directory> Function()? temporal})
    : _temporal = temporal ?? getTemporaryDirectory;
  final Future<Directory> Function() _temporal;

  @override
  Future<String> leer(Uint8List imagen) async {
    final dir = await _temporal();
    final archivo = File(
      '${dir.path}/ocr_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    final reconocedor = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      await archivo.writeAsBytes(imagen, flush: true);
      final r = await reconocedor.processImage(
        InputImage.fromFilePath(archivo.path),
      );
      return r.text;
    } finally {
      await reconocedor.close();
      if (await archivo.exists()) await archivo.delete();
    }
  }
}

/// Sin lectura de texto (Windows).
class LectorTextoNoDisponible implements LectorTextoLocal {
  const LectorTextoNoDisponible();

  @override
  Future<String> leer(Uint8List imagen) async => '';
}

/// Falsa para pruebas: devuelve el texto indicado y guarda lo que recibió.
class LectorTextoFalso implements LectorTextoLocal {
  LectorTextoFalso(this.texto);
  String texto;
  final imagenesRecibidas = <Uint8List>[];

  @override
  Future<String> leer(Uint8List imagen) async {
    imagenesRecibidas.add(imagen);
    return texto;
  }
}

// ---------------------------------------------------------------------------
// Comprobante del gasto (solo en el teléfono)
// ---------------------------------------------------------------------------

/// Guarda la foto de un recibo como comprobante de un gasto.
abstract class ComprobanteLocal {
  Future<void> guardar(String gastoId, Uint8List foto);
  Future<Uint8List?> leer(String gastoId);
  Future<bool> existe(String gastoId);
  Future<void> borrar(String gastoId);
}

/// Archivos en el almacenamiento privado de la app (no en galería ni nube).
/// Un archivo por gasto: `<raiz>/<gastoId>.jpg`.
class ComprobanteLocalArchivos implements ComprobanteLocal {
  ComprobanteLocalArchivos(this.raiz);
  final Directory raiz;

  /// Carpeta `comprobantes` dentro del almacenamiento de soporte de la app.
  static Future<ComprobanteLocalArchivos> predeterminado() async {
    final base = await getApplicationSupportDirectory();
    return ComprobanteLocalArchivos(Directory('${base.path}/comprobantes'));
  }

  static final _idValido = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

  File _archivo(String gastoId) {
    // El id del gasto es un UUID; se rechaza todo lo que parezca una ruta.
    if (!_idValido.hasMatch(gastoId)) {
      throw ArgumentError.value(gastoId, 'gastoId', 'id de gasto no válido');
    }
    return File('${raiz.path}/$gastoId.jpg');
  }

  @override
  Future<void> guardar(String gastoId, Uint8List foto) async {
    final a = _archivo(gastoId);
    await raiz.create(recursive: true);
    await a.writeAsBytes(foto, flush: true);
  }

  @override
  Future<Uint8List?> leer(String gastoId) async {
    final a = _archivo(gastoId);
    return await a.exists() ? a.readAsBytes() : null;
  }

  @override
  Future<bool> existe(String gastoId) => _archivo(gastoId).exists();

  @override
  Future<void> borrar(String gastoId) async {
    final a = _archivo(gastoId);
    if (await a.exists()) await a.delete();
  }
}

/// En memoria, para pruebas.
class ComprobanteLocalMemoria implements ComprobanteLocal {
  final guardados = <String, Uint8List>{};

  @override
  Future<void> guardar(String gastoId, Uint8List foto) async =>
      guardados[gastoId] = foto;

  @override
  Future<Uint8List?> leer(String gastoId) async => guardados[gastoId];

  @override
  Future<bool> existe(String gastoId) async => guardados.containsKey(gastoId);

  @override
  Future<void> borrar(String gastoId) async => guardados.remove(gastoId);
}

// ---------------------------------------------------------------------------
// Páginas de estado de cuenta: se leen y se borran
// ---------------------------------------------------------------------------

/// Lee páginas de un estado de cuenta para conciliar y no deja nada guardado.
/// Cada página pasa por un archivo temporal propio que se borra siempre,
/// incluso si la lectura falla.
class PaginasEstadoCuenta {
  PaginasEstadoCuenta(this._lector, {required this.temporal});
  final LectorTextoLocal _lector;
  final Directory temporal;

  /// Devuelve el texto de cada página, en orden.
  Future<List<String>> leerYBorrar(List<Uint8List> paginas) async {
    await temporal.create(recursive: true);
    final salida = <String>[];
    final archivos = <File>[];
    try {
      for (var i = 0; i < paginas.length; i++) {
        final f = File('${temporal.path}/estado_$i.tmp');
        archivos.add(f);
        await f.writeAsBytes(paginas[i], flush: true);
        salida.add(await _lector.leer(await f.readAsBytes()));
      }
    } finally {
      for (final f in archivos) {
        if (await f.exists()) await f.delete();
      }
    }
    return salida;
  }
}

// ---------------------------------------------------------------------------
// Proveedores
// ---------------------------------------------------------------------------

bool get _esAndroid => !kIsWeb && Platform.isAndroid;

final capturaReciboProvider = Provider<CapturaRecibo>(
  (_) => _esAndroid ? CapturaReciboCamara() : const CapturaReciboSinCamara(),
);

final lectorTextoLocalProvider = Provider<LectorTextoLocal>(
  (_) => _esAndroid ? LectorTextoMlKit() : const LectorTextoNoDisponible(),
);

final comprobanteLocalProvider = FutureProvider<ComprobanteLocal>(
  (_) => ComprobanteLocalArchivos.predeterminado(),
);
