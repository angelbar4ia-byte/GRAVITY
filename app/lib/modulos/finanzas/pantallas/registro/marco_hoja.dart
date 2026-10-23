/// Marco común de las hojas del (+) (Gasto e Ingreso extra): título, contenido
/// que se desplaza y una **barra de acciones fija** al pie, siempre a la vista
/// (I8 de la revisión de la Fase 1).
///
/// - El contenido (teclado, categorías, cuentas…) se desplaza dentro del
///   espacio que queda; *Guardar* nunca queda fuera de la pantalla ni detrás
///   del teclado del sistema, ni en 360 × 800 dp ni con letra grande.
/// - La barra apila los botones (Guardar arriba, Cancelar abajo) cuando no
///   caben en una fila, por ejemplo con letra grande (I6): nunca se corta.
///
/// Sirve igual en la hoja inferior del teléfono y en el diálogo de Ctrl + N
/// de la laptop.
library;

import 'package:flutter/material.dart';

import '../../../../diseno/diseno.dart';
import '../../../../nucleo/contratos/roles.dart';

class MarcoHojaRegistro extends StatelessWidget {
  const MarcoHojaRegistro({
    super.key,
    required this.titulo,
    required this.cuerpo,
    this.barra,
    this.tituloDerecha,
  });

  final String titulo;

  /// Lo que va a la derecha del título (el monto que se teclea): comparte la
  /// línea con el título si caben y, si no, pasa a la siguiente. Ahorra una
  /// fila entera de la hoja (I8).
  final Widget? tituloDerecha;

  /// Lo que se desplaza: formulario o mensaje de estado.
  final Widget cuerpo;

  /// Acciones fijas al pie (normalmente una [BarraAccionesRegistro]).
  final Widget? barra;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final teclado = MediaQuery.viewInsetsOf(context).bottom;
    return TemaModulo(
      modulo: Modulo.finanzas,
      child: Builder(
        builder: (context) => Padding(
          // Con el teclado del sistema abierto, la barra queda encima.
          padding: EdgeInsets.only(bottom: teclado),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            Text(titulo, style: tema.textTheme.titleLarge),
                            ?tituloDerecha,
                          ],
                        ),
                        const SizedBox(height: 8),
                        cuerpo,
                      ],
                    ),
                  ),
                ),
                if (barra != null) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: barra,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Cancelar y Guardar al pie: en una fila si caben y, si no (letra grande o
/// pantalla angosta), **apilados con Guardar arriba**; nunca se cortan (I6).
///
/// Es un `Wrap` que crece hacia arriba: la primera línea (Cancelar) queda
/// abajo y Guardar sube a la línea de encima cuando no caben juntos.
class BarraAccionesRegistro extends StatelessWidget {
  const BarraAccionesRegistro({
    super.key,
    required this.llaveGuardar,
    required this.alGuardar,
    this.textoGuardar = 'Guardar',
  });

  /// Llave del botón principal (las pruebas lo buscan).
  final Key llaveGuardar;

  /// `null` mientras falta algo (el botón queda inactivo).
  final VoidCallback? alGuardar;
  final String textoGuardar;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: Wrap(
      alignment: WrapAlignment.end,
      runAlignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      verticalDirection: VerticalDirection.up,
      spacing: 8,
      runSpacing: 4,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          key: llaveGuardar,
          onPressed: alGuardar,
          icon: const Icon(Icons.check),
          label: Text(textoGuardar),
        ),
      ],
    ),
  );
}
