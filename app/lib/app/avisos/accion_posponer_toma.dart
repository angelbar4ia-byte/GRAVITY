/// Acción *Posponer al siguiente turno* del aviso de toma (spec fase-5 8g).
/// Al tocarla llama a `cui_posponer_toma(p_toma)` con el repositorio de
/// Cuidados. Si el servidor la rechaza (sin permiso, fuera de turno, ya
/// marcada) muestra un aviso sobrio: genérico, sin nombres ni dosis (D3).
library;

import '../../modulos/cuidados/datos/repositorio.dart';
import '../../nucleo/avisos/catalogo_avisos.dart';
import '../../nucleo/avisos/notificador.dart';
import '../../nucleo/cuidados/posponer_toma.dart';

/// Texto del aviso cuando no se pudo posponer.
const textoNoSePudoPosponer = 'No se pudo posponer la toma';

/// Atiende [accion] de la notificación con [carga]. Devuelve `true` si llamó a
/// la RPC y funcionó; `false` si la acción no era de una toma o falló.
Future<bool> posponerTomaDesdeAviso({
  required String? carga,
  required AccionDeNotificacion accion,
  required RepositorioCuidados? repositorio,
  required NotificadorLocal notificador,
}) async {
  final llamada = llamadaDePosponerToma(carga, accion);
  if (llamada == null || carga == null) return false;
  try {
    if (repositorio == null) throw StateError('sin sesión');
    await repositorio.posponerToma(llamada.params['p_toma'] as String);
    await notificador.cancelar(idDeNotificacion(carga));
    return true;
  } catch (_) {
    await notificador.mostrar(
      NotificacionLocal(
        id: idDeNotificacion('cui:posponer_fallo'),
        titulo: textoNoSePudoPosponer,
        canal: CanalAviso.avisos,
      ),
    );
    return false;
  }
}
