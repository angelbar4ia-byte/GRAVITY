import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../proveedores.dart';
import '../valores_diseno.dart';

/// Si los datos sensibles de Hábitos (hábitos a eliminar, oración, diario) se
/// dibujan ocultos. Por omisión sigue a los montos ocultos
/// ([montosOcultosProvider]: modo privado, o sin mostrar tras abrir la app o
/// tras unos minutos sin uso); Hábitos o plataforma lo pueden sustituir.
final sensiblesOcultosProvider = Provider<bool>(
  (ref) => ref.watch(montosOcultosProvider),
);

/// Texto que reemplaza a un dato sensible oculto.
const String textoSensibleOculto = '••••';

/// Etiqueta que oyen el lector de pantalla y las capturas.
const String etiquetaContenidoPrivado = 'Contenido privado';

/// Un texto sensible que se oculta solo (D13, regla 62 de la Fase 3).
///
/// Oculto muestra `••••` de ancho fijo y el lector de pantalla dice solo
/// "Contenido privado": ni el texto ni su longitud salen del widget. Con
/// [alTocar], una zona de 48 dp pide verlo (por omisión,
/// [revelarMontosProvider]: PIN o huella).
class TextoSensible extends ConsumerWidget {
  const TextoSensible(
    this.texto, {
    super.key,
    this.estilo,
    this.oculto = false,
    this.maxLineas,
    this.textAlign,
  });

  final String texto;
  final TextStyle? estilo;

  /// Pide ocultarlo aunque el provider lo deje ver.
  final bool oculto;
  final int? maxLineas;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ValoresDiseno.de(context);
    final ocultoAhora = oculto || ref.watch(sensiblesOcultosProvider);
    final style = estilo ?? v.lectura(color: v.textoFuerte);
    if (!ocultoAhora) {
      return Text(
        texto,
        style: style,
        maxLines: maxLineas,
        overflow: maxLineas == null ? null : TextOverflow.ellipsis,
        textAlign: textAlign,
      );
    }
    return Semantics(
      label: etiquetaContenidoPrivado,
      excludeSemantics: true,
      child: Text(
        textoSensibleOculto,
        style: style.copyWith(letterSpacing: 1.5),
        maxLines: 1,
        textAlign: textAlign,
      ),
    );
  }
}

/// Un bloque sensible (cualquier widget): oculto, se reemplaza por una tarjeta
/// sobria "Contenido privado" con el botón *Ver* de 48 dp.
class BloqueSensible extends ConsumerWidget {
  const BloqueSensible({super.key, required this.child, this.oculto = false});

  final Widget child;
  final bool oculto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!(oculto || ref.watch(sensiblesOcultosProvider))) return child;
    final v = ValoresDiseno.de(context);
    final privado = ref.watch(modoPrivadoProvider);
    return Semantics(
      container: true,
      label: etiquetaContenidoPrivado,
      hint: privado ? null : 'Toca Ver. Se pide tu PIN o tu huella',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: v.panel,
          border: Border.all(color: v.borde, width: v.grosorBorde),
          borderRadius: BorderRadius.circular(v.radioMediano),
        ),
        child: Padding(
          padding: EdgeInsets.all(v.espacio * 2),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            spacing: v.espacio,
            runSpacing: v.espacio,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline, size: 18, color: v.textoTenue),
                  SizedBox(width: v.espacio),
                  Flexible(
                    child: Text(
                      etiquetaContenidoPrivado,
                      style: v.lectura(
                        tamano: 14,
                        peso: FontWeight.w600,
                        color: v.textoFuerte,
                      ),
                    ),
                  ),
                ],
              ),
              if (!privado)
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: OutlinedButton(
                    onPressed: () => ref.read(revelarMontosProvider)(context),
                    child: const Text('Ver'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
