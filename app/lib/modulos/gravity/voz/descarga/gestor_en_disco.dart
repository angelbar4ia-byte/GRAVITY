/// El gestor de modelos real: descarga con huella y reanudación, instalación
/// atómica y marca de carga (spec 4.2.2 y 4.2.3).
///
/// Carpetas (bajo la raíz que dé quien lo crea; ver `proveedores.dart`):
///
/// ```
/// <raíz>/<id>/                   modelo instalado (con instalado.json)
/// <raíz>/<id>.descarga/          descarga a medias
///     <archivo>.parcial          lo que va de un archivo
///     <archivo>                  archivo ya verificado
///     estado.json                ETag de cada archivo y cuáles ya verificaron
/// <raíz>/marcas/cargando-<id>    el modelo se estaba cargando
/// <raíz>/marcas/corrupto-<id>    el modelo se marcó dañado
/// ```
///
/// Reglas:
/// - **Ninguna conexión antes de tocar Descargar** y solo con Wi-Fi o
///   Ethernet; con datos móviles hace falta el permiso de esa descarga
///   ([SinWifi] si no), y sin red ([SinRed]) no se abre nada (criterio 18).
/// - **Cada archivo se verifica** (tamaño y sha256 del catálogo) antes de
///   renombrar `.parcial`; si no coincide, se borra TODA la descarga y se
///   lanza [HuellaIncorrecta] sin reintento automático (criterio 22).
/// - **Instalación atómica:** `<id>.descarga` se renombra a `<id>` solo cuando
///   todos los archivos verificaron; un corte nunca deja un modelo a medias
///   como instalado (criterio 23).
/// - **Reanudar:** `Range: bytes=N-` con `If-Range: <ETag>` por la dirección
///   del catálogo. Si el servidor responde 200 completo, el archivo se
///   reinicia sin concatenar (criterios 20 y 21).
/// - **Disco lleno:** se maneja el error del sistema, sin dejar carpetas a
///   medias (criterio 24). El espacio libre se consulta antes si el sistema
///   de archivos sabe medirlo.
/// - Ningún error ni mensaje lleva direcciones completas ni respuestas del
///   servidor (R6, R7).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io' show FileSystemException, Platform;

import 'package:flutter/foundation.dart' show debugPrint;

import '../../../../nucleo/conectividad/tipo_de_red.dart';
import '../modelos/catalogo.dart';
import '../modelos/estado_modelo.dart';
import '../tipos.dart';
import 'gestor_de_modelos.dart';
import 'huella.dart';
import 'puerta_de_descarga.dart';
import 'sistema_de_archivos.dart';

/// Cada cuántos bytes se avisa el progreso (por omisión).
const pasoDeProgresoPorOmision = 256 * 1024;

/// Cada cuántos bytes se espera a que el disco alcance al flujo.
const _pasoDeVaciado = 1024 * 1024;

/// Respuestas que dicen "ese archivo no está (todavía) en el alojamiento".
const _codigosDeNoDisponible = {400, 403, 404, 410};

class GestorDeModelosEnDisco implements GestorDeModelos {
  GestorDeModelosEnDisco({
    required this._catalogo,
    required Future<String> Function() raiz,
    required this._red,
    required this._puerta,
    SistemaDeArchivos archivos = const SistemaDeArchivosReal(),
    this._huella = huellaSha256EnIsolate,
    this._ahora = DateTime.now,
    this.pasoDeProgreso = pasoDeProgresoPorOmision,
  }) : _raizDeseada = raiz,
       _fs = archivos;

  final CatalogoDeVoces _catalogo;
  final Future<String> Function() _raizDeseada;
  final FuenteTipoDeRed _red;
  final PuertaDeDescarga _puerta;
  final SistemaDeArchivos _fs;
  final CalculadoraDeHuella _huella;
  final DateTime Function() _ahora;

