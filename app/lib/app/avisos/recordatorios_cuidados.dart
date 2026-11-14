/// Conexión de los recordatorios de Cuidados con la app (spec Fase 5, §3, §7 y
/// §8g): programa en este equipo las comidas de Papá **solo de quien está de
/// turno**. Las tomas las avisa el servidor (`recordatorio_toma`); el cliente
/// ya no las programa.
library;

import '../../nucleo/avisos/aviso.dart';
import '../../nucleo/avisos/notificador.dart';
import '../../nucleo/contratos/roles.dart';
import '../../nucleo/cuidados/servicio_recordatorios_cuidados.dart';
import '../../nucleo/cuidados/turnos.dart' as t;
import '../../nucleo/seguridad/almacen_seguro.dart';
import '../../modulos/cuidados/datos/modelos.dart';
import '../../modulos/cuidados/datos/repositorio.dart';

/// Tomas pendientes y comidas sin registrar de hoy, leídas del repositorio.
class FuenteCuidadosRepositorio implements FuenteDeEventosDeCuidado {
  const FuenteCuidadosRepositorio(this.repositorio);

  final RepositorioCuidados repositorio;

  @override
  Future<List<t.EventoDeCuidado>> proximos({
    required DateTime desde,
    required int dias,
  }) async {
    final hoy = soloFecha(desde);
    final eventos = <t.EventoDeCuidado>[];
    // Las tomas ya no se programan en el cliente: el servidor genera el aviso
    // `recordatorio_toma` y es la fuente. Aquí solo quedan las comidas.
    Map<TiempoComidaPapa, HoraComida> horas;
    try {
      horas = await repositorio.horariosComida();
    } catch (_) {
      horas = horariosComidaPorOmision;
    }
    final hechas = {for (final c in await repositorio.comidas(hoy)) c.tiempo};
    for (final e in horas.entries) {
      if (hechas.contains(e.key)) continue;
      eventos.add(
        t.EventoDeCuidado(
          tipo: 'recordatorio_comida',
          objetoId: e.key.name,
          cuando: DateTime(
            hoy.year,
            hoy.month,
            hoy.day,
            e.value.hora,
            e.value.minuto,
          ),
        ),
      );
    }
    return eventos;
  }
}

/// Clave de turno de la persona según su perfil; `null` si no es cuidadora,
/// hermana ni dueño (pareja, Casa, sin acceso).
String? claveDeTurnoDe(TipoPerfil? tipo) => switch (tipo) {
  TipoPerfil.dueno => t.RolDeTurno.dueno,
  TipoPerfil.cuidadora => t.RolDeTurno.cuidadoraPrincipal,
  TipoPerfil.hermana => t.RolDeTurno.hermana,
  _ => null,
};

/// Turnos reales de los próximos 7 días como tramos semanales; los de [mia]
/// llevan su clave y los demás una distinta. Las visitas no cuentan.
List<t.Turno> turnosParaRecordatorios(
  Iterable<Turno> reales,
  String personaId,
  String mia,
) {
  final salida = <t.Turno>[];
  for (final r in reales) {
    if (r.tipo != TipoTurno.turno) continue;
    final quien = r.personaId == personaId ? mia : 'otro:${r.personaId}';
    var dia = soloFecha(r.inicio);
    while (dia.isBefore(r.fin)) {
      final sig = DateTime(dia.year, dia.month, dia.day + 1);
      final ini = r.inicio.isAfter(dia) ? r.inicio : dia;
      final fin = r.fin.isBefore(sig) ? r.fin : sig;
      if (fin.isAfter(ini)) {
        salida.add(
          t.Turno(
            cuidador: quien,
            dia: dia.weekday,
            desde: HoraDelDia(ini.hour, ini.minute),
            hasta: fin == sig
                ? const HoraDelDia(24)
                : HoraDelDia(fin.hour, fin.minute),
          ),
        );
      }
      dia = sig;
    }
  }
  return salida;
}

/// Reprograma los recordatorios de Cuidados de este equipo. Quien no está de
/// turno no recibe nada; sin sesión, sin perfil o sin ser cuidadora, hermana o
/// dueño solo se cancela lo anterior. Si el servidor no responde, se deja lo
/// ya programado. Devuelve lo programado.
Future<List<t.RecordatorioCuidado>> reprogramarRecordatoriosCuidados({
  required RepositorioCuidados repositorio,
  required NotificadorLocal notificador,
  required AlmacenSeguro almacen,
  required Rol? rol,
  required String? personaId,
  required bool esMaestra,
  required DateTime ahora,
  required PreferenciasAvisos preferencias,
  bool tabletPublica = false,
}) async {
  // D3/D14: la tablet pública no programa recordatorios de cuidado (nada
  // clínico en un equipo compartido); solo se cancela lo anterior.
  if (tabletPublica) {
    rol = null;
    personaId = null;
  }
  String? clave;
  var turnos = t.turnosPorOmision;
  if (rol != null && personaId != null) {
    try {
      final tipo = (await repositorio.perfil()).efectivo(rol);
      // La cuenta maestra solo lee (D19), salvo la propia dueña.
      clave = esMaestra && tipo != TipoPerfil.dueno
          ? null
          : claveDeTurnoDe(tipo);
      if (clave != null) {
        final hoy = soloFecha(ahora);
        final reales = await repositorio.turnos(
          hoy,
          DateTime(hoy.year, hoy.month, hoy.day + 7),
        );
        final convertidos = turnosParaRecordatorios(reales, personaId, clave);
        if (convertidos.isNotEmpty) turnos = convertidos;
      }
    } catch (_) {
      return const [];
    }
  }
  return ServicioRecordatoriosCuidados(
    notificador: notificador,
    almacen: almacen,
    fuente: FuenteCuidadosRepositorio(repositorio),
  ).reprogramar(
    cuidador: clave,
    ahora: ahora,
    preferencias: preferencias,
    turnos: turnos,
  );
}
