/// Aviso local «Termina tu descanso» de «Mi gimnasio» (spec 7.2, 9 y PG-18).
///
/// El temporizador de descanso de la sesión en curso **cuenta hacia un instante
/// final** (`DescansoPlanificado.instanteFinal`) y, con la app a la vista, avisa
/// con vibración y una marca visual. Si la app pasa a segundo plano, el sistema
/// debe poder avisar igual: este servicio **programa** una notificación local en
/// ese instante y la **cancela** si el descanso se salta, se ajusta o la sesión
/// termina. Hay **una sola** (el id es fijo): programar otra vez la reemplaza.
///
/// - Texto del catálogo del dominio (`TextoAvisoGimnasio.hab_descanso`): sin
///   nombres de ejercicios, sin cargas, sin dígitos, cuerpo vacío, ≤ 40
///   caracteres. La carga de la notificación (lo que se abre al tocarla) tampoco
///   lleva datos.
/// - **Local:** nada pasa por el servidor ni por Firebase (D3).
/// - Mismas reglas que los recordatorios de Hábitos: solo el teléfono y la
///   tablet personal (nunca la laptop ni la tablet pública), solo quien usa
///   Hábitos, y respeta el interruptor de los recordatorios, el tipo silenciado
///   `hab_descanso` y las horas silenciosas (llega sin sonido).
/// - **No pide permiso** a media sesión: si no se concedió al activar los
///   avisos, no se programa (el temporizador sigue funcionando en pantalla).
/// - Alarma **inexacta** (como todos los avisos): puede tardar si Android ahorra
///   batería; el temporizador no depende de ella (R-5).
library;

import 'package:habitos_dominio/habitos_dominio.dart' show TextoAvisoGimnasio;

import 'aviso.dart';
import 'catalogo_avisos.dart';
import 'notificador.dart';
import 'recordatorios_habitos.dart';
import 'repositorio_avisos.dart';
import 'servicio_avisos.dart' show ContextoAvisos;

/// Id de la única notificación de descanso (un hash estable de su clave).
final int idNotificacionDescanso = idDeNotificacion(claveAvisoDescanso);

/// Clave (y carga) de la notificación: `hab:<tipo>:…`, sin ningún dato.
const claveAvisoDescanso = 'hab:${TipoRecordatorioHabito.descanso}:sesion:0:1';

/// Qué abre al tocarla: la sesión en curso.
bool esCargaDeAvisoDescanso(String? carga) =>
    carga != null && carga.startsWith('hab:${TipoRecordatorioHabito.descanso}:');

class ServicioAvisoDescanso {
  ServicioAvisoDescanso({
    required this.notificador,
    required this.contexto,
    required this.preferencias,
    this.activado,
    DateTime Function()? ahora,
  }) : _ahora = ahora ?? DateTime.now;

  final NotificadorLocal notificador;
  final ContextoAvisos Function() contexto;
  final Future<PreferenciasAvisos> Function() preferencias;

  /// ¿La persona tiene encendidos los recordatorios de Hábitos? (Ajustes ›
  /// Notificaciones). Por omisión, sí.
  final Future<bool> Function()? activado;
  final DateTime Function() _ahora;

  /// El instante final programado ahora, o `null`.
  DateTime? _programado;

  DateTime? get programadoPara => _programado;

  /// ¿Este equipo y esta persona reciben el aviso? Igual que los recordatorios
  /// de Hábitos: teléfono y tablet personal; no la laptop, no la tablet
  /// pública, no la cuenta maestra ni quien no usa Hábitos.
  bool recibe() {
    final c = contexto();
    return c.personaId != null &&
        c.usaHabitos &&
        !c.esMaestra &&
        (c.tipo == TipoEquipoAvisos.telefono ||
            c.tipo == TipoEquipoAvisos.tabletPersonal);
  }

  /// Programa «Termina tu descanso» para [instanteFinal]. Reemplaza al anterior.
  /// Devuelve `true` si quedó programado (no lo está si no corresponde, no hay
  /// permiso, el instante ya pasó o la persona lo silenció).
  Future<bool> programar(DateTime instanteFinal) async {
    // Si había uno, se cancela primero: el descanso cambió (+15 s, −15 s…).
    await cancelar();
    if (!recibe() || !instanteFinal.isAfter(_ahora())) return false;
    if (activado != null && !await activado!()) return false;
    if (!await notificador.permisoConcedido()) return false;
    final prefs = await preferencias();
    if (prefs.tiposSilenciados.contains(TipoRecordatorioHabito.descanso)) {
      return false;
    }
    await notificador.programar(
      NotificacionLocal(
        id: idNotificacionDescanso,
        titulo: TextoAvisoGimnasio.descanso,
        canal: CanalAviso.habitosRecordatorios,
        sonar: sonarEn(prefs, instanteFinal),
        carga: claveAvisoDescanso,
      ),
      instanteFinal,
      zona: prefs.zonaHoraria,
    );
    _programado = instanteFinal;
    return true;
  }

  /// Cancela el aviso (saltar el descanso, terminar la sesión, cambiar de
  /// persona o salir de la pantalla).
  Future<void> cancelar() async {
    _programado = null;
    await notificador.cancelar(idNotificacionDescanso);
  }

  /// Gancho para el temporizador de descanso: pasa el **instante final** del
  /// descanso en curso (`DescansoPlanificado.instanteFinal`), o `null` si no hay
  /// descanso (se saltó o terminó). Programa o cancela según corresponda.
  Future<void> alCambiarDescanso(DateTime? instanteFinal) =>
      instanteFinal == null ? cancelar() : programar(instanteFinal);
}
