/// El reproductor de archivos de audio detrás de una interfaz (spec 3.2,
/// punto 8). Lo usan la fuente B (los WAV que sintetiza) y, más adelante, la
/// fuente C (las piezas pregrabadas). La fuente A habla por sí misma.
///
/// La real, con `audioplayers` 6.8.1, está en `reproductor_audioplayers.dart`
/// (el único archivo que importa el paquete). La falsa reproduce "en el reloj
/// de la prueba": no suena nada ni abre ningún plugin.
///
/// Reproducir archivos **no usa la red** (R8): solo rutas del equipo.
library;

import 'dart:async';

abstract interface class ReproductorDeAudio {
  /// Prepara el archivo de [rutaDeArchivo] (una ruta del equipo).
  Future<void> abrir(String rutaDeArchivo);

  /// Empieza (o sigue, tras [pausar]).
  Future<void> reproducir();
  Future<void> pausar();

  /// Corta y deja el reproductor listo para otro archivo.
  Future<void> parar();

  /// 1.0 es la velocidad normal. La fuente B no lo usa (sintetiza ya a la
  /// velocidad pedida); la C sí.
  Future<void> fijarVelocidad(double factor);

  /// Posición dentro del archivo que suena.
  Stream<Duration> get posicion;

  /// Un evento cuando el archivo **termina de sonar solo** (no al parar).
  Stream<void> get terminado;

  /// Libera los recursos del sistema.
  Future<void> liberar();
}

/// Reproductor simulado: [reproducir] "dura" [duracion] en el reloj de la
/// prueba (`fake_async` o tiempo real) y entonces avisa [terminado].
class ReproductorDeAudioFalso implements ReproductorDeAudio {
  ReproductorDeAudioFalso({
    this.duracion = const Duration(milliseconds: 200),
    this.manual = false,
  });

  /// Cuánto dura cada archivo (si no es [manual]). Cero: termina al instante.
  Duration duracion;

  /// Si es `true`, el archivo no termina hasta que la prueba llame a
  /// [terminarArchivo].
  bool manual;

  /// Rutas abiertas, en orden.
  final abiertos = <String>[];

  /// Velocidades fijadas, en orden.
  final velocidades = <double>[];

  /// Cuántas veces se cortó con [parar] algo que sonaba.
  int cortes = 0;

  int pausas = 0;
  bool liberado = false;

  final _terminado = StreamController<void>.broadcast();
  final _posicion = StreamController<Duration>.broadcast();
  Timer? _reloj;
  bool _sonando = false;
  Duration _restante = Duration.zero;
  DateTime? _desde;

  /// `true` mientras suena un archivo.
  bool get sonando => _sonando;

  @override
  Future<void> abrir(String rutaDeArchivo) async {
    abiertos.add(rutaDeArchivo);
    _restante = duracion;
  }

  @override
  Future<void> reproducir() async {
    _sonando = true;
    if (manual) return;
    _arrancar(_restante);
  }

  void _arrancar(Duration cuanto) {
    _reloj?.cancel();
    _desde = DateTime.now();
    if (cuanto <= Duration.zero) {
      scheduleMicrotask(terminarArchivo);
      return;
    }
    _reloj = Timer(cuanto, terminarArchivo);
  }

  /// El archivo que suena termina (modo [manual] o por el reloj).
  void terminarArchivo() {
    if (!_sonando) return;
    _sonando = false;
    _reloj?.cancel();
    _reloj = null;
    if (!_terminado.isClosed) _terminado.add(null);
  }

  @override
  Future<void> pausar() async {
    if (!_sonando) return;
    pausas++;
    _reloj?.cancel();
    final desde = _desde;
    if (desde != null) {
      final paso = DateTime.now().difference(desde);
      _restante = paso >= _restante ? Duration.zero : _restante - paso;
    }
    _sonando = false;
  }

  @override
  Future<void> parar() async {
    if (_sonando) cortes++;
    _reloj?.cancel();
    _reloj = null;
    _sonando = false;
  }

  @override
  Future<void> fijarVelocidad(double factor) async => velocidades.add(factor);

  @override
  Stream<Duration> get posicion => _posicion.stream;

  @override
  Stream<void> get terminado => _terminado.stream;

  @override
  Future<void> liberar() async {
    liberado = true;
    _reloj?.cancel();
    await _terminado.close();
    await _posicion.close();
  }
}
