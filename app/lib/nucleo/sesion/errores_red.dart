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
