/// Herramientas de navegación: abrir un módulo, una pantalla o una hoja de
/// registro.
///
/// No escriben datos ni leen nada de los módulos, así que no piden
/// confirmación. Abrir la hoja de un gasto tampoco escribe: la persona captura
/// y confirma en la hoja (una orden nunca registra dinero sola). Las de
/// Finanzas y Cuidados son solo locales como todas las de esos módulos (D3):
/// ni siquiera "se abrió Finanzas" llega a la IA en la nube. La clase es
/// `final` y su [HerramientaNavegacion.ejecutar] no lee datos, así que nadie
/// puede colar por aquí una herramienta que devuelva cifras.
library;

import '../contratos/dispositivo.dart';
import '../contratos/roles.dart';
import '../contratos/rutas.dart';
import 'herramienta.dart';
import 'visibilidad_modulos.dart';

/// Rutas que abren las herramientas además de las del contrato `Rutas`
/// (`nucleo/contratos/rutas.dart`, del arquitecto). Una prueba las compara
/// con las de la app; si pasan al contrato, se usan de ahí.
abstract final class RutasDeHerramientas {
  /// Semana de Finanzas: cascada, partidas y revisión semanal (pantalla
  /// "Semana" de la especificación de la Fase 1, sección 6). La declara el
  /// agente finanzas con `GoRoute(path: 'semana')` bajo la raíz del módulo.
  static const semanaFinanzas = '${Rutas.finanzas}/semana';

  /// Compromisos y deudas de Finanzas (pantalla "Compromisos y deudas").
  static const compromisosFinanzas = '${Rutas.finanzas}/compromisos';

  /// Bandeja de solicitudes y recordatorios de GRAVITY (D18; plataforma:
  /// `RutasApp.solicitudes`).
  static const solicitudes = '/solicitudes';
}

/// Abre una ruta de la app o una hoja de registro.
final class HerramientaNavegacion extends Herramienta {
  const HerramientaNavegacion({
    required this.nombre,
    required this.modulo,
    required this.roles,
    required this.ruta,
    required this.etiqueta,
    required this.palabrasClave,
    this.dispositivos,
    this.accion = Accion.leer,
    this.pertenencia = Pertenencia.propia,
    this.ambito = AmbitoHerramienta.general,
    this.hoja,
    this.consulta = false,
    this._descripcion,
  });

  @override
  final String nombre;

  @override
  final Modulo modulo;

  @override
  final Set<Rol> roles;

  /// Ruta que abre. Si tiene [hoja], es la pantalla del módulo que se abre
  /// cuando no hay dónde mostrar la hoja.
  final String ruta;

  /// Nombre visible del destino, p. ej. "Finanzas".
  final String etiqueta;

  /// Palabras (y frases cortas) que lo nombran en una orden, con acentos.
  /// La barra de órdenes las compara sin acentos ni mayúsculas.
  final List<String> palabrasClave;

  /// Dispositivos donde se ofrece; `null`: en todos (p. ej. Desarrollador solo
  /// en la laptop, D16). El router de la plataforma lo vuelve a revisar.
  final Set<TipoDispositivo>? dispositivos;

  /// Lo que la persona debe poder hacer en el módulo: leer para abrirlo;
  /// escribir para abrir la hoja de un registro; administrar para
  /// Desarrollador.
  @override
  final Accion accion;

  @override
  final Pertenencia pertenencia;

  @override
  final AmbitoHerramienta ambito;

  /// Hoja de registro que abre, si no es una pantalla. La hoja es la
  /// confirmación: sin que la persona guarde en ella, no se escribe nada.
  final HojaDeRegistro? hoja;

  /// `true` si es una consulta de solo lectura del libro propio: si el módulo
  /// entrega su contenido ([ContextoHerramienta.consultaLocal]) se muestra o
  /// se dice en local; si no, solo abre la vista. No la recibe la cuenta
  /// maestra de solo lectura total (no lleva libro propio, D19).
  final bool consulta;

  @override
  bool get ofreceASoloLectura => !consulta;

  final String? _descripcion;

  /// `true` si se ofrece en [dispositivo]. Si no se sabe en qué dispositivo
  /// se está (`null`), solo se ofrecen las que van en todos.
  bool disponibleEn(TipoDispositivo? dispositivo) {
    final permitidos = dispositivos;
    return permitidos == null ||
        (dispositivo != null && permitidos.contains(dispositivo));
  }

