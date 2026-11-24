/// Casos de uso de «Mi gimnasio» (Fase 8, G5): arma el estado desde el
/// repositorio local de G3, calcula con el dominio y guarda **primero en el
/// equipo** (la cola lo sube). Sin IA (D3) y sin red para entrenar.
///
/// - Lo que el dominio calcula (versión, carga sugerida, récords, tipo de
///   semana) **no se guarda**: se deriva al abrir (R4, PG-05).
/// - Las molestias solo se **leen** de este equipo para filtrar la sesión; no
///   se copian a nada que se guarde ni se envíe (R6): la sesión planeada que se
///   guarda es la que resume `aResumenPlan`, sin precauciones ni zonas.
library;

import 'package:habitos_dominio/habitos_dominio.dart' hide conflictos;
import 'package:habitos_dominio/habitos_dominio.dart' as dominio
    show conflictos;
import 'package:uuid/uuid.dart';

import '../../../../nucleo/base_local/base_local.dart';
import '../../../../nucleo/cola/cola_sin_conexion.dart';
import '../../../../nucleo/cola/contrato_habitos.dart';
import '../../../../nucleo/gimnasio/ids_gimnasio.dart';
import '../../../../nucleo/gimnasio/molestias_locales.dart';
import '../../../../nucleo/gimnasio/repositorio_gimnasio.dart';
import '../../datos/modelos.dart';
import '../../datos/modelos_agenda.dart';
import '../../datos/repositorio.dart';
import '../../datos/repositorio_agenda.dart';
import '../datos/conversion_gimnasio.dart';
import '../datos/lector_gimnasio.dart';
import '../datos/modelos_gimnasio.dart';
import 'modo_foco.dart';

/// La hora de dormir (8.2): hoy sale de `hab_ajustes.dormir`; cuando exista el
/// plan de transición del sueño, devolverá la de la semana en curso sin tocar
/// el generador.
abstract interface class FuenteHoraDormir {
  Future<int> para(DateTime fecha);
}

class HoraDormirDeAjustes implements FuenteHoraDormir {
  HoraDormirDeAjustes(this._agenda);
  final RepositorioAgenda _agenda;

  @override
  Future<int> para(DateTime fecha) async => (await _agenda.ajustes()).dormirMin;
}

/// Lo que se leyó de la agenda de Hábitos; con `leida == false` son los valores
/// por omisión (sin ajustes ni bloques).
class _LecturaAgenda {
  const _LecturaAgenda({
    required this.ajustes,
    required this.bloques,
    required this.leida,
  });

  final AjustesHab ajustes;
  final List<BloqueHab> bloques;
  final bool leida;
}

const _espacioHabitos = '6b1f8e0a-4c3d-5e2f-9a7b-1d2c3e4f5a6b';

/// Id estable del registro de un bloque en un día (el mismo que usa la agenda).
String idRegistroBloque(String bloqueId, DateTime fecha) =>
    const Uuid().v5(_espacioHabitos, 'bloque|$bloqueId|${fechaIso(fecha)}');

/// Id del objetivo «Entrenamiento» de una persona (PG-14): estable, para que
/// dos equipos converjan en el mismo objetivo.
String idObjetivoEntrenamiento(String persona) =>
    const Uuid().v5(_espacioHabitos, 'gimobjetivo|$persona');

/// Id del bloque de agenda del día [diaSemana] del plan de [persona].
String idBloqueEntrenamiento(String persona, int diaSemana) =>
    const Uuid().v5(_espacioHabitos, 'gimbloque|$persona|$diaSemana');

/// Los bloques que se cruzan con [nuevo] (el aviso no impide guardar).
List<Intervalo> conflictosDeAgenda(Intervalo nuevo, List<Intervalo> otros) =>
    dominio.conflictos(nuevo, otros);

/// Minutos de margen que se suman a la duración estimada al poner el bloque en
/// la agenda (8.1).
const margenBloqueMin = 10;

/// Minutos entre el final del bloque anterior y el inicio propuesto (llegar,
/// cambiarse). Con el día tipo del diseño (llegada ~19:00) cae a las 19:15.
const colchonInicioMin = 15;

PerfilGimnasio _perfilCon(PerfilGimnasio p, VersionSesion? version) =>
    PerfilGimnasio(
      diasPlan: p.diasPlan,
      versionPreferida: version,
      ventana: p.ventana,
      nocheDesdeMin: p.nocheDesdeMin,
      objetivo: p.objetivo,
      nivel: p.nivel,
      inicioCiclo: p.inicioCiclo,
      cicloSemanas: p.cicloSemanas,
      descansoS: p.descansoS,
      margenDormirMin: p.margenDormirMin,
    );

/// Lo hecho de un ejercicio al registrar después (E6): las series, las
/// repeticiones (o segundos) y la carga de todas.
typedef SerieHechaDespues = ({
  EjercicioPlanificado ejercicio,
  int series,
  int reps,
  int? cargaPasos,
  String? bandaId,
});

