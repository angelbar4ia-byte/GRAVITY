/// Catálogo cerrado de avisos (Fase 2, D20, reglas 42 a 47 de
/// `docs/specs/fase-2-finanzas.md`).
///
/// Lo que se ve en la notificación sale **solo de aquí**: título de máximo 40
/// caracteres, sin dígitos, sin "$" y sin nombres propios, y cuerpo vacío. El
/// detalle (montos, libro, cuenta) vive únicamente en la bandeja, dentro de la
/// app. Por Firebase viaja solo `{v, id}`; nunca texto, tipo ni libro.
library;

import 'dart:convert';

/// Qué tan urgente es un aviso. Decide el canal de Android y si suena en las
/// horas silenciosas.
enum SeveridadAviso {
  critica,
  importante,
  informativa;

  static SeveridadAviso? desdeTexto(String? texto) {
    for (final s in values) {
      if (s.name == texto) return s;
    }
    return null;
  }
}

/// Cuatro canales de Android con nombres discretos (regla 46).
enum CanalAviso {
  urgentes('finanzas_urgentes', 'Finanzas · Urgentes'),
  avisos('finanzas_avisos', 'Finanzas · Avisos'),
  informativos('finanzas_informativos', 'Finanzas · Informativos'),
  resumen('finanzas_resumen', 'Finanzas · Resumen'),
  // Hábitos (Fase 3, regla 115): tres canales propios con nombres discretos.
  habitosRecordatorios('habitos_recordatorios', 'Hábitos · Recordatorios'),
  habitosReservados('habitos_reservados', 'Hábitos · Reservados'),
  habitosRevision('habitos_revision', 'Hábitos · Revisión');

  const CanalAviso(this.id, this.nombre);

  final String id;
  final String nombre;
}

/// Título genérico: sin sesión, sin señal o sin poder leer el aviso (regla 43).
const textoAvisoGenerico = 'Tienes un aviso de GRAVITY';

/// Versión pública para equipos que respetan la pantalla bloqueada `PRIVATE`.
const textoAvisoPublico = 'GRAVITY · tienes un aviso';

/// Largo máximo del título (regla 42).
const largoMaximoTituloAviso = 40;

/// Título de cada tipo del catálogo.
const Map<String, String> titulosDeAviso = {
  'pago_proximo': 'Tienes un pago próximo',
  'limite_tarjeta': 'Vence un pago de tarjeta',
  'pago_vencido': 'Hay un pago sin registrar',
  'protegido_riesgo': 'Un gasto protegido necesita atención',
  'flujo_negativo': 'Revisa el flujo de la semana',
  'abono_bajo_minimo': 'Revisa tus pagos de deuda',
  'partida_100': 'Revisa una categoría',
  'partida_80': 'Una categoría se acerca a su límite',
  'ingreso_retrasado': 'Un ingreso no ha llegado',
  'fondo_bajo': 'Revisa tu ahorro',
  'uso_limite': 'Revisa el uso de una tarjeta',
  'aportacion_pendiente': 'Hay ahorro por confirmar',
  'conciliacion_pendiente': 'Falta conciliar el efectivo',
  'salida_libro_representado': 'Hay un movimiento por revisar',
  'retiro_bolsa_compartida': 'Hay un movimiento por revisar',
  'resumen_lunes': 'Tu resumen de la semana está listo',
  'recordatorio_cierre': 'Es hora de cerrar la semana',
  'solicitud_vista': 'Solicitud de vista: Familiar',
  // Cuidados (Fase 5, D6): genéricos, sin medicamento ni dato clínico.
  'recordatorio_toma': 'Hora de un recordatorio de cuidado',
  'recordatorio_comida': 'Hora de la comida',
  'entrega_turno': 'Es hora de dejar tus notas',
  'cambio_urgente_cuidados': 'Cambio urgente en los cuidados',
  'base_80': 'Revisa el almacenamiento de GRAVITY',
  'base_90': 'Revisa el almacenamiento de GRAVITY',
};

