/// Enviador de la cola hacia Supabase: cada `tipo` va a una tabla. Inserta con
/// `ON CONFLICT (id) DO NOTHING`, así un reenvío no duplica y sirve también
/// para el libro solo-agregar (no necesita permiso de actualizar).
///
/// Revisión de la Fase 0 (I4): sin sesión no envía (la petición saldría con la
/// llave pública y el servidor la negaría); los errores de red se reintentan,
/// y lo que el servidor no acepta queda en "requiere atención".
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../sesion/errores_red.dart';
import 'cola_sin_conexion.dart';

class EnviadorSupabase implements Enviador {
  /// Envía siempre con [cliente].
  EnviadorSupabase(SupabaseClient cliente, {required this.tablas})
    : _cliente = (() => cliente);

  /// Envía con el cliente que devuelva [cliente] en cada envío: en la tablet,
  /// el de la persona que entró con su PIN (I6).
  EnviadorSupabase.dinamico(
    SupabaseClient Function() cliente, {
    required this.tablas,
  }) : _cliente = cliente;

  final SupabaseClient Function() _cliente;

  /// Tabla de destino por tipo, p. ej. `{'finanzas.gasto': 'movimientos'}`.
  /// Cada módulo agrega la suya en su fase.
  final Map<String, String> tablas;

  @override
  Future<ResultadoEnvio> enviar(PeticionEnvio peticion) async {
    final cliente = _cliente();
    if (cliente.auth.currentSession == null) return ResultadoEnvio.sinSesion;
    final tabla = tablas[peticion.tipo];
    if (tabla == null) {
      throw RechazoEnvio(
        'La app no sabe a dónde subir "${peticion.tipo}" (falta su tabla).',
      );
    }
    try {
      await cliente
          .from(tabla)
          .upsert(
            {...peticion.carga, 'id': peticion.id},
            onConflict: 'id',
            ignoreDuplicates: true,
          );
      return ResultadoEnvio.enviado;
    } on PostgrestException catch (error) {
      final resultado = clasificarErrorPostgrest(error.code);
      if (resultado == ResultadoEnvio.rechazado) {
        throw RechazoEnvio(_motivo(error));
      }
      return resultado;
    } catch (error) {
      // Sin red: la cola reintenta con espera creciente. Cualquier otro error
      // (no es de red) requiere atención.
      if (esErrorDeRed(error)) rethrow;
      throw RechazoEnvio('Error al subir: $error');
    }
  }

  static String _motivo(PostgrestException error) => switch (error.code) {
    '42501' => 'Sin permiso para guardarlo (42501).',
    final codigo => 'El servidor no lo aceptó (${codigo ?? 'sin código'}): '
        '${error.message}',
  };
}

/// Decide si un error de PostgREST se reintenta o se rechaza (requiere
/// atención). Solo se reintenta lo pasajero.
ResultadoEnvio clasificarErrorPostgrest(String? codigo) {
  if (codigo == null) return ResultadoEnvio.reintentar;
  // Llave foránea: quizá el registro del que depende aún no sube.
  if (codigo == '23503') return ResultadoEnvio.reintentar;
  // Token vencido o inválido (PGRST301 a 303): se renueva y se reintenta.
  if (codigo.startsWith('PGRST3')) return ResultadoEnvio.reintentar;
  // Sin conexión con la base (PGRST000 a 003), servidor ocupado o caído.
  if (codigo.startsWith('PGRST0')) return ResultadoEnvio.reintentar;
  // Estado HTTP sin cuerpo de PostgREST (3 cifras; los de PostgreSQL son 5).
  final http = codigo.length == 3 ? int.tryParse(codigo) : null;
  if (http != null && (http >= 500 || http == 408 || http == 429)) {
    return ResultadoEnvio.reintentar;
  }
  // PostgreSQL: conexión (08…), conflicto de serialización o bloqueo
  // (40001, 40P01), recursos (53…), tiempo agotado (57014) o arranque (57P03).
  if (codigo.startsWith('08') ||
      codigo == '40001' ||
      codigo == '40P01' ||
      codigo.startsWith('53') ||
      codigo == '57014' ||
      codigo == '57P03') {
    return ResultadoEnvio.reintentar;
  }
  // Integridad (23…), datos inválidos (22…), sin permiso por RLS (42501),
  // columna o tabla desconocida (42…, PGRST2…) y demás: requiere atención.
  return ResultadoEnvio.rechazado;
}