class ServicioGimnasio {
  ServicioGimnasio({
    required this.repo,
    required this.persona,
    required this.agenda,
    required this.registros,
    this.molestias,
    this.cola,
    this.lector = const LectorGimnasioNulo(),
    Future<ModoFocoActivo> Function()? foco,
    FuenteHoraDormir? dormir,
    DateTime Function()? ahora,
    Catalogo? catalogo,
    this.reglas = const ReglasGimnasio(),
  }) : foco = foco ?? (() async => const SinModoFoco()),
       dormir = dormir ?? HoraDormirDeAjustes(agenda),
       catalogo = catalogo ?? catalogoGimnasio,
       _ahora = ahora ?? DateTime.now;

  final RepositorioGimnasio repo;
  final String persona;
  final RepositorioAgenda agenda;
  final RepositorioHabitos registros;
  final MolestiasLocales? molestias;

  /// La cola sin conexión: donde queda lo que no se pudo escribir en Hábitos
  /// por falta de señal (el registro del día y el objetivo). Sin ella (pruebas
  /// de lo local) solo se avisa que quedó pendiente.
  final ColaSinConexion? cola;
  final LectorGimnasio lector;
  final Future<ModoFocoActivo> Function() foco;
  final FuenteHoraDormir dormir;
  final Catalogo catalogo;
  final ReglasGimnasio reglas;
  final DateTime Function() _ahora;

  DateTime get hoy => soloDia(_ahora());
  DateTime get ahora => _ahora();

  // ------------------------------------------------------------------ lectura

  Future<DatosGimnasio> cargar() async {
    final perfilFila = await repo.perfil(persona);
    final inv = await repo.inventario(persona);
    final bandas = await repo.bandas(persona);
    final planFilas = await repo.planDias(persona);
    final sesiones = await repo.sesiones(persona);
    final series = await repo.todasLasSeries(persona);
    final perfil = perfilDeFila(perfilFila);
    final porDia = {for (final f in planFilas) f.diaSemana: f};
    final base = planSemanal(perfil.diasPlan);
    final dias = [
      for (var d = 1; d <= 7; d++)
        DiaDelPlan(
          diaSemana: d,
          tipo: porDia[d]?.tipo ?? base.dia(d),
          version: porDia[d]?.version ?? 'auto',
          horaMin: porDia[d]?.hora == null
              ? null
              : minutosDeHora(porDia[d]!.hora!),
        ),
    ];
    return DatosGimnasio(
      persona: persona,
      perfilFila: perfilFila,
      perfil: perfil,
      inventarioFilas: inv,
      bandasFilas: bandas,
      inventario: inventarioDeFilas(inv, bandas),
      dias: dias,
      sesionesFilas: sesiones,
      seriesFilas: series,
      historial: historialDeFilas(sesiones, series),
      enCurso: sesiones.where((s) => s.estado == 'en_curso').firstOrNull,
    );
  }

  /// Baja del servidor lo de la persona y lo fusiona con lo local (último
  /// cambio gana). `false` si no se pudo (sin conexión): se sigue con lo local.
  Future<bool> bajarDelServidor() async {
    final f = await lector.leer();
    if (f == null) return false;
    await repo.fusionarDelServidor(
      persona,
      perfil: f.perfil,
      planDias: f.planDias,
      inventario: f.inventario,
      bandas: f.bandas,
      sesiones: f.sesiones,
      series: f.series,
    );
    return true;
  }

  // ------------------------------------------------------- perfil, inventario

  Future<void> guardarPerfil(Map<String, Object?> cambios) =>
      repo.guardarPerfil(persona, cambios);

  /// «Entendido»: se guarda la fecha en que la persona vio la guía (1.2).
  Future<void> aceptarAviso() =>
      guardarPerfil({'aviso_visto_en': ahora.toUtc().toIso8601String()});

  /// La fila del inventario **de ahora** (no la de una lectura vieja): varias
  /// confirmaciones seguidas del mismo aparato no se pisan.
  Future<GimInventarioFila?> _filaDeInventario(String itemId) async =>
      (await repo.inventario(persona)).where((f) => f.itemId == itemId).firstOrNull;

  Future<void> guardarEstadoItem(
    DatosGimnasio d,
    String itemId,
    EstadoItem estado,
  ) async {
    final previo = await _filaDeInventario(itemId);
    return repo.guardarItemInventario(
      persona,
      itemId: itemId,
      estado: textoDeEstadoItem(estado),
      confirmado: previo?.confirmadoComoMapa ?? const {},
      notas: previo?.notas,
    );
  }

