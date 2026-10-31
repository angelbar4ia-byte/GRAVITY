import 'package:flutter/material.dart';

import '../componentes/monto_ocultable.dart';
import '../tema.dart';
import '../valores_diseno.dart';

/// Qué vence (Fase 2, regla 32 y sección 6.1). Cada tipo lleva icono **y**
/// texto.
enum TipoVencimiento {
  corte('Corte', Icons.content_cut),
  limite('Fecha límite', Icons.event_busy_outlined),
  pago('Pago', Icons.payments_outlined),
  msi('Mensualidad MSI', Icons.calendar_view_month_outlined);

  const TipoVencimiento(this.etiqueta, this.icono);

  final String etiqueta;
  final IconData icono;
}

/// Un vencimiento de la línea.
@immutable
class EventoVencimiento {
  const EventoVencimiento({
    required this.tipo,
    required this.titulo,
    required this.diaTexto,
    this.montoCentavos,
    this.vencido = false,
  });

  final TipoVencimiento tipo;

  /// "Tarjeta X", "Caja Popular".
  final String titulo;

  /// "jue 12 nov" (con el día hábil ya ajustado).
  final String diaTexto;
  final int? montoCentavos;

  /// Pasó la fecha y no se registró el pago: se marca con texto y icono.
  final bool vencido;
}

/// Una semana del calendario.
@immutable
class SemanaVencimientos {
  const SemanaVencimientos({
    required this.etiqueta,
    this.eventos = const [],
    this.actual = false,
  });

  /// "Sem 45 · 2 al 8 nov".
  final String etiqueta;
  final List<EventoVencimiento> eventos;
  final bool actual;
}

/// Total de mensualidades MSI de un mes.
@immutable
class TotalMsiDelMes {
  const TotalMsiDelMes(this.mesTexto, this.centavos);

  final String mesTexto;
  final int centavos;
}

/// Gadget **Línea de vencimientos** (Fase 2, sección 8): calendario de 4 a 8
/// semanas con cortes, fechas límite, pagos y mensualidades de MSI, y el total
/// de MSI por mes. Es una lista vertical por semana (cabe en 360 dp con la
/// letra al 200 %); los montos se ocultan solos.
class LineaVencimientos extends StatelessWidget {
  const LineaVencimientos({
    super.key,
    required this.semanas,
    this.totalesMsi = const [],
    this.alTocarEvento,
  });

  final List<SemanaVencimientos> semanas;
  final List<TotalMsiDelMes> totalesMsi;
  final ValueChanged<EventoVencimiento>? alTocarEvento;

  @override
  Widget build(BuildContext context) {
    assert(semanas.length <= 8, 'Como máximo 8 semanas');
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    final hayEventos = semanas.any((s) => s.eventos.isNotEmpty);
    return Semantics(
      container: true,
      label: 'Calendario de vencimientos',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!hayEventos)
            Text(
              'Sin vencimientos en las próximas ${semanas.length} semanas',
              style: v.lectura(tamano: 14, color: v.textoTenue),
            ),
          for (final semana in semanas) ...[
            if (hayEventos) ...[
              Padding(
                padding: EdgeInsets.only(top: e, bottom: e * 0.5),
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        semana.etiqueta.toUpperCase(),
                        style: v.etiquetaPanel(
                          tamano: 11.5,
                          color: semana.actual ? v.acento : null,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (semana.actual) ...[
                      SizedBox(width: e),
                      Text(
                        'Esta semana',
                        style: v.lectura(
                          tamano: 11.5,
                          peso: FontWeight.w600,
                          color: v.textoFuerte,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (semana.eventos.isEmpty)
                Text(
                  'Sin vencimientos',
                  style: v.lectura(tamano: 13, color: v.textoTenue),
                ),
              for (final evento in semana.eventos)
                _FilaEvento(
                  evento: evento,
                  alTocar: alTocarEvento == null
                      ? null
                      : () => alTocarEvento!(evento),
                ),
            ],
          ],
          if (totalesMsi.isNotEmpty) ...[
            Divider(height: e * 3),
            const _TituloMsi(),
            SizedBox(height: e * 0.5),
            for (final t in totalesMsi)
              Padding(
                padding: EdgeInsets.symmetric(vertical: e * 0.25),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: e,
                  children: [
                    Text(
                      t.mesTexto,
                      style: v.lectura(tamano: 14, color: v.texto),
                    ),
                    MontoOcultable(
                      centavos: t.centavos,
                      estilo: v.numero(
                        tamano: 14,
                        peso: FontWeight.w600,
                        color: v.textoFuerte,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _TituloMsi extends StatelessWidget {
  const _TituloMsi();

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    return Text('MSI POR MES', style: v.etiquetaPanel(tamano: 11.5));
  }
}

class _FilaEvento extends StatelessWidget {
  const _FilaEvento({required this.evento, required this.alTocar});

  final EventoVencimiento evento;
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    final color = evento.vencido ? v.peligro : v.textoTenue;
    final contenido = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: zonaTactilMinima),
      child: Row(
        children: [
          Icon(
            evento.vencido ? Icons.error_outline : evento.tipo.icono,
            size: 20,
            color: color,
          ),
          SizedBox(width: e * 1.25),
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: e,
              runSpacing: e * 0.25,
              children: [
                Text(
                  evento.titulo,
                  style: v.lectura(
                    tamano: 14,
                    peso: FontWeight.w600,
                    color: v.textoFuerte,
                  ),
                ),
                Text(
                  '${evento.vencido ? 'Vencido · ' : ''}${evento.tipo.etiqueta}'
                  ' · ${evento.diaTexto}',
                  style: v.lectura(tamano: 12.5, color: v.textoTenue),
                ),
                if (evento.montoCentavos != null)
                  MontoOcultable(
                    centavos: evento.montoCentavos!,
                    estilo: v.numero(
                      tamano: 13,
                      peso: FontWeight.w600,
                      color: v.texto,
                    ),
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
      label:
          '${evento.vencido ? 'Vencido, ' : ''}${evento.tipo.etiqueta}: '
          '${evento.titulo}, ${evento.diaTexto}',
      excludeSemantics: true,
      onTap: alTocar,
      child: alTocar == null
          ? contenido
          : InkWell(
              onTap: alTocar,
              borderRadius: BorderRadius.circular(v.radioChico),
              child: contenido,
            ),
    );
  }
}
