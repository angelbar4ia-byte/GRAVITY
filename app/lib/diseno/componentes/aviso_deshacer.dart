import 'package:flutter/material.dart';

/// Aviso breve con **Deshacer** del Registro rápido (+) (flujo F1): "Guardado ·
/// Deshacer". Reemplaza al aviso anterior, si había uno, y se va solo después
/// de [duracion] aunque tenga acción.
///
/// Deshacer **no borra** nada: quien lo usa decide qué hace (en Finanzas, una
/// anulación con motivo "Deshecho al capturar"). Toma los colores del tema
/// (`snackBarTheme`), nunca colores fijos.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> mostrarAvisoDeshacer(
  BuildContext context, {
  required String mensaje,
  required VoidCallback alDeshacer,
  String textoAccion = 'Deshacer',
  Duration duracion = const Duration(seconds: 6),
}) {
  final mensajero = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
  return mensajero.showSnackBar(
    SnackBar(
      content: Text(mensaje),
      duration: duracion,
      persist: false,
      action: SnackBarAction(label: textoAccion, onPressed: alDeshacer),
    ),
  );
}