  /// «Confirmar en el aparato» (F-E5): guarda el [valor] del [campo] en el
  /// aparato al que pertenece, con la fecha. Solo entonces entra a un cálculo.
  Future<void> confirmarDato(DatosGimnasio d, String campo, int valor) async {
    final itemId = camposDeAparato[campo];
    if (itemId == null) throw ArgumentError('Ese dato no se confirma aquí.');
    final previo = await _filaDeInventario(itemId);
    return repo.guardarItemInventario(
      persona,
      itemId: itemId,
      estado: previo?.estado ?? 'disponible',
      confirmado: {
        ...?previo?.confirmadoComoMapa,
        campo: valor,
        campoConfirmadoEn: fechaIso(hoy),
      },
      notas: previo?.notas,
    );
  }

  /// Quita una confirmación (vuelve a «confirmar en el aparato»).
  Future<void> olvidarDato(DatosGimnasio d, String campo) async {
    final itemId = camposDeAparato[campo];
    if (itemId == null) return;
    final previo = await _filaDeInventario(itemId);
    if (previo == null) return;
    return repo.guardarItemInventario(
      persona,
      itemId: itemId,
      estado: previo.estado,
      confirmado: {...previo.confirmadoComoMapa}..remove(campo),
      notas: previo.notas,
    );
  }

  /// Un puesto suelto del Marcy que la persona agrega (`otro:<texto>`).
  Future<void> agregarPuestoSuelto(String nombre) {
    final t = nombre.trim().replaceAll(RegExp(r'[\x00-\x1f\x7f]'), ' ');
    if (t.isEmpty || t.length > 55) {
      throw ArgumentError('El nombre va de 1 a 55 caracteres.');
    }
    return repo.guardarItemInventario(
      persona,
      itemId: 'otro:$t',
      estado: 'disponible',
    );
  }

  Future<String> guardarBanda(
    DatosGimnasio d, {
    String? id,
    required String nombre,
    int? orden,
    int? resistenciaKgX10,
    int cantidad = 1,
    bool activa = true,
  }) {
    final n = nombre.trim();
    if (n.isEmpty || n.length > 40) {
      throw ArgumentError('El nombre va de 1 a 40 caracteres.');
    }
    final siguiente = d.bandasFilas.isEmpty
        ? 1
        : (d.bandasFilas.map((b) => b.orden).reduce((a, b) => a > b ? a : b) + 1)
              .clamp(1, 20);
    return repo.guardarBanda(
      persona,
      id: id,
      nombre: n,
      orden: orden ?? siguiente,
      resistenciaKgX10: resistenciaKgX10,
      cantidad: cantidad,
      activa: activa,
    );
  }

  Future<void> borrarBanda(String id) => repo.borrarBanda(persona, id);

  // --------------------------------------------------------------------- plan

  /// El plan por omisión de 3, 4 o 5 días (5.6). Conserva la versión y la hora
  /// de los días que siguen igual.
  Future<void> elegirDiasDelPlan(DatosGimnasio d, int dias) async {
    final nuevo = planSemanal(dias);
    await guardarPerfil({'dias_plan': dias});
    for (var dia = 1; dia <= 7; dia++) {
      final actual = d.dia(dia);
      final igual = actual.tipo == nuevo.dia(dia);
      await repo.guardarPlanDia(
        persona,
        diaSemana: dia,
        tipo: nuevo.dia(dia),
        version: igual ? actual.version : 'auto',
        hora: igual && actual.horaMin != null
            ? horaDeMinutos(actual.horaMin!)
            : null,
      );
    }
  }

  Future<void> guardarDiaDelPlan(
    DiaDelPlan dia, {
    String? version,
    int? horaMin,
    bool quitarHora = false,
  }) => repo.guardarPlanDia(
    persona,
    diaSemana: dia.diaSemana,
    tipo: dia.tipo,
    version: version ?? dia.version,
    hora: quitarHora
        ? null
        : (horaMin ?? dia.horaMin) == null
        ? null
        : horaDeMinutos(horaMin ?? dia.horaMin!),
  );

  /// El plan empieza el lunes de esta semana (el ciclo cuenta desde ahí).
  Future<void> iniciarPlan() =>
      guardarPerfil({'inicio_ciclo': fechaIso(lunesDe(hoy))});

  // ---------------------------------------------------------- agenda y bloque

  /// Lee la agenda de Hábitos (ajustes y bloques). **Sin señal no es un error**
  /// (G6-A1, 9.1): la sesión se arma con el plan y el equipo de este equipo, con
  /// los ajustes por omisión y sin bloques; `leida` dice que no se pudo leer,
  /// para avisarlo sin culpa. No se inventan bloques ocupados que no se vieron.
  Future<_LecturaAgenda> _leerAgenda() async {
    try {
      final aj = await agenda.ajustes();
      final bloques = await agenda.bloques();
      return _LecturaAgenda(ajustes: aj, bloques: bloques, leida: true);
    } on Exception {
      return const _LecturaAgenda(
        ajustes: AjustesHab(),
        bloques: <BloqueHab>[],
        leida: false,
      );
    }
  }

