/// «Entrenamiento de hoy» (E1) y la vista previa de la sesión (E4): la tarjeta
/// de Hoy con **Empezar** (1 toque) y *Hecho* (1 toque, sin registrar series),
/// y la fila de cada ejercicio con su serie, su carga sugerida y *Cambiar
/// ejercicio*.
library;

import 'package:flutter/material.dart';

import '../componentes/tarjeta_modulo.dart';
import '../valores_diseno.dart';
import 'avisos_gimnasio.dart';
import 'piezas_gimnasio.dart';
import 'textos_gimnasio.dart';
import 'tipos_gimnasio.dart';

/// La tarjeta **«Entrenamiento de hoy»** de la pantalla Hoy (E1).
class TarjetaEntrenamientoHoy extends StatelessWidget {
  const TarjetaEntrenamientoHoy({
    super.key,
    required this.plantillaTexto,
    this.versionTexto,
    this.horaTexto,
    this.duracionTexto,
    this.estadoDia = EstadoDiaPlan.pendiente,
    this.tipoSemana = TipoSemanaVista.carga,
    this.avisoTexto,
    this.contenidoEnRevision = false,
    this.alEmpezar,
    this.alHecho,
    this.alDeshacer,
    this.alAbrir,
    this.estado = EstadoVistaGimnasio.listo,
    this.mensajes = const MensajesEstadoGimnasio(
      vacio: 'Hoy no toca entrenar.',
      vacioDetalle: 'Descansar también es parte del plan.',
      cargando: 'Buscando tu entrenamiento de hoy…',
      sinConexion: 'Sin conexión. Tu entrenamiento sigue disponible aquí.',
      error: 'No se pudo cargar el entrenamiento de hoy.',
    ),
    this.alReintentar,
  });

  /// «Fuerza A · Empuje».
  final String plantillaTexto;

  /// «estándar».
  final String? versionTexto;

  /// «19:15».
  final String? horaTexto;

  /// «≈ 36 min» (la duración estimada real, 5.5).
  final String? duracionTexto;
  final EstadoDiaPlan estadoDia;

  /// Con descarga, reentrada o foco se muestra la nota para que no parezca un
  /// retroceso («Esta semana es de descarga. Es parte del plan.»).
  final TipoSemanaVista tipoSemana;

  /// Un aviso ya redactado (cerca de la hora de dormir, carga alta del día…).
  final String? avisoTexto;
  final bool contenidoEnRevision;

  /// *Empezar*: 1 toque.
  final VoidCallback? alEmpezar;

  /// *Hecho*: 1 toque, sin registrar series.
  final VoidCallback? alHecho;

  /// *Deshacer* tras marcar el día.
  final VoidCallback? alDeshacer;

  /// Abre la vista previa de la sesión.
  final VoidCallback? alAbrir;
  final EstadoVistaGimnasio estado;
  final MensajesEstadoGimnasio mensajes;
  final VoidCallback? alReintentar;

