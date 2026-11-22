/// El motor de voz de GRAVITY (spec, sección 3): un solo componente de voz de
/// salida con fuentes intercambiables, detrás de la interfaz [MotorVoz].
///
/// Hoy hay una sola fuente real, la **A** (voz del dispositivo). La **B**
/// (modelo descargable) y la **C** (audio pregrabado) llegan en P3.2a-2 y
/// P3.2a-3; el motor ya las conoce en la cadena y dice, honestamente, que no
/// están instaladas.
///
/// Reglas (spec, sección 2):
/// - R1: al motor solo llega texto ya filtrado. No filtra ni corrige: quien
///   llama filtra.
/// - R2 y R3: solo produce sonido; no recibe identidad ni ejecuta nada, y no
///   tiene ninguna ruta hacia el registro de herramientas.
/// - R6: ningún error ni mensaje de registro lleva el texto hablado.
/// - R8: reproducir no usa la red; una voz que la necesita no se usa nunca.
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;

import '../conversacion/voz.dart' show VozSalida;
import 'asignador.dart';
import 'fuente_de_voz.dart';
import 'preferencias.dart';
import 'tipos.dart';

abstract interface class MotorVoz implements VozSalida {
  /// Cambia cuando cambian voces, modelos o paquetes (la pantalla se
  /// refresca).
  Stream<void> get cambios;

  /// ¿Puede hablar este uso con esta variante? Dice la cadena y por qué no
  /// sirve cada fuente descartada. No habla.
  Future<Disponibilidad> disponibilidad(
    UsoVoz uso, {
    Variante? variante,
    int vocesNecesarias = 1,
  });

  /// Voces locales de una fuente (nunca las que necesitan red).
  Future<List<VozMotor>> voces(Fuente fuente, {Variante? variante});

  /// Qué voz del motor suena como cada voz de guion (lo elegido por la
  /// persona y, donde falta, la propuesta automática). `null` si la fuente no
  /// está en este equipo.
  Future<Asignacion?> asignacion(
    Fuente fuente,
    Variante variante, {
    Set<VozDeGuion>? roles,
  });

  /// Todas las voces que reporta el sistema, también las que no se ofrecen
  /// (para Ajustes › Voz › Detalles técnicos). Vacío si la fuente no sabe
  /// listarlas.
  Future<List<VozDelSistema>> diagnostico(Fuente fuente);

  /// Vuelve a preguntar al sistema qué voces hay.
  Future<void> refrescar();

  /// Reproduce un guion por turnos, cada uno con la voz asignada a su
  /// [VozDeGuion]. [soloFuente] quita el respaldo (pruebas con valor,
  /// "Probar").
  ///
  /// [vocesElegidas] fija exactamente qué voz del motor suena como cada voz de
  /// guion (`VozDeGuion` -> `VozMotor.id`), sin guardarlo en las preferencias:
  /// es para "Probar" una voz concreta. Si alguna no existe en la fuente, la
  /// fuente se descarta con `vocesInsuficientes`.
  Future<Reproduccion> reproducir(
    Guion guion, {
    UsoVoz uso = UsoVoz.curso,
    double velocidad = 1.0,
    Fuente? soloFuente,
    Map<VozDeGuion, String>? vocesElegidas,
  });

  /// Una frase suelta: repetir, tarjetas, probar una voz.
  Future<Reproduccion> decir(
    String texto, {
    required UsoVoz uso,
    Variante variante = Variante.enUS,
    VozDeGuion voz = VozDeGuion.f1,
    double velocidad = 1.0,
    Fuente? soloFuente,
  });

  Future<void> pausarTodo();
  Future<void> reanudarTodo();

  // Heredados de VozSalida:
  //   hablar(texto) == decir(texto, uso: asistente, variante: esMX)
  //   detener()     == para lo que suene y vacía la cola
}

/// Cadena de fuentes por omisión de cada uso (spec 5.3). Son propuestas: el
/// dueño las cambia de oído después de la prueba en el teléfono (P3.3).
List<Fuente> cadenaPorOmision(UsoVoz uso) => switch (uso) {
  UsoVoz.curso => const [Fuente.pregrabado, Fuente.modelo, Fuente.dispositivo],
  // El texto del asistente es nuevo: no hay audio pregrabado.
  UsoVoz.asistente => const [Fuente.dispositivo, Fuente.modelo],
};

/// La cadena que se intenta: la fuente preferida pasa al frente y las demás
/// siguen en el mismo orden; con "solo esta fuente" queda solo esa.
List<Fuente> cadenaDe(
  UsoVoz uso,
  PreferenciasDeUso preferencias, {
  Fuente? soloFuente,
}) {
  final base = cadenaPorOmision(uso);
  if (soloFuente != null) return [soloFuente];
  final elegida = preferencias.fuente;
  if (elegida == null || !base.contains(elegida)) return base;
  if (preferencias.soloEstaFuente) return [elegida];
  return [elegida, ...base.where((f) => f != elegida)];
}

