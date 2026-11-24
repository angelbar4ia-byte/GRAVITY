/// **Lista de preparación** (B3, 4.2): lo que se revisa y se lleva, con la
/// noche anterior (viernes) y antes de salir (sábado).
///
/// Marcar un punto es un toque y se puede deshacer; **un punto sin marcar no
/// bloquea nada** (RB6). Cada punto lleva icono y palabra («Casco, marcado» o
/// «Casco, pendiente»), nunca solo color, y mide 48 dp o más. Debajo va la
/// línea fija de que la lista no es una garantía de seguridad.
library;

import 'package:flutter/material.dart';

import '../componentes/barra_progreso.dart';
import '../componentes/tarjeta_modulo.dart';
import '../valores_diseno.dart';
import 'piezas_bici.dart';
import 'textos_bici.dart';
import 'tipos_bici.dart';

/// Un punto de la lista, con datos ya calculados.
@immutable
class PuntoPreparacionVista {
  const PuntoPreparacionVista({
    required this.id,
    required this.texto,
    this.marcado = false,
    this.ambito = AmbitoPunto.todas,
    this.propio = false,
  });

  /// Identificador estable («casco_puesto»); se devuelve en el aviso.
  final String id;

  /// «Casco y ropa visible listos».
  final String texto;
  final bool marcado;

  /// Si solo aplica a calle o terreno (4.2).
  final AmbitoPunto ambito;

  /// Un punto que escribió la persona (hasta 10 de 60 caracteres).
  final bool propio;

  EstadoPunto get estado =>
      marcado ? EstadoPunto.marcado : EstadoPunto.pendiente;

  /// Lo que lee el lector de pantalla.
  String get anuncio => [
    texto,
    estado.texto.toLowerCase(),
    if (ambito != AmbitoPunto.todas) ambito.texto.toLowerCase(),
  ].join(', ');
}

/// La lista de preparación de un momento.
class ListaPreparacion extends StatelessWidget {
  const ListaPreparacion({
    super.key,
    required this.momento,
    required this.puntos,
    this.alCambiar,
    this.alListo,
    this.alEditar,
    this.mostrarGuia = true,
    this.estado = EstadoVistaBici.listo,
    this.mensajes = const MensajesEstadoBici(
      vacio: 'Todavía no hay puntos en tu lista.',
      vacioDetalle: 'Puedes agregar los tuyos o dejar los de siempre.',
      textoAccionVacia: 'Agregar un punto',
      cargando: 'Cargando tu lista…',
      sinConexion: 'Sin conexión. Tu lista guardada sigue aquí.',
      error: 'No se pudo cargar tu lista. Puedes intentarlo otra vez.',
    ),
    this.alReintentar,
    this.alAccionVacia,
  });

  final MomentoPreparacion momento;
  final List<PuntoPreparacionVista> puntos;

  /// Marca o desmarca un punto: recibe su id y el valor nuevo.
  final void Function(String id, bool marcado)? alCambiar;

  /// *Listo*; no exige tener todo marcado.
  final VoidCallback? alListo;

  /// Editar la lista (laptop): apagar puntos o agregar propios.
  final VoidCallback? alEditar;

  /// La línea fija «Esta guía no sustituye tu prudencia…».
  final bool mostrarGuia;
  final EstadoVistaBici estado;
  final MensajesEstadoBici mensajes;
  final VoidCallback? alReintentar;
  final VoidCallback? alAccionVacia;

  /// «8 de 10».
  String get progresoTexto =>
      '${puntos.where((p) => p.marcado).length} de ${puntos.length}';

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    if (estado != EstadoVistaBici.listo || puntos.isEmpty) {
      return TarjetaModulo(
        titulo: 'Preparación',
        icono: Icons.checklist,
        child: CuerpoEstadoBici(
          estado: estado == EstadoVistaBici.listo
              ? EstadoVistaBici.vacio
              : estado,
          mensajes: mensajes,
          alReintentar: alReintentar,
          alAccionVacia: alAccionVacia,
        ),
      );
    }
    final marcados = puntos.where((p) => p.marcado).length;
    return TarjetaModulo(
      titulo: 'Preparación',
      icono: Icons.checklist,
      accion: MarcaBici(texto: momento.texto, icono: momento.icono),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            container: true,
            label: 'Preparación, $progresoTexto marcados',
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Preparación ($progresoTexto)',
                  key: const ValueKey('preparacion-progreso'),
                  style: v.lectura(
                    tamano: 16,
                    peso: FontWeight.w700,
                    color: v.textoFuerte,
                  ),
                ),
                SizedBox(height: e),
                BarraProgreso(
                  valor: puntos.isEmpty ? 0 : marcados / puntos.length,
                  textoValor: ' ',
                  alto: 8,
                ),
              ],
            ),
          ),
          SizedBox(height: e),
          for (final p in puntos)
            _FilaPunto(
              punto: p,
              alCambiar: alCambiar == null
                  ? null
                  : () => alCambiar!(p.id, !p.marcado),
            ),
          if (mostrarGuia) ...[
            SizedBox(height: e * 1.5),
            Text(
              TextosBici.guiaNoSustituye,
              style: v.lectura(tamano: 13.5, color: v.textoTenue),
            ),
          ],
          if (alListo != null || alEditar != null) ...[
            SizedBox(height: e * 1.5),
            Wrap(
              spacing: e,
              runSpacing: e,
              children: [
                if (alListo != null)
                  FilledButton(
                    key: const ValueKey('preparacion-listo'),
                    onPressed: alListo,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(zonaTactilBici, 56),
                    ),
                    child: const Text(TextosBici.listo),
                  ),
                if (alEditar != null)
                  OutlinedButton.icon(
                    onPressed: alEditar,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Editar mi lista'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FilaPunto extends StatelessWidget {
  const _FilaPunto({required this.punto, required this.alCambiar});

  final PuntoPreparacionVista punto;
  final VoidCallback? alCambiar;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    final marcado = punto.marcado;
    final contenido = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: zonaTactilBici),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: e * 0.5),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Icon(
                punto.estado.icono,
                size: 24,
                color: marcado ? v.exito : v.textoTenue,
              ),
            ),
            SizedBox(width: e * 1.25),
            Expanded(
              child: Wrap(
                spacing: e,
                runSpacing: e * 0.25,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    punto.texto,
                    style: v.lectura(
                      tamano: 15,
                      peso: FontWeight.w600,
                      color: v.textoFuerte,
                    ),
                  ),
                  Text(
                    punto.estado.texto,
                    style: v.lectura(tamano: 13, color: v.textoTenue),
                  ),
                  if (punto.ambito != AmbitoPunto.todas)
                    Text(
                      punto.ambito.texto,
                      style: v.lectura(tamano: 13, color: v.textoTenue),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return Semantics(
      container: true,
      checked: marcado,
      label: punto.anuncio,
      onTap: alCambiar,
      excludeSemantics: true,
      child: alCambiar == null
          ? contenido
          : InkWell(onTap: alCambiar, child: contenido),
    );
  }
}
