/// Ejecutor real de la laptop Windows (D8, Fase 6b). Solo abre y lee.
///
/// Reglas:
/// - Solo ejecuta las acciones de apertura y lectura de la lista cerrada:
///   `abrir_programa`, `abrir_archivo`, `buscar_archivos`, `abrir_pantalla`.
/// - Los procesos se lanzan con ejecutable y lista de argumentos **fijos**
///   (`runInShell: false`): nunca se arma una cadena para un intérprete de
///   comandos.
/// - Vuelve a validar contra [ConfigControlLaptop] aunque la orden ya haya
///   pasado por `traducirOrden` (defensa en profundidad).
/// - Gmail y Calendar pasan por el servidor, no por aquí. Borrar, mover,
///   instalar o pagar no existen.
library;

import 'dart:io';

import '../../../nucleo/contratos/rutas.dart';
import 'acciones.dart';
import 'ejecutor.dart';

/// Lanza un proceso sin esperar. `true` si arrancó. Se cambia en las pruebas.
typedef LanzadorProceso = Future<bool> Function(
  String ejecutable,
  List<String> argumentos,
);

/// Lista los nombres de archivo de [carpeta] que contienen [consulta].
typedef ListadorArchivos = Future<List<String>> Function(
  String carpeta,
  String consulta,
  int limite,
);

/// Abre una pantalla de GRAVITY por su ruta.
typedef AbridorPantalla = void Function(String ruta);

/// Ejecutable de Windows que abre un archivo con su programa predeterminado,
/// sin intérprete de comandos.
const rundll32 = 'rundll32.exe';
const _manejadorArchivo = 'url.dll,FileProtocolHandler';

/// Extensiones que se ejecutan en lugar de abrirse: no se abren por aquí.
const extensionesBloqueadas = {
  'exe',
  'com',
  'bat',
  'cmd',
  'msi',
  'ps1',
  'psm1',
  'vbs',
  'vbe',
  'js',
  'jse',
  'wsf',
  'wsh',
  'scr',
  'lnk',
  'reg',
  'hta',
  'cpl',
  'dll',
  'jar',
  'msc',
  'pif',
  'gadget',
  'application',
  'appx',
  'msix',
};

/// Máximo de nombres que devuelve una búsqueda.
const limiteBusqueda = 10;

/// Ruta de pantalla de cada módulo que se puede abrir.
const rutaDeModulo = {
  'finanzas': Rutas.finanzas,
  'habitos': Rutas.habitos,
  'cuidados': Rutas.cuidados,
  'alimentacion': Rutas.alimentacion,
  'casa': Rutas.casa,
  'gravity': Rutas.inicio,
  'ajustes': Rutas.ajustes,
};

final _metacaracteres = RegExp(r'[&|;<>^%"`$\r\n\t*?]');

/// `true` si [nombre] es un nombre de programa simple (sin metacaracteres de
/// shell, sin rutas relativas).
bool nombreDeProgramaValido(String nombre) =>
    nombre.trim().isNotEmpty &&
    nombre == nombre.trim() &&
    !_metacaracteres.hasMatch(nombre) &&
    !nombre.split(RegExp(r'[\\/]')).contains('..');

String _normRuta(String r) => r.replaceAll('\\', '/');

bool _dentroDePermitidas(String ruta, List<String> carpetas) {
  final r = _normRuta(ruta);
  if (r.isEmpty || r.split('/').contains('..') || _metacaracteres.hasMatch(r)) {
    return false;
  }
  return carpetas.any((c) {
    final base = _normRuta(c).replaceAll(RegExp(r'/+$'), '');
    return base.isNotEmpty && (r == base || r.startsWith('$base/'));
  });
}

class EjecutorLaptopWindows implements EjecutorLaptop {
  EjecutorLaptopWindows({
    this.config = const ConfigControlLaptop(),
    LanzadorProceso? lanzador,
    ListadorArchivos? listador,
    this.abrirPantalla,
    bool? esWindows,
  }) : _lanzador = lanzador ?? _lanzarReal,
       _listador = listador ?? _listarReal,
       _esWindows = esWindows ?? Platform.isWindows;

