/// Fuente de voz simulada para pruebas (spec, sección 11.1): no abre ningún
/// plugin, no suena nada y guarda lo que se le pidió.
///
/// Puede declarar pocas voces o voces de red, tardar lo que se quiera en cada
/// turno (o esperar a que la prueba lo termine a mano) y fallar a mitad.
library;

import 'dart:async';

import 'asignador.dart';
import 'fuente_de_voz.dart';
import 'reproduccion_por_turnos.dart';
import 'tipos.dart';

/// Lo que la fuente falsa recibió para decir un turno.
final class PeticionFalsa {
  const PeticionFalsa({
    required this.voz,
    required this.idVozMotor,
    required this.texto,
    required this.velocidad,
  });
  final VozDeGuion voz;
  final String idVozMotor;
  final String texto;
  final double velocidad;
}

/// Un conjunto de voces de ejemplo: dos mujeres y dos hombres por acento en
/// inglés, y tres en español. No son datos de nadie.
List<VozMotor> vocesDeEjemplo({Fuente fuente = Fuente.dispositivo}) {
  VozMotor v(String id, Variante variante, Genero genero, {int calidad = 3}) =>
      VozMotor(
        id: id,
        fuente: fuente,
        nombre: 'Voz $id',
        variante: variante,
        genero: genero,
        local: true,
        locale: variante.etiqueta,
        calidad: calidad,
      );
  return [
    v('us-mujer-1', Variante.enUS, Genero.mujer),
    v('us-mujer-2', Variante.enUS, Genero.mujer),
    v('us-hombre-1', Variante.enUS, Genero.hombre),
    v('us-hombre-2', Variante.enUS, Genero.hombre),
    v('us-neutra-1', Variante.enUS, Genero.sinDato),
    v('gb-mujer-1', Variante.enGB, Genero.mujer),
    v('gb-hombre-1', Variante.enGB, Genero.hombre),
    v('es-1', Variante.esMX, Genero.sinDato),
    v('es-2', Variante.esMX, Genero.sinDato),
    v('es-3', Variante.esMX, Genero.sinDato),
  ];
}

class FuenteDeVozFalsa implements FuenteDeVoz, FuenteConDiagnostico {
  FuenteDeVozFalsa({
    this.tipo = Fuente.dispositivo,
    List<VozMotor>? voces,
    this.duracionTurno = const Duration(milliseconds: 400),
    this.manual = false,
    this.fallarEnTurno,
    this.motivo,
    this.errorAlListar,
    this.capacidades = const Capacidades(
      tono: false,
      progresoPorPalabra: false,
      pausa: true,
      velocidadMin: 0.5,
      velocidadMax: 1.5,
    ),
  }) : catalogo = voces ?? vocesDeEjemplo(fuente: tipo);

  @override
  final Fuente tipo;
  @override
  final Capacidades capacidades;

  /// Todas las voces que dice tener (también las de red).
  List<VozMotor> catalogo;

  /// Cuánto tarda cada turno (si no es [manual]). Cero: termina al instante y
  /// sin temporizador.
  Duration duracionTurno;

  /// Si es `true`, un turno no termina hasta que la prueba llame a
  /// [terminarTurno].
  bool manual;

  /// Índice del turno que falla (`FalloDeSintesis`), o `null`.
  int? fallarEnTurno;

  /// Si no es `null`, [motivoNoDisponible] lo devuelve siempre.
  Motivo? motivo;

  /// Si no es `null`, [voces] lo lanza (simula un equipo sin motor de voz).
  ErrorVoz? errorAlListar;

  /// Lo que se le pidió decir, en orden.
  final peticiones = <PeticionFalsa>[];

  /// Cuántas reproducciones empezaron.
  int reproducciones = 0;

  /// Cuántas veces se cortó un turno que sonaba.
  int cortes = 0;

  /// La velocidad con la que se pidió la última reproducción.
  double? ultimaVelocidad;

  int refrescos = 0;

  Completer<void>? _turnoEnCurso;
  bool _cortado = false;

  /// Termina el turno que suena (modo [manual]).
  void terminarTurno() {
    final c = _turnoEnCurso;
    if (c != null && !c.isCompleted) c.complete();
  }

  /// `true` si hay un turno sonando.
  bool get sonando => _turnoEnCurso != null && !_turnoEnCurso!.isCompleted;

  @override
  Future<void> refrescar() async => refrescos++;

  @override
  Future<List<VozDelSistema>> diagnostico() async => [
    for (final v in catalogo)
      VozDelSistema(
        nombre: v.nombre,
        locale: v.locale.isEmpty ? v.variante.etiqueta : v.locale,
        requiereRed: !v.local,
        genero: v.genero,
      ),
  ];

  @override
  Future<List<VozMotor>> voces(Variante variante) async {
    final error = errorAlListar;
    if (error != null) throw error;
    return [
      for (final v in catalogo)
        if (v.variante == variante) v,
    ];
  }

  @override
  Future<Motivo?> motivoNoDisponible(Guion guion, Asignacion asignacion) async {
    if (motivo != null) return motivo;
    final locales = [
      for (final v in await voces(guion.variante))
        if (v.local) v.id,
    ];
    if (locales.isEmpty) return Motivo.sinVozEnElIdioma;
    for (final rol in guion.vocesUsadas) {
      final id = asignacion.idVozMotor[rol];
      if (id == null || !locales.contains(id)) return Motivo.vocesInsuficientes;
    }
    return null;
  }

  @override
  Future<Reproduccion> reproducir(
    Guion guion,
    Asignacion asignacion,
    double velocidad,
  ) async {
    reproducciones++;
    ultimaVelocidad = velocidad;
    return ReproduccionPorTurnos(
      fuente: tipo,
      guion: guion,
      decirTurno: (i, turno) async {
        if (fallarEnTurno == i) throw FalloDeSintesis(tipo, 'falla_simulada');
        peticiones.add(
          PeticionFalsa(
            voz: turno.voz,
            idVozMotor: asignacion.idVozMotor[turno.voz] ?? '',
            texto: turno.texto,
            velocidad: velocidad,
          ),
        );
        _cortado = false;
        final c = _turnoEnCurso = Completer<void>();
        Timer? reloj;
        if (!manual) {
          if (duracionTurno <= Duration.zero) {
            // Sin temporizador: las pruebas de widgets no dejan nada pendiente.
            c.complete();
          } else {
            reloj = Timer(duracionTurno, () {
              if (!c.isCompleted) c.complete();
            });
          }
        }
        await c.future;
        reloj?.cancel();
        return _cortado ? ResultadoTurno.interrumpido : ResultadoTurno.completo;
      },
      detenerTurno: () async {
        final c = _turnoEnCurso;
        if (c != null && !c.isCompleted) {
          cortes++;
          _cortado = true;
          c.complete();
        }
      },
    );
  }
}
