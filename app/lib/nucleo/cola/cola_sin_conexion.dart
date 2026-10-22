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
/// - En la tablet pública de la casa (D14), lo de la casa se registra sin PIN
///   eligiendo el nombre ([OrigenRegistro.tabletCasa]): se guarda quién dijo
///   ser y solo se envía con la sesión de la **cuenta del equipo** (Casa),
///   nunca con la de esa persona (no entró con su PIN).
/// - Lo que el servidor no acepta (sin permiso, datos inválidos) o lo que
///   falla demasiadas veces queda en "requiere atención"
///   ([EstadoPendiente.rechazado]): no se pierde, no se reintenta solo y la
///   app lo muestra para que la persona decida.
/// - **Falta de dependencia** (23503: otra cuenta, el original de una
///   anulación… que aún no sube): **se reintenta**, con la misma espera
///   creciente, y no detiene al resto de la ronda ([FaltaDependenciaEnvio]).
///   No va a "requiere atención" por eso; solo si pasan
///   [ColaSinConexion.intentosMaximosPorDependencia] intentos.
/// - **Orden de subida por dependencia:** si el enviador sabe el nivel de
///   cada tipo ([EnviadorOrdenado]), cada ronda sube primero los de nivel
///   menor (cuentas, luego movimientos, luego conciliaciones…) y, dentro de
///   un mismo nivel, en el orden en que se crearon. Un nivel más bajo creado
///   después pasa primero; el reintento por dependencia cubre lo demás.
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
    this.personaId,
    this.origen = OrigenRegistro.propio,
  });

  final String id;
  final String tipo;
  final Map<String, Object?> carga;
  final DateTime creadoEn;

  /// Número de intento (1 la primera vez).
  final int intento;

  /// Quién lo registró (en [OrigenRegistro.tabletCasa], quien dijo ser).
  final String? personaId;
  final OrigenRegistro origen;
}

/// Un enviador la lanza para rechazar un registro diciendo por qué (queda en
/// "requiere atención" con ese motivo).
class RechazoEnvio implements Exception {
  const RechazoEnvio(this.motivo);

  final String motivo;

  @override
  String toString() => 'RechazoEnvio: $motivo';
}

/// Un enviador la lanza cuando al servidor le **falta algo de lo que el
/// registro depende** (23503: otra cuenta, el movimiento que se anula, la
/// semana a la que se aplica… que quizá aún no sube). La cola lo reintenta con
/// espera creciente **sin detener la ronda**: los demás registros siguen, y el
/// registro no pasa a "requiere atención" por esto.
class FaltaDependenciaEnvio implements Exception {
  const FaltaDependenciaEnvio(this.motivo);

  final String motivo;

  @override
  String toString() => 'FaltaDependenciaEnvio: $motivo';
}

/// Envía registros al servidor. Debe ser idempotente por [PeticionEnvio.id].
/// Una excepción cuenta como [ResultadoEnvio.reintentar] (hasta
/// [ColaSinConexion.intentosMaximos]); [RechazoEnvio] manda el registro a
/// "requiere atención" y [FaltaDependenciaEnvio] lo reintenta sin detener la
/// ronda.
abstract interface class Enviador {
  Future<ResultadoEnvio> enviar(PeticionEnvio peticion);
}

/// Un [Enviador] que sabe en qué orden deben subir sus tipos de registro
/// porque unos dependen de otros (cuentas antes que movimientos, el ajuste
/// antes que su conciliación, el cierre antes de marcar la semana cerrada).
abstract interface class EnviadorOrdenado implements Enviador {
  /// Nivel de [tipo]: cada ronda sube primero los de nivel menor. Los tipos
  /// que no dependen de nada (o que el enviador no conoce) son de nivel 0.
  int nivelDeSubida(String tipo);
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
    this.intentosMaximosPorDependencia = 100,
    this.nivelDeSubida,
    this.personaQueRegistra,
    this.personaConSesion,
    this.cuentaDelEquipo,
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

  /// Lo mismo para la falta de dependencia (23503): se reintenta con la
  /// espera creciente (tope de 30 minutos), así que 100 intentos son unos dos
  /// días con la app abierta. Pasado eso, que lo vea la persona; antes no es
  /// un error permanente (lo que falta puede estar por subir desde otro
  /// dispositivo).
  final int intentosMaximosPorDependencia;

  /// Nivel de subida de cada tipo (ver [EnviadorOrdenado]); por omisión, el
  /// del enviador si es un [EnviadorOrdenado], y si no, todos de nivel 0
  /// (solo el orden de creación).
  final int Function(String tipo)? nivelDeSubida;

  /// Persona que registra ahora (se guarda en cada registro). En la tablet,
  /// la que entró con su PIN.
  final String? Function()? personaQueRegistra;

  /// Persona con cuya sesión salen ahora las peticiones al servidor. Si se da
  /// y devuelve `null` (nadie ha entrado), la cola no envía nada; si devuelve
  /// una persona, solo se envía lo que ella registró.
  final String? Function()? personaConSesion;

