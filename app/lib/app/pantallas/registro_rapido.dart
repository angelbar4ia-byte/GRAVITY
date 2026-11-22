/// Registro rápido: abre la hoja de cada opción del botón (+) (teléfono y
/// tablet) y la de Ctrl + N en la laptop. Las hojas las construye cada
/// módulo (`pantallas_externas.dart`); aquí solo se decide cómo se muestran.
library;

import 'package:flutter/material.dart';

import '../navegacion.dart';
import '../pantalla_segura.dart';
import '../pantallas_externas.dart';

/// Llave del contenido de cada registro (para encontrarlo en las pruebas sin
/// depender de lo que dibuje el módulo).
ValueKey<String> llaveRegistro(TipoRegistro tipo) =>
    ValueKey('registro-${tipo.name}');

/// Contenido del registro [tipo] (cada módulo pone el suyo).
Widget contenidoDeRegistro(TipoRegistro tipo) => switch (tipo) {
  TipoRegistro.gasto => hojaRegistrarGasto(),
  TipoRegistro.ingresoExtra => hojaIngresoExtra(),
  TipoRegistro.habito => hojaHabito(),
  TipoRegistro.consumo => hojaConsumo(),
  TipoRegistro.sos => hojaSos(),
};

/// Abre el registro de [opcion] en una hoja inferior (teléfono y tablet).
Future<void> abrirRegistro(BuildContext context, OpcionRegistrar opcion) {
  final contenido = contenidoDeRegistro(opcion.tipo);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    // Un registro (gasto, ingreso…) es personal: la hoja no se puede capturar
    // (I11).
    builder: (contexto) => PantallaSegura(
      activa: true,
      child: KeyedSubtree(key: llaveRegistro(opcion.tipo), child: contenido),
    ),
  );
}

/// Ctrl + N en la laptop: registrar en un diálogo (por omisión un gasto; la
/// barra de órdenes también abre hábito, consumo y SOS).
Future<void> abrirRegistroEnDialogo(
  BuildContext context, {
  TipoRegistro tipo = TipoRegistro.gasto,
}) {
  final contenido = contenidoDeRegistro(tipo);
  return showDialog<void>(
    context: context,
    builder: (contexto) => Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Material(
          type: MaterialType.transparency,
          child: PantallaSegura(
            activa: true,
            child: KeyedSubtree(key: llaveRegistro(tipo), child: contenido),
          ),
        ),
      ),
    ),
  );
}
