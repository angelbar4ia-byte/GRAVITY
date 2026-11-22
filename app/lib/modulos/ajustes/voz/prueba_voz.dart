/// "Probar" de Ajustes › Voz: reproduce una frase de prueba con una fuente (por
/// omisión, la voz del dispositivo; también una voz descargada) y dice, sin
/// adornos, qué voz sonó o por qué no sonó.
///
/// Las frases de prueba son fijas y no llevan datos de nadie (R1). La prueba
/// pide la fuente con `soloFuente` para que suene lo que la pantalla muestra,
/// no un respaldo.
library;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../gravity/voz/asignador.dart';
import '../../gravity/voz/motor.dart';
import '../../gravity/voz/proveedores.dart';
import '../../gravity/voz/tipos.dart';

/// Frase con la que se prueba la voz del asistente (español).
const fraseDePruebaEnEspanol = 'Hola, soy GRAVITY. Así suena mi voz.';

/// Frase con la que se prueba una voz del curso (inglés).
const fraseDePruebaEnIngles = 'Hello, this is a test. This is how my voice sounds.';

/// Diálogo corto de dos voces para comparar F1 con M1 (inglés). Son líneas
/// propias de la prueba, no contenido del curso.
const List<Turno> dialogoDePrueba = [
  Turno(voz: VozDeGuion.f1, texto: 'Good morning. Are you ready for the trip?'),
  Turno(voz: VozDeGuion.m1, texto: 'Yes, I am. My bag is by the door.'),
  Turno(voz: VozDeGuion.f1, texto: 'Great. The bus leaves at half past eight.'),
  Turno(voz: VozDeGuion.m1, texto: 'Then we have ten minutes. Do you want some tea?'),
  Turno(voz: VozDeGuion.f1, texto: 'No, thank you. Let us wait outside.'),
  Turno(voz: VozDeGuion.m1, texto: 'All right. I will bring the tickets.'),
];

/// Por qué no sirve una fuente, en palabras de la pantalla.
String describirMotivo(Motivo motivo) => switch (motivo) {
  Motivo.plataformaNoSoportada => 'no está en este equipo',
  Motivo.sinMotorDeVoz => 'el equipo no tiene un motor de voz que responda',
  Motivo.sinVozEnElIdioma =>
    'no hay una voz en este idioma que funcione sin conexión',
  Motivo.vocesInsuficientes => 'no hay voces distintas suficientes',
  Motivo.modeloNoInstalado => 'no está descargada',
  Motivo.sinPaqueteDeAudio => 'no hay audio descargado',
  Motivo.audioCaducado => 'el audio ya no coincide con el texto',
  Motivo.formatoNoSoportado => 'este equipo no reproduce ese formato',
  Motivo.excluidaPorLaPersona => 'la dejaste fuera',
};

@immutable
class EstadoPrueba {
  const EstadoPrueba({
    this.clave,
    this.sonando = false,
    this.mensaje,
    this.hayOtraVoz = false,
  });

  /// Clave de la fila a la que se refiere el estado (la que se probó).
  final String? clave;

  /// La prueba de [clave] está sonando.
  final bool sonando;

  /// Lo que se le dice a la persona: qué voz sonó o por qué no.
  final String? mensaje;

  /// Hay otra voz sonando (la de otro uso): se ofrece Parar.
  final bool hayOtraVoz;
}

final pruebaVozProvider = NotifierProvider.autoDispose<PruebaVoz, EstadoPrueba>(
  PruebaVoz.new,
);

class PruebaVoz extends Notifier<EstadoPrueba> {
  Reproduccion? _actual;

  @override
  EstadoPrueba build() {
    // Al salir de la pantalla se calla solo lo que sonaba por esta prueba, no
    // la lectura de una respuesta de GRAVITY.
    ref.onDispose(() {
      final r = _actual;
      _actual = null;
      if (r != null) r.parar();
    });
    return const EstadoPrueba();
  }

