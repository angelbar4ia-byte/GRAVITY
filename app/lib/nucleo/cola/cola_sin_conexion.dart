/// Cola sin conexión (D7): lo registrado sin señal se guarda en el dispositivo
/// y se sube cuando vuelve la señal.
///
/// - Cada registro lleva un UUID generado en el dispositivo.
/// - Encolar dos veces el mismo id no lo duplica, y un registro ya enviado no
///   se vuelve a enviar (idempotencia). El servidor también usa el id como
///   llave, así que un reenvío tras una respuesta perdida no duplica.
/// - Si un envío falla por red, se reintenta con espera creciente.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../base_local/base_local.dart';

/// Lo que responde el servidor a un envío.
enum ResultadoEnvio {
  /// Se guardó (o ya existía con ese id).
  enviado,

  /// Falla pasajera (sin señal, servidor ocupado): se reintenta después.
  reintentar,

  /// El servidor no lo acepta (permisos, datos inválidos): no se reintenta.
  rechazado,
}

/// Un registro listo para enviarse.
class PeticionEnvio {
  const PeticionEnvio({
    required this.id,
    required this.tipo,
    required this.carga,
    required this.creadoEn,
    required this.intento,
  });

  final String id;
  final String tipo;
  final Map<String, Object?> carga;
  final DateTime creadoEn;

  /// Número de intento (1 la primera vez).
  final int intento;
}

/// Envía registros al servidor. Debe ser idempotente por [PeticionEnvio.id].
/// Una excepción cuenta como [ResultadoEnvio.reintentar].
abstract interface class Enviador {
  Future<ResultadoEnvio> enviar(PeticionEnvio peticion);
}

/// Espera creciente entre reintentos: inicial × factor^(intentos − 1), con tope.
class PoliticaReintentos {
  const PoliticaReintentos({
    this.esperaInicial = const Duration(seconds: 5),
    this.factor = 2,
    this.esperaMaxima = const Duration(minutes: 30),
  });

  final Duration esperaInicial;
  final double factor;
  final Duration esperaMaxima;

  /// Espera después de [intentos] fallidos (1 o más).
  Duration esperaTras(int intentos) {
    final exponente = max(0, intentos - 1);
    final ms = esperaInicial.inMilliseconds * pow(factor, exponente);
    return Duration(milliseconds: min(ms, esperaMaxima.inMilliseconds).round());
  }
}

/// Resultado de una ronda de envío.
class ResumenProceso {
  const ResumenProceso({
    required this.enviados,
    required this.reintentos,
    required this.rechazados,
    required this.restantes,
  });

  final int enviados;
  final int reintentos;
  final int rechazados;

  /// Pendientes que quedan en la cola al terminar la ronda.
  final int restantes;

  @override
  String toString() =>
      'ResumenProceso(enviados: $enviados, reintentos: $reintentos, '
      'rechazados: $rechazados, restantes: $restantes)';
}

class ColaSinConexion {
  ColaSinConexion({
    required this._base,
    required this._enviador,
    this.politica = const PoliticaReintentos(),
    DateTime Function()? reloj,
    String Function()? generarId,
  }) : _reloj = reloj ?? DateTime.now,
       _generarId = generarId ?? const Uuid().v4;

  final BaseLocal _base;
  final Enviador _enviador;
  final PoliticaReintentos politica;
  final DateTime Function() _reloj;
  final String Function() _generarId;

  Future<ResumenProceso>? _enCurso;
  Timer? _temporizador;

  $PendientesTable get _tabla => _base.pendientes;

  /// Guarda un registro para subirlo. Devuelve su id (UUID). Si ya existe un
  /// registro con [id], no se duplica.
  Future<String> encolar({
    required String tipo,
    required Map<String, Object?> carga,
    String? id,
  }) async {
    final idFinal = id ?? _generarId();
    await _base
        .into(_tabla)
        .insert(
          PendientesCompanion.insert(
            id: idFinal,
            tipo: tipo,
            carga: jsonEncode(carga),
            creadoEn: _reloj(),
            estado: EstadoPendiente.pendiente,
          ),
          mode: InsertMode.insertOrIgnore,
        );
    return idFinal;
  }

  /// Envía, en orden de creación, los pendientes cuya espera ya pasó. Si un
  /// envío falla por red, se programa su reintento y se detiene la ronda. Si
  /// ya hay una ronda en curso, devuelve esa misma (nunca envía en paralelo).
  Future<ResumenProceso> procesar() =>
      _enCurso ??= _procesar().whenComplete(() => _enCurso = null);

