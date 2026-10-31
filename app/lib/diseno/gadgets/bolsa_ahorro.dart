import 'package:flutter/material.dart';

import '../componentes/barra_progreso.dart';
import '../componentes/monto_ocultable.dart';
import '../componentes/semaforo.dart';
import '../tema.dart';
import '../valores_diseno.dart';

/// Tipos de bolsa (Fase 2, regla 15).
enum TipoBolsa {
  fondo('Fondo de emergencia', Icons.shield_outlined),
  reserva('Reserva', Icons.savings_outlined),
  metaConFecha('Meta con fecha', Icons.flag_outlined),
  metaSinFecha('Meta', Icons.outlined_flag);

  const TipoBolsa(this.etiqueta, this.icono);

  final String etiqueta;
  final IconData icono;
}

/// Gadget **Bolsa de ahorro** (Fase 2, sección 8): nombre y tipo, saldo, barra
/// de progreso hacia la meta (el porcentaje siempre se ve), lo **pendiente**
/// ("sin intereses ni castigo"), la proyección ("llegarás a $X el día Y") y,
/// para el fondo, su semáforo con texto. Los montos se ocultan solos.
class BolsaAhorro extends StatelessWidget {
  const BolsaAhorro({
    super.key,
    required this.nombre,
    required this.tipo,
    required this.saldoCentavos,
    this.metaCentavos,
    this.pendienteCentavos = 0,
    this.proyeccionCentavos,
    this.proyeccionFechaTexto,
    this.estado,
    this.textoEstado,
    this.alTocar,
  });

  final String nombre;
  final TipoBolsa tipo;
  final int saldoCentavos;

  /// `null` o cero: una meta sin monto (solo se ve el saldo).
  final int? metaCentavos;

  /// Lo no aportado de semanas pasadas (sin intereses ni castigo).
  final int pendienteCentavos;
  final int? proyeccionCentavos;

  /// "12 de marzo".
  final String? proyeccionFechaTexto;
  final EstadoSemaforo? estado;
  final String? textoEstado;
  final VoidCallback? alTocar;

  bool get conMeta => (metaCentavos ?? 0) > 0;

  /// Fracción de la meta, de 0 a 1.
  double get avance =>
      conMeta ? (saldoCentavos / metaCentavos!).clamp(0.0, 1.0) : 0;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    final radio = BorderRadius.circular(v.radioMediano);

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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(tipo.icono, size: 18, color: v.textoTenue),
                  SizedBox(width: e),
                  Flexible(
                    child: Text(
                      nombre,
                      style: v.lectura(
                        tamano: 15,
                        peso: FontWeight.w600,
                        color: v.textoFuerte,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (estado != null)
                Semaforo(
                  estado: estado!,
                  etiqueta: textoEstado,
                  conIcono: true,
                  tamanoTexto: 13,
                ),
            ],
          ),
          Text(
            tipo.etiqueta,
            style: v.lectura(tamano: 12.5, color: v.textoTenue),
          ),
          SizedBox(height: e),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: e,
            children: [
              MontoOcultable(
                centavos: saldoCentavos,
                estilo: v.numero(
                  tamano: 22,
                  peso: FontWeight.w600,
                  color: v.textoFuerte,
                ),
              ),
              if (conMeta) ...[
                Text('de', style: v.lectura(tamano: 13, color: v.textoTenue)),
                MontoOcultable(
                  centavos: metaCentavos!,
                  estilo: v.numero(tamano: 14, color: v.textoTenue),
                ),
              ],
            ],
          ),
          if (conMeta) ...[
            SizedBox(height: e * 1.25),
            BarraProgreso(
              etiqueta: 'Progreso',
              valor: avance,
              color: v.exito,
              alto: 8,
            ),
          ],
          if (pendienteCentavos > 0)
            Padding(
              padding: EdgeInsets.only(top: e),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: e * 0.5,
                children: [
                  Icon(Icons.schedule, size: 16, color: v.textoTenue),
                  Text(
                    'Pendiente',
                    style: v.lectura(
                      tamano: 13,
                      peso: FontWeight.w600,
                      color: v.textoFuerte,
                    ),
                  ),
                  MontoOcultable(
                    centavos: pendienteCentavos,
                    estilo: v.numero(tamano: 13, color: v.texto),
                  ),
                  Text(
                    '· sin intereses ni castigo',
                    style: v.lectura(tamano: 12.5, color: v.textoTenue),
                  ),
                ],
              ),
            ),
          if (proyeccionCentavos != null && proyeccionFechaTexto != null)
            Padding(
              padding: EdgeInsets.only(top: e),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: e * 0.5,
                children: [
                  Text(
                    'Llegarás a',
                    style: v.lectura(tamano: 13, color: v.textoTenue),
                  ),
                  MontoOcultable(
                    centavos: proyeccionCentavos!,
                    estilo: v.numero(
                      tamano: 13,
                      peso: FontWeight.w600,
                      color: v.texto,
                    ),
                  ),
                  Text(
                    'el $proyeccionFechaTexto',
                    style: v.lectura(tamano: 13, color: v.textoTenue),
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    return Semantics(
      container: true,
      button: alTocar != null,
      label: 'Bolsa de ahorro: $nombre, ${tipo.etiqueta}',
      value: [
        if (conMeta) '${(avance * 100).floor()} % de la meta',
        if (pendienteCentavos > 0) 'con aportación pendiente',
        ?textoEstado,
      ].join(', '),
      onTap: alTocar,
      child: Material(
        color: v.panel,
        shape: RoundedRectangleBorder(
          borderRadius: radio,
          side: BorderSide(color: v.borde),
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