  final ConfigControlLaptop config;
  final AbridorPantalla? abrirPantalla;
  final LanzadorProceso _lanzador;
  final ListadorArchivos _listador;
  final bool _esWindows;

  static const _no = ResultadoEjecucion(
    exito: false,
    resumen: 'No se pudo hacer eso.',
  );

  @override
  Future<ResultadoEjecucion> ejecutar(Accion accion) async {
    try {
      switch (accion) {
        case AbrirPrograma(:final programa):
          if (!_esWindows) return _noWindows;
          if (!config.programasPermitidos.contains(programa) ||
              !nombreDeProgramaValido(programa)) {
            return const ResultadoEjecucion(
              exito: false,
              resumen: 'Ese programa no está permitido.',
            );
          }
          // Sin argumentos: solo se abre el programa.
          final ok = await _lanzador(programa, const []);
          return ResultadoEjecucion(
            exito: ok,
            resumen: ok ? 'Programa abierto.' : 'No pude abrir el programa.',
          );
        case AbrirArchivo(:final ruta):
          if (!_esWindows) return _noWindows;
          if (!_dentroDePermitidas(ruta, config.carpetasPermitidas)) {
            return const ResultadoEjecucion(
              exito: false,
              resumen: 'Ese archivo está fuera de las carpetas permitidas.',
            );
          }
          if (_esEjecutable(ruta)) {
            return const ResultadoEjecucion(
              exito: false,
              resumen: 'Ese tipo de archivo no se abre desde GRAVITY.',
            );
          }
          final ok = await _lanzador(rundll32, [_manejadorArchivo, ruta]);
          return ResultadoEjecucion(
            exito: ok,
            resumen: ok ? 'Archivo abierto.' : 'No pude abrir el archivo.',
          );
        case BuscarArchivos(:final carpeta, :final consulta):
          if (!_dentroDePermitidas(carpeta, config.carpetasPermitidas)) {
            return const ResultadoEjecucion(
              exito: false,
              resumen: 'Esa carpeta no está permitida.',
            );
          }
          final nombres = await _listador(carpeta, consulta, limiteBusqueda);
          return ResultadoEjecucion(
            exito: true,
            resumen: nombres.isEmpty
                ? 'No encontré archivos.'
                : 'Encontré ${nombres.length}: ${nombres.join(', ')}',
          );
        case AbrirPantalla(:final modulo):
          final ruta = rutaDeModulo[modulo];
          final abrir = abrirPantalla;
          if (ruta == null || abrir == null) return _no;
          abrir(ruta);
          return const ResultadoEjecucion(
            exito: true,
            resumen: 'Pantalla abierta.',
          );
        case GmailLeer() ||
            GmailRedactar() ||
            GmailEnviar() ||
            CalendarVer() ||
            CalendarCrear():
          return const ResultadoEjecucion(
            exito: false,
            resumen: 'Gmail y Calendar pasan por el servidor de GRAVITY.',
          );
      }
    } catch (_) {
      return _no;
    }
  }

  static const _noWindows = ResultadoEjecucion(
    exito: false,
    resumen: 'Esto solo funciona en la laptop con Windows.',
  );

  static bool _esEjecutable(String ruta) {
    final nombre = _normRuta(ruta).split('/').last;
    final punto = nombre.lastIndexOf('.');
    if (punto < 0) return false;
    return extensionesBloqueadas.contains(
      nombre.substring(punto + 1).toLowerCase(),
    );
  }
}

Future<bool> _lanzarReal(String ejecutable, List<String> argumentos) async {
  await Process.start(
    ejecutable,
    argumentos,
    runInShell: false,
    mode: ProcessStartMode.detached,
  );
  return true;
}

Future<List<String>> _listarReal(
  String carpeta,
  String consulta,
  int limite,
) async {
  final q = consulta.toLowerCase();
  final salida = <String>[];
  await for (final e in Directory(carpeta).list(followLinks: false)) {
    if (e is! File) continue;
    final nombre = _normRuta(e.path).split('/').last;
    if (nombre.toLowerCase().contains(q)) salida.add(nombre);
    if (salida.length >= limite) break;
  }
  return salida;
}