  /// El bloque de la agenda de [fecha] que es del plan de entrenamiento (`null`
  /// también si la agenda no se pudo leer).
  Future<BloqueHab?> bloqueDe(DateTime fecha) async =>
      _bloqueEn((await _leerAgenda()).bloques, fecha);

  BloqueHab? _bloqueEn(List<BloqueHab> bloques, DateTime fecha) {
    final f = soloDia(fecha);
    final id = idBloqueEntrenamiento(persona, f.weekday);
    for (final b in bloques) {
      if (b.id == id && b.activo && b.recurrente.ocurreEn(f)) return b;
    }
    return null;
  }

  List<Intervalo> _ocupadosEn(List<BloqueHab> bloques, DateTime f) => [
    for (final b in bloques)
      if (b.activo &&
          b.recurrente.ocurreEn(f) &&
          b.id != idBloqueEntrenamiento(persona, f.weekday))
        Intervalo(b.inicioMin, b.inicioMin + b.duracionMin),
  ];

  /// Dónde cabe el entrenamiento ese día (8.1): el primer hueco libre a partir
  /// de `noche_desde` (o antes de la salida, con la ventana de mañana). El
  /// inicio deja [colchonInicioMin] minutos tras el bloque anterior.
  Future<({int inicioMin, int disponibleMin})?> _hueco(
    DateTime f,
    PerfilGimnasio p,
    AjustesHab aj,
    List<Intervalo> ocupados,
  ) async {
    final huecos = huecosLibres(
      aj.despertarMin,
      // Dormir pasada la medianoche (00:30) es del día siguiente (G6-M4).
      dormirNormalizadoMin(aj.dormirMin, despertarMin: aj.despertarMin),
      ocupados,
      minimoMin: 20,
    )..sort((a, b) => a.inicio.compareTo(b.inicio));
    ({int inicioMin, int disponibleMin})? deNoche() {
      for (final h in huecos) {
        if (h.fin <= p.nocheDesdeMin) continue;
        final ini = h.inicio + colchonInicioMin > p.nocheDesdeMin
            ? h.inicio + colchonInicioMin
            : (h.inicio >= p.nocheDesdeMin ? h.inicio : p.nocheDesdeMin);
        if (h.fin - ini >= 20) {
          return (inicioMin: ini, disponibleMin: h.fin - ini);
        }
      }
      return null;
    }

    ({int inicioMin, int disponibleMin})? deManana() {
      for (final h in huecos) {
        if (h.inicio >= reglas.ventanaMananaHastaMin) break;
        final ini = h.inicio + colchonInicioMin;
        if (h.fin - ini >= 20) {
          return (inicioMin: ini, disponibleMin: h.fin - ini);
        }
      }
      return null;
    }

    switch (p.ventana) {
      case VentanaEntrenamiento.noche:
        return deNoche();
      case VentanaEntrenamiento.manana:
        return deManana();
      case VentanaEntrenamiento.flexible:
        final n = deNoche();
        final m = deManana();
        if (n == null) return m;
        if (m == null) return n;
        return m.disponibleMin > n.disponibleMin ? m : n;
    }
  }

  /// Minutos libres desde [inicioMin] hasta lo siguiente que está ocupado (o
  /// hasta dormir). 0 si [inicioMin] cae dentro de algo.
  int _libreDesde(int inicioMin, List<Intervalo> ocupados, int dormirMin) {
    var fin = dormirMin;
    for (final o in ocupados) {
      if (o.inicio <= inicioMin && inicioMin < o.fin) return 0;
      if (o.inicio >= inicioMin && o.inicio < fin) fin = o.inicio;
    }
    return fin - inicioMin;
  }

  // -------------------------------------------------------- el día de entrenar

  EstadoEntrenamientoDia _estadoDe(GimSesionFila? f) => switch (f?.estado) {
    'en_curso' => EstadoEntrenamientoDia.enCurso,
    'completa' => EstadoEntrenamientoDia.hecho,
    'parcial' => EstadoEntrenamientoDia.parcial,
    _ => EstadoEntrenamientoDia.pendiente,
  };

