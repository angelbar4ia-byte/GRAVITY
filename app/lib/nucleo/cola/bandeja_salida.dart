/// Bandeja de salida sin PIN (D14, decisión del dueño del 23/oct/2026).
///
/// Un gasto registrado en la tablet pública con **nombre y PIN** y **sin
/// señal** queda en la bandeja de salida y **se sube solo cuando hay señal**,
/// sin pedir el PIN otra vez. Sube con la sesión de **esa persona** (el
/// servidor la identifica y la bitácora queda bien); nunca con la cuenta Casa.
///
/// ## Cómo funciona
///
/// La credencial de cada persona en la tablet (su sesión del servidor) vive
/// **cifrada con su PIN** (`cifrado.dart`). Para subir sin el PIN hace falta
/// otra copia que la app pueda usar sola. Pero un refresh token **rota** al
/// usarse: dos copias de la misma credencial se estorban (la vieja deja de
/// servir y reusarla puede revocar toda la sesión). Por eso la credencial se
/// **mueve**, no se copia:
///
/// 1. Al **salir** la persona con algo por subir, su credencial pasa del
///    sobre del PIN al **permiso de subida** ([PermisoDeSubida]), guardado en
///    el almacenamiento seguro del dispositivo (Keystore/DPAPI: la llave es la
///    del dispositivo, no el PIN). El sobre del PIN se borra. Junto con el
///    permiso queda un par de llaves nuevo: la pública, en claro; la privada,
///    **cifrada con el PIN** (la app tiene el PIN en memoria solo en ese
///    momento).
/// 2. Cuando hay señal, [SalidaSinPinConSesiones] abre una **sesión aparte** de
///    la persona (sin tocar la de la tablet ni la de quien esté dentro), sube
///    sus pendientes y guarda **de inmediato** cada credencial renovada.
/// 3. Al subir la **última** entrada, la credencial se **sella** con la llave
///    pública ([SobreSellado]) y el texto en claro se borra: lo que queda solo
///    lo abre la llave privada, o sea, el PIN de la persona. Cuando la persona
///    vuelve a entrar con su PIN, el sobre se abre, la credencial vuelve al
///    sobre del PIN y el permiso se borra ([BandejaDeSalida.tomarParaEntrada]).
/// 4. El permiso **caduca a los 7 días** de haberse creado: la credencial en
///    claro se borra, lo pendiente pasa a "requiere atención" con aviso y la
///    persona tendrá que volver a agregarse a la tablet con su correo y su
///    contraseña.
///
/// Un candado por persona ([BandejaDeSalida.adquirir]) evita que la subida sin
/// PIN y la entrada con PIN usen la credencial a la vez.
///
/// ## Riesgos (ver también el informe de plataforma)
///
/// - **Mientras hay algo por subir** (hasta 7 días), la credencial de la
///   persona está en el almacenamiento seguro del dispositivo **sin el PIN**.
///   Quien extraiga ese almacenamiento (equipo con root) podría actuar como esa
///   persona hasta que la sesión caduque o se revoque. Es lo que el dueño
///   aceptó; por eso solo existe mientras hay algo por subir y caduca.
/// - Una sesión de Supabase da **todo** lo que la persona puede, no solo
///   "subir su bandeja" (ver "Qué haría falta del servidor", abajo).
/// - Si la app se cierra justo después de que el servidor renovó el refresh
///   token y antes de guardarlo, la credencial guardada queda vieja y la persona
///   tendrá que volver a agregarse. Se guarda en cuanto llega la renovación
///   para reducirlo al mínimo.
///
/// ## Corregido en la revisión de la Fase 1b (`docs/revisiones/fase-1b.md`)
///
/// - **B1** La caducidad corre también sin sesión abierta (`_procesar` de la
///   cola), y al cerrar la cuenta del equipo (Hogar) los permisos que tienen la
///   credencial en claro se **sellan** ([BandejaDeSalida.sellarTodos], desde
///   `LimpiezaLocal.alCerrarElEquipo`): solo el PIN de cada persona las abre y
///   lo que tenían por subir espera a que vuelvan a entrar (no pasa a "requiere
///   atención": no se perdió nada).
/// - **B2** Solo un error claro del servidor (4xx salvo 408 y 429) da la
///   credencial por vencida; el límite de peticiones (429), un 5xx, la falta de
///   red o algo inesperado se reintentan sin tocar el permiso
///   (`credencialYaNoSirve`, `ErrorSesion.servidorOcupado`).
/// - **B3** Un envío tiene tiempo máximo (`tiempoMaximoDeEnvio`, 30 s) y quien
///   entra con su PIN, cambia su PIN, es quitado o vuelve a agregarse pide el
///   candado con `urgente`: la subida en curso **cede el turno** sin esperar al
///   servidor ([BandejaDeSalida.turnoPedido]); lo que no alcanzó a subir sigue
///   pendiente, sin gastar un intento.
/// - **B5** Volver a agregar a una persona borra su permiso viejo
///   ([BandejaDeSalida.descartarPermiso]): su credencial es de otra cadena de
///   renovación y no debe pisar la nueva. Lo que tenía por subir se conserva.
///
/// ## Pendiente: B4, cerrar la sesión en el servidor al caducar o descartar
///
/// Caducar un permiso (a los 7 días), descartarlo o quitar a la persona borra la
/// copia local de su credencial, pero **no cierra la sesión en el servidor**: el
/// refresh token de Supabase no caduca por tiempo en el plan gratis, así que una
/// copia sacada del equipo antes sigue sirviendo hasta que alguien cierre la
/// sesión o cambie la contraseña. "7 días" es, por ahora, un plazo de la
/// tablet, no del servidor. Se deja para la bandeja acotada (abajo), que lo
/// resuelve de raíz con un permiso que vence y se revoca en el servidor. Si
/// antes se quisiera una mitigación solo de la app, haría falta, con señal, abrir
/// una sesión aparte con la credencial justo antes de borrarla y llamar a
/// `auth.signOut()` (revoca esa sesión en el servidor); sin señal no hay cómo, y
/// la caducidad usa el reloj del dispositivo (atrasarlo la alarga). Prueba
/// pendiente: `f1b_bandeja_hallazgos_test.dart`, "al caducar el permiso se
/// revoca también la sesión en el servidor" (sigue con la etiqueta `hallazgo`).
///
/// ## Qué haría falta del servidor para un permiso de subida acotado
///
/// El dueño aceptó probar la bandeja tal como está (23/oct/2026). Si la
/// revisión de calidad pidiera acotarla, esto es lo que tendría que dar
/// backend; **nada de esto existe hoy** y la app actual no lo necesita:
///
/// 1. **Un permiso de subida por persona**, no una sesión. Una función
///    `emitir_permiso_subida()` que la persona llama con su sesión (cuando sale
///    de la tablet con algo por subir) y que devuelve un secreto de un solo
///    propósito: ligado a la persona y al dispositivo, de 7 días como máximo,
///    revocable y guardado en el servidor solo como hash.
/// 2. **Una función de subida** `subir_pendientes(permiso, registros)` (RPC
///    `security definer` o Edge Function) que valide el permiso y acepte
///    **solo** los tipos que se registran sin conexión (las tablas de
///    `contrato_servidor.dart`), **solo** `insert` idempotente
///    (`on conflict (id) do nothing`, como la cola de hoy) y con las **mismas
///    reglas de RLS** de esa persona (ejecutando como su `auth.uid()`, nunca
///    con permisos de servicio sin revisar). Cualquier otra operación (leer,
///    actualizar, borrar, otras tablas) se rechaza.
/// 3. **Sin refresh token que rote.** El permiso no se renueva al usarse, así
///    desaparecen el riesgo de perder la cadena y el candado/ordenamiento que
///    hoy exige la rotación; quien lo extraiga solo puede **insertar** lo que
///    la persona ya podía registrar, no leer ni cambiar nada.
/// 4. **Baja inmediata** (D5): `revocar_permiso_subida(persona)` al quitarla de
///    la tablet, al darla de baja o al cambiarle el rol, y que la bitácora
///    diga "subido desde la tablet con permiso de subida".
/// 5. **Un tope** de registros por lote y por día para que un permiso robado
///    no pueda llenar la base.
///
/// En la app el cambio queda dentro de [SalidaSinPinConSesiones] y
/// `EnviadorSupabase`: [PermisoDeSubida] guardaría el permiso en vez de la
/// credencial y desaparecería la [SesionAparte].
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../seguridad/almacen_seguro.dart';
import '../seguridad/cifrado.dart';
import '../seguridad/sobre_sellado.dart';
import '../sesion/sesion.dart' show ErrorSesion, SesionAparte;
import 'cola_sin_conexion.dart';

