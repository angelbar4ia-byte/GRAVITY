import 'datos.dart';
import 'lector.dart';

/// Escalera y listas controladas de `data/ingles/niveles.yaml`.
///
/// El formato (sección 8) no fija los nombres de los campos: dice solo que el
/// archivo trae la escalera, el temario y las listas de `habilidad`, `foco` y
/// `temas`. Esta lectura acepta `niveles`, `escalones`, `habilidades`, `focos`
/// y `temas`, cada uno como lista de textos o de bloques con `id`. Si P1.3
/// elige otros nombres, se cambia aquí y en las pruebas, y en ningún otro sitio.
class Niveles {
  const Niveles({
    required this.niveles,
    required this.escalones,
    required this.habilidades,
    required this.focos,
    required this.temas,
    this.datos = const {},
  });

  /// Etapas (A1, A2, B1, B2). Vacía si el archivo no las lista.
  final Set<String> niveles;
  final Set<String> escalones;
  final Set<String> habilidades;
  final Set<String> focos;
  final Set<String> temas;

  /// Todo el archivo tal como se leyó (V27 mira escalones, temas retomados,
  /// cobertura de los manuales y totales).
  final Mapa datos;

  /// Los escalones en el orden en que están escritos, con sus campos.
  List<Mapa> get escalonesEnOrden => [
    for (final e in listaEn(datos, 'escalones') ?? const <Object?>[])
      if (e is Map<String, Object?>) e,
  ];

  /// La etapa de cada escalón (`A2.1` → `A2`), si el archivo la dice.
  Map<String, String> get etapaDeEscalon => {
    for (final e in escalonesEnOrden)
      if (e['id'] is String && e['etapa'] is String)
        e['id']! as String: e['etapa']! as String,
  };

  /// Marcas `pendiente: true` de todo el archivo.
  List<DatoPendiente> get pendientes => pendientesEn(datos);
}

Set<String> _ids(Vista v, String k) {
  final l = v.lista(k, requerido: false);
  final salida = <String>{};
  if (l == null) return salida;
  for (var i = 0; i < l.length; i++) {
    final e = l[i];
    if (e is String && e.trim().isNotEmpty) {
      salida.add(e);
    } else if (e is Map<String, Object?> && e['id'] is String) {
      salida.add(e['id']! as String);
    } else {
      v.lector.error('${v.ruta.isEmpty ? '' : '${v.ruta}.'}$k[$i]', 'debe ser un texto o un bloque con "id"', id: v.id);
    }
  }
  return salida;
}

Niveles leerNiveles(Vista v) => Niveles(
  niveles: _ids(v, 'niveles'),
  escalones: _ids(v, 'escalones'),
  habilidades: _ids(v, 'habilidades'),
  focos: _ids(v, 'focos'),
  temas: _ids(v, 'temas'),
  datos: v.datos,
);
