import 'package:flutter/material.dart';

import '../componentes/monto_ocultable.dart';
import '../componentes/semaforo.dart';
import '../tema.dart';
import '../superficies.dart';
import '../valores_diseno.dart';

/// Un peldaño del fondo de emergencia (Fase 2, regla 17).
@immutable
class NivelFondo {
  const NivelFondo(this.numero, this.nombre, this.semanas);

  final int numero;
  final String nombre;

  /// Semanas de gasto esencial que cubre.
  final int semanas;
}

/// Los 5 niveles del fondo, de abajo hacia arriba.
const List<NivelFondo> nivelesFondo = [
  NivelFondo(1, 'Colchón', 2),
  NivelFondo(2, 'Mes', 4),
  NivelFondo(3, 'Tres meses', 13),
  NivelFondo(4, 'Seis meses', 26),
  NivelFondo(5, 'Un año', 52),
];

/// Gadget **Escalera del fondo** (Fase 2, sección 8): 5 peldaños con el nivel
/// **actual** marcado, la **meta** elegida y el nivel **sugerido**; arriba,
/// "tienes X semanas cubiertas" con su semáforo **con texto**.
///
/// - [nivelActual]: el último nivel alcanzado (0 si aún no llega al primero).
/// - [nivelMeta]: el nivel elegido (1 a 5).
/// - [nivelSugerido]: p. ej. el 4 con un solo ingreso o dependientes; `null`
///   si no hay sugerencia.
/// - [semanasCubiertas]: saldo ÷ gasto esencial; se muestra con un decimal
///   **hacia abajo**. `null`: aún no hay gasto esencial (sin semáforo).
/// - [metasCentavos]: la meta en pesos de cada nivel (5 valores) si se
///   conocen; los montos se ocultan solos.
/// - [alElegirNivel]: si se pasa, cada peldaño se puede tocar (48 dp).
class EscaleraFondo extends StatelessWidget {
  const EscaleraFondo({
    super.key,
    required this.nivelActual,
    required this.nivelMeta,
    this.nivelSugerido,
    this.semanasCubiertas,
    this.estado,
    this.metasCentavos,
    this.alElegirNivel,
  }) : assert(nivelActual >= 0 && nivelActual <= 5),
       assert(nivelMeta >= 1 && nivelMeta <= 5),
       assert(metasCentavos == null || metasCentavos.length == 5);

  final int nivelActual;
  final int nivelMeta;
  final int? nivelSugerido;
  final double? semanasCubiertas;
  final EstadoSemaforo? estado;
  final List<int>? metasCentavos;
  final ValueChanged<int>? alElegirNivel;

  /// "3.0", con un decimal hacia abajo (2.96 se ve "2.9": nunca de más).
  static String textoSemanas(double semanas) =>
      ((semanas * 10).floor() / 10).toStringAsFixed(1);

  static String textoEstado(EstadoSemaforo estado) => switch (estado) {
    EstadoSemaforo.verde => 'Meta cubierta',
    EstadoSemaforo.ambar => 'En camino',
    EstadoSemaforo.rojo => 'Bajo la mitad de la meta',
  };

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    final semanas = semanasCubiertas;
    final resumen = semanas == null
        ? 'Sin gasto esencial calculado'
        : 'Tienes ${textoSemanas(semanas)} semanas cubiertas';
    final estado = semanas == null ? null : this.estado;

