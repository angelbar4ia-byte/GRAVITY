/// Orden de navegación «abre el entrenamiento» (Fase 8, bloque 7 · Mi gimnasio).
///
/// docs/specs/fase-8-habitos-gimnasio.md, 8.5: la herramienta
/// `habitos.abrir_entrenamiento` **solo navega** a la pantalla de
/// entrenamiento de Hábitos. No lee series, cargas, esfuerzo ni molestias, no
/// escribe, no habla por las bocinas (D6) y su resultado nunca llega a la IA en
/// la nube (Hábitos es solo local, D3 y D13). La barra de órdenes la resuelve
/// sin IA, y la orden no se guarda en ningún historial.
///
/// **No está en el catálogo del asistente en la nube**
/// (`supabase/functions/gravity-asistente/catalogo.json`): ni siquiera el
/// nombre «entrenamiento» sale del dispositivo. Una prueba lo vigila
/// (`test/modulos/gravity/conversacion/entrenamiento_sin_ia_test.dart`).
///
/// El destino es [destinoEntrenamiento]: la ruta que fija la especificación
/// (7.1: `entrenamiento`, relativa a `/habitos`) y que declara el router de
/// Hábitos cuando se construye la app del bloque (plataforma G3 y app G5).
/// Cambiar a dónde lleva la orden es cambiar esa constante y nada más.
///
/// Cuando `nucleo/herramientas` la registre (`navegacionFase8`, en
/// `herramientasNavegacion`), [catalogoDeOrdenes] la deja pasar sin repetirla y
/// este archivo solo conserva la definición.
library;

import '../../../nucleo/contratos/roles.dart';
import '../../../nucleo/contratos/rutas.dart';
import '../../../nucleo/herramientas/herramientas.dart';

/// Destino de la orden: Hábitos › Salud › Entrenamiento. Ruta **no reservada**
/// (no pide PIN): lo sensible del entrenamiento, las molestias, vive en otra
/// pantalla y esta orden nunca la nombra.
const String destinoEntrenamiento = '${Rutas.habitos}/entrenamiento';

/// Hábitos › Entrenamiento («abre el entrenamiento», «qué toca hoy en el
/// gimnasio»). Solo abre la vista. No la recibe la cuenta maestra que no es la
/// dueña (Hábitos es de cada quien, `hab_activa`).
final herramientaAbrirEntrenamientoHabitos = HerramientaNavegacion(
  nombre: 'habitos.abrir_entrenamiento',
  modulo: Modulo.habitos,
  roles: rolesParaNavegar(Modulo.habitos),
  ruta: destinoEntrenamiento,
  etiqueta: 'Entrenamiento',
  palabrasClave: const [
    'entrenamiento',
    'entrenar',
    'gimnasio',
    // Con «hoy» solo, la orden llevaría a Hábitos › Hoy: por eso las frases
    // completas (la palabra clave más larga gana, `InterpreteOrdenes`).
    'qué toca hoy en el gimnasio',
    'qué toca hoy de entrenamiento',
    'qué toca entrenar hoy',
  ],
  paraSoloLectura: false,
  historial: false,
  descripcion:
      'Abre Hábitos › Entrenamiento. Solo abre la vista: no lee ni dice series, '
      'cargas ni molestias, nada va a la IA y no se guarda en ningún historial.',
);

/// El catálogo de navegación de la barra de órdenes: el de la plataforma más
/// [herramientaAbrirEntrenamientoHabitos], si `nucleo/herramientas` todavía no
/// la registra (sin repetirla si ya lo hace). Va después de lo último de
/// Hábitos, que es donde se sugiere.
List<HerramientaNavegacion> catalogoDeOrdenes() {
  final base = herramientasNavegacion;
  if (base.any(
    (h) => h.nombre == herramientaAbrirEntrenamientoHabitos.nombre,
  )) {
    return base;
  }
  final ultimaDeHabitos = base.lastIndexWhere(
    (h) => h.modulo == Modulo.habitos,
  );
  return List.unmodifiable([
    ...base.take(ultimaDeHabitos + 1),
    herramientaAbrirEntrenamientoHabitos,
    ...base.skip(ultimaDeHabitos + 1),
  ]);
}

/// Registro de la barra: las herramientas de [catalogoDeOrdenes]. Es el
/// registro con el que la barra ejecuta una orden; el del panel de conversación
/// con la IA (`registroDeGravity`) no la lleva a propósito.
RegistroHerramientas registroDeOrdenes() =>
    RegistroHerramientas(catalogoDeOrdenes());
