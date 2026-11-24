/// Del almacén local (filas de `hab_ent_*`) al dominio del gimnasio y de vuelta.
///
/// Todo lo que el dominio calcula (récords, ciclo, carga sugerida) se **deriva**
/// de estos hechos: aquí solo se traducen filas a tipos del dominio.
library;

import 'package:habitos_dominio/habitos_dominio.dart';

import '../../../../nucleo/base_local/base_local.dart';
import '../../../../nucleo/gimnasio/repositorio_gimnasio.dart';

/// `AAAA-MM-DD` de una fecha.
String fechaIso(DateTime f) =>
    '${f.year.toString().padLeft(4, '0')}-'
    '${f.month.toString().padLeft(2, '0')}-'
    '${f.day.toString().padLeft(2, '0')}';

/// El día de un `AAAA-MM-DD` (UTC a las 00:00, como `soloDia`).
DateTime fechaDeIso(String s) => soloDia(DateTime.parse(s));

/// `HH:MM` a minutos desde la medianoche.
int minutosDeHora(String hhmm) =>
    int.parse(hhmm.substring(0, 2)) * 60 + int.parse(hhmm.substring(3, 5));

String horaDeMinutos(int min) =>
    '${(min ~/ 60).toString().padLeft(2, '0')}:'
    '${(min % 60).toString().padLeft(2, '0')}';

/// Los campos que la persona confirma, y en qué aparato viven (3.2).
const camposDeAparato = <String, String>{
  CamposAparato.pasosMax: 'marcy_mwm7119',
  CamposAparato.kgPorPasoX10: 'marcy_mwm7119',
  CamposAparato.relacionPolea: 'marcy_mwm7119',
  CamposAparato.anclajeEstacion: 'marcy_mwm7119',
  CamposAparato.bancoPlano: 'banco_inclinado',
  CamposAparato.capacidadBancoKg: 'banco_inclinado',
};

/// Campo con la fecha en que se confirmó el aparato (ficha corta).
const campoConfirmadoEn = 'confirmado_en';

PerfilGimnasio perfilDeFila(GimPerfilFila? f) {
  if (f == null) return const PerfilGimnasio();
  T? porId<T>(Iterable<T> valores, String id, String Function(T) de) {
    for (final v in valores) {
      if (de(v) == id) return v;
    }
    return null;
  }

  return PerfilGimnasio(
    diasPlan: f.diasPlan,
    versionPreferida: VersionSesion.deId(f.versionPref),
    ventana:
        porId(VentanaEntrenamiento.values, f.ventana, (v) => v.id) ??
        VentanaEntrenamiento.noche,
    nocheDesdeMin: minutosDeHora(f.nocheDesde),
    objetivo:
        porId(ObjetivoGimnasio.values, f.objetivo, (v) => v.id) ??
        ObjetivoGimnasio.saludGeneral,
    nivel:
        porId(NivelGimnasio.values, f.nivel, (v) => v.id) ??
        NivelGimnasio.principiante,
    inicioCiclo: f.inicioCiclo == null ? null : fechaDeIso(f.inicioCiclo!),
    cicloSemanas: f.cicloSemanas,
    descansoS: f.descansoS,
    margenDormirMin: f.margenDormirMin,
  );
}

EstadoItem estadoDeItem(String estado) => switch (estado) {
  'no_disponible' => EstadoItem.noDisponible,
  'futuro' => EstadoItem.futuro,
  _ => EstadoItem.disponible,
};

String textoDeEstadoItem(EstadoItem e) => switch (e) {
  EstadoItem.disponible => 'disponible',
  EstadoItem.noDisponible => 'no_disponible',
  EstadoItem.futuro => 'futuro',
};

