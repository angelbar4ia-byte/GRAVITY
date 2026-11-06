import 'package:flutter/material.dart';

import '../valores_diseno.dart';

/// Estado vacío con un mensaje claro y una sola acción sugerida (principio 8 y
/// sección 19).
class EstadoVacio extends StatelessWidget {
  const EstadoVacio({
    super.key,
    required this.mensaje,
    this.detalle,
    this.icono = Icons.inbox_outlined,
    this.textoAccion,
    this.alAccionar,
  }) : assert(
         (textoAccion == null) == (alAccionar == null),
         'La acción necesita texto y función.',
       );

  final String mensaje;
  final String? detalle;
  final IconData icono;
  final String? textoAccion;
  final VoidCallback? alAccionar;

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
            Icon(icono, size: 40, color: v.textoTenue),
            SizedBox(height: e * 1.5),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: v.lectura(
                tamano: 17,
                peso: FontWeight.w600,
                color: v.textoFuerte,
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
            if (textoAccion != null) ...[
              SizedBox(height: e * 2),
              OutlinedButton(onPressed: alAccionar, child: Text(textoAccion!)),
            ],
          ],
        ),
      ),
    );
  }
}
