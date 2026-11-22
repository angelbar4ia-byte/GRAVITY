/// Órdenes de cerrar en el servidor la sesión de un permiso de subida que ya no
/// existe (B4 de la revisión de la Fase 1b, `docs/revisiones/fase-1b.md`).
///
/// ## El problema
///
/// Un permiso de subida de la bandeja de salida (`bandeja_salida.dart`) guarda
/// la sesión de la persona **sin su PIN** hasta 7 días. Al caducar o
/// descartarse, la app borra su copia local, pero la sesión sigue viva en el
/// servidor: el refresh token de Supabase no caduca por tiempo en el plan
/// gratis. Quien se hubiera llevado una copia en esos días la conservaría para
/// siempre.
///
/// ## La corrección
///
/// Con señal, la app abre esa sesión una última vez y la **cierra en el
/// servidor** (`POST /auth/v1/logout`, alcance local: solo esa sesión, sin tocar
/// la del equipo, la de quien esté dentro ni las otras de la misma persona;
/// `SesionesPorPersona.revocarSesion`).
///
/// Caducar **no espera a la red**: sin señal el permiso se borra igual y queda
/// una **orden de revocar**, que se reintenta en cada ronda de la cola hasta
/// que el servidor confirme.
///
/// ## Qué se guarda y por cuánto tiempo
///
/// La orden **no depende del permiso** que se acaba de borrar: es su propio
/// registro en el almacenamiento seguro del dispositivo (la misma protección
/// que tenía la credencial). Guarda **lo mínimo para revocar**:
///
/// - el refresh token (nada del token de acceso ni de los datos del usuario:
///   [credencialMinima]),
/// - el id de la persona (no es secreto) y la fecha en que se anotó.
///
/// Se **borra** en cuanto el servidor confirma que la sesión se cerró **o que
/// ya no la conocía** (credencial vencida, ya usada, sesión ya cerrada: no hay
/// nada que revocar). Si la red no vuelve en [plazoParaRevocar] (30 días) se
/// abandona y se borra igual: no se deja un secreto en el equipo para siempre
/// (queda el riesgo de siempre, acotado a ese caso: la sesión solo se cierra
/// cambiando la contraseña o cerrándola desde otro dispositivo). Nunca se
/// imprime ni se registra el contenido de una orden.
library;

import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../seguridad/almacen_seguro.dart';
import '../sesion/sesion.dart' show ResultadoRevocacion;

/// Cuánto se insiste en revocar una sesión sin lograrlo, desde que se anotó la
/// orden. Pasado ese plazo la orden se borra con su credencial.
const plazoParaRevocar = Duration(days: 30);

/// Tiempo máximo de cada intento de revocar: una red que no contesta no debe
/// atorar la ronda de la cola (B3).
const tiempoMaximoDeRevocar = Duration(seconds: 10);

/// Cuánto se espera, tras un intento sin respuesta, para volver a intentar: con
/// la red caída cada intento puede tardar hasta [tiempoMaximoDeRevocar] y la
/// cola corre seguido.
const esperaEntreIntentosDeRevocar = Duration(minutes: 1);

/// Cómo se cierra una sesión en el servidor (`SesionesPorPersona.revocarSesion`).
typedef RevocadorDeSesion = Future<ResultadoRevocacion> Function(
  String credencial, {
  required void Function(String credencial) alRenovar,
});

/// De una credencial guardada deja **solo lo necesario para revocar**: el
/// refresh token. Una sesión de Supabase (JSON con `refresh_token`) pierde el
/// token de acceso y los datos del usuario; cualquier otra cosa (las
/// credenciales de las pruebas) se deja igual.
String credencialMinima(String credencial) {
  try {
    final json = jsonDecode(credencial);
    if (json is Map && json['refresh_token'] is String) {
      return jsonEncode({'refresh_token': json['refresh_token']});
    }
  } catch (_) {
    // No es una sesión de Supabase: se deja como está.
  }
  return credencial;
}

/// Una sesión del servidor que hay que cerrar.
@immutable
class OrdenDeRevocar {
  const OrdenDeRevocar({
    required this.id,
    required this.personaId,
    required this.credencial,
    required this.creadoEn,
  });

