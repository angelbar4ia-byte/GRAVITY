/// Catálogo de herramientas de GRAVITY por fase.
///
/// Cada fase agrega aquí las herramientas que publican sus módulos. El
/// registro las valida al construirse: formato del nombre, matriz de permisos
/// (D5), la bandeja de la cuidadora (D18), la cuenta maestra (D19) y la regla
/// de solo local para Finanzas y Cuidados (D3).
library;

import 'herramienta.dart';
import 'navegacion.dart';
import 'registro_herramientas.dart';

/// Herramientas de la Fase 0 (navegación a cada módulo).
List<Herramienta> herramientasFase0() => [...navegacionFase0];

/// Herramientas que agrega la Fase 1: Finanzas (registrar gasto, la semana)
/// y la bandeja de solicitudes de la cuidadora. Todas navegan; ninguna
/// escribe ni lee montos.
List<Herramienta> herramientasFase1() => [...navegacionFase1];

/// Herramientas que agrega la Fase 3: Hábitos (hoy, agenda, espiritual y SOS).
/// Solo abren la vista; son solo locales (D13) y no se guardan en historial.
List<Herramienta> herramientasFase3() => [...navegacionFase3];

/// Todas las herramientas vigentes, en el orden en que se sugieren.
List<Herramienta> herramientasDeGravity() => [...herramientasNavegacion];

/// Registro con las herramientas de la Fase 0.
RegistroHerramientas registroFase0() =>
    RegistroHerramientas(herramientasFase0());

/// Registro con todas las herramientas vigentes (lo que usa la app).
RegistroHerramientas registroDeGravity() =>
    RegistroHerramientas(herramientasDeGravity());
