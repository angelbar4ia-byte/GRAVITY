/// Bitácora de acciones: solo quién, cuándo, qué acción y resultado.
/// Nunca guarda el contenido de archivos ni correos, ni los argumentos.
library;

enum ResultadoBitacora { ejecutada, fallida, noPermitida, vetada, noConfirmada }

class EntradaBitacora {
  const EntradaBitacora({
    required this.quien,
    required this.cuando,
    required this.accion,
    required this.resultado,
  });

  final String quien;
  final DateTime cuando;

  /// Solo el tipo (`gmail_enviar`, …) o la herramienta pedida.
  final String accion;
  final ResultadoBitacora resultado;
}

abstract class BitacoraLaptop {
  void registrar(EntradaBitacora entrada);
  List<EntradaBitacora> get entradas;
}

class BitacoraEnMemoria implements BitacoraLaptop {
  final List<EntradaBitacora> _e = [];

  @override
  void registrar(EntradaBitacora entrada) => _e.add(entrada);

  @override
  List<EntradaBitacora> get entradas => List.unmodifiable(_e);
}
