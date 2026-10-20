/// Proveedores de Riverpod para la base local y la cola sin conexión.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../base_local/base_local.dart';
import '../sesion/proveedores_sesion.dart';
import '../sesion/sesion.dart';
import '../tablet/controlador_tablet.dart';
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

/// Persona que registra ahora: en la tablet, la que entró con su PIN; si no,
/// la de la sesión (revisión de la Fase 0, I4).
final personaQueRegistraProvider = Provider<String?>(
  (ref) =>
      ref.watch(
        controladorTabletProvider.select((e) => e.usuarioActivo?.personaId),
      ) ??
      ref.watch(sesionActualProvider)?.persona.id,
);

/// Persona con cuya sesión salen ahora las peticiones al servidor (`null`:
/// nadie). Se lee en cada ronda de la cola.
String? personaConSesionServidor(Ref ref) {
  final servicio = ref.read(servicioSesionProvider);
  if (servicio is SesionesPorPersona) {
    return (servicio as SesionesPorPersona).personaEnServidor;
  }
  return servicio.sesionActual?.persona.id;
}

final colaSinConexionProvider = Provider<ColaSinConexion>((ref) {
  final cola = ColaSinConexion(
    base: ref.watch(baseLocalProvider),
    enviador: ref.watch(enviadorProvider),
    personaQueRegistra: () => ref.read(personaQueRegistraProvider),
    personaConSesion: () => personaConSesionServidor(ref),
  );
  ref.onDispose(cola.detenerAutomatico);
  return cola;
});

/// Cuántos registros faltan por subir, en vivo.
final pendientesPorSubirProvider = StreamProvider<int>(
  (ref) => ref.watch(colaSinConexionProvider).vigilarPendientes(),
);

/// Registros de la persona que usa la app ahora y que requieren atención (el
/// servidor no los aceptó). Nadie ve los de otra persona (D5).
final registrosConAtencionProvider = StreamProvider<List<RegistroPendiente>>((
  ref,
) {
  final persona = ref.watch(personaQueRegistraProvider);
  if (persona == null) return Stream.value(const []);
  return ref
      .watch(colaSinConexionProvider)
      .vigilarAtencion(personaId: persona);
});

/// Enviador del modo demostración: nunca sube (los registros esperan, sin
/// contar intentos).
class EnviadorSinServidor implements Enviador {
  const EnviadorSinServidor();

  @override
  Future<ResultadoEnvio> enviar(PeticionEnvio peticion) async =>
      ResultadoEnvio.sinSesion;
}
