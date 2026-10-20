/// Dónde está la página local de Swagger UI (`api/swagger/index.html`) y cómo
/// abrirla (D16).
library;

import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

/// Ruta configurada al compilar:
/// `--dart-define=RUTA_SWAGGER=C:\ruta\gravity\api\swagger\index.html`
/// (o una dirección `http://` si se sirve `api/` con un servidor local).
const String rutaSwaggerConfigurada = String.fromEnvironment('RUTA_SWAGGER');

/// Abre una dirección; `true` si se pudo.
typedef AbrirUrl = Future<bool> Function(Uri uri);

/// `true` si existe el archivo.
typedef ExisteArchivo = bool Function(String ruta);

/// Abre con el navegador predeterminado (url_launcher).
Future<bool> abrirConNavegador(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// Revisa el disco.
bool existeEnDisco(String ruta) => File(ruta).existsSync();

/// Resultado de buscar la página.
sealed class UbicacionSwagger {
  const UbicacionSwagger();
}

/// Se encontró: se abre [uri].
final class SwaggerEncontrado extends UbicacionSwagger {
  const SwaggerEncontrado(this.uri);

  final Uri uri;
}

/// No se encontró. [rutaConfigurada] es `null` si no se configuró ninguna.
final class SwaggerNoEncontrado extends UbicacionSwagger {
  const SwaggerNoEncontrado(this.rutaConfigurada);

  final String? rutaConfigurada;
}

final RegExp _unidadWindows = RegExp(r'^[A-Za-z]:[\\/]');

final RegExp _uriWindows = RegExp(r'^file:///[A-Za-z]:');

bool _pareceWindows(String ruta) =>
    _unidadWindows.hasMatch(ruta) ||
    _uriWindows.hasMatch(ruta) ||
    ruta.contains(r'\');

Uri _uriDeArchivo(String ruta) =>
    Uri.file(ruta, windows: _pareceWindows(ruta)).normalizePath();

/// Busca la página de Swagger UI.
///
/// 1. [rutaConfigurada] (`RUTA_SWAGGER`): una dirección `http(s)://` se usa tal
///    cual; una ruta de archivo, solo si existe.
/// 2. Sin configurar: `api/swagger/index.html` junto a [directorioActual]
///    (`flutter run` desde `app/` o desde la raíz del repositorio).
UbicacionSwagger ubicarSwagger({
  required String rutaConfigurada,
  required String directorioActual,
  required ExisteArchivo existe,
}) {
  final configurada = rutaConfigurada.trim();
  if (configurada.startsWith('http://') || configurada.startsWith('https://')) {
    return SwaggerEncontrado(Uri.parse(configurada));
  }
  if (configurada.isNotEmpty) {
    final ruta = configurada.startsWith('file://')
        ? Uri.parse(configurada)
              .toFilePath(windows: _pareceWindows(configurada))
        : configurada;
    return existe(ruta)
        ? SwaggerEncontrado(_uriDeArchivo(ruta))
        : SwaggerNoEncontrado(configurada);
  }

  final separador = _pareceWindows(directorioActual) ? r'\' : '/';
  final base = directorioActual.endsWith(separador)
      ? directorioActual.substring(0, directorioActual.length - 1)
      : directorioActual;
  final pagina = ['api', 'swagger', 'index.html'].join(separador);
  for (final candidata in [
    '$base$separador..$separador$pagina',
    '$base$separador$pagina',
  ]) {
    if (existe(candidata)) return SwaggerEncontrado(_uriDeArchivo(candidata));
  }
  return const SwaggerNoEncontrado(null);
}

/// Cómo abrirla a mano.
const String instruccionesSwagger =
    'Para abrir Swagger UI:\n'
    '1. Abre api/swagger/index.html del repositorio en el navegador (doble clic).\n'
    '2. O indica la ruta al compilar la app:\n'
    r'   flutter run -d windows --dart-define=RUTA_SWAGGER=C:\ruta\gravity\api\swagger\index.html'
    '\n'
    '3. Para leer openapi.yaml en vivo, sirve la carpeta api/ solo en este equipo '
    '(npx --yes http-server@14.1.1 api -p 8080 -a 127.0.0.1; sin -a 127.0.0.1 '
    'la vería toda la red de la casa) y usa '
    'http://127.0.0.1:8080/swagger/index.html como RUTA_SWAGGER.';