  /// Cada cuántos bytes bajados se avisa el progreso.
  final int pasoDeProgreso;

  final _cambios = StreamController<void>.broadcast();
  final _activas = <String, _Descarga>{};
  final _antesDeBorrar = <Future<void> Function(String)>[];
  Future<String>? _raiz;

  static final _sep = Platform.pathSeparator;

  @override
  List<ModeloDelCatalogo> get catalogo => _catalogo.modelos;

  @override
  Stream<void> get cambios => _cambios.stream;

  void _avisar() {
    if (!_cambios.isClosed) _cambios.add(null);
  }

  /// Libera el gestor (cancela lo que descargue).
  Future<void> cerrar() async {
    for (final id in _activas.keys.toList()) {
      await cancelar(id);
    }
    await _cambios.close();
  }

  Future<String> _raizDelGestor() => _raiz ??= _raizDeseada();

  String _u(String a, String b) => '$a$_sep$b';

  Future<String> _carpetaDe(String id) async => _u(await _raizDelGestor(), id);
  Future<String> _carpetaDeDescarga(String id) async =>
      _u(await _raizDelGestor(), '$id.descarga');
  Future<String> _marca(String tipo, String id) async =>
      _u(_u(await _raizDelGestor(), 'marcas'), '$tipo-$id');

  ModeloDelCatalogo _modelo(String id) {
    final m = _catalogo.porId(id);
    if (m == null) {
      throw const FalloDeSintesis(Fuente.modelo, 'modelo_desconocido');
    }
    return m;
  }

  // ── Estado ────────────────────────────────────────────────────────────────

  @override
  Future<EstadoModelo> estado(String idModelo) async {
    _modelo(idModelo);
    if (_activas.containsKey(idModelo)) return EstadoModelo.descargando;
    return _estadoEnDisco(_modelo(idModelo));
  }

  /// El estado que dice el disco, sin mirar si hay una descarga en curso.
  Future<EstadoModelo> _estadoEnDisco(ModeloDelCatalogo modelo) async {
    final idModelo = modelo.id;
    final carpeta = await _carpetaDe(idModelo);
    final instalado = await _leerInstalado(carpeta);
    final hayCarpeta = await _fs.existeCarpeta(carpeta);
    final conMarca =
        await _fs.existeArchivo(await _marca('cargando', idModelo)) ||
        await _fs.existeArchivo(await _marca('corrupto', idModelo));
    if (!hayCarpeta) {
      if (conMarca) await _limpiarMarcas(idModelo);
      return EstadoModelo.noDescargado;
    }
    // Una carpeta sin `instalado.json` no es un modelo instalado.
    if (instalado == null) return EstadoModelo.noDescargado;
    // El catálogo cambió (otra revisión o huellas): esa copia ya no sirve.
    if (!_coincideConElCatalogo(instalado, modelo)) {
      return EstadoModelo.noDescargado;
    }
    if (conMarca) return EstadoModelo.corrupto;
    // Al arrancar solo se comprueban los tamaños (4.2.2, punto 9).
    for (final a in modelo.archivos) {
      if (await _fs.largo(_u(carpeta, a.nombre)) != a.bytes) {
        return EstadoModelo.corrupto;
      }
    }
    return EstadoModelo.instalado;
  }

  Future<Map<String, Object?>?> _leerInstalado(String carpeta) async {
    final texto = await _fs.leerTexto(_u(carpeta, 'instalado.json'));
    if (texto == null) return null;
    try {
      final json = jsonDecode(texto);
      return json is Map<String, Object?> ? json : null;
    } on FormatException {
      return null;
    }
  }

  bool _coincideConElCatalogo(
    Map<String, Object?> instalado,
    ModeloDelCatalogo modelo,
  ) {
    if (instalado['revision'] != modelo.fuente.revision) return false;
    final archivos = instalado['archivos'];
    if (archivos is! List || archivos.length != modelo.archivos.length) {
      return false;
    }
    final porNombre = {
      for (final a in archivos)
        if (a is Map) '${a['nombre']}': a['sha256'],
    };
    for (final a in modelo.archivos) {
      if (porNombre[a.nombre] != a.sha256) return false;
    }
    return true;
  }

