import 'package:habitos_dominio/habitos_dominio.dart';

final cat = catalogoGimnasio;

/// Lunes 30/nov/2026 (inicio de ciclo de los ejemplos de la especificación).
final lunes30nov = dia(2026, 11, 30);

const banda1 = BandaInventario(
  id: 'b1',
  nombre: 'verde',
  orden: 1,
  cantidad: 2,
);
const banda2 = BandaInventario(id: 'b2', nombre: 'azul', orden: 2);

/// Marcy, banco y caminadora, como viene la primera vez (F-E4).
Inventario inventarioBase() => Inventario.inicial();

Inventario conBandas({bool ancla = false, bool tobillera = false}) {
  var i = Inventario.inicial().conBandas(const [banda1, banda2]);
  if (ancla) i = i.conItem('ancla_puerta', EstadoItem.disponible);
  if (tobillera) i = i.conItem('tobillera_polea', EstadoItem.disponible);
  return i;
}

/// El Marcy sin ninguno de sus puestos (rotos, ocupados o de viaje).
Inventario sinEstacion(Inventario base) {
  var i = base;
  for (final p in const [
    'marcy.press',
    'marcy.polea_alta',
    'marcy.polea_baja',
    'marcy.cojin_curl',
  ]) {
    i = i.conItem(p, EstadoItem.noDisponible);
  }
  return i;
}

Inventario sinMarcy(Inventario base) =>
    sinEstacion(base).conItem('marcy_mwm7119', EstadoItem.noDisponible);

List<String> variantesDe(SesionPlanificada s) => [
  for (final e in s.ejercicios) e.varianteId,
];

SesionPlanificada generar(
  String plantilla, {
  VersionSesion version = VersionSesion.estandar,
  Inventario? inventario,
  DateTime? hoy,
  List<Molestia> molestias = const [],
  List<SesionRegistrada> historial = const [],
  bool modoFoco = false,
  PerfilGimnasio perfil = const PerfilGimnasio(),
  ReglasGimnasio reglas = const ReglasGimnasio(),
  List<Pausa> pausas = const [],
  List<DateTime> lunesEnFoco = const [],
  Set<String> ultimaPlaca = const {},
  Catalogo? catalogo,
}) => generarSesion(
  catalogo: catalogo ?? cat,
  plantillaId: plantilla,
  version: version,
  inventario: inventario ?? inventarioBase(),
  hoy: hoy ?? dia(2026, 12, 3),
  molestias: molestias,
  historial: historial,
  modoFoco: modoFoco,
  perfil: perfil,
  reglas: reglas,
  pausas: pausas,
  lunesEnFoco: lunesEnFoco,
  ultimaPlaca: ultimaPlaca,
);

/// Sesión hecha de un solo ejercicio (por omisión, el press de la A).
SesionRegistrada sesionHecha({
  required DateTime fecha,
  String plantilla = 'A',
  String ejercicio = 'press_pecho',
  String variante = 'press_pecho_estacion',
  List<int> reps = const [12, 12, 12],
  int? carga = 5,
  int? esfuerzoUltima = 3,
  int? esfuerzoSesion,
  TipoSemana tipo = TipoSemana.carga,
  EstadoSesion estado = EstadoSesion.completa,
  int? repsMin = 10,
  int? repsMax = 12,
  int? seriesPlan,
  String? bandaId,
  bool bandaDoble = false,
  List<int>? segundos,
  TiemposMedidos? tiempos,
  int? descansoReal,
}) {
  final n = segundos?.length ?? reps.length;
  return SesionRegistrada(
    fecha: fecha,
    plantilla: plantilla,
    version: VersionSesion.estandar,
    semanaTipo: tipo,
    estado: estado,
    esfuerzo: esfuerzoSesion,
    tiempos: tiempos,
    plan: [
      PlanEjercicioGuardado(
        ejercicioId: ejercicio,
        varianteId: variante,
        series: seriesPlan ?? n,
        repsMin: repsMin,
        repsMax: repsMax,
      ),
    ],
    series: [
      for (var i = 0; i < n; i++)
        SerieRegistrada(
          ejercicioId: ejercicio,
          varianteId: variante,
          n: i + 1,
          reps: segundos == null ? reps[i] : null,
          segundos: segundos?[i],
          cargaPasos: carga,
          bandaId: bandaId,
          bandaDoble: bandaDoble,
          esfuerzo: i == n - 1 ? esfuerzoUltima : null,
          descansoRealS: descansoReal,
        ),
    ],
  );
}

/// Un catálogo chico y totalmente `revisado` (o con una pieza en `borrador`),
/// para probar CA-G-05 y la alternativa sin la zona marcada.
Catalogo miniCatalogo({
  RevisionContenido? plantilla = RevisionContenido.revisado,
  RevisionContenido? ejercicio = RevisionContenido.revisado,
  RevisionContenido? variante = RevisionContenido.revisado,
  List<String> requiereSegunda = const [],
}) {
  Ejercicio ej(String id, List<String> zonas, List<Variante> vs) => Ejercicio(
    id: id,
    nombre: 'Ejercicio $id',
    patron: 'p',
    gruposPrimarios: const [Grupos.pecho],
    zonas: zonas,
    explicacion: 'Explicación breve.',
    repsMin: 8,
    repsMax: 12,
    variantes: vs,
    revision: ejercicio,
  );
  Variante va(
    String id, {
    List<String> requiere = const [],
    List<String>? zonas,
  }) => Variante(
    id: id,
    nombre: 'Variante $id',
    requiere: requiere,
    zonas: zonas,
    revision: variante,
  );
  Slot sl(String id, List<String> c) =>
      Slot(id: id, nombre: 'Slot $id', candidatas: c, repsMin: 8, repsMax: 12);
  return Catalogo(
    version: 1,
    items: cat.items,
    datosAparato: const [],
    ejercicios: [
      // x1: la primera variante carga la rodilla; la segunda, no.
      ej(
        'x1',
        const [Zonas.rodilla],
        [
          va('x1_a', requiere: const ['banco_inclinado']),
          va('x1_b', requiere: requiereSegunda, zonas: const [Zonas.cadera]),
        ],
      ),
      ej('x2', const [Zonas.codo], [va('x2_a')]),
      ej('x3', const [Zonas.hombro], [va('x3_a')]),
    ],
    plantillas: [
      PlantillaSesion(
        id: 'A',
        nombre: 'Mini',
        slots: [
          sl('A1', ['x1_a', 'x1_b']),
          sl('A2', ['x2_a']),
          sl('A3', ['x3_a']),
        ],
        revision: plantilla,
      ),
    ],
    regenerativas: const [],
    bloques: const [],
  );
}
