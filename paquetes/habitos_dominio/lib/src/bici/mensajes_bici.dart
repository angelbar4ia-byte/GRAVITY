/// B1.4 · Catálogo cerrado de mensajes y avisos de la bicicleta (4.4, 4.12).
/// Tono sin culpa, de tú, sin signos de exclamación, sin diagnóstico,
/// tratamiento ni medicamento, **sin cifras de líquidos, comida ni
/// calorías**. El dominio devuelve **códigos**; los textos salen de aquí.
///
/// Todo texto de seguridad y de mantenimiento nace `borrador`: la pantalla
/// muestra «Contenido en revisión» ([contenidoEnRevision]) hasta que una
/// persona competente lo revise (mecánico de bicicletas y, para el texto de
/// salud, un profesional).
library;

import 'carga_piernas.dart';
import 'salida_sabado.dart';
import 'tipos_bici.dart';

class MensajesBici {
  // --- Marca de revisión ---------------------------------------------------
  static const contenidoEnRevision = 'Contenido en revisión';
  static const confirmaIntervalos =
      'Confirma los intervalos con el manual de tu bici o con tu taller.';

  // --- Hoy y salida --------------------------------------------------------
  static const preparaTuSalida = 'Prepara tu salida';
  static const hoyTocaSalida = 'Hoy toca tu salida en bici. ¿Todo listo?';
  static const salidaRegistrada = 'Salida registrada. Gracias por avisar.';
  static const noSalio = 'Hoy no salió la ruta. Cuando quieras, la retomamos.';
  static const revisionPuedeEsperar =
      'Tu revisión semanal puede esperar un rato más si lo necesitas.';
  static const domingoTranquilo = 'Un domingo tranquilo ayuda a recuperar.';
  static const focoSalida = 'Hoy puedes salir o dejarlo: ambos están bien.';
  static const revisionCabe = 'Tu revisión semanal cabe después de la salida.';
  static const revisionNoCabe =
      'Con esta salida la revisión semanal no cabe. Puedes acortar la salida, '
      'hacer la revisión más tarde o dejarla para el domingo.';
  static const pasarRevisionMasTarde = 'Pasar mi revisión a más tarde';
  static const cansado =
      'Una ruta más corta o de calle plana puede ir mejor hoy.';

  // --- Progresión informativa (4.9) ---------------------------------------
  static const progresionNota =
      'Esta salida fue bastante más larga que tus últimas. Si te sientes '
      'bien, adelante; si no, acórtala.';

  // --- Piernas y 48 horas (4.6) -------------------------------------------
  static const piernasAviso =
      'La sesión de piernas queda cerca de la ruta. Tú decides qué prefieres.';
  static const opcionMoverCAlMartes =
      'Poner la sesión C el martes (A lunes, C martes, B miércoles)';
  static const opcionDeclararLigera = 'Declarar la ruta como carga ligera';
  static const opcionDejarloAsi = 'Dejarlo así';
  static const opcionMoverRuta = 'Mover la ruta';
  static const propuestaAcortar = 'Acortar la salida';
  static const propuestaRevisionMasTarde = 'Hacer la revisión más tarde';
  static const propuestaRevisionDomingo = 'Hacer la revisión el domingo';

  // --- Preparación y mantenimiento ----------------------------------------
  static const sinRegistro = 'Sin registro';
  static const alDia = 'Al día';
  static const toca = 'Toca';
  static const desactivada = 'Desactivada';
  static String mantenimientoToca(String tarea) => 'Mantenimiento: $tarea';

  // --- Clima (4.3) ---------------------------------------------------------
  static const casillaDespejado = 'Despejado';
  static const casillaNublado = 'Nublado';
  static const casillaLluvia = 'Posible lluvia';
  static const casillaCalor = 'Mucho calor';
  static const casillaFrio = 'Frío';
  static const climaBuenDia = 'Buen día para salir. Cuídate en las calles.';
  static const climaLluvia =
      'Con lluvia el piso resbala y se ve menos. Considera dejarlo para '
      'otro día o salir en calle por un rato corto.';
  static const climaCalor =
      'Con mucho calor, sal más temprano o acorta la salida, y lleva agua.';
  static const climaFrio = 'Con frío, abrígate por capas y calienta con calma.';

