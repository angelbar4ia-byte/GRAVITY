/// Cliente de las herramientas de Gmail y Google Calendar del asistente
/// (Fase 6, parte 2).
///
/// Habla con la misma función de servidor `gravity-asistente`. La app **no**
/// lleva claves ni tokens de Google: el servidor guarda el token de cada
/// persona cifrado y ejecuta la herramienta con la cuenta de quien pregunta.
/// Lo que Google devuelve (correos, eventos) llega aquí y se muestra en la
/// pantalla; **nunca** se manda al modelo de IA (D3).
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import 'cliente_asistente.dart' show ErrorAsistente;

/// Herramientas de Google que el asistente puede elegir (el modelo solo elige
/// el nombre).
const Set<String> herramientasGoogle = {
  'gmail.leer',
  'gmail.redactar',
  'calendario.ver',
  'calendario.crear',
};

bool esHerramientaGoogle(String nombre) => herramientasGoogle.contains(nombre);

/// Escribir en la cuenta (enviar, crear) pide formulario y confirmación.
bool googleRequiereFormulario(String nombre) =>
    nombre == 'gmail.redactar' || nombre == 'calendario.crear';

/// Lo que el servidor pide confirmar antes de enviar o crear.
class ConfirmacionGoogle {
  const ConfirmacionGoogle({
    required this.herramienta,
    required this.parametros,
    required this.titulo,
    required this.lineas,
    required this.boton,
  });

  /// Herramienta que se ejecuta al confirmar (`gmail.enviar` o
  /// `calendario.crear`) y los parámetros que el servidor validó.
  final String herramienta;
  final Map<String, Object?> parametros;
  final String titulo;
  final List<String> lineas;
  final String boton;
}

class ResultadoGoogle {
  const ResultadoGoogle({
    this.confirmacion,
    this.titulo = '',
    this.lineas = const [],
  });

  final ConfirmacionGoogle? confirmacion;

  /// Texto para mostrar solo en la pantalla.
  final String titulo;
  final List<String> lineas;

  String get texto => [titulo, ...lineas].where((x) => x.isNotEmpty).join('\n');
}

abstract interface class ClienteGoogleAsistente {
  /// Lanza [ErrorAsistente] con un mensaje listo para mostrar (p. ej.
  /// `sin_cuenta_google`: "Falta conectar tu cuenta de Google.").
  Future<ResultadoGoogle> ejecutar({
    required String sesion,
    required String herramienta,
    Map<String, Object?> parametros = const {},
    bool confirmado = false,
  });
}

class ClienteGoogleSupabase implements ClienteGoogleAsistente {
  ClienteGoogleSupabase(this._cliente);

  final SupabaseClient Function() _cliente;

  @override
  Future<ResultadoGoogle> ejecutar({
    required String sesion,
    required String herramienta,
    Map<String, Object?> parametros = const {},
    bool confirmado = false,
  }) async {
    try {
      final r = await _cliente().functions.invoke(
        'gravity-asistente',
        body: {
          'accion': 'herramienta',
          'sesion': sesion,
          'herramienta': herramienta,
          'parametros': parametros,
          // Solo `true` cuando la persona pulsó el botón de la tarjeta.
          'confirmado': confirmado,
        },
      );
      return resultadoGoogleDeJson(r.data);
    } on FunctionException catch (e) {
      final d = e.details;
      if (d is Map && d['mensaje'] is String) {
        throw ErrorAsistente(
          '${d['error'] ?? 'error'}',
          d['mensaje'] as String,
        );
      }
      throw ErrorAsistente(
        'error_${e.status}',
        'GRAVITY no está disponible ahora. Inténtalo más tarde.',
      );
    } on ErrorAsistente {
      rethrow;
    } catch (_) {
      throw const ErrorAsistente(
        'sin_conexion',
        'No pude comunicarme con GRAVITY. Revisa tu conexión.',
      );
    }
  }
}

/// Interpreta la respuesta del servidor (separado para probarlo).
ResultadoGoogle resultadoGoogleDeJson(Object? datos) {
  if (datos is! Map) {
    throw const ErrorAsistente(
      'respuesta_invalida',
      'GRAVITY respondió algo que no entendí. Inténtalo otra vez.',
    );
  }
  List<String> lineas(Object? v) =>
      v is List ? [for (final x in v) '$x'] : const [];
  final c = datos['confirmacion'];
  if (datos['requiere_confirmacion'] == true && c is Map) {
    final p = c['parametros'];
    return ResultadoGoogle(
      confirmacion: ConfirmacionGoogle(
        herramienta: '${c['herramienta']}',
        parametros: p is Map
            ? {for (final e in p.entries) '${e.key}': e.value}
            : const {},
        titulo: '${c['titulo'] ?? '¿Confirmas?'}',
        lineas: lineas(c['lineas']),
        boton: '${c['boton'] ?? 'Confirmar'}',
      ),
    );
  }
  final l = datos['local'];
  if (l is Map) {
    return ResultadoGoogle(
      titulo: '${l['titulo'] ?? ''}',
      lineas: lineas(l['lineas']),
    );
  }
  throw const ErrorAsistente(
    'respuesta_invalida',
    'GRAVITY respondió algo que no entendí. Inténtalo otra vez.',
  );
}

class ClienteGoogleNoDisponible implements ClienteGoogleAsistente {
  const ClienteGoogleNoDisponible();

  @override
  Future<ResultadoGoogle> ejecutar({
    required String sesion,
    required String herramienta,
    Map<String, Object?> parametros = const {},
    bool confirmado = false,
  }) async => throw const ErrorAsistente(
    'sin_servidor',
    'Gmail y Calendar necesitan conexión con el servidor de GRAVITY.',
  );
}