  /// Texto de la opción en la barra: "Abrir Finanzas" o, si abre una hoja,
  /// su etiqueta ("Registrar gasto").
  String get titulo => hoja == null ? 'Abrir $etiqueta' : etiqueta;

  @override
  String get descripcion => _descripcion ?? 'Abre $etiqueta.';

  /// Nunca escribe: abrir una pantalla o una hoja no guarda nada.
  @override
  bool get escribe => false;

  /// Solo local si su módulo lo es (D3: Finanzas y Cuidados). No depende de
  /// que el autor recuerde la marca.
  @override
  bool get soloLocal => modulosSoloLocal.contains(modulo);

  @override
  Future<ResultadoHerramienta> ejecutar(
    Map<String, Object?> parametros,
    ContextoHerramienta ctx,
  ) async {
    final hoja = this.hoja;
    final abrirHoja = ctx.abrirHoja;
    if (hoja != null && abrirHoja != null) {
      abrirHoja(hoja);
      return ResultadoHerramienta(
        this,
        contenido: '$etiqueta: captura y guarda en la hoja.',
        paraIa: 'Se abrió la hoja «$etiqueta»; no se guardó nada.',
      );
    }
    final navegar = ctx.navegar;
    final texto = consulta ? await ctx.consultaLocal?.call(nombre) : null;
    if (texto != null) {
      navegar?.call(ruta);
      return ResultadoHerramienta(this, contenido: texto);
    }
    if (navegar == null) {
      return ResultadoHerramienta(
        this,
        contenido: 'No hay una pantalla donde abrir $etiqueta.',
        paraIa: 'No se pudo abrir $etiqueta: no hay pantalla.',
      );
    }
    navegar(ruta);
    return ResultadoHerramienta(
      this,
      contenido: 'Abriendo $etiqueta…',
      paraIa: 'Se abrió $etiqueta.',
    );
  }
}

// ---------------------------------------------------------------------------
// Fase 0: abrir cada módulo, Ajustes y Desarrollador.
// ---------------------------------------------------------------------------

/// Pantalla principal de GRAVITY.
final herramientaAbrirInicio = HerramientaNavegacion(
  nombre: 'gravity.abrir',
  modulo: Modulo.gravity,
  roles: rolesParaNavegar(Modulo.gravity),
  ruta: Rutas.inicio,
  etiqueta: 'Inicio',
  palabrasClave: const [
    'inicio',
    'gravity',
    'principal',
    'pantalla principal',
    'menú principal',
  ],
);

/// Finanzas (solo local, D3): dueño y pareja, cada quien su libro (D19).
final herramientaAbrirFinanzas = HerramientaNavegacion(
  nombre: 'finanzas.abrir',
  modulo: Modulo.finanzas,
  roles: rolesParaNavegar(Modulo.finanzas),
  ruta: Rutas.finanzas,
  etiqueta: 'Finanzas',
  palabrasClave: const ['finanzas', 'presupuesto', 'presupuestos', 'dinero'],
);

final herramientaAbrirHabitos = HerramientaNavegacion(
  nombre: 'habitos.abrir',
  modulo: Modulo.habitos,
  roles: rolesParaNavegar(Modulo.habitos),
  ruta: Rutas.habitos,
  etiqueta: 'Hábitos',
  palabrasClave: const ['hábitos', 'hábito'],
);

/// Cuidados (solo local, D3). La cuidadora lo abre desde su navegación, no
/// desde GRAVITY (D18).
final herramientaAbrirCuidados = HerramientaNavegacion(
  nombre: 'cuidados.abrir',
  modulo: Modulo.cuidados,
  roles: rolesParaNavegar(Modulo.cuidados),
  ruta: Rutas.cuidados,
  etiqueta: 'Cuidados',
  palabrasClave: const ['cuidados', 'cuidado', 'papá'],
);

final herramientaAbrirAlimentacion = HerramientaNavegacion(
  nombre: 'alimentacion.abrir',
  modulo: Modulo.alimentacion,
  roles: rolesParaNavegar(Modulo.alimentacion),
  ruta: Rutas.alimentacion,
  etiqueta: 'Alimentación',
  palabrasClave: const [
    'alimentación',
    'comida',
    'comidas',
    'cocina',
    'menú',
    'menús',
    'receta',
    'recetas',
  ],
);

