import 'package:flutter/material.dart';

import '../componentes/barra_progreso.dart';
import '../tema.dart';
import '../valores_diseno.dart';
import 'sensible_ocultable.dart';

/// Un versículo del lector.
@immutable
class VersiculoLector {
  const VersiculoLector(this.numero, this.texto, {this.subrayado = false});

  final int numero;
  final String texto;
  final bool subrayado;
}

/// Lector bíblico (personalidad contemplativa): letra de lectura **grande**,
/// interlineado amplio, sin animación y sin brillos. Los subrayados llevan
/// fondo **y** subrayado de texto. Cada versículo se puede tocar (48 dp) para
/// subrayar o anotar. Cabe en 360 dp con la letra al 200 %.
class LectorBiblico extends StatelessWidget {
  const LectorBiblico({
    super.key,
    required this.referencia,
    required this.versiculos,
    this.version,
    this.tamano = 19,
    this.alTocarVersiculo,
  });

  /// "Salmo 23".
  final String referencia;
  final List<VersiculoLector> versiculos;

  /// "RVR1960", etc. (solo si el texto trae licencia libre).
  final String? version;
  final double tamano;
  final ValueChanged<VersiculoLector>? alTocarVersiculo;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    return Semantics(
      container: true,
      label: 'Lector: $referencia',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: e,
            children: [
              Semantics(
                header: true,
                child: Text(
                  referencia,
                  style: v.titulo(tamano: 24, color: v.textoFuerte),
                ),
              ),
              if (version != null)
                Text(
                  version!,
                  style: v.numero(tamano: 12.5, color: v.textoTenue),
                ),
            ],
          ),
          SizedBox(height: e * 1.5),
          for (final versiculo in versiculos)
            _Versiculo(
              versiculo: versiculo,
              tamano: tamano,
              alTocar: alTocarVersiculo == null
                  ? null
                  : () => alTocarVersiculo!(versiculo),
            ),
        ],
      ),
    );
  }
}

class _Versiculo extends StatelessWidget {
  const _Versiculo({
    required this.versiculo,
    required this.tamano,
    required this.alTocar,
  });

  final VersiculoLector versiculo;
  final double tamano;
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final texto = Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '${versiculo.numero} ',
            style: v.numero(tamano: tamano * 0.65, color: v.acento),
          ),
          TextSpan(
            text: versiculo.texto,
            style: v
                .lectura(tamano: tamano, color: v.textoFuerte)
                .copyWith(
                  height: 1.7,
                  decoration: versiculo.subrayado
                      ? TextDecoration.underline
                      : null,
                  backgroundColor: versiculo.subrayado
                      ? v.acento.withValues(alpha: 0.18)
                      : null,
                ),
          ),
        ],
      ),
    );
    return Semantics(
      container: true,
      button: alTocar != null,
      label:
          'Versículo ${versiculo.numero}'
          '${versiculo.subrayado ? ', subrayado' : ''}',
      value: versiculo.texto,
      excludeSemantics: true,
      onTap: alTocar,
      child: alTocar == null
          ? Padding(
              padding: EdgeInsets.symmetric(vertical: v.espacio * 0.5),
              child: texto,
            )
          : InkWell(
              onTap: alTocar,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: zonaTactilMinima),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: v.espacio * 0.5),
                  child: texto,
                ),
              ),
            ),
    );
  }
}

/// Tarjeta de un plan de lectura: avance, lectura de hoy y, si va atrasado,
/// *Ponerse al día* (sin reproche).
class TarjetaPlanLectura extends StatelessWidget {
  const TarjetaPlanLectura({
    super.key,
    required this.titulo,
    required this.avance,
    required this.lecturaDeHoy,
    this.diaTexto,
    this.diasAtrasado = 0,
    this.alLeer,
    this.alPonerseAlDia,
  });

  final String titulo;

  /// De 0 a 1.
  final double avance;

