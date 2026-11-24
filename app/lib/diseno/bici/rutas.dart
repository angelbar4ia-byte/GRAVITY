/// **Rutas guardadas** (B6, F-B6): recorridos que la persona escribió a mano.
/// Viven **solo en el teléfono donde se guardaron** y nunca llegan al
/// servidor ni a la laptop; la lista lo dice. Cada fila lleva el nombre, la
/// distancia que ella escribió, el desnivel y el tipo, con icono y palabras.
library;

import 'package:flutter/material.dart';

import '../componentes/tarjeta_modulo.dart';
import '../valores_diseno.dart';
import 'piezas_bici.dart';
import 'textos_bici.dart';
import 'tipos_bici.dart';

/// Una ruta guardada a mano, con datos ya armados.
@immutable
class RutaVista {
  const RutaVista({
    required this.id,
    required this.nombre,
    this.distanciaTexto,
    this.desnivelTexto,
    this.superficie,
    this.tramosTexto,
  });

  final String id;

  /// «Vuelta al cerro (ejemplo)».
  final String nombre;

  /// «42,0 km».
  final String? distanciaTexto;

  /// «+ 310 m».
  final String? desnivelTexto;
  final SuperficieSalida? superficie;

  /// «6 km de calle, 12 km de terreno».
  final String? tramosTexto;

  String get anuncio => [
    nombre,
    ?distanciaTexto,
    if (desnivelTexto != null) 'desnivel $desnivelTexto',
    if (superficie != null) 'ruta ${superficie!.texto.toLowerCase()}',
    ?tramosTexto,
  ].join(', ');
}

/// La lista de rutas guardadas.
class ListaRutas extends StatelessWidget {
  const ListaRutas({
    super.key,
    required this.rutas,
    this.enEsteEquipo = true,
    this.alElegir,
    this.alNueva,
    this.estado = EstadoVistaBici.listo,
    this.mensajes = const MensajesEstadoBici(
      vacio: 'Todavía no guardas ninguna ruta.',
      vacioDetalle: 'Escribe el nombre y, si quieres, la distancia.',
      textoAccionVacia: 'Nueva ruta',
      cargando: 'Cargando tus rutas…',
      sinConexion: 'Sin conexión. Tus rutas viven en este teléfono.',
      error: 'No se pudieron cargar tus rutas.',
    ),
    this.alReintentar,
  });

  final List<RutaVista> rutas;

  /// `false` en la laptop: las rutas no se muestran ni se conocen ahí.
  final bool enEsteEquipo;
  final ValueChanged<String>? alElegir;
  final VoidCallback? alNueva;
  final EstadoVistaBici estado;
  final MensajesEstadoBici mensajes;
  final VoidCallback? alReintentar;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    if (!enEsteEquipo) {
      return TarjetaModulo(
        titulo: 'Rutas guardadas',
        icono: Icons.route_outlined,
        child: Semantics(
          container: true,
          label: TextosBici.rutasSoloEnTelefono,
          excludeSemantics: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.phone_android, size: 22, color: v.textoTenue),
              SizedBox(width: e),
              Expanded(
                child: Text(
                  TextosBici.rutasSoloEnTelefono,
                  style: v.lectura(tamano: 15, color: v.texto),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (estado != EstadoVistaBici.listo || rutas.isEmpty) {
      return TarjetaModulo(
        titulo: 'Rutas guardadas',
        icono: Icons.route_outlined,
        child: CuerpoEstadoBici(
          estado: estado == EstadoVistaBici.listo
              ? EstadoVistaBici.vacio
              : estado,
          mensajes: mensajes,
          alReintentar: alReintentar,
          alAccionVacia: alNueva,
        ),
      );
    }
    return TarjetaModulo(
      titulo: 'Rutas guardadas',
      icono: Icons.route_outlined,
      accion: const MarcaBici(
        texto: TextosBici.soloEnEsteEquipo,
        icono: Icons.phone_android,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final r in rutas) ...[
            _FilaRuta(
              ruta: r,
              alElegir: alElegir == null ? null : () => alElegir!(r.id),
            ),
            SizedBox(height: e),
          ],
          if (alNueva != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.icon(
                onPressed: alNueva,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(zonaTactilBici, 56),
                ),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Nueva ruta'),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilaRuta extends StatelessWidget {
  const _FilaRuta({required this.ruta, required this.alElegir});

  final RutaVista ruta;
  final VoidCallback? alElegir;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    final contenido = Padding(
      padding: EdgeInsets.all(e * 1.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ruta.nombre,
            style: v.lectura(
              tamano: 16,
              peso: FontWeight.w700,
              color: v.textoFuerte,
            ),
          ),
          if (ruta.distanciaTexto != null || ruta.desnivelTexto != null)
            Text(
              [?ruta.distanciaTexto, ?ruta.desnivelTexto].join(' · '),
              style: v.numero(tamano: 15, color: v.texto),
            ),
          if (ruta.superficie != null || ruta.tramosTexto != null) ...[
            SizedBox(height: e * 0.75),
            Wrap(
              spacing: e,
              runSpacing: e * 0.5,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (ruta.superficie != null)
                  MarcaBici(
                    texto: ruta.superficie!.texto,
                    icono: ruta.superficie!.icono,
                  ),
                if (ruta.tramosTexto != null)
                  Text(
                    ruta.tramosTexto!,
                    style: v.lectura(tamano: 13.5, color: v.textoTenue),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
    return Semantics(
      container: true,
      button: alElegir != null,
      onTap: alElegir,
      label: ruta.anuncio,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: v.panel,
          border: Border.all(color: v.borde, width: v.grosorBorde),
          borderRadius: BorderRadius.circular(v.radioMediano),
        ),
        child: alElegir == null
            ? contenido
            : InkWell(
                borderRadius: BorderRadius.circular(v.radioMediano),
                onTap: alElegir,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: zonaTactilBici),
                  child: contenido,
                ),
              ),
      ),
    );
  }
}
