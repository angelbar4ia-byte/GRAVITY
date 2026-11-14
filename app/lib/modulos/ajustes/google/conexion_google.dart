/// Conectar la cuenta de Google (Gmail y Calendar) desde Ajustes.
///
/// La app no lleva claves ni tokens de Google: pide al servidor
/// (`gravity-asistente`, acción `google_url`) la dirección de autorización,
/// la abre en el navegador y, al volver, consulta si la cuenta quedó
/// conectada. El servidor guarda el token cifrado.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../nucleo/contratos/roles.dart';
import '../../../nucleo/permisos/permisos.dart';
import '../desarrollador/abrir_swagger.dart' show AbrirUrl, abrirConNavegador;

enum AmbitoGoogle { personal, casa }

class EstadoGoogle {
  const EstadoGoogle({required this.conectada, this.correo});
  final bool conectada;
  final String? correo;
}

class ErrorConexionGoogle implements Exception {
  const ErrorConexionGoogle(this.mensaje);
  final String mensaje;
}

/// El botón de la cuenta personal: dueño, coadministrador y familiar. Ni la
/// cuidadora ni Casa, ni la cuenta maestra de solo lectura (D5, D19).
bool puedeConectarGooglePersonal(Rol rol, {bool esMaestra = false}) =>
    !esSoloLectura(rol, esMaestra: esMaestra) &&
    (rol == Rol.dueno || rol == Rol.coadministrador || rol == Rol.familiar);

/// El botón de la cuenta de la casa: solo el dueño.
bool puedeConectarGoogleCasa(Rol rol, {bool esMaestra = false}) =>
    rol == Rol.dueno && !esSoloLectura(rol, esMaestra: esMaestra);

abstract interface class ConexionGoogle {
  /// Dirección de Google para autorizar la cuenta de [ambito].
  Future<Uri> urlDeConexion(AmbitoGoogle ambito);

  Future<EstadoGoogle> estado(AmbitoGoogle ambito);
}

class ConexionGoogleSupabase implements ConexionGoogle {
  ConexionGoogleSupabase(this._cliente);
  final SupabaseClient Function() _cliente;

  @override
  Future<Uri> urlDeConexion(AmbitoGoogle ambito) async {
    try {
      final r = await _cliente().functions.invoke(
        'gravity-asistente',
        body: {'accion': 'google_url', 'ambito': ambito.name},
      );
      final d = r.data;
      final url = d is Map ? d['url'] : null;
      final uri = url is String ? Uri.tryParse(url) : null;
      if (uri == null || uri.scheme != 'https') {
        throw const ErrorConexionGoogle(
          'GRAVITY respondió algo que no entendí.',
        );
      }
      return uri;
    } on FunctionException catch (e) {
      final d = e.details;
      throw ErrorConexionGoogle(
        d is Map && d['mensaje'] is String
            ? d['mensaje'] as String
            : 'No pude conectar con Google ahora. Inténtalo más tarde.',
      );
    } on ErrorConexionGoogle {
      rethrow;
    } catch (_) {
      throw const ErrorConexionGoogle(
        'No pude comunicarme con GRAVITY. Revisa tu conexión.',
      );
    }
  }

  @override
  Future<EstadoGoogle> estado(AmbitoGoogle ambito) async {
    try {
      final filas = await _cliente()
          .from('google_cuentas')
          .select('correo')
          .eq('ambito', ambito.name)
          .limit(1);
      if (filas.isEmpty) return const EstadoGoogle(conectada: false);
      return EstadoGoogle(
        conectada: true,
        correo: filas.first['correo'] as String?,
      );
    } catch (_) {
      throw const ErrorConexionGoogle('No pude revisar la conexión.');
    }
  }
}

class ConexionGoogleNoDisponible implements ConexionGoogle {
  const ConexionGoogleNoDisponible();

  @override
  Future<Uri> urlDeConexion(AmbitoGoogle ambito) async =>
      throw const ErrorConexionGoogle(
        'Conectar Google necesita conexión con el servidor de GRAVITY.',
      );

  @override
  Future<EstadoGoogle> estado(AmbitoGoogle ambito) async =>
      const EstadoGoogle(conectada: false);
}

final conexionGoogleProvider = Provider<ConexionGoogle>((ref) {
  try {
    Supabase.instance.client;
    return ConexionGoogleSupabase(() => Supabase.instance.client);
  } catch (_) {
    return const ConexionGoogleNoDisponible();
  }
});

/// Cómo se abre la dirección (las pruebas lo cambian).
final abrirUrlGoogleProvider = Provider<AbrirUrl>((ref) => abrirConNavegador);