/// Cuánto dura un permiso de subida, desde que se crea.
const vigenciaDelPermisoDeSubida = Duration(days: 7);

/// En qué momento está el permiso de una persona.
enum EstadoPermiso {
  /// Hay algo por subir: la credencial está en claro (cifrada solo por el
  /// almacenamiento seguro del dispositivo) para poder subirlo sin el PIN.
  enEspera,

  /// Ya se subió todo: la credencial está **sellada**; solo el PIN la abre, la
  /// próxima vez que la persona entre.
  devuelto,
}

/// El permiso de una persona para subir su bandeja sin pedir el PIN.
@immutable
class PermisoDeSubida {
  const PermisoDeSubida({
    required this.personaId,
    required this.estado,
    required this.clavePublica,
    required this.clavePrivadaCifrada,
    required this.creadoEn,
    required this.vence,
    this.credencial,
    this.sobre,
  });

  final String personaId;
  final EstadoPermiso estado;

  /// Sesión del servidor de la persona, en claro (solo [EstadoPermiso.enEspera]).
  final String? credencial;

  /// La misma, sellada con [clavePublica] (solo [EstadoPermiso.devuelto]).
  final String? sobre;

  /// Para sellar la credencial sin el PIN (base64).
  final String clavePublica;

  /// La llave privada, cifrada con el PIN de la persona (`CifradoPin`).
  final String clavePrivadaCifrada;