/// El inventario del dominio: arranca con el de la persona nueva (el Marcy con
/// sus cuatro puestos, el banco y la caminadora) y encima va lo que guardó.
/// Lo `confirmar` no entra: solo lo que la persona **confirmó** (CA-G-04).
Inventario inventarioDeFilas(
  List<GimInventarioFila> filas,
  List<GimBandaFila> bandas,
) {
  final items = {...Inventario.inicial().items};
  final conf = <String, int>{};
  for (final f in filas) {
    items[f.itemId] = estadoDeItem(f.estado);
    for (final e in f.confirmadoComoMapa.entries) {
      final v = e.value;
      if (v is int) conf[e.key] = v;
      if (v is bool) conf[e.key] = v ? 1 : 0;
    }
  }
  return Inventario(
    items: items,
    bandas: [
      for (final b in bandas)
        BandaInventario(
          id: b.id,
          nombre: b.nombre,
          orden: b.orden,
          cantidad: b.cantidad,
          activa: b.activa,
          resistenciaKgX10: b.resistenciaKgX10,
        ),
    ],
    confirmaciones: conf,
  );
}

SesionRegistrada sesionDeFila(
  GimSesionFila f,
  List<GimSerieFila> series, {
  ReglasGimnasio reglas = const ReglasGimnasio(),
}) {
  T? porId<T>(Iterable<T> valores, String id, String Function(T) de) {
    for (final v in valores) {
      if (de(v) == id) return v;
    }
    return null;
  }

  final t = f.tiemposComoMapa;
  return SesionRegistrada(
    fecha: fechaDeIso(f.fecha),
    plantilla: f.plantilla,
    version: VersionSesion.deId(f.version) ?? VersionSesion.estandar,
    semanaTipo:
        porId(TipoSemana.values, f.semanaTipo, (v) => v.id) ??
        TipoSemana.carga,
    ventana: porId(VentanaEntrenamiento.values, f.ventana, (v) => v.id),
    inicio: f.inicio,
    fin: f.fin,
    estado:
        porId(EstadoSesion.values, f.estado, (v) => v.id) ??
        EstadoSesion.completa,
    esfuerzo: f.esfuerzo,
    energia: f.energia,
    plan: [
      for (final p in f.planComoLista)
        PlanEjercicioGuardado(
          ejercicioId: p['ejercicio']! as String,
          varianteId: p['variante']! as String,
          series: p['series']! as int,
          repsMin: p['reps_min'] as int?,
          repsMax: p['reps_max'] as int?,
        ),
    ],
    series: [
      for (final s in series)
        SerieRegistrada(
          ejercicioId: s.ejercicioId,
          varianteId: s.varianteId,
          n: s.n,
          lado: s.lado,
          reps: s.reps,
          segundos: s.segundos,
          cargaPasos: s.cargaPasos,
          bandaId: s.bandaId,
          esfuerzo: s.esfuerzo,
          descansoRealS: s.descansoRealS,
          sustituyeA: s.sustituyeA,
          motivoCambio: s.motivoCambio == null
              ? null
              : porId(MotivoCambio.values, s.motivoCambio!, (v) => v.id),
        ),
    ],
    catalogoVersion: f.catalogoVersion,
    tiempos: t == null
        ? null
        : TiemposMedidos(
            segundosPorRepeticion:
                (t['seg_rep'] as int?) ?? reglas.segundosPorRepeticion,
            segundosCambio:
                (t['seg_cambio'] as int?) ?? reglas.segundosCambio,
          ),
  );
}

/// Las sesiones del dominio (con sus series) de las filas locales, de la más
/// antigua a la más nueva. Las `en_curso` se incluyen solo si [conEnCurso].
List<SesionRegistrada> historialDeFilas(
  List<GimSesionFila> sesiones,
  List<GimSerieFila> series, {
  bool conEnCurso = false,
}) {
  final porSesion = <String, List<GimSerieFila>>{};
  for (final s in series) {
    (porSesion[s.sesionId] ??= []).add(s);
  }
  final r = <SesionRegistrada>[
    for (final f in sesiones)
      if (conEnCurso || f.estado != 'en_curso')
        sesionDeFila(f, [
          ...?porSesion[f.id],
        ]..sort((a, b) => a.n.compareTo(b.n))),
  ]..sort((a, b) => a.fecha.compareTo(b.fecha));
  return r;
}
