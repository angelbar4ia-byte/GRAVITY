/// Arranque: detecta el dispositivo, prepara Firebase (solo Android con
/// configuración), la sesión (Supabase o demostración), el almacenamiento
/// seguro, la huella y la base local. Devuelve los `overrides` de Riverpod.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../diseno/licencias.dart';
import '../diseno/proveedores.dart'
    show
        densidadBaseProvider,
        montosVisiblesProvider,
        personaEnPantallaProvider,
        revelarMontosProvider;
import '../diseno/valores_diseno.dart' show densidadPara;

import '../nucleo/base_local/base_local.dart';
import '../nucleo/cola/bandeja_salida.dart';
import '../nucleo/cola/cola_sin_conexion.dart';
import '../nucleo/cola/enviador_supabase.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../nucleo/avisos/fuente_push.dart';
import '../nucleo/avisos/notificador_plugin.dart';
import '../nucleo/avisos/proveedores_avisos.dart';
import '../nucleo/avisos/push_segundo_plano.dart';
import '../nucleo/avisos/repositorio_avisos.dart';
import '../nucleo/cola/proveedores_cola.dart';
import '../nucleo/configuracion/configuracion_entorno.dart';
import '../nucleo/firebase/firebase.dart';
import '../nucleo/invitaciones/invitaciones.dart';
import '../nucleo/seguridad/almacen_seguro.dart';
import '../nucleo/sensibles/subida_diferida.dart' show funcionSubirSobres, tipoColaSobres;
import '../nucleo/seguridad/biometria.dart';
import '../nucleo/seguridad/limpieza_local.dart';
import '../nucleo/seguridad/pantalla_segura.dart';
import '../nucleo/seguridad/proveedores_seguridad.dart';
import '../nucleo/sesion/proveedores_sesion.dart';
import '../nucleo/sesion/servicio_sesion_demostracion.dart';
import '../nucleo/sesion/servicio_sesion_supabase.dart';
import '../nucleo/sesion/sesion.dart';
import 'avisos/con_avisos.dart' show tipoEquipoAvisosProvider;
import 'dispositivo.dart';
import '../nucleo/sensibles/nube_habitos.dart';
import 'sensibles/sensibles.dart';
import '../nucleo/tablet/controlador_tablet.dart' show alEntrarConPinProvider, alSalirDeLaTabletProvider;
import 'montos/montos_al_entrar.dart';
import 'montos/revelar_montos.dart';
import 'pantallas_externas.dart'
    show sobrescriturasAvisosFinanzas, tablasColaFinanzas;
import 'sesion_efectiva.dart';

/// Conexiones entre áreas que la app hace siempre (en el arranque y en las
/// pruebas que montan la app completa).
List<Override> conexionesDeLaApp() => [
  // Finanzas alimenta los recordatorios de vencimiento y el detalle de cada
  // aviso de la bandeja (Fase 2).
  ...sobrescriturasAvisosFinanzas,
  // Al cambiar la persona frente a la pantalla (sesión o PIN en la tablet),
  // diseno vuelve a ocultar los montos y quita el modo privado (M8).
  personaEnPantallaProvider.overrideWith(
    (ref) => ref.watch(sesionEfectivaProvider)?.persona.id,
  ),
  // Los montos se ocultan solos y para verlos se pide el PIN (o la huella en
  // el teléfono), decisión del 23/oct/2026.
  revelarMontosProvider.overrideWith((ref) => revelarMontos),
  // En la tablet, entrar con el PIN cuenta como haber pedido ver los montos
  // (23/oct/2026): se abren a la vista; las reglas de ocultar por inactividad
  // siguen.
  montosVisiblesProvider.overrideWith(MontosVisiblesAlEntrar.new),
  // Bandeja de salida (D14, 23/oct/2026): la tablet mueve la credencial de
  // quien sale con algo por subir a su permiso de subida.
  // Tablet personal (D21): al entrar con el PIN se abren las llaves de
  // Hábitos; al salir se olvidan. En el teléfono y la laptop no hacen nada.
  alEntrarConPinProvider.overrideWith(
    (ref) => (persona, pin) async {
      if (!llavesVanConPin(ref.read(tipoEquipoAvisosProvider))) return;
      await ref.read(llavesHabitosProvider).liberarConPin(persona, pin);
    },
  ),
  alSalirDeLaTabletProvider.overrideWith(
    (ref) => (persona) => ref.read(llavesHabitosProvider).olvidarEnMemoria(),
  ),
  bandejaDeLaTabletProvider.overrideWith(
    (ref) => BandejaDeLaTabletConCola(
      ref.watch(bandejaDeSalidaProvider),
      () => ref.read(colaSinConexionProvider),
    ),
  ),
];

/// Tabla de Supabase por tipo de registro de la cola. Cada módulo agrega los
/// suyos en su fase (`pantallas_externas.dart`); la cola sube cada registro
/// con la sesión de quien lo registró (en la tablet, la de quien entró con
/// su PIN).
const Map<String, String> tablasDeLaCola = {...tablasColaFinanzas};