  final DateTime creadoEn;

  /// Cuándo caduca la subida sin PIN.
  final DateTime vence;

  bool caducadoEn(DateTime ahora) => !ahora.isBefore(vence);

  PermisoDeSubida copiarCon({
    EstadoPermiso? estado,
    String? credencial,
    String? sobre,
    bool sinCredencial = false,
    bool sinSobre = false,
    String? clavePrivadaCifrada,
  }) => PermisoDeSubida(
    personaId: personaId,
    estado: estado ?? this.estado,
    credencial: sinCredencial ? null : (credencial ?? this.credencial),
    sobre: sinSobre ? null : (sobre ?? this.sobre),
    clavePublica: clavePublica,
    clavePrivadaCifrada: clavePrivadaCifrada ?? this.clavePrivadaCifrada,
    creadoEn: creadoEn,
    vence: vence,
  );

  Map<String, Object?> aJson() => {
    'persona_id': personaId,
    'estado': estado.name,
    'credencial': ?credencial,
    'sobre': ?sobre,
    'clave_publica': clavePublica,
    'clave_privada_cifrada': clavePrivadaCifrada,
    'creado_en': creadoEn.toUtc().toIso8601String(),
    'vence': vence.toUtc().toIso8601String(),
  };

  static PermisoDeSubida? desdeJson(Map<String, Object?> json) {
    try {
      final estado = EstadoPermiso.values.byName(json['estado']! as String);
      final permiso = PermisoDeSubida(
        personaId: json['persona_id']! as String,
        estado: estado,
        credencial: json['credencial'] as String?,
        sobre: json['sobre'] as String?,
        clavePublica: json['clave_publica']! as String,
        clavePrivadaCifrada: json['clave_privada_cifrada']! as String,
        creadoEn: DateTime.parse(json['creado_en']! as String),
        vence: DateTime.parse(json['vence']! as String),
      );
      // Un permiso sin lo que su estado necesita no sirve.
      if (estado == EstadoPermiso.enEspera && permiso.credencial == null) {
        return null;
      }
      if (estado == EstadoPermiso.devuelto && permiso.sobre == null) {
        return null;
      }
      return permiso;
    } catch (_) {
      return null;
    }
  }
}

