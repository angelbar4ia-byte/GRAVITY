/// Textos de las fugas silenciosas y de la deuda buena o mala (voz de
/// `docs/specs/fase-8-fugas-y-deudas.md` 8.4 y `docs/DISENO_UX_UI.md`):
/// breves, **sin culpa**, describen lo que ve la app y ofrecen una acción. Sin
/// respuesta de la persona no se acusa. Ningún texto lleva cifras ni nombres de
/// comercios (los datos del libro se muestran aparte, en su propio renglón).
library;

import 'package:finanzas_dominio/finanzas_dominio.dart'
    hide Semaforo, formatearCentavos, TipoLibro, puntosBaseEnCien;

/// Nombre del tipo de fuga en la interfaz.
String nombreTipoFuga(TipoFuga t) => switch (t) {
  TipoFuga.hormiga => 'Hormiga',
  TipoFuga.fantasma => 'Fantasma',
  TipoFuga.vampiro => 'Vampiro',
  TipoFuga.zombie => 'Zombi',
  TipoFuga.ninguna => 'Sin fuga',
};

/// Qué es cada fuga, en una línea (voz de la sección 8.4).
String queEsLaFuga(TipoFuga t) => switch (t) {
  TipoFuga.hormiga =>
    'Estas compras chicas se repiten bastante. ¿Quieres verlas juntas?',
  TipoFuga.fantasma =>
    'Encontré un cobro que se repite y no tienes registrado. ¿Lo reconoces?',
  TipoFuga.vampiro => 'Este cobro sube cada vez. ¿Lo revisamos?',
  TipoFuga.zombie =>
    'No marcaste uso en este cobro las últimas veces. ¿Todavía lo quieres?',
  TipoFuga.ninguna => '',
};

/// Cada cuánto se cobra.
String nombreCadencia(CadenciaCobro c) => switch (c) {
  CadenciaCobro.semanal => 'cada semana',
  CadenciaCobro.quincenal => 'cada quincena',
  CadenciaCobro.mensual => 'cada mes',
  CadenciaCobro.bimestral => 'cada dos meses',
  CadenciaCobro.anual => 'cada año',
  CadenciaCobro.irregular => 'sin fecha fija',
};

/// La regla que puso la fuga ahí, en una frase (el código va aparte).
String fraseDeLaRegla(FugaDetectada f) {
  if (f.origen == OrigenFuga.persona) return 'Lo decidiste tú.';
  final r = f.regla;
  if (f.marcas.contains(MarcaFuga.cobradoTrasCancelar) || r == 'F4') {
    return 'Se cobró después de la cancelación.';
  }
  if (f.marcas.contains(MarcaFuga.porPagarSoloElMinimo) || r == 'VD') {
    return 'Hubo intereses por pagar solo el mínimo.';
  }
  return switch (r) {
    'H' => 'Compras chicas que se repiten en varias semanas.',
    'F3' =>
      f.estado == EstadoFuga.porReconocer
          ? 'Cobro automático que se repite y aún no reconoces.'
          : 'Cobro automático que dijiste no conocer.',
    'Z1' => 'Dijiste que ya no lo usas.',
    'Z2' => 'Confirmaste que está duplicado.',
    'Z3' => 'Confirmaste que es un plan viejo.',
    'Z4' => 'Dijiste que ya no quieres esa cuenta.',
    'Z5' => 'Dijiste que lo cubierto ya no existe.',
    'VA' => 'Intereses o comisiones que aparecen seguido.',
    'VB' => 'El cobro subió con el tiempo.',
    'VC' || 'VC3' => 'Viene más alto de lo normal.',
    _ => 'Cobro que se repite.',
  };
}

/// La acción que sugiere la app (la persona decide).
String accionSugerida(FugaDetectada f) {
  if (f.marcas.contains(MarcaFuga.cobradoTrasCancelar) || f.regla == 'F4') {
    return 'Se cobró después de cancelar: reclámalo con tu folio de '
        'cancelación. Profeco orienta si el cobro sigue.';
  }
  if (f.marcas.contains(MarcaFuga.porPagarSoloElMinimo) || f.regla == 'VD') {
    return 'Este corte tuvo intereses porque se pagó el mínimo. El siguiente '
        'se puede pagar completo.';
  }
  if (f.marcas.contains(MarcaFuga.servicioDelHogar) ||
      f.regla == 'VC' ||
      f.regla == 'VC3') {
    return 'Este recibo viene más alto de lo normal. Conviene revisar '
        'instalaciones y consumo.';
  }
  return switch (f.fuga) {
    TipoFuga.hormiga =>
      'Un límite semanal para este gasto ayuda a verlo antes.',
    TipoFuga.fantasma =>
      'Revísalo con tu banco o el comercio y, si no es tuyo, pide la baja.',
    TipoFuga.vampiro =>
      f.regla == 'VA'
          ? 'Revisa cómo evitar estos intereses o comisiones.'
          : 'Este cobro sube cada vez. ¿Lo revisamos?',
    TipoFuga.zombie => 'Pide la baja formal y guarda el folio de cancelación.',
    TipoFuga.ninguna => '',
  };
}

