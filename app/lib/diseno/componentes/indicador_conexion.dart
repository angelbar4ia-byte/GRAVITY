import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../valores_diseno.dart';

/// Estado de la conexión de la app con el servidor (E1 de la Fase 4).
///
/// Cada estado lleva texto **y** icono además del color (sección 20).
enum EstadoConexion {
  enLinea('En línea', Icons.cloud_done_outlined),
  sincronizando('Sincronizando', Icons.sync),
  sinConexion('Sin conexión', Icons.cloud_off_outlined);

  const EstadoConexion(this.texto, this.icono);

  final String texto;
  final IconData icono;
}

/// Lo que el indicador necesita saber: el estado y cuántos registros esperan
/// subirse (bandeja de salida).
@immutable
class EstadoConectividad {
  const EstadoConectividad(this.estado, {this.pendientes = 0});

  final EstadoConexion estado;

  /// Registros por subir ("3 por subir"); cero no se muestra.
  final int pendientes;

  @override
  bool operator ==(Object other) =>
      other is EstadoConectividad &&
      other.estado == estado &&
      other.pendientes == pendientes;

  @override
  int get hashCode => Object.hash(estado, pendientes);
}

/// **Firma del proveedor de conectividad real.** Plataforma lo reemplaza en el
/// arranque con la conectividad del equipo y el conteo de la bandeja de salida:
/// `conectividadProvider.overrideWith((ref) => ...)`.
///
/// Mientras no exista, la pantalla principal usa el valor de ejemplo de su
/// resumen (`ResumenGravity.enLinea`), que solo sirve para pruebas y para la
/// demostración; en la app real debe estar conectado.
final conectividadProvider = Provider<EstadoConectividad>(
  (ref) => const EstadoConectividad(EstadoConexion.enLinea),
);

/// Indicador de conexión: punto, icono y texto ("En línea", "Sin conexión",
/// "Sincronizando", y "· 3 por subir" si hay pendientes).
class IndicadorConexion extends StatelessWidget {
  const IndicadorConexion({
    super.key,
    required this.estado,
    this.pendientes = 0,
  });

  final EstadoConexion estado;
  final int pendientes;

  String get texto =>
      pendientes > 0 ? '${estado.texto} · $pendientes por subir' : estado.texto;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final color = switch (estado) {
      EstadoConexion.enLinea => v.exito,
      EstadoConexion.sincronizando => v.acento,
      EstadoConexion.sinConexion => v.alerta,
    };
    return Semantics(
      label: 'Estado: $texto',
      liveRegion: true,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(estado.icono, size: 16, color: color),
          SizedBox(width: v.espacio),
          Flexible(
            child: Text(
              texto,
              key: const ValueKey('indicador-conexion-texto'),
              style: v.lectura(tamano: 13, color: v.textoTenue),
            ),
          ),
        ],
      ),
    );
  }
}

/// El indicador ya conectado a [conectividadProvider].
class IndicadorConexionConectado extends ConsumerWidget {
  const IndicadorConexionConectado({super.key, this.alternativo});

  /// Valor de respaldo (ejemplo) mientras plataforma no entregue el proveedor.
  final EstadoConectividad? alternativo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final EstadoConectividad c = alternativo ?? ref.watch(conectividadProvider);
    return IndicadorConexion(estado: c.estado, pendientes: c.pendientes);
  }
}