  /// Lo que toca el día [fecha] con el equipo y las molestias de este equipo.
  /// [tipo] cambia la plantilla (por ejemplo, la regenerativa en un día de
  /// fuerza); [version] fuerza una versión (*Versión corta*).
  Future<EntrenamientoHoy> entrenamientoDe(
    DateTime fecha, {
    DatosGimnasio? datos,
    String? tipo,
    VersionSesion? version,
  }) async {
    final d = datos ?? await cargar();
    final f = soloDia(fecha);
    final dia = d.dia(f.weekday);
    final plantilla = tipo ?? dia.tipo;
    final iso = fechaIso(f);
    final fila = d.sesionesFilas
        .where((s) => s.fecha == iso && s.plantilla == plantilla)
        .firstOrNull;
    final estado = _estadoDe(fila);
    final esSesion = TipoDia.fuerza.contains(plantilla) ||
        plantilla == TipoDia.r1 ||
        plantilla == TipoDia.r2;
    if (!esSesion) {
      return EntrenamientoHoy(fecha: f, tipo: plantilla, estado: estado);
    }
    final deLaAgenda = await _leerAgenda();
    final aj = deLaAgenda.ajustes;
    final bloque = _bloqueEn(deLaAgenda.bloques, f);
    final ocupados = _ocupadosEn(deLaAgenda.bloques, f);
    final horaPlan = tipo == null ? dia.horaMin : null;
    final hueco = await _hueco(f, d.perfil, aj, ocupados);
    final inicio = horaPlan ?? hueco?.inicioMin;
    final disponible = horaPlan != null
        ? _libreDesde(
            horaPlan,
            ocupados,
            dormirNormalizadoMin(aj.dormirMin, despertarMin: aj.despertarMin),
          )
        : (hueco?.disponibleMin ?? 0);

    if (plantilla == TipoDia.r1 || plantilla == TipoDia.r2) {
      final r = generarRegenerativa(
        catalogo: catalogo,
        plantillaId: plantilla,
        inventario: d.inventario,
      );
      return EntrenamientoHoy(
        fecha: f,
        tipo: plantilla,
        estado: estado,
        regenerativa: r,
        version: VersionSesion.estandar,
        inicioMin: inicio,
        horaDelPlan: horaPlan != null,
        noCabe: inicio == null || disponible < r.minutos + margenBloqueMin,
        bloque: bloque,
        filaSesion: fila,
        agendaSinLeer: !deLaAgenda.leida,
      );
    }

    // Fuerza: el modo foco y las molestias solo existen en este equipo.
    final modoFoco = await foco();
    final lectura = await molestias?.leer();
    final activas = lectura?.activas ?? const <Molestia>[];
    final enFoco = modoFoco.para(f);
    final lunes = modoFoco.lunesEnFoco(d.perfil.inicioCiclo ?? f, f);
    final porDia = VersionSesion.deId(dia.version);
    final perfil = porDia != null ? _perfilCon(d.perfil, porDia) : d.perfil;

    EleccionVersion? eleccion;
    VersionSesion v;
    if (version != null) {
      v = version;
    } else {
      eleccion = elegirVersion(
        catalogo: catalogo,
        plantillaId: plantilla,
        inventario: d.inventario,
        hoy: f,
        huecoMin: disponible,
        molestias: activas,
        historial: d.historial,
        modoFoco: enFoco,
        perfil: perfil,
        reglas: reglas,
        lunesEnFoco: lunes,
      );
      v = eleccion.version ?? perfil.versionPreferida ?? VersionSesion.corta;
    }
    final sesion = generarSesion(
      catalogo: catalogo,
      plantillaId: plantilla,
      version: v,
      inventario: d.inventario,
      hoy: f,
      molestias: activas,
      historial: d.historial,
      modoFoco: enFoco,
      perfil: d.perfil,
      reglas: reglas,
      lunesEnFoco: lunes,
    );
    AvisoDormir? aviso;
    if (inicio != null) {
      final ventana = d.perfil.ventana == VentanaEntrenamiento.flexible
          ? ventanaDeInicio(inicio, reglas: reglas)
          : d.perfil.ventana;
      aviso = avisoDormir(
        finMin: finEstimadoMin(inicio, sesion.duracionEstimadaSeg),
        dormirMin: await _horaDeDormir(f, aj),
        margenMin: d.perfil.margenDormirMin,
        ventana: ventana,
        esCorta: v == VersionSesion.corta,
      );
    }
    return EntrenamientoHoy(
      fecha: f,
      tipo: plantilla,
      estado: estado,
      sesion: sesion,
      eleccion: eleccion,
      version: v,
      inicioMin: inicio,
      horaDelPlan: horaPlan != null,
      avisoDormir: aviso,
      noCabe: eleccion != null && !eleccion.cabe,
      bloque: bloque,
      filaSesion: fila,
      molestiasLegibles:
          lectura == null || (lectura.enEsteEquipo && !lectura.bloqueada),
      modoFocoLegible: modoFoco.legible,
      modoFoco: enFoco,
      agendaSinLeer: !deLaAgenda.leida,
    );
  }

  /// La hora de dormir de [f]; si la fuente no se puede leer (sin señal), la de
  /// los ajustes ya leídos (o la de omisión).
  Future<int> _horaDeDormir(DateTime f, AjustesHab aj) async {
    try {
      return await dormir.para(f);
    } on Exception {
      return aj.dormirMin;
    }
  }

