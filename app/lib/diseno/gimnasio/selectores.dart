/// Selectores de la sesión: repeticiones y carga en **pasos** (− y +), sin
/// teclado (6.1), y el botón ✓ «Hecha» de 64 dp (7.2).
library;

import 'package:flutter/material.dart';

import '../valores_diseno.dart';
import 'piezas_gimnasio.dart';
import 'textos_gimnasio.dart';
import 'tipos_gimnasio.dart';

/// Un valor con su − y su +: repeticiones, carga o series. Los botones miden
/// 56 dp. Un botón sin acción (tope o mínimo) se ve tenue y lo dice el lector
/// de pantalla.
class SelectorPasos extends StatelessWidget {
  const SelectorPasos({
    super.key,
    required this.etiqueta,
    required this.valorTexto,
    required this.etiquetaMenos,
    required this.etiquetaMas,
    this.descripcionAccesible,
    this.alMenos,
    this.alMas,
  });

  /// «REPS», «CARGA».
  final String etiqueta;

  /// El valor grande: «12», «Placa 3».
  final String valorTexto;

  /// Lo que lee el lector en el botón −.
  final String etiquetaMenos;

  /// Lo que lee el lector en el botón +.
  final String etiquetaMas;

  /// Frase completa para el lector («12 repeticiones»); por omisión, la
  /// etiqueta y el valor.
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
                        tamano: 32,
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
          BotonPasoGimnasio(
            icono: Icons.remove,
            etiqueta: etiquetaMenos,
            alTocar: alMenos,
          ),
          SizedBox(width: e),
          BotonPasoGimnasio(
            icono: Icons.add,
            etiqueta: etiquetaMas,
            alTocar: alMas,
          ),
        ],
      ),
    );
  }
}

/// Selector de carga en **pasos de la pila** (placas) o en **bandas** (3.2,
/// 5.4 y 5.8).
///
/// Mientras un dato del aparato esté «confirmar en el aparato», la carga se ve
/// en placas, **sin kilos** y sin detectar el tope (CA-G-04): [equivalenciaTexto]
/// solo se pasa cuando la persona ya confirmó cuánto vale una placa. Sin punto
/// de partida ([valorTexto] nulo, 5.12) pide elegir una carga con esfuerzo 3.
class SelectorCarga extends StatelessWidget {
  const SelectorCarga({
    super.key,
    this.unidad = UnidadCarga.placa,
    this.valorTexto,
    this.equivalenciaTexto,
    this.confirmacion = EstadoConfirmacionDato.confirmar,
    this.alMenos,
    this.alMas,
    this.enTope = false,
    this.alConfirmar,
    this.estado = EstadoVistaGimnasio.listo,
    this.mensajes = const MensajesEstadoGimnasio(
      vacio: 'Este ejercicio no lleva carga.',
      vacioDetalle: 'Se hace con el peso del cuerpo.',
      cargando: 'Buscando tu última carga…',
      sinConexion: 'Sin conexión. Se usa la última carga guardada aquí.',
      error: 'No se pudo leer la carga. Puedes elegirla a mano.',
    ),
    this.alReintentar,
  });

  final UnidadCarga unidad;

  /// «Placa 3», «Banda verde»; `null` si todavía no hay punto de partida.
  final String? valorTexto;

  /// «≈ 20 kg». Solo con la equivalencia **confirmada**; si no, nulo.
  final String? equivalenciaTexto;

  /// Estado de confirmación del dato del aparato del que depende la carga.
  final EstadoConfirmacionDato confirmacion;
  final VoidCallback? alMenos;
  final VoidCallback? alMas;

  /// Está en la última placa (con el tope confirmado) o en la banda más fuerte.
  final bool enTope;

  /// Abre «Confirmar en el aparato» (F-E5).
  final VoidCallback? alConfirmar;
  final EstadoVistaGimnasio estado;
  final MensajesEstadoGimnasio mensajes;
  final VoidCallback? alReintentar;

