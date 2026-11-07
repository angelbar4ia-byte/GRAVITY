import 'package:flutter/material.dart';

import '../valores_diseno.dart';
import 'cuadricula_bento.dart';
import 'etiqueta_panel.dart';
import 'superficie_panel.dart';

/// Tarjeta de resumen de un módulo (sección 19): etiqueta, acción opcional y
/// contenido. Toma los colores del estilo activo y la personalidad del módulo.
class TarjetaModulo extends StatelessWidget {
  const TarjetaModulo({
    super.key,
    required this.titulo,
    required this.child,
    this.icono,
    this.accion,
    this.alTocar,
    this.colorEtiqueta,
  });

  /// Texto de la etiqueta; se muestra en mayúsculas.
  final String titulo;

  /// Contenido de la tarjeta.
  final Widget child;

  /// Icono de línea junto a la etiqueta.
  final IconData? icono;

  /// Acción en la esquina superior derecha (por ejemplo, "Mostrar").
  final Widget? accion;

  /// Si se indica, toda la tarjeta abre el detalle del módulo.
  final VoidCallback? alTocar;

  /// Color de la etiqueta; por defecto, el de etiquetas del estilo.
  final Color? colorEtiqueta;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    final radio = BorderRadius.circular(v.radioMediano);

    // Dentro de una tesela bento, la tarjeta llena el alto de su tesela.
    final alto = AlturaTesela.de(context);
    Widget contenido = Padding(
      padding: EdgeInsets.symmetric(horizontal: e * 2 + 2, vertical: e * 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _Cabecera(
            titulo: titulo,
            icono: icono,
            accion: accion,
            colorEtiqueta: colorEtiqueta,
          ),
          SizedBox(height: e * 1.5),
          child,
        ],
      ),
    );

    if (alto > 0) {
      contenido = ConstrainedBox(
        constraints: BoxConstraints(minHeight: alto),
        child: contenido,
      );
    }

    if (alTocar != null) {
      contenido = InkWell(
        onTap: alTocar,
        borderRadius: radio,
        child: contenido,
      );
    }

    return Semantics(
      container: true,
      label: titulo,
      child: SuperficiePanel(
        radio: radio,
        child: v.decoracion && v.marcasEsquina
            ? CustomPaint(
                foregroundPainter: MarcasEsquina(color: v.acento),
                child: contenido,
              )
            : contenido,
      ),
    );
  }
}

/// Cabecera de la tarjeta: etiqueta a la izquierda y [accion] a la derecha.
///
/// Con letra grande o poco ancho, la acción **baja a su propia línea** (queda
/// al inicio) en lugar de cortarse, y la etiqueta usa todo el ancho: un `Wrap`
/// con `spaceBetween`, nunca una fila rígida. Una acción más ancha que la
/// tarjeta debe poder encogerse sola (el [Semaforo] recorta su texto).
class _Cabecera extends StatelessWidget {
  const _Cabecera({
    required this.titulo,
    required this.icono,
    required this.accion,
    required this.colorEtiqueta,
  });

  final String titulo;
  final IconData? icono;
  final Widget? accion;
  final Color? colorEtiqueta;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    final etiqueta = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icono != null) ...[
          Icon(icono, size: 16, color: colorEtiqueta ?? v.etiqueta),
          SizedBox(width: e),
        ],
        Flexible(child: EtiquetaPanel(titulo, color: colorEtiqueta)),
      ],
    );
    final accion = this.accion;
    if (accion == null) return etiqueta;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: e,
      runSpacing: e * 0.5,
      children: [etiqueta, accion],
    );
  }
}

/// Marcas finas en las esquinas, adorno del estilo Futurista (HUD).
/// No se dibujan si el estilo o el módulo van sin decoración.
class MarcasEsquina extends CustomPainter {
  const MarcasEsquina({required this.color, this.largo = 10});

  final Color color;
  final double largo;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final l = largo;
    final w = size.width;
    final h = size.height;
    canvas
      ..drawLine(Offset.zero, Offset(l, 0), p)
      ..drawLine(Offset.zero, Offset(0, l), p)
      ..drawLine(Offset(w, h), Offset(w - l, h), p)
      ..drawLine(Offset(w, h), Offset(w, h - l), p);
  }

  @override
  bool shouldRepaint(MarcasEsquina oldDelegate) =>
      oldDelegate.color != color || oldDelegate.largo != largo;
}
