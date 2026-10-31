/// El corazón de los avisos en el dispositivo (Fase 2, D20, reglas 41 a 49).
///
/// Recibe de Firebase solo `{v, id}`, lee su propia fila de `avisos` con la
/// sesión de la persona y muestra una notificación **discreta** (título del
/// catálogo, cuerpo vacío). Sin sesión, sin señal o si no puede leer el aviso,
/// muestra *"Tienes un aviso de GRAVITY"*. Respeta quién recibe qué:
///
/// - **Teléfono:** push y recordatorios locales.
/// - **Tablet personal:** apagado por omisión; la persona lo activa.
/// - **Tablet pública de la casa:** **nunca** un aviso personal.
/// - **Laptop:** sin push; con la app abierta, la bandeja en vivo y un aviso
///   de Windows con el mismo texto del catálogo.
/// - **Cuenta maestra:** nunca recibe avisos de dinero.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:timezone/data/latest.dart' as tzdatos;
import 'package:timezone/timezone.dart' as tz;

import '../seguridad/almacen_seguro.dart';
import 'aviso.dart';
import 'catalogo_avisos.dart';
import 'fuente_push.dart';
import 'notificador.dart';
import 'recordatorios.dart';
import 'repositorio_avisos.dart';

/// Quién usa el equipo ahora y qué clase de equipo es.
@immutable
class ContextoAvisos {
  const ContextoAvisos({
    required this.tipo,
    this.personaId,
    this.esMaestra = false,
    this.puedeRecibir = true,
  });

  final TipoEquipoAvisos tipo;

  /// `null` si nadie ha entrado (o en la tablet solo está la cuenta Hogar).
  final String? personaId;
  final bool esMaestra;

  /// `false` para quien no ve dinero (familiar, cuidador, Casa): no recibe
  /// avisos de Finanzas (regla 41).
  final bool puedeRecibir;
}

/// Cómo se presenta un aviso (reglas 35 y 36).
enum Presentacion {
  /// Con el sonido y la vibración de su canal.
  sonar,

  /// Llega, pero sin sonido ni vibración (horas silenciosas).
  silenciosa,

  /// No sale de la app: queda en la bandeja (tipo silenciado o tope diario).
  soloBandeja,
}

/// Decide cómo presentar un aviso. Pura, para probarla sin reloj ni sistema.
///
/// [noCriticasHoy] son las notificaciones no críticas ya mostradas hoy.
Presentacion decidirPresentacion({
  required String tipo,
  required PreferenciasAvisos preferencias,
  required HoraDelDia ahora,
  required int noCriticasHoy,
}) {
  if (preferencias.tiposSilenciados.contains(tipo)) {
    return Presentacion.soloBandeja;
  }
  final enSilencio = preferencias.enSilencio(ahora);
  final silencioso = enSilencio ? Presentacion.silenciosa : Presentacion.sonar;
  if (severidadDe(tipo) == SeveridadAviso.critica) {
    return enSilencio && !preferencias.criticasEnSilencio
        ? Presentacion.silenciosa
        : Presentacion.sonar;
  }
  if (avisosFijos.contains(tipo)) return silencioso;
  if (noCriticasHoy >= preferencias.topeNoCriticas) {
    return Presentacion.soloBandeja;
  }
  return silencioso;
}

/// Hora local de la persona (en su zona) para el silencio y el tope.
typedef RelojLocal = ({DateTime fecha, HoraDelDia hora}) Function(String zona);

RelojLocal relojLocalPorOmision(DateTime Function() ahora) {
  var listo = false;
  return (zona) {
    if (!listo) {
      tzdatos.initializeTimeZones();
      listo = true;
    }
    tz.Location ubicacion;
    try {
      ubicacion = tz.getLocation(zona);
    } catch (_) {
      ubicacion = tz.getLocation('America/Mexico_City');
    }
    final local = tz.TZDateTime.from(ahora(), ubicacion);
    return (
      fecha: DateTime(local.year, local.month, local.day),
      hora: HoraDelDia(local.hour, local.minute),
    );
  };
}

