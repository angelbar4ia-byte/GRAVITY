/// Módulo **Hábitos** de GRAVITY (agente habitos, Fase 3).
///
/// Lo que la plataforma conecta en `app/lib/app/pantallas_externas.dart`:
///
/// - [rutasHabitos]: rutas **relativas** a `/habitos` (raíz = Hoy; `objetivos`,
///   `sos`, `reservado` y `eliminar/:tipo`; las tres últimas reservadas).
/// - [hojaPausa], [hojaHabito] y [hojaConsumo]: las tres opciones del (+)
///   (SOS, hábito del día y consumo) en una hoja.
/// - [servicioHabitosProvider], [hoyHabitosProvider] y
///   [repositorioHabitosProvider]: estado.
/// - [consultaLocalHabitos]: texto discreto para `habitos.resumen_hoy`
///   (nunca incluye hábitos sensibles ni sale del equipo, D3/D13).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:go_router/go_router.dart';

import 'estado/proveedores.dart';
import '../../app/sensibles/sensibles.dart' show fuenteDeDatosHabitosProvider;
import '../../nucleo/avisos/proveedores_avisos.dart'
    show fuenteDeRecordatoriosHabitosProvider;
import 'casos_uso/servicio_eliminar.dart';
import 'datos/fuentes_plataforma.dart';
import 'pantallas/agenda.dart';
import 'pantallas/asistente.dart';
import 'pantallas/eliminar.dart';
import 'pantallas/espiritual.dart';
import 'pantallas/hoja_registro.dart';
import 'pantallas/hoy.dart';
import 'pantallas/lector.dart';
import 'pantallas/progreso.dart';
import 'pantallas/objetivos.dart';
import 'pantallas/pausa.dart';

export 'estado/proveedores.dart'
    show
        hoyHabitosProvider,
        repositorioHabitosProvider,
        servicioHabitosProvider;

Page<void> Function(BuildContext, GoRouterState) _pagina(
  Widget Function(BuildContext) b,
) =>
    (context, state) =>
        NoTransitionPage<void>(key: state.pageKey, child: b(context));

List<RouteBase> rutasHabitos() => [
  GoRoute(path: '/', pageBuilder: _pagina((_) => const PantallaHoyHabitos())),
  GoRoute(
    path: 'objetivos',
    pageBuilder: _pagina((_) => const PantallaObjetivos()),
  ),
  GoRoute(path: 'agenda', pageBuilder: _pagina((_) => const PantallaAgenda())),
  GoRoute(
    path: 'asistente',
    pageBuilder: _pagina((_) => const PantallaAsistente()),
  ),
  GoRoute(
    path: 'espiritual',
    pageBuilder: _pagina((_) => const PantallaEspiritual()),
  ),
  GoRoute(
    path: 'lector',
    pageBuilder: (context, state) => NoTransitionPage<void>(
      key: state.pageKey,
      child: PantallaLector(
        libro: int.tryParse(state.uri.queryParameters['libro'] ?? '') ?? 43,
        cap: int.tryParse(state.uri.queryParameters['cap'] ?? '') ?? 1,
      ),
    ),
  ),
  GoRoute(
    path: 'lector/nota',
    pageBuilder: (context, state) => NoTransitionPage<void>(
      key: state.pageKey,
      child: PantallaNotaLector(
        libro: int.tryParse(state.uri.queryParameters['libro'] ?? '') ?? 43,
        cap: int.tryParse(state.uri.queryParameters['cap'] ?? '') ?? 1,
        ver: int.tryParse(state.uri.queryParameters['ver'] ?? '') ?? 1,
      ),
    ),
  ),
  GoRoute(path: 'planes', pageBuilder: _pagina((_) => const PantallaPlanes())),
  GoRoute(
    path: 'devocional',
    pageBuilder: _pagina((_) => const PantallaDevocional()),
  ),
  GoRoute(
    path: 'oracion',
    pageBuilder: _pagina((_) => const PantallaOracion()),
  ),
  GoRoute(
    path: 'progreso',
    pageBuilder: _pagina((_) => const PantallaProgreso()),
  ),
  GoRoute(
    path: 'revision',
    pageBuilder: _pagina((_) => const PantallaRevision()),
  ),
  GoRoute(path: 'sos', pageBuilder: _pagina((_) => const PantallaPausa())),
  GoRoute(
    path: 'reservado',
    pageBuilder: _pagina((_) => const PantallaReservado()),
  ),
  GoRoute(
    path: 'eliminar/:tipo',
    pageBuilder: (context, state) => NoTransitionPage<void>(
      key: state.pageKey,
      child: PantallaHabitoEliminar(
        tipo: TipoHabito.values.firstWhere(
          (t) => t.name == state.pathParameters['tipo'],
          orElse: () => TipoHabito.cigarrillo,
        ),
      ),
    ),
  ),
];

/// SOS "tengo un antojo" como pantalla completa dentro de la hoja del (+) o
/// del diálogo de Ctrl + N: al terminar cierra esa hoja (no navega). Va detrás
/// de la puerta reservada (PIN, sin capturas, nunca en la tablet pública).
Widget hojaPausa() => Builder(
  builder: (contexto) =>
      PantallaPausa(alTerminar: () => Navigator.of(contexto).pop()),
);

/// Registro rápido de un hábito del día (botón (+)): lista lo de hoy con
/// *Hecho* y *Deshacer*. Solo objetivos normales, nada sensible.
Widget hojaHabito() => const HojaHabito();

/// Registro rápido de un consumo (cigarrillo o refresco) en un toque con
/// *Deshacer*. Reservado: detrás de la puerta (PIN o huella, FLAG_SECURE,
/// oculto en modo privado, nunca en la tablet pública; D13 y D21).
Widget hojaConsumo() => const HojaConsumo();

/// Respuesta de `habitos.resumen_hoy` (solo lo no sensible).
final consultaLocalHabitos = FutureProvider<String>(
  (ref) => ref.watch(servicioHabitosProvider).resumenHoy(),
);

/// Lo que la plataforma suma a los `overrides` de Riverpod: exportar mis
/// datos y recordatorios locales de Hábitos.
List<Override> get sobrescriturasHabitos => [
  fuenteDeDatosHabitosProvider.overrideWith(
    (ref) => FuenteDeDatosDeHabitos(
      ref.watch(repositorioHabitosProvider),
      ref.watch(repositorioAgendaProvider),
      ref.watch(documentosSensiblesProvider),
    ),
  ),
  fuenteDeRecordatoriosHabitosProvider.overrideWith(
    (ref) => FuenteDeRecordatoriosDeHabitos(
      ref.watch(repositorioAgendaProvider),
      ref.watch(servicioEliminarProvider),
    ),
  ),
];
