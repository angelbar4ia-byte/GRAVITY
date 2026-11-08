/// Módulo **Finanzas** de GRAVITY (agente finanzas, Fase 1).
///
/// Lo que la plataforma conecta en `app/lib/app/pantallas_externas.dart`:
///
/// - [rutasFinanzas]: rutas **relativas** a `/finanzas`. La raíz
///   (`GoRoute(path: '/')`) es el Tablero en la laptop y la Semana resumida en
///   el teléfono y la tablet; las demás secciones van como segmentos
///   (`'semana'`, `'movimientos'`, …). Las que cambian la configuración
///   (asistente de arranque, importar y ajustes) llevan
///   `metadata: exigeAccion(Accion.administrar)`. Las secciones de la laptop
///   (D4) regresan al inicio del módulo en el teléfono.
/// - [hojaRegistrarGasto] y [hojaIngresoExtra]: las hojas del (+) (flujo F1).
/// - [tablasColaFinanzas]: tabla de Supabase de cada tipo de registro de la
///   cola sin conexión (solo los libros "solo agregar").
/// - [refrescarFinanzas]: vuelve a pedir lo de Finanzas tras una baja del
///   hogar o un cambio de rol (el servidor puede cambiar el administrador y la
///   visibilidad de los compartidos).
/// - [limpiarCopiaLocalFinanzas]: borra del equipo la copia local de una
///   persona (salir, baja y quitarla de la tablet).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:go_router/go_router.dart';

import '../../app/dispositivo.dart' show tipoDispositivoProvider;
import '../../nucleo/contratos/dispositivo.dart';
import '../../nucleo/contratos/roles.dart';
import '../../nucleo/contratos/rutas.dart';
import '../../nucleo/permisos/permisos.dart';
import '../../nucleo/seguridad/almacen_seguro.dart';
import 'datos/repositorio_supabase.dart'
    as supabase
    show CopiaLocalFinanzas, tablasDeLaColaFinanzas;
import 'estado/proveedores_fase2.dart'
    as fase2
    show consultaLocalFinanzasProvider, sobrescriturasAvisosFinanzas;
import 'pantallas/laptop/ajustes.dart';
import 'pantallas/laptop/arranque.dart';
import 'pantallas/laptop/categorias.dart';
import 'pantallas/laptop/compromisos.dart';
import 'pantallas/laptop/cuentas.dart';
import 'pantallas/laptop/fase2.dart';
import 'pantallas/laptop/importar.dart';
import 'pantallas/laptop/ingresos.dart';
import 'pantallas/laptop/marco_laptop.dart';
import 'pantallas/laptop/movimientos.dart';
import 'pantallas/laptop/semana.dart';
import 'pantallas/laptop/tablero.dart';
import 'pantallas/registro/hoja_gasto.dart';
import 'pantallas/registro/hoja_ingreso_extra.dart';
import 'pantallas/telefono/fase2_telefono.dart';
import 'pantallas/telefono/pantallas_telefono.dart';
import 'pantallas/transferencias/aportacion_casa.dart';
import 'pantallas/transferencias/transferencias.dart';
import 'pantallas/vista_papa/pedir_vista_papa.dart';

export 'datos/repositorio_supabase.dart' show TiposCola;
export 'estado/proveedores.dart' show refrescarFinanzas;
export 'estado/resumen_hoy.dart'
    show
        CifrasSemana,
        EstadoResumenHoy,
        ResumenFinanzasHoy,
        ResumenLibroHoy,
        cifrasMiSemanaProvider,
        resumenFinanzasHoyProvider;
export 'pantallas/ajustes_avisos.dart' show SeccionAvisosFinanzas;
export 'pantallas/tarjeta_hoy.dart' show TarjetaFinanzasHoy;
export 'pantallas/vista_papa/pedir_vista_papa.dart' show PantallaPedirVistaPapa;
export 'pantallas/vista_papa/tarjeta_vista_papa_dueno.dart'
    show TarjetaVistaPapaDueno, textosVistaPapa;
export 'pantallas/laptop/marco_laptop.dart' show SeccionFinanzas;

/// Tabla de Supabase de cada tipo de registro de la cola sin conexión
/// (`'finanzas.movimiento': 'fin_movimientos'`, conciliaciones e
/// importaciones). La cola sube con `INSERT … ON CONFLICT (id) DO NOTHING`.
const Map<String, String> tablasColaFinanzas = supabase.tablasDeLaColaFinanzas;

/// Lo que Finanzas pone en los avisos de la plataforma (Fase 2, D20): la
/// fuente de vencimientos de los recordatorios locales (pagos de deudas de los
/// próximos 14 días con la copia local) y el detalle de cada aviso en la
/// bandeja (montos ocultables). El arranque suma esta lista a los `overrides`
/// de Riverpod.
List<Override> get sobrescriturasAvisosFinanzas =>
    fase2.sobrescriturasAvisosFinanzas;

/// Consultas locales de las herramientas `finanzas.resumen_semana`,
/// `finanzas.proximos_pagos` y `finanzas.ahorro_avance`: texto discreto que no
/// sale del equipo (D3). La barra de órdenes lo lee para
/// `ContextoHerramienta.consultaLocal`.
final consultaLocalFinanzasProvider = fase2.consultaLocalFinanzasProvider;

