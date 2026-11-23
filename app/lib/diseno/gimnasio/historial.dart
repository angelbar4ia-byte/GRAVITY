/// Historial y récords (E7 y E8, 6.2 y 6.3): barras sencillas **con texto
/// alternativo**, la lista de sesiones y la lista de récords.
///
/// Una semana de **descarga**, de **reentrada** o de **foco** se marca con
/// icono y palabra y con otro relleno, para que una caída de carga no se lea
/// como retroceso (6.3). Nada compara con otras personas.
library;

import 'package:flutter/material.dart';

import '../componentes/tarjeta_modulo.dart';
import '../superficies.dart';
import '../valores_diseno.dart';
import 'piezas_gimnasio.dart';
import 'textos_gimnasio.dart';
import 'tipos_gimnasio.dart';

/// Una barra del historial de un ejercicio: una semana o una sesión.
@immutable
class BarraHistorialVista {
  const BarraHistorialVista({
    required this.etiqueta,
    required this.valor,
    required this.valorTexto,
    this.tipoSemana = TipoSemanaVista.carga,
    this.esRecord = false,
  });

  /// «Semana del 2 nov».
  final String etiqueta;

  /// Alto relativo de la barra (cualquier escala; se normaliza con el máximo).
  final double valor;

  /// El valor en palabras: «placa 5», «36 repeticiones», «45 s».
  final String valorTexto;
  final TipoSemanaVista tipoSemana;

  /// Marca la barra del récord (con icono y palabra).
  final bool esRecord;

  String get anuncio => [
    etiqueta,
    valorTexto,
    if (tipoSemana != TipoSemanaVista.carga)
      'semana de ${tipoSemana.texto.toLowerCase()}',
    if (esRecord) 'récord',
  ].join(', ');
}

/// **Barras de historial** de un ejercicio: una fila por semana, con la
/// etiqueta y el valor arriba y la barra debajo (así aguanta la letra grande
/// sin recortar nada).
class BarrasHistorial extends StatelessWidget {
  const BarrasHistorial({
    super.key,
    required this.titulo,
    required this.barras,
    this.subtitulo,
    this.resumenAccesible,
    this.estado = EstadoVistaGimnasio.listo,
    this.mensajes = const MensajesEstadoGimnasio(
      vacio: 'Todavía no hay sesiones de este ejercicio.',
      vacioDetalle: 'Cuando termines una, aparece aquí.',
      cargando: 'Cargando tu historial…',
      sinConexion: 'Sin conexión. Se muestra el historial guardado aquí.',
      error: 'No se pudo cargar el historial. Puedes intentarlo otra vez.',
    ),
    this.alReintentar,
  });

  final String titulo;

  /// «Carga por semana».
  final String? subtitulo;
  final List<BarraHistorialVista> barras;

  /// Texto alternativo de toda la gráfica; por omisión se arma con los datos.
  final String? resumenAccesible;
  final EstadoVistaGimnasio estado;
  final MensajesEstadoGimnasio mensajes;
  final VoidCallback? alReintentar;

  /// El texto alternativo armado con las barras.
  String get textoAlternativo =>
      resumenAccesible ??
      '$titulo. ${barras.length} '
          '${barras.length == 1 ? 'registro' : 'registros'}. '
          '${barras.map((b) => b.anuncio).join('. ')}.';

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    if (estado != EstadoVistaGimnasio.listo || barras.isEmpty) {
      return TarjetaModulo(
        titulo: titulo,
        icono: Icons.bar_chart,
        child: CuerpoEstadoGimnasio(
          estado: estado == EstadoVistaGimnasio.listo
              ? EstadoVistaGimnasio.vacio
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
    return TarjetaModulo(
      titulo: titulo,
      icono: Icons.bar_chart,
      child: Semantics(
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
    );
  }
}

class _FilaBarra extends StatelessWidget {
  const _FilaBarra({required this.barra, required this.maximo});

  final BarraHistorialVista barra;
  final double maximo;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    final fraccion = maximo <= 0 ? 0.0 : (barra.valor / maximo).clamp(0.0, 1.0);
    final rayada = barra.tipoSemana != TipoSemanaVista.carga;
    final etiquetas = <Widget>[
      if (rayada)
        MarcaGimnasio(
          texto: barra.tipoSemana.texto,
          icono: barra.tipoSemana.icono,
          color: v.textoTenue,
        ),
      if (barra.esRecord)
        MarcaGimnasio(
          texto: 'Récord',
          icono: Icons.emoji_events_outlined,
          color: v.acento,
          enfasis: true,
        ),
    ];
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
            child: CustomPaint(
              painter: _PintorBarra(
                fraccion: fraccion,
                color: v.acento,
                pista: v.pista,
                rayada: rayada,
              ),
            ),
          ),
        ),
        if (etiquetas.isNotEmpty) ...[
          SizedBox(height: e * 0.75),
          Wrap(spacing: e, runSpacing: e * 0.5, children: etiquetas),
        ],
      ],
    );
  }
}