/// Lo que se reproduce ahora y para qué uso.
class _EnCurso {
  _EnCurso(this.uso, this.reproduccion);
  final UsoVoz uso;
  final Reproduccion reproduccion;
}

class MotorDeVoz implements MotorVoz {
  MotorDeVoz({
    required List<FuenteDeVoz> fuentes,
    required this._preferencias,
    this._asignador = const AsignadorPorGenero(),
  }) : _fuentes = {for (final f in fuentes) f.tipo: f};

  final Map<Fuente, FuenteDeVoz> _fuentes;
  final PreferenciasVoz Function() _preferencias;
  final Asignador _asignador;
  final _cambios = StreamController<void>.broadcast();

  _EnCurso? _enCurso;

  /// Cada `detener` cambia la época: lo que esperaba en la cola ya no habla.
  int _epoca = 0;
  Future<void> _cola = Future<void>.value();

  @override
  Stream<void> get cambios => _cambios.stream;

  /// Libera el motor (cierra el flujo de cambios y corta lo que suene).
  Future<void> cerrar() async {
    await detener();
    await _cambios.close();
  }

  /// Por qué una fuente que no está en este equipo no sirve.
  Motivo _motivoDeAusente(Fuente fuente) => switch (fuente) {
    Fuente.dispositivo => Motivo.plataformaNoSoportada,
    Fuente.modelo => Motivo.modeloNoInstalado,
    Fuente.pregrabado => Motivo.sinPaqueteDeAudio,
  };

  /// Por qué una fuente presente no tiene ninguna voz local de la variante.
  Motivo _motivoSinVoces(FuenteDeVoz fuente, Variante variante) =>
      switch (fuente) {
        final FuenteConMotivoSinVoces f => f.motivoSinVoces(variante),
        _ => Motivo.sinVozEnElIdioma,
      };

  Variante _varianteDe(UsoVoz uso, Variante? variante) =>
      variante ?? (uso == UsoVoz.asistente ? Variante.esMX : Variante.enUS);

  /// Voces locales de la fuente; vacío si no puede listarlas.
  Future<List<VozMotor>> _locales(FuenteDeVoz fuente, Variante variante) async {
    final voces = await fuente.voces(variante);
    return [
      for (final v in voces)
        if (v.local) v,
    ];
  }

  @override
  Future<Disponibilidad> disponibilidad(
    UsoVoz uso, {
    Variante? variante,
    int vocesNecesarias = 1,
  }) async {
    final v = _varianteDe(uso, variante);
    final cadena = cadenaDe(uso, _preferencias().de(uso));
    final sirven = <Fuente>[];
    final descartadas = <Fuente, Motivo>{};
    for (final tipo in cadena) {
      final fuente = _fuentes[tipo];
      if (fuente == null) {
        descartadas[tipo] = _motivoDeAusente(tipo);
        continue;
      }
      try {
        final voces = await _locales(fuente, v);
        if (voces.isEmpty) {
          descartadas[tipo] = _motivoSinVoces(fuente, v);
        } else if (voces.length < vocesNecesarias) {
          descartadas[tipo] = Motivo.vocesInsuficientes;
        } else {
          sirven.add(tipo);
        }
      } on ErrorVoz {
        descartadas[tipo] = Motivo.sinMotorDeVoz;
      }
    }
    return Disponibilidad(cadena: sirven, descartadas: descartadas);
  }

  @override
  Future<List<VozMotor>> voces(Fuente fuente, {Variante? variante}) async {
    final f = _fuentes[fuente];
    if (f == null) return const [];
    try {
      if (variante != null) return await _locales(f, variante);
      return [
        for (final v in Variante.values) ...await _locales(f, v),
      ];
    } on ErrorVoz {
      return const [];
    }
  }

  @override
  Future<Asignacion?> asignacion(
    Fuente fuente,
    Variante variante, {
    Set<VozDeGuion>? roles,
  }) async {
    final f = _fuentes[fuente];
    if (f == null) return null;
    final List<VozMotor> voces;
    try {
      voces = await _locales(f, variante);
    } on ErrorVoz {
      return null;
    }
    return resolverAsignacion(
      asignador: _asignador,
      fuente: fuente,
      variante: variante,
      voces: voces,
      roles: roles ?? VozDeGuion.values.toSet(),
      guardadas: _preferencias().asignacionDe(fuente, variante),
    );
  }

  @override
  Future<List<VozDelSistema>> diagnostico(Fuente fuente) async {
    if (_fuentes[fuente] case final FuenteConDiagnostico d) {
      try {
        return await d.diagnostico();
      } on ErrorVoz {
        return const [];
      }
    }
    return const [];
  }

