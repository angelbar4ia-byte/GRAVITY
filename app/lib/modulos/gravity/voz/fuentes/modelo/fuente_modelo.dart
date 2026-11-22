/// Fuente B del motor de voz: modelos descargables que corren en el equipo
/// (spec 4.2).
///
/// Voces neuronales Piper (VITS) con `sherpa_onnx`, detrás de [PuertaSintesis]
/// (en un `Isolate`), y reproducción con un [ReproductorDeAudio]. Funciona sin
/// conexión una vez descargado el modelo: aquí no hay ni una conexión (R8);
/// solo el gestor de descargas la usa.
///
/// Cómo suena un turno:
/// 1. Se parte en frases ([partirEnFrases]).
/// 2. Se genera la primera frase; mientras suena, se genera la siguiente
///    (adelanto de una). Cada frase se escribe como WAV en la carpeta
///    temporal, se reproduce y se borra.
/// 3. Pausar corta la frase que suena; reanudar la **repite desde su
///    principio** (lo ya sintetizado no se vuelve a generar). El resto del
///    turno sigue donde iba.
///
/// Reglas:
/// - **Solo se carga lo verificado (R10):** las rutas las da el gestor, armadas
///   con los nombres del catálogo, y solo si el modelo está `instalado`.
/// - **Marca de carga (spec 4.2.3):** antes de la primera carga de un modelo en
///   esta sesión se escribe `cargando-<id>`; al terminar, se borra. Si la
///   carga o la prueba de humo (una frase fija) fallan de forma atrapable, el
///   modelo queda `corrupto`.
/// - **Ningún error lleva el texto** (R6): solo códigos.
/// - Con el modelo borrado, esta fuente deja de ofrecer sus voces y, si
///   sonaba, se para antes de borrar (criterio 25).
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;

import '../../asignador.dart';
import '../../audio/reproductor_de_audio.dart';
import '../../audio/wav.dart';
import '../../descarga/gestor_de_modelos.dart';
import '../../descarga/sistema_de_archivos.dart';
import '../../fuente_de_voz.dart';
import '../../modelos/catalogo.dart';
import '../../modelos/estado_modelo.dart';
import '../../reproduccion_por_turnos.dart';
import '../../tipos.dart';
import 'frases.dart';
import 'puerta_sintesis.dart';

/// La frase fija de la prueba de humo (no es contenido del curso).
const fraseDePruebaDeHumo = 'Hello.';

/// Códigos de fallo que dicen que el problema es el entorno (biblioteca,
/// `Isolate`), no el modelo: el modelo no se marca dañado por ellos.
const _fallosDelEntorno = {
  'biblioteca_no_disponible',
  'isolate_no_arranco',
  'isolate_perdido',
  'tiempo_agotado',
};

class FuenteModelo implements FuenteDeVoz, FuenteConMotivoSinVoces {
  FuenteModelo({
    required GestorDeModelos gestor,
    required this._puerta,
    required this._crearReproductor,
    required this._carpetaTemporal,
    SistemaDeArchivos archivos = const SistemaDeArchivosReal(),
    this.hilos = 2,
  }) : _gestor = gestor,
       _fs = archivos {
    _quitarAviso = gestor.antesDeBorrar(_antesDeBorrar);
  }

  final GestorDeModelos _gestor;
  final PuertaSintesis _puerta;
  final ReproductorDeAudio Function() _crearReproductor;
  final Future<String> Function() _carpetaTemporal;
  final SistemaDeArchivos _fs;

  /// Hilos de cómputo del modelo (2 hasta que P3.3 mida).
  final int hilos;

  late final void Function() _quitarAviso;
  ReproductorDeAudio? _reproductor;
  _Activa? _activa;
  final _probados = <String>{};
  final _cargando = <String, Future<void>>{};
  int _contadorDeArchivos = 0;

  @override
  Fuente get tipo => Fuente.modelo;

  /// Sin tono ni avance por palabra. La velocidad llega a la síntesis como
  /// `speed` (1.0 es la normal); de 0.5 a 1.5.
  @override
  Capacidades get capacidades => const Capacidades(
    tono: false,
    progresoPorPalabra: false,
    pausa: true,
    velocidadMin: 0.5,
    velocidadMax: 1.5,
  );

