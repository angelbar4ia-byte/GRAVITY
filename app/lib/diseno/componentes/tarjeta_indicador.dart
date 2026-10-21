import 'package:flutter/material.dart';

import '../formato.dart';
import '../valores_diseno.dart';
import 'etiqueta_panel.dart';
import 'semaforo.dart';

/// Indicador del tablero de Finanzas (remanente, carga de deuda, cumplimiento
/// del presupuesto, patrimonio): etiqueta, cifra grande de ancho fijo y, si
/// aplica, su semáforo **con texto** y un detalle ("Meta 20 %").
///
/// [valor] llega ya formateado (`formatearPuntosBase`, `formatearCentavos`).
/// Con [oculto] la cifra se cambia por `$ • • • • •` (úsalo en los montos; un
/// porcentaje del ingreso puede quedar visible).
class TarjetaIndicador extends StatelessWidget {
  const TarjetaIndicador({
    super.key,
    required this.etiqueta,
    required this.valor,
    this.oculto = false,
    this.estado,
    this.textoEstado,
    this.detalle,
    this.alTocar,
  });

  final String etiqueta;
  final String valor;
  final bool oculto;
  final EstadoSemaforo? estado;

  /// Texto del semáforo; por defecto, el del estado ("En verde").
  final String? textoEstado;
  final String? detalle;
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    final radio = BorderRadius.circular(v.radioMediano);
    final estado = this.estado;
    final textoSemaforo = estado == null
        ? null
        : (textoEstado ?? estado.etiqueta);

    Widget contenido = Padding(
      padding: EdgeInsets.all(e * 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          EtiquetaPanel(etiqueta, tamano: 11.5),
          SizedBox(height: e),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              oculto ? montoOculto : valor,
              style: v.numero(
                tamano: v.densidad == Densidad.grande ? 28 : 24,
                peso: FontWeight.w600,
                color: v.textoFuerte,
              ),
              maxLines: 1,
            ),
          ),
          if (estado != null) ...[
            SizedBox(height: e * 0.75),
            Semaforo(estado: estado, etiqueta: textoSemaforo, tamanoTexto: 13),
          ],
          if (detalle != null) ...[
            SizedBox(height: e * 0.5),
            Text(
              detalle!,
              style: v.lectura(tamano: 13, color: v.textoTenue),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );

    if (alTocar != null) {
      contenido = InkWell(
        onTap: alTocar,
        borderRadius: radio,
        child: contenido,
      );
    }

    return Semantics(
      container: true,
      button: alTocar != null,
      label: etiqueta,
      value: [oculto ? 'oculto' : valor, ?textoSemaforo, ?detalle].join(', '),
      excludeSemantics: true,
      onTap: alTocar,
      child: Material(
        color: v.panel,
        shape: RoundedRectangleBorder(
          borderRadius: radio,
          side: BorderSide(color: v.borde),
        ),
        clipBehavior: Clip.antiAlias,
        child: contenido,
      ),
    );
  }
}
