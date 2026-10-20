/// Puntos de conexión con lo que construyen otros agentes.
///
/// Hoy devuelven pantallas **provisionales**. Al integrar, el arquitecto
/// cambia **solo este archivo**: agrega los imports y reemplaza el cuerpo de
/// cada función por la línea indicada en su comentario "Conectar:".
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../nucleo/contratos/roles.dart';
import '../nucleo/permisos/permisos.dart';
import 'navegacion.dart';

/// Pantalla principal de GRAVITY en la laptop (agente diseno).
///
/// Conectar: `import '../modulos/gravity/pantalla/pantalla_principal.dart';`
/// y `return PantallaPrincipalGravity(barraOrdenes: barraOrdenes);`
Widget pantallaPrincipalGravity({Widget? barraOrdenes}) => _Provisional(
  titulo: 'GRAVITY',
  detalle: 'Pantalla principal (provisional)',
  icono: Icons.blur_circular,
  pie: barraOrdenes,
);

/// "Hoy" del teléfono y de la tablet por persona (agente diseno).
///
/// Conectar: `import '../modulos/gravity/pantalla/hoy_telefono.dart';`
/// y `return const PantallaHoyTelefono();`
Widget pantallaHoyTelefono() => const _Provisional(
  titulo: 'Hoy',
  detalle: 'Lo del día de todos tus módulos (provisional)',
  icono: Icons.today_outlined,
);

/// Barra de órdenes de navegación (agente asistente).
///
/// Conectar: `import '../modulos/gravity/ordenes/barra_ordenes.dart';`
/// y `return BarraOrdenes(rol: rol, onNavegar: onNavegar);`
Widget barraOrdenes({
  required Rol rol,
  required void Function(String ruta) onNavegar,
}) => _BarraOrdenesProvisional(rol: rol, onNavegar: onNavegar);

/// Ajustes › Desarrollador (agente asistente).
///
/// Conectar: `import '../modulos/ajustes/desarrollador/pantalla_desarrollador.dart';`
/// y `return const PantallaDesarrollador();`
Widget pantallaDesarrollador() => const _Provisional(
  titulo: 'Desarrollador',
  detalle: 'APIs del sistema con Swagger UI (provisional)',
  icono: Icons.code,
);

/// Selector de estilo, claro/oscuro y personalidad para Ajustes › Apariencia
/// (agente diseno). `null` muestra el texto provisional.
Widget? seccionApariencia() => null;

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
///
/// Conectar: `import '../diseno/proveedores.dart';` y
/// ```dart
/// return TemaExterno(
///   claro: ref.watch(temaClaroProvider),
///   oscuro: ref.watch(temaOscuroProvider),
///   modo: ref.watch(modoTemaProvider),
///   duracion: duracionCambioTema,
/// );
/// ```
TemaExterno temaExterno(WidgetRef ref) => _temaProvisional;

final _temaProvisional = TemaExterno(
  claro: ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0E7490)),
  ),
  oscuro: ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF22D3EE),
      brightness: Brightness.dark,
    ),
  ),
);

class _Provisional extends StatelessWidget {
  const _Provisional({
    required this.titulo,
    required this.detalle,
    required this.icono,
    this.pie,
  });

  final String titulo;
  final String detalle;
  final IconData icono;
  final Widget? pie;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Material(
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icono, size: 56, color: tema.colorScheme.primary),
                      const SizedBox(height: 16),
                      Text(titulo, style: tema.textTheme.headlineMedium),
                      const SizedBox(height: 8),
                      Text(
                        detalle,
                        textAlign: TextAlign.center,
                        style: tema.textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ?pie,
          ],
        ),
      ),
    );
  }
}

/// Barra provisional: "abre finanzas", "hábitos", "ajustes"…
class _BarraOrdenesProvisional extends StatefulWidget {
  const _BarraOrdenesProvisional({required this.rol, required this.onNavegar});

  final Rol rol;
  final void Function(String ruta) onNavegar;

  @override
  State<_BarraOrdenesProvisional> createState() =>
      _BarraOrdenesProvisionalState();
}

class _BarraOrdenesProvisionalState extends State<_BarraOrdenesProvisional> {
  final _texto = TextEditingController();
  String? _aviso;

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  void _enviar(String orden) {
    final limpio = _sinAcentos(orden.toLowerCase());
    for (final modulo in [...modulosNavegables(widget.rol), Modulo.ajustes]) {
      if (!puedeAbrir(widget.rol, modulo)) continue;
      if (limpio.contains(_sinAcentos(nombreModulo(modulo).toLowerCase()))) {
        _texto.clear();
        setState(() => _aviso = null);
        widget.onNavegar(rutaDeModulo(modulo));
        return;
      }
    }
    setState(() => _aviso = 'No entendí. Prueba "abre hábitos".');
  }

  static String _sinAcentos(String texto) => texto
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u');

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: TextField(
      controller: _texto,
      onSubmitted: _enviar,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.chevron_right),
        hintText: 'Escribe a GRAVITY… (p. ej. "abre hábitos")',
        errorText: _aviso,
        border: const OutlineInputBorder(),
      ),
    ),
  );
}

/// Evita el aviso de import sin uso mientras todo es provisional.
typedef LectorExterno = WidgetRef;
