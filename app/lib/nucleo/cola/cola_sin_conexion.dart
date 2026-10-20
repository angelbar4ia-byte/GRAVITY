/// Cola sin conexión (D7): lo registrado sin señal se guarda en el dispositivo
/// y se sube cuando vuelve la señal.
///
/// - Cada registro lleva un UUID generado en el dispositivo.
/// - Encolar dos veces el mismo id no lo duplica, y un registro ya enviado no
///   se vuelve a enviar (idempotencia). El servidor también usa el id como
///   llave, así que un reenvío tras una respuesta perdida no duplica.
/// - Si un envío falla por red, se reintenta con espera creciente.
/// - Cada registro guarda **quién** lo hizo y solo se envía con la sesión del
///   servidor de esa persona; sin sesión no se envía nada (revisión de la
///   Fase 0, I4).
/// - Lo que el servidor no acepta (sin permiso, datos inválidos) o lo que
///   falla demasiadas veces queda en "requiere atención"
///   ([EstadoPendiente.rechazado]): no se pierde, no se reintenta solo y la
///   app lo muestra para que la persona decida.
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

  /// El servidor no lo acepta (permisos, datos inválidos): requiere atención.
  rechazado,

  /// No hay sesión con el servidor: no se intentó; espera a que la haya (no
  /// cuenta como intento).
  sinSesion,
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

/// Un enviador la lanza para rechazar un registro diciendo por qué (queda en
/// "requiere atención" con ese motivo).
class RechazoEnvio implements Exception {
  const RechazoEnvio(this.motivo);

  final String motivo;

  @override
  String toString() => 'RechazoEnvio: $motivo';
}

