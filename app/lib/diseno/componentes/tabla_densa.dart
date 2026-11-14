import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../proveedores.dart';
import '../superficies.dart';
import '../tema.dart';
import '../valores_diseno.dart';
import 'monto_ocultable.dart';
import 'semaforo.dart';

/// Una columna de [TablaDensa].
@immutable
class ColumnaTabla {
  const ColumnaTabla(
    this.titulo, {
    this.numerica = false,
    this.flex = 1,
    this.ancho,
    this.alOrdenar,
  });

  /// Encabezado ("Categoría", "Gastado").
  final String titulo;

  /// Montos, fechas y porcentajes: alineados a la derecha, como en el boceto
  /// *Laptop · Finanzas › Semana*, para que las cifras se lean en columna.
  final bool numerica;

  /// Parte del ancho libre que toma (si no tiene [ancho] fijo).
  final int flex;

  /// Ancho fijo en píxeles lógicos (p. ej. una fecha o un semáforo).
  final double? ancho;

  /// Si se indica, el encabezado ordena la tabla al tocarlo.
  final VoidCallback? alOrdenar;
}

/// Una fila de [TablaDensa]: una celda por columna.
@immutable
class FilaTabla {
  const FilaTabla({
    required this.celdas,
    this.alTocar,
    this.seleccionada = false,
    this.etiquetaSemantica,
  });

  final List<Widget> celdas;

  /// Abre el detalle (panel lateral u hoja). La fila mide 48 dp o más.
  final VoidCallback? alTocar;

  /// Su detalle está abierto: fondo con el acento y una franja a la izquierda,
  /// y el lector de pantalla dice "seleccionado".
  final bool seleccionada;

  /// Lo que dice el lector de pantalla en lugar de leer celda por celda
  /// ("Alimentación: gastado $1,240.00 de $1,800.00, bien"). Recomendado en
  /// las filas que se tocan.
  final String? etiquetaSemantica;
}

/// Medidas y énfasis de las celdas, según la densidad y si es la fila de total.
class EstiloTabla extends InheritedWidget {
  const EstiloTabla({
    super.key,
    required this.tamanoTexto,
    this.enfasis = false,
    required super.child,
  });

  /// Tamaño de la letra de las celdas.
  final double tamanoTexto;

  /// Fila de totales: cifras en negritas y texto fuerte.
  final bool enfasis;

  /// El de la tabla más cercana; fuera de una tabla, el de la densidad.
  static EstiloTabla de(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<EstiloTabla>() ??
      EstiloTabla(
        tamanoTexto: ValoresDiseno.de(context).densidad.textoTabla,
        child: const SizedBox.shrink(),
      );

  @override
  bool updateShouldNotify(EstiloTabla anterior) =>
      anterior.tamanoTexto != tamanoTexto || anterior.enfasis != enfasis;
}

/// Tabla densa de la personalidad **precisa y serena** (Finanzas en la laptop:
/// partidas, movimientos, cuentas): encabezado sobrio, filas separadas por una
/// línea fina, cifras de ancho fijo alineadas a la derecha, fila de total y
/// selección para el panel de detalle (DISENO_UX_UI, sección 8).
///
/// - Las filas de solo lectura miden lo de la densidad (40 dp en la laptop);
///   las que se tocan, 48 dp o más.
/// - Si la ventana es más angosta que [anchoMinimo], la tabla se desplaza a lo
///   ancho en lugar de apretarse.
/// - Sin filas, muestra [vacio] (p. ej. un `EstadoVacio`) bajo el encabezado.
///
/// No se desplaza a lo alto: va dentro del desplazamiento de la pantalla y se
/// pagina (30 a 50 filas). Necesita un ancho acotado.
class TablaDensa extends StatelessWidget {
  const TablaDensa({
    super.key,
    required this.columnas,
    required this.filas,
    this.pie,
    this.columnaOrdenada,
    this.ascendente = true,
    this.anchoMinimo = 0,
    this.vacio,
    this.etiquetaSemantica,
  });

  final List<ColumnaTabla> columnas;
  final List<FilaTabla> filas;

  /// Fila de totales, con una línea más marcada arriba y cifras en negritas.
  final FilaTabla? pie;

  /// Índice de la columna por la que está ordenada (muestra la flecha).
  final int? columnaOrdenada;
  final bool ascendente;

  /// Ancho por debajo del cual la tabla se desplaza a lo ancho.
  final double anchoMinimo;

  /// Lo que se ve si no hay filas.
  final Widget? vacio;

  /// Nombre de la tabla para el lector de pantalla ("Cuentas de gasto").
  final String? etiquetaSemantica;

