/// B1.4 · Lista de preparación (4.2): catálogo cerrado y editable, en dos
/// momentos. Marcar es un toque y se deshace; **un punto sin marcar no
/// bloquea nada** (RB6). El contenido nace `borrador`.
library;

import '../gimnasio/tipos.dart' show RevisionContenido;
import 'tipos_bici.dart';

enum MomentoPreparacion { viernes, antesDeSalir }

/// A qué tipo de ruta aplica un punto.
enum AplicaA { todas, calleOMixta, terrenoOMixta }

class PuntoPreparacion {
  const PuntoPreparacion({
    required this.id,
    required this.texto,
    required this.momento,
    this.aplicaA = AplicaA.todas,
    this.propio = false,
    this.revision = RevisionContenido.borrador,
  });

  final String id;
  final String texto;
  final MomentoPreparacion momento;
  final AplicaA aplicaA;

  /// Punto que escribió la persona (no es del catálogo).
  final bool propio;
  final RevisionContenido revision;
}

/// Catálogo de 4.2. Los textos no llevan cifras de líquidos ni de comida.
const catalogoPreparacion = <PuntoPreparacion>[
  // Viernes en la noche
  PuntoPreparacion(
    id: 'bici_revisada',
    texto: 'Bici revisada: frenos, llantas y cadena',
    momento: MomentoPreparacion.viernes,
  ),
  PuntoPreparacion(
    id: 'luces_cargadas',
    texto: 'Luces cargadas',
    momento: MomentoPreparacion.viernes,
  ),
  PuntoPreparacion(
    id: 'telefono_cargando',
    texto: 'Teléfono y luces a cargar',
    momento: MomentoPreparacion.viernes,
  ),
  PuntoPreparacion(
    id: 'agua_lista',
    texto: 'Agua lista',
    momento: MomentoPreparacion.viernes,
  ),
  PuntoPreparacion(
    id: 'comida_lista',
    texto: 'Algo fácil de comer',
    momento: MomentoPreparacion.viernes,
  ),
  PuntoPreparacion(
    id: 'herramientas',
    texto: 'Bomba o inflador, parche y cámara de repuesto',
    momento: MomentoPreparacion.viernes,
  ),
  PuntoPreparacion(
    id: 'ropa_lista',
    texto: 'Casco y ropa visible listos',
    momento: MomentoPreparacion.viernes,
  ),
  PuntoPreparacion(
    id: 'clima_visto',
    texto: 'Revisé el clima',
    momento: MomentoPreparacion.viernes,
  ),
  // Antes de salir (sábado)
  PuntoPreparacion(
    id: 'casco_puesto',
    texto: 'Casco',
    momento: MomentoPreparacion.antesDeSalir,
  ),
  PuntoPreparacion(
    id: 'luces_puestas',
    texto: 'Luces puestas',
    momento: MomentoPreparacion.antesDeSalir,
  ),
  PuntoPreparacion(
    id: 'frenos_probados',
    texto: 'Probé los frenos',
    momento: MomentoPreparacion.antesDeSalir,
  ),
  PuntoPreparacion(
    id: 'presion_llantas',
    texto: 'Llantas en buen estado',
    momento: MomentoPreparacion.antesDeSalir,
  ),
  PuntoPreparacion(
    id: 'protector_solar',
    texto: 'Protector solar',
    momento: MomentoPreparacion.antesDeSalir,
  ),
  PuntoPreparacion(
    id: 'escucha_exterior',
    texto: 'Audífonos en escucha exterior o a volumen bajo',
    momento: MomentoPreparacion.antesDeSalir,
  ),
  PuntoPreparacion(
    id: 'aviso_regreso',
    texto: 'Avisé mi hora de regreso',
    momento: MomentoPreparacion.antesDeSalir,
  ),
  // Solo en ruta de calle o mixta
  PuntoPreparacion(
    id: 'ropa_visible',
    texto: 'En calle, ropa visible',
    momento: MomentoPreparacion.antesDeSalir,
    aplicaA: AplicaA.calleOMixta,
  ),
  PuntoPreparacion(
    id: 'luces_siempre',
    texto: 'En calle, luces encendidas',
    momento: MomentoPreparacion.antesDeSalir,
    aplicaA: AplicaA.calleOMixta,
  ),
  // Solo en ruta de terreno o mixta (`herramientas` ya está arriba)
  PuntoPreparacion(
    id: 'llantas_frenos_terreno',
    texto: 'Llantas y frenos revisados para terreno',
    momento: MomentoPreparacion.antesDeSalir,
    aplicaA: AplicaA.terrenoOMixta,
  ),
];

bool _aplica(AplicaA a, SuperficieSalida? s) {
  if (s == null) return true; // sin ruta ni salida previa: se muestran todos
  switch (a) {
    case AplicaA.todas:
      return true;
    case AplicaA.calleOMixta:
      return s != SuperficieSalida.terreno;
    case AplicaA.terrenoOMixta:
      return s != SuperficieSalida.calle;
  }
}