/// Barra con relleno liso (carga) o rayado (descarga, reentrada y foco).
class _PintorBarra extends CustomPainter {
  const _PintorBarra({
    required this.fraccion,
    required this.color,
    required this.pista,
    required this.rayada,
  });

  final double fraccion;
  final Color color;
  final Color pista;
  final bool rayada;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = pista);
    final ancho = size.width * fraccion;
    if (ancho <= 0) return;
    final relleno = Rect.fromLTWH(0, 0, ancho, size.height);
    canvas.drawRect(relleno, Paint()..color = color);
    if (rayada) {
      canvas.save();
      canvas.clipRect(relleno);
      final raya = Paint()
        ..color = pista
        ..strokeWidth = 3;
      for (var x = -size.height; x < ancho; x += 8) {
        canvas.drawLine(
          Offset(x, size.height),
          Offset(x + size.height, 0),
          raya,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_PintorBarra old) =>
      old.fraccion != fraccion ||
      old.color != color ||
      old.pista != pista ||
      old.rayada != rayada;
}

/// Una sesión del historial (6.3): fecha, plantilla, series hechas de las
/// planeadas, duración y el tipo de semana.
@immutable
class SesionHistorialVista {
  const SesionHistorialVista({
    required this.fechaTexto,
    required this.plantillaTexto,
    required this.resumenTexto,
    this.tipoSemana = TipoSemanaVista.carga,
    this.esfuerzoTexto,
  });

  /// «lun 2 nov».
  final String fechaTexto;

  /// «Fuerza A · estándar».
  final String plantillaTexto;

  /// «9 de 12 series · 38 min».
  final String resumenTexto;
  final TipoSemanaVista tipoSemana;

  /// «Esfuerzo 3 de 5».
  final String? esfuerzoTexto;
}

/// Lista de sesiones del historial: filas de 56 dp o más.
class ListaSesionesHistorial extends StatelessWidget {
  const ListaSesionesHistorial({
    super.key,
    required this.sesiones,
    this.alTocarSesion,
    this.estado = EstadoVistaGimnasio.listo,
    this.mensajes = const MensajesEstadoGimnasio(
      vacio: 'Todavía no hay sesiones guardadas.',
      vacioDetalle: 'Cuando termines una, aparece aquí.',
      cargando: 'Cargando tus sesiones…',
      sinConexion: 'Sin conexión. Se muestran las sesiones guardadas aquí.',
      error: 'No se pudieron cargar las sesiones. Puedes intentarlo otra vez.',
    ),
    this.alReintentar,
  });

  final List<SesionHistorialVista> sesiones;
  final ValueChanged<int>? alTocarSesion;
  final EstadoVistaGimnasio estado;
  final MensajesEstadoGimnasio mensajes;
  final VoidCallback? alReintentar;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    if (estado != EstadoVistaGimnasio.listo || sesiones.isEmpty) {
      return TarjetaModulo(
        titulo: 'Sesiones',
        icono: Icons.history,
        child: CuerpoEstadoGimnasio(
          estado: estado == EstadoVistaGimnasio.listo
              ? EstadoVistaGimnasio.vacio
              : estado,
          mensajes: mensajes,
          alReintentar: alReintentar,
        ),
      );
    }
    return TarjetaModulo(
      titulo: 'Sesiones',
      icono: Icons.history,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < sesiones.length; i++)
            Builder(
              builder: (context) {
                final s = sesiones[i];
                final alTocar = alTocarSesion == null
                    ? null
                    : () => alTocarSesion!(i);
                final fila = ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: e),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: e,
                          runSpacing: e * 0.5,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              s.fechaTexto,
                              style: v.lectura(
                                tamano: 15,
                                peso: FontWeight.w700,
                                color: v.textoFuerte,
                              ),
                            ),
                            Text(
                              s.plantillaTexto,
                              style: v.lectura(tamano: 14, color: v.texto),
                            ),
                            if (s.tipoSemana != TipoSemanaVista.carga)
                              MarcaGimnasio(
                                texto: s.tipoSemana.texto,
                                icono: s.tipoSemana.icono,
                              ),
                          ],
                        ),
                        Text(
                          [s.resumenTexto, ?s.esfuerzoTexto].join(' · '),
                          style: v.lectura(tamano: 14, color: v.textoTenue),
                        ),
                      ],
                    ),
                  ),
                );
                final etiqueta = [
                  s.fechaTexto,
                  s.plantillaTexto,
                  if (s.tipoSemana != TipoSemanaVista.carga)
                    'semana de ${s.tipoSemana.texto.toLowerCase()}',
                  s.resumenTexto,
                  ?s.esfuerzoTexto,
                ].join(', ');
                return Semantics(
                  container: true,
                  button: alTocar != null,
                  onTap: alTocar,
                  label: etiqueta,
                  excludeSemantics: true,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: i == sesiones.length - 1
                            ? BorderSide.none
                            : BorderSide(color: v.borde, width: 0.5),
                      ),
                    ),
                    child: alTocar == null
                        ? fila
                        : InkWell(onTap: alTocar, child: fila),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// Un récord personal de una variante (6.2): se calcula, no se guarda.
