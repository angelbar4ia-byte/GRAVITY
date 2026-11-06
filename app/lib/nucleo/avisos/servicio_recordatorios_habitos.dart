/// Programa y atiende los recordatorios locales de Hábitos (ver
/// `recordatorios_habitos.dart`). Se reprograman al abrir la app, al sincronizar,
/// al cambiar los ajustes y al reiniciar (el receptor de arranque de la
/// biblioteca), más una tarea diaria. La laptop no programa; la tablet pública,
/// nunca; la cuenta maestra no tiene Hábitos.
library;

import 'dart:convert';

import '../seguridad/almacen_seguro.dart';
import 'aviso.dart';
import 'notificador.dart';
import 'recordatorios_habitos.dart';
import 'repositorio_avisos.dart';
import 'servicio_avisos.dart' show ContextoAvisos;
import 'catalogo_avisos.dart';

class ServicioRecordatoriosHabitos {
  ServicioRecordatoriosHabitos({
    required this.notificador,
    required this.fuente,
    required this.almacen,
    required this.contexto,
    required this.preferencias,
    DateTime Function()? ahoraLocal,
    this.modoFoco = false,
  }) : _ahora = ahoraLocal ?? DateTime.now;

  final NotificadorLocal notificador;
  final FuenteDeRecordatoriosHabitos fuente;
  final AlmacenSeguro almacen;
  final ContextoAvisos Function() contexto;

  /// Las preferencias de avisos de la persona (zona, silencio, tipos
  /// silenciados); por omisión las de la especificación.
  final Future<PreferenciasAvisos> Function() preferencias;
  final DateTime Function() _ahora;
  final bool modoFoco;

  static String _claveActivado(String p) => 'hab.recordatorios.activado.$p';
  static String _claveProgramados(String p) => 'hab.recordatorios.ids.$p';
  static String _claveAcciones(String p) => 'hab.recordatorios.acciones.$p';

  /// ¿Este equipo y esta persona reciben recordatorios de Hábitos? Teléfono y
  /// tablet personal sí (D21); laptop, tablet pública, maestra y quien no usa
  /// Hábitos, no.
  bool recibe() {
    final c = contexto();
    return c.personaId != null &&
        c.usaHabitos &&
        !c.esMaestra &&
        (c.tipo == TipoEquipoAvisos.telefono ||
            c.tipo == TipoEquipoAvisos.tabletPersonal);
  }

  /// Activados por omisión; la persona los apaga en Ajustes › Notificaciones.
  Future<bool> activado() async {
    final persona = contexto().personaId;
    if (persona == null) return false;
    return await almacen.leer(_claveActivado(persona)) != '0';
  }

  /// Enciende o apaga. Al encender pide el permiso del sistema.
  Future<bool> fijarActivado(bool activar) async {
    final persona = contexto().personaId;
    if (!recibe() || persona == null) return false;
    await almacen.escribir(_claveActivado(persona), activar ? '1' : '0');
    if (!activar) {
      await _cancelarProgramados(persona);
      return true;
    }
    final permiso =
        await notificador.permisoConcedido() ||
        await notificador.pedirPermiso();
    await reprogramar();
    return permiso;
  }

  Future<List<int>> _idsProgramados(String persona) async {
    final texto = await almacen.leer(_claveProgramados(persona));
    if (texto == null) return [];
    try {
      return [for (final i in jsonDecode(texto) as List) i as int];
    } catch (_) {
      return [];
    }
  }

  Future<void> _cancelarProgramados(String persona) async {
    for (final id in await _idsProgramados(persona)) {
      await notificador.cancelar(id);
    }
    await almacen.borrar(_claveProgramados(persona));
  }