/// Lo que la persona cambió de la lista: puntos apagados y propios.
class PreparacionPersonal {
  const PreparacionPersonal({
    this.apagados = const {},
    this.propios = const [],
    this.maxPropios = 10,
    this.maxLargo = 60,
  });

  /// Ids del catálogo que la persona apagó (`{id, activo: false}`).
  final Set<String> apagados;

  /// Textos propios, hasta 10 de 60 caracteres.
  final List<String> propios;
  final int maxPropios;
  final int maxLargo;

  /// Por qué no se puede agregar [texto] (null si se puede).
  ErrorBici? errorAlAgregar(String texto) {
    final t = texto.trim();
    if (t.isEmpty) return ErrorBici('propio_vacio', 'escribe el punto');
    if (t.length > maxLargo) {
      return ErrorBici('propio_largo', 'hasta $maxLargo caracteres');
    }
    if (propios.length >= maxPropios) {
      return ErrorBici('propios_de_mas', 'hasta $maxPropios puntos propios');
    }
    return null;
  }

  /// Agrega un punto propio; **el once se rechaza** con [ArgumentError].
  PreparacionPersonal conPropio(String texto) {
    final e = errorAlAgregar(texto);
    if (e != null) throw ArgumentError.value(texto, 'texto', e.toString());
    return PreparacionPersonal(
      apagados: apagados,
      propios: [...propios, texto.trim()],
      maxPropios: maxPropios,
      maxLargo: maxLargo,
    );
  }

  PreparacionPersonal sinPropio(int indice) => PreparacionPersonal(
    apagados: apagados,
    propios: [
      for (var i = 0; i < propios.length; i++)
        if (i != indice) propios[i],
    ],
    maxPropios: maxPropios,
    maxLargo: maxLargo,
  );

  PreparacionPersonal conActivo(String id, bool activo) => PreparacionPersonal(
    apagados: activo ? ({...apagados}..remove(id)) : {...apagados, id},
    propios: propios,
    maxPropios: maxPropios,
    maxLargo: maxLargo,
  );

  /// `hab_bici_perfil.preparacion`: lista de `{id, activo}` del catálogo y
  /// los puntos propios `{texto}`. Solo catálogo y textos: sin ubicación.
  Map<String, Object?> aJson() => {
    'catalogo': [
      for (final p in catalogoPreparacion)
        {'id': p.id, 'activo': !apagados.contains(p.id)},
    ],
    'propios': [
      for (final t in propios) {'texto': t},
    ],
  };

  static PreparacionPersonal desdeJson(Map<String, Object?> m) {
    final apagados = <String>{};
    for (final x in (m['catalogo'] as List?) ?? const []) {
      final fila = x as Map;
      if (fila['activo'] == false) apagados.add(fila['id'] as String);
    }
    final propios = [
      for (final x in (m['propios'] as List?) ?? const [])
        (x as Map)['texto'] as String,
    ];
    return PreparacionPersonal(apagados: apagados, propios: propios);
  }
}

/// Los puntos que se muestran, en el orden del catálogo y con los propios al
/// final. [momento] `null` = ambos; [superficie] `null` = todos los tipos de
/// ruta (el tipo sale de la ruta elegida o de la última salida; sin ninguno,
/// se muestran todos). Los puntos propios aparecen en **los dos momentos**.
List<PuntoPreparacion> puntosPreparacion({
  MomentoPreparacion? momento,
  SuperficieSalida? superficie,
  PreparacionPersonal personal = const PreparacionPersonal(),
}) {
  final r = <PuntoPreparacion>[
    for (final p in catalogoPreparacion)
      if ((momento == null || p.momento == momento) &&
          _aplica(p.aplicaA, superficie) &&
          !personal.apagados.contains(p.id))
        p,
  ];
  for (var i = 0; i < personal.propios.length; i++) {
    r.add(
      PuntoPreparacion(
        id: 'propio_${i + 1}',
        texto: personal.propios[i],
        momento: momento ?? MomentoPreparacion.viernes,
        propio: true,
      ),
    );
  }
  return r;
}

class ProgresoPreparacion {
  const ProgresoPreparacion(this.marcados, this.total);
  final int marcados;
  final int total;

  bool get completa => total > 0 && marcados == total;

  /// Un punto sin marcar **no bloquea nada** (RB6).
  bool get bloquea => false;
}

/// «Preparación (8 de 10)».
ProgresoPreparacion progresoPreparacion(
  List<PuntoPreparacion> puntos,
  Set<String> marcados,
) => ProgresoPreparacion(
  puntos.where((p) => marcados.contains(p.id)).length,
  puntos.length,
);

/// Marcar y desmarcar son un toque: si estaba, se quita; si no, se pone.
Set<String> alternarMarca(Set<String> marcados, String id) =>
    marcados.contains(id) ? ({...marcados}..remove(id)) : {...marcados, id};
