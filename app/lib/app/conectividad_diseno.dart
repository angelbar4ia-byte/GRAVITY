/// Puente entre la conectividad real del equipo (`nucleo/conectividad`) y el
/// indicador de conexión de diseño (`conectividadProvider`): sin red dice "Sin
/// conexión"; con red y registros por subir, "Sincronizando"; los "N por
/// subir" se muestran en ambos casos.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../diseno/componentes/indicador_conexion.dart' as diseno;
import '../nucleo/conectividad/conectividad.dart' as real;

final conectividadRealDeDisenoProvider = Provider<diseno.EstadoConectividad>((
  ref,
) {
  final r = ref.watch(real.estadoConexionProvider);
  return diseno.EstadoConectividad(switch (r.estado) {
    real.EstadoConexion.enLinea => diseno.EstadoConexion.enLinea,
    real.EstadoConexion.sincronizando => diseno.EstadoConexion.sincronizando,
    real.EstadoConexion.sinConexion ||
    real.EstadoConexion.porSubir => diseno.EstadoConexion.sinConexion,
  }, pendientes: r.porSubir);
});
