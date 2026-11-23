/// Catálogo cerrado de mensajes del gimnasio (7.4, CA-G-40). Tono sin culpa,
/// de tú, sin signos de exclamación. Los códigos de aviso del generador no
/// llevan texto: el texto sale de aquí.
library;

class MensajesGimnasio {
  static const contenidoEnRevision = 'Contenido en revisión';
  static const guiaGeneral =
      'Es una guía general que no sustituye a un profesional.';
  static const consultaAntesDeEmpezar =
      'Si tienes una condición médica o hace tiempo que no entrenas, '
      'consulta a un profesional antes de empezar.';
  static const semanaDeDescarga =
      'Esta semana es de descarga. Es parte del plan.';
  static const semanaDeDescargaBanner =
      'Esta semana es de descarga: menos series para recuperar. '
      'Es parte del plan';
  static const reentrada = 'Retomemos con calma. Hoy cuenta empezar.';
  static const unDiaNoBorra =
      'Un día no borra lo que has avanzado. Retomemos hoy.';
  static const topeDePila =
      'Llegaste al tope de la pila. Seguimos avanzando con más repeticiones '
      'y más control.';
  static const sugerirDescarga =
      'Llevas dos sesiones al límite. ¿Quieres una semana de descarga?';
  static const modoFoco =
      'Esta semana mantenemos la carga sin subir. La versión corta sigue '
      'disponible.';
  static const sinEquipoSuficiente =
      'Con tu equipo o tus precauciones actuales no alcanza una sesión de '
      'fuerza. Puedes hacer la regenerativa o revisar tu inventario.';
  static const noCabe =
      'Hoy no cabe una sesión de fuerza. ¿Movemos el bloque o hacemos la '
      'regenerativa?';
  static const cercaDeDormir =
      'Esta sesión termina cerca de tu hora de dormir. ¿La hacemos más corta?';
  static const seguridadBanda =
      'Revisa la banda antes de usarla: sin grietas ni cortes. '
      'Asegura bien el ancla.';
  static const confirmarEnElAparato = 'Confirmar en el aparato';
  static const cargaEnPlacas =
      'Sin confirmar el aparato, la carga se muestra en placas.';
  static const primeraCarga =
      'Elige una carga con la que llegues a las repeticiones con esfuerzo 3 '
      '(moderado).';

  // Molestias (5.10): sin diagnóstico, sin tratamiento.
  static const molestiaCambio =
      'Gracias por avisar. Cambiamos este ejercicio por otro que no cargue '
      'esa zona. Esta guía no diagnostica.';
  static const molestiaFuerte =
      'No sustituye a un profesional. Si el dolor es fuerte, aparece de '
      'golpe, no cede con el descanso o te acompaña otro síntoma, consulta '
      'a un médico o a un entrenador.';
  static const molestiaConPrecaucion =
      'Este ejercicio carga una zona que marcaste. Hazlo con calma o elige '
      'otro. Si quieres, consulta a un entrenador.';
  static const sigueLaMolestia = '¿Sigue esta molestia?';
  static const molestiasSoloAqui =
      'Las molestias están solo en tu teléfono; aquí no se tienen en cuenta';

  // Ventana de prueba (5.13).
  static const faltanDatos = 'Faltan datos para comparar los horarios.';
  static const sinDiferenciaClara =
      'No hay diferencia clara: conserva la que prefieras.';

  static String hoyToca(String sesion) => 'Hoy toca $sesion. ¿Empezamos?';
  static String descansoTerminado(String siguiente) =>
      'Descanso terminado. Sigue $siguiente.';
  static String recordPersonal(String ejercicio, String carga) =>
      'Nuevo récord personal en $ejercicio: $carga.';
  static String sugiereVentana(String ventana) =>
      'Te fue mejor por la $ventana. Tú decides si la cambias.';

  /// Avisos de molestia: todos recomiendan consultar a alguien competente.
  static const avisosDeMolestia = [molestiaFuerte, molestiaConPrecaucion];

  /// Todos los textos fijos (para las pruebas de tono y de contenido).
  static List<String> get todos => [
        contenidoEnRevision, guiaGeneral, consultaAntesDeEmpezar,
        semanaDeDescarga, semanaDeDescargaBanner, reentrada, unDiaNoBorra,
        topeDePila, sugerirDescarga, modoFoco, sinEquipoSuficiente, noCabe,
        cercaDeDormir, seguridadBanda, confirmarEnElAparato, cargaEnPlacas,
        primeraCarga, molestiaCambio, molestiaFuerte, molestiaConPrecaucion,
        sigueLaMolestia, molestiasSoloAqui, faltanDatos, sinDiferenciaClara,
        hoyToca('Fuerza A'), descansoTerminado('el remo'),
        recordPersonal('press de pecho', 'placa 6'), sugiereVentana('noche'),
        TextoAvisoGimnasio.descanso,
      ];
}

/// Avisos discretos del gimnasio (regla 114 de Hábitos): ≤ 40 caracteres y
/// sin dígitos, sin nombres de ejercicios ni cargas.
class TextoAvisoGimnasio {
  static const descanso = 'Termina tu descanso';
  static const porTipo = <String, String>{'hab_descanso': descanso};
}
