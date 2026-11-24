/// Piezas comunes de las pantallas de «Mi gimnasio»: marco, estados de carga y
/// los textos que se arman con el catálogo del dominio.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habitos_dominio/habitos_dominio.dart';

import '../../../../app/gimnasio/acceso_gimnasio.dart';
import '../../../../app/pantallas/marco_pantalla.dart';
import '../../../../diseno/gimnasio/gimnasio.dart';
import '../../../../diseno/personalidad_modulo.dart';
import '../../../../diseno/tema_modulo.dart';
import '../../../../nucleo/contratos/roles.dart';
import '../../../../nucleo/contratos/rutas.dart';
import '../datos/conversion_gimnasio.dart';
import '../datos/modelos_gimnasio.dart';

/// Textos de la interfaz de «Mi gimnasio» que el dominio y el diseño no traen.
/// Sin signos de exclamación y sin palabras que culpan (CA-G-40).
abstract final class TextosHabitosGimnasio {
  static const sinSesion = 'Nadie ha entrado en este equipo.';
  static const entendido = 'Entendido';
  static const guiaTitulo = 'Antes de empezar';
  static const modoFocoNoLegible =
      'No se pudo leer el modo foco en este equipo.';
  static const hoyBicicleta = 'Hoy toca bicicleta.';
  static const hoyDescanso = 'Hoy es de descanso. Es parte del plan.';
  static const hoyNoHayPlan = 'Hoy no toca fuerza en tu plan.';
  static const guardadoDeshacer = 'Guardado';
  static const empezarPlan = 'Empezar mi plan esta semana';
  static const ponerEnAgenda = 'Poner en mi agenda';
  static const agendaListo = 'Puse tu plan en la agenda.';
  static const agendaConflicto =
      'Algún día se cruza con otro bloque. Lo guardé igual; puedes moverlo.';
  static const comoAmaneciste = '¿Cómo amaneciste?';
  static const descansado = 'Descansado';
  static const normal = 'Normal';
  static const cansado = 'Cansado';
  static const proponemosRegenerativa =
      'Hoy te proponemos la sesión regenerativa.';
  static const verRegenerativa = 'Ver la regenerativa';
  static const listo = 'Listo';
  static const calentamiento = 'Calentamiento';
  static const calentamientoAyuda =
      'Entra en calor con calma y toca Listo cuando quieras empezar.';
  static const terminar = 'Terminar';
  static const terminoSesion = 'Terminé la sesión';
  static const terminoParte = 'Terminé una parte';
  static const cambiarEjercicio = 'Cambiar ejercicio';
  static const versionCorta = 'Versión corta';
  static const guardadoEnElEquipo =
      'Guardado en este equipo; se sube al volver la señal.';
  static const esfuerzoDelEjercicio = 'Esfuerzo del ejercicio';
  static const omitir = 'Omitir';
  static const sesionTerminada = 'Sesión guardada. Un paso más.';
  static const todoComoPlaneado = 'Todo como estaba planeado';
  static const registrarLoQueHice = 'Registrar lo que hice';
  static const guardar = 'Guardar';
  static const sinHistorial = 'Todavía no hay sesiones guardadas.';
  static const sinRecords = 'Los récords aparecen cuando guardes tus series.';
  static const molestiaZona = 'Zona';
  static const molestiaIntensidad = 'Intensidad';
  static const molestiaAgregar = 'Agregar una molestia';
  static const molestiaVacia = 'No has registrado ninguna molestia.';
  static const molestiaNota = 'Nota (solo en este equipo)';
  static const molestiaBloqueada =
      'Escribe tu PIN para abrir lo reservado y ver tus molestias.';
  static const ajustesCiclo = 'Semanas del ciclo (carga y descarga)';
  static const ajustesSinDescarga = 'Sin descarga programada';
  static const ajustesVoz = 'Voz en el descanso';
  static const ajustesVozAyuda =
      'Apagada por omisión: dice el siguiente ejercicio cuando exista el '
      'motor de voz.';
  static const sobreEstaGuiaTexto =
      'Es una guía general que no sustituye a un profesional.';
  static const planAgenda = 'Plan en la agenda';