Future<List<Override>> prepararArranque({
  ConfiguracionEntorno configuracion =
      const ConfiguracionEntorno.desdeCompilacion(),
  BaseLocal Function() abrirBase = BaseLocal.enDispositivo,
}) async {
  final plataforma = defaultTargetPlatform;
  final dispositivo =
      tipoDispositivoForzado(configuracion.dispositivoForzado) ??
      detectarDesdeVista(PlatformDispatcher.instance.views.firstOrNull);

  Intl.defaultLocale = 'es_MX';
  registrarLicenciasFuentes();
  await initializeDateFormatting('es_MX');

  final firebase = await prepararFirebase(plataforma: plataforma);
  if (firebase == EstadoFirebase.activo) {
    // Mensajes con la app cerrada: solo el aviso genérico (ver el archivo).
    FirebaseMessaging.onBackgroundMessage(manejadorPushSegundoPlano);
  }
  final biometria = plataforma == TargetPlatform.android
      ? BiometriaDispositivo()
      : const BiometriaNoDisponible();

  AlmacenSeguro almacen = AlmacenSeguroDispositivo();
  // Lo guardado en el equipo por persona se borra al salir, en una baja y al
  // quitarla de la tablet (M5); el servicio de sesión y la tablet comparten
  // la misma instancia, donde los módulos registran sus ganchos.
  var limpieza = LimpiezaLocal(almacen);
  ServicioSesion? sesion;
  Enviador enviador = const EnviadorSinServidor();
  RepositorioInvitaciones? invitaciones;
  Override? salidaSinPin;
  RepositorioAvisos? avisos;
  if (configuracion.tieneSupabase) {
    try {
      await Supabase.initialize(
        url: configuracion.supabaseUrl,
        publishableKey: configuracion.supabaseLlavePublica,
      );
      final servicio = ServicioSesionSupabase(
        cliente: Supabase.instance.client,
        almacen: almacen,
        url: configuracion.supabaseUrl,
        llavePublica: configuracion.supabaseLlavePublica,
        limpieza: limpieza,
      );
      sesion = servicio;
      // Avisos (Fase 2, D20): se leen con la sesión de quien está dentro.
      avisos = RepositorioAvisosSupabase(() => servicio.clienteActivo);
      // Invitaciones (cuenta maestra): con la sesión de quien está dentro.
      invitaciones = RepositorioInvitacionesSupabase(
        () => servicio.clienteActivo,
      );
      // Bandeja de salida (D14, 23/oct): lo de quien ya salió de la tablet
      // sube con su propio token, en una sesión aparte, sin pedir su PIN.
      salidaSinPin = salidaSinPinProvider.overrideWith(
        (ref) => SalidaSinPinConSesiones(
          bandeja: ref.watch(bandejaDeSalidaProvider),
          abrir: servicio.abrirSesionAparte,
          enviadorDe: (aparte) => EnviadorSupabase(
            (aparte as SesionAparteSupabase).cliente,
            tablas: tablasDeLaCola,
          ),
        ),
      );
      // En la tablet, la cola envía con la sesión de quien entró con su PIN.
      enviador = EnviadorSupabase.dinamico(
        () => servicio.clienteActivo,
        tablas: tablasDeLaCola,
        // Hábitos (Fase 3): sobres ya cifrados, por la función del servidor.
        funciones: const {tipoColaSobres: funcionSubirSobres},
      );
    } catch (error) {
      debugPrint('No se pudo preparar Supabase; modo demostración: $error');
    }
  }
  if (sesion == null) {
    // Demostración: nada de lo de ejemplo se guarda en el dispositivo.
    almacen = AlmacenSeguroEnMemoria();
    limpieza = LimpiezaLocal(almacen);
    sesion = ServicioSesionDemostracion();
  }
  await sesion.iniciar();

  return [
    ...conexionesDeLaApp(),
    tipoDispositivoProvider.overrideWithValue(dispositivo),
    densidadBaseProvider.overrideWithValue(densidadPara(dispositivo)),
    estadoFirebaseProvider.overrideWithValue(firebase),
    almacenSeguroProvider.overrideWithValue(almacen),
    limpiezaLocalProvider.overrideWithValue(limpieza),
    // Una sola bandeja de salida (un solo candado por persona) para la subida
    // sin PIN, la tablet y el cierre de sesión de la cuenta del equipo.
    bandejaDeSalidaProvider.overrideWithValue(limpieza.bandeja),
    // I11: en Android, FLAG_SECURE mientras hay dinero o datos clínicos a la
    // vista; en Windows no hace falta nada.
    protectorDePantallaProvider.overrideWithValue(
      plataforma == TargetPlatform.android
          ? const ProtectorDePantallaAndroid()
          : const ProtectorDePantallaNulo(),
    ),
    biometriaProvider.overrideWithValue(biometria),
    servicioSesionProvider.overrideWithValue(sesion),
    // Demostración: la cola vive en memoria; nada de lo de ejemplo queda en
    // el dispositivo ni se sube después (M16).
    baseLocalProvider.overrideWithValue(
      sesion.esDemostracion ? BaseLocal.enMemoria() : abrirBase(),
    ),
    enviadorProvider.overrideWithValue(enviador),
    if (invitaciones != null)
      repositorioInvitacionesProvider.overrideWithValue(invitaciones),
    ?salidaSinPin,
    // Avisos (Fase 2, D20): notificaciones del sistema en Android (teléfono y
    // tablets) y Windows (laptop, con la app abierta) y push solo en Android
    // con Firebase configurado. Sin servidor, todo queda en memoria.
    if (avisos != null) ...[
      repositorioAvisosProvider.overrideWithValue(avisos),
      if (plataforma == TargetPlatform.android ||
          plataforma == TargetPlatform.windows)
        notificadorProvider.overrideWithValue(NotificadorPlugin()),
      nubeDeHabitosProvider.overrideWithValue(
        NubeDeHabitosSupabase(() => (sesion! as ServicioSesionSupabase).clienteActivo),
      ),
      if (firebase == EstadoFirebase.activo)
        fuentePushProvider.overrideWithValue(FuentePushFirebase()),
    ],
  ];
}