final herramientaAbrirCasa = HerramientaNavegacion(
  nombre: 'casa.abrir',
  modulo: Modulo.casa,
  roles: rolesParaNavegar(Modulo.casa),
  ruta: Rutas.casa,
  etiqueta: 'Casa',
  palabrasClave: const ['casa', 'hogar'],
);

final herramientaAbrirAjustes = HerramientaNavegacion(
  nombre: 'ajustes.abrir',
  modulo: Modulo.ajustes,
  roles: rolesParaNavegar(Modulo.ajustes),
  ruta: Rutas.ajustes,
  etiqueta: 'Ajustes',
  palabrasClave: const ['ajustes', 'ajuste', 'configuración', 'preferencias'],
);

/// Ajustes › Desarrollador: solo quien administra Ajustes, el Dueño, y solo
/// en la laptop (D16; `puedeVerDesarrollador` de la plataforma). Es de lo que
/// administra el hogar (lo ajeno): la cuenta maestra no la recibe (D19). La
/// barra de órdenes no la ofrece en otro dispositivo y el router la vuelve a
/// revisar.
final herramientaAbrirDesarrollador = HerramientaNavegacion(
  nombre: 'ajustes.abrir_desarrollador',
  modulo: Modulo.ajustes,
  roles: rolesQueAdministran(Modulo.ajustes),
  ruta: Rutas.desarrollador,
  etiqueta: 'Desarrollador',
  palabrasClave: const ['desarrollador', 'api', 'apis', 'swagger'],
  dispositivos: const {TipoDispositivo.laptop},
  accion: Accion.administrar,
  pertenencia: Pertenencia.ajena,
);

// ---------------------------------------------------------------------------
// Fase 1: Finanzas (solo locales, D3) y la bandeja de la cuidadora (D18).
// ---------------------------------------------------------------------------

/// Abre la hoja de registro rápido de un gasto (F1). No escribe: la hoja es
/// la confirmación. Solo para quien registra en Finanzas (dueño y pareja); si
/// no hay dónde mostrar la hoja, abre Finanzas.
///
/// **Hay que decir el verbo** (el dueño, 23/oct/2026): solo "registrar gasto"
/// y sus variantes con ese verbo. La palabra "gasto" suelta, "nuevo gasto" o
/// "anota gasto" ya no la nombran; así una palabra al aire no abre la hoja de
/// dinero. Tampoco la recibe la cuenta maestra que no es la dueña (solo
/// lectura total, D19): lo decide [RegistroHerramientas], no esta lista.
final herramientaRegistrarGasto = HerramientaNavegacion(
  nombre: 'finanzas.registrar_gasto',
  modulo: Modulo.finanzas,
  roles: rolesParaNavegar(Modulo.finanzas, accion: Accion.escribir),
  ruta: Rutas.finanzas,
  etiqueta: 'Registrar gasto',
  palabrasClave: const [
    'registrar gasto',
    'registra gasto',
    'registrar un gasto',
    'registra un gasto',
  ],
  accion: Accion.escribir,
  hoja: HojaDeRegistro.gasto,
  descripcion:
      'Abre la hoja para registrar un gasto. No guarda nada: la persona '
      'captura y confirma en la hoja.',
);

/// La semana de Finanzas: cascada, partidas con semáforo y revisión semanal.
final herramientaAbrirSemanaFinanzas = HerramientaNavegacion(
  nombre: 'finanzas.abrir_semana',
  modulo: Modulo.finanzas,
  roles: rolesParaNavegar(Modulo.finanzas),
  ruta: RutasDeHerramientas.semanaFinanzas,
  etiqueta: 'Presupuesto de la semana',
  palabrasClave: const [
    'mi semana',
    'semana',
    'esta semana',
    'presupuesto semanal',
    'cascada',
    'remanente',
    'cuánto me queda',
  ],
  descripcion:
      'Abre la semana de Finanzas (cascada, partidas y revisión semanal). '
      'Solo navega: los montos se ven en la pantalla, nunca van a la IA.',
);

/// Consulta: resumen de la semana (cascada, partidas, remanente). Solo lectura
/// y solo local (D3): el contenido lo entrega Finanzas desde sus datos locales
/// ([ContextoHerramienta.consultaLocal]) y nunca llega a la IA ni a las bocinas.
/// Sin contenido, abre la Semana.
final herramientaResumenSemana = HerramientaNavegacion(
  nombre: 'finanzas.resumen_semana',
  modulo: Modulo.finanzas,
  roles: rolesParaNavegar(Modulo.finanzas),
  ruta: RutasDeHerramientas.semanaFinanzas,
  etiqueta: 'Resumen de la semana',
  palabrasClave: const [
    'resumen de la semana',
    'resumen semanal',
    'cómo voy esta semana',
    'cómo va la semana',
  ],
  consulta: true,
  descripcion:
      'Da el resumen de la semana de Finanzas en pantalla o por voz local. '
      'Solo lectura; nunca va a la IA en la nube ni a las bocinas.',
);