  // Sin señal (G6-A1): lo registrado queda en este equipo y se envía después.
  static const sinNubeSeEnviara =
      'No se pudo guardar en la nube; queda en este equipo y se enviará.';
  static const noSePudoTerminar =
      'No se pudo terminar la sesión ahora. Lo que registraste sigue en este '
      'equipo; inténtalo de nuevo.';
  static const agendaSinLeer =
      'No pude leer tu agenda ahora; la hora es aproximada y se ajusta cuando '
      'haya señal.';
  static const agendaSinSenal =
      'No se pudo poner el plan en la agenda ahora. Inténtalo cuando haya '
      'señal; tu plan sigue en este equipo.';

  // Aviso del banco antes de la primera vez (3.2, G6-M3): una sola vez por
  // persona, sin diagnóstico.
  static const avisoBanco =
      'Antes de usar el banco por primera vez, comprueba en el aparato su '
      'capacidad y que esté estable y firme. Si no puedes comprobarlo, elige '
      'otro ejercicio.';
  static const yaLoRevise = 'Ya lo revisé';

  static List<String> get todos => [
    sinSesion,
    entendido,
    guiaTitulo,
    modoFocoNoLegible,
    hoyBicicleta,
    hoyDescanso,
    hoyNoHayPlan,
    guardadoDeshacer,
    empezarPlan,
    ponerEnAgenda,
    agendaListo,
    agendaConflicto,
    comoAmaneciste,
    descansado,
    normal,
    cansado,
    proponemosRegenerativa,
    verRegenerativa,
    listo,
    calentamiento,
    calentamientoAyuda,
    terminar,
    terminoSesion,
    terminoParte,
    cambiarEjercicio,
    versionCorta,
    guardadoEnElEquipo,
    esfuerzoDelEjercicio,
    omitir,
    sesionTerminada,
    todoComoPlaneado,
    registrarLoQueHice,
    guardar,
    sinHistorial,
    sinRecords,
    molestiaAgregar,
    molestiaVacia,
    molestiaNota,
    molestiaBloqueada,
    ajustesCiclo,
    ajustesSinDescarga,
    ajustesVoz,
    ajustesVozAyuda,
    sobreEstaGuiaTexto,
    planAgenda,
    sinNubeSeEnviara,
    noSePudoTerminar,
    agendaSinLeer,
    agendaSinSenal,
    avisoBanco,
    yaLoRevise,
  ];
}

/// El marco de una pantalla de «Mi gimnasio»: título, regreso a Entrenamiento
/// y, en las pantallas en movimiento (sesión y registro), la personalidad
/// Sport (H-18).
class MarcoGimnasio extends ConsumerWidget {
  const MarcoGimnasio({
    super.key,
    required this.destino,
    required this.cuerpo,
    this.sport = false,
    this.acciones = const [],
  });

  final DestinoGimnasio destino;
  final Widget cuerpo;
  final bool sport;
  final List<Widget> acciones;

  @override
  Widget build(BuildContext context, WidgetRef ref) => TemaModulo(
    modulo: Modulo.habitos,
    submodulo: sport ? Submodulo.entrenamiento : null,
    child: MarcoPantalla(
      titulo: destino.titulo,
      rutaAnterior: destino == DestinoGimnasio.hoy
          ? Rutas.habitos
          : RutasGimnasio.hoy,
      acciones: acciones,
      cuerpo: SafeArea(child: AnchoCentrado(child: cuerpo)),
    ),
  );
}

/// Centra el contenido con un ancho cómodo en la laptop y la tablet.
class AnchoCentrado extends StatelessWidget {
  const AnchoCentrado({super.key, required this.child, this.ancho = 760});

  final Widget child;
  final double ancho;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: ancho),
      child: child,
    ),
  );
}

