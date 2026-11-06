/// Distingue la falta de red de los demás errores (revisión de la Fase 0, I3
/// e I4): sin red se usa lo guardado y la cola reintenta; con cualquier otro
/// error, no.
library;

import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// `true` si [error] es falta de red o de respuesta (sin señal, servidor
/// inalcanzable, tiempo agotado), no una respuesta del servidor.
bool esErrorDeRed(Object error) =>
    error is SocketException ||
    error is TimeoutException ||
    error is HandshakeException ||
    error is http.ClientException ||
    error is AuthRetryableFetchException;

/// `true` si [error], al renovar una credencial guardada, dice **con claridad**
/// que ya no sirve: el servidor respondió con un error 4xx de cliente (token
/// no encontrado, ya usado, sesión cerrada…). Ese es el único caso en que se
/// borra la credencial guardada de una persona.
///
/// Un error pasajero no lo es (revisión de la Fase 1b, B2): el límite de
/// peticiones (429), el tiempo agotado (408), un 5xx, la falta de red o algo
/// inesperado dejan la credencial como está para reintentar; borrarla
/// mandaría lo pendiente a "requiere atención" por un tropiezo de un rato.
bool credencialYaNoSirve(Object error) {
  if (error is! AuthException || esErrorDeRed(error)) return false;
  final estado = int.tryParse(error.statusCode ?? '');
  if (estado == null || estado == 408 || estado == 429) return false;
  return estado >= 400 && estado < 500;
}