  @override
  Widget build(BuildContext context) {
    if (estado != EstadoVistaGimnasio.listo) {
      return CuerpoEstadoGimnasio(
        estado: estado,
        mensajes: mensajes,
        alReintentar: alReintentar,
      );
    }
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    final sinPunto = valorTexto == null;
    final etiquetaCarga = unidad == UnidadCarga.placa ? 'CARGA' : 'BANDA';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SelectorPasos(
          etiqueta: etiquetaCarga,
          valorTexto: valorTexto ?? 'Elige tu ${unidad.palabra}',
          descripcionAccesible: sinPunto
              ? 'Carga sin elegir. ${TextosGimnasio.eligeTuCarga}'
              : '$etiquetaCarga: $valorTexto'
                    '${equivalenciaTexto == null ? '' : ', $equivalenciaTexto'}'
                    '${enTope ? '. Tope' : ''}',
          etiquetaMenos: unidad.textoMenos,
          etiquetaMas: enTope
              ? '${unidad.textoMas}, no disponible: tope'
              : unidad.textoMas,
          alMenos: alMenos,
          alMas: enTope ? null : alMas,
        ),
        if (sinPunto) ...[
          SizedBox(height: e),
          Text(
            TextosGimnasio.eligeTuCarga,
            style: v.lectura(tamano: 14, color: v.textoTenue),
          ),
        ],
        if (equivalenciaTexto != null &&
            confirmacion == EstadoConfirmacionDato.confirmado) ...[
          SizedBox(height: e * 0.5),
          Text(
            equivalenciaTexto!,
            style: v.numero(tamano: 14, color: v.textoTenue),
          ),
        ],
        SizedBox(height: e),
        _FilaConfirmacion(
          confirmacion: confirmacion,
          alConfirmar: alConfirmar,
          sinKilos: unidad == UnidadCarga.placa,
        ),
        if (enTope) ...[
          SizedBox(height: e),
          MarcaGimnasio(
            texto: unidad == UnidadCarga.placa
                ? 'Última placa'
                : 'Banda más fuerte',
            icono: Icons.vertical_align_top,
            color: v.acento,
          ),
          SizedBox(height: e * 0.5),
          Text(
            TextosGimnasio.topeDePila,
            style: v.lectura(tamano: 14, color: v.textoTenue),
          ),
        ],
      ],
    );
  }
}

/// La marca de confirmación del dato del aparato y, si falta, el botón de 48 dp
/// *Confirmar en el aparato*.
class _FilaConfirmacion extends StatelessWidget {
  const _FilaConfirmacion({
    required this.confirmacion,
    required this.alConfirmar,
    required this.sinKilos,
  });

  final EstadoConfirmacionDato confirmacion;
  final VoidCallback? alConfirmar;
  final bool sinKilos;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    final falta = confirmacion == EstadoConfirmacionDato.confirmar;
    return Wrap(
      spacing: e,
      runSpacing: e,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        MarcaGimnasio(
          texto: confirmacion.texto,
          icono: confirmacion.icono,
          color: switch (confirmacion) {
            EstadoConfirmacionDato.confirmado => v.exito,
            EstadoConfirmacionDato.confirmar => v.alerta,
            EstadoConfirmacionDato.delDiseno => v.textoTenue,
          },
          enfasis: falta,
        ),
        if (falta && sinKilos)
          Text(
            TextosGimnasio.sinKgHastaConfirmar,
            style: v.lectura(tamano: 13, color: v.textoTenue),
          ),
        if (falta && alConfirmar != null)
          OutlinedButton.icon(
            onPressed: alConfirmar,
            icon: const Icon(Icons.fact_check_outlined, size: 18),
            label: const Text(TextosGimnasio.confirmarEnElAparato),
          ),
      ],
    );
  }
}

/// El botón ✓ **Hecha** de la sesión: 64 dp de alto, ancho completo. Guardar
/// una serie cuesta **un toque** con lo sugerido (6.1). Después muestra
/// «Serie guardada» y *Deshacer* a la vista (7.2: 5 s, lo cuenta la pantalla).
class BotonSerieHecha extends StatelessWidget {
  const BotonSerieHecha({
    super.key,
    required this.alHecha,
    this.guardada = false,
    this.alDeshacer,
    this.etiquetaAccesible,
  });

