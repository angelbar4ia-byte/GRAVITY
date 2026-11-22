/// Gestor de modelos de voz descargables (spec 3.2 punto 7 y 4.2.2).
///
/// Esta es la interfaz que ven la fuente B y Ajustes; la implementación real
/// está en `gestor_en_disco.dart` y la simulada, en `gestor_falso.dart`.
library;

import '../modelos/catalogo.dart';
import '../modelos/estado_modelo.dart';

/// Rutas de los archivos de un modelo instalado, armadas **solo** con los
/// nombres del catálogo dentro de la carpeta del modelo (R10: el cargador
/// nunca recorre la carpeta ni acepta otros archivos).
final class RutasDelModelo {
  const RutasDelModelo({
    required this.carpeta,
    required this.modelo,
    required this.tokens,
    this.lexicon,
  });

  final String carpeta;
  final String modelo;
  final String tokens;
  final String? lexicon;
}

abstract interface class GestorDeModelos {
  /// Los modelos que ofrece la app. Salen de `app/assets`, no de la red.
  List<ModeloDelCatalogo> get catalogo;

  /// Avisa cuando cambia el estado de algún modelo (empezó o terminó una
  /// descarga, se borró, se marcó dañado…): la pantalla y la cadena de fuentes
  /// se refrescan.
  Stream<void> get cambios;

  Future<EstadoModelo> estado(String idModelo);

  /// Bytes ya guardados de una descarga a medias (0 si no hay). Sirve para
  /// ofrecer *Reanudar*.
  Future<int> bytesDescargados(String idModelo);

  /// Descarga el modelo: aviso de red, un archivo tras otro, cada uno
  /// verificado, y recién al final se instala (todo o nada).
  ///
  /// El flujo emite [ProgresoDescarga] y termina cuando el modelo quedó
  /// instalado o cuando se canceló (en ese caso el estado no es `instalado`).
  /// Si falla, emite un `ErrorVoz` (`SinWifi`, `SinRed`, `SinEspacio`,
  /// `HuellaIncorrecta`, `DescargaInterrumpida`, `NoDisponibleAun`). Pedirla
  /// otra vez mientras corre devuelve el mismo flujo.
  ///
  /// [permitirDatosMoviles] es el permiso de **esta** descarga: no se recuerda.
  Stream<ProgresoDescarga> descargar(
    String idModelo, {
    bool permitirDatosMoviles = false,
  });

  /// El flujo de la descarga en curso (para una pantalla que se abre después),
  /// o `null` si no hay ninguna.
  Stream<ProgresoDescarga>? seguir(String idModelo);

  /// Detiene la descarga y conserva lo descargado para reanudar.
  Future<void> cancelar(String idModelo);

  /// Borra el modelo y lo que haya de su descarga; para antes la voz si
  /// sonaba (por los avisos de [antesDeBorrar]). Devuelve los bytes liberados.
  Future<int> borrar(String idModelo);

  /// Lo que ocupan todos los modelos y descargas a medias.
  Future<int> bytesOcupados();

  /// Lo que ocupa un modelo (instalado y descarga a medias).
  Future<int> bytesOcupadosPor(String idModelo);

  /// Recalcula el sha256 de cada archivo instalado (en un `Isolate`). Si
  /// alguno no coincide, el modelo queda `corrupto`.
  Future<bool> comprobar(String idModelo);

  /// Quita las marcas de "dañado" y de "carga sin terminar" y vuelve a
  /// comprobar el modelo. Devuelve su estado después.
  Future<EstadoModelo> reintentar(String idModelo);

  /// Las rutas para cargar el modelo, o `null` si no está `instalado`.
  Future<RutasDelModelo?> rutasParaCargar(String idModelo);

  // ── Marca de carga (spec 4.2.3) ──────────────────────────────────────────
  // Un error nativo al cargar no se atrapa: mata el proceso. Antes de cargar
  // se escribe la marca; si al arrancar sigue ahí, el modelo queda `corrupto`
  // y no se vuelve a cargar solo: una voz que tumba la app no puede tumbarla
  // en cada arranque.

  Future<void> iniciarCarga(String idModelo);
  Future<void> terminarCarga(String idModelo);

  /// El modelo falló de forma que se pudo atrapar (por ejemplo, la prueba de
  /// humo): queda `corrupto` hasta que se reintente o se borre.
  Future<void> marcarCorrupto(String idModelo);

  /// Registra algo que se debe hacer **antes** de borrar un modelo (parar la
  /// voz que suena y liberar el modelo cargado). Devuelve cómo quitarlo.
  void Function() antesDeBorrar(Future<void> Function(String idModelo) hacer);
}