  ReproductorDeAudio get _jugador => _reproductor ??= _crearReproductor();

  /// Id de la voz del motor: `<modelo>/<sid>`.
  static String idDeVoz(String idModelo, int sid) => '$idModelo/$sid';

  ({ModeloDelCatalogo modelo, VozDeModelo voz})? _resolver(String idVoz) {
    final corte = idVoz.lastIndexOf('/');
    if (corte < 0) return null;
    final modelo = _gestor.catalogo
        .where((m) => m.id == idVoz.substring(0, corte))
        .firstOrNull;
    final sid = int.tryParse(idVoz.substring(corte + 1));
    if (modelo == null || sid == null) return null;
    final voz = modelo.voces.where((v) => v.sid == sid).firstOrNull;
    return voz == null ? null : (modelo: modelo, voz: voz);
  }

  @override
  Motivo motivoSinVoces(Variante variante) =>
      _gestor.catalogo.any((m) => m.cargable && m.ofrece(variante))
      ? Motivo.modeloNoInstalado
      : Motivo.sinVozEnElIdioma;

  @override
  Future<List<VozMotor>> voces(Variante variante) async {
    final voces = <VozMotor>[];
    for (final modelo in _gestor.catalogo) {
      // Sin mirar el disco de los modelos que ni siquiera hablan esa variante.
      if (!modelo.cargable || !modelo.ofrece(variante)) continue;
      if (await _gestor.estado(modelo.id) != EstadoModelo.instalado) continue;
      for (final v in modelo.voces) {
        if (v.variante != variante) continue;
        voces.add(
          VozMotor(
            id: idDeVoz(modelo.id, v.sid),
            fuente: Fuente.modelo,
            nombre: v.nombre,
            variante: variante,
            genero: v.genero,
            local: true,
            locale: variante.etiqueta,
            // Una voz de acento aproximado va al final de la lista.
            calidad: v.acentoAproximado ? 2 : 3,
          ),
        );
      }
    }
    voces.sort((a, b) {
      final q = b.calidad.compareTo(a.calidad);
      return q != 0 ? q : a.nombre.compareTo(b.nombre);
    });
    return voces;
  }

  @override
  Future<Motivo?> motivoNoDisponible(Guion guion, Asignacion asignacion) async {
    final disponibles = await voces(guion.variante);
    if (disponibles.isEmpty) return motivoSinVoces(guion.variante);
    final ids = {for (final v in disponibles) v.id};
    for (final rol in guion.vocesUsadas) {
      final id = asignacion.idVozMotor[rol];
      if (id == null || !ids.contains(id)) return Motivo.vocesInsuficientes;
    }
    // Nunca la misma voz para dos voces de guion (criterio 4).
    final usadas = [
      for (final rol in guion.vocesUsadas) asignacion.idVozMotor[rol],
    ];
    if (usadas.toSet().length != usadas.length) {
      return Motivo.vocesInsuficientes;
    }
    return null;
  }

  // ── Carga del modelo ─────────────────────────────────────────────────────

  Future<void> _asegurarCargado(ModeloDelCatalogo modelo) {
    // Ojo: el cuerpo de `whenComplete` va con llaves; `remove` devuelve el
    // propio futuro y devolverlo lo haría esperarse a sí mismo.
    return _cargando[modelo.id] ??= _cargar(modelo).whenComplete(() {
      _cargando.remove(modelo.id);
    });
  }

