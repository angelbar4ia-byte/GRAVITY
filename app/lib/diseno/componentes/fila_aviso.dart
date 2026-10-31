import 'package:flutter/material.dart';

import '../tema.dart';
import '../valores_diseno.dart';
import 'chip_nivel_alerta.dart';

/// Fila de la **Bandeja de avisos** (Fase 2, sección 6.1): nivel (icono +
/// texto), título del catálogo, libro y fecha. No lleva cifras: el detalle con
/// montos (ocultos hasta mostrarlos) vive en la pantalla del aviso. Los avisos
/// sin leer van en negritas **y** con un punto.
class FilaAviso extends StatelessWidget {
  const FilaAviso({
    super.key,
    required this.nivel,
    required this.titulo,
    required this.libro,
    required this.cuandoTexto,
    this.leido = false,
    this.alTocar,
  });

  final NivelAlerta nivel;

  /// "Pago de deuda", "Fondo de emergencia bajo".
  final String titulo;

  /// Libro al que pertenece ("Mi libro", "Gastos de la casa").
  final String libro;

  /// "hoy 8:00", "ayer".
  final String cuandoTexto;
  final bool leido;
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    final contenido = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: zonaTactilMinima),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: e * 1.5, vertical: e),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: e * 0.75, right: e),
              child: Icon(
                leido ? Icons.circle_outlined : Icons.circle,
                size: 10,
                color: leido ? v.textoTenue : v.acento,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: v.lectura(
                      tamano: 15,
                      peso: leido ? FontWeight.w400 : FontWeight.w700,
                      color: v.textoFuerte,
                    ),
                  ),
                  SizedBox(height: e * 0.5),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: e,
                    runSpacing: e * 0.5,
                    children: [
                      ChipNivelAlerta(nivel: nivel),
                      Text(
                        '$libro · $cuandoTexto',
                        style: v.lectura(tamano: 12.5, color: v.textoTenue),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return Semantics(
      container: true,
      button: alTocar != null,
      label:
          '${leido ? '' : 'Sin leer. '}${nivel.etiqueta}: $titulo, '
          '$libro, $cuandoTexto',
      excludeSemantics: true,
      onTap: alTocar,
      child: alTocar == null
          ? contenido
          : InkWell(onTap: alTocar, child: contenido),
    );
  }
}
