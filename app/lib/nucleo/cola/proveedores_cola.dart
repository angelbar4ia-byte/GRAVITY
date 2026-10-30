/// Proveedores de Riverpod para la base local y la cola sin conexión.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../base_local/base_local.dart';
import '../contratos/roles.dart';
import '../sesion/proveedores_sesion.dart';
import '../sesion/sesion.dart';
import '../tablet/controlador_tablet.dart';
import '../seguridad/proveedores_seguridad.dart';
import 'bandeja_salida.dart';
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

/// Persona de la cuenta del equipo: la cuenta Casa de la tablet (D14), o
/// `null` si la sesión abierta es de una persona.
String? cuentaDelEquipo(Ref ref) {
  final sesion = ref.read(sesionActualProvider);
  return sesion?.rol == Rol.casa ? sesion!.persona.id : null;
}

/// Permisos de subida de la bandeja de salida (D14, 23/oct/2026).
final bandejaDeSalidaProvider = Provider<BandejaDeSalida>(
  (ref) => BandejaDeSalida(
    ref.watch(almacenSeguroProvider),
    reloj: ref.watch(relojSeguridadProvider),
  ),
);

/// Sube lo de las personas que ya salieron de la tablet, con su propio token.
/// El arranque la fija con Supabase; por omisión (demostración y pruebas), sin
/// ella.
final salidaSinPinProvider = Provider<SalidaSinPin?>((ref) => null);

final colaSinConexionProvider = Provider<ColaSinConexion>((ref) {
  final cola = ColaSinConexion(
    base: ref.watch(baseLocalProvider),
    enviador: ref.watch(enviadorProvider),
    personaQueRegistra: () => ref.read(personaQueRegistraProvider),
    personaConSesion: () => personaConSesionServidor(ref),
    cuentaDelEquipo: () => cuentaDelEquipo(ref),
    salida: ref.watch(salidaSinPinProvider),
    reloj: ref.watch(relojSeguridadProvider),
  );
  ref.onDispose(cola.cerrar);
  return cola;
});

/// Cuántos registros faltan por subir, en vivo.
final pendientesPorSubirProvider = StreamProvider<int>(
  (ref) => ref.watch(colaSinConexionProvider).vigilarPendientes(),
);

/// Cuántos registros caducaron en la bandeja de salida (solo el número).
final caducadosDeLaBandejaProvider = StreamProvider<int>(
  (ref) => ref.watch(colaSinConexionProvider).vigilarCaducadosDeLaBandeja(),
);

/// Lo que dejaron sin subir las personas quitadas de la tablet y se borrará
/// (solo cuántos y cuándo; L1 de la revisión de la Fase 1b).
final purgaDeQuitadosProvider = StreamProvider<PurgaProgramada?>(
  (ref) => ref.watch(colaSinConexionProvider).vigilarPurga(),
);

/// Cómo está la bandeja de salida del equipo (solo números: nada de montos ni
/// de quién registró qué).
class EstadoBandeja {
  const EstadoBandeja({this.porSubir = 0, this.seSubenSolos = 0});

  static const vacio = EstadoBandeja();

  /// Registros pendientes de cualquier persona.
  final int porSubir;

  /// De ellos, los que se subirán solos al haber señal (su persona dejó un
  /// permiso de subida); los demás esperan a que la persona entre con su PIN.
  final int seSubenSolos;

  int get esperanElPin => porSubir - seSubenSolos;
}

final estadoBandejaProvider = FutureProvider<EstadoBandeja>((ref) async {
  final porSubir = ref.watch(pendientesPorSubirProvider).value ?? 0;
  if (porSubir == 0) return EstadoBandeja.vacio;
  final cola = ref.read(colaSinConexionProvider);
  var solos = 0;
  for (final permiso in await ref.read(bandejaDeSalidaProvider).todos()) {
    if (permiso.estado == EstadoPermiso.enEspera) {
      solos += await cola.contarPendientesDe(permiso.personaId);
    }
  }
  return EstadoBandeja(porSubir: porSubir, seSubenSolos: solos);
});

/// Registros de la persona que usa la app ahora y que requieren atención (el
/// servidor no los aceptó). Nadie ve los de otra persona (D5).
final registrosConAtencionProvider = StreamProvider<List<RegistroPendiente>>((
  ref,
) {
  final persona = ref.watch(personaQueRegistraProvider);
  if (persona == null) return Stream.value(const []);
  // En el modo Casa también se ven los registrados en la tablet sin PIN.
  final enModoCasa =
      ref.watch(sesionActualProvider)?.rol == Rol.casa &&
      ref.watch(
        controladorTabletProvider.select((e) => e.usuarioActivo == null),
      );
  return ref
      .watch(colaSinConexionProvider)
      .vigilarAtencion(personaId: persona, deLaTabletCasa: enModoCasa);
});

/// Enviador del modo demostración: nunca sube (los registros esperan, sin
/// contar intentos).
class EnviadorSinServidor implements Enviador {
  const EnviadorSinServidor();

  @override
  Future<ResultadoEnvio> enviar(PeticionEnvio peticion) async =>
      ResultadoEnvio.sinSesion;
}
