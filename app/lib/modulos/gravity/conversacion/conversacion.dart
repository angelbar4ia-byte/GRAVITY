/// Estado de la conversación de GRAVITY en la pantalla principal.
///
/// Las respuestas del asistente se muestran en la misma pantalla. Lo que una
/// herramienta devuelve (p. ej. el resumen de la semana) se muestra también
/// aquí, pero **solo en el dispositivo**: nunca se manda al asistente ni se
/// agrega al historial que viaja al servidor (D3).
library;

import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cliente_asistente.dart';

/// Quién dijo un mensaje.
enum AutorMensaje { persona, asistente, local, error }

class MensajeConversacion {
  const MensajeConversacion(this.autor, this.texto);

  final AutorMensaje autor;
  final String texto;
}

class EstadoConversacion {
  const EstadoConversacion({
    this.mensajes = const [],
    this.pensando = false,
    required this.sesion,
  });

  final List<MensajeConversacion> mensajes;
  final bool pensando;

  /// Identificador de esta conversación (UUID v4), para la bitácora.
  final String sesion;

  EstadoConversacion copiar({
    List<MensajeConversacion>? mensajes,
    bool? pensando,
  }) => EstadoConversacion(
    mensajes: mensajes ?? this.mensajes,
    pensando: pensando ?? this.pensando,
    sesion: sesion,
  );
}

/// UUID v4 sin dependencias.
String nuevoUuid([math.Random? azar]) {
  final r = azar ?? math.Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  String h(int i) => b[i].toRadixString(16).padLeft(2, '0');
  return '${h(0)}${h(1)}${h(2)}${h(3)}-${h(4)}${h(5)}-${h(6)}${h(7)}-'
      '${h(8)}${h(9)}-${h(10)}${h(11)}${h(12)}${h(13)}${h(14)}${h(15)}';
}

/// El cliente de la conversación. Por omisión usa Supabase si está
/// inicializado; si no, avisa que falta el servidor. Las pruebas lo cambian.
final clienteAsistenteProvider = Provider<ClienteAsistente>((ref) {
  try {
    // Lanza si Supabase no se inicializó (modo demostración).
    Supabase.instance.client;
    return ClienteAsistenteSupabase(() => Supabase.instance.client);
  } catch (_) {
    return const ClienteAsistenteNoDisponible();
  }
});

/// Ejecuta una herramienta en el dispositivo y devuelve el texto que se
/// muestra (o `null` si solo abrió una pantalla).
typedef EjecutorLocal = Future<String?> Function(String herramienta);

class ConversacionAsistente extends Notifier<EstadoConversacion> {
  @override
  EstadoConversacion build() => EstadoConversacion(sesion: nuevoUuid());

  /// Máximo de turnos que se mandan como contexto.
  static const turnosDeContexto = 6;

  Future<void> enviar(String texto, {EjecutorLocal? ejecutar}) async {
    final mensaje = texto.trim();
    if (mensaje.isEmpty || state.pensando) return;
    // Contexto: solo lo dicho por la persona y por el asistente; nunca los
    // mensajes locales (pueden traer cifras de las herramientas).
    final historial = [
      for (final m in state.mensajes)
        if (m.autor == AutorMensaje.persona || m.autor == AutorMensaje.asistente)
          TurnoConversacion(
            esPersona: m.autor == AutorMensaje.persona,
            texto: m.texto,
          ),
    ];
    final recientes = historial.length > turnosDeContexto
        ? historial.sublist(historial.length - turnosDeContexto)
        : historial;
    state = state.copiar(
      mensajes: [
        ...state.mensajes,
        MensajeConversacion(AutorMensaje.persona, mensaje),
      ],
      pensando: true,
    );
    try {
      final r = await ref
          .read(clienteAsistenteProvider)
          .preguntar(
            mensaje: mensaje,
            sesion: state.sesion,
            historial: recientes,
          );
      var mensajes = [
        ...state.mensajes,
        MensajeConversacion(AutorMensaje.asistente, r.texto),
      ];
      final herramienta = r.herramienta;
      if (herramienta != null && ejecutar != null) {
        try {
          final local = await ejecutar(herramienta);
          if (local != null && local.isNotEmpty) {
            mensajes = [...mensajes, MensajeConversacion(AutorMensaje.local, local)];
          }
        } catch (_) {
          mensajes = [
            ...mensajes,
            const MensajeConversacion(
              AutorMensaje.error,
              'No pude hacer eso en este dispositivo.',
            ),
          ];
        }
      }
      state = state.copiar(mensajes: mensajes, pensando: false);
    } on ErrorAsistente catch (e) {
      state = state.copiar(
        mensajes: [
          ...state.mensajes,
          MensajeConversacion(AutorMensaje.error, e.mensaje),
        ],
        pensando: false,
      );
    }
  }

  void limpiar() => state = EstadoConversacion(sesion: nuevoUuid());
}

final conversacionAsistenteProvider =
    NotifierProvider<ConversacionAsistente, EstadoConversacion>(
      ConversacionAsistente.new,
    );
