/// Mensajes sin culpa (convención 8, regla 21) y textos de avisos discretos.
class MensajesHabitos {
  static const rachaRota = 'Un día no borra lo que has avanzado. Retomemos hoy.';
  static const retomar = 'Retomemos hoy';
  static const recaida = 'Una caída no borra lo avanzado.';
  static const recaidaAjuste = 'Aprendamos de lo que pasó y ajustemos el plan.';
  static const saturado = 'Hoy hay mucho. ¿Dejamos solo lo esencial?';
  static const sinObjetivos =
      'Empecemos con uno pequeño. ¿Qué te gustaría lograr esta semana?';
  static const diaLibre = 'Hoy está libre. ¿Agregamos algo pequeño?';
  static const superoLimite = '¿Qué te ayudaría mañana?';
  static const graciaUsada = 'Usaste tu día de gracia';
  static const apoyoProfesional =
      'Hablar con tu médico o con alguien de confianza puede ayudarte.';
  static const sinLineaAyuda =
      'Habla con tu médico o con alguien de confianza';
  static const faltanDias = 'Faltan algunos días para calcular tu promedio';

  static const todos = [
    rachaRota, retomar, recaida, recaidaAjuste, saturado, sinObjetivos,
    diaLibre, superoLimite, graciaUsada, apoyoProfesional, sinLineaAyuda,
    faltanDias,
  ];

  static const prohibidas = [
    'fallaste', 'fracaso', 'perdiste', 'culpa', 'castigo', 'vergüenza', '!',
  ];
}

/// Catálogo cerrado de recordatorios (regla 114): ≤ 40 caracteres, sin
/// dígitos, sin "$", sin nombres de hábitos ni cantidades.
class TextoAvisoHabitos {
  static const porTipo = <String, String>{
    'hab_bloque': 'Tu siguiente actividad empieza pronto',
    'hab_lectura': 'Es hora de tu lectura',
    'hab_momento': 'Es hora de tu momento tranquilo',
    'hab_reservado': 'Recordatorio',
    'hab_revision_pre': 'Tu revisión semanal empieza pronto',
    'hab_revision': 'Es hora de tu revisión semanal',
    'hab_cierre_dia': 'Es hora de cerrar tu día',
  };
  static const generico = 'Tienes un aviso de GRAVITY';

  static String paraTipo(String tipo) => porTipo[tipo] ?? generico;

  /// Título con el nombre del objetivo (solo no sensibles), recortado a 40.
  static String conNombre(String nombre) =>
      nombre.length <= 40 ? nombre : nombre.substring(0, 40);
}
