/// Fuente A del motor de voz: la voz del dispositivo (spec, sección 4.1).
///
/// Android usa el motor de texto a voz que tenga instalado el teléfono y
/// Windows las voces del sistema, las dos por `flutter_tts` (ver
/// `puerto_tts.dart`). La app no descarga ni instala voces aquí: solo usa las
/// que ya tiene el equipo y las que no necesitan red.
///
/// Reglas (R8): **una voz que necesita red nunca se ofrece ni se usa**
/// (`network_required == "1"` en Android), y una voz cuyos datos no están
/// instalados tampoco. En Windows el plugin no dice si una voz usa red; las
/// voces del sistema son locales.
library;

import 'dart:async';

import '../../asignador.dart';
import '../../fuente_de_voz.dart';
import '../../reproduccion_por_turnos.dart';
import '../../tipos.dart';
import 'puerto_tts.dart';

class FuenteDispositivo implements FuenteDeVoz, FuenteConDiagnostico {
  FuenteDispositivo(this._puerto);

  final PuertoTts _puerto;

  @override
  Fuente get tipo => Fuente.dispositivo;

  /// La velocidad se pide como factor (1.0 normal) y se traduce a la escala del
  /// plugin. El rango de 0.5 a 1.5 funciona igual en Android y en Windows. El
  /// tono existe en el plugin (`setPitch`) pero esta versión no lo usa.
  @override
  Capacidades get capacidades => const Capacidades(
    tono: true,
    progresoPorPalabra: false,
    pausa: true,
    velocidadMin: 0.5,
    velocidadMax: 1.5,
  );

  Future<List<VozDelSistema>>? _cache;
  String? _vozFijada;

  Future<List<VozDelSistema>> _sistema() {
    final f = _cache ??= _puerto.voces();
    unawaited(
      f.then<void>(
        (_) {},
        onError: (Object _) {
          // Un fallo no se guarda: la próxima vez se vuelve a preguntar.
          if (identical(_cache, f)) _cache = null;
        },
      ),
    );
    return f;
  }

  @override
  Future<void> refrescar() async {
    _cache = null;
    _vozFijada = null;
    try {
      await _sistema();
    } on ErrorVoz {
      // `voces` y `diagnostico` lo vuelven a decir cuando alguien pregunte.
    }
  }

  @override
  Future<List<VozDelSistema>> diagnostico() => _sistema();

  /// Variante a la que pertenece una voz, o `null` si no se ofrece (por
  /// ejemplo, inglés de Australia). El español se agrupa entero en `esMX`.
  static Variante? varianteDe(String locale) {
    final partes = locale.toLowerCase().replaceAll('_', '-').split('-');
    final idioma = partes.first;
    final region = partes.length > 1 ? partes[1] : '';
    if (idioma == 'es') return Variante.esMX;
    if (idioma == 'en') {
      if (region == 'us') return Variante.enUS;
      if (region == 'gb') return Variante.enGB;
    }
    return null;
  }

  static String idDe(VozDelSistema v) => '${v.locale}|${v.nombre}';

  static int _rangoCalidad(String? calidad) => switch (calidad?.toLowerCase()) {
    'very high' => 5,
    'high' => 4,
    'normal' => 3,
    'low' => 2,
    'very low' => 1,
    _ => 0,
  };

  // Qué tan cerca está un español del de México (para ordenar).
  static int _cercaniaConMexico(String locale) {
    final l = locale.toLowerCase().replaceAll('_', '-');
    if (l == 'es-mx') return 0;
    if (l == 'es-us') return 1;
    if (l == 'es-419') return 2;
    return 3;
  }

  @override
  Future<List<VozMotor>> voces(Variante variante) async {
    final todas = await _sistema();
    final voces = <VozMotor>[];
    for (final v in todas) {
      if (varianteDe(v.locale) != variante) continue;
      if (v.requiereRed == true || !v.instalada) continue;
      voces.add(
        VozMotor(
          id: idDe(v),
          fuente: Fuente.dispositivo,
          nombre: v.nombre,
          variante: variante,
          genero: v.genero,
          local: true,
          locale: v.locale,
          calidad: _rangoCalidad(v.calidad),
        ),
      );
    }
    voces.sort((a, b) {
      if (variante == Variante.esMX) {
        final c = _cercaniaConMexico(a.locale).compareTo(
          _cercaniaConMexico(b.locale),
        );
        if (c != 0) return c;
      }
      final q = b.calidad.compareTo(a.calidad);
      if (q != 0) return q;
      return a.nombre.compareTo(b.nombre);
    });
    return voces;
  }

  @override
  Future<Motivo?> motivoNoDisponible(Guion guion, Asignacion asignacion) async {
    final List<VozMotor> disponibles;
    try {
      disponibles = await voces(guion.variante);
    } on ErrorVoz {
      return Motivo.sinMotorDeVoz;
    }
    if (disponibles.isEmpty) return Motivo.sinVozEnElIdioma;
    final ids = {for (final v in disponibles) v.id};
    for (final rol in guion.vocesUsadas) {
      final id = asignacion.idVozMotor[rol];
      if (id == null || !ids.contains(id)) return Motivo.vocesInsuficientes;
    }
    // Nunca la misma voz para dos voces de guion (criterio 4).
    final usadas = [
      for (final rol in guion.vocesUsadas) asignacion.idVozMotor[rol],
    ];
    if (usadas.toSet().length != usadas.length) return Motivo.vocesInsuficientes;
    return null;
  }

  @override
  Future<Reproduccion> reproducir(
    Guion guion,
    Asignacion asignacion,
    double velocidad,
  ) async {
    final sistema = await _sistema();
    final porId = {for (final v in sistema) idDe(v): v};
    final rango = await _puerto.rangoVelocidad();
    final factor = capacidades.ajustarVelocidad(velocidad);
    final rate = (rango.normal * factor).clamp(rango.min, rango.max).toDouble();
    await _puerto.fijarVelocidad(rate);
    return ReproduccionPorTurnos(
      fuente: Fuente.dispositivo,
      guion: guion,
      decirTurno: (indice, turno) async {
        final id = asignacion.idVozMotor[turno.voz];
        final voz = id == null ? null : porId[id];
        if (id == null || voz == null) {
          throw const FalloDeSintesis(Fuente.dispositivo, 'voz_no_encontrada');
        }
        if (_vozFijada != id) {
          final ok = await _puerto.fijarVoz(voz.nombre, voz.locale);
          if (!ok) {
            throw const FalloDeSintesis(
              Fuente.dispositivo,
              'voz_no_encontrada',
            );
          }
          _vozFijada = id;
        }
        final r = await _puerto.hablar(turno.texto);
        return r == ResultadoHabla.completo
            ? ResultadoTurno.completo
            : ResultadoTurno.interrumpido;
      },
      detenerTurno: _puerto.detener,
    );
  }
}