  /// "Salmo 23 · Juan 1:1-18".
  final String lecturaDeHoy;
  final String? diaTexto;
  final int diasAtrasado;
  final VoidCallback? alLeer;
  final VoidCallback? alPonerseAlDia;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    return Semantics(
      container: true,
      label: 'Plan de lectura: $titulo',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: v.panel,
          border: Border.all(color: v.borde),
          borderRadius: BorderRadius.circular(v.radioMediano),
        ),
        child: Padding(
          padding: EdgeInsets.all(e * 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                titulo,
                style: v.lectura(
                  tamano: 16,
                  peso: FontWeight.w600,
                  color: v.textoFuerte,
                ),
              ),
              if (diaTexto != null)
                Text(
                  diaTexto!,
                  style: v.lectura(tamano: 13, color: v.textoTenue),
                ),
              SizedBox(height: e * 1.25),
              BarraProgreso(etiqueta: 'Avance', valor: avance, alto: 8),
              SizedBox(height: e * 1.25),
              Text(
                'Hoy: $lecturaDeHoy',
                style: v.lectura(tamano: 15, color: v.texto),
              ),
              if (diasAtrasado > 0)
                Padding(
                  padding: EdgeInsets.only(top: e * 0.5),
                  child: Text(
                    'Llevas $diasAtrasado ${diasAtrasado == 1 ? 'día' : 'días'} de atraso. Sin prisa.',
                    style: v.lectura(tamano: 13, color: v.textoTenue),
                  ),
                ),
              SizedBox(height: e * 1.5),
              Wrap(
                spacing: e,
                runSpacing: e,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: zonaTactilMinima,
                    ),
                    child: FilledButton(
                      onPressed: alLeer,
                      child: const Text('Leer'),
                    ),
                  ),
                  if (diasAtrasado > 0)
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: zonaTactilMinima,
                      ),
                      child: OutlinedButton(
                        onPressed: alPonerseAlDia,
                        child: const Text('Ponerme al día'),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tarjeta del devocional del día: referencia, un pensamiento corto y la acción
/// *Leer*. El pensamiento personal es sensible y se oculta solo.
class TarjetaDevocional extends StatelessWidget {
  const TarjetaDevocional({
    super.key,
    required this.referencia,
    this.pensamiento,
    this.alLeer,
  });

  final String referencia;
  final String? pensamiento;
  final VoidCallback? alLeer;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    return Semantics(
      container: true,
      label: 'Devocional: $referencia',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: v.panel,
          border: Border.all(color: v.borde),
          borderRadius: BorderRadius.circular(v.radioMediano),
        ),
        child: Padding(
          padding: EdgeInsets.all(e * 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'DEVOCIONAL',
                style: v.etiquetaPanel(tamano: 12, color: v.acento),
              ),
              SizedBox(height: e),
              Text(
                referencia,
                style: v.titulo(tamano: 20, color: v.textoFuerte),
              ),
              if (pensamiento != null) ...[
                SizedBox(height: e),
                TextoSensible(
                  pensamiento!,
                  estilo: v
                      .lectura(tamano: 16, color: v.texto)
                      .copyWith(height: 1.6),
                ),
              ],
              SizedBox(height: e * 1.5),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: zonaTactilMinima,
                  ),
                  child: FilledButton(
                    onPressed: alLeer,
                    child: const Text('Leer'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fila de una petición de oración (diario y listas): el texto es sensible;
/// una respondida lleva palomita **y** la palabra "Respondida".
class FilaOracion extends StatelessWidget {
  const FilaOracion({
    super.key,
    required this.texto,
    this.respondida = false,
    this.fechaTexto,
    this.alTocar,
  });

  final String texto;
  final bool respondida;
  final String? fechaTexto;
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    final contenido = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: zonaTactilMinima),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: e * 1.5, vertical: e),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              respondida ? Icons.check_circle_outline : Icons.circle_outlined,
              size: 20,
              color: respondida ? v.exito : v.textoTenue,
            ),
            SizedBox(width: e * 1.25),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextoSensible(
                    texto,
                    estilo: v.lectura(tamano: 15, color: v.textoFuerte),
                  ),
                  if (respondida || fechaTexto != null)
                    Text(
                      [if (respondida) 'Respondida', ?fechaTexto].join(' · '),
                      style: v.lectura(tamano: 12.5, color: v.textoTenue),
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
      button: alTocar != null,
      label: 'Oración${respondida ? ' respondida' : ''}',
      excludeSemantics: true,
      onTap: alTocar,
      child: alTocar == null
          ? contenido
          : InkWell(onTap: alTocar, child: contenido),
    );
  }
}