@immutable
class RecordVista {
  const RecordVista({
    required this.ejercicio,
    required this.tipo,
    required this.valorTexto,
    this.varianteTexto,
    this.fechaTexto,
    this.reciente = false,
  });

  /// «Press de pecho».
  final String ejercicio;
  final TipoRecordVista tipo;

  /// «Placa 6», «14 repeticiones», «45 s».
  final String valorTexto;

  /// «En la estación», «Polea baja»: los récords no mezclan puestos.
  final String? varianteTexto;

  /// «2 nov».
  final String? fechaTexto;

  /// Se acaba de lograr: lleva «Nuevo récord» con icono.
  final bool reciente;

  String get anuncio => [
    ejercicio,
    ?varianteTexto,
    tipo.texto,
    valorTexto,
    ?fechaTexto,
    if (reciente) TextosGimnasio.nuevoRecord.toLowerCase(),
  ].join(', ');
}

/// **Récords**: una fila por variante, sin compararse con nadie (6.2).
class ListaRecords extends StatelessWidget {
  const ListaRecords({
    super.key,
    required this.records,
    this.alTocarRecord,
    this.estado = EstadoVistaGimnasio.listo,
    this.mensajes = const MensajesEstadoGimnasio(
      vacio: 'Todavía no hay récords.',
      vacioDetalle: 'Tu primera serie ya cuenta como punto de partida.',
      cargando: 'Calculando tus récords…',
      sinConexion: 'Sin conexión. Se muestran los récords de lo guardado aquí.',
      error: 'No se pudieron calcular los récords. Puedes intentarlo otra vez.',
    ),
    this.alReintentar,
  });

  final List<RecordVista> records;
  final ValueChanged<int>? alTocarRecord;
  final EstadoVistaGimnasio estado;
  final MensajesEstadoGimnasio mensajes;
  final VoidCallback? alReintentar;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    if (estado != EstadoVistaGimnasio.listo || records.isEmpty) {
      return TarjetaModulo(
        titulo: 'Récords',
        icono: Icons.emoji_events_outlined,
        child: CuerpoEstadoGimnasio(
          estado: estado == EstadoVistaGimnasio.listo
              ? EstadoVistaGimnasio.vacio
              : estado,
          mensajes: mensajes,
          alReintentar: alReintentar,
        ),
      );
    }
    return TarjetaModulo(
      titulo: 'Récords',
      icono: Icons.emoji_events_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < records.length; i++)
            Builder(
              builder: (context) {
                final r = records[i];
                final alTocar = alTocarRecord == null
                    ? null
                    : () => alTocarRecord!(i);
                final fila = ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: e),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(
                            top: e * 0.25,
                            right: e * 1.25,
                          ),
                          child: Icon(r.tipo.icono, size: 22, color: v.acento),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.ejercicio,
                                style: v.lectura(
                                  tamano: 15,
                                  peso: FontWeight.w700,
                                  color: v.textoFuerte,
                                ),
                              ),
                              Text(
                                [
                                  r.tipo.texto,
                                  ?r.varianteTexto,
                                  ?r.fechaTexto,
                                ].join(' · '),
                                style: v.lectura(
                                  tamano: 13.5,
                                  color: v.textoTenue,
                                ),
                              ),
                              if (r.reciente) ...[
                                SizedBox(height: e * 0.5),
                                MarcaGimnasio(
                                  texto: TextosGimnasio.nuevoRecord,
                                  icono: Icons.emoji_events_outlined,
                                  color: v.acento,
                                  enfasis: true,
                                ),
                              ],
                            ],
                          ),
                        ),
                        SizedBox(width: e),
                        Flexible(
                          child: Text(
                            r.valorTexto,
                            textAlign: TextAlign.end,
                            style: v.numero(
                              tamano: 20,
                              peso: FontWeight.w700,
                              color: v.textoFuerte,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
                return Semantics(
                  container: true,
                  button: alTocar != null,
                  onTap: alTocar,
                  label: r.anuncio,
                  excludeSemantics: true,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: i == records.length - 1
                            ? BorderSide.none
                            : BorderSide(color: v.borde, width: 0.5),
                      ),
                    ),
                    child: alTocar == null
                        ? fila
                        : InkWell(onTap: alTocar, child: fila),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
