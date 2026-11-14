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
import '../sesion/sesion.dart' show ErrorSesion;

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

/// Prefijos de los tipos de registro **personales** (dinero, hábitos, datos
/// clínicos). En la tablet pública de la casa nunca se registran con solo el
/// nombre: piden nombre y PIN (D14), y suben con la sesión de la persona.
const List<String> prefijosDeTiposPersonales = [
  'finanzas.',
  'habitos.',
  'cuidados.',
];

/// `true` si [tipo] es un registro personal (ver [prefijosDeTiposPersonales]).
bool esTipoPersonal(String tipo) =>
    prefijosDeTiposPersonales.any(tipo.startsWith);

/// Motivos que ve la persona en "Por revisar" cuando la bandeja de salida no
/// pudo subir lo suyo (ver `bandeja_salida.dart`).
const motivoBandejaCaducada =
    'No se pudo subir en 7 días: la bandeja de salida caducó. Revísalo y '
    'vuelve a intentarlo con tu PIN.';
const motivoSesionInservible =
    'Tu sesión en esta tablet ya no sirve para subirlo sola. Entra con tu PIN '
    'para revisarlo.';
const motivoPersonaQuitada =
    'Se quitó a la persona de la tablet antes de que se pudiera subir. Se '
    'borra de esta tablet a los 7 días.';

/// Cuánto se conserva en la tablet lo que una persona quitada dejó sin subir
/// (L1 de la revisión de la Fase 1b): ese registro (monto, concepto, cuentas)
/// está en la base local en claro y, si la persona no vuelve, nadie lo
/// revisaría nunca.
const conservarLoDeQuitados = Duration(days: 7);

/// Cuánto se conserva en la base local lo ya **enviado** (para revisar un
/// envío reciente) y lo **descartado** por la persona. Pasado el plazo se
/// borra: ese registro (monto, concepto, cuentas) está en claro y ya no hace
/// falta (L1 de la revisión de la Fase 1b).
const conservarLoEnviado = Duration(days: 1);
const conservarLoDescartado = Duration(days: 7);

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

/// Qué permisos de subida hay y cuáles caducaron (ver `bandeja_salida.dart`).
class PreparacionSalida {
  const PreparacionSalida({
    this.conPermiso = const [],
    this.caducadas = const [],
  });

  /// Personas con algo por subir y un permiso vigente.
  final List<String> conPermiso;

  /// Personas cuyo permiso caducó (ya se borró su credencial).
  final List<String> caducadas;
}

/// Una sesión abierta aparte para subir lo de una persona.
abstract interface class SesionDeSubida {
  /// Sube con el token de **esa persona**.
  Enviador get enviador;

  /// Termina: con [quedanPendientes] guarda la credencial renovada para la
  /// próxima ronda; sin ellos, la sella y borra la copia en claro.
  Future<void> cerrar({required bool quedanPendientes});
}

/// Bandeja de salida sin PIN (D14, 23/oct/2026): sube lo registrado por una
/// persona que ya salió de la tablet, con su propio token, sin pedir su PIN.
abstract interface class SalidaSinPin {
  /// Borra los permisos caducados y dice a quiénes se les puede subir.
  /// [hayPendientes] dice si la persona tiene algo por subir.
  Future<PreparacionSalida> preparar(
    Future<bool> Function(String personaId) hayPendientes,
  );

  /// Abre la sesión de [personaId] para subir; `null` si ahora no se puede
  /// (sin señal). Lanza [ErrorSesion] si su sesión ya no sirve (vencida o dada
  /// de baja).
  Future<SesionDeSubida?> abrir(String personaId);

  /// Borra el permiso de [personaId] (su sesión ya no sirve).
  Future<void> descartar(String personaId);
}

/// Lo que dejaron sin subir las personas quitadas de la tablet y se borrará.
class PurgaProgramada {
  const PurgaProgramada({required this.cuantos, this.primeraEl});

  final int cuantos;

  /// Cuándo se borra el primero (los demás, ese día o después).
  final DateTime? primeraEl;
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
    this.salida,
    this.tiempoMaximoDeEnvio = const Duration(seconds: 30),
    this.conservarQuitados = conservarLoDeQuitados,
    this.conservarEnviados = conservarLoEnviado,
    this.conservarDescartados = conservarLoDescartado,
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

