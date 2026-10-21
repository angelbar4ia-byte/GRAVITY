/// Registro rápido: abre la hoja de cada opción del botón (+) (teléfono y
/// tablet) y la de Ctrl + N en la laptop. Las hojas las construye cada
/// módulo (`pantallas_externas.dart`); aquí solo se decide cómo se muestran.
library;

import 'package:flutter/material.dart';

import '../navegacion.dart';
import '../pantallas_externas.dart';

/// Llave del contenido de cada registro (para encontrarlo en las pruebas sin
/// depender de lo que dibuje el módulo).
ValueKey<String> llaveRegistro(TipoRegistro tipo) =>
    ValueKey('registro-${tipo.name}');

/// Contenido del registro [tipo], o `null` si aún no llega (su fase).
Widget? contenidoDeRegistro(TipoRegistro tipo) => switch (tipo) {
  TipoRegistro.gasto => hojaRegistrarGasto(),
  TipoRegistro.ingresoExtra => hojaIngresoExtra(),
  TipoRegistro.habito || TipoRegistro.consumo || TipoRegistro.sos => null,
};

/// `true` si el registro [tipo] ya se puede abrir.
bool registroDisponible(TipoRegistro tipo) => contenidoDeRegistro(tipo) != null;

/// Abre el registro de [opcion] en una hoja inferior (teléfono y tablet). Si
/// aún no llega, avisa en qué fase.
Future<void> abrirRegistro(BuildContext context, OpcionRegistrar opcion) {
  final contenido = contenidoDeRegistro(opcion.tipo);
  if (contenido == null) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text('${opcion.etiqueta}: llega en la Fase ${opcion.fase}.'),
      ),
    );
    return Future.value();
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (contexto) =>
        KeyedSubtree(key: llaveRegistro(opcion.tipo), child: contenido),
  );
}

/// Ctrl + N en la laptop: registrar un movimiento de Finanzas en un diálogo.
Future<void> abrirRegistroEnDialogo(
  BuildContext context, {
  TipoRegistro tipo = TipoRegistro.gasto,
}) {
  final contenido = contenidoDeRegistro(tipo);
  if (contenido == null) return Future.value();
  return showDialog<void>(
    context: context,
    builder: (contexto) => Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Material(
          type: MaterialType.transparency,
          child: KeyedSubtree(key: llaveRegistro(tipo), child: contenido),
        ),
      ),
    ),
  );
}