  // --- Seguridad (4.4) -----------------------------------------------------
  static const lineaFija =
      'Esta guía no sustituye tu prudencia, las reglas de tránsito ni a un '
      'profesional. Ajusta la salida a cómo te sientes, al clima y al camino.';
  static const siTeSientesMal =
      'Si te sientes mal durante la salida, detente en un lugar seguro y pide '
      'ayuda. Si el malestar es fuerte o no cede, llama a emergencias o '
      'consulta a un médico.';
  static const seguridadCalle =
      'En calle, usa casco, luces y ropa visible, y respeta las señales. Con '
      'audífonos, deja pasar el sonido del entorno.';
  static const seguridadTerreno =
      'En terreno, revisa llantas y frenos antes de salir y lleva '
      'herramientas básicas.';
  static const horaDeRegreso =
      'Avisa a alguien de confianza tu hora de regreso. GRAVITY no vigila tu '
      'salida: si no regresas, nadie recibe un aviso automático.';
  static const aguaYComida =
      'Lleva agua y algo fácil de comer, y bebe con regularidad desde el '
      'inicio.';
  static const emergencia =
      'Para una emergencia, llama a emergencias (el número del país está en '
      'Ajustes) o a tu contacto.';

  /// Mensaje que arma «Avisar mi hora de regreso»: la persona toca Enviar; la
  /// app nunca envía nada sola.
  static String avisoRegreso(int salidaMin, int regresoMin) =>
      'Salgo a las ${horaTexto(salidaMin)} y regreso hacia las '
      '${horaTexto(regresoMin)}. No me vigila nadie: si no sé de ti, llámame.';

  /// «La sesión C del jueves queda a 36 h 45 min de la ruta.»
  static String piernasIntervalo(String sesion, int intervaloMin) =>
      'La sesión $sesion queda a ${duracionTexto(intervaloMin)} de la ruta.';

  // --- Textos por código ---------------------------------------------------
  static String deOpcionPiernas(OpcionPiernas o) => switch (o) {
    OpcionPiernas.moverCAlMartes => opcionMoverCAlMartes,
    OpcionPiernas.declararRutaLigera => opcionDeclararLigera,
    OpcionPiernas.dejarloAsi => opcionDejarloAsi,
    OpcionPiernas.moverLaRuta => opcionMoverRuta,
  };

  static String dePropuestaRevision(PropuestaRevision p) => switch (p) {
    PropuestaRevision.acortarSalida => propuestaAcortar,
    PropuestaRevision.revisionMasTarde => propuestaRevisionMasTarde,
    PropuestaRevision.revisionElDomingo => propuestaRevisionDomingo,
  };

  /// Textos de seguridad (4.4) en el orden de la especificación.
  static const seguridad = [
    lineaFija,
    siTeSientesMal,
    seguridadCalle,
    seguridadTerreno,
    horaDeRegreso,
    aguaYComida,
    emergencia,
  ];

  /// Todos los textos fijos (para las pruebas de tono y de contenido).
  static List<String> get todos => [
    contenidoEnRevision,
    confirmaIntervalos,
    preparaTuSalida,
    hoyTocaSalida,
    salidaRegistrada,
    noSalio,
    revisionPuedeEsperar,
    domingoTranquilo,
    focoSalida,
    revisionCabe,
    revisionNoCabe,
    pasarRevisionMasTarde,
    cansado,
    progresionNota,
    piernasAviso,
    opcionMoverCAlMartes,
    opcionDeclararLigera,
    opcionDejarloAsi,
    opcionMoverRuta,
    propuestaAcortar,
    propuestaRevisionMasTarde,
    propuestaRevisionDomingo,
    sinRegistro,
    alDia,
    toca,
    desactivada,
    mantenimientoToca('Lubricar la cadena'),
    casillaDespejado,
    casillaNublado,
    casillaLluvia,
    casillaCalor,
    casillaFrio,
    climaBuenDia,
    climaLluvia,
    climaCalor,
    climaFrio,
    ...seguridad,
    avisoRegreso(480, 720),
    piernasIntervalo('C', 2205),
    ...TextoAvisoBici.respaldo.values,
  ];
}

/// Títulos de recordatorio de **respaldo** (4.12): solo se usan si se veta el
/// uso de bloques de agenda (PB-08). Máximo 40 caracteres, sin dígitos ni
/// nombres, cuerpo vacío. Los bloques usan el título que ya existe en
/// `TextoAvisoHabitos`.
class TextoAvisoBici {
  static const prepara = 'Prepara tu bici para mañana';
  static const salida = 'Hora de tu salida en bici';
  static const respaldo = <String, String>{
    'hab_bici_prepara': prepara,
    'hab_bici_salida': salida,
  };
}
