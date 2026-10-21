/// Puntos de conexión con lo que construyen otros agentes.
///
/// Integrado por el arquitecto (Fase 0): cada función devuelve la pantalla real
/// del agente dueño. Para cambiar una conexión, cambia solo este archivo.
///
/// Fase 1: los huecos de Finanzas devuelven piezas **provisionales**. Al
/// integrar, el arquitecto agrega
/// `import '../modulos/finanzas/finanzas.dart' as finanzas;` y reemplaza el
/// cuerpo de cada uno por la línea de su comentario "Conectar:".
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../diseno/diseno.dart';
import '../modulos/ajustes/desarrollador/pantalla_desarrollador.dart';
import '../modulos/gravity/ordenes/barra_ordenes.dart';
import '../modulos/gravity/pantalla/hoy_telefono.dart';
import '../modulos/gravity/pantalla/pantalla_principal.dart';
import '../nucleo/contratos/dispositivo.dart';
import '../nucleo/contratos/roles.dart';
import 'pantallas/pantalla_proximamente.dart';

/// Pantalla principal de GRAVITY en la laptop (agente diseno).
Widget pantallaPrincipalGravity({Widget? barraOrdenes}) =>
    PantallaPrincipalGravity(barraOrdenes: barraOrdenes);

/// "Hoy" del teléfono y de la tablet por persona (agente diseno).
Widget pantallaHoyTelefono() => const PantallaHoyTelefono();

/// Barra de órdenes de navegación (agente asistente). Con el [dispositivo]
/// solo sugiere destinos que existen en él (Desarrollador, solo en la laptop;
/// revisión de la Fase 0, M6).
Widget barraOrdenes({
  required Rol rol,
  required void Function(String ruta) onNavegar,
  TipoDispositivo? dispositivo,
}) => BarraOrdenes(rol: rol, onNavegar: onNavegar, dispositivo: dispositivo);

/// Ajustes › Desarrollador (agente asistente).
Widget pantallaDesarrollador() => const PantallaDesarrollador();

/// Estilo, claro/oscuro y personalidad para Ajustes › Apariencia (agente diseno).
Widget? seccionApariencia() => const SeccionApariencia();

// ---------------------------------------------------------------------------
// Finanzas (agente finanzas, Fase 1): `app/lib/modulos/finanzas/finanzas.dart`.
// ---------------------------------------------------------------------------

/// Rutas de Finanzas, **relativas** a `Rutas.finanzas`. La pantalla de inicio
/// del módulo es la ruta raíz, `GoRoute(path: '/', …)`; las demás van con
/// segmentos relativos (`'semana'`, `'movimientos'`, …), a su lado o debajo
/// de la raíz. El router monta la raíz en `/finanzas` y lo demás debajo
/// (`montarRutasDeModulo`, en `router.dart`), dentro del cascarón: en la
/// laptop a pantalla completa y en el teléfono en la pestaña Finanzas.
///
/// El router ya deja fuera a familiar, cuidador y casa en cualquier ruta bajo
/// `/finanzas`. Las rutas que además de leer exigen escribir o administrar
/// (asistente de arranque, importar, ajustes de Finanzas, nueva cuenta…)
/// llevan `metadata: exigeAccion(Accion.escribir)` (o `administrar`) de
/// `nucleo/permisos/permisos.dart`: el coadministrador, que solo lee, vuelve
/// al inicio del módulo.
///
/// Conectar: `List<RouteBase> rutasFinanzas() => finanzas.rutasFinanzas();`
List<RouteBase> rutasFinanzas() => [
  GoRoute(
    path: '/',
    pageBuilder: (context, estado) => NoTransitionPage<void>(
      key: estado.pageKey,
      child: PantallaProximamente.modulo(
        Modulo.finanzas,
        detalle: 'Tablero, semana, movimientos y cuentas (provisional).',
      ),
    ),
  ),
];

/// Registro rápido de un gasto (F1). La plataforma lo muestra en una hoja
/// inferior desde el (+) del teléfono y de la tablet, y en un diálogo con
/// Ctrl + N en la laptop (`pantallas/registro_rapido.dart`). La hoja se
/// cierra sola con `Navigator.pop` al guardar o cancelar, se ajusta al
/// teclado y avisa *"Guardado · Deshacer"*.
///
/// Conectar: `Widget hojaRegistrarGasto() => finanzas.hojaRegistrarGasto();`
Widget hojaRegistrarGasto() => const _RegistroProvisional(
  titulo: 'Registrar gasto',
  icono: Icons.payments_outlined,
);

/// Registro de un ingreso extra (monto → cuenta → fecha → Guardar), en una
/// hoja inferior desde el (+), igual que [hojaRegistrarGasto].
///
/// Conectar: `Widget hojaIngresoExtra() => finanzas.hojaIngresoExtra();`
Widget hojaIngresoExtra() => const _RegistroProvisional(
  titulo: 'Registrar ingreso extra',
  icono: Icons.savings_outlined,
);

/// Tabla de Supabase por tipo de registro de la cola sin conexión (p. ej.
/// `'finanzas.movimiento': 'fin_movimientos'`). La cola sube con
/// `INSERT … ON CONFLICT (id) DO NOTHING` y la sesión de quien registró.
///
/// Conectar:
/// ```dart
/// const Map<String, String> tablasColaFinanzas = finanzas.tablasColaFinanzas;
/// ```
const Map<String, String> tablasColaFinanzas = {
  'finanzas.movimiento': 'fin_movimientos',
};

/// Hoja provisional de un registro de Finanzas.
class _RegistroProvisional extends StatelessWidget {
  const _RegistroProvisional({required this.titulo, required this.icono});

  final String titulo;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icono, color: tema.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(titulo, style: tema.textTheme.titleLarge),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Llega con el módulo de Finanzas (provisional).',
              style: tema.textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cerrar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tema de la app.
class TemaExterno {
  const TemaExterno({
    required this.claro,
    required this.oscuro,
    this.modo = ThemeMode.system,
    this.duracion = kThemeAnimationDuration,
  });

  final ThemeData claro;
  final ThemeData oscuro;
  final ThemeMode modo;
  final Duration duracion;
}

/// Tema de la app (agente diseno: sistema de estilos, claro/oscuro por hora).
TemaExterno temaExterno(WidgetRef ref) => TemaExterno(
  claro: ref.watch(temaClaroProvider),
  oscuro: ref.watch(temaOscuroProvider),
  modo: ref.watch(modoTemaProvider),
  duracion: duracionCambioTema,
);