  Future<void> _limpiarMarcas(String id) async {
    await _fs.borrar(await _marca('cargando', id));
    await _fs.borrar(await _marca('corrupto', id));
  }

  @override
  Future<int> bytesDescargados(String idModelo) async {
    final modelo = _modelo(idModelo);
    final carpeta = await _carpetaDeDescarga(idModelo);
    var suma = 0;
    for (final a in modelo.archivos) {
      suma +=
          await _fs.largo(_u(carpeta, a.nombre)) ??
          await _fs.largo(_u(carpeta, '${a.nombre}.parcial')) ??
          0;
    }
    return suma;
  }

  @override
  Future<int> bytesOcupados() async => _fs.bytesEn(await _raizDelGestor());

  @override
  Future<int> bytesOcupadosPor(String idModelo) async =>
      await _fs.bytesEn(await _carpetaDe(idModelo)) +
      await _fs.bytesEn(await _carpetaDeDescarga(idModelo));

  // ── Descarga ──────────────────────────────────────────────────────────────

  @override
  Stream<ProgresoDescarga>? seguir(String idModelo) =>
      _activas[idModelo]?.flujo();

  @override
  Stream<ProgresoDescarga> descargar(
    String idModelo, {
    bool permitirDatosMoviles = false,
  }) {
    final existente = _activas[idModelo];
    if (existente != null) return existente.flujo();
    final ModeloDelCatalogo modelo;
    try {
      modelo = _modelo(idModelo);
    } on ErrorVoz catch (e) {
      return Stream<ProgresoDescarga>.error(e);
    }
    final descarga = _Descarga();
    _activas[idModelo] = descarga;
    // `unawaited`: el resultado llega por el flujo. Lo primero que hace es
    // esperar la red, así quien llama alcanza a escuchar antes de cualquier
    // evento.
    unawaited(
      _correr(modelo, permitirDatosMoviles, descarga).whenComplete(() {
        _activas.remove(idModelo);
        _avisar();
      }),
    );
    _avisar();
    return descarga.flujo();
  }

  Future<void> _correr(
    ModeloDelCatalogo modelo,
    bool permitirDatosMoviles,
    _Descarga d,
  ) async {
    ErrorVoz? fallo;
    try {
      // 1. Red: sin abrir ninguna conexión todavía (criterio 18).
      final tipo = await _red.tipo();
      if (tipo == TipoDeRed.sinRed) throw const SinRed();
      if (!tipo.esSinCostoDeDatos && !permitirDatosMoviles) {
        throw const SinWifi();
      }
      // 2. Ya instalado: nada que bajar.
      final instalado = await _estadoEnDisco(modelo);
      if (instalado == EstadoModelo.instalado) {
        d.emitir(
          ProgresoDescarga(
            modelo.bytes,
            modelo.bytes,
            modelo.archivos.last.nombre,
          ),
        );
        return;
      }
      if (instalado == EstadoModelo.corrupto) {
        // Descargar de nuevo reemplaza lo dañado.
        await _fs.borrar(await _carpetaDe(modelo.id));
        await _limpiarMarcas(modelo.id);
      }
      await _bajarTodo(modelo, d);
    } on ErrorVoz catch (e) {
      fallo = e;
    } on FileSystemException catch (e) {
      fallo = esDiscoLleno(e)
          ? SinEspacio(d.faltaPorBajar)
          : const FalloDeSintesis(Fuente.modelo, 'disco');
      if (fallo is SinEspacio) await _borrarDescarga(modelo.id);
    } catch (e) {
      // Nunca se copia el mensaje: podría traer una dirección (R6, R7).
      debugPrint('Voz: descarga fallida (${e.runtimeType})');
      fallo = const FalloDeSintesis(Fuente.modelo, 'error_inesperado');
    } finally {
      // Siempre se avisa el final, también cuando no había nada que bajar.
      d.terminar(fallo);
    }
  }

