import 'package:flutter/material.dart';

import '../tema.dart';
import '../valores_diseno.dart';

/// Estado **cargando** de una pantalla: indicador y mensaje, anunciado al
/// lector de pantalla. Con "reducir movimiento" el indicador queda quieto.
class EstadoCargando extends StatelessWidget {
  const EstadoCargando({super.key, this.mensaje = 'Cargando…'});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final quieto = MediaQuery.disableAnimationsOf(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(v.espacio * 3),
        child: Semantics(
          liveRegion: true,
          label: mensaje,
          excludeSemantics: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: v.acento,
                  value: quieto ? 0.35 : null,
                ),
              ),
              SizedBox(height: v.espacio * 1.5),
              Text(
                mensaje,
                textAlign: TextAlign.center,
                style: v.lectura(tamano: 14, color: v.textoTenue),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Estado de **error** o **sin conexión** de una pantalla: mensaje claro, sin
/// culpa, y un solo botón *Reintentar* de 48 dp (nunca reintenta solo).
class EstadoError extends StatelessWidget {
  const EstadoError({
    super.key,
    required this.mensaje,
    this.detalle,
    this.sinConexion = false,
    this.alReintentar,
  });

  final String mensaje;
  final String? detalle;

  /// Cambia el icono (y el aviso al lector) por el de "sin conexión".
  final bool sinConexion;
  final VoidCallback? alReintentar;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(e * 3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              sinConexion ? Icons.cloud_off_outlined : Icons.error_outline,
              size: 40,
              color: sinConexion ? v.textoTenue : v.alerta,
              semanticLabel: sinConexion ? 'Sin conexión' : 'Error',
            ),
            SizedBox(height: e * 1.5),
            Semantics(
              liveRegion: true,
              child: Text(
                mensaje,
                textAlign: TextAlign.center,
                style: v.lectura(
                  tamano: 17,
                  peso: FontWeight.w600,
                  color: v.textoFuerte,
                ),
              ),
            ),
            if (detalle != null) ...[
              SizedBox(height: e),
              Text(
                detalle!,
                textAlign: TextAlign.center,
                style: v.lectura(tamano: 14, color: v.textoTenue),
              ),
            ],
            if (alReintentar != null) ...[
              SizedBox(height: e * 2),
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: zonaTactilMinima,
                  minWidth: zonaTactilMinima,
                ),
                child: OutlinedButton(
                  onPressed: alReintentar,
                  child: const Text('Reintentar'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
