/// Enviador de la cola hacia Supabase: cada `tipo` va a una tabla. Inserta con
/// `ON CONFLICT (id) DO NOTHING`, así un reenvío no duplica y sirve también
/// para el libro solo-agregar (no necesita permiso de actualizar).
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import 'cola_sin_conexion.dart';

class EnviadorSupabase implements Enviador {
  EnviadorSupabase(this._cliente, {required this.tablas});

  final SupabaseClient _cliente;

  /// Tabla de destino por tipo, p. ej. `{'finanzas.gasto': 'movimientos'}`.
  /// Cada módulo agrega la suya en su fase.
  final Map<String, String> tablas;

  @override
  Future<ResultadoEnvio> enviar(PeticionEnvio peticion) async {
    final tabla = tablas[peticion.tipo];
    if (tabla == null) return ResultadoEnvio.rechazado;
    try {
      await _cliente
          .from(tabla)
          .upsert(
            {...peticion.carga, 'id': peticion.id},
            onConflict: 'id',
            ignoreDuplicates: true,
          );
      return ResultadoEnvio.enviado;
    } on PostgrestException catch (error) {
      return clasificarErrorPostgrest(error.code);
    }
    // Errores de red: la excepción sube y la cola reintenta.
  }
}

/// Decide si un error de PostgREST se reintenta o se rechaza.
ResultadoEnvio clasificarErrorPostgrest(String? codigo) {
  if (codigo == null) return ResultadoEnvio.reintentar;
  // Llave foránea: quizá el registro del que depende aún no sube.
  if (codigo == '23503') return ResultadoEnvio.reintentar;
  // Integridad (23…), datos inválidos (22…) y sin permiso por RLS (42501).
  if (codigo.startsWith('23') ||
      codigo.startsWith('22') ||
      codigo == '42501') {
    return ResultadoEnvio.rechazado;
  }
  // Token vencido (PGRST301/303), servidor ocupado y demás: reintentar.
  return ResultadoEnvio.reintentar;
}