    return Semantics(
      container: true,
      label: 'Escalera del fondo de emergencia',
      value: [
        resumen,
        if (estado != null) textoEstado(estado),
        'Nivel actual: ${nivelActual == 0 ? 'ninguno' : nivelActual}',
        'Meta: nivel $nivelMeta',
      ].join('. '),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: e,
              runSpacing: e * 0.5,
              children: [
                Text(
                  resumen,
                  style: v.lectura(
                    tamano: 16,
                    peso: FontWeight.w600,
                    color: v.textoFuerte,
                  ),
                ),
                if (estado != null)
                  Semaforo(
                    estado: estado,
                    etiqueta: textoEstado(estado),
                    conIcono: true,
                    tamanoTexto: 13,
                  ),
              ],
            ),
          ),
          SizedBox(height: e * 1.5),
          for (final nivel in nivelesFondo.reversed)
            _Peldano(
              nivel: nivel,
              alcanzado: nivel.numero <= nivelActual,
              actual: nivel.numero == nivelActual,
              meta: nivel.numero == nivelMeta,
              sugerido: nivel.numero == nivelSugerido,
              metaCentavos: metasCentavos?[nivel.numero - 1],
              alTocar: alElegirNivel == null
                  ? null
                  : () => alElegirNivel!(nivel.numero),
            ),
        ],
      ),
    );
  }
}

class _Peldano extends StatelessWidget {
  const _Peldano({
    required this.nivel,
    required this.alcanzado,
    required this.actual,
    required this.meta,
    required this.sugerido,
    required this.metaCentavos,
    required this.alTocar,
  });

  final NivelFondo nivel;
  final bool alcanzado;
  final bool actual;
  final bool meta;
  final bool sugerido;
  final int? metaCentavos;
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    final color = alcanzado ? v.exito : v.textoTenue;
    final marcas = [
      if (actual) 'Actual',
      if (meta) 'Meta',
      if (sugerido) 'Sugerido',
    ];
    final descripcion = [
      'Nivel ${nivel.numero}: ${nivel.nombre}, ${nivel.semanas} semanas',
      alcanzado ? 'alcanzado' : 'sin alcanzar',
      ...marcas.map((m) => m.toLowerCase()),
    ].join(', ');

    final contenido = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: zonaTactilMinima),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: e, vertical: e * 0.5),
        child: Row(
          children: [
            Icon(
              alcanzado ? Icons.check_circle_outline : Icons.circle_outlined,
              size: 20,
              color: color,
            ),
            SizedBox(width: e),
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: e,
                runSpacing: e * 0.25,
                children: [
                  Text(
                    '${nivel.numero}. ${nivel.nombre}',
                    style: v.lectura(
                      tamano: 14,
                      peso: actual || meta ? FontWeight.w700 : FontWeight.w500,
                      color: v.textoFuerte,
                    ),
                  ),
                  Text(
                    '${nivel.semanas} semanas',
                    style: v.numero(tamano: 12, color: v.textoTenue),
                  ),
                  if (metaCentavos != null)
                    MontoOcultable(
                      centavos: metaCentavos!,
                      estilo: v.numero(tamano: 12, color: v.textoTenue),
                    ),
                  for (final m in marcas)
                    _Marca(texto: m, resaltada: m == 'Meta'),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final forma = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(v.radioMediano),
      side: BorderSide(
        color: actual || meta ? v.acento : v.borde,
        width: actual || meta ? 1.5 : 1,
      ),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: e * 0.5),
      child: Semantics(
        container: true,
        button: alTocar != null,
        selected: meta,
        label: descripcion,
        excludeSemantics: true,
        onTap: alTocar,
        child: Material(
          color: meta ? v.chipSeleccionado : v.panel,
          shape: forma,
          clipBehavior: Clip.antiAlias,
          child: alTocar == null
              ? contenido
              : InkWell(onTap: alTocar, customBorder: forma, child: contenido),
        ),
      ),
    );
  }
}

class _Marca extends StatelessWidget {
  const _Marca({required this.texto, required this.resaltada});

  final String texto;
  final bool resaltada;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: resaltada ? v.acento : v.borde),
        borderRadius: BorderRadius.circular(v.radioChico),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: v.espacio * 0.75,
          vertical: 1,
        ),
        child: Text(
          texto,
          style: v.lectura(
            tamano: 11.5,
            peso: FontWeight.w600,
            color: v.textoFuerte,
          ),
        ),
      ),
    );
  }
}
