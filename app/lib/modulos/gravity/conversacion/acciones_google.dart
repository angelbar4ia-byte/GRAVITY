/// Estado de la acción de Google en curso dentro del panel de conversación:
/// formulario (redactar, crear evento) y pantalla de confirmación.
///
/// Reglas (spec de la Fase 6, sección 4; D8):
/// - Enviar un correo y crear un evento **siempre** pasan por la tarjeta de
///   confirmación; el servidor no escribe sin `confirmado: true`.
/// - Leer correo y ver el calendario se muestran en la pantalla y no vuelven
///   al asistente (D3).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cliente_asistente.dart' show ErrorAsistente;
import 'cliente_google.dart';
import 'conversacion.dart';

enum FaseGoogle { formulario, confirmacion }

class AccionGoogle {
  const AccionGoogle({
    required this.herramienta,
    required this.fase,
    this.confirmacion,
    this.error,
    this.ocupada = false,
    this.parametros = const {},
  });

  /// `gmail.redactar` o `calendario.crear` (la herramienta que se eligió).
  final String herramienta;
  final FaseGoogle fase;
  final ConfirmacionGoogle? confirmacion;
  final String? error;
  final bool ocupada;

  /// Lo capturado en el formulario (para no perderlo si hay un error).
  final Map<String, Object?> parametros;

  AccionGoogle copiar({
    FaseGoogle? fase,
    ConfirmacionGoogle? confirmacion,
    String? error,
    bool quitarError = false,
    bool? ocupada,
    Map<String, Object?>? parametros,
  }) => AccionGoogle(
    herramienta: herramienta,
    fase: fase ?? this.fase,
    confirmacion: confirmacion ?? this.confirmacion,
    error: quitarError ? null : (error ?? this.error),
    ocupada: ocupada ?? this.ocupada,
    parametros: parametros ?? this.parametros,
  );
}

/// El cliente. Por omisión usa Supabase si está inicializado. Las pruebas lo
/// cambian.
final clienteGoogleProvider = Provider<ClienteGoogleAsistente>((ref) {
  try {
    Supabase.instance.client;
    return ClienteGoogleSupabase(() => Supabase.instance.client);
  } catch (_) {
    return const ClienteGoogleNoDisponible();
  }
});

/// Fecha y hora local con su diferencia horaria (`2026-11-12T19:00:00-06:00`).
String isoConZona(DateTime local) {
  final d = local.isUtc ? local.toLocal() : local;
  final off = d.timeZoneOffset;
  final signo = off.isNegative ? '-' : '+';
  final min = off.inMinutes.abs();
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${d.year.toString().padLeft(4, '0')}-${dos(d.month)}-${dos(d.day)}'
      'T${dos(d.hour)}:${dos(d.minute)}:00$signo${dos(min ~/ 60)}:${dos(min % 60)}';
}

class AccionesGoogle extends Notifier<AccionGoogle?> {
  @override
  AccionGoogle? build() => null;

  String get _sesion => ref.read(conversacionAsistenteProvider).sesion;

  /// El asistente eligió [herramienta]. Leer y ver se resuelven al instante;
  /// redactar y crear abren el formulario.
  Future<void> iniciar(String herramienta) async {
    if (!esHerramientaGoogle(herramienta)) return;
    if (googleRequiereFormulario(herramienta)) {
      state = AccionGoogle(
        herramienta: herramienta,
        fase: FaseGoogle.formulario,
      );
      return;
    }
    final conv = ref.read(conversacionAsistenteProvider.notifier);
    try {
      final r = await ref
          .read(clienteGoogleProvider)
          .ejecutar(sesion: _sesion, herramienta: herramienta);
      conv.agregar(AutorMensaje.local, r.texto);
    } on ErrorAsistente catch (e) {
      conv.agregar(AutorMensaje.error, e.mensaje);
    }
  }

  /// La persona llenó el formulario: el servidor valida y devuelve la
  /// tarjeta de confirmación. Todavía no se envía ni se crea nada.
  Future<void> enviarFormulario(Map<String, Object?> parametros) async {
    final a = state;
    if (a == null || a.fase != FaseGoogle.formulario || a.ocupada) return;
    state = a.copiar(ocupada: true, quitarError: true, parametros: parametros);
    try {
      final r = await ref
          .read(clienteGoogleProvider)
          .ejecutar(
            sesion: _sesion,
            herramienta: a.herramienta,
            parametros: parametros,
          );
      final c = r.confirmacion;
      if (c == null) {
        state = a.copiar(
          ocupada: false,
          error: 'GRAVITY no pidió confirmación.',
          parametros: parametros,
        );
        return;
      }
      state = a.copiar(
        fase: FaseGoogle.confirmacion,
        confirmacion: c,
        ocupada: false,
        quitarError: true,
        parametros: parametros,
      );
    } on ErrorAsistente catch (e) {
      state = a.copiar(
        ocupada: false,
        error: e.mensaje,
        parametros: parametros,
      );
    }
  }

  /// La persona pulsó el botón de la tarjeta: aquí (y solo aquí) viaja
  /// `confirmado: true`.
  Future<void> confirmar() async {
    final a = state;
    final c = a?.confirmacion;
    if (a == null ||
        c == null ||
        a.fase != FaseGoogle.confirmacion ||
        a.ocupada) {
      return;
    }
    state = a.copiar(ocupada: true, quitarError: true);
    final conv = ref.read(conversacionAsistenteProvider.notifier);
    try {
      final r = await ref
          .read(clienteGoogleProvider)
          .ejecutar(
            sesion: _sesion,
            herramienta: c.herramienta,
            parametros: c.parametros,
            confirmado: true,
          );
      state = null;
      conv.agregar(AutorMensaje.local, r.texto.isEmpty ? 'Listo.' : r.texto);
    } on ErrorAsistente catch (e) {
      state = a.copiar(ocupada: false, error: e.mensaje);
    }
  }

  /// Descartar: no se envía ni se crea nada.
  void cancelar() => state = null;
}

final accionesGoogleProvider = NotifierProvider<AccionesGoogle, AccionGoogle?>(
  AccionesGoogle.new,
);
