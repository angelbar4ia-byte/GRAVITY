/// **Línea de la semana** (E1 y E3, 5.6): los siete días con lo que toca
/// (fuerza A, B o C, regenerativas, la bicicleta del sábado y el descanso), su
/// estado y los avisos de las 48 horas. Sirve para los planes de 3, 4 y 5 días:
/// lo que cambia son los días que llegan como datos.
///
/// Si caben siete celdas de 48 dp con la letra normal, se dibuja una **tira**;
/// con letra grande o poco ancho se dibuja una **lista** de filas de 56 dp con
/// el nombre del día, lo que toca y su estado, sin recortar nada.
library;

import 'package:flutter/material.dart';

import '../componentes/tarjeta_modulo.dart';
import '../superficies.dart';
import '../valores_diseno.dart';
import 'piezas_gimnasio.dart';
import 'textos_gimnasio.dart';
import 'tipos_gimnasio.dart';

/// Un día del plan, con datos ya calculados.
@immutable
class DiaSemanaVista {
  const DiaSemanaVista({
    required this.nombre,
    required this.letra,
    required this.tipo,
    this.estado = EstadoDiaPlan.pendiente,
    this.esHoy = false,
    this.detalleTexto,
    this.conAviso = false,
  });

  /// «lunes».
  final String nombre;

  /// «L», «M», «X»…
  final String letra;
  final TipoDiaPlan tipo;
  final EstadoDiaPlan estado;
  final bool esHoy;

  /// «estándar · 19:15».
  final String? detalleTexto;

  /// Tiene un aviso de 48 horas o de la bicicleta.
  final bool conAviso;

  /// Lo que lee el lector de pantalla.
  String get anuncio => [
    nombre,
    if (esHoy) 'hoy',
    tipo.texto,
    ?detalleTexto,
    estado.texto.toLowerCase(),
    if (conAviso) 'con aviso',
  ].join(', ');
}

/// Línea de la semana.
class LineaSemana extends StatelessWidget {
  const LineaSemana({
    super.key,
    required this.dias,
    this.titulo = 'Semana',
    this.avisos = const [],
    this.alTocarDia,
    this.estado = EstadoVistaGimnasio.listo,
    this.mensajes = const MensajesEstadoGimnasio(
      vacio: 'Todavía no hay un plan para la semana.',
      vacioDetalle: 'Elige 3, 4 o 5 días y lo armamos.',
      textoAccionVacia: 'Armar mi semana',
      cargando: 'Cargando tu semana…',
      sinConexion: 'Sin conexión. Se muestra la semana guardada aquí.',
      error: 'No se pudo cargar la semana. Puedes intentarlo otra vez.',
    ),
    this.alReintentar,
    this.alAccionVacia,
  });

  /// Siete días, de lunes a domingo (la semana empieza en lunes).
  final List<DiaSemanaVista> dias;
  final String titulo;

  /// Avisos de las 48 horas, ya redactados («A y B comparten hombro; mejor
  /// 30 min más tarde»). Se muestran bajo la línea con icono y palabras.
  final List<String> avisos;

  /// Mover o abrir un día; sin esto las celdas no se tocan.
  final ValueChanged<int>? alTocarDia;
  final EstadoVistaGimnasio estado;
  final MensajesEstadoGimnasio mensajes;
  final VoidCallback? alReintentar;
  final VoidCallback? alAccionVacia;

  /// Ancho mínimo de una celda de la tira.
  static const double _celda = 48;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    if (estado != EstadoVistaGimnasio.listo || dias.isEmpty) {
      return TarjetaModulo(
        titulo: titulo,
        icono: Icons.calendar_view_week_outlined,
        child: CuerpoEstadoGimnasio(
          estado: estado == EstadoVistaGimnasio.listo
              ? EstadoVistaGimnasio.vacio
              : estado,
          mensajes: mensajes,
          alReintentar: alReintentar,
          alAccionVacia: alAccionVacia,
        ),
      );
    }
    return TarjetaModulo(
      titulo: titulo,
      icono: Icons.calendar_view_week_outlined,
      child: LayoutBuilder(
        builder: (context, caja) {
          final letraGrande = MediaQuery.textScalerOf(context).scale(10) > 13;
          final caben = caja.maxWidth >= dias.length * (_celda + 2);
          final tira = caben && !letraGrande;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (tira)
                _Tira(dias: dias, alTocarDia: alTocarDia)
              else
                _Lista(dias: dias, alTocarDia: alTocarDia),
              SizedBox(height: e * 1.5),
              _Leyenda(dias: dias),
              for (final aviso in avisos) ...[
                SizedBox(height: e),
                _FilaAvisoSemana(texto: aviso),
              ],
            ],
          );
        },
      ),
    );
  }
}

Color _colorEstado(ValoresDiseno v, EstadoDiaPlan e) => switch (e) {
  EstadoDiaPlan.hecho => v.exito,
  EstadoDiaPlan.parcial => v.alerta,
  EstadoDiaPlan.saltado => v.textoTenue,
  EstadoDiaPlan.pendiente => v.textoTenue,
};

class _Tira extends StatelessWidget {
  const _Tira({required this.dias, required this.alTocarDia});

  final List<DiaSemanaVista> dias;
  final ValueChanged<int>? alTocarDia;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < dias.length; i++) ...[
          if (i > 0) const SizedBox(width: 2),
          Expanded(
            child: _CeldaDia(
              dia: dias[i],
              alTocar: alTocarDia == null ? null : () => alTocarDia!(i),
            ),
          ),
        ],
      ],
    );
  }
}

class _CeldaDia extends StatelessWidget {
  const _CeldaDia({required this.dia, required this.alTocar});

