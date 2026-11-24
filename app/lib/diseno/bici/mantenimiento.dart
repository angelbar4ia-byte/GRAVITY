/// **Mi bici y mantenimiento** (B7, 4.8): el odómetro (que **se calcula** con
/// las salidas, no se guarda como contador) y las tareas de cuidado de la
/// bici con su estado.
///
/// Una tarea sin ningún registro dice **«Sin registro»**, nunca «vencida»; una
/// que toca dice «Toca» y no bloquea nada. Los intervalos son un punto de
/// partida marcado «Borrador» y la tarjeta pide confirmarlos con el manual o
/// el taller. Cada estado lleva icono y palabra.
library;

import 'package:flutter/material.dart';

import '../componentes/tarjeta_modulo.dart';
import '../valores_diseno.dart';
import 'piezas_bici.dart';
import 'textos_bici.dart';
import 'tipos_bici.dart';

/// Una tarea de mantenimiento con datos ya calculados.
@immutable
class TareaMantenimientoVista {
  const TareaMantenimientoVista({
    required this.id,
    required this.nombre,
    required this.estado,
    this.intervaloTexto,
    this.ultimaVezTexto,
    this.faltaTexto,
  });

  final String id;

  /// «Lubricar la cadena».
  final String nombre;
  final EstadoTarea estado;

  /// «Cada 150 km o 4 semanas».
  final String? intervaloTexto;

  /// «Hecha el 2 nov, a los 350 km»; `null` sin registro.
  final String? ultimaVezTexto;

  /// «Faltan 30 km» o «Ya pasaron 4 semanas»; `null` sin registro.
  final String? faltaTexto;

  /// Lo que lee el lector de pantalla.
  String get anuncio => [
    nombre,
    estado.texto.toLowerCase(),
    ?intervaloTexto,
    ?ultimaVezTexto,
    ?faltaTexto,
  ].join(', ');
}

/// La tarjeta de la bici: odómetro y tareas.
class TarjetaMantenimiento extends StatelessWidget {
  const TarjetaMantenimiento({
    super.key,
    required this.bicicletaTexto,
    required this.odometroTexto,
    required this.tareas,
    this.alHecho,
    this.alAnotarLectura,
    this.alCambiarIntervalos,
    this.estado = EstadoVistaBici.listo,
    this.mensajes = const MensajesEstadoBici(
      vacio: 'Todavía no hay tareas de mantenimiento.',
      vacioDetalle: 'Puedes activar las que usas.',
      cargando: 'Cargando tu mantenimiento…',
      sinConexion: 'Sin conexión. Se muestra lo guardado en este equipo.',
      error: 'No se pudo cargar tu mantenimiento.',
    ),
    this.alReintentar,
  });

  /// «Mi bici».
  final String bicicletaTexto;

  /// «470 km»; se calcula con la última lectura más las salidas posteriores.
  final String odometroTexto;
  final List<TareaMantenimientoVista> tareas;

  /// *Hecho* de una tarea (2 toques en total, F-B7): recibe su id.
  final ValueChanged<String>? alHecho;

  /// Anotar lo que marca el ciclocomputador (una lectura).
  final VoidCallback? alAnotarLectura;

  /// Cambiar los intervalos.
  final VoidCallback? alCambiarIntervalos;
  final EstadoVistaBici estado;
  final MensajesEstadoBici mensajes;
  final VoidCallback? alReintentar;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    if (estado != EstadoVistaBici.listo) {
      return TarjetaModulo(
        titulo: 'Mantenimiento',
        icono: Icons.build_outlined,
        child: CuerpoEstadoBici(
          estado: estado,
          mensajes: mensajes,
          alReintentar: alReintentar,
        ),
      );
    }
    return TarjetaModulo(
      titulo: 'Mantenimiento',
      icono: Icons.build_outlined,
      accion: const MarcaBici(
        texto: TextosBici.borrador,
        icono: Icons.rule_folder_outlined,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            container: true,
            label:
                '$bicicletaTexto, $odometroTexto. '
                '${TextosBici.odometroCalculado}.',
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bicicletaTexto, style: v.etiquetaPanel()),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    odometroTexto,
                    key: const ValueKey('mantenimiento-odometro'),
                    maxLines: 1,
                    style: v.numero(
                      tamano: 36,
                      peso: FontWeight.w700,
                      color: v.textoFuerte,
                    ),
                  ),
                ),
                Text(
                  TextosBici.odometroCalculado,
                  style: v.lectura(tamano: 13.5, color: v.textoTenue),
                ),
              ],
            ),
          ),
          if (alAnotarLectura != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: alAnotarLectura,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text(TextosBici.registrarLectura),
              ),
            ),
          SizedBox(height: e),
          if (tareas.isEmpty)
            CuerpoEstadoBici(estado: EstadoVistaBici.vacio, mensajes: mensajes)
          else
            for (final t in tareas) ...[
              _FilaTarea(
                tarea: t,
                alHecho: alHecho == null ? null : () => alHecho!(t.id),
              ),
              SizedBox(height: e),
            ],
          Text(
            TextosBici.confirmaIntervalos,
            style: v.lectura(tamano: 13.5, color: v.textoTenue),
          ),
          if (alCambiarIntervalos != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: alCambiarIntervalos,
                child: const Text('Cambiar intervalos'),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilaTarea extends StatelessWidget {
  const _FilaTarea({required this.tarea, required this.alHecho});

  final TareaMantenimientoVista tarea;
  final VoidCallback? alHecho;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    final color = switch (tarea.estado) {
      EstadoTarea.alDia => v.exito,
      EstadoTarea.toca => v.alerta,
      EstadoTarea.sinRegistro => v.textoTenue,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: v.panel,
        border: Border.all(color: v.borde, width: v.grosorBorde),
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
              label: tarea.anuncio,
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tarea.nombre,
                    style: v.lectura(
                      tamano: 16,
                      peso: FontWeight.w700,
                      color: v.textoFuerte,
                    ),
                  ),
                  if (tarea.intervaloTexto != null)
                    Text(
                      tarea.intervaloTexto!,
                      style: v.lectura(tamano: 14, color: v.textoTenue),
                    ),
                  SizedBox(height: e),
                  MarcaBici(
                    texto: tarea.estado.texto,
                    icono: tarea.estado.icono,
                    color: color,
                    enfasis: tarea.estado == EstadoTarea.toca,
                  ),
                  if (tarea.ultimaVezTexto != null || tarea.faltaTexto != null)
                    Padding(
                      padding: EdgeInsets.only(top: e),
                      child: Text(
                        [?tarea.ultimaVezTexto, ?tarea.faltaTexto].join(' · '),
                        style: v.numero(tamano: 14, color: v.texto),
                      ),
                    )
                  else if (tarea.estado == EstadoTarea.sinRegistro)
                    Padding(
                      padding: EdgeInsets.only(top: e),
                      child: Text(
                        TextosBici.sinRegistroNota,
                        style: v.lectura(tamano: 14, color: v.texto),
                      ),
                    ),
                ],
              ),
            ),
            if (alHecho != null) ...[
              SizedBox(height: e),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton.icon(
                  onPressed: alHecho,
                  icon: const Icon(Icons.check, size: 18),
                  label: Text('${TextosBici.hecho}: ${tarea.nombre}'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
