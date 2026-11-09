/// "Sugerir con IA" de Alimentación (Fase 8) con la función de servidor del
/// asistente (`gravity-asistente`). Vive en `app/` por la guardia D3: el
/// módulo no importa red ni sesión, solo el contrato [SugeridorRecetas].
///
/// Lo único que viaja es el [ContextoSugerencia]: nombres de ingredientes,
/// cantidades aproximadas y las preferencias que la persona escribió. La
/// clave del proveedor de IA vive solo en el servidor.
///
/// Contrato que espera del servidor (a confirmar con asistente):
/// - Petición: `{"accion": "sugerir_recetas", "contexto": {"ingredientes":
///   [{"nombre", "cantidad_aprox", "unidad"}], "preferencias": "..."}}`.
/// - Respuesta: `{"recetas": [{"titulo", "porciones", "pasos": [...],
///   "ingredientes": [{"nombre", "cantidad", "unidad", "pasillo"?}]}]}`
///   (el formato del archivo de recetas, versión 1). La app la valida como un
///   archivo importado; nada se guarda sin confirmación.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../modulos/alimentacion/casos_uso/sugerir_platillos.dart';
import '../../modulos/alimentacion/datos/modelos.dart';
import '../../nucleo/sesion/proveedores_sesion.dart';
import '../../nucleo/sesion/servicio_sesion_supabase.dart';
import '../sesion_efectiva.dart';

/// Llama a la función con [cuerpo] y devuelve su respuesta ya decodificada.
typedef InvocadorSugerencia =
    Future<Object?> Function(Map<String, Object?> cuerpo);

class SugeridorRecetasSupabase implements SugeridorRecetas {
  SugeridorRecetasSupabase(this._invocar);

  final InvocadorSugerencia _invocar;

  /// El cuerpo exacto que sale hacia la IA para [contexto].
  static Map<String, Object?> cuerpoDe(ContextoSugerencia contexto) => {
    'accion': 'sugerir_recetas',
    'contexto': contexto.aJson(),
  };

  @override
  Future<List<Platillo>> sugerir(ContextoSugerencia contexto) async {
    final Object? r;
    try {
      r = await _invocar(cuerpoDe(contexto));
    } on FunctionException catch (e) {
      final d = e.details;
      throw ErrorSugerencia(
        d is Map && d['mensaje'] is String
            ? d['mensaje'] as String
            : 'GRAVITY no está disponible ahora. Inténtalo más tarde.',
      );
    } on ErrorSugerencia {
      rethrow;
    } catch (_) {
      throw const ErrorSugerencia(
        'No pude comunicarme con GRAVITY. Revisa tu conexión.',
      );
    }
    return recetasSugeridas(r);
  }
}

/// El sugeridor con el cliente de la persona activa, o `null` sin sesión real.
final sugeridorRecetasSupabaseProvider = Provider<SugeridorRecetas?>((ref) {
  final sesion = ref.watch(sesionEfectivaProvider);
  final servicio = ref.watch(servicioSesionProvider);
  if (sesion == null || servicio is! ServicioSesionSupabase) return null;
  return SugeridorRecetasSupabase(
    (cuerpo) async => (await servicio.clienteActivo.functions.invoke(
      'gravity-asistente',
      body: cuerpo,
    )).data,
  );
});
