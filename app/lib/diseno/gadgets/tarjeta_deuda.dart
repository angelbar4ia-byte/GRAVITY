import 'package:flutter/material.dart';

import '../componentes/barra_progreso.dart';
import '../componentes/monto_ocultable.dart';
import '../formato.dart';
import '../tema.dart';
import '../valores_diseno.dart';

/// Gadget **Tarjeta de deuda** (Fase 2, sección 8): acreedor, clase, saldo,
/// tasa, interés mensual estimado, próximo pago y avance. Los montos se ocultan
/// solos; la tasa y el avance, que son porcentajes, siempre se ven.
///
/// Nada se inventa: si falta la tasa dice "Captura la tasa" (con
/// [alCapturarTasa], ofrece el botón); si falta el próximo pago no lo dibuja.
/// Una deuda sin saldo se marca **Liquidada** y sugiere archivarla.
class TarjetaDeuda extends StatelessWidget {
  const TarjetaDeuda({
    super.key,
    required this.acreedor,
    required this.clase,
    required this.saldoCentavos,
    this.tasaAnualPuntosBase,
    this.interesMensualCentavos,
    this.proximoPagoTexto,
    this.proximoPagoCentavos,
    this.avance,
    this.liquidada = false,
    this.alTocar,
    this.alCapturarTasa,
  });

  /// "Tarjeta X", "Caja Popular (auto)", "Papá (préstamo)".
  final String acreedor;

  /// "Tarjeta", "Préstamo", "Crédito", "MSI" o "Familiar".
  final String clase;
  final int saldoCentavos;

  /// Tasa anual en puntos base (6000 = 60 %); `null` si no se ha capturado.
  final int? tasaAnualPuntosBase;
  final int? interesMensualCentavos;

  /// "jue 12 nov" (ya con el día hábil ajustado).
  final String? proximoPagoTexto;
  final int? proximoPagoCentavos;

  /// Fracción ya pagada, de 0 a 1; `null` si no se conoce el monto original.
  final double? avance;
  final bool liquidada;
  final VoidCallback? alTocar;
  final VoidCallback? alCapturarTasa;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    final radio = BorderRadius.circular(v.radioMediano);
    final tasa = tasaAnualPuntosBase;
    final textoTasa = tasa == null
        ? 'Captura la tasa'
        : 'Tasa ${formatearPuntosBase(tasa, decimales: 1)}';

    Widget fila(String etiqueta, Widget valor) => Padding(
      padding: EdgeInsets.only(top: e * 0.5),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: e,
        children: [
          Text(etiqueta, style: v.lectura(tamano: 13, color: v.textoTenue)),
          valor,
        ],
      ),
    );

    final contenido = Padding(
      padding: EdgeInsets.all(e * 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: e,
            runSpacing: e * 0.5,
            children: [
              Text(
                acreedor,
                style: v.lectura(
                  tamano: 15,
                  peso: FontWeight.w600,
                  color: v.textoFuerte,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              _Etiqueta(
                texto: liquidada ? 'Liquidada' : clase,
                icono: liquidada ? Icons.check_circle_outline : null,
              ),
            ],
          ),
          SizedBox(height: e),
          MontoOcultable(
            centavos: saldoCentavos,
            estilo: v.numero(
              tamano: 24,
              peso: FontWeight.w600,
              color: v.textoFuerte,
            ),
          ),
          if (liquidada)
            Padding(
              padding: EdgeInsets.only(top: e * 0.5),
              child: Text(
                'Sin saldo: puedes archivarla.',
                style: v.lectura(tamano: 13, color: v.textoTenue),
              ),
            )
          else ...[
            fila(
              textoTasa,
              tasa == null && alCapturarTasa != null
                  ? TextButton(
                      onPressed: alCapturarTasa,
                      child: const Text('Capturar'),
                    )
                  : const SizedBox.shrink(),
            ),
            if (interesMensualCentavos != null)
              fila(
                'Interés al mes (estimado)',
                MontoOcultable(
                  centavos: interesMensualCentavos!,
                  estilo: v.numero(tamano: 13, color: v.texto),
                ),
              ),
            if (proximoPagoTexto != null)
              fila(
                'Próximo pago: $proximoPagoTexto',
                proximoPagoCentavos == null
                    ? const SizedBox.shrink()
                    : MontoOcultable(
                        centavos: proximoPagoCentavos!,
                        estilo: v.numero(
                          tamano: 13,
                          peso: FontWeight.w600,
                          color: v.textoFuerte,
                        ),
                      ),
              ),
            if (avance != null) ...[
              SizedBox(height: e * 1.5),
              BarraProgreso(
                etiqueta: 'Pagado',
                valor: avance!,
                color: v.exito,
                alto: 8,
              ),
            ],
          ],
        ],
      ),
    );

    final partes = [
      acreedor,
      liquidada ? 'liquidada' : clase,
      if (!liquidada) textoTasa.toLowerCase(),
      if (proximoPagoTexto != null && !liquidada)
        'próximo pago $proximoPagoTexto',
    ];
    return Semantics(
      container: true,
      button: alTocar != null,
      label: 'Deuda: ${partes.join(', ')}',
      onTap: alTocar,
      child: Material(
        color: v.panel,
        shape: RoundedRectangleBorder(
          borderRadius: radio,
          side: BorderSide(color: v.borde, width: v.grosorBorde),
        ),
        clipBehavior: Clip.antiAlias,
        child: alTocar == null
            ? contenido
            : InkWell(
                onTap: alTocar,
                borderRadius: radio,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: zonaTactilMinima,
                  ),
                  child: contenido,
                ),
              ),
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta({required this.texto, this.icono});

  final String texto;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: v.borde, width: v.grosorBorde),
        borderRadius: BorderRadius.circular(v.radioChico),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: v.espacio, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icono != null) ...[
              Icon(icono, size: 14, color: v.exito),
              SizedBox(width: v.espacio * 0.5),
            ],
            Flexible(
              child: Text(
                texto,
                style: v.lectura(
                  tamano: 12,
                  peso: FontWeight.w600,
                  color: v.textoFuerte,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
