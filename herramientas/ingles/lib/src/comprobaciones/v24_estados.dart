import '../contexto.dart';
import '../hallazgo.dart';
import '../modelo/archivo.dart';
import 'comun.dart';

/// V24 (parte que no depende de revisiones) · Un archivo en `validado` no
/// puede tener errores. Nada puede estar en `revisado` ni en `aprobado`
/// todavía: no existe `comparar`, y por tanto ninguna revisión a ciegas
/// vigente.
///
/// Recibe los hallazgos que dejaron las demás comprobaciones sobre este mismo
/// archivo. (La parte con huella y revisiones llega con `comparar`.)
List<Hallazgo> v24(Archivo a, Contexto c, List<Hallazgo> previos) {
  final estado = a.estado;
  if (estado == null || estado == Estado.borrador || estado == Estado.retirado) {
    return const [];
  }
  final h = <Hallazgo>[];
  if (estado == Estado.revisado || estado == Estado.aprobado) {
    h.add(error(a, 'V24', 'está en "${estado.name}" y no hay revisión a ciegas vigente: todavía no existe comparar, así que nada puede pasar de "validado"'));
  }
  final errores = previos.where((x) => x.esError && x.archivo == a.ruta).length;
  if (errores > 0) {
    h.add(error(a, 'V24', 'está en "${estado.name}" pero tiene $errores error${errores == 1 ? '' : 'es'}: un archivo validado no puede tener errores'));
  }
  return h;
}