  @override
  Widget build(BuildContext context) {
    assert(
      [...filas, ?pie].every((f) => f.celdas.length == columnas.length),
      'Cada fila necesita una celda por columna',
    );
    final v = ValoresDiseno.de(context);
    final tamano = v.densidad.textoTabla;
    final ordenable = columnas.any((c) => c.alOrdenar != null);

    final tabla = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _Encabezado(
          columnas: columnas,
          alto: ordenable ? zonaTactilMinima : v.densidad.altoEncabezadoTabla,
          columnaOrdenada: columnaOrdenada,
          ascendente: ascendente,
        ),
        if (filas.isEmpty && vacio != null)
          Padding(
            padding: EdgeInsets.symmetric(vertical: v.espacio * 3),
            child: vacio,
          ),
        for (final fila in filas)
          _Fila(columnas: columnas, fila: fila, tamanoTexto: tamano),
        if (pie != null)
          _Fila(
            columnas: columnas,
            fila: pie!,
            tamanoTexto: tamano,
            total: true,
          ),
      ],
    );

    return Semantics(
      container: true,
      label: etiquetaSemantica,
      child: LayoutBuilder(
        builder: (context, limites) {
          if (anchoMinimo <= limites.maxWidth) return tabla;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(width: anchoMinimo, child: tabla),
          );
        },
      ),
    );
  }
}

/// Celda dentro de su columna: ancho, alineación y relleno.
Widget _enColumna(ColumnaTabla columna, ValoresDiseno v, Widget hijo) {
  final celda = Padding(
    padding: EdgeInsets.symmetric(horizontal: v.espacio * 1.5),
    child: Align(
      alignment: columna.numerica
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: hijo,
    ),
  );
  final ancho = columna.ancho;
  return ancho != null
      ? SizedBox(width: ancho, child: celda)
      : Expanded(flex: columna.flex, child: celda);
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({
    required this.columnas,
    required this.alto,
    required this.columnaOrdenada,
    required this.ascendente,
  });

  final List<ColumnaTabla> columnas;
  final double alto;
  final int? columnaOrdenada;
  final bool ascendente;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final estilo = v.lectura(
      tamano: v.densidad.textoTabla - 0.5,
      peso: FontWeight.w600,
      color: v.etiqueta,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: v.encabezadoTabla,
        border: Border(
          bottom: BorderSide(color: v.borde, width: v.grosorBorde),
        ),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: alto),
        child: Row(
          children: [
            for (var i = 0; i < columnas.length; i++)
              _enColumna(
                columnas[i],
                v,
                _TituloColumna(
                  columna: columnas[i],
                  estilo: estilo,
                  ordenada: columnaOrdenada == i,
                  ascendente: ascendente,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TituloColumna extends StatelessWidget {
  const _TituloColumna({
    required this.columna,
    required this.estilo,
    required this.ordenada,
    required this.ascendente,
  });

  final ColumnaTabla columna;
  final TextStyle estilo;
  final bool ordenada;
  final bool ascendente;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final texto = Text(
      columna.titulo,
      style: estilo,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: columna.numerica ? TextAlign.end : TextAlign.start,
    );
    final alOrdenar = columna.alOrdenar;
    if (alOrdenar == null) {
      return Semantics(header: true, child: texto);
    }
    final contenido = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: texto),
        if (ordenada) ...[
          SizedBox(width: v.espacio * 0.5),
          Icon(
            ascendente ? Icons.arrow_upward : Icons.arrow_downward,
            size: 14,
            color: v.etiqueta,
          ),
        ],
      ],
    );
    return Semantics(
      header: true,
      button: true,
      label: columna.titulo,
      value: ordenada
          ? (ascendente ? 'orden ascendente' : 'orden descendente')
          : null,
      hint: 'Toca para ordenar',
      excludeSemantics: true,
      onTap: alOrdenar,
      child: InkWell(
        onTap: alOrdenar,
        borderRadius: BorderRadius.circular(v.radioChico),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: zonaTactilMinima),
          child: Align(widthFactor: 1, child: contenido),
        ),
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({
    required this.columnas,
    required this.fila,
    required this.tamanoTexto,
    this.total = false,
  });

  final List<ColumnaTabla> columnas;
  final FilaTabla fila;
  final double tamanoTexto;
  final bool total;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final alTocar = fila.alTocar;
    final alto = alTocar != null
        ? math.max(zonaTactilMinima, v.densidad.altoFilaTabla)
        : v.densidad.altoFilaTabla;

    Widget contenido = ConstrainedBox(
      constraints: BoxConstraints(minHeight: alto),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: v.espacio * 0.5),
        child: Row(
          children: [
            for (var i = 0; i < columnas.length; i++)
              _enColumna(columnas[i], v, fila.celdas[i]),
          ],
        ),
      ),
    );

    contenido = EstiloTabla(
      tamanoTexto: tamanoTexto,
      enfasis: total,
      child: contenido,
    );

    if (alTocar != null) {
      contenido = InkWell(
        onTap: alTocar,
        hoverColor: v.filaResaltada,
        child: contenido,
      );
    }

    contenido = Material(
      color: fila.seleccionada ? v.filaSeleccionada : Colors.transparent,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: v.borde, width: total ? 2 : 1),
            left: fila.seleccionada
                ? BorderSide(color: v.acento, width: 3)
                : BorderSide.none,
          ),
        ),
        child: contenido,
      ),
    );

    final etiqueta = fila.etiquetaSemantica;
    return Semantics(
      container: true,
      selected: fila.seleccionada,
      button: alTocar != null,
      label: etiqueta,
      onTap: etiqueta != null ? alTocar : null,
      excludeSemantics: etiqueta != null,
      child: contenido,
    );
  }
}