  Future<ResumenProceso> _procesar() async {
    final ahora = _reloj();
    final listos =
        await (_base.select(_tabla)
              ..where(
                (t) =>
                    t.estado.equalsValue(EstadoPendiente.pendiente) &
                    (t.siguienteIntento.isNull() |
                        t.siguienteIntento.isSmallerOrEqualValue(ahora)),
              )
              ..orderBy([
                (t) => OrderingTerm.asc(t.creadoEn),
                (t) => OrderingTerm.asc(t.rowId),
              ]))
            .get();

    var enviados = 0;
    var reintentos = 0;
    var rechazados = 0;
    for (final registro in listos) {
      final intento = registro.intentos + 1;
      ResultadoEnvio resultado;
      String? error;
      try {
        resultado = await _enviador.enviar(
          PeticionEnvio(
            id: registro.id,
            tipo: registro.tipo,
            carga: (jsonDecode(registro.carga) as Map).cast<String, Object?>(),
            creadoEn: registro.creadoEn,
            intento: intento,
          ),
        );
      } catch (e) {
        resultado = ResultadoEnvio.reintentar;
        error = '$e';
      }

      final actualizar = _base.update(_tabla)
        ..where(
          (t) =>
              t.id.equals(registro.id) &
              t.estado.equalsValue(EstadoPendiente.pendiente),
        );
      switch (resultado) {
        case ResultadoEnvio.enviado:
          enviados++;
          await actualizar.write(
            PendientesCompanion(
              estado: const Value(EstadoPendiente.enviado),
              intentos: Value(intento),
              siguienteIntento: const Value(null),
              ultimoError: const Value(null),
            ),
          );
        case ResultadoEnvio.rechazado:
          rechazados++;
          await actualizar.write(
            PendientesCompanion(
              estado: const Value(EstadoPendiente.rechazado),
              intentos: Value(intento),
              siguienteIntento: const Value(null),
              ultimoError: Value(error ?? 'Rechazado por el servidor'),
            ),
          );
        case ResultadoEnvio.reintentar:
          reintentos++;
          await actualizar.write(
            PendientesCompanion(
              intentos: Value(intento),
              siguienteIntento: Value(ahora.add(politica.esperaTras(intento))),
              ultimoError: Value(error ?? 'Sin respuesta del servidor'),
            ),
          );
      }
      if (resultado == ResultadoEnvio.reintentar) break;
    }

    return ResumenProceso(
      enviados: enviados,
      reintentos: reintentos,
      rechazados: rechazados,
      restantes: await contarPendientes(),
    );
  }

  /// Cuántos registros faltan por subir.
  Future<int> contarPendientes() => _consultaPendientes().getSingle();

  /// Cuántos faltan por subir, en vivo (para el aviso "3 por subir").
  Stream<int> vigilarPendientes() => _consultaPendientes().watchSingle();

  Selectable<int> _consultaPendientes() {
    final cuenta = _tabla.id.count();
    return (_base.selectOnly(_tabla)
          ..addColumns([cuenta])
          ..where(_tabla.estado.equalsValue(EstadoPendiente.pendiente)))
        .map((fila) => fila.read(cuenta) ?? 0);
  }

  /// Todos los registros de la cola (para revisar y para pruebas).
  Future<List<RegistroPendiente>> registros() => (_base.select(_tabla)
        ..orderBy([
          (t) => OrderingTerm.asc(t.creadoEn),
          (t) => OrderingTerm.asc(t.rowId),
        ]))
      .get();

  /// Borra los enviados con más de [antiguedad].
  Future<int> limpiarEnviados({
    Duration antiguedad = const Duration(days: 7),
  }) {
    final limite = _reloj().subtract(antiguedad);
    return (_base.delete(_tabla)..where(
          (t) =>
              t.estado.equalsValue(EstadoPendiente.enviado) &
              t.creadoEn.isSmallerThanValue(limite),
        ))
        .go();
  }

  /// Intenta subir cada [cada] mientras la app está abierta (el registro
  /// llega en cuanto vuelve la señal).
  void iniciarAutomatico({Duration cada = const Duration(seconds: 30)}) {
    _temporizador?.cancel();
    _temporizador = Timer.periodic(cada, (_) => unawaited(procesar()));
  }

  void detenerAutomatico() {
    _temporizador?.cancel();
    _temporizador = null;
  }
}