  /// ¿Cuenta como un elemento de Hoy, y cuántos hechos? (`habitos.resumen_hoy`:
  /// solo el conteo, sin cargas ni molestias.)
  Future<({int total, int hechos})> conteoDeHoy() async {
    final d = await cargar();
    final dia = d.dia(hoy.weekday);
    if (!dia.esSesion) return (total: 0, hechos: 0);
    final iso = fechaIso(hoy);
    final fila = d.sesionesFilas
        .where((s) => s.fecha == iso && s.plantilla == dia.tipo)
        .firstOrNull;
    final hecho = fila != null && fila.estado != 'en_curso';
    return (total: 1, hechos: hecho ? 1 : 0);
  }

  // ------------------------------------------------------------------ agenda

  /// *Poner en mi agenda* (8.1): un bloque recurrente por cada día de fuerza o
  /// regenerativa del plan, con duración = estimada + 10 min. Los conflictos
  /// **avisan y no impiden guardar**.
  Future<ResultadoAgenda> ponerEnMiAgenda(DatosGimnasio d) async {
    await _asegurarObjetivo(d);
    final objetivoId = idObjetivoEntrenamiento(persona);
    final conflictos = <int>[];
    var creados = 0;
    for (final dia in d.dias.where((x) => x.esSesion)) {
      // La próxima fecha con ese día de la semana (hoy cuenta).
      final fecha = sumarDias(hoy, (dia.diaSemana - hoy.weekday + 7) % 7);
      final h = await entrenamientoDe(fecha, datos: d);
      if (h.inicioMin == null || h.duracionSeg == null) continue;
      final dur = (h.duracionSeg! + 59) ~/ 60 + margenBloqueMin;
      final id = idBloqueEntrenamiento(persona, dia.diaSemana);
      final ocupados = [
        for (final b in await agenda.bloques())
          if (b.activo && b.recurrente.ocurreEn(fecha) && b.id != id)
            Intervalo(b.inicioMin, b.inicioMin + b.duracionMin),
      ];
      if (_seCruza(h.inicioMin!, dur, ocupados)) conflictos.add(dia.diaSemana);
      await agenda.guardarBloque(
        BloqueHab(
          id: id,
          titulo: 'Entrenamiento · ${_nombreDeTipo(dia.tipo)}',
          area: 'salud',
          tipo: 'actividad',
          inicioMin: h.inicioMin!,
          duracionMin: dur,
          dias: 1 << (dia.diaSemana - 1),
          desde: fecha,
          objetivoId: objetivoId,
          modificadoEn: ahora.toUtc(),
        ),
      );
      creados++;
    }
    return ResultadoAgenda(bloques: creados, conflictos: conflictos);
  }

  bool _seCruza(int inicio, int dur, List<Intervalo> ocupados) =>
      conflictosDeAgenda(Intervalo(inicio, inicio + dur), ocupados).isNotEmpty;

  String _nombreDeTipo(String tipo) =>
      catalogo.plantilla(tipo)?.nombre ??
      catalogo.regenerativa(tipo)?.nombre ??
      tipo;

  /// Que exista el objetivo «Entrenamiento». `true` si no se pudo escribir en
  /// Hábitos (sin señal) y quedó en la cola para reponerlo sin pisar nada.
  Future<bool> _asegurarObjetivo(DatosGimnasio d) async {
    final id = idObjetivoEntrenamiento(persona);
    final objetivo = ObjetivoHab(
      id: id,
      titulo: 'Entrenamiento',
      area: 'salud',
      tipo: TipoObjetivo.construir,
      fechaInicio: hoy,
      unidad: 'sesiones',
      metaValor: d.dias.where((x) => x.esFuerza).length,
      frecuencia: Frecuencia.nPorSemana,
      modificadoEn: ahora.toUtc(),
    );
    try {
      final existe = (await registros.objetivos()).any((o) => o.id == id);
      if (existe) return false;
      await registros.guardarObjetivo(objetivo);
      return false;
    } on Exception {
      // Sin señal: queda en este equipo y se envía al volver. La cola lo
      // inserta sin pisar (si la persona ya lo cambió, no se deshace).
      await _encolarObjetivo(objetivo);
      return true;
    }
  }

  /// Guarda el registro del día en Hábitos; si no se puede (sin señal), lo deja
  /// en la cola y devuelve `true` (G6-A1: lo registrado nunca se pierde).
  Future<bool> _guardarRegistroOEncolar(RegistroHab r) async {
    try {
      await registros.guardarRegistro(r);
      return false;
    } on Exception {
      await _encolarRegistro(r);
      return true;
    }
  }

  /// Con la cola, queda para subir (mismo cambio, misma entrada: idempotente;
  /// otro cambio del mismo día, otra entrada: gana el `modificado_en` más
  /// reciente). Sin cola (pruebas de lo local) no hay dónde dejarlo.
  Future<void> _encolarRegistro(RegistroHab r) async {
    final c = cola;
    if (c == null) return;
    await c.encolar(
      tipo: TipoColaHabitos.registro,
      id: const Uuid().v5(
        _espacioHabitos,
        'cola|${TipoColaHabitos.registro}|${r.id}|'
        '${r.modificadoEn.toUtc().millisecondsSinceEpoch}|${r.estado.name}',
      ),
      carga: r.aFila(),
      personaId: persona,
    );
  }