  final DiaSemanaVista dia;
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final fuerza = dia.tipo.esFuerza;
    final color = fuerza ? v.acento : v.textoTenue;
    final contenido = DecoratedBox(
      decoration: BoxDecoration(
        color: dia.esHoy
            ? v.chipSeleccionado
            : fuerza
            ? Color.alphaBlend(v.acento.withValues(alpha: 0.06), v.panel)
            : null,
        border: Border.all(
          color: dia.esHoy ? v.acento : v.borde,
          width: dia.esHoy ? v.grosorBorde + 1 : v.grosorBorde,
        ),
        borderRadius: BorderRadius.circular(v.radioMediano),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 88),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: v.espacio * 0.75),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                dia.letra,
                style: v.numero(
                  tamano: 13,
                  peso: dia.esHoy ? FontWeight.w700 : FontWeight.w500,
                  color: v.textoFuerte,
                ),
              ),
              const SizedBox(height: 4),
              Icon(dia.tipo.icono, size: 22, color: color),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  dia.tipo.codigo,
                  maxLines: 1,
                  style: v.numero(
                    tamano: 13,
                    peso: FontWeight.w600,
                    color: v.textoFuerte,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Icon(
                dia.conAviso ? Icons.info_outline : dia.estado.icono,
                size: 16,
                color: dia.conAviso ? v.alerta : _colorEstado(v, dia.estado),
              ),
            ],
          ),
        ),
      ),
    );
    return Semantics(
      container: true,
      button: alTocar != null,
      onTap: alTocar,
      label: dia.anuncio,
      excludeSemantics: true,
      child: alTocar == null
          ? contenido
          : InkWell(
              onTap: alTocar,
              borderRadius: BorderRadius.circular(v.radioMediano),
              child: contenido,
            ),
    );
  }
}

class _Lista extends StatelessWidget {
  const _Lista({required this.dias, required this.alTocarDia});

  final List<DiaSemanaVista> dias;
  final ValueChanged<int>? alTocarDia;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < dias.length; i++)
          Builder(
            builder: (context) {
              final d = dias[i];
              final alTocar = alTocarDia == null ? null : () => alTocarDia!(i);
              final color = d.tipo.esFuerza ? v.acento : v.textoTenue;
              final fila = DecoratedBox(
                decoration: BoxDecoration(
                  color: d.esHoy ? v.chipSeleccionado : null,
                  border: Border(
                    bottom: BorderSide(color: v.borde, width: 0.5),
                    left: d.esHoy
                        ? BorderSide(color: v.acento, width: 3)
                        : BorderSide.none,
                  ),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: e,
                      vertical: e * 0.75,
                    ),
                    child: Row(
                      children: [
                        ExcludeSemantics(
                          child: Icon(d.tipo.icono, size: 22, color: color),
                        ),
                        SizedBox(width: e * 1.25),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                d.esHoy ? '${d.nombre} · hoy' : d.nombre,
                                style: v.lectura(
                                  tamano: 15,
                                  peso: FontWeight.w700,
                                  color: v.textoFuerte,
                                ),
                              ),
                              Text(
                                [d.tipo.texto, ?d.detalleTexto].join(' · '),
                                style: v.lectura(
                                  tamano: 14,
                                  color: v.textoTenue,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: e),
                        ExcludeSemantics(
                          child: Icon(
                            d.conAviso ? Icons.info_outline : d.estado.icono,
                            size: 20,
                            color: d.conAviso
                                ? v.alerta
                                : _colorEstado(v, d.estado),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
              return Semantics(
                container: true,
                button: alTocar != null,
                onTap: alTocar,
                label: d.anuncio,
                excludeSemantics: true,
                child: alTocar == null
                    ? fila
                    : InkWell(onTap: alTocar, child: fila),
              );
            },
          ),
      ],
    );
  }
}

/// Leyenda con **palabras e iconos** de lo que aparece en la línea, para que el
/// estado de un día no dependa del color ni de un icono suelto.
class _Leyenda extends StatelessWidget {
  const _Leyenda({required this.dias});

  final List<DiaSemanaVista> dias;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    final estados = {for (final d in dias) d.estado};
    final hayAviso = dias.any((d) => d.conAviso);
    final hayHoy = dias.any((d) => d.esHoy);
    Widget item(IconData icono, String texto, Color color) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(child: Icon(icono, size: 16, color: color)),
        SizedBox(width: e * 0.5),
        Flexible(
          child: Text(
            texto,
            style: v.lectura(tamano: 13, color: v.textoTenue),
          ),
        ),
      ],
    );
    return ExcludeSemantics(
      child: Wrap(
        spacing: e * 2,
        runSpacing: e * 0.5,
        children: [
          if (hayHoy) item(Icons.today_outlined, TextosGimnasio.hoy, v.acento),
          for (final s in EstadoDiaPlan.values)
            if (estados.contains(s)) item(s.icono, s.texto, _colorEstado(v, s)),
          if (hayAviso) item(Icons.info_outline, 'Con aviso', v.alerta),
        ],
      ),
    );
  }
}

class _FilaAvisoSemana extends StatelessWidget {
  const _FilaAvisoSemana({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    return Semantics(
      container: true,
      liveRegion: false,
      label: 'Aviso: $texto',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color.alphaBlend(v.alerta.withValues(alpha: 0.10), v.panel),
          border: Border.all(color: v.alerta, width: v.grosorBorde),
          borderRadius: BorderRadius.circular(v.radioMediano),
        ),
        child: Padding(
          padding: EdgeInsets.all(e * 1.25),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 20, color: v.alerta),
              SizedBox(width: e),
              Expanded(
                child: Text(
                  'Aviso: $texto',
                  style: v.lectura(tamano: 14, color: v.texto),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
