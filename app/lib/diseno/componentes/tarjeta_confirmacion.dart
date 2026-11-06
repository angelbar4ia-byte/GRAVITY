import 'package:flutter/material.dart';

import '../tema.dart';
import '../valores_diseno.dart';
import 'etiqueta_panel.dart';

/// Un dato de lo que se va a guardar ("Categoría: Alimentación").
@immutable
class DetalleConfirmacion {
  const DetalleConfirmacion(this.etiqueta, this.valor);

  final String etiqueta;
  final String valor;
}

/// Tarjeta de confirmación (principio 6 y sección 19): toda escritura que llega
/// por voz o por GRAVITY se muestra aquí antes de guardarse.
class TarjetaConfirmacion extends StatelessWidget {
  const TarjetaConfirmacion({
    super.key,
    required this.titulo,
    required this.alConfirmar,
    required this.alCancelar,
    this.descripcion,
    this.detalles = const [],
    this.origen = 'GRAVITY',
    this.textoConfirmar = 'Confirmar',
    this.textoCancelar = 'Cancelar',
  });

  /// Qué se va a hacer ("Registrar gasto").
  final String titulo;
  final String? descripcion;
  final List<DetalleConfirmacion> detalles;

  /// De dónde llegó la orden ("GRAVITY", "Voz").
  final String origen;
  final String textoConfirmar;
  final String textoCancelar;
  final VoidCallback alConfirmar;
  final VoidCallback alCancelar;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Confirmar: $titulo',
      child: Material(
        color: v.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(v.radioMediano),
          side: BorderSide(color: v.acento, width: 1.5),
        ),
        child: Padding(
          padding: EdgeInsets.all(e * 2.5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.task_alt, size: 18, color: v.acento),
                  SizedBox(width: e),
                  Expanded(
                    child: EtiquetaPanel('Confirma · $origen', color: v.acento),
                  ),
                ],
              ),
              SizedBox(height: e * 1.5),
              Text(titulo, style: v.titulo(tamano: 20)),
              if (descripcion != null) ...[
                SizedBox(height: e),
                Text(descripcion!, style: v.lectura(color: v.textoTenue)),
              ],
              if (detalles.isNotEmpty) ...[
                SizedBox(height: e * 1.5),
                for (final d in detalles)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: e * 0.5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            d.etiqueta,
                            style: v.lectura(tamano: 14, color: v.textoTenue),
                          ),
                        ),
                        SizedBox(width: e),
                        Expanded(
                          flex: 3,
                          child: Text(
                            d.valor,
                            style: v.lectura(
                              tamano: 15,
                              peso: FontWeight.w600,
                              color: v.textoFuerte,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              SizedBox(height: e * 2.5),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: e * 1.5,
                runSpacing: e,
                children: [
                  OutlinedButton(
                    onPressed: alCancelar,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(120, zonaTactilMinima),
                    ),
                    child: Text(textoCancelar),
                  ),
                  FilledButton(
                    onPressed: alConfirmar,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(120, zonaTactilMinima),
                    ),
                    child: Text(textoConfirmar),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