  static String _notaSemana(TipoSemanaVista t) => switch (t) {
    TipoSemanaVista.descarga =>
      'Esta semana es de descarga: menos series para recuperar. Es parte '
          'del plan.',
    TipoSemanaVista.reentrada => 'Retomemos con calma. Hoy cuenta empezar.',
    TipoSemanaVista.foco =>
      'Estás en modo foco: hoy no subimos carga. La sesión sigue disponible.',
    TipoSemanaVista.carga => '',
  };

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    if (estado != EstadoVistaGimnasio.listo) {
      return TarjetaModulo(
        titulo: 'Entrenamiento de hoy',
        icono: Icons.fitness_center,
        child: CuerpoEstadoGimnasio(
          estado: estado,
          mensajes: mensajes,
          alReintentar: alReintentar,
        ),
      );
    }
    final hecho =
        estadoDia == EstadoDiaPlan.hecho || estadoDia == EstadoDiaPlan.parcial;
    final datos = [?versionTexto, ?horaTexto, ?duracionTexto].join(' · ');
    return TarjetaModulo(
      titulo: 'Entrenamiento de hoy',
      icono: Icons.fitness_center,
      alTocar: alAbrir,
      accion: estadoDia == EstadoDiaPlan.pendiente
          ? null
          : MarcaGimnasio(
              texto: estadoDia.texto,
              icono: estadoDia.icono,
              color: estadoDia == EstadoDiaPlan.hecho ? v.exito : v.textoTenue,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            header: true,
            child: Text(plantillaTexto, style: v.titulo(tamano: 26)),
          ),
          if (datos.isNotEmpty)
            Text(
              datos,
              style: v.numero(tamano: 15, color: v.textoTenue),
            ),
          if (tipoSemana != TipoSemanaVista.carga) ...[
            SizedBox(height: e * 1.5),
            MarcaGimnasio(texto: tipoSemana.texto, icono: tipoSemana.icono),
            SizedBox(height: e * 0.75),
            Text(
              _notaSemana(tipoSemana),
              style: v.lectura(tamano: 14, color: v.texto),
            ),
          ],
          if (avisoTexto != null) ...[
            SizedBox(height: e * 1.5),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 20, color: v.alerta),
                SizedBox(width: e),
                Expanded(
                  child: Text(
                    'Aviso: $avisoTexto',
                    style: v.lectura(tamano: 14, color: v.texto),
                  ),
                ),
              ],
            ),
          ],
          if (contenidoEnRevision) ...[
            SizedBox(height: e * 1.5),
            const TarjetaContenidoEnRevision(compacta: true),
          ],
          SizedBox(height: e * 2),
          if (hecho)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: alDeshacer == null
                  ? null
                  : TextButton.icon(
                      onPressed: alDeshacer,
                      icon: const Icon(Icons.undo, size: 18),
                      label: const Text(TextosGimnasio.deshacer),
                    ),
            )
          else
            Wrap(
              spacing: e,
              runSpacing: e,
              children: [
                FilledButton.icon(
                  key: const ValueKey('entrenamiento-empezar'),
                  onPressed: alEmpezar,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(zonaTactilGimnasio, 56),
                  ),
                  icon: const Icon(Icons.play_arrow, size: 22),
                  label: const Text('Empezar'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('entrenamiento-hecho'),
                  onPressed: alHecho,
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Hecho'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Un ejercicio de la vista previa de la sesión (E4) con datos ya calculados.
@immutable
class EjercicioPlanVista {
  const EjercicioPlanVista({
    required this.ejercicio,
    required this.seriesTexto,
    this.varianteTexto,
    this.cargaTexto,
    this.conPrecaucion = false,
    this.cambioTexto,
  });

  /// «Elevaciones laterales».
  final String ejercicio;

  /// «3 × 12–15» o «3 × 30 s».
  final String seriesTexto;

  /// «Polea baja», «Con banda pisada».
  final String? varianteTexto;

  /// «Placa 3», «Banda verde», «Peso corporal»; `null` sin sugerencia
  /// (primer arranque, 5.12).
  final String? cargaTexto;

  /// Carga una zona con molestia: va con la palabra «Con precaución».
  final bool conPrecaucion;

  /// Por qué cambió respecto al plan («Sin aparato», «Más fácil»).
  final String? cambioTexto;
}

/// La fila de un ejercicio con *Cambiar ejercicio* de 48 dp.
class FilaEjercicioPlan extends StatelessWidget {
  const FilaEjercicioPlan({
    super.key,
    required this.numero,
    required this.total,
    required this.datos,
    this.alCambiar,
  });

  final int numero;
  final int total;
  final EjercicioPlanVista datos;
  final VoidCallback? alCambiar;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    final anuncio = [
      'Ejercicio $numero de $total',
      datos.ejercicio,
      ?datos.varianteTexto,
      datos.seriesTexto,
      datos.cargaTexto ?? 'sin carga sugerida',
      if (datos.conPrecaucion) 'con precaución',
      ?datos.cambioTexto,
    ].join(', ');
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: anuncio,
      child: DecoratedBox(
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
              ExcludeSemantics(
                child: Text(
                  '$numero / $total',
                  style: v.etiquetaPanel(),
                ),
              ),
              ExcludeSemantics(
                child: Text(
                  datos.ejercicio,
                  style: v.lectura(
                    tamano: 17,
                    peso: FontWeight.w700,
                    color: v.textoFuerte,
                  ),
                ),
              ),
              if (datos.varianteTexto != null)
                ExcludeSemantics(
                  child: Text(
                    datos.varianteTexto!,
                    style: v.lectura(tamano: 14, color: v.textoTenue),
                  ),
                ),
              SizedBox(height: e),
              ExcludeSemantics(
                child: Wrap(
                  spacing: e * 2,
                  runSpacing: e * 0.5,
                  children: [
                    Text(
                      datos.seriesTexto,
                      style: v.numero(
                        tamano: 16,
                        peso: FontWeight.w600,
                        color: v.textoFuerte,
                      ),
                    ),
                    Text(
                      datos.cargaTexto ?? 'Sin carga sugerida',
                      style: v.numero(tamano: 16, color: v.texto),
                    ),
                  ],
                ),
              ),
              if (datos.conPrecaucion || datos.cambioTexto != null) ...[
                SizedBox(height: e),
                Wrap(
                  spacing: e,
                  runSpacing: e,
                  children: [
                    if (datos.conPrecaucion)
                      MarcaGimnasio(
                        texto: EstadoSerie.conPrecaucion.texto,
                        icono: EstadoSerie.conPrecaucion.icono,
                        color: v.alerta,
                        enfasis: true,
                      ),
                    if (datos.cambioTexto != null)
                      MarcaGimnasio(
                        texto: datos.cambioTexto!,
                        icono: Icons.swap_horiz,
                      ),
                  ],
                ),
              ],
              if (alCambiar != null) ...[
                SizedBox(height: e),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: alCambiar,
                    icon: const Icon(Icons.swap_horiz, size: 18),
                    label: const Text('Cambiar ejercicio'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
