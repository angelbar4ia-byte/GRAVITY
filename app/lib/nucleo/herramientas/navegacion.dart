/// Herramientas de navegación de la Fase 0: abrir un módulo o una pantalla.
///
/// No escriben datos ni leen nada de los módulos, así que no piden
/// confirmación y su resultado ("Se abrió Finanzas") sí puede verlo la IA.
library;

import '../contratos/roles.dart';
import '../contratos/rutas.dart';
import 'herramienta.dart';
import 'registro_herramientas.dart';
import 'visibilidad_modulos.dart';

/// Abre una ruta de la app.
final class HerramientaNavegacion extends Herramienta {
  const HerramientaNavegacion({
    required this.nombre,
    required this.modulo,
    required this.roles,
    required this.ruta,
    required this.etiqueta,
    required this.palabrasClave,
  });

  @override
  final String nombre;

  @override
  final Modulo modulo;

  @override
  final Set<Rol> roles;

  /// Ruta de `Rutas` que abre.
  final String ruta;

  /// Nombre visible del destino, p. ej. "Finanzas".
  final String etiqueta;

  /// Palabras (y frases cortas) que lo nombran en una orden, con acentos.
  /// La barra de órdenes las compara sin acentos ni mayúsculas.
  final List<String> palabrasClave;

  @override
  String get descripcion => 'Abre $etiqueta.';

  @override
  bool get escribe => false;

  @override
  bool get soloLocal => false;

  @override
  Future<ResultadoHerramienta> ejecutar(
    Map<String, Object?> parametros,
    ContextoHerramienta ctx,
  ) async {
    final navegar = ctx.navegar;
    if (navegar == null) {
      return ResultadoHerramienta(
        this,
        contenido: 'No hay una pantalla donde abrir $etiqueta.',
        paraIa: 'No se pudo abrir $etiqueta: no hay pantalla.',
      );
    }
    navegar(ruta);
    return ResultadoHerramienta(
      this,
      contenido: 'Abriendo $etiqueta…',
      paraIa: 'Se abrió $etiqueta.',
    );
  }
}

/// Catálogo de navegación de la Fase 0, en el orden en que se sugiere.
final List<HerramientaNavegacion> herramientasNavegacion = List.unmodifiable([
  HerramientaNavegacion(
    nombre: 'gravity.abrir',
    modulo: Modulo.gravity,
    roles: rolesQueVen(Modulo.gravity),
    ruta: Rutas.inicio,
    etiqueta: 'Inicio',
    palabrasClave: const [
      'inicio',
      'gravity',
      'principal',
      'pantalla principal',
      'menú principal',
    ],
  ),
  HerramientaNavegacion(
    nombre: 'finanzas.abrir',
    modulo: Modulo.finanzas,
    roles: rolesQueVen(Modulo.finanzas),
    ruta: Rutas.finanzas,
    etiqueta: 'Finanzas',
    palabrasClave: const ['finanzas', 'presupuesto', 'presupuestos', 'dinero'],
  ),
  HerramientaNavegacion(
    nombre: 'habitos.abrir',
    modulo: Modulo.habitos,
    roles: rolesQueVen(Modulo.habitos),
    ruta: Rutas.habitos,
    etiqueta: 'Hábitos',
    palabrasClave: const ['hábitos', 'hábito'],
  ),
  HerramientaNavegacion(
    nombre: 'cuidados.abrir',
    modulo: Modulo.cuidados,
    roles: rolesQueVen(Modulo.cuidados),
    ruta: Rutas.cuidados,
    etiqueta: 'Cuidados',
    palabrasClave: const ['cuidados', 'cuidado', 'papá'],
  ),
  HerramientaNavegacion(
    nombre: 'alimentacion.abrir',
    modulo: Modulo.alimentacion,
    roles: rolesQueVen(Modulo.alimentacion),
    ruta: Rutas.alimentacion,
    etiqueta: 'Alimentación',
    palabrasClave: const [
      'alimentación',
      'comida',
      'comidas',
      'cocina',
      'menú',
      'menús',
      'receta',
      'recetas',
    ],
  ),
  HerramientaNavegacion(
    nombre: 'casa.abrir',
    modulo: Modulo.casa,
    roles: rolesQueVen(Modulo.casa),
    ruta: Rutas.casa,
    etiqueta: 'Casa',
    palabrasClave: const ['casa', 'hogar'],
  ),
  HerramientaNavegacion(
    nombre: 'ajustes.abrir',
    modulo: Modulo.ajustes,
    roles: rolesQueVen(Modulo.ajustes),
    ruta: Rutas.ajustes,
    etiqueta: 'Ajustes',
    palabrasClave: const ['ajustes', 'ajuste', 'configuración', 'preferencias'],
  ),
  // Ajustes › Desarrollador: solo quien administra Ajustes, el Dueño (D16).
  // Que solo aparezca en la laptop lo decide el cascarón de la plataforma.
  HerramientaNavegacion(
    nombre: 'ajustes.abrir_desarrollador',
    modulo: Modulo.ajustes,
    roles: rolesQueAdministran(Modulo.ajustes),
    ruta: Rutas.desarrollador,
    etiqueta: 'Desarrollador',
    palabrasClave: const ['desarrollador', 'api', 'apis', 'swagger'],
  ),
]);

/// Todas las herramientas de la Fase 0.
List<Herramienta> herramientasFase0() => [...herramientasNavegacion];

/// Registro con las herramientas de la Fase 0.
RegistroHerramientas registroFase0() => RegistroHerramientas(herramientasFase0());
