/// Gadget **Serie y descanso** (entrenamiento): ¿qué sigue y cuánto descanso?
/// (`DISENO_UX_UI.md:131`, 7.2). Reúne el ejercicio, la serie en curso, las
/// series como chips con icono y palabra, el temporizador de descanso y lo que
/// sigue. En la tablet escala a números de más de 96 dp, legibles desde 2 m.
library;

import 'package:flutter/material.dart';

import '../componentes/tarjeta_modulo.dart';
import '../valores_diseno.dart';
import 'piezas_gimnasio.dart';
import 'temporizador_descanso.dart';
import 'textos_gimnasio.dart';
import 'tipos_gimnasio.dart';

/// Un chip de serie: icono, número y palabra del estado («1 · Hecha»). No se
/// toca; el lector de pantalla lo lee entero (10).
class ChipSerie extends StatelessWidget {
  const ChipSerie({super.key, required this.serie, required this.total});

  final SerieVista serie;
  final int total;

  /// «Serie 2 de 3, 12 repeticiones, placa 3, pendiente» (10).
  String get anuncio {
    final partes = <String>[
      'Serie ${serie.numero} de $total',
      if (serie.repeticiones != null) '${serie.repeticiones} repeticiones',
      ?serie.cargaTexto,
      serie.estado.texto.toLowerCase(),
    ];
    return partes.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    final actual =
        serie.estado == EstadoSerie.actual ||
        serie.estado == EstadoSerie.enDescanso;
    final color = switch (serie.estado) {
      EstadoSerie.hecha => v.exito,
      EstadoSerie.conPrecaucion => v.alerta,
      EstadoSerie.actual || EstadoSerie.enDescanso => v.acento,
      _ => v.textoTenue,
    };
    return Semantics(
      container: true,
      label: anuncio,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: actual
              ? Color.alphaBlend(color.withValues(alpha: 0.14), v.panel)
              : null,
          border: Border.all(
            color: actual ? color : v.borde,
            width: actual ? v.grosorBorde + 0.5 : v.grosorBorde,
          ),
          borderRadius: BorderRadius.circular(v.radioMediano),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: e * 1.25,
              vertical: e * 0.5,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(serie.estado.icono, size: 18, color: color),
                SizedBox(width: e * 0.6),
                Flexible(
                  child: Text(
                    '${serie.numero} · ${serie.estado.texto}',
                    style: v.lectura(
                      tamano: 13,
                      peso: actual ? FontWeight.w700 : FontWeight.w500,
                      color: v.textoFuerte,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// **Serie y descanso**: la tarjeta del gadget.
///
/// Recibe datos ya calculados. [descanso] `null` no muestra temporizador
/// activo (muestra «Sin descanso en curso»). Los cuatro estados de pantalla
/// (vacío, cargando, sin conexión y error) usan las palabras de [mensajes].
class GadgetSerieDescanso extends StatelessWidget {
  const GadgetSerieDescanso({
    super.key,
    required this.ejercicio,
    this.puestoTexto,
    required this.serieActual,
    required this.seriesTotales,
    required this.repeticionesTexto,
    this.cargaTexto,
    this.series = const [],
    this.descanso,
    this.siguiente,
    this.escala = EscalaTemporizador.compacta,
    this.alMasQuince,
    this.alMenosQuince,
    this.alSaltar,
    this.alTerminarDescanso,
    this.ahora,
    this.vibrar,
    this.estado = EstadoVistaGimnasio.listo,
    this.mensajes = const MensajesEstadoGimnasio(
      vacio: 'No hay una sesión en curso.',
      vacioDetalle: 'Cuando empieces una, aquí ves la serie y el descanso.',
      cargando: 'Cargando tu sesión…',
      sinConexion: 'Sin conexión. La sesión sigue guardándose en este equipo.',
      error: 'No se pudo mostrar la sesión. Tus series guardadas siguen aquí.',
    ),
    this.alReintentar,
  });

  /// Nombre del ejercicio («Elevaciones laterales»).
  final String ejercicio;

  /// Aparato o puesto («Polea baja»).
  final String? puestoTexto;
  final int serieActual;
  final int seriesTotales;

  /// «12 repeticiones» o «30 s».
  final String repeticionesTexto;

  /// «Placa 3», «Banda verde»; `null` sin carga.
  final String? cargaTexto;

  /// Los chips de las series; vacío no los muestra.
  final List<SerieVista> series;

  /// El descanso en curso.
  final DescansoPlanificado? descanso;

  /// «Tríceps en polea alta».
  final String? siguiente;
  final EscalaTemporizador escala;
  final VoidCallback? alMasQuince;
  final VoidCallback? alMenosQuince;
  final VoidCallback? alSaltar;
  final VoidCallback? alTerminarDescanso;

  /// Reloj y vibración inyectables (pruebas).
  final DateTime Function()? ahora;
  final Future<void> Function()? vibrar;
  final EstadoVistaGimnasio estado;
  final MensajesEstadoGimnasio mensajes;
  final VoidCallback? alReintentar;

  @override
  Widget build(BuildContext context) {
    if (estado != EstadoVistaGimnasio.listo) {
      return TarjetaModulo(
        titulo: 'Serie y descanso',
        icono: Icons.fitness_center,
        child: CuerpoEstadoGimnasio(
          estado: estado,
          mensajes: mensajes,
          alReintentar: alReintentar,
        ),
      );
    }
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    final temporizador = TemporizadorDescanso(
      descanso: descanso,
      escala: escala,
      alMasQuince: alMasQuince,
      alMenosQuince: alMenosQuince,
      alSaltar: alSaltar,
      alTerminar: alTerminarDescanso,
      ahora: ahora ?? DateTime.now,
      vibrar: vibrar ?? vibracionFinDescanso,
    );
    final datos = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Text(
            ejercicio,
            style: v.titulo(
              tamano: escala == EscalaTemporizador.tablet ? 40 : 28,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (puestoTexto != null)
          Text(puestoTexto!, style: v.lectura(tamano: 15, color: v.textoTenue)),
        SizedBox(height: e),
        Text(
          'Serie $serieActual de $seriesTotales · $repeticionesTexto'
          '${cargaTexto == null ? '' : ' · $cargaTexto'}',
          style: v.lectura(
            tamano: 17,
            peso: FontWeight.w600,
            color: v.textoFuerte,
          ),
        ),
        if (series.isNotEmpty) ...[
          SizedBox(height: e * 1.5),
          Wrap(
            spacing: e,
            runSpacing: e,
            children: [
              for (final s in series) ChipSerie(serie: s, total: seriesTotales),
            ],
          ),
        ],
        if (siguiente != null) ...[
          SizedBox(height: e * 1.5),
          Text(
            '${TextosGimnasio.siguiente}: $siguiente',
            style: v.lectura(tamano: 15, color: v.textoTenue),
          ),
        ],
      ],
    );
    return TarjetaModulo(
      titulo: 'Serie y descanso',
      icono: Icons.fitness_center,
      child: LayoutBuilder(
        builder: (context, caja) {
          // En la tablet horizontal los datos van a la izquierda y el
          // temporizador a la derecha; si no cabe, uno bajo el otro.
          final ancho = caja.maxWidth >= 640;
          if (ancho) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: datos),
                SizedBox(width: e * 3),
                temporizador,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              datos,
              SizedBox(height: e * 2),
              temporizador,
            ],
          );
        },
      ),
    );
  }
}