  /// Cancela lo programado y vuelve a programar desde la copia local. Devuelve
  /// los recordatorios que quedaron.
  Future<List<RecordatorioHabito>> reprogramar() async {
    final persona = contexto().personaId;
    if (persona == null) return const [];
    await _cancelarProgramados(persona);
    if (!recibe() ||
        !await activado() ||
        !await notificador.permisoConcedido()) {
      return const [];
    }
    final prefs = await preferencias();
    final ahora = _ahora();
    List<RecordatorioHabito> candidatos;
    try {
      candidatos = await fuente.proximos(desde: ahora, dias: 7);
    } catch (_) {
      candidatos = const [];
    }
    final lista = recordatoriosAProgramar(
      candidatos: candidatos,
      preferencias: prefs,
      ahora: ahora,
      modoFoco: modoFoco,
    );
    final ids = <int>[];
    for (final r in lista) {
      final n = notificacionDeRecordatorio(r, prefs);
      await notificador.programar(n, r.cuando, zona: prefs.zonaHoraria);
      ids.add(n.id);
    }
    await almacen.escribir(_claveProgramados(persona), jsonEncode(ids));
    return lista;
  }

  /// Retira un recordatorio (p. ej. la persona ya marcó la actividad).
  Future<void> retirar(RecordatorioHabito r) =>
      notificador.cancelar(idDeNotificacion(claveDeRecordatorio(r)));

  // ------------------------------------------------------------ acciones

  /// Un botón de la notificación. *Posponer 10 min* vuelve a programarla con el
  /// mismo texto discreto; *Hecho* y *Omitir* (solo de lo no sensible) se
  /// guardan en el equipo para que Hábitos los suba por la cola. Ninguna acción
  /// escribe un dato sensible.
  Future<void> alAccion(String? carga, AccionDeNotificacion accion) async {
    final persona = contexto().personaId;
    final tipo = tipoDeClaveDeHabito(carga);
    if (carga == null || tipo == null || persona == null) return;
    final sensible = tipo == TipoRecordatorioHabito.reservado;
    final id = idDeNotificacion(carga);
    switch (accion) {
      case AccionDeNotificacion.posponer10:
        final prefs = await preferencias();
        final cuando = _ahora().add(const Duration(minutes: minutosDePosponer));
        await notificador.programar(
          NotificacionLocal(
            id: id,
            titulo: titulosDeHabitos[tipo] ?? textoAvisoGenerico,
            canal: sensible
                ? CanalAviso.habitosReservados
                : CanalAviso.habitosRecordatorios,
            sonar: sonarEn(prefs, cuando),
            carga: carga,
            acciones: sensible
                ? const [AccionDeNotificacion.posponer10]
                : const [
                    AccionDeNotificacion.hecho,
                    AccionDeNotificacion.posponer10,
                    AccionDeNotificacion.omitir,
                  ],
          ),
          cuando,
          zona: prefs.zonaHoraria,
        );
      case AccionDeNotificacion.hecho || AccionDeNotificacion.omitir:
        if (sensible) return; // nunca se escribe lo sensible desde aquí
        await notificador.cancelar(id);
        final lista = await accionesPendientes();
        lista.add(
          AccionDeRecordatorio(clave: carga, accion: accion, en: _ahora()),
        );
        await almacen.escribir(
          _claveAcciones(persona),
          jsonEncode([for (final a in lista) a.aJson()]),
        );
    }
  }

  /// Lo que se hizo desde las notificaciones y Hábitos aún no guardó.
  Future<List<AccionDeRecordatorio>> accionesPendientes() async {
    final persona = contexto().personaId;
    if (persona == null) return [];
    final texto = await almacen.leer(_claveAcciones(persona));
    if (texto == null) return [];
    try {
      return [
        for (final j in jsonDecode(texto) as List)
          AccionDeRecordatorio(
            clave: (j as Map)['clave'] as String,
            accion: AccionDeNotificacion.desdeId(j['accion'] as String?)!,
            en: DateTime.parse(j['en'] as String),
          ),
      ];
    } catch (_) {
      return [];
    }
  }

  /// Hábitos ya las guardó: se vacía la lista.
  Future<void> entregadas() async {
    final persona = contexto().personaId;
    if (persona != null) await almacen.borrar(_claveAcciones(persona));
  }
}
