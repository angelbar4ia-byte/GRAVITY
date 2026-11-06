import 'package:flutter/material.dart';

import '../valores_diseno.dart';

/// Dónde se ve un aviso (Fase 2, sección 6.3).
enum SuperficieAviso {
  /// Pantalla bloqueada del teléfono: título y canal, sin cuerpo.
  bloqueo('Pantalla bloqueada'),

  /// Pulsera: el título y una vibración; sin botones.
  pulsera('Pulsera');

  const SuperficieAviso(this.etiqueta);

  final String etiqueta;
}

/// Vista previa de **cómo se ve un aviso** en la pantalla bloqueada o en la
/// pulsera. Es discreta a propósito: lleva el título genérico del catálogo
/// ("Tienes un pago próximo") y **nunca cifras**, nombres ni cuerpo.
///
/// En depuración falla si el [titulo] trae dígitos o `$`: una cifra en una
/// notificación es un error de D3, no un detalle de diseño.
class VistaPreviaAviso extends StatelessWidget {
  VistaPreviaAviso({
    super.key,
    required this.titulo,
    required this.superficie,
    this.canal = 'Finanzas · Urgentes',
  }) : assert(
         !RegExp(r'[\d$]').hasMatch(titulo),
         'Un aviso en pantalla bloqueada o pulsera no lleva cifras: "$titulo"',
       );

  final String titulo;
  final SuperficieAviso superficie;

  /// Canal de Android donde llega.
  final String canal;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    final pulsera = superficie == SuperficieAviso.pulsera;
    return Semantics(
      container: true,
      label: 'Así se ve en ${superficie.etiqueta.toLowerCase()}',
      value: pulsera ? '$titulo, con vibración' : '$titulo, canal $canal',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            superficie.etiqueta.toUpperCase(),
            style: v.etiquetaPanel(tamano: 11.5),
          ),
          SizedBox(height: e * 0.75),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Color.lerp(v.fondo, v.panel, 0.6),
              border: Border.all(color: v.borde),
              borderRadius: BorderRadius.circular(
                pulsera ? v.radioGrande * 2 : v.radioGrande,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(e * 1.5),
              child: pulsera
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.vibration, size: 22, color: v.acento),
                        SizedBox(width: e),
                        Flexible(
                          child: Text(
                            titulo,
                            style: v.lectura(
                              tamano: 14,
                              peso: FontWeight.w600,
                              color: v.textoFuerte,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.notifications_none,
                              size: 16,
                              color: v.textoTenue,
                            ),
                            SizedBox(width: e * 0.75),
                            Flexible(
                              child: Text(
                                canal,
                                style: v.lectura(
                                  tamano: 12,
                                  color: v.textoTenue,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: e * 0.75),
                        Text(
                          titulo,
                          style: v.lectura(
                            tamano: 15,
                            peso: FontWeight.w600,
                            color: v.textoFuerte,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