  Future<void> _borrarDescarga(String id) async {
    try {
      await _fs.borrar(await _carpetaDeDescarga(id));
    } on FileSystemException {
      // Si ni siquiera se puede borrar, no hay más que hacer.
    }
  }

  Future<void> _bajarTodo(ModeloDelCatalogo modelo, _Descarga d) async {
    final carpeta = await _carpetaDeDescarga(modelo.id);
    var estadoDescarga = await _EstadoDeDescarga.leer(_fs, carpeta);
    // Otra revisión del catálogo: lo que había a medias no sirve.
    if (estadoDescarga.revision != null &&
        estadoDescarga.revision != modelo.fuente.revision) {
      await _fs.borrar(carpeta);
      estadoDescarga = _EstadoDeDescarga();
    }
    estadoDescarga.revision = modelo.fuente.revision;
    await _fs.crearCarpeta(carpeta);

    // Espacio libre (si el sistema sabe medirlo): lo que falta por bajar.
    final yaBajado = await bytesDescargados(modelo.id);
    d.total = modelo.bytes;
    d.acumulado = 0;
    final pendiente = modelo.bytes - yaBajado;
    final libres = await _fs.bytesLibres(carpeta);
    if (libres != null && libres < pendiente) {
      await _borrarDescarga(modelo.id);
      throw SinEspacio(pendiente - libres);
    }

    for (final archivo in modelo.archivos) {
      if (d.cancelada) return;
      await _bajarArchivo(modelo, archivo, carpeta, estadoDescarga, d);
    }
    if (d.cancelada) return;

    // Instalación atómica: la marca va dentro y la carpeta se renombra al
    // final.
    await _fs.escribirTexto(
      _u(carpeta, 'instalado.json'),
      jsonEncode({
        'esquema': 'gravity-voces-instalado-v1',
        'id': modelo.id,
        'revision': modelo.fuente.revision,
        'instalado': _ahora().toUtc().toIso8601String(),
        'archivos': [
          for (final a in modelo.archivos)
            {'nombre': a.nombre, 'bytes': a.bytes, 'sha256': a.sha256},
        ],
      }),
    );
    await _fs.borrar(_u(carpeta, 'estado.json'));
    final destino = await _carpetaDe(modelo.id);
    await _fs.renombrar(carpeta, destino);
    d.emitir(
      ProgresoDescarga(modelo.bytes, modelo.bytes, modelo.archivos.last.nombre),
    );
  }