/// Un `AsyncValue` con los estados de la pantalla (cargando y error con
/// *Reintentar*; nunca reintenta solo).
Widget vistaAsincrona<T>(
  AsyncValue<T> v, {
  required Widget Function(T datos) listo,
  required VoidCallback alReintentar,
  MensajesEstadoGimnasio mensajes = const MensajesEstadoGimnasio(),
}) => v.when(
  data: listo,
  loading: () => Center(
    child: CuerpoEstadoGimnasio(
      estado: EstadoVistaGimnasio.cargando,
      mensajes: mensajes,
    ),
  ),
  error: (_, _) => Center(
    child: CuerpoEstadoGimnasio(
      estado: EstadoVistaGimnasio.error,
      mensajes: mensajes,
      alReintentar: alReintentar,
    ),
  ),
);

/// Sin sesión en este equipo.
class SinPersonaGimnasio extends StatelessWidget {
  const SinPersonaGimnasio({super.key});

  @override
  Widget build(BuildContext context) => const Center(
    child: CuerpoEstadoGimnasio(
      estado: EstadoVistaGimnasio.vacio,
      mensajes: MensajesEstadoGimnasio(vacio: TextosHabitosGimnasio.sinSesion),
    ),
  );
}

// ------------------------------------------------------------------ textos

String textoVersion(VersionSesion v) => switch (v) {
  VersionSesion.corta => 'corta',
  VersionSesion.estandar => 'estándar',
  VersionSesion.larga => 'larga',
};

String textoVersionId(String id) => switch (id) {
  'corta' => 'Corta',
  'estandar' => 'Estándar',
  'larga' => 'Larga',
  _ => 'Automática',
};

/// «≈ 36 min».
String textoDuracion(int segundos) => '≈ ${(segundos + 30) ~/ 60} min';

TipoSemanaVista semanaVista(TipoSemana t) => switch (t) {
  TipoSemana.carga => TipoSemanaVista.carga,
  TipoSemana.descarga => TipoSemanaVista.descarga,
  TipoSemana.reentrada => TipoSemanaVista.reentrada,
  TipoSemana.foco => TipoSemanaVista.foco,
};

TipoSemanaVista semanaVistaDe(String id) => switch (id) {
  'descarga' => TipoSemanaVista.descarga,
  'reentrada' => TipoSemanaVista.reentrada,
  'foco' => TipoSemanaVista.foco,
  _ => TipoSemanaVista.carga,
};

TipoDiaPlan tipoDiaPlan(String tipo) => switch (tipo) {
  'A' => TipoDiaPlan.fuerzaA,
  'B' => TipoDiaPlan.fuerzaB,
  'C' => TipoDiaPlan.fuerzaC,
  'R1' => TipoDiaPlan.regenerativa1,
  'R2' => TipoDiaPlan.regenerativa2,
  'bici' => TipoDiaPlan.bicicleta,
  _ => TipoDiaPlan.descanso,
};

/// «Fuerza A · Empuje», «Regenerativa 1».
String nombreDePlantilla(Catalogo c, String tipo) =>
    c.plantilla(tipo)?.nombre ?? c.regenerativa(tipo)?.nombre ?? tipo;

String nombreDeEjercicio(Catalogo c, String ejercicioId) =>
    c.ejercicio(ejercicioId)?.nombre ?? ejercicioId;

String nombreDeVariante(Catalogo c, String varianteId) =>
    c.variante(varianteId)?.nombre ?? varianteId;

/// «3 × 10–12», «3 × 30–45 s», «3 × 10–12 por pierna».
String textoSeries(EjercicioPlanificado e) {
  final rango = e.rangoMin == e.rangoMax
      ? '${e.rangoMin}'
      : '${e.rangoMin}–${e.rangoMax}';
  return '${e.series} × $rango${e.porTiempo ? ' s' : ''}'
      '${e.porLado ? ' por pierna' : ''}';
}

String horaTexto(int minutos) => horaDeMinutos(minutos % 1440);

String nombreDeDia(int diaSemana) => const [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
][diaSemana - 1];

const _letrasDia = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
String letraDeDia(int diaSemana) => _letrasDia[diaSemana - 1];

