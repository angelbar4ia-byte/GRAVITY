/// **Casillas de clima** (4.3, PB-09): cinco casillas de un toque y una
/// respuesta fija. Ninguna bloquea nada: «Posible lluvia» y «Mucho calor»
/// sugieren, no obligan. La casilla se guarda en la salida para el historial;
/// el enlace de clima, **no** (puede incluir un lugar). Funcionan siempre,
/// también sin red. *Ver el clima* abre la app que la persona ya usa.
library;

import 'package:flutter/material.dart';

import '../componentes/tarjeta_modulo.dart';
import '../valores_diseno.dart';
import 'piezas_bici.dart';
import 'textos_bici.dart';
import 'tipos_bici.dart';

/// Las cinco casillas, con la respuesta del catálogo.
class CasillasClima extends StatelessWidget {
  const CasillasClima({
    super.key,
    this.seleccionado,
    this.respuestaTexto,
    this.alElegir,
    this.alVerClima,
    this.hayEnlace = true,
    this.estado = EstadoVistaBici.listo,
    this.mensajes = const MensajesEstadoBici(
      cargando: 'Cargando el clima…',
      sinConexion: 'Sin conexión. Las casillas funcionan igual.',
      error: 'No se pudo cargar esto. Las casillas siguen aquí.',
    ),
    this.alReintentar,
    this.conTarjeta = true,
  });

  /// La casilla elegida; `null` si todavía no se elige.
  final ClimaBici? seleccionado;

  /// La respuesta fija del catálogo para la casilla elegida.
  final String? respuestaTexto;

  /// Elegir una casilla; elegir la misma otra vez la quita (recibe `null`).
  final ValueChanged<ClimaBici?>? alElegir;

  /// *Ver el clima*: abre la app o la página que la persona guardó.
  final VoidCallback? alVerClima;

  /// Si ya hay un enlace de clima guardado.
  final bool hayEnlace;
  final EstadoVistaBici estado;
  final MensajesEstadoBici mensajes;
  final VoidCallback? alReintentar;

  /// Dentro de otra tarjeta (la hoja de registro) se dibuja sin marco.
  final bool conTarjeta;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    Widget cuerpo;
    if (estado != EstadoVistaBici.listo && estado != EstadoVistaBici.vacio) {
      cuerpo = CuerpoEstadoBici(
        estado: estado,
        mensajes: mensajes,
        alReintentar: alReintentar,
      );
    } else {
      cuerpo = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: e,
            runSpacing: e,
            children: [
              for (final c in ClimaBici.values)
                OpcionBici(
                  texto: c.texto,
                  icono: c.icono,
                  seleccionada: seleccionado == c,
                  etiquetaAccesible: 'Clima: ${c.texto}',
                  alTocar: alElegir == null
                      ? null
                      : () => alElegir!(seleccionado == c ? null : c),
                ),
            ],
          ),
          if (respuestaTexto != null && seleccionado != null) ...[
            SizedBox(height: e * 1.5),
            Semantics(
              container: true,
              liveRegion: true,
              label: respuestaTexto,
              excludeSemantics: true,
              child: Text(
                respuestaTexto!,
                key: const ValueKey('clima-respuesta'),
                style: v.lectura(tamano: 14.5, color: v.texto),
              ),
            ),
          ],
          if (alVerClima != null) ...[
            SizedBox(height: e * 1.5),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                onPressed: hayEnlace ? alVerClima : null,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(zonaTactilBici, 56),
                ),
                icon: const Icon(Icons.cloud_outlined, size: 20),
                label: Text(
                  hayEnlace
                      ? TextosBici.verElClima
                      : '${TextosBici.verElClima} (sin enlace)',
                ),
              ),
            ),
          ],
        ],
      );
    }
    if (!conTarjeta) return cuerpo;
    return TarjetaModulo(
      titulo: 'Clima',
      icono: Icons.wb_sunny_outlined,
      child: cuerpo,
    );
  }
}
