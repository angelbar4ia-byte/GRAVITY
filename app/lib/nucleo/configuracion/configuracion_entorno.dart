/// Configuración que entra al compilar con `--dart-define` (nunca en el
/// repositorio): llaves de Supabase y forzar un tipo de dispositivo.
library;

class ConfiguracionEntorno {
  const ConfiguracionEntorno({
    this.supabaseUrl = '',
    this.supabaseLlavePublica = '',
    this.dispositivoForzado = '',
  });

  /// Lee `SUPABASE_URL`, `SUPABASE_ANON_KEY` y `GRAVITY_DISPOSITIVO`.
  const ConfiguracionEntorno.desdeCompilacion()
    : supabaseUrl = const String.fromEnvironment('SUPABASE_URL'),
      supabaseLlavePublica = const String.fromEnvironment('SUPABASE_ANON_KEY'),
      dispositivoForzado = const String.fromEnvironment('GRAVITY_DISPOSITIVO');

  final String supabaseUrl;

  /// Llave pública (anon/publishable) del proyecto. No es secreta, pero
  /// tampoco se sube al repositorio.
  final String supabaseLlavePublica;

  /// `laptop`, `tablet` o `telefono` para probar otro cascarón (p. ej. la
  /// tablet desde la laptop). Vacío: se detecta solo.
  final String dispositivoForzado;

  /// Sin las dos llaves, la app arranca en modo demostración.
  bool get tieneSupabase =>
      supabaseUrl.trim().isNotEmpty && supabaseLlavePublica.trim().isNotEmpty;
}
