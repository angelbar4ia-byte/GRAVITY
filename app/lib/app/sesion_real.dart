/// Si hay sesión real con Supabase (F4-A6). Vive en la capa de la app para
/// que Alimentación no importe `nucleo/sesion` (regla de la revisión F4).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../nucleo/sesion/proveedores_sesion.dart';
import '../nucleo/sesion/servicio_sesion_supabase.dart';
import 'sesion_efectiva.dart';

/// `true` con sesión real (Supabase): no se muestran datos de ejemplo.
final sesionRealSupabaseProvider = Provider<bool>((ref) {
  final sesion = ref.watch(sesionEfectivaProvider);
  return sesion != null &&
      ref.watch(servicioSesionProvider) is ServicioSesionSupabase;
});
