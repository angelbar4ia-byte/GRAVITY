/// Acceso a «Mi gimnasio» (Fase 8, G3; spec 7.1): destinos, rutas y qué ve cada
/// equipo. **Puro** (sin widgets): lo usa el router para decidir y las pruebas.
///
/// Las pantallas E1 a E10 viven **dentro de Hábitos** (`/habitos/entrenamiento/…`)
/// y por eso heredan la regla de Hábitos: solo dueño, coadministrador y familiar
/// (cada quien lo **suyo**); cuidador, Hogar (Casa) y la cuenta maestra no ven
/// nada (`puedeUsarHabitos`, que ya aplica el router).
///
/// Encima, [gimnasioDisponibleEn] recorta por **equipo** (matriz de 7.1):
///
/// | | teléfono | laptop | tablet personal | tablet pública |
/// |---|---|---|---|---|
/// | E1 Hoy, E4 Sesión de hoy | sí | sí | sí | sí (con nombre y PIN) |
/// | E5 Sesión en curso | sí | solo ver | sí | sí |
/// | E2, E3, E6, E7, E8, E10 | sí | sí | sí | no |
/// | E9 Molestias | sí | **no** | solo este equipo | **nunca** |
library;

import '../../nucleo/avisos/repositorio_avisos.dart' show TipoEquipoAvisos;
import '../../nucleo/contratos/rutas.dart';

/// Las diez pantallas de «Mi gimnasio» (7.1).
enum DestinoGimnasio {
  /// E1 · «Entrenamiento de hoy»: la entrada, con **Empezar** y *Hecho*.
  hoy('entrenamiento', 'Entrenamiento'),

  /// E2 · Inventario de aparatos, puestos, bandas y accesorios.
  inventario('entrenamiento/inventario', 'Inventario'),

  /// E3 · Plan de la semana.
  plan('entrenamiento/plan', 'Plan de la semana'),

  /// E4 · Vista previa de la sesión de hoy.
  sesion('entrenamiento/sesion', 'Sesión de hoy'),

  /// E5 · Sesión en curso (pantalla completa, Sport).
  sesionEnCurso('entrenamiento/sesion/en-curso', 'Sesión en curso'),

  /// E6 · Registrar lo que hice.
  registro('entrenamiento/registro', 'Registrar lo que hice'),

  /// E7 · Historial.
  historial('entrenamiento/historial', 'Historial'),

  /// E8 · Récords.
  records('entrenamiento/records', 'Récords'),

  /// E9 · Molestias (solo en este equipo; FLAG_SECURE y modo privado).
  molestias('entrenamiento/molestias', 'Molestias'),

  /// E10 · Ajustes de Mi gimnasio.
  ajustes('entrenamiento/ajustes', 'Ajustes de Mi gimnasio');

  const DestinoGimnasio(this.rutaRelativa, this.titulo);

  /// Ruta relativa a `/habitos` (como `rutasHabitos`).
  final String rutaRelativa;
  final String titulo;

  /// Ruta completa (`/habitos/entrenamiento/…`).
  String get ruta => '${Rutas.habitos}/$rutaRelativa';
}

/// Rutas con nombre, para quien navega (G5, GRAVITY, Hoy).
abstract final class RutasGimnasio {
  static String get hoy => DestinoGimnasio.hoy.ruta;
  static String get sesionEnCurso => DestinoGimnasio.sesionEnCurso.ruta;
  static String get molestias => DestinoGimnasio.molestias.ruta;
}

/// El destino de [ubicacion] (ruta completa, con o sin barra final), o `null`
/// si no es una pantalla de «Mi gimnasio».
DestinoGimnasio? destinoGimnasioDeRuta(String ubicacion) {
  final limpia = ubicacion.length > 1 && ubicacion.endsWith('/')
      ? ubicacion.substring(0, ubicacion.length - 1)
      : ubicacion;
  for (final d in DestinoGimnasio.values) {
    if (d.ruta == limpia) return d;
  }
  return null;
}

/// `true` si [ubicacion] es la pantalla de molestias (E9).
bool esRutaDeMolestias(String ubicacion) =>
    destinoGimnasioDeRuta(ubicacion) == DestinoGimnasio.molestias;

/// ¿Esa pantalla existe en ese equipo? (matriz de 7.1; ver la cabecera).
bool gimnasioDisponibleEn(DestinoGimnasio destino, TipoEquipoAvisos equipo) {
  final publica = equipo == TipoEquipoAvisos.tabletPublica;
  final laptop = equipo == TipoEquipoAvisos.laptop;
  return switch (destino) {
    // En todos los equipos (la sesión en curso, en la laptop, solo se ve).
    DestinoGimnasio.hoy ||
    DestinoGimnasio.sesion ||
    DestinoGimnasio.sesionEnCurso => true,
    // Las molestias no están en la laptop ni en la tablet pública.
    DestinoGimnasio.molestias => !publica && !laptop,
    // Planear, registrar después, revisar y ajustar: no en la tablet pública.
    DestinoGimnasio.inventario ||
    DestinoGimnasio.plan ||
    DestinoGimnasio.registro ||
    DestinoGimnasio.historial ||
    DestinoGimnasio.records ||
    DestinoGimnasio.ajustes => !publica,
  };
}

/// En la laptop la sesión en curso es **solo para ver** (7.1).
bool gimnasioSoloVerEn(DestinoGimnasio destino, TipoEquipoAvisos equipo) =>
    destino == DestinoGimnasio.sesionEnCurso &&
    equipo == TipoEquipoAvisos.laptop;
