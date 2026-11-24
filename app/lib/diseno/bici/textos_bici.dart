/// Textos fijos de la interfaz de «Bicicleta» (fase 8, bloque B4).
///
/// Son palabras de la **interfaz** (botones, estados, avisos genéricos) y las
/// líneas fijas de seguridad de la especificación (1.2 y 4.4). El resto del
/// contenido (nombres de rutas, kilómetros, tareas, respuestas por casilla de
/// clima, mensajes del catálogo) llega ya armado desde el dominio como datos.
///
/// Tono (CA-B-08): sin signos de exclamación y sin las palabras que culpan
/// (*fallaste, fracaso, perdiste, culpa, castigo, vergüenza*). Contenido
/// (CA-B-01): sin diagnósticos, tratamientos, medicamentos, dosis, litros,
/// gramos, calorías ni nombres de enfermedades o lesiones.
library;

/// Los textos fijos del módulo; las pruebas los recorren para revisar el tono
/// y el contenido.
abstract final class TextosBici {
  // --- Guía y seguridad (1.2, 4.4) -----------------------------------------
  /// La línea fija de la guía (1.2).
  static const guiaNoSustituye =
      'Esta guía no sustituye tu prudencia, las reglas de tránsito ni a un '
      'profesional. Ajusta la salida a cómo te sientes, al clima y al camino.';

  /// Versión corta, para la pantalla de planear.
  static const guiaNoSustituyeCorta =
      'Esta guía no sustituye tu prudencia ni las reglas de tránsito.';

  /// «Si te sientes mal» (PB-19): no nombra síntomas ni enfermedades.
  static const siTeSientesMal =
      'Si te sientes mal durante la salida, detente en un lugar seguro y pide '
      'ayuda. Si el malestar es fuerte o no cede, llama a emergencias o '
      'consulta a un médico.';

  /// Nadie vigila la salida (4.4): se dice con estas palabras.
  static const nadieVigila =
      'GRAVITY no vigila tu salida: si no regresas, nadie recibe un aviso '
      'automático.';
  static const seguridadTitulo = 'Seguridad y contacto';
  static const consejosSeguridad = 'Antes de salir';

  // --- Contenido en revisión -----------------------------------------------
  static const contenidoEnRevision = 'Contenido en revisión';
  static const contenidoEnRevisionDetalle =
      'Es una guía general que no sustituye a un profesional. Los intervalos '
      'de mantenimiento son un punto de partida.';
  static const sobreEstaGuia = 'Sobre esta guía';
  static const entendido = 'Entendido';

  // --- Mantenimiento (4.8) -------------------------------------------------
  static const confirmaIntervalos =
      'Confirma los intervalos con el manual de tu bici o con tu taller.';
  static const borrador = 'Borrador';
  static const hecho = 'Hecho';
  static const registrarLectura = 'Anotar lo que marca mi bici';
  static const odometroCalculado = 'Se calcula con tus salidas';
  static const sinRegistroNota = 'Sin registro. Cuando la hagas, márcala.';

  // --- Rutas y contacto: solo en el teléfono (7.1) --------------------------
  static const soloEnEsteEquipo = 'Solo se guarda en este equipo';
  static const rutasSoloEnTelefono =
      'Tus rutas y tu contacto están solo en tu teléfono.';

  // --- Acciones -------------------------------------------------------------
  static const sali = 'Salí';
  static const empezar = 'Empezar';
  static const terminar = 'Terminar';
  static const preparar = 'Preparar';
  static const prepararSalida = 'Prepara tu salida';
  static const registrarLoQueHice = 'Registrar lo que hice';
  static const todoComoEstabaPlaneado = 'Todo como estaba planeado';
  static const guardar = 'Guardar';
  static const deshacer = 'Deshacer';
  static const verOpciones = 'Ver opciones';
  static const dejarloAsi = 'Dejarlo así';
  static const posponerRevision = 'Pasar mi revisión a más tarde';
  static const listo = 'Listo';
  static const cambiar = 'Cambiar';
  static const abrir = 'Abrir';

  // --- Enlaces y contacto (4.4) ---------------------------------------------
  static const abrirMiLista = 'Abrir mi lista';
  static const verElClima = 'Ver el clima';
  static const abrirMiRuta = 'Abrir mi mapa';
  static const seAbreEnOtraApp = 'Se abre en otra app';
  static const noSePudoAbrir = 'No se pudo abrir';
  static const avisarMiHoraDeRegreso = 'Avisar mi hora de regreso';
  static const llamarAMiContacto = 'Llamar a mi contacto';
  static const agregarContacto = 'Agregar mi contacto';
  static const nadaSeEnviaSolo =
      'Se abre tu aplicación de mensajes o tu marcador. Tú tocas Enviar o '
      'Llamar.';

  // --- Cronómetro (6.6) -----------------------------------------------------
  static const cronometroParado =
      'Empieza y termina parado, en un lugar seguro.';
  static const cronometro = 'Cronómetro';
  static const sinEmpezar = 'Sin empezar';
  static const enCurso = 'En curso';
  static const terminado = 'Terminado';

  // --- Esfuerzo percibido (4.5) ---------------------------------------------
  static const esfuerzos = [
    'Muy ligero',
    'Ligero',
    'Moderado',
    'Duro',
    'Al límite',
  ];

  // --- V2, no aprobado ------------------------------------------------------
  static const v2NoAprobado = 'V2, no aprobado';
  static const v2Detalle =
      'Maqueta sin funcionar. Necesita paquetes y permisos que el dueño no ha '
      'aprobado. Esta pantalla no existe en la app.';

  // --- Estados de cada componente (vacío, cargando, sin conexión, error) ----
  static const cargando = 'Cargando…';
  static const sinConexionGenerico =
      'Sin conexión. Se muestra lo guardado en este equipo.';
  static const errorGenerico =
      'No se pudo cargar esto. Puedes intentarlo otra vez.';
  static const reintentar = 'Reintentar';
}