  Future<void> _bajarArchivo(
    ModeloDelCatalogo modelo,
    ArchivoDeModelo archivo,
    String carpeta,
    _EstadoDeDescarga ed,
    _Descarga d,
  ) async {
    final nombre = archivo.nombre;
    final destino = _u(carpeta, nombre);
    final parcial = _u(carpeta, '$nombre.parcial');

    // Ya verificado en una descarga anterior: no se pide otra vez.
    if (ed.verificados.contains(nombre)) {
      if (await _fs.largo(destino) == archivo.bytes) {
        d.acumulado += archivo.bytes;
        d.emitir(ProgresoDescarga(d.acumulado, d.total, nombre));
        return;
      }
      ed.verificados.remove(nombre);
      await _fs.borrar(destino);
    }

    var n = await _fs.largo(parcial) ?? 0;
    final etag = ed.etags[nombre];
    // Sin ETag no hay forma de saber si el archivo cambió: se empieza de nuevo.
    if (n > archivo.bytes || (n > 0 && etag == null)) {
      await _fs.borrar(parcial);
      n = 0;
    }

    var reintentoSinRango = false;
    while (true) {
      if (d.cancelada) return;
      final cabeceras = <String, String>{
        'Accept-Encoding': 'identity',
        'User-Agent': userAgentDeDescarga,
        if (n > 0 && n < archivo.bytes) ...{
          'Range': 'bytes=$n-',
          'If-Range': etag!,
        },
      };
      RespuestaDeDescarga? respuesta;
      EscritorDeArchivo? escritor;
      try {
        if (n < archivo.bytes) {
          try {
            respuesta = await _puerta.pedir(archivo.url, cabeceras: cabeceras);
          } on Object catch (e) {
            // Antes de la respuesta: no hay conexión (o no se pudo abrir).
            debugPrint('Voz: sin respuesta (${e.runtimeType})');
            throw const SinRed();
          }
          d.respuesta = respuesta;
          final codigo = respuesta.codigo;
          if (_codigosDeNoDisponible.contains(codigo)) {
            throw const NoDisponibleAun();
          }
          if (codigo == 416) {
            // El servidor no acepta el rango: se empieza el archivo de nuevo.
            await _fs.borrar(parcial);
            if (n == 0 || reintentoSinRango) {
              throw DescargaInterrumpida(d.acumulado, d.total);
            }
            reintentoSinRango = true;
            n = 0;
            continue;
          }
          if (codigo != 200 && codigo != 206) {
            throw DescargaInterrumpida(d.acumulado, d.total);
          }
          var anexar = false;
          if (codigo == 206) {
            final r = respuesta.contentRange;
            if (n > 0 && r != null && r.startsWith('bytes $n-')) {
              anexar = true;
            } else if (n > 0) {
              // Una respuesta parcial que no empieza donde se pidió: no se
              // pega a lo que ya hay.
              await respuesta.cerrar();
              await _fs.borrar(parcial);
              if (reintentoSinRango) {
                throw DescargaInterrumpida(d.acumulado, d.total);
              }
              reintentoSinRango = true;
              n = 0;
              continue;
            }
          }
          if (!anexar) {
            // 200 completo (el servidor ignoró `Range` o el archivo cambió):
            // se reinicia este archivo, sin concatenar.
            n = 0;
          }
          final largo = respuesta.largoDelCuerpo;
          if (largo != null && largo != archivo.bytes - n) {
            // El servidor tiene otro archivo: no vale la pena bajarlo.
            await _borrarDescarga(modelo.id);
            throw HuellaIncorrecta(nombre);
          }
          if (respuesta.etag != null) ed.etags[nombre] = respuesta.etag!;
          await ed.guardar(_fs, carpeta);
          escritor = await _fs.abrirEscritura(parcial, anexar: anexar);
          d.acumulado += n;
          d.emitir(ProgresoDescarga(d.acumulado, d.total, nombre));
          var desdeElUltimoAviso = 0;
          var desdeElUltimoVaciado = 0;
          try {
            await for (final trozo in respuesta.cuerpo) {
              if (d.cancelada) break;
              escritor.agregar(trozo);
              n += trozo.length;
              d.acumulado += trozo.length;
              desdeElUltimoAviso += trozo.length;
              desdeElUltimoVaciado += trozo.length;
              if (desdeElUltimoVaciado >= _pasoDeVaciado) {
                desdeElUltimoVaciado = 0;
                await escritor.vaciar();
              }
              if (desdeElUltimoAviso >= pasoDeProgreso) {
                desdeElUltimoAviso = 0;
                d.emitir(ProgresoDescarga(d.acumulado, d.total, nombre));
              }
            }
          } on FileSystemException {
            rethrow;
          } on Object catch (e) {
            // Se cortó a la mitad: se guarda lo que llegó para reanudar.
            debugPrint('Voz: descarga cortada (${e.runtimeType})');
            try {
              await escritor.cerrar();
            } on FileSystemException {
              // Lo guardado hasta aquí es lo que hay.
            }
            escritor = null;
            // Si la cortó quien canceló, no es un fallo.
            if (d.cancelada) return;
            throw DescargaInterrumpida(d.acumulado, d.total);
          }
          await escritor.cerrar();
          escritor = null;
          if (d.cancelada) return;
          if (n < archivo.bytes) {
            throw DescargaInterrumpida(d.acumulado, d.total);
          }
          if (n > archivo.bytes) {
            await _borrarDescarga(modelo.id);
            throw HuellaIncorrecta(nombre);
          }
          d.emitir(ProgresoDescarga(d.acumulado, d.total, nombre));
        } else {
          // Ya estaba completo y sin verificar (se cortó justo ahí).
          d.acumulado += n;
        }
        // Verificación antes de renombrar (criterio 22).
        if (await _fs.largo(parcial) != archivo.bytes ||
            await _huella(parcial) != archivo.sha256) {
          await _borrarDescarga(modelo.id);
          throw HuellaIncorrecta(nombre);
        }
        await _fs.renombrar(parcial, destino);
        ed.verificados.add(nombre);
        await ed.guardar(_fs, carpeta);
        return;
      } finally {
        if (escritor != null) {
          try {
            await escritor.cerrar();
          } on Object {
            // Ya se está saliendo por otro error.
          }
        }
        await respuesta?.cerrar();
        d.respuesta = null;
      }
    }
  }