/// Envía registros al servidor. Debe ser idempotente por [PeticionEnvio.id].
/// Una excepción cuenta como [ResultadoEnvio.reintentar] (hasta
/// [ColaSinConexion.intentosMaximos]).
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
    this.intentosMaximos = 20,
    this.personaQueRegistra,
    this.personaConSesion,
    DateTime Function()? reloj,
    String Function()? generarId,
  }) : _reloj = reloj ?? DateTime.now,
       _generarId = generarId ?? const Uuid().v4;

  final BaseLocal _base;
  final Enviador _enviador;
  final PoliticaReintentos politica;

  /// Tras estos intentos fallidos sin respuesta clara, el registro pasa a
  /// "requiere atención" en lugar de reintentarse para siempre (M16).
  final int intentosMaximos;

  /// Persona que registra ahora (se guarda en cada registro). En la tablet,
  /// la que entró con su PIN.
  final String? Function()? personaQueRegistra;

  /// Persona con cuya sesión salen ahora las peticiones al servidor. Si se da
  /// y devuelve `null` (nadie ha entrado), la cola no envía nada; si devuelve
  /// una persona, solo se envía lo que ella registró.
  final String? Function()? personaConSesion;

  final DateTime Function() _reloj;
  final String Function() _generarId;

  Future<ResumenProceso>? _enCurso;
  Timer? _temporizador;

  /// Avisa cada vez que la cola cambia (para los avisos en pantalla). Se usa
  /// en lugar de `watch()` de drift, que deja temporizadores al cancelar.
  final _cambios = StreamController<void>.broadcast(sync: true);

  void _avisar() {
    if (!_cambios.isClosed) _cambios.add(null);
  }

  /// Emite [consulta] ahora y otra vez cada vez que la cola cambia.
  Stream<T> _vigilar<T>(Future<T> Function() consulta) {
    late final StreamController<T> salida;
    StreamSubscription<void>? cambios;
    var activa = true;
    Future<void> emitir() async {
      try {
        final valor = await consulta();
        if (activa) salida.add(valor);
      } catch (error, pila) {
        if (activa) salida.addError(error, pila);
      }
    }

    salida = StreamController<T>(
      onListen: () {
        cambios = _cambios.stream.listen((_) => emitir());
        emitir();
      },
      onCancel: () {
        activa = false;
        return cambios?.cancel();
      },
    );
    return salida.stream;
  }

  $PendientesTable get _tabla => _base.pendientes;

  /// Guarda un registro para subirlo. Devuelve su id (UUID). Si ya existe un
  /// registro con [id], no se duplica.
  /// [personaId] es quien lo registra; por omisión, [personaQueRegistra].
  Future<String> encolar({
    required String tipo,
    required Map<String, Object?> carga,
    String? id,
    String? personaId,
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
            personaId: Value(personaId ?? personaQueRegistra?.call()),
          ),
          mode: InsertMode.insertOrIgnore,
        );
    _avisar();
    return idFinal;
  }

  /// Envía, en orden de creación, los pendientes cuya espera ya pasó. Si un
  /// envío falla por red, se programa su reintento y se detiene la ronda. Si
  /// ya hay una ronda en curso, devuelve esa misma (nunca envía en paralelo).
  Future<ResumenProceso> procesar() =>
      _enCurso ??= _procesar().whenComplete(() => _enCurso = null);

  Future<ResumenProceso> _procesar() async {
    final ahora = _reloj();
    // Sin sesión no se envía nada; con sesión, solo lo de esa persona.
    final conSesion = personaConSesion;
    final persona = conSesion?.call();
    if (conSesion != null && persona == null) {
      return ResumenProceso(
        enviados: 0,
        reintentos: 0,
        rechazados: 0,
        restantes: await contarPendientes(),
      );
    }
    final listos =
        await (_base.select(_tabla)
              ..where(
                (t) =>
                    t.estado.equalsValue(EstadoPendiente.pendiente) &
                    (t.siguienteIntento.isNull() |
                        t.siguienteIntento.isSmallerOrEqualValue(ahora)) &
                    (persona == null
                        ? const Constant(true)
                        : t.personaId.equals(persona)),
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
      } on RechazoEnvio catch (e) {
        resultado = ResultadoEnvio.rechazado;
        error = e.motivo;
      } catch (e) {
        resultado = ResultadoEnvio.reintentar;
        error = '$e';
      }
      if (resultado == ResultadoEnvio.sinSesion) break;
      if (resultado == ResultadoEnvio.reintentar && intento >= intentosMaximos) {
        // Demasiados intentos sin una respuesta clara: que lo vea la persona.
        resultado = ResultadoEnvio.rechazado;
        error = 'Falló $intento veces: ${error ?? 'sin respuesta clara del servidor'}';
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
              ultimoError: Value(error ?? 'El servidor no lo aceptó'),
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
        case ResultadoEnvio.sinSesion:
          break;
      }
      if (resultado == ResultadoEnvio.reintentar) break;
    }

    if (enviados + reintentos + rechazados > 0) _avisar();
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
  Stream<int> vigilarPendientes() => _vigilar(contarPendientes);

  Selectable<int> _consultaPendientes() {
    final cuenta = _tabla.id.count();
    return (_base.selectOnly(_tabla)
          ..addColumns([cuenta])
          ..where(_tabla.estado.equalsValue(EstadoPendiente.pendiente)))
        .map((fila) => fila.read(cuenta) ?? 0);
  }

  /// Registros que requieren atención (el servidor no los aceptó), de
  /// [personaId] si se da: nadie ve lo que registró otra persona (D5).
  Future<List<RegistroPendiente>> requierenAtencion({String? personaId}) =>
      _consultaAtencion(personaId).get();

  /// Lo mismo, en vivo (para el aviso en pantalla).
  Stream<List<RegistroPendiente>> vigilarAtencion({String? personaId}) =>
      _vigilar(() => requierenAtencion(personaId: personaId));

  SimpleSelectStatement<$PendientesTable, RegistroPendiente> _consultaAtencion(
    String? personaId,
  ) => _base.select(_tabla)
    ..where(
      (t) =>
          t.estado.equalsValue(EstadoPendiente.rechazado) &
          (personaId == null
              ? const Constant(true)
              : t.personaId.equals(personaId)),
    )
    ..orderBy([
      (t) => OrderingTerm.asc(t.creadoEn),
      (t) => OrderingTerm.asc(t.rowId),
    ]);

  /// La persona pide intentar otra vez un registro que requería atención.
  Future<void> reintentar(String id) => _cambiarAtencion(
    id,
    const PendientesCompanion(
      estado: Value(EstadoPendiente.pendiente),
      intentos: Value(0),
      siguienteIntento: Value(null),
    ),
  );

  /// La persona decide no subir un registro que requería atención.
  Future<void> descartar(String id) => _cambiarAtencion(
    id,
    const PendientesCompanion(
      estado: Value(EstadoPendiente.descartado),
      siguienteIntento: Value(null),
    ),
  );

  Future<void> _cambiarAtencion(String id, PendientesCompanion cambio) async {
    await (_base.update(_tabla)..where(
          (t) =>
              t.id.equals(id) &
              t.estado.equalsValue(EstadoPendiente.rechazado),
        ))
        .write(cambio);
    _avisar();
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

  /// Deja de avisar cambios (al desechar la cola).
  Future<void> cerrar() async {
    detenerAutomatico();
    await _cambios.close();
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