/// El texto de cada aviso del generador (sale del catálogo de mensajes).
String? textoDeAviso(CodigoAviso c) => switch (c) {
  CodigoAviso.sinEquipoSuficiente => MensajesGimnasio.sinEquipoSuficiente,
  CodigoAviso.slotOmitido =>
    'Dejamos un ejercicio fuera por el equipo o por una precaución.',
  CodigoAviso.conPrecaucion => MensajesGimnasio.molestiaConPrecaucion,
  CodigoAviso.topeDePila => MensajesGimnasio.topeDePila,
  CodigoAviso.cercaDeDormir => MensajesGimnasio.cercaDeDormir,
  CodigoAviso.modoFoco => MensajesGimnasio.modoFoco,
  CodigoAviso.contenidoEnRevision => null, // lo dice la tarjeta de revisión
  CodigoAviso.descargaSugerida => MensajesGimnasio.sugerirDescarga,
  CodigoAviso.molestiaFuerte => MensajesGimnasio.molestiaFuerte,
  CodigoAviso.ofrecerRegenerativa => TextosGimnasio.molestiaProponerRegenerativa,
  CodigoAviso.seguridadBanda => MensajesGimnasio.seguridadBanda,
  CodigoAviso.versionCortaSugerida =>
    'Si hoy está pesado, la versión corta sigue disponible.',
};

/// Los avisos de una sesión sin repetir, ya redactados.
List<String> avisosDe(EntrenamientoHoy h) {
  final r = <String>[];
  void poner(String? t) {
    if (t != null && !r.contains(t)) r.add(t);
  }

  if (h.noCabe) poner(MensajesGimnasio.noCabe);
  if (h.avisoDormir != null) poner(MensajesGimnasio.cercaDeDormir);
  for (final a in h.sesion?.avisos ?? const <AvisoGimnasio>[]) {
    poner(textoDeAviso(a.codigo));
  }
  // Al final: lo importante de la sesión va primero.
  if (h.agendaSinLeer) poner(TextosHabitosGimnasio.agendaSinLeer);
  return r;
}

String textoDeOpcionDormir(OpcionDormir o) => switch (o) {
  OpcionDormir.versionMasCorta => 'Hacer una versión más corta',
  OpcionDormir.regenerativa => 'Hacer la regenerativa',
  OpcionDormir.empezarAntes => 'Empezar antes',
  OpcionDormir.moverALaManana => 'Moverla a la mañana',
};

/// Los destinos de «Mi gimnasio» como rutas con parámetros.
String rutaConParametros(DestinoGimnasio d, Map<String, String> parametros) =>
    Uri(path: d.ruta, queryParameters: parametros.isEmpty ? null : parametros)
        .toString();

/// La fecha de hoy como `DateTime` UTC (sin hora).
DateTime hoyDe(DateTime ahora) => soloDia(ahora);

String fechaCortaTexto(String isoFecha) {
  final f = fechaDeIso(isoFecha);
  const meses = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];
  return '${nombreDeDia(f.weekday).substring(0, 3)} ${f.day} ${meses[f.month - 1]}';
}

/// La carga sugerida de un ejercicio: «Placa 4» (sin kilos si no se confirmó
/// el aparato, CA-G-04), «Banda verde» o `null` sin historial (5.12).
String? textoCargaSugerida(EjercicioPlanificado e, Inventario inv) {
  if (e.cargaPasos != null) {
    final t = mostrarCargaPasos(e.cargaPasos!, inv).texto;
    return t[0].toUpperCase() + t.substring(1);
  }
  if (e.bandaId != null) {
    final b = inv.bandas.where((x) => x.id == e.bandaId).firstOrNull;
    if (b != null) return e.bandaDoble ? '${b.nombre} ×2' : b.nombre;
  }
  return null;
}

/// «aprox.» para lo que viene del diseño; los kilos solo si se confirmaron.
EjercicioPlanVista vistaDeEjercicio(
  EjercicioPlanificado e,
  Catalogo c,
  Inventario inv,
) {
  final variante = c.variante(e.varianteId);
  final ej = c.ejercicio(e.ejercicioId);
  return EjercicioPlanVista(
    ejercicio: ej?.nombre ?? e.ejercicioId,
    varianteTexto: variante?.nombre,
    seriesTexto: textoSeries(e),
    cargaTexto: textoCargaSugerida(e, inv),
    conPrecaucion: e.conPrecaucion,
  );
}
