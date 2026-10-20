/// Catálogo de herramientas de GRAVITY por fase.
///
/// Cada fase agrega aquí las herramientas que publican sus módulos. El
/// registro las valida al construirse: formato del nombre, matriz de permisos
/// (D5) y la regla de solo local para Finanzas y Cuidados (D3).
library;

import 'herramienta.dart';
import 'navegacion.dart';
import 'registro_herramientas.dart';

/// Todas las herramientas de la Fase 0 (solo navegación).
List<Herramienta> herramientasFase0() => [...herramientasNavegacion];

/// Registro con las herramientas de la Fase 0.
RegistroHerramientas registroFase0() =>
    RegistroHerramientas(herramientasFase0());
