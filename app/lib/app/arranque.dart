/// Arranque: detecta el dispositivo, prepara Firebase (solo Android con
/// configuración), la sesión (Supabase o demostración), el almacenamiento
/// seguro, la huella y la base local. Devuelve los `overrides` de Riverpod.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../nucleo/base_local/base_local.dart';
import '../nucleo/cola/cola_sin_conexion.dart';
import '../nucleo/cola/enviador_supabase.dart';
import '../nucleo/cola/proveedores_cola.dart';
import '../nucleo/configuracion/configuracion_entorno.dart';
import '../nucleo/firebase/firebase.dart';
import '../nucleo/seguridad/almacen_seguro.dart';
import '../nucleo/seguridad/biometria.dart';
import '../nucleo/seguridad/proveedores_seguridad.dart';
import '../nucleo/sesion/proveedores_sesion.dart';
import '../nucleo/sesion/servicio_sesion_demostracion.dart';
import '../nucleo/sesion/servicio_sesion_supabase.dart';
import '../nucleo/sesion/sesion.dart';
import 'dispositivo.dart';

/// Tabla de Supabase por tipo de registro de la cola. Cada módulo agrega los
/// suyos en su fase (p. ej. `'finanzas.gasto': 'movimientos'`).
const Map<String, String> tablasDeLaCola = {};

Future<List<Override>> prepararArranque({
  ConfiguracionEntorno configuracion =
      const ConfiguracionEntorno.desdeCompilacion(),
}) async {
  final plataforma = defaultTargetPlatform;
  final dispositivo =
      tipoDispositivoForzado(configuracion.dispositivoForzado) ??
      detectarDesdeVista(PlatformDispatcher.instance.views.firstOrNull);

  Intl.defaultLocale = 'es_MX';
  await initializeDateFormatting('es_MX');

  final firebase = await prepararFirebase(plataforma: plataforma);
  final biometria = plataforma == TargetPlatform.android
      ? BiometriaDispositivo()
      : const BiometriaNoDisponible();

  AlmacenSeguro almacen = AlmacenSeguroDispositivo();
  ServicioSesion? sesion;
  Enviador enviador = const EnviadorSinServidor();
  if (configuracion.tieneSupabase) {
    try {
      await Supabase.initialize(
        url: configuracion.supabaseUrl,
        publishableKey: configuracion.supabaseLlavePublica,
      );
      final cliente = Supabase.instance.client;
      sesion = ServicioSesionSupabase(
        cliente: cliente,
        almacen: almacen,
        url: configuracion.supabaseUrl,
        llavePublica: configuracion.supabaseLlavePublica,
      );
      enviador = EnviadorSupabase(cliente, tablas: tablasDeLaCola);
    } catch (error) {
      debugPrint('No se pudo preparar Supabase; modo demostración: $error');
    }
  }
  if (sesion == null) {
    // Demostración: nada de lo de ejemplo se guarda en el dispositivo.
    almacen = AlmacenSeguroEnMemoria();
    sesion = ServicioSesionDemostracion();
  }
  await sesion.iniciar();

  return [
    tipoDispositivoProvider.overrideWithValue(dispositivo),
    estadoFirebaseProvider.overrideWithValue(firebase),
    almacenSeguroProvider.overrideWithValue(almacen),
    biometriaProvider.overrideWithValue(biometria),
    servicioSesionProvider.overrideWithValue(sesion),
    baseLocalProvider.overrideWithValue(BaseLocal.enDispositivo()),
    enviadorProvider.overrideWithValue(enviador),
  ];
}
