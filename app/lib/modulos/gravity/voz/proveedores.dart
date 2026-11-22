/// Proveedores del motor de voz: qué fuentes hay en este equipo y el motor.
///
/// La reproducción vive en el proveedor, no en una pantalla (spec 3.4, punto
/// 6): salir de una pantalla no la detiene a menos que la pantalla lo pida.
///
/// Fuentes de hoy: la **A** (voz del dispositivo) y la **B** (voces
/// descargables, P3.2a-2). La **C** (audio pregrabado) llega en P3.2a-3.
library;

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../nucleo/conectividad/tipo_de_red.dart';
import 'audio/reproductor_audioplayers.dart';
import 'audio/reproductor_de_audio.dart';
import 'descarga/gestor_de_modelos.dart';
import 'descarga/gestor_en_disco.dart';
import 'descarga/puerta_de_descarga.dart';
import 'fuente_de_voz.dart';
import 'fuentes/dispositivo/fuente_dispositivo.dart';
import 'fuentes/dispositivo/puerto_tts.dart';
import 'fuentes/modelo/fuente_modelo.dart';
import 'fuentes/modelo/puerta_sherpa.dart';
import 'fuentes/modelo/puerta_sintesis.dart';
import 'modelos/catalogo.dart';
import 'motor.dart';
import 'preferencias.dart';

/// `true` si este equipo puede usar la voz del dispositivo: Android (teléfono y
/// tablets) y Windows (laptop). En las pruebas (Linux) no hay ninguna fuente y
/// el motor no toca ningún plugin.
bool plataformaConVozDelDispositivo() =>
    !kIsWeb && (Platform.isAndroid || Platform.isWindows);

/// El catálogo de voces descargables. El arranque lo lee de
/// `assets/voces/catalogo.json` y lo valida; si no pasa la validación (o en las
/// pruebas), queda vacío y no hay voces descargables.
final catalogoDeVocesProvider = Provider<CatalogoDeVoces>(
  (ref) => CatalogoDeVoces.vacio,
);

/// La puerta HTTP del gestor de descargas. Se sustituye en las pruebas.
final puertaDeDescargaProvider = Provider<PuertaDeDescarga>(
  (ref) => PuertaDeDescargaHttp(),
);

/// Dónde viven los modelos descargados. Android: `filesDir` (el sistema no lo
/// vacía). Windows: AppData\Local (`getApplicationCacheDirectory`), **no**
/// AppData\Roaming, que es lo que da `getApplicationSupportDirectory` (spec
/// 4.2.2, punto 3). Ninguna carpeta pública ni permiso de almacenamiento.
Future<String> carpetaDeModelos() async {
  final base = Platform.isWindows
      ? await getApplicationCacheDirectory()
      : await getApplicationSupportDirectory();
  final s = Platform.pathSeparator;
  return '${base.path}${s}voces${s}modelos';
}

/// Los WAV temporales de la fuente B; se vacían al arrancar.
Future<String> carpetaTemporalDeVoz() async {
  final base = await getTemporaryDirectory();
  return '${base.path}${Platform.pathSeparator}gravity-voz';
}

/// El gestor de modelos descargables, o `null` donde no hay voces
/// descargables (otras plataformas que Android y Windows) o el catálogo está
/// vacío. Se sustituye en las pruebas.
final gestorDeModelosProvider = Provider<GestorDeModelos?>((ref) {
  if (!plataformaConVozDelDispositivo()) return null;
  final catalogo = ref.watch(catalogoDeVocesProvider);
  if (catalogo.modelos.isEmpty) return null;
  final gestor = GestorDeModelosEnDisco(
    catalogo: catalogo,
    raiz: carpetaDeModelos,
    red: ref.watch(fuenteTipoDeRedProvider),
    puerta: ref.watch(puertaDeDescargaProvider),
  );
  ref.onDispose(() => unawaited(gestor.cerrar()));
  return gestor;
});

/// La síntesis neuronal (un `Isolate` con `sherpa_onnx`). Se sustituye en las
/// pruebas.
final puertaSintesisProvider = Provider<PuertaSintesis>((ref) {
  final puerta = PuertaSintesisSherpa();
  ref.onDispose(() => unawaited(puerta.cerrar()));
  return puerta;
});

/// Cómo se crea el reproductor de audio. Se sustituye en las pruebas.
final crearReproductorProvider = Provider<ReproductorDeAudio Function()>(
  (ref) => ReproductorAudioplayers.new,
);

/// Las fuentes de este equipo. Hoy la A y la B; la C se suma en P3.2a-3. Se
/// sustituye en las pruebas.
final fuentesDeVozProvider = Provider<List<FuenteDeVoz>>((ref) {
  final gestor = ref.watch(gestorDeModelosProvider);
  FuenteModelo? modelo;
  if (gestor != null) {
    modelo = FuenteModelo(
      gestor: gestor,
      puerta: ref.watch(puertaSintesisProvider),
      crearReproductor: ref.watch(crearReproductorProvider),
      carpetaTemporal: carpetaTemporalDeVoz,
    );
    final fuente = modelo;
    unawaited(fuente.limpiarTemporales());
    ref.onDispose(() => unawaited(fuente.cerrar()));
  }
  return [
    if (plataformaConVozDelDispositivo()) FuenteDispositivo(PuertoTtsFlutter()),
    ?modelo,
  ];
});

final motorVozProvider = Provider<MotorVoz>((ref) {
  final motor = MotorDeVoz(
    fuentes: ref.watch(fuentesDeVozProvider),
    // Se lee en cada reproducción: cambiar de persona o de preferencia no
    // reinicia el motor.
    preferencias: () => ref.read(preferenciasVozProvider),
  );
  ref.onDispose(motor.cerrar);
  return motor;
});
