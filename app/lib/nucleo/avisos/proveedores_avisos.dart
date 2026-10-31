/// Proveedores de los avisos (Fase 2, D20). El arranque fija los reales; por
/// omisión (pruebas, demostración) todo es en memoria y sin Firebase.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'fuente_push.dart';
import 'notificador.dart';
import 'recordatorios.dart';
import 'repositorio_avisos.dart';

final notificadorProvider = Provider<NotificadorLocal>(
  (ref) => NotificadorEnMemoria(),
);

final fuentePushProvider = Provider<FuentePush>((ref) => const FuentePushNula());

/// `null` sin servidor.
final repositorioAvisosProvider = Provider<RepositorioAvisos?>((ref) => null);

/// Finanzas lo sustituye con su copia local (vencimientos de los próximos 14
/// días).
final fuenteDeVencimientosProvider = Provider<FuenteDeVencimientos>(
  (ref) => const SinVencimientos(),
);

/// Detalle de un aviso dentro de la bandeja (con montos, ocultables). Lo
/// aporta Finanzas; sin él, la bandeja muestra solo el título del catálogo.
typedef ConstructorDetalleAviso = Widget Function(BuildContext context, Object aviso);

final detalleDeAvisoProvider = Provider<ConstructorDetalleAviso?>((ref) => null);
