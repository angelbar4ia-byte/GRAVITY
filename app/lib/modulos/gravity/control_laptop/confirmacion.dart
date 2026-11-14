/// Diálogo de confirmación en pantalla (D8) para las acciones que escriben:
/// enviar un correo y crear un evento. Se pasa como [Confirmador] a
/// `ControlLaptop`.
library;

import 'package:flutter/material.dart';

import 'acciones.dart';
import 'control_laptop.dart';

String _dos(int n) => n.toString().padLeft(2, '0');
String _fechaHora(DateTime d) =>
    '${d.day}/${d.month}/${d.year} ${_dos(d.hour)}:${_dos(d.minute)}';

/// Título, líneas y texto del botón de la confirmación de [accion].
({String titulo, List<String> lineas, String boton}) textoConfirmacion(
  Accion accion,
) => switch (accion) {
  GmailEnviar() => (
    titulo: '¿Enviar este correo?',
    lineas: const ['Se enviará el borrador desde tu Gmail.'],
    boton: 'Enviar',
  ),
  CalendarCrear(:final titulo, :final inicio, :final fin) => (
    titulo: '¿Crear este evento?',
    lineas: [titulo, '${_fechaHora(inicio)} a ${_fechaHora(fin)}'],
    boton: 'Crear evento',
  ),
  _ => (
    titulo: '¿Confirmas esta acción?',
    lineas: const <String>[],
    boton: 'Confirmar',
  ),
};

/// Pregunta en pantalla. `true` solo si la persona pulsó el botón de
/// confirmar; cancelar, cerrar o tocar fuera devuelve `false`.
Future<bool> mostrarConfirmacion(BuildContext context, Accion accion) async {
  final t = textoConfirmacion(accion);
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(t.titulo),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [for (final l in t.lineas) Text(l)],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(c).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(c).pop(true),
          child: Text(t.boton),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// [Confirmador] que usa el contexto vigente en el momento de preguntar.
Confirmador confirmadorConDialogo(BuildContext Function() contexto) =>
    (accion) => mostrarConfirmacion(contexto(), accion);