class ServicioAvisos {
  ServicioAvisos({
    required this.notificador,
    required this.fuentePush,
    required this.repositorio,
    required this.almacen,
    required this.contexto,
    this.alAbrirAviso,
    this.recordatorios,
    RelojLocal? reloj,
    this.esperaMaximaDeLectura = const Duration(seconds: 8),
  }) : _reloj = reloj ?? relojLocalPorOmision(DateTime.now);

  final NotificadorLocal notificador;
  final FuentePush fuentePush;

  /// `null` si no hay servidor (modo demostración).
  final RepositorioAvisos? Function() repositorio;
  final AlmacenSeguro almacen;
  final ContextoAvisos Function() contexto;

  /// Qué hacer al tocar una notificación (la app abre la bandeja).
  final void Function(String? avisoId)? alAbrirAviso;
  final RecordatoriosLocales? recordatorios;
  final RelojLocal _reloj;
  final Duration esperaMaximaDeLectura;

  StreamSubscription<MensajePush>? _mensajes;
  StreamSubscription<String>? _renovaciones;
  StreamSubscription<List<Aviso>>? _enVivo;
  final Set<String> _vistosEnVivo = {};
  bool _primeraEmision = true;
  PreferenciasAvisos? _preferencias;
  String? _tokenRegistrado;

  static String _claveActivado(String persona) => 'avisos.activado.$persona';
  static String _claveContador(String persona) => 'avisos.contador.$persona';

  // ---------------------------------------------------------------- inicio

  Future<void> iniciar() async {
    await notificador.iniciar(
      alTocar: (carga) => alAbrirAviso?.call(carga),
    );
    _mensajes ??= fuentePush.mensajes.listen(
      (mensaje) => unawaited(alRecibirPush(mensaje)),
    );
    _renovaciones ??= fuentePush.renovaciones.listen(
      (token) => unawaited(_registrar(token)),
    );
    final inicial = await fuentePush.mensajeInicial();
    if (inicial != null) alAbrirAviso?.call(inicial.id);
  }

  Future<void> detener() async {
    await _mensajes?.cancel();
    await _renovaciones?.cancel();
    await _enVivo?.cancel();
    _mensajes = _renovaciones = _enVivo = null;
  }

  // ----------------------------------------------- recibir en este equipo

  /// ¿Este equipo muestra avisos personales a esta persona? La tablet pública
  /// nunca; la tablet personal solo si la persona lo activó; la maestra,
  /// nunca; la laptop recibe por la bandeja en vivo, no por push.
  Future<bool> recibeEnEsteEquipo({bool porPush = true}) async {
    final c = contexto();
    if (c.tipo == TipoEquipoAvisos.tabletPublica ||
        c.esMaestra ||
        !c.puedeRecibir) {
      return false;
    }
    if (c.tipo == TipoEquipoAvisos.laptop) return !porPush;
    if (c.tipo == TipoEquipoAvisos.telefono) {
      final persona = c.personaId;
      if (persona == null) return true; // el genérico, sin datos de nadie
      return await almacen.leer(_claveActivado(persona)) != '0';
    }
    // Tablet personal: apagada por omisión.
    final persona = c.personaId;
    return persona != null && await almacen.leer(_claveActivado(persona)) == '1';
  }

  /// Si la persona activó los avisos en este equipo (teléfono: sí por
  /// omisión; tablet personal: no).
  Future<bool> activado() async {
    final c = contexto();
    final persona = c.personaId;
    if (persona == null) return false;
    final guardado = await almacen.leer(_claveActivado(persona));
    return guardado == null ? c.tipo.recibePushPorOmision : guardado == '1';
  }

  /// Activa o apaga los avisos en este equipo. Al activar pide el permiso del
  /// sistema (la pantalla explica antes por qué) y registra el equipo.
  /// Devuelve `false` si el sistema niega el permiso.
  Future<bool> fijarActivado(bool activar) async {
    final c = contexto();
    final persona = c.personaId;
    if (persona == null ||
        c.tipo == TipoEquipoAvisos.tabletPublica ||
        c.esMaestra ||
        !c.puedeRecibir) {
      return false;
    }
    await almacen.escribir(_claveActivado(persona), activar ? '1' : '0');
    if (!activar) {
      await alSalirPersona(conservarToken: true);
      return true;
    }
    final permiso = await notificador.permisoConcedido() ||
        await notificador.pedirPermiso();
    await alEntrarPersona();
    return permiso;
  }

