/// Textos fijos de la interfaz de «Mi gimnasio» (fase 8, bloque 7).
///
/// Son palabras de la **interfaz** (botones, estados, avisos genéricos), no
/// contenido de entrenamiento: los nombres de ejercicios, aparatos, cargas y
/// los mensajes del catálogo llegan ya armados desde el dominio como datos.
///
/// Tono (CA-G-40): sin signos de exclamación y sin las palabras que culpan
/// (*fallaste, fracaso, perdiste, culpa, castigo, vergüenza*). Todo aviso de
/// molestia menciona a un «profesional», un «médico» o un «entrenador»
/// (CA-G-03) y ninguno dice qué es una molestia ni cómo tratarla.
library;

/// Los textos fijos del módulo; las pruebas los recorren para revisar el tono.
abstract final class TextosGimnasio {
  // --- Contenido en revisión (PG-25) ---------------------------------------
  static const contenidoEnRevision = 'Contenido en revisión';
  static const contenidoEnRevisionDetalle =
      'Es una guía general que no sustituye a un profesional. Todavía no la '
      'revisa un entrenador.';
  static const sobreEstaGuia = 'Sobre esta guía';

  // --- Molestias (5.10, sin diagnosticar) ----------------------------------
  static const molestiaSoloEnEsteEquipo = 'Solo se guarda en este equipo';
  static const molestiaLeve =
      'Los ejercicios que cargan esta zona van con precaución. Esta guía no '
      'sustituye a un profesional.';
  static const molestiaModerada =
      'Cambiamos los ejercicios que cargan esta zona. Esta guía no sustituye '
      'a un profesional.';
  static const molestiaFuerte =
      'No sustituye a un profesional. Si el dolor es fuerte, aparece de '
      'golpe, no cede con el descanso o te acompaña otro síntoma, consulta a '
      'un médico o a un entrenador.';
  static const molestiaProponerRegenerativa =
      'Te proponemos la sesión regenerativa de hoy.';
  static const molestiaPreguntaSigue = '¿Sigue esta molestia?';
  static const molestiaSigue = 'Sigue';
  static const molestiaYaNo = 'Ya no';
  static const molestiaOtroEquipo =
      'Las molestias están solo en tu teléfono; aquí no se tienen en cuenta.';

  // --- Carga y aparato (3.1, 3.2, 5.8) -------------------------------------
  static const confirmarEnElAparato = 'Confirmar en el aparato';
  static const confirmado = 'Confirmado';
  static const aproximadoDistribuidor = 'Aprox., según el distribuidor';
  static const eligeTuCarga =
      'Elige una carga con la que llegues a las repeticiones con esfuerzo 3 '
      '(moderado).';
  static const topeDePila =
      'Llegaste al tope de la pila. Seguimos avanzando con más repeticiones '
      'y más control.';
  static const sinKgHastaConfirmar = 'Sin kilos hasta confirmar en el aparato';
  static const marcarNoDisponible = 'Marcar como no disponible';
  static const marcarDisponible = 'Marcar como disponible';
  static const equipoFuturoNota = 'Cuando lo tengas. Por ahora no genera nada.';

  // --- Serie y descanso (7.2) ----------------------------------------------
  static const descanso = 'Descanso';
  static const descansoTerminado = 'Descanso terminado';
  static const sinDescanso = 'Sin descanso en curso';
  static const mas15 = '+15 s';
  static const menos15 = '−15 s';
  static const saltar = 'Saltar';
  static const hecha = 'Hecha';
  static const serieGuardada = 'Serie guardada';
  static const deshacer = 'Deshacer';
  static const siguiente = 'Sigue';

  // --- Semana y 48 horas ---------------------------------------------------
  static const hoy = 'Hoy';

  // --- Historial y récords -------------------------------------------------
  static const nuevoRecord = 'Nuevo récord';
  static const semanaDeDescarga = 'Descarga: menos series a propósito';

  // --- Estados de cada componente (vacío, cargando, sin conexión, error) ---
  static const cargando = 'Cargando…';
  static const sinConexionGenerico =
      'Sin conexión. Se muestra lo guardado en este equipo.';
  static const errorGenerico =
      'No se pudo cargar esto. Puedes intentarlo otra vez.';
  static const reintentar = 'Reintentar';
}
