/// Las pantallas reales de «Mi gimnasio» (G5): sustituyen a las maquetas de G4
/// que G3 dejó como provisionales.
///
/// El router de G3 (`rutasGimnasio`) pide cada pantalla a
/// `pantallaGimnasioProvider`; aquí se sobrescribe con las E1 a E10 reales. La
/// pantalla de molestias la envuelve siempre `ProtegerMolestias`
/// (FLAG_SECURE, modo privado y equipos que no las admiten).
library;

import 'package:flutter/material.dart';

import '../../../app/gimnasio/acceso_gimnasio.dart';
import 'pantallas/ajustes.dart';
import 'pantallas/historial.dart';
import 'pantallas/hoy_gimnasio.dart';
import 'pantallas/inventario.dart';
import 'pantallas/molestias.dart';
import 'pantallas/plan.dart';
import 'pantallas/registro.dart';
import 'pantallas/sesion_en_curso.dart';
import 'pantallas/sesion_hoy.dart';

export 'pantallas/hoy_gimnasio.dart' show TarjetaEntrenamientoHoyConectada;

/// La pantalla real de cada destino.
Widget pantallaDeGimnasio(DestinoGimnasio destino) => switch (destino) {
  DestinoGimnasio.hoy => const PantallaEntrenamientoHoy(),
  DestinoGimnasio.inventario => const PantallaInventario(),
  DestinoGimnasio.plan => const PantallaPlan(),
  DestinoGimnasio.sesion => const PantallaSesionDeHoy(),
  DestinoGimnasio.sesionEnCurso => const PantallaSesionEnCurso(),
  DestinoGimnasio.registro => const PantallaRegistro(),
  DestinoGimnasio.historial => const PantallaHistorial(),
  DestinoGimnasio.records => const PantallaRecords(),
  DestinoGimnasio.molestias => const PantallaMolestias(),
  DestinoGimnasio.ajustes => const PantallaAjustesGimnasio(),
};