  Future<void> _cargar(ModeloDelCatalogo modelo) async {
    final rutas = await _gestor.rutasParaCargar(modelo.id);
    final lexicon = rutas?.lexicon;
    if (rutas == null || lexicon == null) {
      throw const FalloDeSintesis(Fuente.modelo, 'modelo_no_instalado');
    }
    final carga = CargaDeModelo(
      idModelo: modelo.id,
      rutaModelo: rutas.modelo,
      rutaTokens: rutas.tokens,
      rutaLexicon: lexicon,
      hilos: hilos,
    );
    if (_probados.contains(modelo.id)) {
      // Ya se cargó y probó en esta sesión (cargar es barato si sigue en
      // memoria; si el `Isolate` lo había soltado, vuelve a cargarlo).
      await _puerta.cargar(carga);
      return;
    }
    await _gestor.iniciarCarga(modelo.id);
    try {
      await _puerta.cargar(carga);
      // Prueba de humo: el paquete devuelve audio vacío cuando falla.
      final prueba = await _puerta.sintetizar(
        idModelo: modelo.id,
        sid: modelo.voces.first.sid,
        texto: fraseDePruebaDeHumo,
        velocidad: 1.0,
      );
      if (prueba.vacio) {
        throw const FalloDeSintesis(Fuente.modelo, 'prueba_de_humo');
      }
    } on FalloDeSintesis catch (e) {
      if (_fallosDelEntorno.contains(e.codigo)) {
        await _gestor.terminarCarga(modelo.id);
      } else {
        // Un fallo atrapable del modelo: queda dañado hasta que se reintente.
        await _gestor.marcarCorrupto(modelo.id);
      }
      rethrow;
    }
    await _gestor.terminarCarga(modelo.id);
    _probados.add(modelo.id);
  }

  // ── Reproducción ─────────────────────────────────────────────────────────

  @override
  Future<Reproduccion> reproducir(
    Guion guion,
    Asignacion asignacion,
    double velocidad,
  ) async {
    final modelos = <String>{};
    for (final rol in guion.vocesUsadas) {
      final id = asignacion.idVozMotor[rol];
      final r = id == null ? null : _resolver(id);
      if (r == null) {
        throw const FalloDeSintesis(Fuente.modelo, 'voz_no_encontrada');
      }
      modelos.add(r.modelo.id);
    }
    final turnos = _TurnosPorFrases(this, asignacion, velocidad);
    final repro = ReproduccionPorTurnos(
      fuente: Fuente.modelo,
      guion: guion,
      decirTurno: turnos.decir,
      detenerTurno: turnos.detener,
    );
    final activa = _Activa(repro, modelos);
    _activa = activa;
    unawaited(
      repro.terminada.then<void>((_) {}, onError: (Object _) {}).whenComplete(
        () {
          if (identical(_activa, activa)) _activa = null;
          unawaited(turnos.limpiar());
        },
      ),
    );
    return repro;
  }

  /// Si el modelo que se va a borrar es de lo que suena, para antes; y suelta
  /// el modelo de la memoria.
  Future<void> _antesDeBorrar(String idModelo) async {
    final a = _activa;
    if (a != null && a.modelos.contains(idModelo)) await a.repro.parar();
    _probados.remove(idModelo);
    try {
      await _puerta.descargar(idModelo);
    } on Object catch (e) {
      debugPrint('Voz: al liberar un modelo (${e.runtimeType})');
    }
  }

  /// Borra los WAV que hubieran quedado de una sesión anterior.
  Future<void> limpiarTemporales() async {
    try {
      await _fs.borrar(await _carpetaTemporal());
    } on Object catch (e) {
      debugPrint('Voz: al limpiar temporales (${e.runtimeType})');
    }
  }

  /// Libera el `Isolate`, los modelos y el reproductor.
  Future<void> cerrar() async {
    _quitarAviso();
    await _activa?.repro.parar();
    await _puerta.cerrar();
    await _reproductor?.liberar();
    _reproductor = null;
  }
}

class _Activa {
  _Activa(this.repro, this.modelos);
  final ReproduccionPorTurnos repro;
  final Set<String> modelos;
}

/// La frase de un turno, sintetizándose o ya lista.
class _Frase {
  _Frase(this.muestras);
  final Future<MuestrasDeAudio> muestras;
  String? ruta;
}

/// El estado de una reproducción: qué turno va, qué frases tiene sintetizadas
/// y si la cortaron.
class _TurnosPorFrases {
  _TurnosPorFrases(this._f, this._asignacion, this._velocidad);

  final FuenteModelo _f;
  final Asignacion _asignacion;
  final double _velocidad;

  int _indice = -1;
  List<String> _frases = const [];
  List<_Frase?> _hechas = const [];
  int _desde = 0;
  bool _cortado = false;
  Completer<bool>? _suena;
  final _escritos = <String>[];

