/// Proveedores de Riverpod para la base local y la cola sin conexión.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../base_local/base_local.dart';
import 'cola_sin_conexion.dart';

/// Base local. Se fija en el arranque (archivo del dispositivo) o en la
/// prueba (`BaseLocal.enMemoria()`).
final baseLocalProvider = Provider<BaseLocal>(
  (ref) => throw UnimplementedError(
    'baseLocalProvider se configura en el arranque o en la prueba',
  ),
);

/// Enviador de la cola. Sin servidor (modo demostración) los registros se
/// quedan en el dispositivo.
final enviadorProvider = Provider<Enviador>((ref) => const EnviadorSinServidor());

final colaSinConexionProvider = Provider<ColaSinConexion>((ref) {
  final cola = ColaSinConexion(
    base: ref.watch(baseLocalProvider),
    enviador: ref.watch(enviadorProvider),
  );
  ref.onDispose(cola.detenerAutomatico);
  return cola;
});

/// Cuántos registros faltan por subir, en vivo.
final pendientesPorSubirProvider = StreamProvider<int>(
  (ref) => ref.watch(colaSinConexionProvider).vigilarPendientes(),
);

/// Enviador del modo demostración: nunca sube (los registros esperan).
class EnviadorSinServidor implements Enviador {
  const EnviadorSinServidor();

  @override
  Future<ResultadoEnvio> enviar(PeticionEnvio peticion) async =>
      ResultadoEnvio.reintentar;
}
