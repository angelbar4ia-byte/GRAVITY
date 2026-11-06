import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../proveedores.dart';
import '../tema.dart';
import '../valores_diseno.dart';

/// Marca "Montos ocultos · Toca para ver": avisa que las cifras de la pantalla
/// están ocultas y es la forma de pedir verlas (PIN o huella, según el
/// dispositivo: [revelarMontosProvider]).
///
/// No dibuja nada si los montos están a la vista ([montosOcultosProvider]).
/// Con el modo privado activo dice "Montos ocultos · modo privado" y no se toca
/// (para verlos se quita el modo privado). Zona táctil de 48 dp o más, con
/// texto además del icono, y el lector de pantalla dice qué es y qué pasa al
/// tocarla. Ponla junto a los montos, en el encabezado de la pantalla o de la
/// tarjeta.
class MarcaMontosOcultos extends ConsumerWidget {
  const MarcaMontosOcultos({super.key, this.alTocar});

  /// Qué hacer al tocarla; por omisión, pedir ver los montos
  /// ([revelarMontosProvider]).
  final VoidCallback? alTocar;

  /// Texto de la marca con los montos ocultos por falta de uso.
  static const texto = 'Montos ocultos · Toca para ver';

  /// Texto de la marca en modo privado.
  static const textoPrivado = 'Montos ocultos · modo privado';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(montosOcultosProvider)) return const SizedBox.shrink();
    final privado = ref.watch(modoPrivadoProvider);
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    final forma = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(v.radioGrande * 2),
      side: BorderSide(color: v.borde, width: v.grosorBorde),
    );
    final mostrado = privado ? textoPrivado : texto;
    final accion = privado
        ? null
        : (alTocar ?? () => ref.read(revelarMontosProvider)(context));
    final contenido = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: zonaTactilMinima),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: e * 1.75, vertical: e * 0.5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.visibility_off_outlined, size: 18, color: v.textoFuerte),
            SizedBox(width: e),
            Flexible(
              child: Text(
                mostrado,
                style: v.lectura(
                  tamano: 13,
                  peso: FontWeight.w500,
                  color: v.textoFuerte,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
    return Semantics(
      container: true,
      button: accion != null,
      label: privado ? 'Montos ocultos por el modo privado' : 'Montos ocultos',
      hint: privado ? null : 'Toca para ver. Se pide tu PIN o tu huella',
      excludeSemantics: true,
      onTap: accion,
      child: Material(
        key: const ValueKey('marca-montos-ocultos'),
        color: v.panel,
        shape: forma,
        clipBehavior: Clip.antiAlias,
        child: accion == null
            ? contenido
            : InkWell(onTap: accion, customBorder: forma, child: contenido),
      ),
    );
  }
}
