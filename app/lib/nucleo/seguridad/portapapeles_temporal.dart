/// Copiar al portapapeles un texto **sensible** (el código de una invitación)
/// sin dejarlo ahí para siempre (C1 de la revisión de la Fase 1b).
///
/// El portapapeles lo leen otras apps y los teclados con historial. El texto
/// se borra solo a los [duracion] (60 s por omisión) o, si la app estaba en
/// segundo plano y el temporizador no corrió, al volver a primer plano. Solo
/// se borra si el portapapeles **sigue teniendo ese texto**: si la persona
/// copió otra cosa mientras tanto, se respeta.
library;

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef EscribirPortapapeles = Future<void> Function(String texto);
typedef LeerPortapapeles = Future<String?> Function();

Future<void> _escribirDelSistema(String texto) =>
    Clipboard.setData(ClipboardData(text: texto));

Future<String?> _leerDelSistema() async =>
    (await Clipboard.getData(Clipboard.kTextPlain))?.text;

class PortapapelesTemporal with WidgetsBindingObserver {
  PortapapelesTemporal({
    this.duracion = const Duration(seconds: 60),
    EscribirPortapapeles? escribir,
    LeerPortapapeles? leer,
    DateTime Function()? reloj,
  }) : _escribir = escribir ?? _escribirDelSistema,
       _leer = leer ?? _leerDelSistema,
       _reloj = reloj ?? DateTime.now;

  /// Cuánto tiempo queda el texto en el portapapeles.
  final Duration duracion;

  final EscribirPortapapeles _escribir;
  final LeerPortapapeles _leer;
  final DateTime Function() _reloj;

  String? _copiado;
  DateTime? _venceEn;
  Timer? _temporizador;
  bool _observando = false;

  /// El texto que se copió y aún no se ha borrado, o `null`.
  String? get pendiente => _copiado;

  /// Copia [texto] y programa su borrado.
  Future<void> copiar(String texto) async {
    await _escribir(texto);
    _copiado = texto;
    _venceEn = _reloj().add(duracion);
    _temporizador?.cancel();
    _temporizador = Timer(duracion, limpiar);
    _observar(true);
  }

  /// Borra el texto del portapapeles ya, si sigue siendo el que se copió.
  Future<void> limpiar() async {
    final copiado = _copiado;
    _temporizador?.cancel();
    _temporizador = null;
    _copiado = null;
    _venceEn = null;
    _observar(false);
    if (copiado == null) return;
    try {
      final actual = await _leer();
      // Sin poder leerlo (Android no deja a una app en segundo plano), se
      // borra: es preferible a dejar el código ahí.
      if (actual == null || actual == copiado) await _escribir('');
    } catch (_) {
      try {
        await _escribir('');
      } catch (_) {
        // Nada más que hacer.
      }
    }
  }

  /// Al volver a primer plano: si ya pasó el tiempo, se borra.
  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    final vence = _venceEn;
    if (estado == AppLifecycleState.resumed &&
        vence != null &&
        !_reloj().isBefore(vence)) {
      unawaited(limpiar());
    }
  }

  void _observar(bool activar) {
    if (activar == _observando) return;
    try {
      final binding = WidgetsBinding.instance;
      activar ? binding.addObserver(this) : binding.removeObserver(this);
      _observando = activar;
    } catch (_) {
      // Sin binding (pruebas de Dart puro): solo corre el temporizador.
    }
  }

  void dispose() {
    _temporizador?.cancel();
    _observar(false);
  }
}

/// El portapapeles temporal de la app.
final portapapelesTemporalProvider = Provider<PortapapelesTemporal>((ref) {
  final portapapeles = PortapapelesTemporal();
  ref.onDispose(portapapeles.dispose);
  return portapapeles;
});