  Future<ResultadoTurno> decir(int indice, Turno turno) async {
    // Lo primero, sin esperar nada: una pausa que llegue durante las esperas
    // de más abajo no se pierde.
    _cortado = false;
    if (indice != _indice) {
      await _borrarArchivos();
      _indice = indice;
      _frases = partirEnFrases(turno.texto);
      _hechas = List<_Frase?>.filled(_frases.length, null);
      _desde = 0;
    }
    if (_frases.isEmpty) return ResultadoTurno.completo;
    final idVoz = _asignacion.idVozMotor[turno.voz];
    final r = idVoz == null ? null : _f._resolver(idVoz);
    if (r == null) {
      throw const FalloDeSintesis(Fuente.modelo, 'voz_no_encontrada');
    }
    await _f._asegurarCargado(r.modelo);
    if (_cortado) return ResultadoTurno.interrumpido;

    _Frase sintetizar(int k) {
      return _hechas[k] ??= _Frase(
        _f._puerta.sintetizar(
          idModelo: r.modelo.id,
          sid: r.voz.sid,
          texto: _frases[k],
          velocidad: _velocidad,
        )..ignore(),
      );
    }

    for (var k = _desde; k < _frases.length; k++) {
      if (_cortado) {
        _desde = k;
        return ResultadoTurno.interrumpido;
      }
      final frase = sintetizar(k);
      final muestras = await frase.muestras;
      if (muestras.vacio) {
        throw const FalloDeSintesis(Fuente.modelo, 'audio_vacio');
      }
      // Mientras suena esta frase se genera la siguiente.
      if (k + 1 < _frases.length) sintetizar(k + 1);
      if (_cortado) {
        _desde = k;
        return ResultadoTurno.interrumpido;
      }
      final ruta = frase.ruta ??= await _escribir(muestras);
      final completa = await _sonar(ruta);
      if (!completa) {
        _desde = k;
        return ResultadoTurno.interrumpido;
      }
      // Ya sonó: el archivo no hace falta (y el audio, tampoco).
      frase.ruta = null;
      await _borrar(ruta);
      _hechas[k] = null;
      _desde = k + 1;
    }
    _desde = 0;
    return ResultadoTurno.completo;
  }

  /// Reproduce [ruta]; `true` si terminó sola, `false` si la cortaron.
  Future<bool> _sonar(String ruta) async {
    final jugador = _f._jugador;
    final c = _suena = Completer<bool>();
    final oyente = jugador.terminado.listen((_) {
      if (!c.isCompleted) c.complete(true);
    });
    try {
      await jugador.abrir(ruta);
      if (_cortado) return false;
      await jugador.reproducir();
      return await c.future;
    } on ErrorVoz {
      rethrow;
    } on Object catch (e) {
      debugPrint('Voz: al reproducir (${e.runtimeType})');
      throw const FalloDeSintesis(Fuente.modelo, 'reproduccion');
    } finally {
      // Sin `await`: la cancelación de una suscripción devuelve un futuro de
      // la zona raíz que, en las pruebas de widgets (reloj simulado), no
      // llega a completar.
      unawaited(oyente.cancel());
      if (identical(_suena, c)) _suena = null;
    }
  }

  Future<String> _escribir(MuestrasDeAudio audio) async {
    final carpeta = await _f._carpetaTemporal();
    final sep = carpeta.contains(r'\') ? r'\' : '/';
    final ruta = '$carpeta$sep${_f._contadorDeArchivos++}.wav';
    try {
      final escritor = await _f._fs.abrirEscritura(ruta);
      escritor.agregar(codificarWav(audio.muestras, audio.frecuencia));
      await escritor.cerrar();
    } on Object catch (e) {
      debugPrint('Voz: al escribir el audio (${e.runtimeType})');
      throw const FalloDeSintesis(Fuente.modelo, 'disco');
    }
    _escritos.add(ruta);
    return ruta;
  }

  Future<void> _borrar(String ruta) async {
    _escritos.remove(ruta);
    try {
      await _f._fs.borrar(ruta);
    } on Object {
      // Un temporal que no se borra se limpia al arrancar.
    }
  }

  Future<void> _borrarArchivos() async {
    for (final ruta in List.of(_escritos)) {
      await _borrar(ruta);
    }
  }

  Future<void> detener() async {
    _cortado = true;
    final c = _suena;
    if (c != null && !c.isCompleted) c.complete(false);
    await _f._reproductor?.parar();
  }

  Future<void> limpiar() => _borrarArchivos();
}