/// Almacén de los permisos de subida (uno por persona) en el almacenamiento
/// seguro del dispositivo.
class BandejaDeSalida {
  BandejaDeSalida(
    this._almacen, {
    DateTime Function()? reloj,
    this.vigencia = vigenciaDelPermisoDeSubida,
  }) : _reloj = reloj ?? DateTime.now;

  static const prefijo = 'bandeja.permiso.';
  static String clave(String personaId) => '$prefijo$personaId';

  final AlmacenSeguro _almacen;
  final DateTime Function() _reloj;
  final Duration vigencia;

  // ------------------------------------------------------------- candado

  final Map<String, Future<void>> _candados = {};
  final Map<String, int> _urgentes = {};
  final Map<String, Completer<void>> _senales = {};

  /// Toma el candado de [personaId]: quien lo tiene es el único que usa su
  /// credencial. Devuelve cómo soltarlo (una sola vez).
  ///
  /// Con [urgente] (la persona entró con su PIN, cambió su PIN, la quitan o la
  /// vuelven a agregar), si otro tiene el candado se le **pide el turno**
  /// ([turnoPedido]): una subida en curso se interrumpe sin esperar a que el
  /// servidor conteste (B3 de la revisión de la Fase 1b: una subida colgada no
  /// puede dejar a la persona sin poder entrar).
  Future<void Function()> adquirir(
    String personaId, {
    bool urgente = false,
  }) async {
    final ocupado = _candados[personaId] != null;
    final anterior = _candados[personaId] ?? Future<void>.value();
    final libre = Completer<void>();
    final cola = anterior.then((_) => libre.future);
    _candados[personaId] = cola;
    final pide = urgente && ocupado;
    if (pide) {
      _urgentes[personaId] = (_urgentes[personaId] ?? 0) + 1;
      _senales.remove(personaId)?.complete();
    }
    try {
      await anterior;
    } finally {
      if (pide) {
        final quedan = (_urgentes[personaId] ?? 1) - 1;
        quedan <= 0
            ? _urgentes.remove(personaId)
            : _urgentes[personaId] = quedan;
      }
    }
    return () {
      if (!libre.isCompleted) libre.complete();
      if (identical(_candados[personaId], cola)) {
        _candados.remove(personaId);
        _senales.remove(personaId);
      }
    };
  }

  Future<T> conCandado<T>(
    String personaId,
    Future<T> Function() tarea, {
    bool urgente = false,
  }) async {
    final soltar = await adquirir(personaId, urgente: urgente);
    try {
      return await tarea();
    } finally {
      soltar();
    }
  }

  /// `true` si alguien con urgencia espera el candado de [personaId].
  bool turnoPedidoYa(String personaId) => (_urgentes[personaId] ?? 0) > 0;

  /// Termina cuando alguien con urgencia pide el candado de [personaId]. Lo usa
  /// quien lo tiene (la subida sin PIN) para soltarlo en cuanto se lo piden.
  Future<void> turnoPedido(String personaId) => turnoPedidoYa(personaId)
      ? Future<void>.value()
      : (_senales[personaId] ??= Completer<void>()).future;

  // ----------------------------------------------------------- lectura

