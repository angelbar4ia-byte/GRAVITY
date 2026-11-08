/// Voz de la conversación con GRAVITY (Fase 6b): escuchar y hablar.
///
/// Reglas:
/// - La voz no identifica a la persona (D5): quien habla es quien tiene la
///   sesión abierta. No hay huella de voz ni se decide nada por la voz.
/// - La voz no autoriza acciones (D8): lo que se reconoce entra como un
///   mensaje de texto normal y pasa por el mismo filtro de D3 del servidor.
///   Las acciones que piden confirmación siguen pidiendo el botón.
/// - Solo se lee en voz alta la respuesta del asistente (texto ya filtrado),
///   nunca los mensajes locales de la pantalla (pueden traer cifras, D3/D6),
///   y solo si la persona lo activó.
///
/// Las implementaciones reales (plugins de voz de Flutter) se conectan detrás
/// de estas interfaces en una fase posterior; hoy no hay ninguna activa.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Reconocimiento de voz: convierte lo dicho en texto.
abstract class VozEntrada {
  /// Si el dispositivo puede escuchar. Sin ello no se muestra el micrófono.
  Future<bool> disponible();

  /// Escucha una frase y devuelve el texto reconocido, o `null` si no se
  /// entendió nada o se canceló.
  Future<String?> escuchar();

  /// Deja de escuchar.
  Future<void> detener();
}

/// Síntesis de voz: lee un texto en voz alta.
abstract class VozSalida {
  Future<void> hablar(String texto);
  Future<void> detener();
}

/// Sin reconocimiento de voz (valor por omisión mientras no haya plugin).
class VozEntradaNoDisponible implements VozEntrada {
  const VozEntradaNoDisponible();

  @override
  Future<bool> disponible() async => false;

  @override
  Future<String?> escuchar() async => null;

  @override
  Future<void> detener() async {}
}

/// Sin síntesis de voz (valor por omisión mientras no haya plugin).
class VozSalidaNoDisponible implements VozSalida {
  const VozSalidaNoDisponible();

  @override
  Future<void> hablar(String texto) async {}

  @override
  Future<void> detener() async {}
}

/// Voz de entrada falsa para pruebas: devuelve el texto que se le indique.
/// No toca ningún micrófono.
class VozEntradaFalsa implements VozEntrada {
  VozEntradaFalsa([this.texto, this.estaDisponible = true]);

  String? texto;
  bool estaDisponible;
  int escuchas = 0;

  @override
  Future<bool> disponible() async => estaDisponible;

  @override
  Future<String?> escuchar() async {
    escuchas++;
    return texto;
  }

  @override
  Future<void> detener() async {}
}

/// Voz de salida falsa para pruebas: guarda lo que se le pidió decir.
class VozSalidaFalsa implements VozSalida {
  final dichas = <String>[];

  @override
  Future<void> hablar(String texto) async => dichas.add(texto);

  @override
  Future<void> detener() async {}
}

final vozEntradaProvider = Provider<VozEntrada>(
  (ref) => const VozEntradaNoDisponible(),
);

final vozSalidaProvider = Provider<VozSalida>(
  (ref) => const VozSalidaNoDisponible(),
);

/// Si la persona activó leer las respuestas en voz alta. Apagado por omisión
/// y por sesión de la app: no se guarda.
class LeerEnVozAlta extends Notifier<bool> {
  @override
  bool build() => false;

  void fijar(bool activo) => state = activo;
}

final leerEnVozAltaProvider = NotifierProvider<LeerEnVozAlta, bool>(
  LeerEnVozAlta.new,
);
