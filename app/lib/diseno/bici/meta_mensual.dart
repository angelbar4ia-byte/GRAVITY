/// **Meta mensual de salidas** (4.11, PB-06): «Llevas 2 de 3 este mes».
///
/// **Sin racha semanal y sin culpa.** Una salida que no salió por clima o por
/// seguridad se cuenta aparte, con su propio icono y palabras, y no rompe
/// nada ni dice «racha rota». Alcanzar la meta se celebra en voz baja: sin
/// premios ni puntos. Cada salida es un punto con icono y palabra.
library;

import 'package:flutter/material.dart';

import '../componentes/barra_progreso.dart';
import '../componentes/tarjeta_modulo.dart';
import '../valores_diseno.dart';
import 'piezas_bici.dart';
import 'tipos_bici.dart';

/// La meta del mes con lo que se lleva, ya calculado.
class MetaMensualBici extends StatelessWidget {
  const MetaMensualBici({
    super.key,
    required this.mesTexto,
    required this.hechas,
    required this.meta,
    this.omitidasPorClima = 0,
    this.omitidasPorSeguridad = 0,
    this.mensajeTexto,
    this.estado = EstadoVistaBici.listo,
    this.mensajes = const MensajesEstadoBici(
      vacio: 'Todavía no hay una meta para este mes.',
      vacioDetalle: 'Puedes elegir cuántas salidas quieres.',
      cargando: 'Cargando tu meta…',
      sinConexion: 'Sin conexión. Se muestra lo guardado en este equipo.',
      error: 'No se pudo cargar tu meta del mes.',
    ),
    this.alReintentar,
  }) : assert(hechas >= 0 && meta >= 0);

  /// «noviembre».
  final String mesTexto;
  final int hechas;
  final int meta;
  final int omitidasPorClima;
  final int omitidasPorSeguridad;

  /// Un mensaje del catálogo («Llevas 2 de 3 salidas este mes.»).
  final String? mensajeTexto;
  final EstadoVistaBici estado;
  final MensajesEstadoBici mensajes;
  final VoidCallback? alReintentar;

  /// «2 de 3».
  String get progresoTexto => '$hechas de $meta';

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    if (estado != EstadoVistaBici.listo || meta == 0) {
      return TarjetaModulo(
        titulo: 'Meta del mes',
        icono: Icons.flag_outlined,
        child: CuerpoEstadoBici(
          estado: estado == EstadoVistaBici.listo
              ? EstadoVistaBici.vacio
              : estado,
          mensajes: mensajes,
          alReintentar: alReintentar,
        ),
      );
    }
    final cumplida = hechas >= meta;
    final omitidas = omitidasPorClima + omitidasPorSeguridad;
    final anuncio = [
      'Meta de $mesTexto: $progresoTexto salidas',
      if (cumplida) 'meta cumplida',
      if (omitidasPorClima > 0)
        '$omitidasPorClima omitidas por clima',
      if (omitidasPorSeguridad > 0)
        '$omitidasPorSeguridad omitidas por seguridad',
    ].join(', ');
    return TarjetaModulo(
      titulo: 'Meta del mes',
      icono: Icons.flag_outlined,
      accion: cumplida
          ? MarcaBici(
              texto: 'Meta cumplida',
              icono: Icons.check_circle_outline,
              color: v.exito,
            )
          : null,
      child: Semantics(
        container: true,
        label: anuncio,
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(mesTexto, style: v.etiquetaPanel()),
            Text(
              '$progresoTexto salidas',
              key: const ValueKey('meta-progreso'),
              style: v.numero(
                tamano: 26,
                peso: FontWeight.w700,
                color: v.textoFuerte,
              ),
            ),
            SizedBox(height: e),
            BarraProgreso(
              valor: meta == 0 ? 0 : hechas / meta,
              textoValor: ' ',
              alto: 8,
            ),
            if (omitidas > 0) ...[
              SizedBox(height: e * 1.25),
              Wrap(
                spacing: e,
                runSpacing: e * 0.5,
                children: [
                  if (omitidasPorClima > 0)
                    MarcaBici(
                      texto: 'Omitidas por clima: $omitidasPorClima',
                      icono: Icons.cloud_outlined,
                    ),
                  if (omitidasPorSeguridad > 0)
                    MarcaBici(
                      texto: 'Omitidas por seguridad: $omitidasPorSeguridad',
                      icono: Icons.shield_outlined,
                    ),
                ],
              ),
            ],
            if (mensajeTexto != null) ...[
              SizedBox(height: e * 1.25),
              Text(mensajeTexto!, style: v.lectura(tamano: 14.5, color: v.texto)),
            ],
          ],
        ),
      ),
    );
  }
}