  // -------------------------------------------- dispositivo y sesión

  /// La persona entró (o se abrió la app con sesión): registra el token del
  /// equipo a su nombre (reasigna si era de otra) y empieza a escuchar.
  Future<void> alEntrarPersona() async {
    final c = contexto();
    if (c.personaId == null ||
        c.tipo == TipoEquipoAvisos.tabletPublica ||
        c.esMaestra ||
        !c.puedeRecibir) {
      return;
    }
    _preferencias = null;
    if (c.tipo == TipoEquipoAvisos.laptop) {
      await _escucharEnVivo();
      return;
    }
    if (!await activado()) return;
    final token = await fuentePush.token();
    if (token != null) await _registrar(token);
    await reprogramarRecordatorios();
  }

  /// Vuelve a programar los recordatorios locales (al abrir la app, al
  /// sincronizar, al cambiar las preferencias). Sin permiso o sin avisos
  /// activados, deja todo cancelado.
  Future<void> reprogramarRecordatorios() async {
    final r = recordatorios;
    if (r == null) return;
    if (!await recibeEnEsteEquipo() || contexto().personaId == null) {
      await notificador.cancelarProgramadas();
      return;
    }
    final preferencias = await _leerPreferencias();
    final reloj = _reloj(preferencias.zonaHoraria);
    await r.reprogramar(
      preferencias: preferencias,
      ahora: DateTime(
        reloj.fecha.year,
        reloj.fecha.month,
        reloj.fecha.day,
        reloj.hora.hora,
        reloj.hora.minuto,
      ),
    );
  }

  Future<void> _registrar(String token) async {
    final c = contexto();
    final repo = repositorio();
    if (repo == null || c.personaId == null || !await activado()) return;
    try {
      await repo.registrarDispositivo(
        token: token,
        plataforma: 'android',
        nombre: switch (c.tipo) {
          TipoEquipoAvisos.telefono => 'Teléfono',
          TipoEquipoAvisos.tabletPersonal => 'Tablet personal',
          TipoEquipoAvisos.tabletPublica => 'Tablet de la casa',
          TipoEquipoAvisos.laptop => 'Laptop',
        },
        tipo: c.tipo,
      );
      _tokenRegistrado = token;
    } catch (error) {
      debugPrint('No se pudo registrar el equipo para avisos: $error');
    }
  }

  /// La persona salió, se quitó de la tablet o se dio de baja: el equipo deja
  /// de recibir sus avisos y se borran sus notificaciones programadas.
  /// [conservarToken]: solo se apagan los avisos, no se cierra la sesión.
  Future<void> alSalirPersona({bool conservarToken = false}) async {
    await _enVivo?.cancel();
    _enVivo = null;
    _vistosEnVivo.clear();
    _primeraEmision = true;
    _preferencias = null;
    final token = _tokenRegistrado ?? await fuentePush.token();
    _tokenRegistrado = null;
    try {
      if (token != null) await repositorio()?.quitarDispositivo(token);
    } catch (error) {
      debugPrint('No se pudo quitar el equipo de los avisos: $error');
    }
    await notificador.cancelarProgramadas();
    if (!conservarToken) await fuentePush.olvidarToken();
  }

  // ---------------------------------------------------------------- push

  /// Llegó `{v, id}` por Firebase.
  Future<void> alRecibirPush(MensajePush mensaje) async {
    if (!await recibeEnEsteEquipo()) return;
    if (!await notificador.permisoConcedido()) return;
    final c = contexto();
    final persona = c.personaId;
    final repo = repositorio();
    if (persona == null || repo == null) {
      await _mostrarGenerico();
      return;
    }
    final Aviso? aviso;
    try {
      aviso = await repo.leer(mensaje.id).timeout(esperaMaximaDeLectura);
    } catch (_) {
      await _mostrarGenerico(); // sin señal o sin poder leerlo
      return;
    }
    if (aviso == null) {
      await _mostrarGenerico();
      return;
    }
    await _mostrar(aviso, persona);
  }

