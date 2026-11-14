/// Puente de casa (D9): lo que GRAVITY necesita de Home Assistant.
///
/// Reglas: sin puertos abiertos en el router; el token de Home Assistant vive
/// en el servidor / el equipo del puente (variable de entorno o gestor de
/// secretos), nunca en la app ni en el repositorio; el puente corre con la
/// cuenta de rol Casa (D5).
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'mensaje_bocina.dart';

abstract interface class PuenteCasa {
  /// Envía un mensaje **ya validado** a una bocina (entidad `media_player`).
  /// Solo acepta [MensajeBocina]: no hay forma de enviar texto sin filtrar.
  Future<void> hablar({required String bocina, required MensajeBocina mensaje});
}

/// Implementación para pruebas: guarda lo recibido, no toca la red.
final class PuenteCasaFalso implements PuenteCasa {
  final List<({String bocina, String texto})> enviados = [];

  @override
  Future<void> hablar({
    required String bocina,
    required MensajeBocina mensaje,
  }) async {
    enviados.add((bocina: bocina, texto: mensaje.texto));
  }
}

/// Entrega la cabecera de autorización. La implementación real lee el token
/// del entorno del servidor; la app nunca lo conoce.
abstract interface class AutorizacionHomeAssistant {
  Future<Map<String, String>> cabeceras();
}

class PuenteHomeAssistantError implements Exception {
  PuenteHomeAssistantError(this.mensaje);
  final String mensaje;
  @override
  String toString() => 'PuenteHomeAssistantError: $mensaje';
}

/// Adaptador a la API local de Home Assistant (`POST /api/services/tts/speak`).
/// Solo acepta direcciones de la red de casa; no expone nada hacia fuera.
final class PuenteHomeAssistant implements PuenteCasa {
  PuenteHomeAssistant({
    required Uri urlBase,
    required AutorizacionHomeAssistant autorizacion,
    http.Client? cliente,
    this.entidadTts = 'tts.home_assistant_cloud',
  }) : _base = urlBase,
       _auth = autorizacion,
       _cliente = cliente ?? http.Client() {
    if (!esHostLocal(urlBase.host)) {
      throw ArgumentError('El puente solo habla con la red local (D9).');
    }
  }

  final Uri _base;
  final AutorizacionHomeAssistant _auth;
  final http.Client _cliente;
  final String entidadTts;

  static bool esHostLocal(String host) {
    final h = host.toLowerCase();
    if (h == 'localhost' || h.endsWith('.local') || h == 'homeassistant') {
      return true;
    }
    final p = h.split('.').map(int.tryParse).toList();
    if (p.length != 4 || p.any((x) => x == null || x < 0 || x > 255)) {
      return false;
    }
    final a = p[0]!, b = p[1]!;
    return a == 10 ||
        a == 127 ||
        (a == 192 && b == 168) ||
        (a == 172 && b >= 16 && b <= 31);
  }

  @override
  Future<void> hablar({
    required String bocina,
    required MensajeBocina mensaje,
  }) async {
    if (!RegExp(r'^media_player\.[a-z0-9_]+$').hasMatch(bocina)) {
      throw ArgumentError('Entidad de bocina no válida.');
    }
    final r = await _cliente.post(
      _base.resolve('/api/services/tts/speak'),
      headers: {...await _auth.cabeceras(), 'Content-Type': 'application/json'},
      body: jsonEncode({
        'entity_id': entidadTts,
        'media_player_entity_id': bocina,
        'message': mensaje.texto,
        'language': 'es-MX',
      }),
    );
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw PuenteHomeAssistantError(
        'Home Assistant respondió ${r.statusCode}.',
      );
    }
  }
}