/// Consulta: próximos pagos y vencimientos. Sin contenido, abre Compromisos y
/// deudas.
final herramientaProximosPagos = HerramientaNavegacion(
  nombre: 'finanzas.proximos_pagos',
  modulo: Modulo.finanzas,
  roles: rolesParaNavegar(Modulo.finanzas),
  ruta: RutasDeHerramientas.compromisosFinanzas,
  etiqueta: 'Próximos pagos',
  palabrasClave: const [
    'próximos pagos',
    'pagos próximos',
    'qué pagos vienen',
    'qué vence',
    'vencimientos',
  ],
  consulta: true,
  descripcion:
      'Da los próximos pagos y vencimientos de Finanzas en pantalla o por voz '
      'local. Solo lectura; nunca va a la IA en la nube ni a las bocinas.',
);

/// Consulta: avance del ahorro. Sin contenido, abre el Tablero de Finanzas
/// (aún no hay una pantalla de ahorro propia).
final herramientaAhorroAvance = HerramientaNavegacion(
  nombre: 'finanzas.ahorro_avance',
  modulo: Modulo.finanzas,
  roles: rolesParaNavegar(Modulo.finanzas),
  ruta: Rutas.finanzas,
  etiqueta: 'Avance del ahorro',
  palabrasClave: const [
    'avance del ahorro',
    'cómo va mi ahorro',
    'mis ahorros',
    'metas de ahorro',
    'ahorro',
  ],
  consulta: true,
  descripcion:
      'Da el avance de las bolsas de ahorro en pantalla o por voz local. Solo '
      'lectura; nunca va a la IA en la nube ni a las bocinas.',
);

/// Bandeja de solicitudes y recordatorios de GRAVITY: lo único de GRAVITY
/// que usa la cuidadora (D18). No es de conversación libre ni de la familia.
final herramientaAbrirSolicitudes = HerramientaNavegacion(
  nombre: 'gravity.abrir_solicitudes',
  modulo: Modulo.gravity,
  roles: rolesConBandeja(),
  ruta: RutasDeHerramientas.solicitudes,
  etiqueta: 'Solicitudes',
  palabrasClave: const [
    'solicitudes',
    'solicitud',
    'recordatorios',
    'recordatorio',
    'bandeja',
  ],
  ambito: AmbitoHerramienta.solicitudes,
  descripcion:
      'Abre la bandeja de solicitudes y recordatorios de GRAVITY para '
      'confirmarlos (hecho o no se pudo, con nota).',
);

/// Navegación de la Fase 0.
final List<HerramientaNavegacion> navegacionFase0 = List.unmodifiable([
  herramientaAbrirInicio,
  herramientaAbrirFinanzas,
  herramientaAbrirHabitos,
  herramientaAbrirCuidados,
  herramientaAbrirAlimentacion,
  herramientaAbrirCasa,
  herramientaAbrirAjustes,
  herramientaAbrirDesarrollador,
]);

/// Navegación de la Fase 1: Finanzas y la bandeja de la cuidadora.
final List<HerramientaNavegacion> navegacionFase1 = List.unmodifiable([
  herramientaRegistrarGasto,
  herramientaAbrirSemanaFinanzas,
  herramientaResumenSemana,
  herramientaProximosPagos,
  herramientaAhorroAvance,
  herramientaAbrirSolicitudes,
]);

/// Todo el catálogo de navegación, en el orden en que se sugiere.
final List<HerramientaNavegacion> herramientasNavegacion = List.unmodifiable([
  herramientaAbrirInicio,
  herramientaAbrirFinanzas,
  herramientaRegistrarGasto,
  herramientaAbrirSemanaFinanzas,
  herramientaResumenSemana,
  herramientaProximosPagos,
  herramientaAhorroAvance,
  herramientaAbrirHabitos,
  herramientaAbrirCuidados,
  herramientaAbrirAlimentacion,
  herramientaAbrirCasa,
  herramientaAbrirSolicitudes,
  herramientaAbrirAjustes,
  herramientaAbrirDesarrollador,
]);