  /// Muestra un aviso ya leído, con el texto del catálogo.
  Future<void> _mostrar(Aviso aviso, String persona) async {
    if (!aviso.estado.abierto) {
      // Ya se atendió o se canceló: se retira si seguía ahí.
      await notificador.cancelar(idDeNotificacion(aviso.clave));
      return;
    }
    final preferencias = await _leerPreferencias();
    final reloj = _reloj(preferencias.zonaHoraria);
    final contador = await _contador(persona, reloj.fecha);
    final decision = decidirPresentacion(
      tipo: aviso.tipo,
      preferencias: preferencias,
      ahora: reloj.hora,
      noCriticasHoy: contador,
    );
    if (decision == Presentacion.soloBandeja) return;
    if (severidadDe(aviso.tipo) != SeveridadAviso.critica &&
        !avisosFijos.contains(aviso.tipo)) {
      await _guardarContador(persona, reloj.fecha, contador + 1);
    }
    await notificador.mostrar(
      NotificacionLocal(
        id: idDeNotificacion(aviso.clave),
        titulo: aviso.titulo,
        canal: canalDe(aviso.tipo),
        sonar: decision == Presentacion.sonar,
        carga: aviso.id,
      ),
    );
  }

  Future<void> _mostrarGenerico() => notificador.mostrar(
    NotificacionLocal(
      id: idNotificacionGenerica,
      titulo: textoAvisoGenerico,
      canal: CanalAviso.avisos,
    ),
  );

  /// *Enviarme un aviso de prueba*: la notificación genérica, que es lo que
  /// ven la pantalla bloqueada y la pulsera.
  Future<bool> avisoDePrueba() async {
    if (!await notificador.permisoConcedido()) return false;
    await _mostrarGenerico();
    return true;
  }

  // ------------------------------------------------------------- laptop

  Future<void> _escucharEnVivo() async {
    final repo = repositorio();
    if (repo == null) return;
    await _enVivo?.cancel();
    _primeraEmision = true;
    _enVivo = repo.enVivo().listen(
      (lista) => unawaited(_alCambiarBandeja(lista)),
      onError: (Object e) => debugPrint('Bandeja en vivo: $e'),
    );
  }

  Future<void> _alCambiarBandeja(List<Aviso> lista) async {
    final c = contexto();
    final persona = c.personaId;
    if (persona == null || !await recibeEnEsteEquipo(porPush: false)) return;
    // La primera lista es lo que ya había: solo se avisa de lo nuevo.
    final nuevos = [
      for (final a in lista)
        if (_vistosEnVivo.add(a.id) && !_primeraEmision) a,
    ];
    _primeraEmision = false;
    for (final aviso in nuevos) {
      if (aviso.estado == EstadoAviso.pendiente ||
          aviso.estado == EstadoAviso.enviada) {
        await _mostrar(aviso, persona);
      }
    }
  }

  // ------------------------------------------------ preferencias y tope

  Future<PreferenciasAvisos> _leerPreferencias() async {
    final guardadas = _preferencias;
    if (guardadas != null) return guardadas;
    PreferenciasAvisos? leidas;
    try {
      leidas = await repositorio()?.preferencias();
    } catch (_) {}
    return _preferencias = leidas ?? const PreferenciasAvisos();
  }

  /// Después de guardar preferencias en el servidor.
  void preferenciasCambiaron(PreferenciasAvisos nuevas) {
    _preferencias = nuevas;
    unawaited(reprogramarRecordatorios());
  }

  Future<int> _contador(String persona, DateTime dia) async {
    final texto = await almacen.leer(_claveContador(persona));
    if (texto == null) return 0;
    try {
      final json = (jsonDecode(texto) as Map).cast<String, Object?>();
      return json['dia'] == _dia(dia) ? (json['n'] as int? ?? 0) : 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _guardarContador(String persona, DateTime dia, int n) =>
      almacen.escribir(
        _claveContador(persona),
        jsonEncode({'dia': _dia(dia), 'n': n}),
      );

  static String _dia(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Retira la notificación de un aviso (p. ej. al registrar el pago).
  Future<void> retirarPorClave(String clave) =>
      notificador.cancelar(idDeNotificacion(clave));
}
