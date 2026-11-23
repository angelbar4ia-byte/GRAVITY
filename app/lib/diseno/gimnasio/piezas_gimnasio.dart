/// Piezas pequeñas que comparten los componentes de «Mi gimnasio»: los cuatro
/// estados (vacío, cargando, sin conexión, error), la marca con icono y
/// palabra, y el botón de paso (− y +) de 56 dp.
library;

import 'package:flutter/material.dart';

import '../superficies.dart';
import '../tema.dart';
import '../valores_diseno.dart';
import 'textos_gimnasio.dart';
import 'tipos_gimnasio.dart';

/// Los textos de los estados de un componente. Cada componente trae los suyos
/// por omisión; la pantalla puede cambiarlos con lo que diga su catálogo.
@immutable
class MensajesEstadoGimnasio {
  const MensajesEstadoGimnasio({
    this.vacio = 'Todavía no hay nada aquí.',
    this.vacioDetalle,
    this.textoAccionVacia,
    this.cargando = TextosGimnasio.cargando,
    this.sinConexion = TextosGimnasio.sinConexionGenerico,
    this.error = TextosGimnasio.errorGenerico,
  });

  final String vacio;
  final String? vacioDetalle;

  /// Texto de la única acción sugerida del estado vacío; sin él no hay botón.
  final String? textoAccionVacia;
  final String cargando;
  final String sinConexion;
  final String error;

  /// El mensaje que corresponde a [estado] (vacío si es [listo], que no se usa).
  String de(EstadoVistaGimnasio estado) => switch (estado) {
    EstadoVistaGimnasio.listo || EstadoVistaGimnasio.vacio => vacio,
    EstadoVistaGimnasio.cargando => cargando,
    EstadoVistaGimnasio.sinConexion => sinConexion,
    EstadoVistaGimnasio.error => error,
  };
}

/// Cuerpo compacto de un estado que no es [EstadoVistaGimnasio.listo]: icono,
/// palabras y, si corresponde, un botón de 48 dp. Se anuncia al lector de
/// pantalla. Nunca reintenta solo.
class CuerpoEstadoGimnasio extends StatelessWidget {
  const CuerpoEstadoGimnasio({
    super.key,
    required this.estado,
    this.mensajes = const MensajesEstadoGimnasio(),
    this.alReintentar,
    this.alAccionVacia,
  }) : assert(estado != EstadoVistaGimnasio.listo);

  final EstadoVistaGimnasio estado;
  final MensajesEstadoGimnasio mensajes;

  /// Para *sin conexión* y *error*.
  final VoidCallback? alReintentar;

