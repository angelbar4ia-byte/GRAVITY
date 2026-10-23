// Dobles de prueba de la bandeja de salida: un servidor que tiene o no señal
// y un enviador que anota con la sesión de quién llegó cada registro.
import 'package:gravity/nucleo/cola/cola_sin_conexion.dart';

/// Servidor falso: hay señal o no, y anota con la sesión de quién llegó cada
/// registro.
class ServidorFalso {
  bool conSenal = true;
  final List<({String id, String? sesionDe})> recibidos = [];

  List<String> idsDe(String? sesionDe) => [
    for (final r in recibidos)
      if (r.sesionDe == sesionDe) r.id,
  ];
}

class EnviadorDeSesion implements Enviador {
  EnviadorDeSesion(this.servidor, this.sesionDe);

  final ServidorFalso servidor;
  final String? Function() sesionDe;

  @override
  Future<ResultadoEnvio> enviar(PeticionEnvio peticion) async {
    if (!servidor.conSenal) return ResultadoEnvio.reintentar;
    servidor.recibidos.add((id: peticion.id, sesionDe: sesionDe()));
    return ResultadoEnvio.enviado;
  }
}