  @override
  Future<void> cancelar(String idModelo) async {
    final d = _activas[idModelo];
    if (d == null) return;
    d.cancelada = true;
    await d.respuesta?.cerrar();
    try {
      await d.terminada;
    } on Object {
      // El resultado ya le llega a quien escucha el flujo.
    }
  }

  // ── Borrar, comprobar, reintentar ────────────────────────────────────────

  @override
  void Function() antesDeBorrar(Future<void> Function(String idModelo) hacer) {
    _antesDeBorrar.add(hacer);
    return () => _antesDeBorrar.remove(hacer);
  }

  @override
  Future<int> borrar(String idModelo) async {
    _modelo(idModelo);
    for (final hacer in List.of(_antesDeBorrar)) {
      try {
        await hacer(idModelo);
      } on Object catch (e) {
        debugPrint('Voz: antes de borrar (${e.runtimeType})');
      }
    }
    await cancelar(idModelo);
    final bytes = await bytesOcupadosPor(idModelo);
    await _fs.borrar(await _carpetaDe(idModelo));
    await _fs.borrar(await _carpetaDeDescarga(idModelo));
    await _limpiarMarcas(idModelo);
    _avisar();
    return bytes;
  }

  @override
  Future<bool> comprobar(String idModelo) async {
    final modelo = _modelo(idModelo);
    final carpeta = await _carpetaDe(idModelo);
    for (final a in modelo.archivos) {
      final ruta = _u(carpeta, a.nombre);
      if (await _fs.largo(ruta) != a.bytes || await _huella(ruta) != a.sha256) {
        await marcarCorrupto(idModelo);
        return false;
      }
    }
    return true;
  }

  @override
  Future<EstadoModelo> reintentar(String idModelo) async {
    _modelo(idModelo);
    await _limpiarMarcas(idModelo);
    if (await _estadoEnDisco(_modelo(idModelo)) == EstadoModelo.instalado) {
      await comprobar(idModelo);
    }
    _avisar();
    return estado(idModelo);
  }

  @override
  Future<RutasDelModelo?> rutasParaCargar(String idModelo) async {
    final modelo = _modelo(idModelo);
    if (await estado(idModelo) != EstadoModelo.instalado) return null;
    final carpeta = await _carpetaDe(idModelo);
    return RutasDelModelo(
      carpeta: carpeta,
      modelo: _u(carpeta, modelo.archivoDe(RolDeArchivo.modelo).nombre),
      tokens: _u(carpeta, modelo.archivoDe(RolDeArchivo.tokens).nombre),
      lexicon: modelo.archivoOpcional(RolDeArchivo.lexicon) == null
          ? null
          : _u(carpeta, modelo.archivoDe(RolDeArchivo.lexicon).nombre),
    );
  }