  /// Bandeja de salida sin PIN: sube lo de las personas que ya salieron de la
  /// tablet con su propio token. `null`: sin ella (lo de cada persona espera a
  /// que vuelva a entrar con su PIN).
  final SalidaSinPin? salida;

  /// Cuánto se espera la respuesta de **un** envío. Pasado el tiempo se toma
  /// como falta de respuesta (se reintenta): un servidor que no contesta no
  /// puede dejar la ronda, y con ella la bandeja de salida, esperando para
  /// siempre (B3 de la revisión de la Fase 1b).
  final Duration tiempoMaximoDeEnvio;

  /// Cuánto se conserva lo que dejó sin subir una persona quitada de la tablet
  /// antes de borrarlo ([purgarLoDeQuitados]).
  final Duration conservarQuitados;

  /// Cuánto se conserva lo ya enviado y lo descartado antes de borrarlo de la
  /// base local ([purgarEnviadosYDescartados]).
  final Duration conservarEnviados;
  final Duration conservarDescartados;

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
  /// tablet de la casa (entonces [personaId] es obligatorio y el [tipo] no
  /// puede ser personal: lanza [ArgumentError], ver [esTipoPersonal]).
  Future<String> encolar({
    required String tipo,
    required Map<String, Object?> carga,
    String? id,
    String? personaId,
    OrigenRegistro origen = OrigenRegistro.propio,
  }) async {
    if (origen == OrigenRegistro.tabletCasa) {
      if (personaId == null) throw ArgumentError.notNull('personaId');
      // D14: solo lo de la casa (lista de compras, recordatorios genéricos)
      // se registra con el nombre y sin PIN. El dinero, los hábitos y lo de
      // Cuidados piden nombre y PIN (M3, revisión de la Fase 1).
      if (esTipoPersonal(tipo)) {
        throw ArgumentError.value(
          tipo,
          'tipo',
          'Lo personal (dinero, hábitos, Cuidados) pide nombre y PIN: no se '
              'registra desde la tablet de la casa solo con el nombre (D14).',
        );
      }
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

  /// Envía los pendientes cuya espera ya pasó: primero los de nivel de subida
  /// menor y, dentro de un nivel, en orden de creación. Si un envío falla por
  /// red, se programa su reintento y se detiene la ronda; si solo falta una
  /// dependencia (23503), se programa su reintento y la ronda sigue. Si ya hay
  /// una ronda en curso, devuelve esa misma (nunca envía en paralelo).
  Future<ResumenProceso> procesar() =>
      _enCurso ??= _procesar().whenComplete(() => _enCurso = null);

  Future<ResumenProceso> _procesar() async {
    final ahora = _reloj();
    // Lo de personas quitadas, lo enviado y lo descartado cuyo plazo venció se
    // borra de la base local (L1), haya o no sesión.
    await purgarLoDeQuitados();
    await purgarEnviadosYDescartados();
    // Sin sesión no se envía nada; con sesión, solo lo de esa persona.
    final conSesion = personaConSesion;
    final persona = conSesion?.call();
    if (conSesion != null && persona == null) {
      // Nada se envía, pero la caducidad de los permisos de subida corre
      // igual: una credencial sin el PIN no puede quedarse en el equipo más de
      // sus 7 días porque nadie tenga la sesión abierta (B1 de la revisión de
      // la Fase 1b).
      var rechazados = 0;
      final bandeja = salida;
      if (bandeja != null) {
        rechazados = (await _caducarBandeja(bandeja)).rechazados;
        if (rechazados > 0) _avisar();
      }
      return ResumenProceso(
        enviados: 0,
        reintentos: 0,
        rechazados: rechazados,
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

    var conteo = await _enviarLote(_ordenados(listos), _enviador, ahora);

    // Bandeja de salida: lo de las personas que ya salieron de la tablet sube
    // con su propio token, sin pedir su PIN.
    final bandeja = salida;
    if (bandeja != null && (conSesion == null || persona != null)) {
      conteo += await _subirBandeja(bandeja, persona, ahora);
    }
    final (enviados, reintentos, rechazados) = (
      conteo.enviados,
      conteo.reintentos,
      conteo.rechazados,
    );

    if (enviados + reintentos + rechazados > 0) _avisar();
    return ResumenProceso(
      enviados: enviados,
      reintentos: reintentos,
      rechazados: rechazados,
      restantes: await contarPendientes(),
    );
  }

  /// Orden de subida: primero los de nivel menor, y dentro de un nivel, el
  /// orden en que se crearon (el de la consulta).
  List<RegistroPendiente> _ordenados(List<RegistroPendiente> listos) {
    final nivelDe = nivelDeSubida ?? _nivelDelEnviador;
    final posicion = {for (var i = 0; i < listos.length; i++) listos[i].id: i};
    final niveles = {for (final r in listos) r.id: nivelDe(r.tipo)};
    return [...listos]..sort((a, b) {
      final porNivel = niveles[a.id]!.compareTo(niveles[b.id]!);
      return porNivel != 0
          ? porNivel
          : posicion[a.id]!.compareTo(posicion[b.id]!);
    });
  }

  /// Lo de [personaId] (registrado con su sesión) que ya se puede intentar.
  Future<List<RegistroPendiente>> _listosDePersona(
    String personaId,
    DateTime ahora,
  ) async => _ordenados(
    await (_base.select(_tabla)
          ..where(
            (t) =>
                t.estado.equalsValue(EstadoPendiente.pendiente) &
                (t.siguienteIntento.isNull() |
                    t.siguienteIntento.isSmallerOrEqualValue(ahora)) &
                (t.origen.isNull() |
                    t.origen.equalsValue(OrigenRegistro.tabletCasa).not()) &
                t.personaId.equals(personaId),
          )
          ..orderBy([
            (t) => OrderingTerm.asc(t.creadoEn),
            (t) => OrderingTerm.asc(t.rowId),
          ]))
        .get(),
  );

  /// Cuántos registros de [personaId] (con su sesión) faltan por subir.
  Future<int> contarPendientesDe(String personaId) {
    final cuenta = _tabla.id.count();
    return (_base.selectOnly(_tabla)
          ..addColumns([cuenta])
          ..where(
            _tabla.estado.equalsValue(EstadoPendiente.pendiente) &
                (_tabla.origen.isNull() |
                    _tabla.origen
                        .equalsValue(OrigenRegistro.tabletCasa)
                        .not()) &
                _tabla.personaId.equals(personaId),
          ))
        .map((fila) => fila.read(cuenta) ?? 0)
        .getSingle();
  }

  /// Cuántos registros (de cualquier persona) pasaron a "requiere atención"
  /// porque la bandeja de salida caducó. Es un número: nadie ve de quién es
  /// ni qué dice (D5).
  Future<int> contarCaducadosDeLaBandeja() {
    final cuenta = _tabla.id.count();
    return (_base.selectOnly(_tabla)
          ..addColumns([cuenta])
          ..where(
            _tabla.estado.equalsValue(EstadoPendiente.rechazado) &
                _tabla.ultimoError.equals(motivoBandejaCaducada),
          ))
        .map((fila) => fila.read(cuenta) ?? 0)
        .getSingle();
  }

  /// Lo mismo, en vivo.
  Stream<int> vigilarCaducadosDeLaBandeja() =>
      _vigilar(contarCaducadosDeLaBandeja);

  /// `true` si [personaId] tiene algo por subir.
  Future<bool> hayPendientesDe(String personaId) async =>
      await contarPendientesDe(personaId) > 0;

  /// Pasa lo pendiente de [personaId] a "requiere atención" con [motivo] (p.
  /// ej. la bandeja caducó). No se pierde: la persona lo ve en "Por revisar".
  /// Devuelve cuántos fueron.
  ///
  /// Si [motivo] es [motivoPersonaQuitada], el registro se borra de la base
  /// local a los [conservarQuitados] (la fecha queda en `siguienteIntento`,
  /// que un registro rechazado no usa para nada más): L1 de la revisión de la
  /// Fase 1b.
  Future<int> rechazarPendientesDe(String personaId, String motivo) async {
    final borrarEl = motivo == motivoPersonaQuitada
        ? _reloj().add(conservarQuitados)
        : null;
    final cuantos =
        await (_base.update(_tabla)..where(
              (t) =>
                  t.estado.equalsValue(EstadoPendiente.pendiente) &
                  (t.origen.isNull() |
                      t.origen.equalsValue(OrigenRegistro.tabletCasa).not()) &
                  t.personaId.equals(personaId),
            ))
            .write(
              PendientesCompanion(
                estado: const Value(EstadoPendiente.rechazado),
                siguienteIntento: Value(borrarEl),
                ultimoError: Value(motivo),
              ),
            );
    if (cuantos > 0) _avisar();
    return cuantos;
  }

  SimpleSelectStatement<$PendientesTable, RegistroPendiente> _deQuitados() =>
      _base.select(_tabla)..where(
        (t) =>
            t.estado.equalsValue(EstadoPendiente.rechazado) &
            t.ultimoError.equals(motivoPersonaQuitada),
      );

  /// Borra de la base local lo que dejó sin subir una persona quitada de la
  /// tablet y ya cumplió su plazo ([conservarQuitados]). Corre sola en cada
  /// ronda ([procesar]), también sin sesión abierta. Devuelve cuántos borró.
  Future<int> purgarLoDeQuitados() async {
    final ahora = _reloj();
    final borrados =
        await (_base.delete(_tabla)..where(
              (t) =>
                  t.estado.equalsValue(EstadoPendiente.rechazado) &
                  t.ultimoError.equals(motivoPersonaQuitada) &
                  t.siguienteIntento.isSmallerOrEqualValue(ahora),
            ))
            .go();
    if (borrados > 0) _avisar();
    return borrados;
  }

  /// Borra de la base local lo **enviado** hace más de [conservarEnviados] y lo
  /// **descartado** hace más de [conservarDescartados]: ya no hacen falta y
  /// llevan el monto y el concepto en claro. Corre sola en cada ronda
  /// ([procesar]). Devuelve cuántos borró.
  ///
  /// Un descartado guarda en `siguienteIntento` el día en que se borra (como lo
  /// de los quitados); los que se descartaron antes de este cambio no lo tienen
  /// y cuentan desde su creación, así que no hace falta migrar nada.
  Future<int> purgarEnviadosYDescartados() async {
    final ahora = _reloj();
    final enviados = await limpiarEnviados(antiguedad: conservarEnviados);
    final descartados =
        await (_base.delete(_tabla)..where(
              (t) =>
                  t.estado.equalsValue(EstadoPendiente.descartado) &
                  (t.siguienteIntento.isSmallerOrEqualValue(ahora) |
                      (t.siguienteIntento.isNull() &
                          t.creadoEn.isSmallerThanValue(
                            ahora.subtract(conservarDescartados),
                          ))),
            ))
            .go();
    return enviados + descartados;
  }

  /// Lo de personas quitadas que espera su borrado: cuántos son y cuándo se
  /// borra el primero. Solo números y una fecha (nadie ve montos ni de quién).
  Future<PurgaProgramada?> purgaProgramada() async {
    final filas = await _deQuitados().get();
    if (filas.isEmpty) return null;
    DateTime? primera;
    for (final fila in filas) {
      final cuando = fila.siguienteIntento;
      if (cuando != null && (primera == null || cuando.isBefore(primera))) {
        primera = cuando;
      }
    }
    return PurgaProgramada(cuantos: filas.length, primeraEl: primera);
  }

  /// Lo mismo, en vivo (para el aviso en Ajustes › Personas).
  Stream<PurgaProgramada?> vigilarPurga() => _vigilar(purgaProgramada);

  /// Borra los permisos caducados (y sella los que ya no tienen nada por
  /// subir) sin enviar nada.
  Future<_Conteo> _caducarBandeja(SalidaSinPin bandeja) async {
    final preparacion = await bandeja.preparar(hayPendientesDe);
    return _rechazarCaducadas(preparacion.caducadas);
  }

  /// Lo pendiente de quien perdió su permiso por caducidad pasa a "requiere
  /// atención".
  Future<_Conteo> _rechazarCaducadas(List<String> caducadas) async {
    var total = const _Conteo(0, 0, 0);
    for (final caducada in caducadas) {
      final cuantos = await rechazarPendientesDe(
        caducada,
        motivoBandejaCaducada,
      );
      total += _Conteo(0, 0, cuantos);
    }
    return total;
  }

  /// Sube la bandeja de salida: lo de cada persona con permiso que no es la
  /// que tiene la sesión ahora, con su propio token.
  Future<_Conteo> _subirBandeja(
    SalidaSinPin bandeja,
    String? persona,
    DateTime ahora,
  ) async {
    final preparacion = await bandeja.preparar(hayPendientesDe);
    var total = await _rechazarCaducadas(preparacion.caducadas);
    for (final personaId in preparacion.conPermiso) {
      // Quien está dentro sube con su propia sesión (ronda de arriba).
      if (personaId == persona) continue;
      final listos = await _listosDePersona(personaId, ahora);
      if (listos.isEmpty) continue;
      SesionDeSubida? sesion;
      try {
        sesion = await bandeja.abrir(personaId);
      } on ErrorSesion {
        // Su sesión ya no sirve (vencida o dada de baja): no subirá sola. Lo
        // pendiente pasa a "requiere atención"; con su PIN lo revisa.
        final cuantos = await rechazarPendientesDe(
          personaId,
          motivoSesionInservible,
        );
        await bandeja.descartar(personaId);
        total += _Conteo(0, 0, cuantos);
        continue;
      } catch (_) {
        continue; // Algo inesperado: se intenta en la siguiente ronda.
      }
      if (sesion == null) continue; // Sin señal.
      try {
        total += await _enviarLote(listos, sesion.enviador, ahora);
      } finally {
        await sesion.cerrar(quedanPendientes: await hayPendientesDe(personaId));
      }
    }
    return total;
  }

  /// Envía [listos] (ya ordenados) con [enviador] y anota cada resultado.
  Future<_Conteo> _enviarLote(
    List<RegistroPendiente> listos,
    Enviador enviador,
    DateTime ahora,
  ) async {
    var enviados = 0;
    var reintentos = 0;
    var rechazados = 0;
    for (final registro in listos) {
      final intento = registro.intentos + 1;
      ResultadoEnvio resultado;
      String? error;
      var faltaDependencia = false;
      try {
        resultado = await enviador
            .enviar(
              PeticionEnvio(
                id: registro.id,
                tipo: registro.tipo,
                carga: (jsonDecode(registro.carga) as Map)
                    .cast<String, Object?>(),
                creadoEn: registro.creadoEn,
                intento: intento,
                personaId: registro.personaId,
                origen: registro.origen ?? OrigenRegistro.propio,
              ),
            )
            .timeout(tiempoMaximoDeEnvio);
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
        error =
            'Falló $intento veces: ${error ?? 'sin respuesta clara del servidor'}';
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

    return _Conteo(enviados, reintentos, rechazados);
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
    () =>
        requierenAtencion(personaId: personaId, deLaTabletCasa: deLaTabletCasa),
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

  /// La persona decide no subir un registro que requería atención. Se conserva
  /// [conservarDescartados] y luego se borra de la base local.
  Future<void> descartar(String id) => _cambiarAtencion(
    id,
    PendientesCompanion(
      estado: const Value(EstadoPendiente.descartado),
      siguienteIntento: Value(_reloj().add(conservarDescartados)),
    ),
  );

  Future<void> _cambiarAtencion(String id, PendientesCompanion cambio) async {
    await (_base.update(_tabla)..where(
          (t) =>
              t.id.equals(id) & t.estado.equalsValue(EstadoPendiente.rechazado),
        ))
        .write(cambio);
    _avisar();
  }

  /// Todos los registros de la cola (para revisar y para pruebas).
  Future<List<RegistroPendiente>> registros() =>
      (_base.select(_tabla)..orderBy([
            (t) => OrderingTerm.asc(t.creadoEn),
            (t) => OrderingTerm.asc(t.rowId),
          ]))
          .get();

  /// Borra los enviados con más de [antiguedad].
  Future<int> limpiarEnviados({Duration antiguedad = const Duration(days: 7)}) {
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

/// Lo que pasó en un lote de envíos.
class _Conteo {
  const _Conteo(this.enviados, this.reintentos, this.rechazados);

  final int enviados;
  final int reintentos;
  final int rechazados;

  _Conteo operator +(_Conteo otro) => _Conteo(
    enviados + otro.enviados,
    reintentos + otro.reintentos,
    rechazados + otro.rechazados,
  );
}
