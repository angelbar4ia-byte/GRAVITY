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

import '../../modulos/alimentacion/casos_uso/sugerir_platillos.dart';
import '../../modulos/alimentacion/datos/modelos.dart';
import '../../modulos/gravity/conversacion/cliente_asistente.dart';
import '../../nucleo/sesion/proveedores_sesion.dart';
import '../../nucleo/sesion/servicio_sesion_supabase.dart';
import '../sesion_efectiva.dart';

/// Usa el único cliente de IA de la app ([ClienteAsistente], acción
/// `sugerir_recetas`); aquí no hay red propia.
class SugeridorRecetasSupabase implements SugeridorRecetas {
  SugeridorRecetasSupabase(this._cliente);

  final ClienteAsistente _cliente;

  @override
  Future<List<Platillo>> sugerir(ContextoSugerencia contexto) async {
    final Object? r;
    try {
      r = await _cliente.sugerirRecetas(contexto.aJson());
    } on ErrorAsistente catch (e) {
      throw ErrorSugerencia(e.mensaje);
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
    ClienteAsistenteSupabase(() => servicio.clienteActivo),
  );
});
