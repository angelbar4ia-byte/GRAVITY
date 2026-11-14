/// Dónde se guardan los comprobantes de los recibos (Fase 8, bloque 4). Por
/// omisión, en memoria; plataforma lo reemplaza con los archivos privados del
/// teléfono. La foto no sube a ninguna nube (D3).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../casos_uso/gasto_desde_recibo.dart';

final comprobanteLocalProvider = Provider<ComprobanteLocal>(
  (ref) => ComprobanteLocalEnMemoria(),
);
