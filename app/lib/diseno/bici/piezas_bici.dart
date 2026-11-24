/// Piezas pequeñas que comparten los componentes de «Bicicleta»: los cuatro
/// estados (vacío, cargando, sin conexión, error), la marca con icono y
/// palabra, el botón de paso (− y +), la opción seleccionable y el aviso con
/// acciones. Todo lee del tema: nunca colores fijos.
library;

import 'package:flutter/material.dart';

import '../superficies.dart';
import '../tema.dart';
import '../valores_diseno.dart';
import 'textos_bici.dart';
import 'tipos_bici.dart';

/// Alto mínimo de un botón grande de la salida (*Salí*, *Terminar*): 64 dp en
/// el cronómetro y el visor (6.6).
const double altoAccionBici = 64;

/// Zona táctil mínima de los demás controles: 48 dp (6.6).
const double zonaTactilBici = zonaTactilMinima;

/// Los textos de los estados de un componente. Cada componente trae los suyos
/// por omisión; la pantalla puede cambiarlos con lo que diga su catálogo.
@immutable
class MensajesEstadoBici {
  const MensajesEstadoBici({
    this.vacio = 'Todavía no hay nada aquí.',
    this.vacioDetalle,
    this.textoAccionVacia,
    this.cargando = TextosBici.cargando,
    this.sinConexion = TextosBici.sinConexionGenerico,
    this.error = TextosBici.errorGenerico,
  });

  final String vacio;
  final String? vacioDetalle;

  /// Texto de la única acción sugerida del estado vacío; sin él no hay botón.
  final String? textoAccionVacia;
  final String cargando;
  final String sinConexion;
  final String error;

  /// El mensaje que corresponde a [estado] (vacío si es [listo], que no se usa).
  String de(EstadoVistaBici estado) => switch (estado) {
    EstadoVistaBici.listo || EstadoVistaBici.vacio => vacio,
    EstadoVistaBici.cargando => cargando,
    EstadoVistaBici.sinConexion => sinConexion,
    EstadoVistaBici.error => error,
  };
}

/// Cuerpo compacto de un estado que no es [EstadoVistaBici.listo]: icono,
/// palabras y, si corresponde, un botón de 48 dp. Se anuncia al lector de
/// pantalla. Nunca reintenta solo.
class CuerpoEstadoBici extends StatelessWidget {
  const CuerpoEstadoBici({
    super.key,
    required this.estado,
    this.mensajes = const MensajesEstadoBici(),
    this.alReintentar,
    this.alAccionVacia,
  }) : assert(estado != EstadoVistaBici.listo);

  final EstadoVistaBici estado;
  final MensajesEstadoBici mensajes;

  /// Para *sin conexión* y *error*.
  final VoidCallback? alReintentar;