/// Un cobro que se repite (no una subcategoría hormiga, ni un cargo de
/// estados de cuenta, ni un servicio del hogar): se puede reconocer, usar o
/// cancelar.
bool esCobroRecurrente(FugaDetectada f) =>
    !f.clave.startsWith('hormiga|') &&
    !f.clave.startsWith('cargo|') &&
    !f.marcas.contains(MarcaFuga.servicioDelHogar);

/// Título corto de la pregunta de la revisión mensual.
String textoDePregunta(TipoPregunta t) => switch (t) {
  TipoPregunta.reconoce => 'Encontré un cobro que se repite. ¿Lo reconoces?',
  TipoPregunta.uso => '¿Lo usaste este mes?',
};

/// Textos de las respuestas.
String textoDeRespuesta(TipoPregunta t, RespuestaPersona r) => switch ((t, r)) {
  (TipoPregunta.reconoce, RespuestaPersona.si) => 'Sí, lo conozco',
  (TipoPregunta.reconoce, RespuestaPersona.no) => 'No lo conocía',
  (TipoPregunta.uso, RespuestaPersona.si) => 'Lo usé',
  (TipoPregunta.uso, RespuestaPersona.no) => 'No lo usé',
  (_, RespuestaPersona.despues) => 'Después',
};

// ----------------------------------------------------------- deuda buena o mala

/// Texto corto de cada estado de una deuda (voz de la sección 8.4).
String textoCortoDeCalidad(EstadoCalidad e, {required bool esMsi}) =>
    switch (e) {
      EstadoCalidad.buena =>
        esMsi
            ? 'Esta compra a meses va al corriente y sirve para lo que dijiste.'
            : 'Va al corriente y sirve para lo que dijiste.',
      EstadoCalidad.enVigilancia =>
        'Va bien, pero hay señales que conviene vigilar.',
      EstadoCalidad.seVolvioMala =>
        'Esta deuda cambió y conviene revisarla. Veamos opciones.',
      EstadoCalidad.porDeclarar =>
        'Falta declarar para qué fue. Mientras tanto no la juzgo.',
      EstadoCalidad.sinCosto =>
        'Préstamo sin costo: no entra al semáforo, sí a tu carga total.',
      EstadoCalidad.liquidada => 'Ya está liquidada.',
    };

/// Etiqueta (con texto, nunca solo color).
String etiquetaDeCalidad(EstadoCalidad e) => e.etiqueta;

/// Texto de un nivel de señal.
String nombreNivelSenal(NivelSenal n) => switch (n) {
  NivelSenal.verde => 'En verde',
  NivelSenal.ambar => 'En ámbar',
  NivelSenal.rojo => 'En rojo',
  NivelSenal.porDeclarar => 'Por declarar',
  NivelSenal.sinDato => 'Sin dato',
};

/// Nombre de cada propósito de deuda para el formulario.
String nombreProposito(PropositoDeuda p) => switch (p) {
  PropositoDeuda.bienDuradero =>
    'Algo que dura (equipo, mueble, electrodoméstico)',
  PropositoDeuda.generaIngreso => 'Herramienta de trabajo o negocio',
  PropositoDeuda.patrimonio => 'Vivienda o patrimonio',
  PropositoDeuda.educacionOSalud => 'Educación, salud o protección',
  PropositoDeuda.emergencia => 'Una emergencia',
  PropositoDeuda.consumo => 'Un gusto o consumo',
};

String nombreEstadoObjetivo(EstadoObjetivo e) => switch (e) {
  EstadoObjetivo.vigente => 'Lo tengo y sigue vigente',
  EstadoObjetivo.cumplido => 'Ya lo tengo y lo uso',
  EstadoObjetivo.yaNoExiste => 'Ya no existe (vendido, devuelto, perdido)',
  EstadoObjetivo.cambio => 'Ya no lo quiero',
};

// --------------------------------------------------------------- títulos

String _mayuscula(String t) {
  final limpio = t.trim();
  if (limpio.isEmpty) return limpio;
  return limpio
      .split(RegExp(r'\s+'))
      .map((p) => p.isEmpty ? p : p[0].toUpperCase() + p.substring(1))
      .join(' ');
}

/// Cómo se llama una fuga en la lista: el comercio (si lo hay) y la
/// categoría. Son datos del libro: se ven en pantalla, nunca en un aviso.
String tituloDeFuga(FugaDetectada f, DatosFinanzas d) {
  final categoria = f.categoriaId == null
      ? null
      : d.arbol.porId(f.categoriaId!)?.nombre;
  if (f.clave.startsWith('hormiga|')) {
    return categoria == null
        ? 'Compras chicas'
        : 'Compras chicas en $categoria';
  }
  if (f.clave.startsWith('cargo|')) {
    final deuda = d.deudas.where((x) => x.id == f.deudaId).firstOrNull;
    return deuda == null
        ? 'Intereses y cargos'
        : 'Intereses y cargos de ${deuda.titulo}';
  }
  final comercio = f.comercioNorm;
  final base = comercio == null || comercio.isEmpty
      ? 'Cobro sin comercio'
      : _mayuscula(comercio);
  return categoria == null ? base : '$base · $categoria';
}
