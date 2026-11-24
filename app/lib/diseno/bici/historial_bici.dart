/// **Historial** (B5): barras de las últimas semanas **con texto
/// alternativo** y la lista de salidas.
///
/// Una semana sin salida, o una salida omitida por clima o por seguridad, se
/// muestra con icono y palabras neutras: **sin colores de alarma, sin racha y
/// sin culpa** (4.11). La nota de progresión (4.9) es una comparación de
/// números, no consejo de entrenamiento, y nunca bloquea nada. Nada compara
/// con otras personas.
library;

import 'package:flutter/material.dart';

import '../componentes/tarjeta_modulo.dart';
import '../superficies.dart';
import '../valores_diseno.dart';
import 'piezas_bici.dart';
import 'tipos_bici.dart';

/// Cómo fue una semana en el historial.
enum EstadoSemanaBici {
  conSalida('Con salida', Icons.directions_bike),
  sinSalida('Sin salida', Icons.remove_circle_outline),
  omitidaPorClima('Omitida por clima', Icons.cloud_outlined),
  omitidaPorSeguridad('Omitida por seguridad', Icons.shield_outlined);

  const EstadoSemanaBici(this.texto, this.icono);

  final String texto;
  final IconData icono;
}

/// Una barra del historial: una semana.
@immutable
class BarraSalidaVista {
  const BarraSalidaVista({
    required this.etiqueta,
    required this.valor,
    required this.valorTexto,
    this.estado = EstadoSemanaBici.conSalida,
    this.detalleTexto,
  });

  /// «Semana del 16 nov».
  final String etiqueta;

  /// Alto relativo de la barra (cualquier escala; se normaliza con el máximo).
  final double valor;

  /// El valor en palabras: «62,4 km», «sin salida».
  final String valorTexto;
  final EstadoSemanaBici estado;

  /// «4 h 05 min · mixta».
  final String? detalleTexto;

  String get anuncio => [
    etiqueta,
    valorTexto,
    if (estado != EstadoSemanaBici.conSalida) estado.texto.toLowerCase(),
    ?detalleTexto,
  ].join(', ');
}

/// **Barras de historial** de las salidas: una fila por semana, con la
/// etiqueta y el valor arriba y la barra debajo (así aguanta la letra grande
/// sin recortar nada).
class BarrasHistorialBici extends StatelessWidget {
  const BarrasHistorialBici({
    super.key,
    required this.barras,
    this.titulo = 'Kilómetros por semana',
    this.subtitulo,
    this.resumenAccesible,
    this.notaProgresionTexto,
    this.modoFoco = false,
    this.estado = EstadoVistaBici.listo,
    this.mensajes = const MensajesEstadoBici(
      vacio: 'Todavía no hay salidas registradas.',
      vacioDetalle: 'Cuando registres una, aparece aquí.',
      cargando: 'Cargando tu historial…',
      sinConexion: 'Sin conexión. Se muestra el historial guardado aquí.',
      error: 'No se pudo cargar el historial. Puedes intentarlo otra vez.',
    ),
    this.alReintentar,
  });

  final String titulo;

  /// «Últimas 6 semanas».
  final String? subtitulo;
  final List<BarraSalidaVista> barras;

  /// Texto alternativo de toda la gráfica; por omisión se arma con los datos.
  final String? resumenAccesible;

  /// La nota informativa de 4.9 («Esta salida fue bastante más larga…»).
  final String? notaProgresionTexto;

  /// Con el modo foco la nota no se muestra (4.10).
  final bool modoFoco;
  final EstadoVistaBici estado;
  final MensajesEstadoBici mensajes;
  final VoidCallback? alReintentar;

