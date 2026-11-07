/// Módulo **Cuidados** de GRAVITY (agente cuidados, Fase 5).
///
/// [rutasCuidados]: rutas **relativas** a `/cuidados` (raíz = Mi turno;
/// `medicamentos`, `comidas`, `bitacora`, `instrucciones`, `consentimientos`, `resumen`, `urgente`, `gestion`).
/// Contrato del servidor: `docs/specs/fase-5-cuidados.md` y las tablas
/// `cui_*` (columnas en `datos/repositorio_supabase.dart`). Los datos
/// clínicos nunca van a la IA ni a las bocinas (D3, D6): este módulo no
/// registra herramientas de GRAVITY ni consultas locales.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../nucleo/contratos/roles.dart';
import '../../nucleo/permisos/permisos.dart';
import 'pantallas/bitacora.dart';
import 'pantallas/cambio_urgente.dart';
import 'pantallas/comidas.dart';
import 'pantallas/consentimientos.dart';
import 'pantallas/gestion.dart';
import 'pantallas/instrucciones.dart';
import 'pantallas/medicamentos.dart';
import 'pantallas/mi_turno.dart';
import 'pantallas/resumen_mensual.dart';

export 'casos_uso/horario_turnos.dart' show deTurnoAhora, recibeRecordatorio;
export 'casos_uso/servicio_cuidados.dart' show textoRecordatorioGenerico;
export 'estado/proveedores.dart' show repositorioCuidadosProvider;

Page<void> Function(BuildContext, GoRouterState) _pagina(Widget Function() b) =>
    (context, state) => NoTransitionPage<void>(key: state.pageKey, child: b());

List<RouteBase> rutasCuidados() => [
  GoRoute(path: '/', pageBuilder: _pagina(() => const PantallaMiTurno())),
  GoRoute(
    path: 'medicamentos',
    pageBuilder: _pagina(() => const PantallaMedicamentos()),
  ),
  GoRoute(path: 'comidas', pageBuilder: _pagina(() => const PantallaComidas())),
  GoRoute(
    path: 'bitacora',
    pageBuilder: _pagina(() => const PantallaBitacora()),
  ),
  GoRoute(
    path: 'instrucciones',
    pageBuilder: _pagina(() => const PantallaInstrucciones()),
  ),
  GoRoute(
    path: 'consentimientos',
    pageBuilder: _pagina(() => const PantallaConsentimientos()),
  ),
  GoRoute(
    path: 'resumen',
    pageBuilder: _pagina(() => const PantallaResumenMensual()),
  ),
  GoRoute(
    path: 'urgente',
    metadata: exigeAccion(Accion.administrar),
    pageBuilder: _pagina(() => const PantallaCambioUrgente()),
  ),
  GoRoute(
    path: 'gestion',
    metadata: exigeAccion(Accion.administrar),
    pageBuilder: _pagina(() => const PantallaGestionCuidados()),
  ),
];
