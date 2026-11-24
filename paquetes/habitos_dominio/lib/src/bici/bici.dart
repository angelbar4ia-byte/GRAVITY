/// Dominio puro de la bicicleta de los sábados (Hábitos, Fase 8, B1): salida
/// y revisión de las 14:30, carga de piernas y 48 h, mantenimiento y odómetro,
/// preparación, clima, progresión informativa, modo foco, meta mensual y
/// catálogo de mensajes.
///
/// Base: `docs/specs/fase-8-habitos-bicicleta.md` (4, 5.3 y 9.1). Dart puro,
/// sin Flutter, sin I/O, sin reloj propio y sin dependencias. **No modela
/// ubicación:** rutas, enlaces de ruta, trazos y contacto de emergencia son
/// del tipo local `ubicacion_local` (decisión D-B) y nunca salen del equipo;
/// ningún tipo de aquí tiene esos campos.
library;

export 'carga_piernas.dart';
export 'clima.dart';
export 'contenido_bici.dart';
export 'enlaces.dart';
export 'hoy_bici.dart';
export 'mantenimiento.dart';
export 'mensajes_bici.dart';
export 'objetivo_bici.dart';
export 'perfil_bici.dart';
export 'preparacion.dart';
export 'progresion_bici.dart';
export 'reglas_bici.dart';
export 'salida_sabado.dart';
export 'tipos_bici.dart';