  @override
  Future<void> refrescar() async {
    for (final f in _fuentes.values) {
      if (f case final FuenteConDiagnostico d) await d.refrescar();
    }
    if (!_cambios.isClosed) _cambios.add(null);
  }

  @override
  Future<Reproduccion> reproducir(
    Guion guion, {
    UsoVoz uso = UsoVoz.curso,
    double velocidad = 1.0,
    Fuente? soloFuente,
    Map<VozDeGuion, String>? vocesElegidas,
  }) async {
    // Una sola voz a la vez (3.4, punto 1).
    final actual = _enCurso;
    if (actual != null) {
      if (uso == UsoVoz.asistente && actual.uso == UsoVoz.curso) {
        throw const OcupadoPorOtroUso();
      }
      // Una acción explícita de la persona reemplaza lo que suena.
      await actual.reproduccion.parar();
    }
    final preferencias = _preferencias();
    final cadena = cadenaDe(uso, preferencias.de(uso), soloFuente: soloFuente);
    final motivos = <Fuente, Motivo>{};
    for (final tipo in cadena) {
      final fuente = _fuentes[tipo];
      if (fuente == null) {
        motivos[tipo] = _motivoDeAusente(tipo);
        continue;
      }
      try {
        final voces = await _locales(fuente, guion.variante);
        if (voces.isEmpty) {
          motivos[tipo] = _motivoSinVoces(fuente, guion.variante);
          continue;
        }
        final asignacion = vocesElegidas != null
            ? Asignacion(tipo, guion.variante, vocesElegidas)
            : resolverAsignacion(
                asignador: _asignador,
                fuente: tipo,
                variante: guion.variante,
                voces: voces,
                roles: guion.vocesUsadas,
                guardadas: preferencias.asignacionDe(tipo, guion.variante),
              );
        final motivo = await fuente.motivoNoDisponible(guion, asignacion);
        if (motivo != null) {
          motivos[tipo] = motivo;
          continue;
        }
        final repro = await fuente.reproducir(
          guion,
          asignacion,
          fuente.capacidades.ajustarVelocidad(velocidad),
        );
        final nuevo = _EnCurso(uso, repro);
        _enCurso = nuevo;
        unawaited(
          repro.terminada.then<void>(
            (_) {},
            onError: (Object _) {},
          ).whenComplete(() {
            if (identical(_enCurso, nuevo)) _enCurso = null;
          }),
        );
        return repro;
      } on FalloDeSintesis {
        motivos[tipo] = Motivo.sinMotorDeVoz;
      }
    }
    throw SinFuenteDisponible(motivos);
  }

  @override
  Future<Reproduccion> decir(
    String texto, {
    required UsoVoz uso,
    Variante variante = Variante.enUS,
    VozDeGuion voz = VozDeGuion.f1,
    double velocidad = 1.0,
    Fuente? soloFuente,
  }) => reproducir(
    Guion(
      id: 'frase',
      variante: variante,
      turnos: [Turno(voz: voz, texto: texto)],
    ),
    uso: uso,
    velocidad: velocidad,
    soloFuente: soloFuente,
  );

  @override
  Future<void> hablar(String texto) {
    if (texto.trim().isEmpty) return Future<void>.value();
    final epoca = _epoca;
    // Dos respuestas seguidas del asistente se encolan en orden.
    final turno = _cola.then((_) => _hablarUno(texto, epoca));
    _cola = turno.catchError((Object _) {});
    return turno;
  }

  Future<void> _hablarUno(String texto, int epoca) async {
    if (epoca != _epoca) return;
    try {
      final velocidad = _preferencias().asistente.velocidad;
      final repro = await decir(
        texto,
        uso: UsoVoz.asistente,
        variante: Variante.esMX,
        velocidad: velocidad,
      );
      if (epoca != _epoca) {
        await repro.parar();
        return;
      }
      await repro.terminada;
    } on ErrorVoz catch (e) {
      // La respuesta sigue en pantalla: si no se puede leer, no pasa nada.
      // Solo se registra el tipo, nunca el texto (R6).
      debugPrint('Voz: no se leyó la respuesta (${e.runtimeType})');
    } catch (e) {
      debugPrint('Voz: no se leyó la respuesta (${e.runtimeType})');
    }
  }

  @override
  Future<void> detener() async {
    _epoca++;
    final actual = _enCurso;
    _enCurso = null;
    if (actual != null) await actual.reproduccion.parar();
  }

  @override
  Future<void> pausarTodo() async => await _enCurso?.reproduccion.pausar();

  @override
  Future<void> reanudarTodo() async => await _enCurso?.reproduccion.reanudar();
}