  /// El texto alternativo armado con las barras.
  String get textoAlternativo =>
      resumenAccesible ??
      '$titulo. ${barras.length} '
          '${barras.length == 1 ? 'semana' : 'semanas'}. '
          '${barras.map((b) => b.anuncio).join('. ')}.';

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    if (estado != EstadoVistaBici.listo || barras.isEmpty) {
      return TarjetaModulo(
        titulo: titulo,
        icono: Icons.bar_chart,
        child: CuerpoEstadoBici(
          estado: estado == EstadoVistaBici.listo
              ? EstadoVistaBici.vacio
              : estado,
          mensajes: mensajes,
          alReintentar: alReintentar,
        ),
      );
    }
    var maximo = 0.0;
    for (final b in barras) {
      if (b.valor > maximo) maximo = b.valor;
    }
    final nota = modoFoco ? null : notaProgresionTexto;
    return TarjetaModulo(
      titulo: titulo,
      icono: Icons.bar_chart,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            container: true,
            label: textoAlternativo,
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (subtitulo != null)
                  Padding(
                    padding: EdgeInsets.only(bottom: e * 1.5),
                    child: Text(
                      subtitulo!,
                      style: v.lectura(tamano: 14, color: v.textoTenue),
                    ),
                  ),
                for (var i = 0; i < barras.length; i++) ...[
                  if (i > 0) SizedBox(height: e * 1.5),
                  _FilaBarra(barra: barras[i], maximo: maximo),
                ],
              ],
            ),
          ),
          if (nota != null) ...[
            SizedBox(height: e * 1.5),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 20, color: v.textoTenue),
                SizedBox(width: e),
                Expanded(
                  child: Text(
                    nota,
                    key: const ValueKey('historial-nota'),
                    style: v.lectura(tamano: 14, color: v.texto),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FilaBarra extends StatelessWidget {
  const _FilaBarra({required this.barra, required this.maximo});

  final BarraSalidaVista barra;
  final double maximo;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    final fraccion = maximo <= 0 ? 0.0 : (barra.valor / maximo).clamp(0.0, 1.0);
    final conSalida = barra.estado == EstadoSemanaBici.conSalida;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: e,
          children: [
            Text(
              barra.etiqueta,
              style: v.lectura(tamano: 14, color: v.textoTenue),
            ),
            Text(
              barra.valorTexto,
              style: v.numero(
                tamano: 15,
                peso: FontWeight.w700,
                color: v.textoFuerte,
              ),
            ),
          ],
        ),
        SizedBox(height: e * 0.5),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: SizedBox(
            height: 14,
            child: ColoredBox(
              color: v.pista,
              child: FractionallySizedBox(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: conSalida ? fraccion : 0,
                heightFactor: 1,
                child: ColoredBox(color: v.acento),
              ),
            ),
          ),
        ),
        if (!conSalida || barra.detalleTexto != null) ...[
          SizedBox(height: e * 0.75),
          Wrap(
            spacing: e,
            runSpacing: e * 0.5,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (!conSalida)
                MarcaBici(texto: barra.estado.texto, icono: barra.estado.icono),
              if (barra.detalleTexto != null)
                Text(
                  barra.detalleTexto!,
                  style: v.lectura(tamano: 13.5, color: v.textoTenue),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Una salida de la lista del historial.
@immutable
class SalidaHistorialVista {
  const SalidaHistorialVista({
    required this.fechaTexto,
    required this.resumenTexto,
    this.superficie,
    this.esfuerzoTexto,
    this.climaTexto,
    this.acompanado = false,
  });

  /// «sáb 21 nov».
  final String fechaTexto;

  /// «4 h 05 min · 62,4 km».
  final String resumenTexto;
  final SuperficieSalida? superficie;

  /// «Esfuerzo 3 de 5».
  final String? esfuerzoTexto;

  /// «Despejado».
  final String? climaTexto;
  final bool acompanado;

  String get anuncio => [
    fechaTexto,
    resumenTexto,
    ?textoRuta(superficie),
    ?esfuerzoTexto,
    ?climaTexto,
    if (acompanado) 'acompañado',
  ].join(', ');
}

/// La lista de salidas del historial.
class ListaSalidasHistorial extends StatelessWidget {
  const ListaSalidasHistorial({
    super.key,
    required this.salidas,
    this.alTocarSalida,
    this.estado = EstadoVistaBici.listo,
    this.mensajes = const MensajesEstadoBici(
      vacio: 'Todavía no hay salidas registradas.',
      cargando: 'Cargando tus salidas…',
      sinConexion: 'Sin conexión. Se muestran las salidas guardadas aquí.',
      error: 'No se pudieron cargar tus salidas.',
    ),
    this.alReintentar,
  });

  final List<SalidaHistorialVista> salidas;
  final ValueChanged<int>? alTocarSalida;
  final EstadoVistaBici estado;
  final MensajesEstadoBici mensajes;
  final VoidCallback? alReintentar;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    if (estado != EstadoVistaBici.listo || salidas.isEmpty) {
      return TarjetaModulo(
        titulo: 'Salidas',
        icono: Icons.list_alt,
        child: CuerpoEstadoBici(
          estado: estado == EstadoVistaBici.listo
              ? EstadoVistaBici.vacio
              : estado,
          mensajes: mensajes,
          alReintentar: alReintentar,
        ),
      );
    }
    return TarjetaModulo(
      titulo: 'Salidas',
      icono: Icons.list_alt,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < salidas.length; i++) ...[
            if (i > 0) SizedBox(height: e),
            _FilaSalida(
              salida: salidas[i],
              alTocar: alTocarSalida == null ? null : () => alTocarSalida!(i),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilaSalida extends StatelessWidget {
  const _FilaSalida({required this.salida, required this.alTocar});

  final SalidaHistorialVista salida;
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    final contenido = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: zonaTactilBici),
      child: Padding(
        padding: EdgeInsets.all(e * 1.25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(salida.fechaTexto, style: v.etiquetaPanel()),
            Text(
              salida.resumenTexto,
              style: v.numero(
                tamano: 16,
                peso: FontWeight.w600,
                color: v.textoFuerte,
              ),
            ),
            if (salida.superficie != null ||
                salida.esfuerzoTexto != null ||
                salida.climaTexto != null ||
                salida.acompanado) ...[
              SizedBox(height: e * 0.75),
              Wrap(
                spacing: e,
                runSpacing: e * 0.5,
                children: [
                  if (salida.superficie != null)
                    MarcaBici(
                      texto: salida.superficie!.texto,
                      icono: salida.superficie!.icono,
                    ),
                  if (salida.esfuerzoTexto != null)
                    MarcaBici(texto: salida.esfuerzoTexto!, icono: Icons.speed),
                  if (salida.climaTexto != null)
                    MarcaBici(
                      texto: salida.climaTexto!,
                      icono: Icons.wb_sunny_outlined,
                    ),
                  if (salida.acompanado)
                    const MarcaBici(
                      texto: 'Acompañado',
                      icono: Icons.people_outline,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
    return Semantics(
      container: true,
      button: alTocar != null,
      onTap: alTocar,
      label: salida.anuncio,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: v.panel,
          border: Border.all(color: v.borde, width: v.grosorBorde),
          borderRadius: BorderRadius.circular(v.radioMediano),
        ),
        child: alTocar == null
            ? contenido
            : InkWell(
                borderRadius: BorderRadius.circular(v.radioMediano),
                onTap: alTocar,
                child: contenido,
              ),
      ),
    );
  }
}