  /// Identifica la orden en el almacén (huella corta de la credencial con la que
  /// se anotó; no cambia aunque la credencial se renueve).
  final String id;
  final String personaId;

  /// La credencial **mínima** ([credencialMinima]). Es un secreto.
  final String credencial;
  final DateTime creadoEn;

  bool vencidaEn(DateTime ahora, Duration plazo) =>
      !ahora.isBefore(creadoEn.add(plazo));

  OrdenDeRevocar conCredencial(String nueva) => OrdenDeRevocar(
    id: id,
    personaId: personaId,
    credencial: nueva,
    creadoEn: creadoEn,
  );

  Map<String, Object?> aJson() => {
    'id': id,
    'persona_id': personaId,
    'credencial': credencial,
    'creado_en': creadoEn.toUtc().toIso8601String(),
  };

  static OrdenDeRevocar? desdeJson(Map<String, Object?> json) {
    try {
      return OrdenDeRevocar(
        id: json['id']! as String,
        personaId: json['persona_id']! as String,
        credencial: json['credencial']! as String,
        creadoEn: DateTime.parse(json['creado_en']! as String),
      );
    } catch (_) {
      return null;
    }
  }

  // Nunca se imprime la credencial.
  @override
  String toString() => 'OrdenDeRevocar($id)';
}

/// Qué pasó en una vuelta de [RevocacionesPendientes.ejecutar].
@immutable
class ResumenRevocacion {
  const ResumenRevocacion({
    this.cerradas = 0,
    this.pendientes = 0,
    this.abandonadas = 0,
  });

  /// Sesiones que el servidor cerró (o que ya no existían): la orden se borró.
  final int cerradas;

  /// Órdenes que siguen esperando (sin señal o servidor ocupado).
  final int pendientes;

  /// Órdenes que pasaron [plazoParaRevocar] sin lograrse y se borraron.
  final int abandonadas;
}

/// Las órdenes de revocar, en el almacenamiento seguro del dispositivo.
class RevocacionesPendientes {
  RevocacionesPendientes(
    this._almacen, {
    DateTime Function()? reloj,
    this.plazo = plazoParaRevocar,
    this.espera = esperaEntreIntentosDeRevocar,
  }) : _reloj = reloj ?? DateTime.now;

  static const prefijo = 'bandeja.revocar.';

  final AlmacenSeguro _almacen;
  final DateTime Function() _reloj;
  final Duration plazo;
  final Duration espera;

  /// Hasta cuándo no se vuelve a intentar tras un intento sin respuesta (solo
  /// en memoria: al reiniciar la app se intenta de inmediato).
  DateTime? _noAntesDe;

  static String _huella(String credencial) =>
      sha256.convert(utf8.encode(credencial)).toString().substring(0, 16);

  static String _clave(String personaId, String id) => '$prefijo$personaId.$id';

  String _claveDe(OrdenDeRevocar orden) => _clave(orden.personaId, orden.id);

  /// Anota que hay que cerrar en el servidor la sesión de [credencial]. Si ya
  /// hay una orden para esa misma sesión, no hace nada (idempotente).
  ///
  /// Guarda solo lo mínimo ([credencialMinima]).
  Future<void> anotar(String personaId, String credencial) async {
    final minima = credencialMinima(credencial);
    final id = _huella(minima);
    final clave = _clave(personaId, id);
    // Una orden nueva merece intentarse en la siguiente ronda.
    _noAntesDe = null;
    if (await _almacen.leer(clave) != null) return;
    await _almacen.escribir(
      clave,
      jsonEncode(
        OrdenDeRevocar(
          id: id,
          personaId: personaId,
          credencial: minima,
          creadoEn: _reloj(),
        ).aJson(),
      ),
    );
  }

