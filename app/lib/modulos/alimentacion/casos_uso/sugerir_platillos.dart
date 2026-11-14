/// Platillos desde la despensa (Fase 8, sección 2).
///
/// 1. [platillosConDespensa]: qué platillos del catálogo se pueden cocinar
///    con lo que hay en la despensa de la cuenta que lo pide. Todo local.
/// 2. "Sugerir con IA": la app arma un [ContextoSugerencia] y se lo da a un
///    [SugeridorRecetas]. El contexto lleva **solo** nombres de ingredientes,
///    cantidades aproximadas y las preferencias que la persona escribió.
///    Nunca el perfil clínico de Papá (ni nada de su salud, textura o dieta;
///    D3, D23), ni precios, ni cuentas. Una receta sugerida no se guarda
///    hasta que la persona la confirma (ver
///    `ServicioAlimentacion.guardarSugerida`).
library;

import 'dart:convert';

import '../datos/modelos.dart';
import 'importar_recetas.dart';

/// Máximo de caracteres de las preferencias que se mandan.
const maxCaracteresPreferencias = 300;

/// Máximo de ingredientes de la despensa que se mandan.
const maxIngredientesSugerencia = 60;

String _norm(String t) {
  const de = 'áéíóúüñ';
  const a = 'aeiouun';
  final b = StringBuffer();
  for (final ch in t.trim().toLowerCase().split('')) {
    final i = de.indexOf(ch);
    b.write(i >= 0 ? a[i] : ch);
  }
  return b.toString();
}

/// Un platillo y lo que le falta de la despensa (vacío = se puede cocinar).
class PlatilloConDespensa {
  const PlatilloConDespensa(this.platillo, this.faltantes);
  final Platillo platillo;

  /// Nombres de los ingredientes que faltan o no alcanzan.
  final List<String> faltantes;

  bool get cocinable => faltantes.isEmpty;
}

/// Cruza el catálogo con la despensa. Un ingrediente alcanza si está con la
/// misma unidad y cantidad suficiente; con otra unidad (no se convierte) basta
/// con que haya algo del ingrediente. Primero los que se pueden cocinar, luego
/// los que faltan pocos ingredientes. Platillos sin ingredientes se omiten.
List<PlatilloConDespensa> platillosConDespensa(
  Iterable<Platillo> platillos,
  Iterable<ItemDespensa> despensa,
) {
  final porNombre = <String, List<ItemDespensa>>{};
  for (final d in despensa) {
    if (d.cantidad > 0) (porNombre[_norm(d.nombre)] ??= []).add(d);
  }
  final r = <PlatilloConDespensa>[];
  for (final p in platillos) {
    if (p.ingredientes.isEmpty) continue;
    final faltan = <String>[];
    for (final i in p.ingredientes) {
      final hay = porNombre[_norm(i.nombre)] ?? const [];
      final mismaUnidad = hay.where((d) => _norm(d.unidad) == _norm(i.unidad));
      final alcanza = mismaUnidad.isNotEmpty
          ? mismaUnidad.fold<double>(0, (a, d) => a + d.cantidad) >=
                i.cantidad
          : hay.isNotEmpty;
      if (!alcanza) faltan.add(i.nombre);
    }
    r.add(PlatilloConDespensa(p, faltan));
  }
  r.sort((a, b) => a.faltantes.length.compareTo(b.faltantes.length));
  return r;
}

/// Cantidad aproximada: no se manda la exacta.
double cantidadAproximada(double c) {
  if (c <= 0) return 0;
  double redondeo(double paso) => (c / paso).round() * paso;
  final r = c < 10 ? redondeo(0.5) : c < 100 ? redondeo(5) : c < 1000 ? redondeo(50) : redondeo(100);
  return r == 0 ? (c < 10 ? 0.5 : 5) : r;
}

/// Lo único que sale hacia la IA. Cualquier campo nuevo aquí es un cambio de
/// privacidad: hay una prueba que fija las llaves.
class ContextoSugerencia {
  const ContextoSugerencia({
    required this.ingredientes,
    required this.preferencias,
  });

  /// Cada uno: `nombre`, `cantidad_aprox` y `unidad`.
  final List<Map<String, Object>> ingredientes;
  final String preferencias;

  /// Llaves permitidas (para pruebas y revisión).
  static const llaves = {'ingredientes', 'preferencias'};
  static const llavesIngrediente = {'nombre', 'cantidad_aprox', 'unidad'};

  Map<String, Object> aJson() => {
    'ingredientes': ingredientes,
    'preferencias': preferencias,
  };

  /// Despensa y preferencias -> contexto. Solo nombre, unidad y cantidad
  /// aproximada de lo que tiene existencia; preferencias en texto plano y
  /// cortas.
  factory ContextoSugerencia.de(
    Iterable<ItemDespensa> despensa,
    String preferencias,
  ) {
    final limpias = preferencias
        .replaceAll(RegExp(r'[\u0000-\u001f\u007f<>]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return ContextoSugerencia(
      ingredientes: [
        for (final d in despensa.where((d) => d.cantidad > 0).take(
          maxIngredientesSugerencia,
        ))
          {
            'nombre': d.nombre.trim(),
            'cantidad_aprox': cantidadAproximada(d.cantidad),
            'unidad': d.unidad.trim(),
          },
      ],
      preferencias: limpias.length > maxCaracteresPreferencias
          ? limpias.substring(0, maxCaracteresPreferencias)
          : limpias,
    );
  }
}

/// Un fallo de la sugerencia, con mensaje para mostrar.
class ErrorSugerencia implements Exception {
  const ErrorSugerencia(this.mensaje);
  final String mensaje;
  @override
  String toString() => mensaje;
}

/// La función de la IA (asistente). Vive fuera del módulo (guardia D3): aquí
/// solo está el contrato.
abstract interface class SugeridorRecetas {
  Future<List<Platillo>> sugerir(ContextoSugerencia contexto);
}

/// Sin servidor (demostración): avisa, no inventa recetas.
class SugeridorNoDisponible implements SugeridorRecetas {
  const SugeridorNoDisponible();
  @override
  Future<List<Platillo>> sugerir(ContextoSugerencia contexto) async =>
      throw const ErrorSugerencia(
        'La ayuda con IA necesita conexión con el servidor de GRAVITY.',
      );
}

/// Valida la respuesta de la IA (no es confiable) con las mismas reglas del
/// archivo de recetas: `{"recetas": [...]}` con título, pasos e ingredientes.
/// Nada se guarda aquí.
List<Platillo> recetasSugeridas(Object? respuesta) {
  final Object? lista = respuesta is Map ? respuesta['recetas'] : respuesta;
  if (lista is! List || lista.isEmpty) {
    throw const ErrorSugerencia('La IA no devolvió recetas. Inténtalo otra vez.');
  }
  final r = importarRecetasDeTexto(
    jsonEncode({'version': 1, 'recetas': lista}),
  );
  if (!r.valido) {
    throw const ErrorSugerencia(
      'La IA devolvió recetas que no se pueden usar. Inténtalo otra vez.',
    );
  }
  return [for (final x in r.recetas) x.platillo];
}
