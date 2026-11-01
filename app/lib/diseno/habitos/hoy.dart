import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../componentes/semaforo.dart';
import '../superficies.dart';
import '../tema.dart';
import '../valores_diseno.dart';
import 'rachas.dart';
import 'sensible_ocultable.dart';

/// Un anillo del día (una área o un grupo de objetivos).
@immutable
class AnilloDia {
  const AnilloDia(this.etiqueta, this.valor, {this.textoValor});

  final String etiqueta;

  /// De 0 a 1.
  final double valor;

  /// "3 de 5"; por omisión, el porcentaje.
  final String? textoValor;
}

/// Anillos del día: cada uno con su porcentaje o cuenta **en texto** (no solo
/// el arco) y su etiqueta. Se dibujan quietos si se pidió reducir movimiento.
class AnillosDia extends StatelessWidget {
  const AnillosDia({super.key, required this.anillos, this.diametro = 72});

  final List<AnilloDia> anillos;
  final double diametro;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    return Semantics(
      container: true,
      label: 'Anillos del día',
      child: Wrap(
        spacing: v.espacio * 2,
        runSpacing: v.espacio * 2,
        children: [
          for (final a in anillos)
            Semantics(
              label: a.etiqueta,
              value: a.textoValor ?? '${(a.valor * 100).floor()} %',
              excludeSemantics: true,
              child: SizedBox(
                width: math.max(diametro, 88),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: diametro,
                      height: diametro,
                      child: CustomPaint(
                        painter: _PintorAnillo(
                          fraccion: a.valor.clamp(0.0, 1.0),
                          pista: v.pista,
                          color: a.valor >= 1 ? v.exito : v.acento,
                        ),
                        child: Center(
                          child: Text(
                            a.textoValor ?? '${(a.valor * 100).floor()} %',
                            style: v.numero(
                              tamano: 14,
                              peso: FontWeight.w600,
                              color: v.textoFuerte,
                            ),
                            maxLines: 1,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: v.espacio * 0.5),
                    Text(
                      a.etiqueta,
                      textAlign: TextAlign.center,
                      style: v.lectura(tamano: 12.5, color: v.textoTenue),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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

class _PintorAnillo extends CustomPainter {
  const _PintorAnillo({
    required this.fraccion,
    required this.pista,
    required this.color,
  });

  final double fraccion;
  final Color pista;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final grosor = size.shortestSide * 0.12;
    final rect = Offset.zero & size;
    final area = rect.deflate(grosor / 2);
    final pincel = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(area, 0, math.pi * 2, false, pincel..color = pista);
    if (fraccion > 0) {
      canvas.drawArc(
        area,
        -math.pi / 2,
        math.pi * 2 * fraccion,
        false,
        pincel..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_PintorAnillo old) =>
      old.fraccion != fraccion || old.pista != pista || old.color != color;
}

/// Carga del día: minutos planeados frente a los disponibles (Fase 3, regla
/// de carga). Lógica de presentación pura.
@immutable
class CargaDia {
  const CargaDia({required this.planeadosMin, required this.disponiblesMin});

  final int planeadosMin;
  final int disponiblesMin;

  double get fraccion => disponiblesMin <= 0
      ? (planeadosMin > 0 ? 1 : 0)
      : planeadosMin / disponiblesMin;

  /// Ligero hasta 75 %, lleno hasta 100 %, cargado arriba (sin rojo).
  EstadoSemaforo get estado {
    if (planeadosMin * 4 <= disponiblesMin * 3) return EstadoSemaforo.verde;
    if (planeadosMin <= disponiblesMin) return EstadoSemaforo.ambar;
    return EstadoSemaforo.rojo;
  }

  String get texto => switch (estado) {
    EstadoSemaforo.verde => 'Día ligero',
    EstadoSemaforo.ambar => 'Día lleno',
    EstadoSemaforo.rojo => 'Día cargado: ¿movemos algo?',
  };
}

/// Medidor de la carga del día: barra + texto ("Día lleno") + horas.
class MedidorCarga extends StatelessWidget {
  const MedidorCarga({
    super.key,
    required this.planeadosMin,
    required this.disponiblesMin,
  });

  final int planeadosMin;
  final int disponiblesMin;

  static String horas(int min) {
    final h = min ~/ 60;
    final m = min % 60;
    return m == 0 ? '$h h' : '$h h $m min';
  }

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final carga = CargaDia(
      planeadosMin: planeadosMin,
      disponiblesMin: disponiblesMin,
    );
    final color = switch (carga.estado) {
      EstadoSemaforo.verde => v.exito,
      EstadoSemaforo.ambar => v.alerta,
      EstadoSemaforo.rojo => v.peligro,
    };
    return Semantics(
      container: true,
      label: 'Carga del día',
      value:
          '${carga.texto}. ${horas(planeadosMin)} de ${horas(disponiblesMin)}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: v.espacio,
            children: [
              Text(
                carga.texto,
                style: v.lectura(
                  tamano: 14,
                  peso: FontWeight.w600,
                  color: v.textoFuerte,
                ),
              ),
              Text(
                '${horas(planeadosMin)} de ${horas(disponiblesMin)}',
                style: v.numero(tamano: 13, color: v.textoTenue),
              ),
            ],
          ),
          SizedBox(height: v.espacio * 0.75),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: SizedBox(
              height: 10,
              child: ColoredBox(
                color: v.pista,
                child: FractionallySizedBox(
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: carga.fraccion.clamp(0.0, 1.0),
                  child: ColoredBox(color: color),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Estado de un elemento de Hoy.
enum EstadoFila {
  pendiente('Pendiente', Icons.radio_button_unchecked),
  hecho('Hecho', Icons.check_circle_outline),
  parcial('Hecho a medias', Icons.timelapse),
  pospuesto('Pospuesto', Icons.schedule),
  omitido('Omitido', Icons.remove_circle_outline);

  const EstadoFila(this.etiqueta, this.icono);

  final String etiqueta;
  final IconData icono;
}

/// Fila de Hoy: hecho / posponer / omitir. Se puede **deslizar** (derecha =
/// Hecho, izquierda = Posponer) y siempre hay **botones** de 48 dp (Hecho y un
/// menú con Posponer y Omitir) y acciones personalizadas para el lector de
/// pantalla. Hecho cuesta un toque. [sensible] oculta el título.
class FilaHabito extends StatelessWidget {
  const FilaHabito({
    super.key,
    required this.titulo,
    this.horaTexto,
    this.detalle,
    this.estado = EstadoFila.pendiente,
    this.racha,
    this.sensible = false,
    this.alHecho,
    this.alPosponer,
    this.alOmitir,
  });

  final String titulo;
  final String? horaTexto;
  final String? detalle;
  final EstadoFila estado;

  /// Días de racha del hábito; `null` no la muestra.
  final int? racha;
  final bool sensible;
  final VoidCallback? alHecho;
  final VoidCallback? alPosponer;
  final VoidCallback? alOmitir;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    final cerrada = estado == EstadoFila.hecho || estado == EstadoFila.omitido;
    final fila = DecoratedBox(
      decoration: BoxDecoration(
        color: v.panel,
        border: Border.all(color: v.borde),
        borderRadius: BorderRadius.circular(v.radioMediano),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: zonaTactilMinima),
        child: Padding(
          padding: EdgeInsets.only(
            left: e * 1.5,
            top: e * 0.5,
            bottom: e * 0.5,
          ),
          child: Row(
            children: [
              ExcludeSemantics(
                child: Icon(
                  estado.icono,
                  size: 22,
                  color: estado == EstadoFila.hecho ? v.exito : v.textoTenue,
                ),
              ),
              SizedBox(width: e * 1.25),
              Expanded(
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: e,
                        children: [
                          if (horaTexto != null)
                            Text(
                              horaTexto!,
                              style: v.numero(tamano: 13, color: v.acento),
                            ),
                          _Titulo(
                            titulo,
                            sensible: sensible,
                            estilo: v.lectura(
                              tamano: 15,
                              peso: FontWeight.w600,
                              color: cerrada ? v.textoTenue : v.textoFuerte,
                            ),
                          ),
                        ],
                      ),
                      if (detalle != null || estado != EstadoFila.pendiente)
                        Text(
                          [
                            if (estado != EstadoFila.pendiente) estado.etiqueta,
                            ?detalle,
                          ].join(' · '),
                          style: v.lectura(tamano: 12.5, color: v.textoTenue),
                        ),
                      if (racha != null && racha! > 0)
                        Padding(
                          padding: EdgeInsets.only(top: e * 0.5),
                          child: ChipRacha(dias: racha!),
                        ),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Hecho',
                constraints: const BoxConstraints(
                  minWidth: zonaTactilMinima,
                  minHeight: zonaTactilMinima,
                ),
                onPressed: alHecho,
                icon: const Icon(Icons.check),
              ),
              PopupMenuButton<String>(
                tooltip: 'Más acciones',
                onSelected: (a) =>
                    a == 'posponer' ? alPosponer?.call() : alOmitir?.call(),
                itemBuilder: (_) => [
                  if (alPosponer != null)
                    const PopupMenuItem(
                      value: 'posponer',
                      child: Text('Posponer'),
                    ),
                  if (alOmitir != null)
                    const PopupMenuItem(value: 'omitir', child: Text('Omitir')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    final deslizable = alHecho != null || alPosponer != null;
    return Semantics(
      container: true,
      label:
          '${horaTexto == null ? '' : '$horaTexto, '}'
          '${sensible ? etiquetaContenidoPrivado : titulo}',
      value: estado.etiqueta,
      customSemanticsActions: {
        const CustomSemanticsAction(label: 'Hecho'): ?alHecho,
        const CustomSemanticsAction(label: 'Posponer'): ?alPosponer,
        const CustomSemanticsAction(label: 'Omitir'): ?alOmitir,
      },
      child: deslizable
          ? Dismissible(
              key: ValueKey('desliza-$titulo-$horaTexto'),
              confirmDismiss: (dir) async {
                (dir == DismissDirection.startToEnd ? alHecho : alPosponer)
                    ?.call();
                return false;
              },
              direction: alPosponer == null
                  ? DismissDirection.startToEnd
                  : DismissDirection.horizontal,
              background: _Fondo(
                texto: 'Hecho',
                icono: Icons.check,
                v: v,
                alInicio: true,
              ),
              secondaryBackground: _Fondo(
                texto: 'Posponer',
                icono: Icons.schedule,
                v: v,
                alInicio: false,
              ),
              child: fila,
            )
          : fila,
    );
  }
}

class _Fondo extends StatelessWidget {
  const _Fondo({
    required this.texto,
    required this.icono,
    required this.v,
    required this.alInicio,
  });

  final String texto;
  final IconData icono;
  final ValoresDiseno v;
  final bool alInicio;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Color.alphaBlend(v.acento.withValues(alpha: 0.14), v.panel),
      borderRadius: BorderRadius.circular(v.radioMediano),
    ),
    child: Align(
      alignment: alInicio ? Alignment.centerLeft : Alignment.centerRight,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: v.espacio * 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, color: v.textoFuerte),
            SizedBox(width: v.espacio),
            Text(texto, style: v.lectura(color: v.textoFuerte)),
          ],
        ),
      ),
    ),
  );
}

/// Tarjeta *Sigue*: lo siguiente del día, o lo que está **en curso** con el
/// tiempo transcurrido. Hecho y Posponer a un toque.
class TarjetaSigue extends StatelessWidget {
  const TarjetaSigue({
    super.key,
    required this.titulo,
    required this.horaTexto,
    this.enCurso = false,
    this.transcurridoTexto,
    this.sensible = false,
    this.alHecho,
    this.alPosponer,
  });

  final String titulo;
  final String horaTexto;
  final bool enCurso;
  final String? transcurridoTexto;
  final bool sensible;
  final VoidCallback? alHecho;
  final VoidCallback? alPosponer;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    return Semantics(
      container: true,
      label: enCurso ? 'En curso' : 'Sigue',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: v.panel,
          border: Border.all(color: v.acento),
          borderRadius: BorderRadius.circular(v.radioMediano),
        ),
        child: Padding(
          padding: EdgeInsets.all(e * 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${enCurso ? 'EN CURSO' : 'SIGUE'} · $horaTexto'.toUpperCase(),
                style: v.etiquetaPanel(tamano: 12, color: v.acento),
              ),
              SizedBox(height: e),
              _Titulo(
                titulo,
                sensible: sensible,
                estilo: v.lectura(
                  tamano: 18,
                  peso: FontWeight.w600,
                  color: v.textoFuerte,
                ),
              ),
              if (enCurso && transcurridoTexto != null)
                Text(
                  'Llevas $transcurridoTexto',
                  style: v.lectura(tamano: 14, color: v.textoTenue),
                ),
              SizedBox(height: e * 1.5),
              Wrap(
                spacing: e,
                runSpacing: e,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: zonaTactilMinima,
                    ),
                    child: FilledButton(
                      onPressed: alHecho,
                      child: const Text('Hecho'),
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: zonaTactilMinima,
                    ),
                    child: OutlinedButton(
                      onPressed: alPosponer,
                      child: const Text('Posponer'),
                    ),
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

/// Título que se oculta solo si el elemento es sensible.
class _Titulo extends StatelessWidget {
  const _Titulo(this.texto, {required this.sensible, required this.estilo});

  final String texto;
  final bool sensible;
  final TextStyle estilo;

  @override
  Widget build(BuildContext context) => sensible
      ? TextoSensible(texto, estilo: estilo)
      : Text(texto, style: estilo);
}