  /// ✓: guarda la serie con las repeticiones y la carga que se ven.
  final VoidCallback? alHecha;

  /// La última serie ya se guardó: se muestra el aviso y *Deshacer*.
  final bool guardada;

  /// Quita la última serie; solo se muestra mientras [guardada].
  final VoidCallback? alDeshacer;

  /// «Marcar la serie 2 de 3 como hecha».
  final String? etiquetaAccesible;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          enabled: alHecha != null,
          onTap: alHecha,
          label: etiquetaAccesible ?? 'Marcar la serie como hecha',
          excludeSemantics: true,
          child: FilledButton.icon(
            key: const ValueKey('boton-serie-hecha'),
            onPressed: alHecha,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(altoAccionSesion),
            ),
            icon: const Icon(Icons.check, size: 30),
            label: Text(
              TextosGimnasio.hecha.toUpperCase(),
              style: v.titulo(
                tamano: 22,
                peso: FontWeight.w700,
                color: v.sobreAcento,
                espaciadoLetras: 1,
              ),
            ),
          ),
        ),
        if (guardada) ...[
          SizedBox(height: e),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: e,
            children: [
              MarcaGimnasio(
                texto: TextosGimnasio.serieGuardada,
                icono: Icons.check_circle_outline,
                color: v.exito,
              ),
              if (alDeshacer != null)
                TextButton.icon(
                  onPressed: alDeshacer,
                  icon: const Icon(Icons.undo, size: 18),
                  label: const Text(TextosGimnasio.deshacer),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// El panel de **registro rápido de una serie** (E5 y E6): serie actual,
/// repeticiones con − y +, carga con − y +, y ✓ **Hecha**. Se arma con los
/// componentes de arriba; el temporizador y el «Siguiente» van aparte.
class PanelRegistroSerie extends StatelessWidget {
  const PanelRegistroSerie({
    super.key,
    required this.serieActual,
    required this.seriesTotales,
    required this.repeticionesTexto,
    this.alMenosReps,
    this.alMasReps,
    this.porTiempo = false,
    this.carga,
    required this.alHecha,
    this.guardada = false,
    this.alDeshacer,
  });

  final int serieActual;
  final int seriesTotales;

  /// «12» o, si es por tiempo, «30 s».
  final String repeticionesTexto;
  final VoidCallback? alMenosReps;
  final VoidCallback? alMasReps;

  /// Plancha: el valor son segundos, no repeticiones.
  final bool porTiempo;

  /// El [SelectorCarga] (o `null` si el ejercicio no lleva carga).
  final Widget? carga;
  final VoidCallback? alHecha;
  final bool guardada;
  final VoidCallback? alDeshacer;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    final palabra = porTiempo ? 'segundos' : 'repeticiones';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: 'Serie $serieActual de $seriesTotales',
          excludeSemantics: true,
          child: Text(
            'SERIE  $serieActual / $seriesTotales',
            style: v.titulo(tamano: 26, peso: FontWeight.w700),
          ),
        ),
        SizedBox(height: e * 1.5),
        SelectorPasos(
          etiqueta: porTiempo ? 'SEGUNDOS' : 'REPS',
          valorTexto: repeticionesTexto,
          descripcionAccesible: '$repeticionesTexto $palabra',
          etiquetaMenos: porTiempo
              ? 'Quitar segundos'
              : 'Quitar una repetición',
          etiquetaMas: porTiempo
              ? 'Agregar segundos'
              : 'Agregar una repetición',
          alMenos: alMenosReps,
          alMas: alMasReps,
        ),
        if (carga != null) ...[SizedBox(height: e * 1.5), carga!],
        SizedBox(height: e * 2),
        BotonSerieHecha(
          alHecha: alHecha,
          guardada: guardada,
          alDeshacer: alDeshacer,
          etiquetaAccesible:
              'Marcar la serie $serieActual de $seriesTotales como hecha',
        ),
      ],
    );
  }
}
