/// Campos opcionales del registro de un gasto para las fugas silenciosas
/// (Fase 8, bloque 6, `docs/specs/fase-8-fugas-y-deudas.md` 8.1 y 12.1): el
/// **comercio** y la casilla «Es un cargo automático».
///
/// Los dos son opcionales y **no añaden pasos**: el gasto se guarda igual con
/// ambos vacíos (el registro rápido de menos de 10 s no cambia). El comercio es
/// un dato del libro: jamás sale en un aviso, a la IA ni a las bocinas.
library;

import 'package:flutter/material.dart';

import '../../casos_uso/servicio_finanzas.dart' show comercioMaximo;

/// Texto de ayuda del campo (sin cifras ni nombres de comercios reales).
const ayudaComercio =
    'Opcional. Ayuda a reconocer cobros que se repiten; se queda en tu libro.';

class CampoComercio extends StatelessWidget {
  const CampoComercio({
    super.key,
    required this.controlador,
    this.llave = const ValueKey('gasto-comercio'),
  });

  final TextEditingController controlador;
  final Key llave;

  @override
  Widget build(BuildContext context) => TextField(
    key: llave,
    controller: controlador,
    maxLength: comercioMaximo,
    textCapitalization: TextCapitalization.words,
    decoration: const InputDecoration(
      labelText: 'Comercio (opcional)',
      helperText: ayudaComercio,
      helperMaxLines: 2,
    ),
  );
}

class CasillaCargoAutomatico extends StatelessWidget {
  const CasillaCargoAutomatico({
    super.key,
    required this.valor,
    required this.alCambiar,
    this.llave = const ValueKey('gasto-cargo-automatico'),
  });

  final bool valor;
  final ValueChanged<bool> alCambiar;
  final Key llave;

  @override
  Widget build(BuildContext context) => CheckboxListTile(
    key: llave,
    value: valor,
    onChanged: (v) => alCambiar(v ?? false),
    contentPadding: EdgeInsets.zero,
    controlAffinity: ListTileControlAffinity.leading,
    title: const Text('Es un cargo automático'),
    subtitle: const Text('Se cobra solo (domiciliado o a tarjeta).'),
  );
}