/// Borra del equipo lo que Finanzas guardó de [personaId] (la copia local para
/// trabajar sin señal: libros, cuentas, categorías, sobres, nombres). Lo llama
/// la limpieza de plataforma al **salir**, al detectar una **baja** y al
/// **quitar a la persona de la tablet** (M5 de la revisión de la Fase 1; D5).
/// Nunca lanza. [almacen] es el almacén seguro del equipo (por omisión, el del
/// dispositivo).
Future<void> limpiarCopiaLocalFinanzas(
  String personaId, {
  AlmacenSeguro? almacen,
}) => supabase.CopiaLocalFinanzas.borrarDe(
  almacen ?? AlmacenSeguroDispositivo(),
  personaId,
);

/// Registro rápido de un gasto (F1): teclado ya abierto → categoría →
/// cuenta → Guardar → *"Guardado · Deshacer"*.
Widget hojaRegistrarGasto() => const HojaRegistrarGasto();

/// Registro de un ingreso extra: monto → cuenta → fecha → Guardar.
Widget hojaIngresoExtra() => const HojaIngresoExtra();

/// `true` si [dispositivo] lleva Finanzas completo (D4: la laptop).
bool esFinanzasCompleto(TipoDispositivo dispositivo) =>
    dispositivo == TipoDispositivo.laptop;

/// Rutas de Finanzas, relativas a `Rutas.finanzas` (ver arriba).
List<RouteBase> rutasFinanzas() => [
  GoRoute(
    path: '/',
    pageBuilder: _pagina(
      (_) => const _SegunDispositivo(
        laptop: PantallaTablero(),
        telefono: PantallaSemanaTelefono(),
      ),
    ),
  ),
  GoRoute(
    path: SeccionFinanzas.semana.segmento,
    pageBuilder: _pagina(
      (_) => const _SegunDispositivo(
        laptop: PantallaSemana(),
        telefono: PantallaSemanaTelefono(),
      ),
    ),
  ),
  GoRoute(
    path: SeccionFinanzas.movimientos.segmento,
    pageBuilder: _pagina(
      (_) => const _SegunDispositivo(
        laptop: PantallaMovimientos(),
        telefono: PantallaMovimientosTelefono(),
      ),
    ),
  ),
  _soloLaptop(SeccionFinanzas.cuentas, (_) => const PantallaCuentas()),
  _soloLaptop(SeccionFinanzas.ingresos, (_) => const PantallaIngresos()),
  _soloLaptop(SeccionFinanzas.categorias, (_) => const PantallaCategorias()),
  _soloLaptop(SeccionFinanzas.compromisos, (_) => const PantallaCompromisos()),
  GoRoute(
    path: SeccionFinanzas.deudas.segmento,
    pageBuilder: _pagina(
      (_) => const _SegunDispositivo(
        laptop: PantallaDeudas(),
        telefono: PantallaDeudasTelefono(),
      ),
    ),
  ),
  _soloLaptop(SeccionFinanzas.patrimonio, (_) => const PantallaPatrimonio()),
  _soloLaptop(SeccionFinanzas.simulador, (_) => const PantallaSimulador()),
  _soloLaptop(SeccionFinanzas.tarjetas, (_) => const PantallaTarjetas()),
  GoRoute(
    path: SeccionFinanzas.ahorro.segmento,
    pageBuilder: _pagina(
      (_) => const _SegunDispositivo(
        laptop: PantallaAhorro(),
        telefono: PantallaAhorroTelefono(),
      ),
    ),
  ),
  GoRoute(
    path: SeccionFinanzas.vencimientos.segmento,
    pageBuilder: _pagina(
      (_) => const _SegunDispositivo(
        laptop: PantallaVencimientos(),
        telefono: PantallaVencimientosTelefono(),
      ),
    ),
  ),
  GoRoute(
    path: SeccionFinanzas.transferencias.segmento,
    pageBuilder: _pagina((_) => const PantallaTransferencias()),
  ),
  GoRoute(
    path: SeccionFinanzas.aportacion.segmento,
    pageBuilder: _pagina((_) => const PantallaAportacionCasa()),
  ),
  // D24: el familiar pide ver las finanzas de Papá (vista temporal de 30 min).
  GoRoute(
    path: 'vista-papa',
    pageBuilder: _pagina((_) => const PantallaPedirVistaPapa()),
  ),
  _soloLaptop(SeccionFinanzas.arranque, (_) => const PantallaArranque()),
  _soloLaptop(SeccionFinanzas.importar, (_) => const PantallaImportar()),
  _soloLaptop(SeccionFinanzas.ajustes, (_) => const PantallaAjustesFinanzas()),
];

/// Página sin animación (cambiar de sección es cambiar de pestaña).
Page<void> Function(BuildContext, GoRouterState) _pagina(
  WidgetBuilder pantalla,
) =>
    (context, estado) =>
        NoTransitionPage<void>(key: estado.pageKey, child: pantalla(context));

/// Sección que solo existe en la laptop (D4). En el teléfono y la tablet
/// regresa al inicio del módulo. Las de configuración exigen administrar.
GoRoute _soloLaptop(SeccionFinanzas seccion, WidgetBuilder pantalla) => GoRoute(
  path: seccion.segmento,
  metadata: seccion.esDeConfiguracion ? exigeAccion(Accion.administrar) : null,
  redirect: (context, estado) {
    final dispositivo = ProviderScope.containerOf(
      context,
      listen: false,
    ).read(tipoDispositivoProvider);
    return esFinanzasCompleto(dispositivo) ? null : Rutas.finanzas;
  },
  pageBuilder: _pagina(pantalla),
);

/// La pantalla de la laptop o la del teléfono (y la tablet).
class _SegunDispositivo extends ConsumerWidget {
  const _SegunDispositivo({required this.laptop, required this.telefono});

  final Widget laptop;
  final Widget telefono;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      esFinanzasCompleto(ref.watch(tipoDispositivoProvider))
      ? laptop
      : telefono;
}
