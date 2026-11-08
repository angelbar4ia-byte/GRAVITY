/// Repositorio de Alimentación con la sesión real. Vive en la capa de la app
/// para que el módulo no importe `nucleo/sesion` ni la red (guardia D3 de la
/// revisión F4): el módulo solo recibe la interfaz.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../modulos/alimentacion/datos/repositorio.dart';
import '../../modulos/finanzas/datos/fuente_tablas.dart';
import '../../nucleo/sesion/proveedores_sesion.dart';
import '../../nucleo/sesion/servicio_sesion_supabase.dart';
import '../sesion_efectiva.dart';
import 'repositorio_alimentacion_supabase.dart';

/// El repositorio de Supabase con el cliente de la persona activa, o `null` si
/// no hay sesión real con hogar (demostración o sin sesión).
final repositorioAlimentacionSupabaseProvider =
    Provider<RepositorioAlimentacion?>((ref) {
      final sesion = ref.watch(sesionEfectivaProvider);
      final servicio = ref.watch(servicioSesionProvider);
      final hogarId = sesion?.hogarId;
      if (sesion == null ||
          servicio is! ServicioSesionSupabase ||
          hogarId == null) {
        return null;
      }
      return RepositorioAlimentacionSupabase(
        fuente: FuenteTablasSupabase(() => servicio.clienteActivo),
        hogarId: hogarId,
        personaId: sesion.persona.id,
        nombre: sesion.persona.nombre,
      );
    });