  /// Persona de la cuenta del equipo (la cuenta Casa de la tablet pública), o
  /// `null` si el equipo no tiene una. Lo registrado en la tablet de la casa
  /// sin PIN solo se envía cuando la sesión del servidor es esa cuenta.
  final String? Function()? cuentaDelEquipo;

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
  /// [origen] dice si la persona entró con su sesión o eligió su nombre en la
  /// tablet de la casa (entonces [personaId] es obligatorio).
  Future<String> encolar({
    required String tipo,
    required Map<String, Object?> carga,
    String? id,
    String? personaId,
    OrigenRegistro origen = OrigenRegistro.propio,
  }) async {
    if (origen == OrigenRegistro.tabletCasa && personaId == null) {
      throw ArgumentError.notNull('personaId');
    }
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
            origen: Value(origen),
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
    // Lo de la tablet de la casa (sin PIN) sale solo con la cuenta del
    // equipo; lo demás, solo con la sesión de quien lo registró.
    final equipo = cuentaDelEquipo?.call();
    final conCuentaDelEquipo = persona != null && persona == equipo;
    final listos =
        await (_base.select(_tabla)
              ..where((t) {
                final esDeLaCasa = t.origen.equalsValue(
                  OrigenRegistro.tabletCasa,
                );
                final propio = t.origen.isNull() | esDeLaCasa.not();
                final deQuien = persona == null
                    ? const Constant(true)
                    : (propio & t.personaId.equals(persona)) |
                          (esDeLaCasa & Constant(conCuentaDelEquipo));
                return t.estado.equalsValue(EstadoPendiente.pendiente) &
                    (t.siguienteIntento.isNull() |
                        t.siguienteIntento.isSmallerOrEqualValue(ahora)) &
                    deQuien;
              })
              ..orderBy([
                (t) => OrderingTerm.asc(t.creadoEn),
                (t) => OrderingTerm.asc(t.rowId),
              ]))
            .get();

    // Orden de subida: primero los de nivel menor, y dentro de un nivel, el
    // orden en que se crearon (el de la consulta).
    final nivelDe = nivelDeSubida ?? _nivelDelEnviador;
    final posicion = {
      for (var i = 0; i < listos.length; i++) listos[i].id: i,
    };
    final niveles = {for (final r in listos) r.id: nivelDe(r.tipo)};
    listos.sort((a, b) {
      final porNivel = niveles[a.id]!.compareTo(niveles[b.id]!);
      return porNivel != 0
          ? porNivel
          : posicion[a.id]!.compareTo(posicion[b.id]!);
    });

    var enviados = 0;
    var reintentos = 0;
    var rechazados = 0;
    for (final registro in listos) {
      final intento = registro.intentos + 1;
      ResultadoEnvio resultado;
      String? error;
      var faltaDependencia = false;
      try {
        resultado = await _enviador.enviar(
          PeticionEnvio(
            id: registro.id,
            tipo: registro.tipo,
            carga: (jsonDecode(registro.carga) as Map).cast<String, Object?>(),
            creadoEn: registro.creadoEn,
            intento: intento,
            personaId: registro.personaId,
            origen: registro.origen ?? OrigenRegistro.propio,
          ),
        );
      } on RechazoEnvio catch (e) {
        resultado = ResultadoEnvio.rechazado;
        error = e.motivo;
      } on FaltaDependenciaEnvio catch (e) {
        resultado = ResultadoEnvio.reintentar;
        error = e.motivo;
        faltaDependencia = true;
      } catch (e) {
        resultado = ResultadoEnvio.reintentar;
        error = '$e';
      }
      if (resultado == ResultadoEnvio.sinSesion) break;
      final limite = faltaDependencia
          ? intentosMaximosPorDependencia
          : intentosMaximos;
      if (resultado == ResultadoEnvio.reintentar && intento >= limite) {
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
      // Sin señal o con el servidor ocupado se detiene la ronda (los demás
      // fallarían igual); si solo falta una dependencia, el servidor sí
      // responde y los demás pueden seguir.
      if (resultado == ResultadoEnvio.reintentar && !faltaDependencia) break;
    }

    if (enviados + reintentos + rechazados > 0) _avisar();
    return ResumenProceso(
      enviados: enviados,
      reintentos: reintentos,
      rechazados: rechazados,
      restantes: await contarPendientes(),
    );
  }

  int _nivelDelEnviador(String tipo) {
    final enviador = _enviador;
    return enviador is EnviadorOrdenado ? enviador.nivelDeSubida(tipo) : 0;
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
  /// [personaId] si se da: nadie ve lo que registró otra persona (D5). Con
  /// [deLaTabletCasa] (modo Casa) se incluyen los registrados en la tablet de
  /// la casa sin PIN, que son de la casa.
  Future<List<RegistroPendiente>> requierenAtencion({
    String? personaId,
    bool deLaTabletCasa = false,
  }) => _consultaAtencion(personaId, deLaTabletCasa).get();

  /// Lo mismo, en vivo (para el aviso en pantalla).
  Stream<List<RegistroPendiente>> vigilarAtencion({
    String? personaId,
    bool deLaTabletCasa = false,
  }) => _vigilar(
    () => requierenAtencion(personaId: personaId, deLaTabletCasa: deLaTabletCasa),
  );

  SimpleSelectStatement<$PendientesTable, RegistroPendiente> _consultaAtencion(
    String? personaId,
    bool deLaTabletCasa,
  ) => _base.select(_tabla)
    ..where((t) {
      final esDeLaCasa = t.origen.equalsValue(OrigenRegistro.tabletCasa);
      final propio = t.origen.isNull() | esDeLaCasa.not();
      final deQuien = personaId == null
          ? const Constant(true)
          : (propio & t.personaId.equals(personaId)) |
                (esDeLaCasa & Constant(deLaTabletCasa));
      return t.estado.equalsValue(EstadoPendiente.rechazado) & deQuien;
    })
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
