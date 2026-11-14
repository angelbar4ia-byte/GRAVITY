/// Cliente de la conversación de GRAVITY (Fase 6, parte 1).
///
/// Habla con la función de servidor `gravity-asistente`
/// (`supabase/functions/gravity-asistente/`). La app **no** lleva ninguna
/// clave del proveedor de IA: la clave vive solo en el servidor (secreto de la
/// función). La app manda el mensaje y el identificador de la conversación;
/// el servidor decide el rol con la sesión (nunca confía en lo que diga la
/// app) y devuelve un texto y, si hace falta, el nombre de una herramienta,
/// que la app ejecuta **en el dispositivo**: su resultado nunca viaja a la IA
/// (D3).
library;

import 'package:supabase_flutter/supabase_flutter.dart';

/// Un turno ya dicho, para dar contexto a la siguiente respuesta.
class TurnoConversacion {
  const TurnoConversacion({required this.esPersona, required this.texto});

  final bool esPersona;
  final String texto;

  Map<String, String> aJson() => {
    'de': esPersona ? 'persona' : 'asistente',
    'texto': texto,
  };
}

/// Lo que responde el asistente.
class RespuestaAsistente {
  const RespuestaAsistente({required this.texto, this.herramienta});

  final String texto;

  /// Herramienta que el asistente eligió (`modulo.accion`), si alguna.
  final String? herramienta;
}

/// Un error que se le puede mostrar a la persona tal cual.
class ErrorAsistente implements Exception {
  const ErrorAsistente(this.codigo, this.mensaje);

  /// `sin_clave`, `limite_diario`, `sin_servidor`, `sin_conexion`…
  final String codigo;
  final String mensaje;

  @override
  String toString() => 'ErrorAsistente($codigo)';
}

abstract interface class ClienteAsistente {
  /// Pregunta al asistente. Lanza [ErrorAsistente] con un mensaje listo para
  /// mostrar.
  Future<RespuestaAsistente> preguntar({
    required String mensaje,
    required String sesion,
    List<TurnoConversacion> historial = const [],
  });

  /// Acción `sugerir_recetas` (Alimentación): manda el [contexto] (solo
  /// ingredientes aproximados y preferencias escritas) y devuelve la respuesta
  /// del servidor ya decodificada, sin validar. Lanza [ErrorAsistente].
  Future<Object?> sugerirRecetas(Map<String, Object?> contexto);
}

/// Con la función de servidor de Supabase.
class ClienteAsistenteSupabase implements ClienteAsistente {
  ClienteAsistenteSupabase(this._cliente);

  final SupabaseClient Function() _cliente;

  @override
  Future<Object?> sugerirRecetas(Map<String, Object?> contexto) async {
    try {
      final r = await _cliente().functions.invoke(
        'gravity-asistente',
        body: {'accion': 'sugerir_recetas', 'contexto': contexto},
      );
      return r.data;
    } on FunctionException catch (e) {
      final d = e.details;
      throw ErrorAsistente(
        d is Map ? '${d['error'] ?? 'error'}' : 'error_${e.status}',
        d is Map && d['mensaje'] is String
            ? d['mensaje'] as String
            : 'GRAVITY no está disponible ahora. Inténtalo más tarde.',
      );
    } catch (_) {
      throw const ErrorAsistente(
        'sin_conexion',
        'No pude comunicarme con GRAVITY. Revisa tu conexión.',
      );
    }
  }

  @override
  Future<RespuestaAsistente> preguntar({
    required String mensaje,
    required String sesion,
    List<TurnoConversacion> historial = const [],
  }) async {
    try {
      final r = await _cliente().functions.invoke(
        'gravity-asistente',
        body: {
          'mensaje': mensaje,
          'sesion': sesion,
          if (historial.isNotEmpty)
            'historial': [for (final t in historial) t.aJson()],
        },
      );
      final datos = r.data;
      if (datos is Map && datos['respuesta'] is String) {
        final h = datos['herramienta'];
        return RespuestaAsistente(
          texto: datos['respuesta'] as String,
          herramienta: h is String && h.isNotEmpty ? h : null,
        );
      }
      throw const ErrorAsistente(
        'respuesta_invalida',
        'GRAVITY respondió algo que no entendí. Inténtalo otra vez.',
      );
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

/// Sin servidor (modo demostración o Supabase sin preparar).
class ClienteAsistenteNoDisponible implements ClienteAsistente {
  const ClienteAsistenteNoDisponible();

  @override
  Future<Object?> sugerirRecetas(Map<String, Object?> contexto) async =>
      throw const ErrorAsistente(
        'sin_servidor',
        'La conversación necesita conexión con el servidor de GRAVITY.',
      );

  @override
  Future<RespuestaAsistente> preguntar({
    required String mensaje,
    required String sesion,
    List<TurnoConversacion> historial = const [],
  }) async => throw const ErrorAsistente(
    'sin_servidor',
    'La conversación necesita conexión con el servidor de GRAVITY.',
  );
}