/// Texto en una celda, con un detalle opcional más tenue ("Servicios ·
/// protegida"). Con [numerico], letra de ancho fijo (fechas, porcentajes).
class CeldaTexto extends StatelessWidget {
  const CeldaTexto(
    this.texto, {
    super.key,
    this.detalle,
    this.tenue = false,
    this.numerico = false,
  });

  final String texto;
  final String? detalle;
  final bool tenue;
  final bool numerico;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final t = EstiloTabla.de(context);
    final color = tenue ? v.textoTenue : (t.enfasis ? v.textoFuerte : v.texto);
    final peso = t.enfasis ? FontWeight.w600 : FontWeight.w400;
    final base = numerico
        ? v.numero(tamano: t.tamanoTexto, peso: peso, color: color)
        : v.lectura(tamano: t.tamanoTexto, peso: peso, color: color);
    return Text.rich(
      TextSpan(
        text: texto,
        style: base,
        children: [
          if (detalle != null)
            TextSpan(
              text: ' · $detalle',
              style: v.lectura(
                tamano: t.tamanoTexto - 1.5,
                color: v.textoTenue,
              ),
            ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Monto en una celda: ancho fijo, cifras tabulares y modo oculto (si lo pide
/// [oculto] o la app tiene los montos ocultos: [montosOcultosProvider]). Los
/// negativos van en rojo **y** con su signo (salvo con el monto oculto, donde
/// el color no delata nada).
class CeldaMonto extends ConsumerWidget {
  const CeldaMonto(
    this.centavos, {
    super.key,
    this.oculto = false,
    this.mostrarSigno = false,
    this.negativoEnRojo = true,
    this.tenue = false,
  });

  final int centavos;
  final bool oculto;
  final bool mostrarSigno;
  final bool negativoEnRojo;
  final bool tenue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final oculto = this.oculto || ref.watch(montosOcultosProvider);
    final v = ValoresDiseno.de(context);
    final t = EstiloTabla.de(context);
    final Color color;
    if (!oculto && negativoEnRojo && centavos < 0) {
      color = v.peligro;
    } else if (tenue) {
      color = v.textoTenue;
    } else {
      color = t.enfasis ? v.textoFuerte : v.texto;
    }
    return MontoOcultable(
      centavos: centavos,
      oculto: oculto,
      mostrarSigno: mostrarSigno,
      estilo: v.numero(
        tamano: t.tamanoTexto,
        peso: t.enfasis ? FontWeight.w700 : FontWeight.w500,
        color: color,
      ),
    );
  }
}

/// Semáforo en una celda: icono del estado y su texto ("⚠ Cerca del límite").
/// Con [soloIcono], solo el icono (columna estrecha); el texto queda para el
/// lector de pantalla y como texto emergente.
class CeldaSemaforo extends StatelessWidget {
  const CeldaSemaforo(
    this.estado, {
    super.key,
    this.etiqueta,
    this.soloIcono = false,
  });

  final EstadoSemaforo estado;
  final String? etiqueta;
  final bool soloIcono;

  @override
  Widget build(BuildContext context) {
    final t = EstiloTabla.de(context);
    return Semaforo(
      estado: estado,
      etiqueta: etiqueta,
      tamanoTexto: t.tamanoTexto,
      conIcono: true,
      soloIcono: soloIcono,
    );
  }
}