  /// La acción del estado vacío (con [MensajesEstadoGimnasio.textoAccionVacia]).
  final VoidCallback? alAccionVacia;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    final quieto = MediaQuery.disableAnimationsOf(context);
    final mensaje = mensajes.de(estado);
    final (icono, colorIcono, palabra) = switch (estado) {
      EstadoVistaGimnasio.vacio => (
        Icons.inbox_outlined,
        v.textoTenue,
        'Vacío',
      ),
      EstadoVistaGimnasio.sinConexion => (
        Icons.cloud_off_outlined,
        v.textoTenue,
        'Sin conexión',
      ),
      EstadoVistaGimnasio.error => (
        Icons.error_outline,
        v.alerta,
        'Error',
      ),
      _ => (Icons.hourglass_empty, v.textoTenue, 'Cargando'),
    };
    final conAccion =
        (estado == EstadoVistaGimnasio.sinConexion ||
            estado == EstadoVistaGimnasio.error) &&
        alReintentar != null;
    final conAccionVacia =
        estado == EstadoVistaGimnasio.vacio &&
        mensajes.textoAccionVacia != null &&
        alAccionVacia != null;
    return Semantics(
      container: true,
      liveRegion: true,
      label: '$palabra. $mensaje',
      excludeSemantics: !(conAccion || conAccionVacia),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: e * 1.5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (estado == EstadoVistaGimnasio.cargando)
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: v.acento,
                  value: quieto ? 0.35 : null,
                ),
              )
            else
              ExcludeSemantics(child: Icon(icono, size: 32, color: colorIcono)),
            SizedBox(height: e),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: v.lectura(
                tamano: 15,
                peso: FontWeight.w600,
                color: v.textoFuerte,
              ),
            ),
            if (estado == EstadoVistaGimnasio.vacio &&
                mensajes.vacioDetalle != null) ...[
              SizedBox(height: e * 0.5),
              Text(
                mensajes.vacioDetalle!,
                textAlign: TextAlign.center,
                style: v.lectura(tamano: 13.5, color: v.textoTenue),
              ),
            ],
            if (conAccion) ...[
              SizedBox(height: e * 1.5),
              OutlinedButton(
                onPressed: alReintentar,
                child: const Text(TextosGimnasio.reintentar),
              ),
            ],
            if (conAccionVacia) ...[
              SizedBox(height: e * 1.5),
              OutlinedButton(
                onPressed: alAccionVacia,
                child: Text(mensajes.textoAccionVacia!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Marca con icono y palabra (nunca solo color): estados, avisos y etiquetas.
/// Baja a otra línea el texto si no cabe.
class MarcaGimnasio extends StatelessWidget {
  const MarcaGimnasio({
    super.key,
    required this.texto,
    required this.icono,
    this.color,
    this.enfasis = false,
  });

  final String texto;
  final IconData icono;

  /// Color del icono y del borde; por omisión, el texto tenue.
  final Color? color;

  /// Relleno suave del color (para lo que no debe pasar desapercibido).
  final bool enfasis;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final tono = color ?? v.textoTenue;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: enfasis
            ? Color.alphaBlend(tono.withValues(alpha: 0.12), v.panel)
            : null,
        border: Border.all(color: tono, width: v.grosorBorde),
        borderRadius: BorderRadius.circular(v.radioGrande * 2),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: v.espacio * 1.25,
          vertical: v.espacio * 0.5,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(child: Icon(icono, size: 16, color: tono)),
            SizedBox(width: v.espacio * 0.6),
            Flexible(
              child: Text(
                texto,
                style: v.lectura(
                  tamano: 13,
                  peso: FontWeight.w600,
                  color: v.textoFuerte,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Botón cuadrado de un paso (− o +): **56 dp** (7.2 y 10), con etiqueta para el
/// lector de pantalla. Apagado (sin [alTocar]) se ve tenue con el borde
/// punteado por la forma, no por la transparencia, para no perder contraste.
class BotonPasoGimnasio extends StatelessWidget {
  const BotonPasoGimnasio({
    super.key,
    required this.icono,
    required this.etiqueta,
    required this.alTocar,
  });

  /// 56 dp: manos con sudor y uso con una mano (10).
  static const double tamano = 56;

  final IconData icono;

  /// Lo que lee el lector de pantalla («Quitar una repetición»).
  final String etiqueta;
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final activo = alTocar != null;
    final forma = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(v.radioMediano),
      side: BorderSide(
        color: activo ? v.acento : v.borde,
        width: v.grosorBorde + (activo ? 0.5 : 0),
      ),
    );
    return Semantics(
      button: true,
      enabled: activo,
      onTap: alTocar,
      label: etiqueta,
      excludeSemantics: true,
      child: Material(
        color: activo ? v.chipSeleccionado : v.panel,
        shape: forma,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: alTocar,
          child: SizedBox(
            width: tamano,
            height: tamano,
            child: Icon(
              icono,
              size: 28,
              color: activo ? v.textoFuerte : v.textoTenue,
            ),
          ),
        ),
      ),
    );
  }
}

/// Alto mínimo de un botón de acción grande de la sesión (✓ y temporizador).
const double altoAccionSesion = 64;

/// Zona táctil mínima, reexportada para los componentes.
const double zonaTactilGimnasio = zonaTactilMinima;