  /// El objetivo se encola con **su** id como id de la entrada: aunque se
  /// intente varias veces sin señal, queda una sola.
  Future<void> _encolarObjetivo(ObjetivoHab o) async {
    final c = cola;
    if (c == null) return;
    await c.encolar(
      tipo: TipoColaHabitos.objetivo,
      id: o.id,
      carga: o.aFila(),
      personaId: persona,
    );
  }

  // ------------------------------------------------------------------ sesión

  String idSesion(DateTime fecha, String plantilla) =>
      IdsGimnasio.sesion(persona, fecha, plantilla);

  /// Empieza (o retoma) la sesión: queda guardada `en_curso` en el equipo antes
  /// de la primera serie, para retomarla si la tablet vuelve a Casa (PG-17).
  Future<GimSesionFila> iniciarSesion(
    EntrenamientoHoy h, {
    DateTime? inicio,
  }) async {
    final actual = h.filaSesion;
    if (actual != null && actual.estado == 'en_curso') return actual;
    inicio ??= ahora;
    final s = SesionRegistrada(
      fecha: h.fecha,
      plantilla: h.tipo,
      version: h.version ?? VersionSesion.estandar,
      semanaTipo: h.semanaTipo,
      inicio: inicio,
      estado: EstadoSesion.enCurso,
      plan: _resumenPlan(h),
      catalogoVersion: versionCatalogo,
    );
    return repo.guardarSesion(
      persona,
      s.aJsonServidor(
        id: idSesion(h.fecha, h.tipo),
        bloqueId: h.bloque?.id,
      ),
    );
  }

  List<PlanEjercicioGuardado> _resumenPlan(EntrenamientoHoy h) =>
      h.sesion?.aResumenPlan() ?? const [];

  /// Guarda una serie hecha. [descansoRealS] es el descanso que se tomó antes.
  Future<String> registrarSerie({
    required String sesionId,
    required EjercicioPlanificado ejercicio,
    required String varianteId,
    required int n,
    int? reps,
    int? segundos,
    int? cargaPasos,
    String? bandaId,
    int? descansoRealS,
    String? sustituyeA,
    MotivoCambioLocal? motivo,
  }) {
    final serie = SerieRegistrada(
      ejercicioId: catalogo.ejercicioDeVariante(varianteId)?.id ??
          ejercicio.ejercicioId,
      varianteId: varianteId,
      n: n,
      reps: reps,
      segundos: segundos,
      cargaPasos: cargaPasos,
      bandaId: bandaId,
      descansoRealS: descansoRealS,
      sustituyeA: sustituyeA,
      // «molestia» se guarda como «otra»: el servidor nunca la conoce (PG-19).
      motivoCambio: motivo?.paraServidor,
    );
    final ejercicioId = serie.ejercicioId;
    return repo.guardarSerie(
      persona,
      serie.aJsonServidor(
        id: IdsGimnasio.serie(persona, sesionId, ejercicioId, n),
        sesionId: sesionId,
      ),
    );
  }

  Future<void> deshacerSerie(String serieId) =>
      repo.borrarSerie(persona, serieId);

  /// El esfuerzo (1 a 5) de un ejercicio, en su última serie (opcional).
  Future<void> esfuerzoDeSerie(String serieId, int esfuerzo) async {
    final s = (await repo.todasLasSeries(persona))
        .where((x) => x.id == serieId)
        .firstOrNull;
    if (s == null) return;
    await repo.guardarSerie(persona, {...s.aMapaServidor(), 'esfuerzo': esfuerzo});
  }

  /// Termina la sesión: «Terminé la sesión» (`completa`) o «Terminé una parte»
  /// (`parcial`), sin juzgar cuántas series fueron (PG-13). Escribe el registro
  /// del bloque y del objetivo, así Hoy, la racha y el progreso siguen igual.
  Future<ResultadoSesion> terminarSesion({
    required GimSesionFila fila,
    required EntrenamientoHoy h,
    required bool completa,
    int? esfuerzo,
    int? energia,
    TiemposMedidos? tiempos,
    List<PlanEjercicioGuardado>? plan,
    DateTime? fin,
  }) async {
    final d = await cargar();
    final previas = [
      for (final s in d.historial)
        if (!(s.fecha == soloDia(h.fecha) && s.plantilla == h.tipo)) s,
    ];
    fin ??= ahora;
    final estado = completa ? EstadoSesion.completa : EstadoSesion.parcial;
    final json = {
      ...fila.aMapaServidor(),
      'fin': fin.toUtc().toIso8601String(),
      'estado': estado.id,
      'esfuerzo': esfuerzo,
      'energia': energia,
      'plan': plan == null
          ? fila.planComoLista
          : [for (final p in plan) p.aJson()],
    };
    final guardada = await repo.guardarSesion(
      persona,
      json,
      tiempos: tiempos == null
          ? null
          : {
              'seg_rep': tiempos.segundosPorRepeticion,
              'seg_cambio': tiempos.segundosCambio,
            },
    );
    final enviarDespues = await _registrarDia(
      h.fecha,
      completa ? EstadoRegistro.hecho : EstadoRegistro.parcial,
      bloqueId: h.bloque?.id ?? guardada.bloqueId,
      d: d,
      esFuerza: h.esFuerza,
    );
    final nueva = sesionDeFila(
      guardada,
      [
        for (final s in d.seriesFilas)
          if (s.sesionId == guardada.id) s,
      ],
      reglas: reglas,
    );
    return ResultadoSesion(
      records: h.esFuerza
          ? recordsNuevos(
              previas,
              nueva,
              catalogo,
              bandas: d.inventario.bandas,
            )
          : const [],
      estado: estado,
      enviarDespues: enviarDespues,
    );
  }

