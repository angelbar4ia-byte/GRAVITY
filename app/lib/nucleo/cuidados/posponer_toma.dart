/// Posponer una toma al siguiente turno (spec fase-5 8g). Puro: solo arma el
/// nombre de la RPC y sus parámetros. La llamada al servidor la hace el módulo
/// de Cuidados; aquí no hay red ni datos clínicos (la carga es la clave del
/// recordatorio, que lleva solo el id de la toma).
library;

import '../avisos/notificador.dart';

/// Nombre exacto de la RPC del servidor (migración 20261121).
const rpcPosponerToma = 'cui_posponer_toma';

/// Texto de la acción de la notificación.
const textoPosponerAlSiguienteTurno = 'Posponer al siguiente turno';

/// Acciones que lleva el aviso de [tipo]: la toma ofrece posponer al
/// siguiente turno; lo demás, ninguna.
List<AccionDeNotificacion> accionesDeRecordatorio(String tipo) =>
    tipo == 'recordatorio_toma'
    ? const [AccionDeNotificacion.posponerTurno]
    : const [];

/// Id de la toma dentro de la clave `cui:recordatorio_toma:<id>:<día>:<hm>`;
/// `null` si la clave no es de una toma.
String? tomaDeClave(String? clave) {
  if (clave == null) return null;
  final partes = clave.split(':');
  if (partes.length < 3 || partes[0] != 'cui' || partes[1] != 'recordatorio_toma') {
    return null;
  }
  return partes[2].isEmpty ? null : partes[2];
}

/// Llamada a hacer: `rpc` y `params` (`{'toma': <id>}`).
typedef LlamadaRpc = ({String rpc, Map<String, dynamic> params});

/// Qué RPC llamar al tocar *Posponer al siguiente turno* en la notificación
/// con [carga]; `null` si la acción no es esa o la carga no es de una toma.
LlamadaRpc? llamadaDePosponerToma(String? carga, AccionDeNotificacion accion) {
  if (accion != AccionDeNotificacion.posponerTurno) return null;
  final toma = tomaDeClave(carga);
  if (toma == null) return null;
  return (rpc: rpcPosponerToma, params: {'toma': toma});
}