  /// Reproduce [guion] con [fuente] (por omisión, la voz del dispositivo).
  /// [clave] identifica la fila que suena. [vocesElegidas] fija qué voz del
  /// motor suena como cada voz de guion (probar una voz concreta).
  Future<void> probar({
    required String clave,
    required Guion guion,
    required UsoVoz uso,
    double velocidad = 1.0,
    Fuente fuente = Fuente.dispositivo,
    Map<VozDeGuion, String>? vocesElegidas,
  }) async {
    final MotorVoz motor = ref.read(motorVozProvider);
    state = EstadoPrueba(clave: clave, sonando: true);
    try {
      final repro = await motor.reproducir(
        guion,
        uso: uso,
        velocidad: velocidad,
        soloFuente: fuente,
        vocesElegidas: vocesElegidas,
      );
      if (!ref.mounted) {
        await repro.parar();
        return;
      }
      _actual = repro;
      final quien = await _quienSono(
        motor,
        guion,
        repro.fuente,
        vocesElegidas,
      );
      if (!ref.mounted) return;
      state = EstadoPrueba(
        clave: clave,
        sonando: true,
        mensaje: 'Suena con: $quien',
      );
      Fin? fin;
      try {
        fin = await repro.terminada;
      } on ErrorVoz {
        if (ref.mounted && identical(_actual, repro)) {
          _actual = null;
          state = EstadoPrueba(clave: clave, mensaje: 'La voz se detuvo.');
        }
        return;
      }
      if (ref.mounted && identical(_actual, repro)) {
        _actual = null;
        state = EstadoPrueba(
          clave: clave,
          mensaje: fin == Fin.completa ? 'Sonó con: $quien' : null,
        );
      }
    } on SinFuenteDisponible catch (e) {
      if (!ref.mounted) return;
      final motivos = e.motivos.entries
          .map((m) => '${m.key.nombre}: ${describirMotivo(m.value)}')
          .join('. ');
      state = EstadoPrueba(
        clave: clave,
        mensaje:
            'No hay una voz disponible para esta prueba.${motivos.isEmpty ? '' : ' $motivos.'}',
      );
    } on OcupadoPorOtroUso {
      if (!ref.mounted) return;
      state = EstadoPrueba(
        clave: clave,
        mensaje: 'Hay otra voz sonando.',
        hayOtraVoz: true,
      );
    } on ErrorVoz {
      if (!ref.mounted) return;
      state = EstadoPrueba(clave: clave, mensaje: 'La voz se detuvo.');
    }
  }

  /// "Voz del dispositivo · nombre" (o una por cada voz del diálogo).
  Future<String> _quienSono(
    MotorVoz motor,
    Guion guion,
    Fuente fuente,
    Map<VozDeGuion, String>? vocesElegidas,
  ) async {
    final asignacion = vocesElegidas != null
        ? Asignacion(fuente, guion.variante, vocesElegidas)
        : await motor.asignacion(
            fuente,
            guion.variante,
            roles: guion.vocesUsadas,
          );
    final voces = {
      for (final v in await motor.voces(fuente, variante: guion.variante))
        v.id: v.nombre,
    };
    final nombres = <String>[];
    for (final rol in guion.vocesUsadas) {
      final id = asignacion?.idVozMotor[rol];
      final nombre = id == null ? null : voces[id];
      if (nombre == null) continue;
      nombres.add(guion.vocesDistintas > 1 ? '${rol.etiqueta}: $nombre' : nombre);
    }
    final lista = nombres.isEmpty ? '' : ' · ${nombres.join(' · ')}';
    return '${fuente.nombre}$lista';
  }

  /// Corta la prueba; si la que suena es de otro uso, la corta también.
  Future<void> parar() async {
    final r = _actual;
    if (r != null) {
      await r.parar();
    } else {
      await ref.read(motorVozProvider).detener();
    }
    if (ref.mounted) state = const EstadoPrueba();
  }
}
