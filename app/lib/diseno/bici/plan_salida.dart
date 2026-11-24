/// **Planear la salida** (B2, 6.3): la hora, la duración, el regreso estimado,
/// si cabe antes de la revisión de las 14:30, la ruta y la bicicleta. Los
/// avisos de piernas y de revisión llevan sus opciones y se cierran con
/// «Dejarlo así».
library;

import 'package:flutter/material.dart';

import '../componentes/tarjeta_modulo.dart';
import '../valores_diseno.dart';
import 'piezas_bici.dart';
import 'textos_bici.dart';
import 'tipos_bici.dart';

/// La tarjeta con el resumen de la salida planeada.
class TarjetaPlanSalida extends StatelessWidget {
  const TarjetaPlanSalida({
    super.key,
    required this.diaHoraTexto,
    required this.duracionTexto,
    required this.regresoTexto,
    this.revisionTexto,
    this.encaje,
    this.encajeTexto,
    this.rutaTexto,
    this.bicicletaTexto,
    this.odometroTexto,
    this.alElegirRuta,
    this.alCambiarHora,
    this.alElegirBicicleta,
    this.estado = EstadoVistaBici.listo,
    this.mensajes = const MensajesEstadoBici(
      vacio: 'Todavía no has planeado una salida.',
      vacioDetalle: 'Elige la hora y la duración, y la ponemos en tu agenda.',
      textoAccionVacia: 'Poner en mi agenda',
      cargando: 'Preparando tu salida…',
      sinConexion: 'Sin conexión. Tu plan guardado sigue aquí.',
      error: 'No se pudo cargar tu plan. Puedes intentarlo otra vez.',
    ),
    this.alReintentar,
    this.alAccionVacia,
  });

  /// «Sábado · 8:00».
  final String diaHoraTexto;

  /// «≈ 4 h».
  final String duracionTexto;

  /// «12:00».
  final String regresoTexto;

  /// «14:30».
  final String? revisionTexto;
  final EncajeRevision? encaje;

  /// «Sobran 60 min».
  final String? encajeTexto;

  /// El nombre de la ruta guardada; `null` si no hay (se puede elegir).
  final String? rutaTexto;

  /// «Mi bici».
  final String? bicicletaTexto;

  /// «470 km» (se calcula, no se guarda).
  final String? odometroTexto;
  final VoidCallback? alElegirRuta;
  final VoidCallback? alCambiarHora;
  final VoidCallback? alElegirBicicleta;
  final EstadoVistaBici estado;
  final MensajesEstadoBici mensajes;
  final VoidCallback? alReintentar;
  final VoidCallback? alAccionVacia;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    if (estado != EstadoVistaBici.listo) {
      return TarjetaModulo(
        titulo: 'Salida del sábado',
        icono: Icons.directions_bike,
        child: CuerpoEstadoBici(
          estado: estado,
          mensajes: mensajes,
          alReintentar: alReintentar,
          alAccionVacia: alAccionVacia,
        ),
      );
    }
    final enc = encaje;
    final anuncio = [
      '$diaHoraTexto, $duracionTexto',
      'Regreso estimado $regresoTexto',
      if (revisionTexto != null) 'Revisión semanal $revisionTexto',
      if (enc != null) anuncioEncaje(enc, encajeTexto),
    ].join('. ');
    final colorEncaje = switch (encaje) {
      EncajeRevision.cabe => v.exito,
      EncajeRevision.cabeJusto || EncajeRevision.noCabe => v.alerta,
      null => v.textoTenue,
    };
    return TarjetaModulo(
      titulo: 'Salida del sábado',
      icono: Icons.directions_bike,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            container: true,
            label: anuncio,
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(diaHoraTexto, style: v.titulo(tamano: 26)),
                Text(
                  duracionTexto,
                  style: v.numero(tamano: 15, color: v.textoTenue),
                ),
                SizedBox(height: e * 1.5),
                Wrap(
                  spacing: e * 3,
                  runSpacing: e,
                  children: [
                    _Cifra(etiqueta: 'REGRESO ESTIMADO', valor: regresoTexto),
                    if (revisionTexto != null)
                      _Cifra(
                        etiqueta: 'REVISIÓN SEMANAL',
                        valor: revisionTexto!,
                      ),
                  ],
                ),
                if (encaje != null) ...[
                  SizedBox(height: e * 1.25),
                  MarcaBici(
                    texto: textoEncaje(encaje!, encajeTexto),
                    icono: encaje!.icono,
                    color: colorEncaje,
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: e * 1.5),
          _FilaElegir(
            icono: Icons.route_outlined,
            etiqueta: 'Ruta',
            valor: rutaTexto ?? 'Sin ruta elegida',
            textoBoton: rutaTexto == null ? 'Elegir ruta' : TextosBici.cambiar,
            alTocar: alElegirRuta,
          ),
          _FilaElegir(
            icono: Icons.pedal_bike,
            etiqueta: 'Bici',
            valor: [?bicicletaTexto, ?odometroTexto].join(' · '),
            textoBoton: TextosBici.cambiar,
            alTocar: alElegirBicicleta,
          ),
          if (alCambiarHora != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: alCambiarHora,
                icon: const Icon(Icons.schedule, size: 18),
                label: const Text('Cambiar la hora'),
              ),
            ),
        ],
      ),
    );
  }
}

class _Cifra extends StatelessWidget {
  const _Cifra({required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(etiqueta, style: v.etiquetaPanel()),
        Text(
          valor,
          style: v.numero(
            tamano: 26,
            peso: FontWeight.w700,
            color: v.textoFuerte,
          ),
        ),
      ],
    );
  }
}

class _FilaElegir extends StatelessWidget {
  const _FilaElegir({
    required this.icono,
    required this.etiqueta,
    required this.valor,
    required this.textoBoton,
    required this.alTocar,
  });

  final IconData icono;
  final String etiqueta;
  final String valor;
  final String textoBoton;
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: zonaTactilBici),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: e,
        runSpacing: e * 0.25,
        children: [
          Semantics(
            container: true,
            label: '$etiqueta: $valor',
            excludeSemantics: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icono, size: 18, color: v.textoTenue),
                SizedBox(width: e),
                Flexible(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '$etiqueta  ',
                          style: v.lectura(tamano: 14, color: v.textoTenue),
                        ),
                        TextSpan(
                          text: valor,
                          style: v.lectura(
                            tamano: 15,
                            peso: FontWeight.w600,
                            color: v.textoFuerte,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (alTocar != null)
            TextButton(onPressed: alTocar, child: Text(textoBoton)),
        ],
      ),
    );
  }
}