  /// La acción del estado vacío (con [MensajesEstadoBici.textoAccionVacia]).
  final VoidCallback? alAccionVacia;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    final quieto = MediaQuery.disableAnimationsOf(context);
    final mensaje = mensajes.de(estado);
    final (icono, colorIcono, palabra) = switch (estado) {
      EstadoVistaBici.vacio => (Icons.inbox_outlined, v.textoTenue, 'Vacío'),
      EstadoVistaBici.sinConexion => (
        Icons.cloud_off_outlined,
        v.textoTenue,
        'Sin conexión',
      ),
      EstadoVistaBici.error => (Icons.error_outline, v.alerta, 'Error'),
      _ => (Icons.hourglass_empty, v.textoTenue, 'Cargando'),
    };
    final conAccion =
        (estado == EstadoVistaBici.sinConexion ||
            estado == EstadoVistaBici.error) &&
        alReintentar != null;
    final conAccionVacia =
        estado == EstadoVistaBici.vacio &&
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
            if (estado == EstadoVistaBici.cargando)
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
            if (estado == EstadoVistaBici.vacio &&
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
                child: const Text(TextosBici.reintentar),
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
class MarcaBici extends StatelessWidget {
  const MarcaBici({
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

/// Botón cuadrado de un paso (− o +): **56 dp**, con etiqueta para el lector
/// de pantalla. Apagado (sin [alTocar]) se ve tenue con el borde distinto por
/// la forma y el color, no por la transparencia, para no perder contraste.
class BotonPasoBici extends StatelessWidget {
  const BotonPasoBici({
    super.key,
    required this.icono,
    required this.etiqueta,
    required this.alTocar,
  });

  /// 56 dp: uso con una mano y manos con guantes.
  static const double tamano = 56;

  final IconData icono;

  /// Lo que lee el lector de pantalla («Quitar 15 minutos»).
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

/// Un valor con su − y su +: duración, margen o tope. Los botones miden 56 dp.
class SelectorPasosBici extends StatelessWidget {
  const SelectorPasosBici({
    super.key,
    required this.etiqueta,
    required this.valorTexto,
    required this.etiquetaMenos,
    required this.etiquetaMas,
    this.descripcionAccesible,
    this.alMenos,
    this.alMas,
  });

  /// «DURACIÓN».
  final String etiqueta;

  /// El valor grande: «4 h», «90 min».
  final String valorTexto;

  /// Lo que lee el lector en el botón −.
  final String etiquetaMenos;

  /// Lo que lee el lector en el botón +.
  final String etiquetaMas;

  /// Frase completa para el lector; por omisión, la etiqueta y el valor.
  final String? descripcionAccesible;

  /// `null` apaga el botón − (ya está en el mínimo).
  final VoidCallback? alMenos;

  /// `null` apaga el botón + (ya está en el tope).
  final VoidCallback? alMas;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              label: descripcionAccesible ?? '$etiqueta: $valorTexto',
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(etiqueta, style: v.etiquetaPanel()),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      valorTexto,
                      maxLines: 1,
                      style: v.numero(
                        tamano: 30,
                        peso: FontWeight.w700,
                        color: v.textoFuerte,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: e),
          BotonPasoBici(
            icono: Icons.remove,
            etiqueta: etiquetaMenos,
            alTocar: alMenos,
          ),
          SizedBox(width: e),
          BotonPasoBici(
            icono: Icons.add,
            etiqueta: etiquetaMas,
            alTocar: alMas,
          ),
        ],
      ),
    );
  }
}

/// Una opción de un grupo de una sola elección (superficie, clima, carga de
/// piernas, esfuerzo): 48 dp o más. La elegida lleva **marca de verificación,
/// borde grueso y la palabra «seleccionado» para el lector de pantalla**, no
/// solo color.
class OpcionBici extends StatelessWidget {
  const OpcionBici({
    super.key,
    required this.texto,
    required this.seleccionada,
    required this.alTocar,
    this.icono,
    this.etiquetaAccesible,
  });

  final String texto;
  final bool seleccionada;
  final VoidCallback? alTocar;
  final IconData? icono;

  /// Frase para el lector («Esfuerzo 3, moderado»); por omisión, el texto.
  final String? etiquetaAccesible;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    final forma = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(v.radioMediano),
      side: BorderSide(
        color: seleccionada ? v.acento : v.borde,
        width: v.grosorBorde + (seleccionada ? 1 : 0),
      ),
    );
    return Semantics(
      button: true,
      selected: seleccionada,
      inMutuallyExclusiveGroup: true,
      onTap: alTocar,
      label: etiquetaAccesible ?? texto,
      excludeSemantics: true,
      child: Material(
        color: seleccionada ? v.chipSeleccionado : v.panel,
        shape: forma,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: alTocar,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: zonaTactilMinima,
              minWidth: zonaTactilMinima,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: e * 1.5,
                vertical: e * 0.75,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (seleccionada) ...[
                    Icon(Icons.check, size: 18, color: v.acento),
                    SizedBox(width: e * 0.5),
                  ] else if (icono != null) ...[
                    Icon(icono, size: 18, color: v.textoTenue),
                    SizedBox(width: e * 0.5),
                  ],
                  Flexible(
                    child: Text(
                      texto,
                      style: v.lectura(
                        tamano: 14.5,
                        peso: seleccionada ? FontWeight.w700 : FontWeight.w500,
                        color: v.textoFuerte,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Una acción de un [AvisoBici] (*Ver opciones*, *Dejarlo así*).
@immutable
class AccionAvisoBici {
  const AccionAvisoBici({required this.texto, required this.alTocar});

  final String texto;
  final VoidCallback? alTocar;
}

/// Un aviso con icono y la palabra «Aviso» (nunca solo color): el de las
/// piernas y las 48 horas (4.6) o el de la revisión que no cabe (4.7). Dice
/// qué pasa y qué opciones hay, sin culpa; se cierra con *Dejarlo así*.
class AvisoBici extends StatelessWidget {
  const AvisoBici({
    super.key,
    required this.texto,
    this.acciones = const [],
    this.icono = Icons.info_outline,
  });

  final String texto;
  final List<AccionAvisoBici> acciones;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color.alphaBlend(v.alerta.withValues(alpha: 0.08), v.panel),
          border: Border.all(color: v.alerta, width: v.grosorBorde),
          borderRadius: BorderRadius.circular(v.radioMediano),
        ),
        child: Padding(
          padding: EdgeInsets.all(e * 1.5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                container: true,
                label: 'Aviso: $texto',
                excludeSemantics: true,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icono, size: 20, color: v.alerta),
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
              if (acciones.isNotEmpty) ...[
                SizedBox(height: e),
                Wrap(
                  spacing: e,
                  runSpacing: e * 0.5,
                  children: [
                    for (final a in acciones)
                      TextButton(
                        onPressed: a.alTocar,
                        child: Text(a.texto),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// «Contenido en revisión» (borrador): los intervalos de mantenimiento y los
/// textos de seguridad se marcan así mientras el dueño no los confirme (4.8).
/// Compacta es una sola línea; completa agrega la frase de «guía general».
class TarjetaContenidoEnRevisionBici extends StatelessWidget {
  const TarjetaContenidoEnRevisionBici({
    super.key,
    this.compacta = false,
    this.texto = TextosBici.contenidoEnRevision,
    this.detalle = TextosBici.contenidoEnRevisionDetalle,
    this.alAbrir,
    this.estado = EstadoVistaBici.listo,
    this.mensajes = const MensajesEstadoBici(
      vacio: 'Todo el contenido está revisado.',
      cargando: 'Revisando el estado del contenido…',
      sinConexion: 'Sin conexión. El contenido viene con la app.',
      error: 'No se pudo leer el estado de la revisión del contenido.',
    ),
    this.alReintentar,
  });

  final bool compacta;
  final String texto;
  final String detalle;

  /// Abre *Sobre esta guía*; con él la tarjeta se toca (48 dp o más).
  final VoidCallback? alAbrir;

  /// `listo`: hay contenido en revisión. `vacio`: todo revisado.
  final EstadoVistaBici estado;
  final MensajesEstadoBici mensajes;
  final VoidCallback? alReintentar;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    if (estado != EstadoVistaBici.listo) {
      return DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: v.borde, width: v.grosorBorde),
          borderRadius: BorderRadius.circular(v.radioMediano),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: e * 1.5),
          child: CuerpoEstadoBici(
            estado: estado,
            mensajes: mensajes,
            alReintentar: alReintentar,
          ),
        ),
      );
    }
    final cuerpo = Padding(
      padding: EdgeInsets.symmetric(horizontal: e * 1.5, vertical: e * 1.25),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.rule_folder_outlined, size: 22, color: v.alerta),
          SizedBox(width: e * 1.25),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  texto,
                  style: v.lectura(
                    tamano: 15,
                    peso: FontWeight.w700,
                    color: v.textoFuerte,
                  ),
                ),
                if (!compacta) ...[
                  SizedBox(height: e * 0.5),
                  Text(detalle, style: v.lectura(tamano: 14, color: v.texto)),
                ],
              ],
            ),
          ),
          if (alAbrir != null) ...[
            SizedBox(width: e),
            Padding(
              padding: EdgeInsets.only(top: e * 0.25),
              child: Icon(Icons.chevron_right, size: 22, color: v.textoTenue),
            ),
          ],
        ],
      ),
    );
    final forma = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(v.radioMediano),
      side: BorderSide(color: v.alerta, width: v.grosorBorde),
    );
    return Semantics(
      container: true,
      button: alAbrir != null,
      onTap: alAbrir,
      label: compacta ? texto : '$texto. $detalle',
      hint: alAbrir == null ? null : TextosBici.sobreEstaGuia,
      excludeSemantics: true,
      child: Material(
        color: Color.alphaBlend(v.alerta.withValues(alpha: 0.08), v.panel),
        shape: forma,
        clipBehavior: Clip.antiAlias,
        child: alAbrir == null
            ? ConstrainedBox(
                constraints: const BoxConstraints(minHeight: zonaTactilMinima),
                child: cuerpo,
              )
            : InkWell(
                onTap: alAbrir,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: zonaTactilMinima,
                  ),
                  child: cuerpo,
                ),
              ),
      ),
    );
  }
}