  Future<PermisoDeSubida?> leer(String personaId) async {
    final texto = await _almacen.leer(clave(personaId));
    if (texto == null) return null;
    try {
      return PermisoDeSubida.desdeJson(
        (jsonDecode(texto) as Map).cast<String, Object?>(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Los permisos guardados, de cualquier persona.
  Future<List<PermisoDeSubida>> todos() async {
    final permisos = <PermisoDeSubida>[];
    for (final c in await _almacen.claves()) {
      if (!c.startsWith(prefijo)) continue;
      final permiso = await leer(c.substring(prefijo.length));
      if (permiso != null) permisos.add(permiso);
    }
    return permisos;
  }

  Future<void> _guardar(PermisoDeSubida permiso) =>
      _almacen.escribir(clave(permiso.personaId), jsonEncode(permiso.aJson()));

  /// Borra el permiso (con su credencial) de [personaId].
  Future<void> borrar(String personaId) => _almacen.borrar(clave(personaId));

  // ------------------------------------------------------- al salir (PIN)

  /// La persona sale con algo por subir: su [credencial] (la más reciente)
  /// pasa de su sobre del PIN al permiso de subida. [llave] es la de su PIN, en
  /// memoria solo ahora: protege la llave privada que servirá para sellar.
  ///
  /// Si ya había un permiso en espera que no ha caducado se conserva su
  /// vencimiento (los 7 días cuentan desde lo más viejo que sigue pendiente).
  Future<void> delegar(String personaId, String credencial, LlavePin llave) =>
      conCandado(personaId, () async {
        final ahora = _reloj();
        final anterior = await leer(personaId);
        final conserva =
            anterior != null &&
            anterior.estado == EstadoPermiso.enEspera &&
            !anterior.caducadoEn(ahora);
        final par = SobreSellado.generar();
        await _guardar(
          PermisoDeSubida(
            personaId: personaId,
            estado: EstadoPermiso.enEspera,
            credencial: credencial,
            clavePublica: par.publica,
            clavePrivadaCifrada: CifradoPin.cifrar(
              llave,
              base64Encode(par.privada),
            ),
            creadoEn: conserva ? anterior.creadoEn : ahora,
            vence: conserva ? anterior.vence : ahora.add(vigencia),
          ),
        );
      });

  // -------------------------------------------------------- al entrar (PIN)

  /// La persona entra con su [pin] (ya comprobado): si tiene permiso, devuelve
  /// su credencial **más reciente** y borra el permiso (vuelve al sobre del
  /// PIN, que guarda quien llama). `null` si no hay permiso o no se pudo abrir.
  ///
  /// Espera al candado: si la subida sin PIN está usando la credencial,
  /// termina primero.
  Future<String?> tomarParaEntrada(String personaId, String pin) => conCandado(
    personaId,
    urgente: true,
    () async {
      final permiso = await leer(personaId);
      if (permiso == null) return null;
      // Entrar con el PIN siempre puede tomar la credencial, aunque el permiso
      // haya caducado: el PIN es la identidad.
      final credencial = switch (permiso.estado) {
        EstadoPermiso.enEspera => permiso.credencial,
        EstadoPermiso.devuelto => await _abrirSobre(permiso, pin),
      };
      if (credencial == null) {
        // Con el PIN bueno y sin poder abrirlo: está dañado, no sirve.
        if (permiso.estado == EstadoPermiso.devuelto &&
            await CifradoPin.descifrarAsync(pin, permiso.clavePrivadaCifrada) !=
                null) {
          await borrar(personaId);
        }
        return null;
      }
      await borrar(personaId);
      return credencial;
    },
  );

  Future<String?> _abrirSobre(PermisoDeSubida permiso, String pin) async {
    final privada = await CifradoPin.descifrarAsync(
      pin,
      permiso.clavePrivadaCifrada,
    );
    if (privada == null) return null;
    final (llave, base64Privada) = privada;
    llave.olvidar();
    return SobreSellado.abrir(base64Decode(base64Privada), permiso.sobre!);
  }

  /// La persona cambia su PIN: la llave privada del permiso (si lo hay) se
  /// vuelve a cifrar con el nuevo. `false` si el PIN actual no la abre.
  Future<bool> cambiarPin(
    String personaId,
    String pinActual,
    String pinNuevo,
  ) => conCandado(personaId, urgente: true, () async {
    final permiso = await leer(personaId);
    if (permiso == null) return true;
    final privada = await CifradoPin.descifrarAsync(
      pinActual,
      permiso.clavePrivadaCifrada,
    );
    if (privada == null) return false;
    final (llaveVieja, base64Privada) = privada;
    llaveVieja.olvidar();
    final llaveNueva = await LlavePin.derivarAsync(pinNuevo);
    await _guardar(
      permiso.copiarCon(
        clavePrivadaCifrada: CifradoPin.cifrar(llaveNueva, base64Privada),
      ),
    );
    llaveNueva.olvidar();
    return true;
  });

  // ------------------------------------------- subida sin PIN (con candado)

  /// Guarda la credencial renovada de [personaId] mientras hay algo por subir.
  /// Sin candado: la llama quien ya lo tiene (la sesión de subida).
  Future<void> guardarCredencialRenovada(
    String personaId,
    String credencial,
  ) async {
    final permiso = await leer(personaId);
    if (permiso == null || permiso.estado != EstadoPermiso.enEspera) return;
    await _guardar(permiso.copiarCon(credencial: credencial));
  }

  /// Ya no hay nada por subir: la credencial se sella con la llave pública y
  /// el texto en claro se borra. Sin candado (ver [guardarCredencialRenovada]).
  Future<void> sellarYDevolver(String personaId, String credencial) async {
    final permiso = await leer(personaId);
    if (permiso == null) return;
    await _guardar(
      permiso.copiarCon(
        estado: EstadoPermiso.devuelto,
        sobre: SobreSellado.sellar(permiso.clavePublica, credencial),
        sinCredencial: true,
      ),
    );
  }

  /// Sella todos los permisos que tienen la credencial en claro, sin subir
  /// nada. Se hace cuando la cuenta del equipo (Hogar) cierra sesión: con
  /// nadie dentro, no debe quedar en el equipo una credencial sin el PIN (B1
  /// de la revisión de la Fase 1b). Lo que esas personas tengan por subir
  /// espera a que vuelvan a entrar con su PIN, que abre el sobre.
  Future<void> sellarTodos() async {
    for (final permiso in await todos()) {
      if (permiso.estado != EstadoPermiso.enEspera) continue;
      await conCandado(permiso.personaId, () async {
        final actual = await leer(permiso.personaId);
        if (actual?.estado == EstadoPermiso.enEspera &&
            actual!.credencial != null) {
          await sellarYDevolver(permiso.personaId, actual.credencial!);
        }
      }, urgente: true);
    }
  }

  /// Borra el permiso de [personaId] (con su credencial), interrumpiendo una
  /// subida en curso. Es lo que pasa cuando la persona vuelve a agregarse con
  /// una credencial nueva: la del permiso es de otra cadena y no debe pisarla
  /// (B5 de la revisión de la Fase 1b).
  Future<void> descartarPermiso(String personaId) =>
      conCandado(personaId, () => borrar(personaId), urgente: true);

  /// Borra los permisos en espera que ya caducaron y devuelve de quiénes eran.
  /// Los devueltos (sellados) no caducan: solo el PIN los abre.
  Future<List<String>> caducar() async {
    final ahora = _reloj();
    final caducadas = <String>[];
    for (final permiso in await todos()) {
      if (permiso.estado == EstadoPermiso.enEspera &&
          permiso.caducadoEn(ahora)) {
        await conCandado(permiso.personaId, () async {
          // Con el candado, por si se renovó justo ahora.
          final actual = await leer(permiso.personaId);
          if (actual != null &&
              actual.estado == EstadoPermiso.enEspera &&
              actual.caducadoEn(ahora)) {
            await borrar(permiso.personaId);
            caducadas.add(permiso.personaId);
          }
        });
      }
    }
    return caducadas;
  }
}

// ---------------------------------------------------------------------------
// Sesión aparte para subir
// ---------------------------------------------------------------------------

/// Cómo se abre una [SesionAparte]: lo ofrecen los servicios con servidor
/// (`SesionesPorPersona.abrirSesionAparte`).
typedef AbridorDeSesionAparte = Future<SesionAparte> Function(
  String personaId,
  String credencial, {
  required void Function(String credencial) alRenovar,
});

/// Crea el [Enviador] que sube con la sesión de [sesion].
typedef FabricaDeEnviador = Enviador Function(SesionAparte sesion);

/// Implementa [SalidaSinPin] con la [BandejaDeSalida] y sesiones aparte.
class SalidaSinPinConSesiones implements SalidaSinPin {
  SalidaSinPinConSesiones({
    required this.bandeja,
    required this._abrir,
    required this._enviadorDe,
  });

  final BandejaDeSalida bandeja;
  final AbridorDeSesionAparte _abrir;
  final FabricaDeEnviador _enviadorDe;

  @override
  Future<PreparacionSalida> preparar(
    Future<bool> Function(String personaId) hayPendientes,
  ) async {
    final caducadas = await bandeja.caducar();
    final conPermiso = <String>[];
    for (final permiso in await bandeja.todos()) {
      if (permiso.estado != EstadoPermiso.enEspera) continue;
      if (await hayPendientes(permiso.personaId)) {
        conPermiso.add(permiso.personaId);
      } else {
        // Un permiso en espera sin nada por subir (se descartó o se subió
        // desde dentro): se sella ya, sin abrir sesión.
        await bandeja.conCandado(permiso.personaId, () async {
          final actual = await bandeja.leer(permiso.personaId);
          if (actual?.estado == EstadoPermiso.enEspera &&
              actual!.credencial != null) {
            await bandeja.sellarYDevolver(
              permiso.personaId,
              actual.credencial!,
            );
          }
        });
      }
    }
    return PreparacionSalida(conPermiso: conPermiso, caducadas: caducadas);
  }

  @override
  Future<SesionDeSubida?> abrir(String personaId) async {
    final soltar = await bandeja.adquirir(personaId);
    try {
      final permiso = await bandeja.leer(personaId);
      if (permiso == null ||
          permiso.estado != EstadoPermiso.enEspera ||
          permiso.credencial == null) {
        soltar();
        return null;
      }
      var ultima = permiso.credencial!;
      // Escrituras en orden: la renovación más nueva siempre gana.
      var guardando = Future<void>.value();
      void alRenovar(String nueva) {
        ultima = nueva;
        // De inmediato: la anterior ya no sirve (y reusarla puede revocar la
        // sesión). Aunque la apertura falle después, esto ya quedó guardado.
        guardando = guardando.then(
          (_) => bandeja.guardarCredencialRenovada(personaId, nueva),
        );
      }

      final SesionAparte aparte;
      try {
        aparte = await _abrir(personaId, ultima, alRenovar: alRenovar);
      } on ErrorSesion catch (error) {
        await guardando;
        soltar();
        // Solo un error claro (credencial vencida o persona dada de baja) quita
        // el permiso. Sin señal, con el servidor ocupado (429…) o ante algo
        // inesperado se reintenta en la siguiente ronda (B2 de la revisión de
        // la Fase 1b).
        if (error != ErrorSesion.credencialVencida &&
            error != ErrorSesion.sinRol) {
          return null;
        }
        rethrow;
      }
      return _SesionDeSubida(
        enviador: EnviadorQueCede(_enviadorDe(aparte), bandeja, personaId),
        alCerrar: (quedanPendientes) async {
          try {
            final vigente = await aparte.cerrar() ?? ultima;
            await guardando;
            if (quedanPendientes) {
              await bandeja.guardarCredencialRenovada(personaId, vigente);
            } else {
              await bandeja.sellarYDevolver(personaId, vigente);
            }
          } finally {
            soltar();
          }
        },
      );
    } catch (_) {
      soltar();
      rethrow;
    }
  }

  @override
  Future<void> descartar(String personaId) =>
      bandeja.conCandado(personaId, () => bandeja.borrar(personaId));
}

/// Envía con el [Enviador] real, pero **cede el turno**: si la persona entra
/// con su PIN (o la quitan) mientras un envío espera al servidor, no espera a
/// que conteste. Devuelve `sinSesion`, que la cola toma como "detén la ronda"
/// sin tocar el registro; el envío se vuelve a intentar después y, si el
/// servidor sí lo recibió, lo ignora por duplicado (`on_conflict`, idempotente).
class EnviadorQueCede implements Enviador {
  const EnviadorQueCede(this._real, this._bandeja, this._personaId);

  final Enviador _real;
  final BandejaDeSalida _bandeja;
  final String _personaId;

  @override
  Future<ResultadoEnvio> enviar(PeticionEnvio peticion) {
    if (_bandeja.turnoPedidoYa(_personaId)) {
      return Future.value(ResultadoEnvio.sinSesion);
    }
    return Future.any<ResultadoEnvio>([
      _real.enviar(peticion),
      _bandeja.turnoPedido(_personaId).then((_) => ResultadoEnvio.sinSesion),
    ]);
  }
}

class _SesionDeSubida implements SesionDeSubida {
  _SesionDeSubida({required this.enviador, required this.alCerrar});

  @override
  final Enviador enviador;

  final Future<void> Function(bool quedanPendientes) alCerrar;
  bool _cerrada = false;

  @override
  Future<void> cerrar({required bool quedanPendientes}) async {
    if (_cerrada) return;
    _cerrada = true;
    await alCerrar(quedanPendientes);
  }
}

// ---------------------------------------------------------------------------
// Lo que la tablet necesita de la bandeja
// ---------------------------------------------------------------------------

/// La bandeja de salida vista desde la tablet (`ControladorTablet`): qué hacer
/// con la credencial de una persona al salir, al entrar, al cambiar su PIN y
/// al quitarla. Sin ella (`null`), la credencial queda siempre en el sobre del
/// PIN y lo de cada persona espera a que vuelva a entrar.
abstract interface class BandejaDeLaTablet {
  /// La persona tiene algo por subir (registrado con su sesión).
  Future<bool> hayPendientesDe(String personaId);

  /// La persona sale con algo por subir: su [credencial] pasa al permiso de
  /// subida ([BandejaDeSalida.delegar]).
  Future<void> delegar(String personaId, String credencial, LlavePin llave);

  /// La persona entra con su [pin] (ya comprobado): su credencial más reciente
  /// si estaba en la bandeja, o `null`.
  Future<String?> tomarParaEntrada(String personaId, String pin);

  /// La llave del permiso pasa al PIN nuevo. `false` si el actual no la abre.
  Future<bool> cambiarPin(String personaId, String pinActual, String pinNuevo);

  /// Quitan a la persona de la tablet: se borra su permiso y lo que tenía por
  /// subir pasa a "requiere atención" ([motivoPersonaQuitada]).
  Future<void> alQuitarPersona(String personaId);

  /// La persona se vuelve a agregar con una credencial nueva: el permiso viejo
  /// se borra (su credencial es de otra cadena). Lo que tenía por subir se
  /// conserva y sube con su sesión nueva.
  Future<void> alAgregarDeNuevo(String personaId);
}

/// [BandejaDeLaTablet] con la [BandejaDeSalida] y la cola.
class BandejaDeLaTabletConCola implements BandejaDeLaTablet {
  BandejaDeLaTabletConCola(this.bandeja, this._cola);

  final BandejaDeSalida bandeja;
  final ColaSinConexion Function() _cola;

  @override
  Future<bool> hayPendientesDe(String personaId) =>
      _cola().hayPendientesDe(personaId);

  @override
  Future<void> delegar(String personaId, String credencial, LlavePin llave) =>
      bandeja.delegar(personaId, credencial, llave);

  @override
  Future<String?> tomarParaEntrada(String personaId, String pin) =>
      bandeja.tomarParaEntrada(personaId, pin);

  @override
  Future<bool> cambiarPin(
    String personaId,
    String pinActual,
    String pinNuevo,
  ) => bandeja.cambiarPin(personaId, pinActual, pinNuevo);

  @override
  Future<void> alQuitarPersona(String personaId) async {
    await bandeja.descartarPermiso(personaId);
    await _cola().rechazarPendientesDe(personaId, motivoPersonaQuitada);
  }

  @override
  Future<void> alAgregarDeNuevo(String personaId) =>
      bandeja.descartarPermiso(personaId);
}

/// Se fija en el arranque y en las pruebas de la app (`conexionesDeLaApp`);
/// por omisión, sin bandeja.
final bandejaDeLaTabletProvider = Provider<BandejaDeLaTablet?>((ref) => null);
