import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../componentes/estado_vacio.dart';
import '../componentes/barra_progreso.dart';
import '../tema.dart';
import '../valores_diseno.dart';
import 'rachas.dart';

/// Tarjeta de un objetivo: área, avance, ritmo necesario y racha. Un objetivo
/// pausado se dice con texto, no solo atenuado.
class TarjetaObjetivo extends StatelessWidget {
  const TarjetaObjetivo({
    super.key,
    required this.titulo,
    required this.area,
    required this.avance,
    this.avanceTexto,
    this.ritmoTexto,
    this.racha,
    this.pausado = false,
    this.alTocar,
  });

  final String titulo;
  final String area;

  /// De 0 a 1.
  final double avance;

  /// "12 de 30 páginas".
  final String? avanceTexto;

  /// "Necesitas 2 por día".
  final String? ritmoTexto;
  final int? racha;
  final bool pausado;
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    final radio = BorderRadius.circular(v.radioMediano);
    final contenido = Padding(
      padding: EdgeInsets.all(e * 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: e,
            runSpacing: e * 0.5,
            children: [
              Text(area.toUpperCase(), style: v.etiquetaPanel(tamano: 11.5)),
              if (pausado)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.pause_circle_outline,
                      size: 16,
                      color: v.textoTenue,
                    ),
                    SizedBox(width: e * 0.5),
                    Text(
                      'En pausa',
                      style: v.lectura(tamano: 12.5, color: v.textoTenue),
                    ),
                  ],
                ),
            ],
          ),
          SizedBox(height: e * 0.5),
          Text(
            titulo,
            style: v.lectura(
              tamano: 16,
              peso: FontWeight.w600,
              color: pausado ? v.textoTenue : v.textoFuerte,
            ),
          ),
          SizedBox(height: e * 1.25),
          BarraProgreso(
            etiqueta: avanceTexto ?? 'Avance',
            valor: avance,
            alto: 8,
          ),
          if (ritmoTexto != null)
            Padding(
              padding: EdgeInsets.only(top: e),
              child: Text(
                ritmoTexto!,
                style: v.lectura(tamano: 13, color: v.textoTenue),
              ),
            ),
          if (racha != null && racha! > 0)
            Padding(
              padding: EdgeInsets.only(top: e),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: ChipRacha(dias: racha!),
              ),
            ),
        ],
      ),
    );
    return Semantics(
      container: true,
      button: alTocar != null,
      label: 'Objetivo: $titulo, $area${pausado ? ', en pausa' : ''}',
      value: '${(avance * 100).floor()} %',
      onTap: alTocar,
      child: Material(
        color: v.panel,
        shape: RoundedRectangleBorder(
          borderRadius: radio,
          side: BorderSide(color: v.borde),
        ),
        clipBehavior: Clip.antiAlias,
        child: alTocar == null
            ? contenido
            : InkWell(
                onTap: alTocar,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: zonaTactilMinima,
                  ),
                  child: contenido,
                ),
              ),
      ),
    );
  }
}

/// Una línea del resumen semanal: área y cumplimiento (0 a 1) con su
/// porcentaje en texto.
@immutable
class CumplimientoArea {
  const CumplimientoArea(this.area, this.valor);

  final String area;
  final double valor;
}

/// Resumen de la revisión semanal: barras por área con el porcentaje escrito y
/// una pregunta reflexiva al pie (sin juicio).
class ResumenSemanal extends StatelessWidget {
  const ResumenSemanal({
    super.key,
    required this.areas,
    this.pregunta = '¿Qué te ayudó esta semana?',
    this.alCerrar,
  });

  final List<CumplimientoArea> areas;
  final String pregunta;
  final VoidCallback? alCerrar;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    return Semantics(
      container: true,
      label: 'Revisión semanal',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final a in areas)
            Padding(
              padding: EdgeInsets.only(bottom: e * 1.25),
              child: BarraProgreso(
                etiqueta: a.area,
                valor: a.valor,
                textoValor: '${(a.valor * 100).floor()} %',
                alto: 8,
              ),
            ),
          SizedBox(height: e),
          Text(
            pregunta,
            style: v
                .lectura(tamano: 16, color: v.textoFuerte)
                .copyWith(height: 1.5),
          ),
          if (alCerrar != null) ...[
            SizedBox(height: e * 2),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: zonaTactilMinima),
                child: FilledButton(
                  onPressed: alCerrar,
                  child: const Text('Cerrar la revisión'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Abre una **hoja inferior** con asa, título y cierre de 48 dp; el contenido
/// se desplaza y se ajusta al teclado.
Future<T?> mostrarHojaInferior<T>(
  BuildContext context, {
  required String titulo,
  required Widget child,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => HojaInferior(titulo: titulo, child: child),
  );
}

class HojaInferior extends StatelessWidget {
  const HojaInferior({super.key, required this.titulo, required this.child});

  final String titulo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(e * 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      titulo,
                      style: v.titulo(tamano: 20, color: v.textoFuerte),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  constraints: const BoxConstraints(
                    minWidth: zonaTactilMinima,
                    minHeight: zonaTactilMinima,
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    Navigator.maybePop(context);
                  },
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            SizedBox(height: e),
            child,
          ],
        ),
      ),
    );
  }
}

/// Mensajes de estado vacío de Hábitos: cálidos, sin culpa ni reproche.
enum VacioHabitos {
  hoyLibre(
    'Hoy está libre',
    'Cuando quieras, agrega algo pequeño.',
    Icons.wb_sunny_outlined,
  ),
  sinObjetivos(
    'Aún no hay objetivos',
    'Empezamos con uno, el más sencillo.',
    Icons.flag_outlined,
  ),
  sinRacha(
    'Empecemos cuando quieras',
    'Cada día cuenta, sin prisa.',
    Icons.local_fire_department_outlined,
  ),
  sinDatos(
    'Faltan algunos días',
    'Cuando haya más registros, calculamos tu promedio.',
    Icons.hourglass_empty,
  ),
  soloTelefono(
    'Este dato está solo en tu teléfono',
    'Puedes activar la nube cifrada si quieres verlo aquí.',
    Icons.phone_android,
  );

  const VacioHabitos(this.mensaje, this.detalle, this.icono);

  final String mensaje;
  final String detalle;
  final IconData icono;
}

/// Estado vacío de Hábitos con un mensaje de [VacioHabitos] y, si se pasa
/// [alAccionar], un único botón (por ejemplo *Cómo activar la nube cifrada*).
class EstadoVacioHabitos extends StatelessWidget {
  const EstadoVacioHabitos({
    super.key,
    required this.tipo,
    this.textoAccion,
    this.alAccionar,
  });

  final VacioHabitos tipo;
  final String? textoAccion;
  final VoidCallback? alAccionar;

  @override
  Widget build(BuildContext context) => EstadoVacio(
    mensaje: tipo.mensaje,
    detalle: tipo.detalle,
    icono: tipo.icono,
    textoAccion: alAccionar == null ? null : textoAccion,
    alAccionar: textoAccion == null ? null : alAccionar,
  );
}
