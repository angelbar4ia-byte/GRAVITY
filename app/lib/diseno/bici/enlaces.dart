/// **Enlaces externos** (3.1, 3.12, F-B9): abrir tu música, tu mapa o tu clima
/// **en la app que ya usas**. Un enlace nunca se abre solo: hace falta un
/// toque. Si la app no está, el botón dice «No se pudo abrir» y no pasa nada
/// más. Cada botón mide 48 dp o más y lleva icono, palabra y «se abre en otra
/// app» para el lector de pantalla.
library;

import 'package:flutter/material.dart';

import '../componentes/tarjeta_modulo.dart';
import '../valores_diseno.dart';
import 'piezas_bici.dart';
import 'textos_bici.dart';
import 'tipos_bici.dart';

/// Un enlace guardado por la persona, con datos ya armados.
@immutable
class EnlaceVista {
  const EnlaceVista({
    required this.tipo,
    required this.texto,
    this.nombreTexto,
    this.guardado = true,
    this.noSePudoAbrir = false,
    this.alAbrir,
  });

  final TipoEnlace tipo;

  /// El texto del botón («Abrir mi lista», «Ver el clima»).
  final String texto;

  /// El nombre que le puso la persona («Rodadas de sábado»); sin direcciones.
  final String? nombreTexto;

  /// Si ya hay un enlace guardado; si no, se invita a guardarlo en Ajustes.
  final bool guardado;

  /// El último intento no encontró la app: se avisa sin romper nada.
  final bool noSePudoAbrir;
  final VoidCallback? alAbrir;
}

/// La lista de enlaces de la salida.
class ListaEnlaces extends StatelessWidget {
  const ListaEnlaces({
    super.key,
    required this.enlaces,
    this.estado = EstadoVistaBici.listo,
    this.mensajes = const MensajesEstadoBici(
      vacio: 'Todavía no guardas ningún enlace.',
      vacioDetalle: 'En Ajustes puedes guardar tu lista, tu mapa y tu clima.',
      cargando: 'Cargando tus enlaces…',
      sinConexion: 'Sin conexión. Tus enlaces se abren cuando haya señal.',
      error: 'No se pudieron cargar tus enlaces.',
    ),
    this.alReintentar,
  });

  final List<EnlaceVista> enlaces;
  final EstadoVistaBici estado;
  final MensajesEstadoBici mensajes;
  final VoidCallback? alReintentar;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    if (estado != EstadoVistaBici.listo || enlaces.isEmpty) {
      return TarjetaModulo(
        titulo: 'Música, mapa y clima',
        icono: Icons.open_in_new,
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
      titulo: 'Música, mapa y clima',
      icono: Icons.open_in_new,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: e,
            runSpacing: e,
            children: [for (final x in enlaces) _BotonEnlace(enlace: x)],
          ),
          for (final x in enlaces.where((x) => x.noSePudoAbrir)) ...[
            SizedBox(height: e),
            MarcaBici(
              texto: '${x.tipo.texto}: ${TextosBici.noSePudoAbrir}',
              icono: Icons.link_off,
              color: v.alerta,
              enfasis: true,
            ),
          ],
          SizedBox(height: e * 1.25),
          Text(
            TextosBici.seAbreEnOtraApp,
            style: v.lectura(tamano: 13.5, color: v.textoTenue),
          ),
        ],
      ),
    );
  }
}

class _BotonEnlace extends StatelessWidget {
  const _BotonEnlace({required this.enlace});

  final EnlaceVista enlace;

  @override
  Widget build(BuildContext context) {
    final activo = enlace.guardado && enlace.alAbrir != null;
    final etiqueta = [
      enlace.texto,
      ?enlace.nombreTexto,
      if (!enlace.guardado) 'sin enlace guardado'
      else TextosBici.seAbreEnOtraApp.toLowerCase(),
    ].join(', ');
    return Semantics(
      button: true,
      enabled: activo,
      onTap: activo ? enlace.alAbrir : null,
      label: etiqueta,
      excludeSemantics: true,
      child: OutlinedButton.icon(
        onPressed: activo ? enlace.alAbrir : null,
        icon: Icon(enlace.tipo.icono, size: 20),
        label: Text(
          enlace.guardado
              ? enlace.texto
              : '${enlace.texto} (sin enlace)',
        ),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(zonaTactilBici, 56),
        ),
      ),
    );
  }
}