  /// Escribe el registro del bloque y del objetivo. `true` si algo no se pudo
  /// escribir ahora (sin señal) y quedó en la cola para enviarse después.
  Future<bool> _registrarDia(
    DateTime fecha,
    EstadoRegistro estado, {
    String? bloqueId,
    required DatosGimnasio d,
    required bool esFuerza,
  }) async {
    final f = soloDia(fecha);
    var pendiente = false;
    if (bloqueId != null) {
      pendiente |= await _guardarRegistroOEncolar(
        RegistroHab(
          id: idRegistroBloque(bloqueId, f),
          bloqueId: bloqueId,
          fecha: f,
          estado: estado,
          modificadoEn: ahora.toUtc(),
        ),
      );
    }
    // El objetivo «Entrenamiento» cuenta las sesiones de fuerza de la semana
    // (las regenerativas no rompen ni suman: PG-14).
    if (esFuerza) {
      pendiente |= await _asegurarObjetivo(d);
      pendiente |= await _guardarRegistroOEncolar(
        RegistroHab(
          id: idRegistro(idObjetivoEntrenamiento(persona), f),
          objetivoId: idObjetivoEntrenamiento(persona),
          fecha: f,
          estado: estado,
          modificadoEn: ahora.toUtc(),
        ),
      );
    }
    return pendiente;
  }

  /// *Hecho* en Hoy (F-E1): un toque, sin registrar series. Deja una sesión
  /// `completa` sin series (el historial la cuenta; la progresión no, porque no
  /// hay cargas) y marca el bloque.
  Future<ResultadoSesion> marcarHecho(EntrenamientoHoy h) async {
    final fila = await iniciarSesion(h);
    return terminarSesion(fila: fila, h: h, completa: true);
  }

  /// Deshacer *Hecho*: quita la sesión sin series y vuelve el día a pendiente.
  Future<void> deshacerHecho(EntrenamientoHoy h) async {
    final d = await cargar();
    final id = idSesion(h.fecha, h.tipo);
    final tieneSeries = d.seriesFilas.any((s) => s.sesionId == id);
    if (!tieneSeries) await repo.borrarSesion(persona, id);
    await _registrarDia(
      h.fecha,
      EstadoRegistro.pendiente,
      bloqueId: h.bloque?.id,
      d: d,
      esFuerza: h.esFuerza,
    );
  }

  /// Registrar lo que hice después (E6): [series] ya con lo hecho.
  Future<ResultadoSesion> registrarDespues({
    required EntrenamientoHoy h,
    required List<SerieHechaDespues> hecho,
    required bool completa,
    int? esfuerzo,
    int? energia,
  }) async {
    // Una sesión de otro día: empieza a la hora del plan y dura lo estimado; si
    // eso cae en el futuro, termina ahora.
    final dur = Duration(seconds: h.duracionSeg ?? 45 * 60);
    final min = h.inicioMin ?? (19 * 60 + 15);
    var inicio = DateTime(h.fecha.year, h.fecha.month, h.fecha.day, 0, min);
    var fin = inicio.add(dur);
    if (fin.isAfter(ahora)) {
      fin = ahora;
      inicio = ahora.subtract(dur);
    }
    final fila = await iniciarSesion(h, inicio: inicio);
    for (final e in hecho) {
      for (var n = 1; n <= e.series; n++) {
        await registrarSerie(
          sesionId: fila.id,
          ejercicio: e.ejercicio,
          varianteId: e.ejercicio.varianteId,
          n: n,
          reps: e.ejercicio.porTiempo ? null : e.reps,
          segundos: e.ejercicio.porTiempo ? e.reps : null,
          cargaPasos: e.cargaPasos,
          bandaId: e.bandaId,
        );
      }
    }
    return terminarSesion(
      fila: fila,
      h: h,
      completa: completa,
      esfuerzo: esfuerzo,
      energia: energia,
      fin: fin,
    );
  }
}