  // ── Marca de carga ───────────────────────────────────────────────────────

  @override
  Future<void> iniciarCarga(String idModelo) async {
    _modelo(idModelo);
    await _fs.escribirTexto(
      await _marca('cargando', idModelo),
      _ahora().toUtc().toIso8601String(),
    );
  }

  @override
  Future<void> terminarCarga(String idModelo) async {
    _modelo(idModelo);
    await _fs.borrar(await _marca('cargando', idModelo));
  }

  @override
  Future<void> marcarCorrupto(String idModelo) async {
    _modelo(idModelo);
    await _fs.escribirTexto(
      await _marca('corrupto', idModelo),
      _ahora().toUtc().toIso8601String(),
    );
    await _fs.borrar(await _marca('cargando', idModelo));
    _avisar();
  }
}

/// Una descarga en curso: quién la sigue, cuánto va y cómo terminó.
class _Descarga {
  final _oyentes = <MultiStreamController<ProgresoDescarga>>[];
  final _fin = Completer<void>();
  ProgresoDescarga? _ultimo;
  bool _hecha = false;
  ErrorVoz? _error;

  bool cancelada = false;
  RespuestaDeDescarga? respuesta;
  int total = 0;
  int acumulado = 0;

  _Descarga() {
    _fin.future.ignore();
  }

  int get faltaPorBajar => total - acumulado;

  Future<void> get terminada => _fin.future;

  Stream<ProgresoDescarga> flujo() => Stream.multi((c) {
    final u = _ultimo;
    if (u != null) c.add(u);
    if (_hecha) {
      final e = _error;
      if (e != null) c.addError(e);
      c.close();
      return;
    }
    _oyentes.add(c);
    c.onCancel = () => _oyentes.remove(c);
  });

  void emitir(ProgresoDescarga p) {
    _ultimo = p;
    for (final c in List.of(_oyentes)) {
      c.add(p);
    }
  }

  void terminar(ErrorVoz? error) {
    if (_hecha) return;
    _hecha = true;
    _error = error;
    for (final c in List.of(_oyentes)) {
      if (error != null) c.addError(error);
      c.close();
    }
    _oyentes.clear();
    if (!_fin.isCompleted) _fin.complete();
  }
}

/// `estado.json` de una descarga a medias: el ETag de cada archivo (para
/// `If-Range`) y cuáles ya verificaron.
class _EstadoDeDescarga {
  _EstadoDeDescarga();

  String? revision;
  final etags = <String, String>{};
  final verificados = <String>{};

  static Future<_EstadoDeDescarga> leer(
    SistemaDeArchivos fs,
    String carpeta,
  ) async {
    final e = _EstadoDeDescarga();
    final texto = await fs.leerTexto(
      '$carpeta${Platform.pathSeparator}estado.json',
    );
    if (texto == null) return e;
    try {
      final json = jsonDecode(texto);
      if (json is Map) {
        e.revision = json['revision'] as String?;
        final tags = json['etags'];
        if (tags is Map) {
          tags.forEach((k, v) {
            if (k is String && v is String) e.etags[k] = v;
          });
        }
        final ver = json['verificados'];
        if (ver is List) e.verificados.addAll(ver.whereType<String>());
      }
    } on FormatException {
      // Un estado ilegible se ignora: se vuelve a empezar.
    }
    return e;
  }

  Future<void> guardar(SistemaDeArchivos fs, String carpeta) =>
      fs.escribirTexto(
        '$carpeta${Platform.pathSeparator}estado.json',
        jsonEncode({
          'revision': revision,
          'etags': etags,
          'verificados': verificados.toList(),
        }),
      );
}
