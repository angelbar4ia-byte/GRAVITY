/// Interfaz de ejecución de la laptop (D8). La implementación real de Windows
/// está en `ejecutor_windows.dart`.
library;

import 'acciones.dart';

class ResultadoEjecucion {
  const ResultadoEjecucion({required this.exito, this.resumen = ''});
  final bool exito;

  /// Texto corto sin contenido de archivos ni correos.
  final String resumen;
}

abstract class EjecutorLaptop {
  Future<ResultadoEjecucion> ejecutar(Accion accion);
}

/// Para pruebas: guarda lo que se le pidió y no toca el sistema.
class EjecutorLaptopFalso implements EjecutorLaptop {
  final List<Accion> ejecutadas = [];
  bool fallar = false;

  @override
  Future<ResultadoEjecucion> ejecutar(Accion accion) async {
    ejecutadas.add(accion);
    return ResultadoEjecucion(exito: !fallar, resumen: fallar ? 'falló' : 'ok');
  }
}