/// Severidad de cada tipo (regla 32). Los fijos (resumen y cierre) son
/// informativos y no cuentan para el tope diario.
const Map<String, SeveridadAviso> severidadDeAviso = {
  'pago_proximo': SeveridadAviso.critica,
  'limite_tarjeta': SeveridadAviso.critica,
  'pago_vencido': SeveridadAviso.critica,
  'protegido_riesgo': SeveridadAviso.critica,
  'flujo_negativo': SeveridadAviso.critica,
  'abono_bajo_minimo': SeveridadAviso.critica,
  'base_90': SeveridadAviso.critica,
  'partida_100': SeveridadAviso.importante,
  'ingreso_retrasado': SeveridadAviso.importante,
  'fondo_bajo': SeveridadAviso.importante,
  'salida_libro_representado': SeveridadAviso.importante,
  'base_80': SeveridadAviso.importante,
  // D24: el familiar pidió la vista temporal de Finanzas de Papá.
  'solicitud_vista': SeveridadAviso.critica,
  // Cuidados: el cambio urgente del dueño llega al instante a quien está de turno.
  'cambio_urgente_cuidados': SeveridadAviso.critica,
  'recordatorio_toma': SeveridadAviso.importante,
  'recordatorio_comida': SeveridadAviso.importante,
  'entrega_turno': SeveridadAviso.informativa,
  'partida_80': SeveridadAviso.informativa,
  'uso_limite': SeveridadAviso.informativa,
  'aportacion_pendiente': SeveridadAviso.informativa,
  'conciliacion_pendiente': SeveridadAviso.informativa,
  'retiro_bolsa_compartida': SeveridadAviso.informativa,
  'resumen_lunes': SeveridadAviso.informativa,
  'recordatorio_cierre': SeveridadAviso.informativa,
};

/// Los que no cuentan para el tope diario de avisos no críticos.
const Set<String> avisosFijos = {'resumen_lunes', 'recordatorio_cierre'};

/// Tipos de Cuidados: los recibe también quien no ve dinero (el cuidador).
const Set<String> avisosDeCuidados = {
  'recordatorio_toma',
  'recordatorio_comida',
  'entrega_turno',
  'cambio_urgente_cuidados',
};

/// Título para [tipo]; el genérico si no está en el catálogo.
String tituloDeAviso(String? tipo) =>
    titulosDeAviso[tipo] ?? textoAvisoGenerico;

SeveridadAviso severidadDe(String? tipo) =>
    severidadDeAviso[tipo] ?? SeveridadAviso.informativa;

/// Canal de Android de un aviso (regla 46).
CanalAviso canalDe(String? tipo) {
  if (tipo == 'resumen_lunes' || tipo == 'recordatorio_cierre') {
    return CanalAviso.resumen;
  }
  return switch (severidadDe(tipo)) {
    SeveridadAviso.critica => CanalAviso.urgentes,
    SeveridadAviso.importante => CanalAviso.avisos,
    SeveridadAviso.informativa => CanalAviso.informativos,
  };
}

/// `true` si [texto] cumple las reglas de discreción: sin dígitos, sin "$", de
/// máximo [largoMaximoTituloAviso] caracteres. Las pruebas lo exigen de todo el
/// catálogo.
bool textoDeAvisoEsDiscreto(String texto) =>
    texto.isNotEmpty &&
    texto.length <= largoMaximoTituloAviso &&
    !RegExp(r'[0-9$]').hasMatch(texto);

/// Id de la notificación local de un aviso: un hash estable de su `clave`
/// (regla 45). Si el mismo aviso llega por Firebase y por el recordatorio
/// local, el segundo **reemplaza** al primero y la persona ve una sola.
/// FNV-1a de 32 bits recortado a 31 (los ids de Android son enteros con signo).
int idDeNotificacion(String clave) {
  var hash = 0x811c9dc5;
  for (final byte in utf8.encode(clave)) {
    hash ^= byte;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash & 0x7FFFFFFF;
}

/// Id de la notificación genérica (sin clave que la distinga).
final int idNotificacionGenerica = idDeNotificacion('gravity:generico');