  /// Las órdenes que esperan (de cualquier persona). Una orden dañada se borra:
  /// no sirve y no hay por qué dejar su contenido.
  Future<List<OrdenDeRevocar>> todas() async {
    final ordenes = <OrdenDeRevocar>[];
    for (final clave in await _almacen.claves()) {
      if (!clave.startsWith(prefijo)) continue;
      final texto = await _almacen.leer(clave);
      if (texto == null) continue;
      OrdenDeRevocar? orden;
      try {
        orden = OrdenDeRevocar.desdeJson(
          (jsonDecode(texto) as Map).cast<String, Object?>(),
        );
      } catch (_) {
        orden = null;
      }
      if (orden == null || _claveDe(orden) != clave) {
        await _almacen.borrar(clave);
        continue;
      }
      ordenes.add(orden);
    }
    return ordenes;
  }

  Future<void> _borrar(OrdenDeRevocar orden) =>
      _almacen.borrar(_claveDe(orden));

  /// Guarda la credencial renovada de la orden (el servidor rota el refresh
  /// token): solo si la orden sigue ahí, para no resucitar una ya cumplida.
  Future<void> _renovar(OrdenDeRevocar orden, String credencial) async {
    final clave = _claveDe(orden);
    if (await _almacen.leer(clave) == null) return;
    await _almacen.escribir(
      clave,
      jsonEncode(orden.conCredencial(credencialMinima(credencial)).aJson()),
    );
  }

  Future<ResumenRevocacion>? _enCurso;

  /// Intenta cumplir todas las órdenes con [revocar]. Una a la vez, cada una con
  /// tiempo máximo ([tiempoMaximo]); si una falla por falta de red o de
  /// respuesta, las demás esperan a la siguiente ronda (fallarían igual).
  /// Nunca lanza por un fallo de red.
  ///
  /// Si ya hay una vuelta en curso devuelve esa misma.
  Future<ResumenRevocacion> ejecutar(
    RevocadorDeSesion revocar, {
    Duration tiempoMaximo = tiempoMaximoDeRevocar,
  }) => _enCurso ??= _ejecutar(
    revocar,
    tiempoMaximo,
  ).whenComplete(() => _enCurso = null);

  Future<ResumenRevocacion> _ejecutar(
    RevocadorDeSesion revocar,
    Duration tiempoMaximo,
  ) async {
    var cerradas = 0;
    var abandonadas = 0;
    var pendientes = 0;
    var sinRed = false;
    var fallo = false;
    final hastaCuando = _noAntesDe;
    if (hastaCuando != null && _reloj().isBefore(hastaCuando)) {
      // Hace poco no hubo respuesta: no se vuelve a esperar a la red todavía.
      // (Las vencidas se revisan igual, abajo.)
      sinRed = true;
    }
    for (final orden in await todas()) {
      if (orden.vencidaEn(_reloj(), plazo)) {
        // No se guarda un secreto para siempre.
        await _borrar(orden);
        abandonadas++;
        debugPrint(
          'Revocar sesión: se abandonó una orden tras ${plazo.inDays} días '
          'sin lograrse.',
        );
        continue;
      }
      if (sinRed) {
        pendientes++;
        continue;
      }
      var terminado = false;
      var guardando = Future<void>.value();
      void alRenovar(String nueva) {
        // Lo que llegue después de terminar el intento (p. ej. tras el tiempo
        // máximo) se ignora: no debe resucitar una orden ya cumplida.
        if (terminado) return;
        guardando = guardando.then((_) => _renovar(orden, nueva));
      }

      var resultado = ResultadoRevocacion.reintentar;
      try {
        resultado = await revocar(
          orden.credencial,
          alRenovar: alRenovar,
        ).timeout(tiempoMaximo);
      } catch (error) {
        // Solo el tipo: un error podría llevar la petición con el token.
        debugPrint('Revocar sesión: sin respuesta (${error.runtimeType}).');
      }
      terminado = true;
      try {
        await guardando;
      } catch (_) {
        // Si no se pudo guardar la renovación, se sigue con la anterior.
      }
      if (resultado == ResultadoRevocacion.cerrada) {
        await _borrar(orden);
        cerradas++;
      } else {
        pendientes++;
        sinRed = true;
        fallo = true;
      }
    }
    if (fallo) {
      _noAntesDe = _reloj().add(espera);
    } else if (pendientes == 0) {
      _noAntesDe = null;
    }
    return ResumenRevocacion(
      cerradas: cerradas,
      pendientes: pendientes,
      abandonadas: abandonadas,
    );
  }
}
